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
    description   = "Mute CloudWatch alarms by disabling actions"
    parameters = {
      AutomationAssumeRole = {
        type        = "String"
        description = "IAM role for Automation to assume"
      }
      AlarmNames = {
        type        = "StringList"
        description = "Target CloudWatch alarm names"
        default     = var.alarm_names
      }
    }
    assumeRole = "{{ AutomationAssumeRole }}"
    mainSteps = [
      {
        name   = "DisableAlarms"
        action = "aws:executeAwsApi"
        inputs = {
          Service    = "CloudWatch"
          Api        = "DisableAlarmActions"
          AlarmNames = "{{ AlarmNames }}"
        }
      }
    ]
  })
}

resource "aws_ssm_document" "unmute_alarms" {
  name          = "unmute-cloudwatch-alarms"
  document_type = "Automation"

  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Unmute CloudWatch alarms by enabling actions"
    parameters = {
      AutomationAssumeRole = {
        type        = "String"
        description = "IAM role for Automation to assume"
      }
      AlarmNames = {
        type        = "StringList"
        description = "Target CloudWatch alarm names"
        default     = var.alarm_names
      }
    }
    assumeRole = "{{ AutomationAssumeRole }}"
    mainSteps = [
      {
        name   = "EnableAlarms"
        action = "aws:executeAwsApi"
        inputs = {
          Service    = "CloudWatch"
          Api        = "EnableAlarmActions"
          AlarmNames = "{{ AlarmNames }}"
        }
      }
    ]
  })
}

############################################
# EventBridge Targets & SSM Automation
############################################

# Target: mute
resource "aws_cloudwatch_event_target" "mute_target" {
  rule     = aws_cloudwatch_event_rule.mute.name
  arn      = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:automation-definition/${aws_ssm_document.mute_alarms.name}:$DEFAULT"
  role_arn = aws_iam_role.eventbridge_role_assume.arn

  input = jsonencode({
    DocumentName    = aws_ssm_document.mute_alarms.name
    DocumentVersion = "$DEFAULT" # opcional, pero consistente
    Parameters = {
      AutomationAssumeRole = [aws_iam_role.ssm_automation_role.arn]
      AlarmNames           = var.alarm_names
    }
  })

  depends_on = [aws_iam_role_policy.eventbridge_ssm_policy]
}

# Target: unmute
resource "aws_cloudwatch_event_target" "unmute_target" {
  rule     = aws_cloudwatch_event_rule.unmute.name
  arn      = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:automation-definition/${aws_ssm_document.unmute_alarms.name}:$DEFAULT"
  role_arn = aws_iam_role.eventbridge_role_assume.arn

  input = jsonencode({
    DocumentName    = aws_ssm_document.unmute_alarms.name
    DocumentVersion = "$DEFAULT"
    Parameters = {
      AutomationAssumeRole = [aws_iam_role.ssm_automation_role.arn]
      AlarmNames           = var.alarm_names
    }
  })

  depends_on = [aws_iam_role_policy.eventbridge_ssm_policy]
}


