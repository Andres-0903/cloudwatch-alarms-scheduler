###Reglas de EventBridge para gestionar silencios en CloudWatch###
resource "aws_cloudwatch_event_rule" "mute" {
  name                = "mute-alarms-rule"
  schedule_expression = var.mute_cron
}

resource "aws_cloudwatch_event_rule" "unmute" {
  name                = "unmute-alarms-rule"
  schedule_expression = var.unmute_cron
}

##Roles de EventBridge para mutear y desmutear alarmas##
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
