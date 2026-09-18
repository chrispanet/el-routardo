output "site_url" {
  value = "https://${var.site_domain}"
}

output "site_cloudfront_url" {
  description = "URL CloudFront d'origine, conservee et toujours fonctionnelle"
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "site_bucket" {
  value = aws_s3_bucket.site.bucket
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.site.id
}

output "suggestions_url" {
  value = aws_lambda_function_url.suggestions.function_url
}

output "gha_role_arn" {
  description = "À mettre dans la variable de dépôt GitHub AWS_ROLE_ARN"
  value       = aws_iam_role.gha.arn
}
