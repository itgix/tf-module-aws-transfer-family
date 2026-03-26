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

###############################################################################
# CloudWatch Log Group
###############################################################################
resource "aws_cloudwatch_log_group" "sftp" {
  name              = "/aws/transfer/${var.name_prefix}-sftp"
  retention_in_days = var.logging_retention_days
  tags              = var.tags
}

###############################################################################
# IAM Role - SFTP (Transfer + Access Grants + Logging)
###############################################################################
data "aws_iam_policy_document" "sftp_assume" {
  statement {
    sid     = "AllowTransferAndAccessGrants"
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:SetContext"]
    principals {
      type        = "Service"
      identifiers = ["transfer.amazonaws.com", "access-grants.s3.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.aws_account_id]
    }
  }
}

resource "aws_iam_role" "sftp" {
  name               = "${var.name_prefix}-transfer-sftp"
  assume_role_policy = data.aws_iam_policy_document.sftp_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "sftp_s3" {
  statement {
    sid       = "ListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.this.arn]
  }
  statement {
    sid    = "ObjectAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObjectVersion",
    ]
    resources = ["${aws_s3_bucket.this.arn}/*"]
  }
}

resource "aws_iam_role_policy" "sftp_s3" {
  name   = "s3-access"
  role   = aws_iam_role.sftp.id
  policy = data.aws_iam_policy_document.sftp_s3.json
}

data "aws_iam_policy_document" "sftp_logging" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:CreateLogGroup",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.sftp.arn}:*"]
  }
}

resource "aws_iam_role_policy" "sftp_logging" {
  name   = "cloudwatch-logging"
  role   = aws_iam_role.sftp.id
  policy = data.aws_iam_policy_document.sftp_logging.json
}

###############################################################################
# SFTP Server
###############################################################################
resource "aws_transfer_server" "sftp" {
  protocols              = ["SFTP"]
  identity_provider_type = "SERVICE_MANAGED"
  domain                 = "S3"
  endpoint_type          = "VPC"
  security_policy_name   = var.sftp_security_policy
  logging_role           = aws_iam_role.sftp.arn

  structured_log_destinations = [
    "${aws_cloudwatch_log_group.sftp.arn}:*"
  ]

  s3_storage_options {
    directory_listing_optimization = "ENABLED"
  }

  endpoint_details {
    vpc_id                 = var.vpc_id
    subnet_ids             = var.subnet_ids
    address_allocation_ids = var.eip_allocation_ids
    security_group_ids     = var.security_group_ids
  }

  protocol_details {
    passive_ip                  = "AUTO"
    set_stat_option             = "ENABLE_NO_OP"
    tls_session_resumption_mode = "ENFORCED"
  }

  pre_authentication_login_banner = var.pre_authentication_login_banner != "" ? var.pre_authentication_login_banner : null

  tags = var.tags
}

###############################################################################
# SFTP Users
###############################################################################
locals {
  user_ssh_keys = flatten([
    for user, config in var.sftp_users : [
      for idx, key in config.ssh_public_keys : {
        user = user
        idx  = idx
        key  = key
      }
    ]
  ])
}

