###############################################################################
# Elastic IPs (one per subnet)
###############################################################################
resource "aws_eip" "sftp" {
  count  = length(var.subnet_ids)
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name_prefix}-sftp-${count.index}" })
}

###############################################################################
# Security Group
###############################################################################
resource "aws_security_group" "sftp" {
  name_prefix = "${var.name_prefix}-sftp-"
  description = "SFTP server access on port 22"
  vpc_id      = var.vpc_id
  tags        = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "sftp" {
  for_each = var.allowed_ips

  security_group_id = aws_security_group.sftp.id
  description       = each.key
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "${each.value}/32"
  tags              = var.tags
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
    address_allocation_ids = aws_eip.sftp[*].allocation_id
    security_group_ids     = [aws_security_group.sftp.id]
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
  for_each = var.sftp_users

  statement {
    sid       = "AllowListingOfUserFolder"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.s3_bucket_name}"]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${each.key}/*", "${each.key}"]
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
    resources = ["arn:aws:s3:::${var.s3_bucket_name}/${each.key}/*"]
  }
}

resource "aws_transfer_user" "this" {
  for_each = var.sftp_users

  server_id      = aws_transfer_server.sftp.id
  user_name      = each.key
  role           = aws_iam_role.sftp.arn
  home_directory = each.value.home_directory != null ? each.value.home_directory : "/${var.s3_bucket_name}/${each.key}"
  policy         = data.aws_iam_policy_document.sftp_user_session[each.key].json
  tags           = var.tags
}

resource "aws_transfer_ssh_key" "this" {
  for_each = { for item in local.user_ssh_keys : "${item.user}-${item.idx}" => item }

  server_id = aws_transfer_server.sftp.id
  user_name = each.value.user
  body      = each.value.key

  depends_on = [aws_transfer_user.this]
}
