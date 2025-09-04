terraform {
  required_version = ">= 1.6.0"
  required_providers { aws = { source = "hashicorp/aws", version = ">= 5.0" } }
}


provider "aws" { region = var.region }


#data "aws_region" "cur" {}


module "dynamodb" {
  source     = "../../modules/dynamodb"
  table_name = var.table_name
}


module "iam" {
  source             = "../../modules/iam"
  user_role_name     = var.user_role_name
  policy1_name       = var.policy1_name
  policy2_name       = var.policy2_name
  lambda_role_name   = var.lambda_role_name
  dynamodb_table_arn = module.dynamodb.table_arn
}


# Compute hash of the lambda zip so TF updates function on code change
locals { lambda_code_hash = filebase64sha256(var.lambda_zip_path) }


module "lambda" {
  source           = "../../modules/lambda"
  function_name    = var.function_name
  role_arn         = module.iam.lambda_role_arn
  lambda_zip_path  = var.lambda_zip_path
  source_code_hash = local.lambda_code_hash
  environment = {
  TABLE_NAME    = module.dynamodb.table_name
  ROLE_TEMPLATE = "{userid}-role"  # literal placeholder consumed by Lambda
}

}

# Discover VPC (for its CIDR)
data "aws_vpc" "this" {
  id = var.vpc_id
}

# Security group for the Interface VPCE
resource "aws_security_group" "vpce_apigw" {
  name        = "apigw-vpce-sg"
  description = "Allow HTTPS from VPC to API Gateway VPCE"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this.cidr_block] # allow callers inside the VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Interface VPC Endpoint for API Gateway (execute-api)
#data "aws_region" "cur" {}

resource "aws_vpc_endpoint" "apigw" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.execute-api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.vpce_apigw.id]
  private_dns_enabled = true
}


module "api" {
  source               = "../../modules/api_gateway_private"
  name                 = var.api_name
  stage_name           = var.stage_name
  lambda_invoke_arn    = module.lambda.function_arn 
  lambda_function_name = module.lambda.function_name
  allowed_vpce_ids     = [aws_vpc_endpoint.apigw.id]   # <-- this is the key line
  region               = var.region
}

