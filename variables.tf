# ----------------------------------------
# General Configuration
# ----------------------------------------

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# ----------------------------------------
# Naming & Resource Configuration
# ----------------------------------------

variable "repository_name" {
  description = "Base name for the repository and associated resources"
  type        = string
}

variable "suffix" {
  description = "Optional suffix for resource names"
  type        = string
  default     = ""
}

# ----------------------------------------
# Application Configuration
# ----------------------------------------

variable "app_name" {
  description = "The name of the CodeDeploy application"
  type        = string
}

variable "app_source_path" {
  description = "Path to the local directory containing the application source for CodeDeploy"
  type        = string
}

# ----------------------------------------
# Deployment Configuration
# ----------------------------------------

variable "deployment_instance_count" {
  description = "Number of EC2 instances to be deployed and used as CodeDeploy targets"
  type        = number
  default     = 1
}

variable "deployment_instance_type" {
  description = "EC2 instance type for deployment targets"
  type        = string
  default     = "t3.micro"
}
