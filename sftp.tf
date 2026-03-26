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
