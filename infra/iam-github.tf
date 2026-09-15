# Rôle assumé par GitHub Actions (OIDC) : déploiement du contenu et Terraform depuis le dépôt.

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.github_oidc_provider_arn == "" ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # Empreinte historique, AWS valide désormais les certificats GitHub sans s'y fier.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

locals {
  oidc_provider_arn = var.github_oidc_provider_arn != "" ? var.github_oidc_provider_arn : aws_iam_openid_connect_provider.github[0].arn
  tf_state_bucket   = "el-routardo-tfstate"
}

data "aws_iam_policy_document" "gha_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repo}:ref:refs/heads/main",
        "repo:${var.github_repo}:pull_request",
      ]
    }
  }
}

resource "aws_iam_role" "gha" {
  name               = "el-routardo-gha"
  description        = "GitHub Actions ${var.github_repo} : déploiement site + Terraform"
  assume_role_policy = data.aws_iam_policy_document.gha_trust.json
}

data "aws_iam_policy_document" "gha_permissions" {
  # Contenu du site
  statement {
    sid = "SiteBucket"
    actions = [
      "s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
      "s3:GetBucket*", "s3:PutBucket*", "s3:GetEncryptionConfiguration", "s3:PutEncryptionConfiguration",
    ]
    resources = [aws_s3_bucket.site.arn, "${aws_s3_bucket.site.arn}/*"]
  }

  # State Terraform
  statement {
    sid       = "TfState"
    actions   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${local.tf_state_bucket}", "arn:aws:s3:::${local.tf_state_bucket}/*"]
  }

  # CloudFront : invalidation + gestion de la distribution et de l'OAC
  statement {
    sid = "CloudFront"
    actions = [
      "cloudfront:CreateInvalidation", "cloudfront:GetInvalidation", "cloudfront:ListInvalidations",
      "cloudfront:GetDistribution", "cloudfront:GetDistributionConfig", "cloudfront:UpdateDistribution",
      "cloudfront:TagResource", "cloudfront:UntagResource", "cloudfront:ListTagsForResource",
    ]
    resources = [aws_cloudfront_distribution.site.arn]
  }
  statement {
    sid = "CloudFrontOac"
    actions = [
      "cloudfront:ListDistributions", "cloudfront:ListOriginAccessControls",
      "cloudfront:GetOriginAccessControl", "cloudfront:CreateOriginAccessControl",
      "cloudfront:UpdateOriginAccessControl", "cloudfront:DeleteOriginAccessControl",
      "cloudfront:ListCachePolicies", "cloudfront:GetCachePolicy",
    ]
    resources = ["*"]
  }

  # Lambda suggestions
  statement {
    sid = "Lambda"
    actions = [
      "lambda:GetFunction*", "lambda:ListFunctionUrlConfigs", "lambda:GetPolicy",
      "lambda:UpdateFunctionCode", "lambda:UpdateFunctionConfiguration", "lambda:TagResource", "lambda:UntagResource",
      "lambda:CreateFunctionUrlConfig", "lambda:UpdateFunctionUrlConfig", "lambda:DeleteFunctionUrlConfig",
      "lambda:AddPermission", "lambda:RemovePermission", "lambda:ListVersionsByFunction",
    ]
    resources = [aws_lambda_function.suggestions.arn]
  }

  # Dépendances de la Lambda (lecture / tags)
  statement {
    sid       = "SuggestionsBucketRead"
    actions   = ["s3:GetBucket*", "s3:ListBucket", "s3:GetEncryptionConfiguration"]
    resources = [aws_s3_bucket.suggestions.arn]
  }
  statement {
    sid       = "SnsTopic"
    actions   = ["sns:GetTopicAttributes", "sns:SetTopicAttributes", "sns:ListTagsForResource", "sns:TagResource", "sns:UntagResource"]
    resources = [aws_sns_topic.suggestions.arn]
  }

  # IAM : lecture des rôles gérés + passage du rôle Lambda
  statement {
    sid = "IamRead"
    actions = [
      "iam:GetRole", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:GetRolePolicy",
      "iam:ListInstanceProfilesForRole", "iam:GetOpenIDConnectProvider", "iam:GetPolicy", "iam:GetPolicyVersion",
    ]
    resources = ["*"]
  }
  statement {
    sid       = "IamManageOwnRole"
    actions   = ["iam:UpdateAssumeRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:TagRole", "iam:UntagRole"]
    resources = [aws_iam_role.gha.arn]
  }
  statement {
    sid       = "PassLambdaRole"
    actions   = ["iam:PassRole"]
    resources = [local.lambda_role_arn]
  }
}

resource "aws_iam_role_policy" "gha" {
  name   = "el-routardo-gha"
  role   = aws_iam_role.gha.id
  policy = data.aws_iam_policy_document.gha_permissions.json
}
