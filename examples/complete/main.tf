resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

module "aws_codedeploy" {
  source = "../.."

  repository_name = "demo-test"
  app_name        = "SampleApp_Linux.zip"
  suffix          = random_string.suffix.result
  app_source_path = "${path.module}/external/SampleApp_Linux.zip"

  tags = {
    Environment = "dev"
    Project     = "example-project"
  }
}

# Outputs
output "all_module_outputs" {
  description = "All outputs from the Code Deploy module"
  value       = module.aws_codedeploy
}
