###------Regla para deshabilitar alarmas------###
resource "aws_cloudwatch_event_rule" "disable_alarms_rule" {
  name                = "{var.name_prefix}-disable-alarms-rule"
  description         = "Rule to disable CloudWatch Alarms during silence period"
  schedule_expression = var.disable_cron
}

resource "aws_cloudwatch_event_target" "disable_target" {
  rule      = aws_cloudwatch_event_rule.disable_alarms_rule.name
  target_id = "EnableAlarm_Actions"
  arn       = "arn:aws:cloudwatch:${var.region}:${var.account_id}:alarm:*"
  role_arn  = aws_iam_role.eventbirdge_role.arn
  input     = "{}"

}

###-----SSM Parameter to hold alarm names to mute-----###
resource "aws_ssm_document" "mute_alarms" {
  name          = "mute-cloudwatch-alarms"
  document_type = "Automation"

  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Mute CloudWatch alarms"
    mainSteps = [{
      name   = "DisableAlarms"
      action = "aws:executeAwsApi"
      inputs = {
        Service    = "CloudWatch"
        Api        = "DisableAlarmActions"
        AlarmNames = var.alarm_names
      }
    }]
  })
}
###------Regla para habilitar alarmas------###
resource "aws_ssm_document" "unmute_alarms" {
  name          = "mute-cloudwatch-alarms"
  document_type = "Automation"

  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Mute CloudWatch alarms"
    mainSteps = [{
      name   = "EnableAlarmActions"
      action = "aws:executeAwsApi"
      inputs = {
        Service    = "CloudWatch"
        Api        = "EnableAlarmActions"
        AlarmNames = var.alarm_names
      }
    }]
  })
}

##Targets SSM para mutear y desmutear alarmas##
resource "aws_cloudwatch_event_target" "mute_target" {
  rule     = aws_cloudwatch_event_rule.mute.name
  arn      = aws_ssm_document.mute_alarms.arn
  role_arn = aws_iam_role.eventbridge_ssm_role.arn
}

resource "aws_cloudwatch_event_target" "unmute_target" {
  rule     = aws_cloudwatch_event_rule.unmute.name
  arn      = aws_ssm_document.unmute_alarms.arn
  role_arn = aws_iam_role.eventbridge_ssm_role.arn
}
