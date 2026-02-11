# CloudWatch Alarms Scheduler

Módulo de Terraform para **silenciar** (_mute_) y **reactivar** (_unmute_) acciones de **Amazon CloudWatch Alarms** de forma **programada** mediante **Amazon EventBridge** y **AWS Systems Manager Automation** (sin Lambda).

## Objetivo

- Deshabilitar acciones de alarmas durante ventanas de mantenimiento.
- Reactivar automáticamente al finalizar la ventana.
- Mantener un enfoque serverless con mínimo privilegio IAM.

## Diagrama

![Proceso](diagram.png)

## Variables

```hcl
variable "name_prefix" { type = string }
variable "alarm_names"  { type = list(string) }
variable "mute_cron"    { type = string }
variable "unmute_cron"  { type = string }
```

> **Notas**
>
> - Las expresiones `cron()` de EventBridge se evalúan en **UTC**.
> - Las APIs `DisableAlarmActions`/`EnableAlarmActions` aceptan **hasta 100** nombres por invocación; si tienes más, divide en lotes.

## Ejemplo de uso

```hcl
module "cloudwatch_alarms_scheduler" {
  source = "git::https://github.com/Andres-0903/cloudwatch-alarms-scheduler.git//CloudwatchSilence?ref=1.0.8"

  name_prefix = "Demo_alarms"

  # Colombia -> UTC (ejemplos)
  mute_cron   = "cron(15 10 * * ? *)" # 05:15 COL = 10:15 UTC
  unmute_cron = "cron(00 11 * * ? *)" # 06:00 COL = 11:00 UTC

  # Selección de alarmas
  filter_mode = "TAGS" # o "PREFIX" o "ALL"
  tag_key     = "Mute"
  tag_value   = "true"
  # Si usas prefijo:
  # alarm_prefix = "ec2-"

  regions = ["us-east-1"]
}
```

## Salidas

- `mute_rule_name`, `unmute_rule_name`
- `eventbridge_role_arn`, `ssm_automation_role_arn`
- `alarm_arns`

## Cómo funciona

1. Dos **reglas de EventBridge** (mute/unmute) con cron en UTC.
2. Cada regla invoca un **SSM Automation Document** que llama a `DisableAlarmActions` o `EnableAlarmActions`.
3. **CloudWatch** aplica los cambios en las alarmas especificadas.

## Seguridad

- IAM con alcance a los **ARNs** de las alarmas objetivo.
- Sin runtimes administrados: menor superficie operativa.

## Roadmap

- Opción con **EventBridge Scheduler** y `schedule_timezone`.
- Soporte de auto-chunking para >100 alarmas.
