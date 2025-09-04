variable "function_name" {
  type = string
}

variable "role_arn" {
  type = string
}

variable "lambda_zip_path" {
  type = string
}

variable "source_code_hash" {
  type = string
}

variable "environment" {
  type    = map(string)
  default = {}
}
