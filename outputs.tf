output "sftp_server_id" {
  description = "Transfer Family SFTP server ID"
  value       = aws_transfer_server.sftp.id
}

output "sftp_server_endpoint" {
  description = "SFTP server endpoint"
  value       = aws_transfer_server.sftp.endpoint
}

output "sftp_eip_public_ips" {
  description = "Public IP addresses allocated to the SFTP server"
  value       = aws_eip.sftp[*].public_ip
}

output "sftp_security_group_id" {
  description = "Security group ID attached to the SFTP server"
  value       = aws_security_group.sftp.id
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.this.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.this.arn
}

output "sftp_role_arn" {
  description = "IAM role ARN used by the SFTP server"
  value       = aws_iam_role.sftp.arn
}

output "web_app_id" {
  description = "Transfer Family Web App ID"
  value       = var.enable_web_app ? aws_transfer_web_app.this[0].web_app_id : null
}

output "web_app_endpoint" {
  description = "Transfer Family Web App URL"
  value       = var.enable_web_app ? aws_transfer_web_app.this[0].access_endpoint : null
}

output "access_grants_instance_arn" {
  description = "S3 Access Grants instance ARN"
  value       = var.enable_web_app ? aws_s3control_access_grants_instance.this[0].access_grants_instance_arn : null
}

output "sftp_custom_hostname_dns_target" {
  description = "SFTP server endpoint to use as CNAME target for the custom SFTP hostname"
  value       = try(var.custom_domain.sftp_hostname, null) != null ? aws_transfer_server.sftp.endpoint : null
}

output "web_app_cloudfront_domain" {
  description = "CloudFront domain name to use as alias/CNAME target for the custom web app hostname"
  value       = var.enable_web_app && try(var.custom_domain.web_app_hostname, null) != null ? aws_cloudfront_distribution.web_app[0].domain_name : null
}
