# --- Required ---

region          = "us-east-2"
lambda_zip_path = "./files/lambda.zip"

# VPC + subnets (all from your output)
vpc_id     = "vpc-0d5df60d200ad4bc4"
subnet_ids = [
  "subnet-0d6fffe2d57db644b",  # us-east-2b
  "subnet-0570342b34d4a3386",  # us-east-2a
  "subnet-0383d19d0b50042fe"   # us-east-2c
]


# --- Do NOT set allowed_vpce_ids here ---
# The module wires: allowed_vpce_ids = [aws_vpc_endpoint.apigw.id]
# so you must NOT put allowed_vpce_ids in tfvars.

# Optional naming overrides
# user_role_name = "test-userid1-role"
# policy1_name = "test-policy1"
# policy2_name = "test-policy2"
# lambda_role_name = "test-user-access-lambda"
# function_name = "test-user-access"
# api_name = "iam-policy-manager-api"
# stage_name = "v1"