data "aws_iam_policy_document" "sftp_user_session" {
  statement {
    sid       = "AllowListingOfUserFolder"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::$${transfer:HomeBucket}"]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["$${transfer:HomeFolder}/*", "$${transfer:HomeFolder}"]
    }
  }
  statement {
    sid    = "HomeDirObjectAccess"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:GetObjectVersion",
    ]
    resources = ["arn:aws:s3:::$${transfer:HomeDirectory}/*"]
  }
}

resource "aws_transfer_user" "this" {
  for_each = var.sftp_users

  server_id      = aws_transfer_server.sftp.id
  user_name      = each.key
  role           = aws_iam_role.sftp.arn
  home_directory = each.value.home_directory != null ? each.value.home_directory : "/${var.s3_bucket_name}/${each.key}"
  policy         = data.aws_iam_policy_document.sftp_user_session.json
  tags           = var.tags
}

resource "aws_transfer_ssh_key" "this" {
  for_each = { for item in local.user_ssh_keys : "${item.user}-${item.idx}" => item }

  server_id = aws_transfer_server.sftp.id
  user_name = each.value.user
  body      = each.value.key

  depends_on = [aws_transfer_user.this]
}

resource "aws_s3_object" "user_home_dirs" {
  for_each = var.sftp_users

  bucket  = aws_s3_bucket.this.id
  key     = "${each.key}/"
  content = ""
}

###############################################################################
# IAM Role - Web App Identity Bearer (only when web app enabled)
###############################################################################
data "aws_iam_policy_document" "web_app_assume" {
  count = var.enable_web_app ? 1 : 0

  statement {
    sid     = "AllowTransferAndAccessGrants"
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:SetContext"]
    principals {
      type        = "Service"
      identifiers = ["transfer.amazonaws.com", "access-grants.s3.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.aws_account_id]
    }
  }
}

resource "aws_iam_role" "web_app" {
  count = var.enable_web_app ? 1 : 0

  name               = "${var.name_prefix}-transfer-webapp-identity-bearer"
  assume_role_policy = data.aws_iam_policy_document.web_app_assume[0].json
  tags               = var.tags
}

data "aws_iam_policy_document" "web_app_access_grants" {
  count = var.enable_web_app ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["s3:GetDataAccess", "s3:ListCallerAccessGrants"]
    resources = [
      "arn:aws:s3:${var.aws_region}:${var.aws_account_id}:access-grants/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "s3:ResourceAccount"
      values   = [var.aws_account_id]
    }
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:ListAccessGrantsInstances"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "s3:ResourceAccount"
      values   = [var.aws_account_id]
    }
  }
}

resource "aws_iam_role_policy" "web_app_access_grants" {
  count = var.enable_web_app ? 1 : 0

  name   = "access-grants"
  role   = aws_iam_role.web_app[0].id
  policy = data.aws_iam_policy_document.web_app_access_grants[0].json
}

data "aws_iam_policy_document" "web_app_s3" {
  count = var.enable_web_app ? 1 : 0

  statement {
    sid       = "ListAllBuckets"
    effect    = "Allow"
    actions   = ["s3:ListAllMyBuckets"]
    resources = ["*"]
  }
  statement {
    sid       = "ListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.this.arn]
  }
  statement {
    sid       = "GetObject"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]
  }
}

resource "aws_iam_role_policy" "web_app_s3" {
  count = var.enable_web_app ? 1 : 0

  name   = "s3-read-access"
  role   = aws_iam_role.web_app[0].id
  policy = data.aws_iam_policy_document.web_app_s3[0].json
}

###############################################################################
# Transfer Family Web App (only when web app enabled)
###############################################################################
resource "aws_transfer_web_app" "this" {
  count = var.enable_web_app ? 1 : 0

  identity_provider_details {
    identity_center_config {
      instance_arn = var.identity_center_instance_arn
      role         = aws_iam_role.web_app[0].arn
    }
  }

  web_app_units {
    provisioned = var.web_app_units
  }

  tags = var.tags
}

###############################################################################
# S3 Access Grants (only when web app enabled)
###############################################################################
resource "aws_s3control_access_grants_instance" "this" {
  count = var.enable_web_app ? 1 : 0

  identity_center_arn = var.identity_center_instance_arn
  tags                = var.tags
}

resource "aws_s3control_access_grants_location" "default" {
  count = var.enable_web_app ? 1 : 0

  depends_on = [aws_s3control_access_grants_instance.this]

  iam_role_arn   = aws_iam_role.sftp.arn
  location_scope = "s3://"
  tags           = var.tags
}

resource "aws_s3control_access_grant" "this" {
  for_each = var.enable_web_app ? var.access_grants : {}

  access_grants_location_id = aws_s3control_access_grants_location.default[0].access_grants_location_id
  permission                = each.value.permission

  access_grants_location_configuration {
    s3_sub_prefix = "${var.s3_bucket_name}/${each.value.s3_prefix}"
  }

  grantee {
    grantee_type       = each.value.grantee_type
    grantee_identifier = each.value.grantee_identifier
  }

  tags = var.tags
}
