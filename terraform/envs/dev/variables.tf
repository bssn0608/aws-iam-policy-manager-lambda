variable "region" {
  type    = string
  default = "us-east-1"
}

#variable "allowed_vpce_ids" {
#  type = list(string)
#}

variable "lambda_zip_path" {
  type = string
}

variable "table_name" {
  type    = string
  default = "test-user-access"
}

variable "user_role_name" {
  type    = string
  default = "test-userid1-role"
}

variable "policy1_name" {
  type    = string
  default = "test-policy1"
}

variable "policy2_name" {
  type    = string
  default = "test-policy2"
}

variable "lambda_role_name" {
  type    = string
  default = "test-user-access-lambda"
}

variable "function_name" {
  type    = string
  default = "test-user-access"
}

variable "api_name" {
  type    = string
  default = "iam-policy-manager-api"
}

variable "stage_name" {
  type    = string
  default = "v1"
}
variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
  description = "Private subnet IDs in the VPC for the VPCE ENIs"
}
