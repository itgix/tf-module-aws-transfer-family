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
