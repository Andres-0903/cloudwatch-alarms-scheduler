# Solución diseñada para mutear diferentes alarmas

> **Objetivo**: lograr **mutear (silenciar) alarmas** y **prevenir el envío de notificaciones** en ciertos horarios, contribuyendo a **evitar falsos positivos** durante ventanas de mantenimiento o actividades planificadas.

---

## 🧩 Descripción general

Este módulo implementa un **programador de silencios** para alarmas de Amazon CloudWatch usando **Amazon EventBridge → AWS Lambda**.

- **EventBridge** activa dos reglas en horarios definidos: `mute` y `unmute` (formato **UTC**).
- **Lambda** recibe `{ "action": "MUTE" | "UNMUTE" }` y aplica `DisableAlarmActions` / `EnableAlarmActions` sobre **grandes volúmenes** de alarmas de forma segura (paginación + lotes de 100 + reintentos).
- **Selección flexible** de alarmas objetivo por **TAGS** (recomendado) o por **prefijo del nombre** (**PREFIX**), sin listas estáticas.
- **DLQ (Dead Letter Queue)** y **Retry Policy** para resiliencia.

> Probado con escenarios de **miles** de alarmas: el handler procesa por páginas y ejecuta en **lotes de hasta 100 nombres** por llamada a la API de CloudWatch (límite del servicio), con reintentos exponenciales.

---

## 🏗️ Arquitectura

```mermaid
flowchart LR
    subgraph EventBridge [Amazon EventBridge]
      R1[Regla MUTE\ncron(...)] --> T1
      R2[Regla UNMUTE\ncron(...)] --> T2
    end

    T1[Target\nLambda handler] --> L[(Lambda\nalarms-mute-handler)]
    T2[Target\nLambda handler] --> L

    L -->|DescribeAlarms (paginate)| CW[(Amazon CloudWatch)]
    L -->|Disable/EnableAlarmActions (batches ≤100)| CW

    T1 -. errores .-> DLQ[(SQS DLQ\nEventBridge DLQ)]
    T2 -. errores .-> DLQ
```

---

## ⚙️ Variables principales del módulo

- `name_prefix` : Prefijo para nombrar recursos.
- `mute_cron` / `unmute_cron`: Expresiones **cron** de EventBridge (**UTC**).
- `filter_mode` : `TAGS` | `PREFIX` | `ALL`.
- Para **TAGS**: `tag_key`, `tag_value`.
- Para **PREFIX**: `alarm_prefix` (se compara con el **inicio** del nombre del **Alarm**, no con el de la instancia).
- `regions`: Lista de regiones a consultar (CSV interno en Lambda). Por defecto `["us-east-1"]`.
- `batch_size`: Tamaño de lote de nombres por llamada (máx. **100**).

> **Nota**: El código del módulo empaqueta automáticamente `handler/handler.py` usando el provider `archive` y despliega la Lambda con `source_code_hash` para detectar cambios.

---

## ⏰ Conversión rápida de horario Colombia → UTC

Colombia es **UTC‑5** (sin DST).

> **UTC = Hora Colombia + 5 horas**

| Colombia | UTC   | Cron EventBridge                 |
| -------- | ----- | -------------------------------- |
| 05:15    | 10:15 | `cron(15 10 * * ? *)`            |
| 09:05    | 14:05 | `cron(05 14 * * ? *)`            |
| 11:15    | 16:15 | `cron(15 16 * * ? *)`            |
| 11:35    | 16:35 | `cron(35 16 * * ? *)`            |
| 19:20    | 00:20 | `cron(20 00 * * ? *)` (día sig.) |

---

## 🚀 Ejemplos de uso

### Ejemplo 1 — **Filtrar por TAGS** (recomendado)

Silenciar **solo** las alarmas que tengan `Name = MongoDB` todos los días entre **11:15** y **11:35** (hora Colombia).

```hcl
module "cloudwatch_alarms_scheduler" {
  source      = "git::https://github.com/Andres-0903/cloudwatch-alarms-scheduler.git//CloudwatchSilence?ref=v2.0.0"

  name_prefix = "demo_alarms"

  # 11:15 y 11:35 COL = 16:15 / 16:35 UTC
  mute_cron   = "cron(15 16 * * ? *)"
  unmute_cron = "cron(35 16 * * ? *)"

  # Selección de alarmas objetivo por TAG
  filter_mode = "TAGS"
  tag_key     = "Name"
  tag_value   = "MongoDB"

  regions     = ["us-east-1"]
  batch_size  = 100
}
```

> Asegúrate de que **las alarmas** tengan ese tag (no solo la EC2). Recomendado: heredar tags de la instancia al crear la alarma (`tags = merge(var.resource_tags, instance_tags[each.key], {...})`).

---

