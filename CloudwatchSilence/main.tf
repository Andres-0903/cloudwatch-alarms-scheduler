############################################
# Datos de cuenta/region y ARNs de alarmas
############################################
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Construimos los ARNs exactos de cada alarma para reducir el alcance de IAM
locals {
  alarm_arns = [
    for n in var.alarm_names :
    format(
      "arn:aws:cloudwatch:%s:%s:alarm:%s",
      data.aws_region.current.name,
      data.aws_caller_identity.current.account_id,
      n
    )
  ]
}

############################################
# Rol que usará SSM Automation
############################################
resource "aws_iam_role" "ssm_automation_role" {
  name        = "${var.name_prefix}-ssm-automation-role"
  description = "IAM Role for SSM Automation to mute/unmute CloudWatch Alarms"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ssm.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Política con privilegios mínimos: solo sobre las alarmas objetivo
resource "aws_iam_policy" "ssm_automation_policy" {
  name        = "${var.name_prefix}-ssm-automation-role-policy"
  description = "Policy for SSM Automation to mute/unmute CloudWatch Alarms"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cloudwatch:DisableAlarmActions",
        "cloudwatch:EnableAlarmActions",
        "cloudwatch:DescribeAlarms"
      ]
      Resource = local.alarm_arns
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_automation_role_attachment" {
  role       = aws_iam_role.ssm_automation_role.name
  policy_arn = aws_iam_policy.ssm_automation_policy.arn
}

############################################
# SSM Automation Documents
############################################
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

############################################
# EventBridge Targets & SSM Automation
############################################
resource "aws_cloudwatch_event_target" "mute_target" {
  rule     = aws_cloudwatch_event_rule.mute.name
  arn      = aws_ssm_document.mute_alarms.arn
  role_arn = aws_iam_role.eventbridge_role_assume.arn

  input = jsonencode({
    DocumentName = aws_ssm_document.mute_alarms.name
    Parameters = {
      AutomationAssumeRole = [aws_iam_role.ssm_automation_role.arn]
    }
  })

  depends_on = [aws_iam_role_policy.eventbridge_ssm_policy]
}

resource "aws_cloudwatch_event_target" "unmute_target" {
  rule     = aws_cloudwatch_event_rule.unmute.name
  arn      = aws_ssm_document.unmute_alarms.arn
  role_arn = aws_iam_role.eventbridge_role_assume.arn

  input = jsonencode({
    DocumentName = aws_ssm_document.unmute_alarms.name
    Parameters = {
      AutomationAssumeRole = [aws_iam_role.ssm_automation_role.arn]
    }
  })

  depends_on = [aws_iam_role_policy.eventbridge_ssm_policy]
}
