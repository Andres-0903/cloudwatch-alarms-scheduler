############################################
# EventBridge rules + IAM para SSM Automation
############################################

resource "aws_cloudwatch_event_rule" "mute" {
  description         = "Rule to mute CloudWatch alarms on schedule"
  name                = "${var.name_prefix}-mute"
  schedule_expression = var.mute_cron
}

resource "aws_cloudwatch_event_rule" "unmute" {
  description         = "Rule to unmute CloudWatch alarms on schedule"
  name                = "${var.name_prefix}-unmute"
  schedule_expression = var.unmute_cron
}

# Rol que EventBridge asume para invocar SSM Automation
resource "aws_iam_role" "eventbridge_role_assume" {
  name = "${var.name_prefix}-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Permiso mínimo: permitir StartAutomationExecution solo sobre nuestros documentos
resource "aws_iam_role_policy" "eventbridge_ssm_policy" {
  name = "${var.name_prefix}-eventbridge-ssm-policy"
  role = aws_iam_role.eventbridge_role_assume.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StartAutomationExecutionOnlyOnDocs"
        Effect = "Allow"
        Action = "ssm:StartAutomationExecution"
        Resource = [
          aws_ssm_document.mute_alarms.arn,
          aws_ssm_document.unmute_alarms.arn
        ]
      },
      {
        Sid      = "PassAutomationRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.ssm_automation_role.arn
      }
    ]
  })
}
