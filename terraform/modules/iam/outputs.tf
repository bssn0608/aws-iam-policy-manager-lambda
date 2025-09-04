output "user_role_arn" {
  value = aws_iam_role.user_role.arn
}

output "policy1_arn" {
  value = aws_iam_policy.p1.arn
}

output "policy2_arn" {
  value = aws_iam_policy.p2.arn
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda_role.arn
}
