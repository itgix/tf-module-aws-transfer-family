variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the SFTP server endpoint"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the SFTP server VPC endpoint"
  type        = list(string)
}

variable "allowed_ips" {
  description = "Map of descriptive name to IP address allowed to connect on port 22 (e.g. {\"office\" = \"203.0.113.10\"})"
  type        = map(string)
  default     = {}
}

variable "sftp_security_policy" {
  description = "Security policy for the SFTP server"
  type        = string
  default     = "TransferSecurityPolicy-2024-01"
}

variable "pre_authentication_login_banner" {
  description = "Login banner displayed before authentication"
  type        = string
  default     = ""
}

variable "logging_retention_days" {
  description = "CloudWatch log group retention in days"
  type        = number
  default     = 365
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for SFTP storage"
  type        = string
}

variable "sftp_users" {
  description = "Map of SFTP users with SSH keys and optional home directory override"
  type = map(object({
    ssh_public_keys = list(string)
    home_directory  = optional(string)
  }))
  default = {}
}

variable "enable_web_app" {
  description = "Enable the Transfer Family Web App, S3 Access Grants, and associated IAM role"
  type        = bool
  default     = false
}

variable "identity_center_instance_arn" {
  description = "ARN of the IAM Identity Center instance (required when enable_web_app = true)"
  type        = string
  default     = ""
}

variable "web_app_units" {
  description = "Number of provisioned web app units (concurrent connections)"
  type        = number
  default     = 1
}

variable "access_grants" {
  description = "Map of S3 Access Grants for Identity Center users/groups. The map key is used as the S3 home directory name."
  type = map(object({
    grantee_type       = string # DIRECTORY_USER or DIRECTORY_GROUP
    grantee_identifier = string # Identity Center user/group ID
    permission         = string # READ, WRITE, or READWRITE
    s3_prefix          = optional(string) # Override auto-generated prefix (default: "<key>/*")
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
