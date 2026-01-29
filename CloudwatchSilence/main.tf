resource "aws_iam_role" "eventbridge_role" {
  name = "${var.name_prefix}-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "eventbridge_policy" {
  name = "${var.name_prefix}-eventbridge-policy"
  role = aws_iam_role.eventbridge_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:DisableAlarmActions",
          "cloudwatch:EnableAlarmActions"
        ],
        Resource = "*"
      }
    ]
  })
}

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
