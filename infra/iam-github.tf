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
  github_repo_with_ids = "${split("/", var.github_repo)[0]}@${var.github_owner_id}/${split("/", var.github_repo)[1]}@${var.github_repo_id}"
  oidc_provider_arn    = var.github_oidc_provider_arn != "" ? var.github_oidc_provider_arn : aws_iam_openid_connect_provider.github[0].arn
  tf_state_bucket      = "el-routardo-tfstate"
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
    # GitHub émet le sub sous la forme "repo:owner@<owner_id>/repo@<repo_id>:..."
    # (constaté dans CloudTrail le 2026-09-15). On accepte les deux formes.
    #
    # Un job rattaché à un environnement GitHub voit son sub se terminer par
    # ":environment:<nom>" au lieu de ":ref:refs/heads/main". Le job apply du
    # workflow Terraform déclare "environment: production", d'où un sub
    # "repo:chrispanet@162978253/el-routardo@1371595020:environment:production"
    # refusé jusqu'ici (CloudTrail eu-west-3, 2026-09-18, 24 AccessDenied).
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repo}:ref:refs/heads/main",
        "repo:${var.github_repo}:pull_request",
        "repo:${var.github_repo}:environment:${var.github_environment}",
        "repo:${local.github_repo_with_ids}:ref:refs/heads/main",
        "repo:${local.github_repo_with_ids}:pull_request",
        "repo:${local.github_repo_with_ids}:environment:${var.github_environment}",
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
  #
  # Lecture en s3:Get* plutôt qu'en liste d'actions : rafraîchir un
  # aws_s3_bucket lit une douzaine de sous-configurations, dont certaines
  # portent un nom d'action IAM qui ne contient pas "Bucket" et échappaient
  # donc à s3:GetBucket*. Le plan du run 35346847811 est mort en 403 sur
  # s3:GetAccelerateConfiguration. L'étoile reste bornée à ce seul bucket ;
  # l'écriture, elle, reste énumérée.
  statement {
    sid = "SiteBucket"
    actions = [
      "s3:Get*", "s3:ListBucket",
      "s3:PutObject", "s3:DeleteObject", "s3:PutBucket*", "s3:PutEncryptionConfiguration",
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
    # Bornée à l'ARN du bucket, sans "/*" : configurations seulement,
    # aucun accès aux suggestions elles-mêmes.
    sid       = "SuggestionsBucketRead"
    actions   = ["s3:Get*", "s3:ListBucket"]
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

# Droits du nom de domaine, dans une policy séparée.
#
# Elle ne référence aucune ressource de ce dépôt (uniquement le rôle et
# l'identifiant de la zone). C'est ce qui permet aux ressources de dns.tf de
# dépendre d'elle sans créer de cycle : la policy principale, elle, référence
# l'ARN de la distribution CloudFront, que dns.tf modifie à son tour.
data "aws_iam_policy_document" "gha_dns" {
  # Certificat ACM du nom de domaine (us-east-1, imposé par CloudFront).
  # RequestCertificate ne supporte pas le filtrage par ressource à la création.
  statement {
    sid = "Acm"
    actions = [
      "acm:RequestCertificate", "acm:DescribeCertificate", "acm:ListCertificates",
      "acm:AddTagsToCertificate", "acm:RemoveTagsFromCertificate", "acm:ListTagsForCertificate",
      "acm:DeleteCertificate", "acm:GetCertificate",
    ]
    resources = ["*"]
  }

  # Route 53 : validation du certificat et enregistrement du site.
  # L'écriture est limitée à la zone azean.com, le reste est en lecture seule.
  statement {
    sid       = "Route53Write"
    actions   = ["route53:ChangeResourceRecordSets", "route53:ListResourceRecordSets", "route53:GetHostedZone"]
    resources = ["arn:aws:route53:::hostedzone/${var.parent_hosted_zone_id}"]
  }
  statement {
    sid       = "Route53Read"
    actions   = ["route53:GetChange", "route53:ListHostedZones", "route53:ListHostedZonesByName"]
    resources = ["*"]
  }

  # Politique d'en-têtes de réponse CloudFront (X-Robots-Tag).
  statement {
    sid = "CloudFrontResponseHeaders"
    actions = [
      "cloudfront:CreateResponseHeadersPolicy", "cloudfront:GetResponseHeadersPolicy",
      "cloudfront:GetResponseHeadersPolicyConfig", "cloudfront:UpdateResponseHeadersPolicy",
      "cloudfront:DeleteResponseHeadersPolicy", "cloudfront:ListResponseHeadersPolicies",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "gha_dns" {
  name   = "el-routardo-gha-dns"
  role   = aws_iam_role.gha.id
  policy = data.aws_iam_policy_document.gha_dns.json
}
