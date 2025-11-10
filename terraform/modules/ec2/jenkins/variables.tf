variable "jenkins_ami_id" {
  description = "AMI ID for Jenkins controller"
  type        = string
}

variable "instance_type" {
  description = "Instance type for Jenkins controller"
  type        = string
  # No default - passed from root module
}

variable "volume_size" {
  description = "Root volume size in GB"
  type        = number
  # No default - passed from root module
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for Jenkins"
  type        = string
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile name for SSM"
  type        = string
}

variable "instance_name" {
  description = "Optional Name tag for the Jenkins instance"
  type        = string
  default     = "Jenkins Controller"
}