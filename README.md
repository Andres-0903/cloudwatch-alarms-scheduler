# cloudwatch-alarms-scheduler

Módulo **Terraform** para programar el *muteo (silence)* y *desmuteo* automático de acciones de alarmas de **Amazon CloudWatch**
usando **EventBridge** y **AWS Systems Manager (SSM)**, **sin necesidad de Lambda**.

Este módulo **NO crea alarmas**, únicamente actúa sobre alarmas existentes.

---

## 📌 Uso

```hcl
module "cloudwatch_alarms_silence" {
  source = "github.com/Andres-0903/cloudwatch-alarms-scheduler?ref=feature/monitoring"

  alarm_names = [
    "monitoreo-EC2-CPUUtilization-Apache-dev",
    "monitoreo-EC2-MemoryUtilization-Apache-dev"
  ]

  mute_cron   = "cron(0 23 * * ? *)" # 11:00 PM
  unmute_cron = "cron(0 6 * * ? *)"  # 06:00 AM
}
```

---

## 🔧 Variables

| Nombre        | Tipo          | Descripción |
|--------------|---------------|-------------|
| `alarm_names` | `list(string)` | Lista de nombres de alarmas de CloudWatch |
| `mute_cron`   | `string`       | Expresión cron para mutear alarmas |
| `unmute_cron` | `string`       | Expresión cron para desmutear alarmas |

---

## 📤 Outputs (opcional)

Puedes exponer los ARNs de las reglas de EventBridge si lo deseas:

```hcl
output "mute_rule_arn" {
  value = aws_cloudwatch_event_rule.mute.arn
}

output "unmute_rule_arn" {
  value = aws_cloudwatch_event_rule.unmute.arn
}
```

---

## ⚙️ Requisitos

- Terraform >= 1.0
- AWS Provider >= 5.x
- Permisos IAM para:
  - `cloudwatch:DisableAlarmActions`
  - `cloudwatch:EnableAlarmActions`
  - `ssm:StartAutomationExecution`

---

## 📝 Notas

- Diseñado para ambientes **dev / qa / prod**
- Escala sin problema a **cientos de alarmas**
- Ideal para integrarse con **pipelines Jenkins**
- Compatible con cuentas **AWS Free Tier**

---

## 🧠 Arquitectura

```
EventBridge (cron)
        ↓
SSM Automation
        ↓
CloudWatch (Enable / Disable Alarm Actions)
```
