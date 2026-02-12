
##Empaqueta automáticamente handler/handler.py → build/lambda_mute.zip
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/handler/handler.py"
  output_path = "${path.module}/build/lambda_mute.zip"
}

resource "aws_lambda_function" "mute_handler" {
  function_name = "${var.name_prefix}-alarms-mute-handler"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  filename      = "lambda_mute.zip" # ZIP que contiene handler.py en la raíz

  timeout     = 600
  memory_size = 256

  environment {
    variables = {
      FILTER_MODE  = var.filter_mode # TAGS | PREFIX | ALL
      TAG_KEY      = var.tag_key
      TAG_VALUE    = var.tag_value
      ALARM_PREFIX = var.alarm_prefix
      BATCH_SIZE   = tostring(var.batch_size)
      REGIONS      = join(",", var.regions) # "us-east-1,us-west-2"
      DRY_RUN      = "false"
    }
  }
}

# Permisos para que EventBridge invoque la Lambda
resource "aws_lambda_permission" "allow_events_mute" {
  statement_id  = "AllowExecutionFromEventBridgeMute"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mute_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.mute.arn
}

resource "aws_lambda_permission" "allow_events_unmute" {
  statement_id  = "AllowExecutionFromEventBridgeUnmute"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mute_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.unmute.arn
}
