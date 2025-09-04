terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  role             = var.role_arn
  filename         = var.lambda_zip_path
  source_code_hash = var.source_code_hash
  handler          = "main.lambda_handler"
  runtime          = "python3.12"

  environment {
    variables = var.environment
  }
}
