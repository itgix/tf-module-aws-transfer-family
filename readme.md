The Terraform module is used by the ITGix AWS Landing Zone - https://itgix.com/itgix-landing-zone/

# AWS Transfer Family Terraform Module

This module deploys an AWS Transfer Family SFTP server with a VPC endpoint, S3 backend storage, IAM roles, CloudWatch logging, and optional web application with S3 Access Grants integration via IAM Identity Center.

Part of the [ITGix AWS Landing Zone](https://itgix.com/itgix-landing-zone/).

## Resources Created

- AWS Transfer Family SFTP server (VPC endpoint with Elastic IPs)
- S3 bucket (versioned, encrypted, public access blocked)
- SFTP users with SSH key authentication and scoped session policies
- IAM roles and policies for SFTP and (optionally) the web app
- CloudWatch log group with structured logging
- *(Optional)* Transfer Family Web App with Identity Center integration
- *(Optional)* S3 Access Grants instance and per-user/group grants

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.5.0 |
| AWS provider | >= 5.70.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `name_prefix` | Prefix for resource names | `string` | — | yes |
| `aws_account_id` | AWS account ID | `string` | — | yes |
| `aws_region` | AWS region | `string` | — | yes |
| `vpc_id` | VPC ID for the SFTP server endpoint | `string` | — | yes |
| `subnet_ids` | Subnet IDs for the SFTP server VPC endpoint | `list(string)` | — | yes |
| `eip_allocation_ids` | Elastic IP allocation IDs for the SFTP server VPC endpoint | `list(string)` | — | yes |
| `s3_bucket_name` | Name of the S3 bucket for SFTP storage | `string` | — | yes |
| `security_group_ids` | Security group IDs for the SFTP server VPC endpoint | `list(string)` | `[]` | no |
| `sftp_security_policy` | Security policy for the SFTP server | `string` | `"TransferSecurityPolicy-FIPS-2024-01"` | no |
| `pre_authentication_login_banner` | Login banner displayed before authentication | `string` | `""` | no |
| `logging_retention_days` | CloudWatch log group retention in days | `number` | `365` | no |
| `sftp_users` | Map of SFTP users with SSH keys and optional home directory override | `map(object({ssh_public_keys=list(string), home_directory=optional(string)}))` | `{}` | no |
| `enable_web_app` | Enable the Transfer Family Web App, S3 Access Grants, and associated IAM role | `bool` | `false` | no |
| `identity_center_instance_arn` | ARN of the IAM Identity Center instance (required when `enable_web_app = true`) | `string` | `""` | no |
| `web_app_units` | Number of provisioned web app units (concurrent connections) | `number` | `1` | no |
| `access_grants` | Map of S3 Access Grants for Identity Center users/groups | `map(object({grantee_type=string, grantee_identifier=string, permission=string, s3_prefix=string}))` | `{}` | no |
| `tags` | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `sftp_server_id` | Transfer Family SFTP server ID |
| `sftp_server_endpoint` | SFTP server endpoint |
| `s3_bucket_name` | S3 bucket name |
| `s3_bucket_arn` | S3 bucket ARN |
| `sftp_role_arn` | IAM role ARN used by the SFTP server |
| `web_app_id` | Transfer Family Web App ID (null if web app disabled) |
| `web_app_endpoint` | Transfer Family Web App URL (null if web app disabled) |
| `access_grants_instance_arn` | S3 Access Grants instance ARN (null if web app disabled) |

## Usage Example

```hcl
module "transfer_family" {
  source = "path/to/tf-module-aws-transfer-family"

  name_prefix    = "myproject"
  aws_account_id = "123456789012"
  aws_region     = "eu-west-1"

  vpc_id             = "vpc-0abc1234def567890"
  subnet_ids         = ["subnet-aaa111", "subnet-bbb222"]
  eip_allocation_ids = ["eipalloc-aaa111", "eipalloc-bbb222"]
  security_group_ids = ["sg-0abc1234"]

  s3_bucket_name         = "myproject-sftp-storage"
  logging_retention_days = 90

  sftp_users = {
    alice = {
      ssh_public_keys = ["ssh-ed25519 AAAAC3Nza..."]
    }
    bob = {
      ssh_public_keys = ["ssh-rsa AAAAB3Nza..."]
      home_directory  = "/myproject-sftp-storage/shared/bob"
    }
  }

  # Optional: enable web app (integrated with Identity Center)
  enable_web_app               = true
  identity_center_instance_arn = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
  web_app_units                = 2

  access_grants = {
    alice_rw = {
      grantee_type       = "DIRECTORY_USER"
      grantee_identifier = "a1b2c3d4-5678-90ab-cdef-111111111111" // ID of the user from Identity Center
      permission         = "READWRITE"
      s3_prefix          = "alice/*"
    }
    analysts_ro = {
      grantee_type       = "DIRECTORY_GROUP"
      grantee_identifier = "a1b2c3d4-5678-90ab-cdef-222222222222" // ID of the user from Identity Center
      permission         = "READ"
      s3_prefix          = "reports/*"
    }
  }

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```
