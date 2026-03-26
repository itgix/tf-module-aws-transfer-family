###############################################################################
# CloudWatch Log Group
###############################################################################
resource "aws_cloudwatch_log_group" "sftp" {
  name              = "/aws/transfer/${var.name_prefix}-sftp"
  retention_in_days = var.logging_retention_days
  tags              = var.tags
}