### Ejemplo 2 — **Filtrar por PREFIJO (PREFIX)**

Silenciar **todas** las alarmas cuyo **nombre** comience por `monitoreo-EC2-DCBOGCONT`, de 11:15 a 11:35 COL.

```hcl
module "cloudwatch_alarms_scheduler" {
  source      = "git::https://github.com/Andres-0903/cloudwatch-alarms-scheduler.git//CloudwatchSilence?ref=2.0.0"

  name_prefix = "demo_alarms_bog"

  # 11:15 y 11:35 COL = 16:15 / 16:35 UTC
  mute_cron   = "cron(15 16 * * ? *)"
  unmute_cron = "cron(35 16 * * ? *)"

  # Selección por prefijo del **nombre del Alarm** (no de la instancia)
  filter_mode  = "PREFIX"
  alarm_prefix = "monitoreo-EC2-xxxxx"

  regions     = ["us-east-1"]
  batch_size  = 100
}
```

> Ajusta `alarm_prefix` al **inicio real** de tus alarmas. Ej.: `monitoreo-EC2-CPUUtilization-DCBOGCONT`, `monitoreo-EC2-` (todas las EC2), etc.

---

## ✅ Validación

1. **Lambda (Test manual)**
   - Ejecuta en la consola de Lambda: `{ "action": "MUTE" }` y observa que las alarmas objetivo pasan a **Actions disabled**. Luego `{ "action": "UNMUTE" }`.
2. **EventBridge**
   - Pestaña **Event schedule**: verifica _Next invocations_ según el cron en **UTC**.
   - Pestaña **Targets**: Type = _Lambda function_, Input = `{ "action": "MUTE" | "UNMUTE" }`.
   - **Monitoring**: `Invocations` sube, `FailedInvocations = 0`.
3. **CloudWatch Alarms**
   - Columna **Actions**: `Actions disabled` durante la ventana; `Actions enabled` al terminar.
4. **Logs**
   - **CloudWatch Logs** de la Lambda: verás métricas (`found`, `changed`, `api_calls`, `filter_mode`, etc.).

---

## 🛡️ Resiliencia y límites

- **Batch size ≤ 100** (límite de `Disable/EnableAlarmActions`).
- **DescribeAlarms** paginado.
- Reintentos exponenciales ante _throttling_ (`max_attempts=8`).
- **DLQ (SQS)** conectada al target de EventBridge: si una invocación falla tras reintentos, el evento queda disponible para inspección y reproceso manual.

---

## 🧰 Troubleshooting

- **No se ejecutó a la hora**: revisa que el cron esté en **UTC** y la regla en **Enabled**.
- **EventBridge invoca pero no cambia alarmas**: valida filtros (`TAGS`/`PREFIX`) y que las alarmas realmente matcheen.
- **Permisos**: la Lambda debe tener `cloudwatch:DescribeAlarms`, `Disable/EnableAlarmActions`, `ListTagsForResource`, y `logs:*`.
- **Mensajes en DLQ**: inspecciona SQS para ver el motivo exacto del fallo.
- **Cambios en handler**: el módulo usa `archive_file` + `source_code_hash`; cualquier cambio en `handler.py` redeploya automáticamente.

---

## 📦 Estructura del módulo

```
CloudwatchSilence/
├─ handler/
│  └─ handler.py
├─ lambda.tf          # archive_file + aws_lambda_function + permisos
├─ eventbridge.tf     # reglas + targets + DLQ + retry
├─ iam.tf             # rol + inline policy para Lambda
├─ variables.tf       # interfaz del módulo
├─ outputs.tf
├─ versions.tf        # required_providers { aws, archive }
└─ README.md
```

---

## 🔄 Escenarios avanzados (opcional)

- **Varios prefijos**: instanciar varios módulos con distintos `alarm_prefix`. Alternativa: extender `handler.py` para aceptar `ALARM_PREFIXES` en CSV.
- **Varios valores de tag**: extender `handler.py` para aceptar una lista (`TAG_VALUES="MongoDB,Redis"`).
- **Filtro compuesto**: combinación TAG + PREFIX (requiere cambio menor en handler).
- **Multi‑región**: establece `regions = ["us-east-1","us-west-2", ...]`.
- **Multi‑cuenta**: invocación cross‑account o despliegue por cuenta.

---

## 📝 Licencia y mantenimiento

- Recomendación: versionado semántico (`v2.x`) para cambios mayores (ej. cambio SSM→Lambda).
- Mantener el `ref` del módulo en tags inmutables.

---

## 👀 Créditos

Diseño y pruebas: muteo programado con EventBridge→Lambda, filtrado por TAGS/PREFIX y empaquetado automático con `archive_file`, orientado a evitar falsos positivos en ventanas de mantenimiento.
