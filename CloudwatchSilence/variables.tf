variable "name_prefix" {
  description = "Prefix for CloudWatch silence resources"
  type        = string
  default     = "cloudwatch-silence"
}

variable "alarm_names" {
  description = "List of CloudWatch alarm names to mute/unmute"
  type        = list(string)
}

variable "mute_cron" {
  description = "Cron expression to mute CloudWatch alarms"
  type        = string

  validation {
    condition     = length(var.mute_cron) > 0
    error_message = "mute_cron cannot be empty"
  }
}

variable "unmute_cron" {
  description = "Cron expression to unmute CloudWatch alarms"
  type        = string
}


variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
