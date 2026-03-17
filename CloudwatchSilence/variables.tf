variable "name_prefix" {
  type    = string
  default = "myapp"
}

# Horarios (EventBridge usa UTC)
# 09:05 Colombia = 14:05 UTC
variable "mute_cron" {
  type    = string
  default = "cron(05 14 * * ? *)"
}

# 09:15 Colombia = 14:15 UTC
variable "unmute_cron" {
  type    = string
  default = "cron(15 14 * * ? *)"
}

# Filtro de selección para Lambda
variable "filter_mode" {
  type    = string
  default = "TAGS" # TAGS | PREFIX | ALL
  validation {
    condition     = contains(["TAGS", "PREFIX", "ALL"], upper(var.filter_mode))
    error_message = "filter_mode debe ser TAGS, PREFIX o ALL."
  }
}

variable "tag_key" {
  type    = string
  default = "Mute"
}

variable "tag_value" {
  type    = string
  default = "true"
}

variable "alarm_prefix" {
  type    = string
  default = ""
}

variable "batch_size" {
  type    = number
  default = 100 # <=100 por llamada API
  validation {
    condition     = var.batch_size >= 1 && var.batch_size <= 100
    error_message = "batch_size debe estar entre 1 y 100."
  }
}

variable "regions" {
  type    = list(string)
  default = ["us-east-1"]
}

variable "runtime_version" {
  description = "version lambda"
  type        = string
  default     = "python3.13"
}
