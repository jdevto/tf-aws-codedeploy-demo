output "aws_region" {
  description = "The AWS region where resources are deployed"
  value       = data.aws_region.this.name
}

# ----------------------------------------
# VPC Outputs
# ----------------------------------------

output "vpc_id" {
  description = "The ID of the created VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

# ----------------------------------------
# S3 Outputs
# ----------------------------------------

output "s3_bucket_name" {
  description = "The name of the created S3 bucket"
  value       = module.s3_bucket.bucket_id
}

output "s3_bucket_arn" {
  description = "The ARN of the created S3 bucket"
  value       = module.s3_bucket.bucket_arn
}

# ----------------------------------------
# EC2 Outputs
# ----------------------------------------

output "ec2_instance_ids" {
  description = "List of IDs of the deployed EC2 instances"
  value       = aws_instance.this[*].id
}

output "ec2_private_ips" {
  description = "List of private IPs of the deployed EC2 instances"
  value       = aws_instance.this[*].private_ip
}

output "ec2_instance_profile" {
  description = "The IAM instance profile associated with EC2"
  value       = aws_iam_instance_profile.ec2_codedeploy.name
}

# ----------------------------------------
# IAM Outputs
# ----------------------------------------

output "iam_role_codedeploy" {
  description = "The IAM role ARN for CodeDeploy"
  value       = aws_iam_role.codedeploy.arn
}

output "iam_role_codepipeline" {
  description = "The IAM role ARN for CodePipeline"
  value       = aws_iam_role.codepipeline.arn
}

# ----------------------------------------
# CodeDeploy Outputs
# ----------------------------------------

output "codedeploy_app_name" {
  description = "The name of the CodeDeploy application"
  value       = aws_codedeploy_app.this.name
}

output "codedeploy_deployment_group" {
  description = "The name of the CodeDeploy deployment group"
  value       = aws_codedeploy_deployment_group.this.deployment_group_name
}

# ----------------------------------------
# CodePipeline Outputs
# ----------------------------------------

output "codepipeline_name" {
  description = "The name of the created CodePipeline"
  value       = aws_codepipeline.codepipeline.name
}
