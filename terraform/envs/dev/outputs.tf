output "rest_api_id" { value = module.api.rest_api_id }
output "invoke_url" { value = module.api.invoke_url }
output "stage_name" { value = module.api.stage_name }
output "lambda_name" { value = module.lambda.function_name }
output "dynamodb_table" { value = module.dynamodb.table_name }
output "user_role_arn" { value = module.iam.user_role_arn }