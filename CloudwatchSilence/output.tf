output "mute_rule_name" {
  description = "Nombre de la regla EventBridge para mutear alarmas"
  value       = aws_cloudwatch_event_rule.mute.name
}

output "unmute_rule_name" {
  description = "Nombre de la regla EventBridge para desmutear alarmas"
  value       = aws_cloudwatch_event_rule.unmute.name
}

output "lambda_function_name" {
  description = "Nombre de la Lambda que mutea/desmutea alarmas"
  value       = aws_lambda_function.mute_handler.function_name
}

output "eventbridge_dlq_url" {
  description = "SQS DLQ para EventBridge (si hay fallos de invocación)"
  value       = aws_sqs_queue.eventbridge_dlq.id
}
