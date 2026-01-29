resource "aws_cloudwatch_event_rule" "mute" {
  name                = "${var.name_prefix}-mute"
  schedule_expression = var.mute_cron
}

resource "aws_cloudwatch_event_rule" "unmute" {
  name                = "${var.name_prefix}-unmute"
  schedule_expression = var.unmute_cron
}
