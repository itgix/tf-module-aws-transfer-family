output "sftp_server_id" {
  description = "Transfer Family SFTP server ID"
  value       = aws_transfer_server.sftp.id
}

output "sftp_server_endpoint" {
  description = "SFTP server endpoint"
  value       = aws_transfer_server.sftp.endpoint
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
