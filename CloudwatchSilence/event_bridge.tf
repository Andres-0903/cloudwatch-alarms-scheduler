############################################
# Reglas de EventBridge (una sola vez c/u)
############################################
resource "aws_cloudwatch_event_rule" "mute" {
  name                = "${var.name_prefix}-mute"
  description         = "Mute CloudWatch alarms on schedule"
  schedule_expression = var.mute_cron
}

resource "aws_cloudwatch_event_rule" "unmute" {
  name                = "${var.name_prefix}-unmute"
  description         = "Unmute CloudWatch alarms on schedule"
  schedule_expression = var.unmute_cron
}

############################################
# DLQ opcional para ver errores de invocación
############################################
resource "aws_sqs_queue" "eventbridge_dlq" {
  name = "${var.name_prefix}-eventbridge-dlq"
}

############################################
# Targets EventBridge -> Lambda
############################################
resource "aws_cloudwatch_event_target" "mute_target" {
  rule      = aws_cloudwatch_event_rule.mute.name
  target_id = "mute-lambda-v1"
  arn       = aws_lambda_function.mute_handler.arn
  input     = jsonencode({ action = "MUTE" })

  dead_letter_config {
    arn = aws_sqs_queue.eventbridge_dlq.arn
  }
  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts       = 2
  }
}

resource "aws_cloudwatch_event_target" "unmute_target" {
  rule      = aws_cloudwatch_event_rule.unmute.name
  target_id = "unmute-lambda-v1"
  arn       = aws_lambda_function.mute_handler.arn
  input     = jsonencode({ action = "UNMUTE" })

  dead_letter_config {
    arn = aws_sqs_queue.eventbridge_dlq.arn
  }
  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts       = 2
  }
}
