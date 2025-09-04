variable "name" {
  type = string
}

variable "lambda_invoke_arn" {
  type = string
}

variable "lambda_function_name" {
  type = string
}

variable "allowed_vpce_ids" {
  type = list(string)
}

variable "stage_name" {
  type    = string
  default = "v1"
}
variable "region" {
  type = string
}

