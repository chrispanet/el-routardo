# Import déclaratif (Terraform >= 1.5) des ressources déjà en production.
# Les identifiants viennent de terraform.tfvars (scripts/discover.sh).
# Une fois le premier apply réussi, ces blocs peuvent être supprimés.

import {
  to = aws_s3_bucket.site
  id = var.site_bucket_name
}

import {
  to = aws_s3_bucket_public_access_block.site
  id = var.site_bucket_name
}

import {
  to = aws_s3_bucket_ownership_controls.site
  id = var.site_bucket_name
}

import {
  to = aws_s3_bucket_server_side_encryption_configuration.site
  id = var.site_bucket_name
}

import {
  to = aws_s3_bucket_policy.site
  id = var.site_bucket_name
}

import {
  to = aws_cloudfront_distribution.site
  id = var.cloudfront_distribution_id
}

# L'OAC n'est importé que s'il existe déjà (sinon il est créé).
import {
  for_each = var.cloudfront_oac_id != "" ? toset([var.cloudfront_oac_id]) : toset([])
  to       = aws_cloudfront_origin_access_control.site
  id       = each.value
}

import {
  to = aws_lambda_function.suggestions
  id = var.lambda_function_name
}

import {
  to = aws_lambda_function_url.suggestions
  id = var.lambda_function_name
}

import {
  provider = aws.eu-west-1
  to       = aws_s3_bucket.suggestions
  id       = var.suggestions_bucket_name
}

import {
  to = aws_sns_topic.suggestions
  id = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.sns_topic_name}"
}
