output "mute_rule_name" {
  description = "Nombre de la regla EventBridge para mutear alarmas"
  value       = aws_cloudwatch_event_rule.mute.name
}

output "unmute_rule_name" {
  description = "Nombre de la regla EventBridge para desmutear alarmas"
  value       = aws_cloudwatch_event_rule.unmute.name
}

output "eventbridge_role_arn" {
  description = "ARN del rol que usa EventBridge para invocar SSM Automation"
  value       = aws_iam_role.eventbridge_role_assume.arn
}

output "ssm_automation_role_arn" {
  description = "ARN del rol asumido por SSM Automation en la ejecución"
  value       = aws_iam_role.ssm_automation_role.arn
}

output "alarm_arns" {
  description = "ARNs de las alarmas objetivo"
  value       = local.alarm_arns
}
