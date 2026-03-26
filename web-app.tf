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
