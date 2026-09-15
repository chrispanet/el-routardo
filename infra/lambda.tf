# Lambda "suggestions" existante + sa Function URL publique, importées.

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = var.lambda_role_name
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  lifecycle {
    # Les politiques attachées existantes (logs, SES...) ne sont pas déclarées : Terraform ne les touche pas.
    ignore_changes = [description, tags, tags_all]
  }
}

data "archive_file" "suggestions" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/suggestions/src"
  output_path = "${path.module}/../lambda/suggestions/build.zip"
}

resource "aws_lambda_function" "suggestions" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda.arn
  runtime       = var.lambda_runtime
  handler       = var.lambda_handler
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size
  architectures = [var.lambda_architecture]

  filename         = data.archive_file.suggestions.output_path
  source_code_hash = data.archive_file.suggestions.output_base64sha256

  lifecycle {
    # À RETIRER une fois le vrai code commité dans lambda/suggestions/src (make fetch-lambda).
    # Tant que ce bloc est là, Terraform ne touche ni au code ni aux variables d'environnement.
    ignore_changes = [filename, source_code_hash, environment, layers, description, tags, tags_all]
  }
}

resource "aws_lambda_function_url" "suggestions" {
  function_name      = aws_lambda_function.suggestions.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["POST"]
    allow_headers = ["content-type"]
    max_age       = 86400
  }
}
