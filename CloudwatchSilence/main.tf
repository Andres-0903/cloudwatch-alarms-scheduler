resource "aws_ssm_document" "mute_alarms" {
  name          = "mute-cloudwatch-alarms"
  document_type = "Automation"

  content = jsonencode({
    schemaVersion = "0.3"
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

resource "aws_ssm_document" "unmute_alarms" {
  name          = "unmute-cloudwatch-alarms"
  document_type = "Automation"

  content = jsonencode({
    schemaVersion = "0.3"
    mainSteps = [{
      name   = "EnableAlarms"
      action = "aws:executeAwsApi"
      inputs = {
        Service    = "CloudWatch"
        Api        = "EnableAlarmActions"
        AlarmNames = var.alarm_names
      }
    }]
  })
}

resource "aws_cloudwatch_event_target" "mute_target" {
  rule     = aws_cloudwatch_event_rule.mute.name
  arn      = aws_ssm_document.mute_alarms.arn
  role_arn = aws_iam_role.eventbridge_role_assume.arn

  depends_on = [aws_iam_role_policy.eventbridge_ssm_policy]
}

resource "aws_cloudwatch_event_target" "unmute_target" {
  rule     = aws_cloudwatch_event_rule.unmute.name
  arn      = aws_ssm_document.unmute_alarms.arn
  role_arn = aws_iam_role.eventbridge_role_assume.arn

  depends_on = [aws_iam_role_policy.eventbridge_ssm_policy]
}
