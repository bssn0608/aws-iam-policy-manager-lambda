terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_caller_identity" "cur" {}
#data "aws_region" "cur" {}
data "aws_partition" "cur" {}

# 1) Create the Private REST API (no policy here)
resource "aws_api_gateway_rest_api" "this" {
  name = var.name

  endpoint_configuration {
    types            = ["PRIVATE"]
    vpc_endpoint_ids = var.allowed_vpce_ids
  }
}

# 2) Attach the resource policy in a separate resource (avoids self-reference)
resource "aws_api_gateway_rest_api_policy" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Sid       = "DenyUnlessViaAllowedVPCE",
        Effect    = "Deny",
        Principal = "*",
        Action    = "execute-api:Invoke",
        Resource  = "arn:${data.aws_partition.cur.partition}:execute-api:${var.region}:${data.aws_caller_identity.cur.account_id}:${aws_api_gateway_rest_api.this.id}/*/*/*",
        Condition = {
          StringNotEquals = {
            "aws:SourceVpce" = var.allowed_vpce_ids
          }
        }
      },
      {
        Sid       = "AllowAllAfterDeny",
        Effect    = "Allow",
        Principal = "*",
        Action    = "execute-api:Invoke",
        Resource  = "arn:${data.aws_partition.cur.partition}:execute-api:${var.region}:${data.aws_caller_identity.cur.account_id}:${aws_api_gateway_rest_api.this.id}/*/*/*"
      }
    ]
  })
}

# 3) Resource + Method + Integration
resource "aws_api_gateway_resource" "user_access" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "user-access"
}

resource "aws_api_gateway_method" "get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.user_access.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.user_access.id
  http_method             = aws_api_gateway_method.get.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri = "arn:${data.aws_partition.cur.partition}:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.lambda_invoke_arn}/invocations"
  
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:${data.aws_partition.cur.partition}:execute-api:${var.region}:${data.aws_caller_identity.cur.account_id}:${aws_api_gateway_rest_api.this.id}/*/${aws_api_gateway_method.get.http_method}${aws_api_gateway_resource.user_access.path}"
}

# 4) Deployment + Stage
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode({
      method = aws_api_gateway_method.get.id
      integ  = aws_api_gateway_integration.lambda.id
      res    = aws_api_gateway_resource.user_access.id
      pol    = aws_api_gateway_rest_api_policy.this.id
    }))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "stage" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.stage_name
}
