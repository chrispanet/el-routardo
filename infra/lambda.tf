# Lambda "suggestions" existante (Python 3.12) + Function URL publique + dépendances, importées.
# Elle enregistre chaque suggestion dans le bucket "elroutardo" (préfixe suggestions/)
# et publie une notification sur le topic SNS "elroutardo-suggestions".

locals {
  # Rôle d'exécution existant, référencé mais non géré (ses politiques restent hors Terraform).
  lambda_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.lambda_role_name}"
}

resource "aws_s3_bucket" "suggestions" {
  provider = aws.eu-west-1
  bucket   = var.suggestions_bucket_name
}

resource "aws_sns_topic" "suggestions" {
  name = var.sns_topic_name
  # Les abonnements (e-mail) ne sont pas gérés ici.
}

data "archive_file" "suggestions" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/suggestions/src"
  output_path = "${path.module}/../lambda/suggestions/build.zip"
}

resource "aws_lambda_function" "suggestions" {
  function_name = var.lambda_function_name
  role          = local.lambda_role_arn
  runtime       = var.lambda_runtime
  handler       = var.lambda_handler
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size
  architectures = [var.lambda_architecture]

  filename         = data.archive_file.suggestions.output_path
  source_code_hash = data.archive_file.suggestions.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME   = aws_s3_bucket.suggestions.bucket
      SNS_TOPIC_ARN = aws_sns_topic.suggestions.arn
    }
  }
}

resource "aws_lambda_function_url" "suggestions" {
  function_name      = aws_lambda_function.suggestions.function_name
  authorization_type = "NONE"
  invoke_mode        = "BUFFERED"

  cors {
    allow_credentials = false
    allow_origins     = ["*"]
    allow_methods     = ["POST"]
    allow_headers     = ["content-type"]
  }
}
