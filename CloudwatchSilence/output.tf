output "disable_rule_arn" {
  value = aws_cloudwatch_event_rule.disable_alarms_rule.arn
}

output "enable_rule_arn" {
  value = aws_cloudwatch_event_rule.enable_alarms_rule.arn
}
