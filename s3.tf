###############################################################################
# S3 Bucket
###############################################################################
resource "aws_s3_bucket" "this" {
  bucket = var.s3_bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "user_home_dirs" {
  for_each = var.sftp_users

  bucket  = aws_s3_bucket.this.id
  key     = "${each.key}/"
  content = ""
}

locals {
  users_with_notifications = {
    for user_key, user in var.sftp_users :
    user_key => user.event_notification
    if user.event_notification != null
  }

  lambda_notifications = {
    for user_key, notif in local.users_with_notifications :
    user_key => notif
    if notif.destination_type == "lambda"
  }

  sqs_notifications = {
    for user_key, notif in local.users_with_notifications :
    user_key => notif
    if notif.destination_type == "sqs"
  }

  sns_notifications = {
    for user_key, notif in local.users_with_notifications :
    user_key => notif
    if notif.destination_type == "sns"
  }

  has_any_notification = length(local.users_with_notifications) > 0
}

resource "aws_s3_bucket_notification" "this" {
  count  = local.has_any_notification ? 1 : 0
  bucket = aws_s3_bucket.this.id

  dynamic "lambda_function" {
    for_each = local.lambda_notifications
    content {
      lambda_function_arn = lambda_function.value.destination_arn
      events              = lambda_function.value.events
      filter_prefix       = lambda_function.value.filter_prefix
      filter_suffix       = lambda_function.value.filter_suffix
    }
  }

  dynamic "queue" {
    for_each = local.sqs_notifications
    content {
      queue_arn     = queue.value.destination_arn
      events        = queue.value.events
      filter_prefix = queue.value.filter_prefix
      filter_suffix = queue.value.filter_suffix
    }
  }

  dynamic "topic" {
    for_each = local.sns_notifications
    content {
      topic_arn     = topic.value.destination_arn
      events        = topic.value.events
      filter_prefix = topic.value.filter_prefix
      filter_suffix = topic.value.filter_suffix
    }
  }
}
