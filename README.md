# cloudwatch-alarms-scheduler
Este modulo permite silenciar alarmas en cloudwatch


--🎃🎶
## Ejemplo de uso

module "cloudwatch_mute_scheduler" {
  source      = "./modules/cloudwatch-alarms-scheduler"

  name_prefix = "prod-alarms"

  region      = "us-east-1"
  account_id  = "123456789012"

  # 11 PM para mutear
  disable_cron = "cron(0 23 * * ? *)"

  # 6 AM para activar
  enable_cron  = "cron(0 6 * * ? *)"
}
--🤖👾