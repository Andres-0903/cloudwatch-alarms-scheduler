variable "name_prefix" {
  description = "Prefix for the CloudWatch Silence name"
  type        = string
  default     = "cloudwatch-silence"
}

variable "disable_cron" {
  description = "Cron Expression para mutear alarmas"
  type        = string
}


variable "enable_cron" {
  description = "Cron Expression para activar alarmas"
  type        = string
}

variable "region" {
  description = "Region en la que se crearan los recursos"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "Account ID donde se crearan los recursos"
  type        = string
}

####Variables para las alarmas
variable "alarm_names" {
  type        = list(string)
  description = "Alarmas a mutear"
}

variable "mute_cron" {
  type = string
}

variable "unmute_cron" {
  type = string
}


