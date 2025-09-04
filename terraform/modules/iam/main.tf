terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_partition" "cur" {}

data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "user_role" {
  name               = var.user_role_name
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

resource "aws_iam_policy" "p1" {
  name   = var.policy1_name
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:ListAllMyBuckets"], Resource = "*" },
      { Effect = "Allow", Action = ["s3:GetObject"],        Resource = "arn:${data.aws_partition.cur.partition}:s3:::*/*" }
    ]
  })
}
resource "aws_iam_policy" "p2" {
  name   = var.policy2_name
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:ListAllMyBuckets"], Resource = "*" },
      { Effect = "Allow", Action = ["s3:ListBucket"],       Resource = "arn:${data.aws_partition.cur.partition}:s3:::*" }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_p1" {
  role       = aws_iam_role.user_role.name
  policy_arn = aws_iam_policy.p1.arn
}

resource "aws_iam_role_policy_attachment" "attach_p2" {
  role       = aws_iam_role.user_role.name
  policy_arn = aws_iam_policy.p2.arn
}

data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = var.lambda_role_name
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

resource "aws_iam_policy" "lambda_inline" {
  name = "${var.lambda_role_name}-inline"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      # DynamoDB permissions on the table
      { Effect = "Allow", Action = ["dynamodb:GetItem","dynamodb:UpdateItem","dynamodb:Scan"], Resource = var.dynamodb_table_arn },
      # IAM list/detach limited to the target user role
      { Effect = "Allow", Action = ["iam:ListAttachedRolePolicies","iam:DetachRolePolicy"], Resource = aws_iam_role.user_role.arn },
      # Logs
      { Effect = "Allow", Action = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"], Resource = "*" }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach_inline" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_inline.arn
}
