############################################
# Global Variables & Data Sources
############################################

locals {
  base_name = (
    var.suffix == "" ?
    var.repository_name :
    "${var.repository_name}-${var.suffix}"
  )
}

data "aws_region" "this" {}
data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

data "http" "my_public_ip" {
  url = "http://ifconfig.me/ip"
}

############################################
# VPC Configuration
############################################

module "vpc" {
  source             = "tfstack/vpc/aws"
  region             = data.aws_region.this.name
  vpc_name           = local.base_name
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = data.aws_availability_zones.available.names

  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  eic_subnet               = "private"
  jumphost_instance_create = false
  create_igw               = true
  ngw_type                 = "single"

  tags = merge(var.tags, { Name = local.base_name })
}

############################################
# S3 Configuration
############################################

module "s3_bucket" {
  source = "tfstack/s3/aws"

  bucket_name   = local.base_name
  bucket_suffix = var.suffix
  force_destroy = true
  tags          = merge(var.tags, { Name = local.base_name })

  enable_versioning = true
  logging_enabled   = true
}

resource "aws_s3_object" "this" {
  bucket = module.s3_bucket.bucket_id
  key    = var.app_name
  source = var.app_source_path
}

############################################
# IAM Roles & Policies
############################################

## EC2 IAM Role & Policies
resource "aws_iam_role" "ec2_codedeploy" {
  name = "${local.base_name}-ec2-codedeploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowEC2AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, { Name = "${local.base_name}-ec2-codedeploy" })
}

resource "aws_iam_policy" "ec2_codedeploy" {
  name        = "${local.base_name}-ec2-codedeploy"
  description = "IAM policy for EC2 instances to interact with CodeDeploy and read deployment artifacts from S3."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "CodeDeployAccess"
        Effect = "Allow"
        Action = [
          "codedeploy:PutHostCommandAcknowledgement",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision",
          "codedeploy:PollHostCommand"
        ],
        Resource = [
          aws_codedeploy_app.this.arn,
          aws_codedeploy_deployment_group.this.arn
        ]
      },
      {
        Sid    = "S3DeploymentReadAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ],
        Resource = "${module.s3_bucket.bucket_arn}/*"
      }
    ]
  })

  tags = merge(var.tags, { Name = "${local.base_name}-ec2-codedeploy" })
}

resource "aws_iam_policy_attachment" "ec2_codedeploy" {
  name = "${local.base_name}-ec2-codedeploy"
  roles = [
    aws_iam_role.ec2_codedeploy.name
  ]
  policy_arn = aws_iam_policy.ec2_codedeploy.arn
}

resource "aws_iam_policy_attachment" "ec2_ssm_core" {
  name = "${local.base_name}-ec2-ssm-core"
  roles = [
    aws_iam_role.ec2_codedeploy.name
  ]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_codedeploy" {
  name = "${local.base_name}-ec2-codedeploy"
  role = aws_iam_role.ec2_codedeploy.name

  tags = merge(var.tags, { Name = "${local.base_name}-ec2-codedeploy" })
}

## CodeDeploy IAM Role
resource "aws_iam_role" "codedeploy" {
  name = "${local.base_name}-codedeploy"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

## CodePipeline IAM Role

resource "aws_iam_role" "codepipeline" {
  name = "${local.base_name}-codepipeline"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = merge(var.tags, { Name = "${local.base_name}-codepipeline" })
}

resource "aws_iam_policy" "codepipeline" {
  name        = "${local.base_name}-codepipeline"
  description = "Allows CodePipeline to access S3 and create deployments in CodeDeploy."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject"
        ]
        Resource = [
          module.s3_bucket.bucket_arn,
          "${module.s3_bucket.bucket_arn}/*"
        ]
      },
      {
        Sid    = "CodeDeployAccess"
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:GetApplicationRevision",
          "codedeploy:RegisterApplicationRevision"
        ]
        Resource = [
          aws_codedeploy_app.this.arn,
          aws_codedeploy_deployment_group.this.arn
        ]
      },
      {
        Sid    = "CodeDeployConfigAccess"
        Effect = "Allow"
        Action = [
          "codedeploy:GetDeploymentConfig"
        ]
        Resource = [
          aws_codedeploy_deployment_group.this.arn,
          "arn:aws:codedeploy:${data.aws_region.this.name}:${data.aws_caller_identity.current.account_id}:deploymentconfig:*"
        ]
      }
    ]
  })

  tags = merge(var.tags, { Name = "${local.base_name}-codepipeline" })
}

resource "aws_iam_role_policy_attachment" "codepipeline" {
  policy_arn = aws_iam_policy.codepipeline.arn
  role       = aws_iam_role.codepipeline.name
}

############################################
# EC2 Configuration
############################################

data "aws_ami" "amzn2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }
}

resource "aws_instance" "this" {
  count = min(var.deployment_instance_count, length(module.vpc.private_subnet_ids))

  ami                  = data.aws_ami.amzn2023.id
  instance_type        = var.deployment_instance_type
  iam_instance_profile = aws_iam_instance_profile.ec2_codedeploy.name
  subnet_id            = module.vpc.private_subnet_ids[count.index % length(module.vpc.private_subnet_ids)]

  vpc_security_group_ids = [
    module.vpc.eic_security_group_id
  ]

  user_data = file("${path.module}/external/cloud-init.yaml")

  tags = merge(var.tags, { Name = "${local.base_name}-${count.index}" })
}

############################################
# CodeDeploy Configuration
############################################

resource "aws_codedeploy_app" "this" {
  name             = local.base_name
  compute_platform = "Server"

  tags = merge(var.tags, { Name = local.base_name })
}

resource "aws_codedeploy_deployment_group" "this" {
  app_name              = aws_codedeploy_app.this.name
  deployment_group_name = local.base_name
  service_role_arn      = aws_iam_role.codedeploy.arn

  deployment_config_name = "CodeDeployDefault.OneAtATime"

  deployment_style {
    deployment_type   = "IN_PLACE"
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
  }

  ec2_tag_set {
    dynamic "ec2_tag_filter" {
      for_each = aws_instance.this[*].tags.Name
      content {
        key   = "Name"
        type  = "KEY_AND_VALUE"
        value = ec2_tag_filter.value
      }
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  tags = merge(var.tags, { Name = local.base_name })
}

############################################
# CodePipeline Configuration
############################################

resource "aws_codepipeline" "codepipeline" {
  name          = local.base_name
  role_arn      = aws_iam_role.codepipeline.arn
  pipeline_type = "V1"

  artifact_store {
    location = module.s3_bucket.bucket_id
    type     = "S3"
  }

  stage {
    name = "source"

    action {
      name             = "s3-source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["source-output"]

      configuration = {
        S3Bucket             = module.s3_bucket.bucket_id
        S3ObjectKey          = var.app_name
        PollForSourceChanges = "true"
      }
    }
  }

  stage {
    name = "deploy"

    action {
      name            = "deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["source-output"]

      configuration = {
        ApplicationName     = aws_codedeploy_app.this.name
        DeploymentGroupName = aws_codedeploy_deployment_group.this.deployment_group_name
      }
    }
  }

  depends_on = [
    aws_s3_object.this
  ]

  tags = merge(var.tags, { Name = local.base_name })
}
