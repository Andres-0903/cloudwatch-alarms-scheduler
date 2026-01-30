variable "name_prefix" {
  description = "Prefix for CloudWatch silence resources"
  type        = string
  default     = "cloudwatch-silence"
}

variable "alarm_names" {
  description = "List of CloudWatch alarm names to mute/unmute"
  type        = list(string)

  # CloudWatch API: máximo 100 nombres por llamada
  validation {
    condition     = length(var.alarm_names) > 0 && length(var.alarm_names) <= 100
    error_message = "alarm_names must contain 1..100 items (CloudWatch API limit)."
  }
}

variable "mute_cron" {
  description = "Cron expression to mute CloudWatch alarms (EventBridge)"
  type        = string

  validation {
    condition     = length(var.mute_cron) > 0
    error_message = "mute_cron cannot be empty"
  }
}

variable "unmute_cron" {
  description = "Cron expression to unmute CloudWatch alarms (EventBridge)"
  type        = string

  validation {
    condition     = length(var.unmute_cron) > 0
    error_message = "unmute_cron cannot be empty"
  }
}
