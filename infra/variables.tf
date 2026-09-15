variable "aws_region" {
  description = "Région principale (Lambda, state)"
  type        = string
  default     = "eu-west-3"
}

variable "github_repo" {
  description = "Dépôt GitHub autorisé à assumer le rôle de déploiement (owner/repo)"
  type        = string
  default     = "chrispanet/el-routardo"
}

variable "github_owner_id" {
  description = "Identifiant numérique du compte GitHub propriétaire (claim sub)"
  type        = number
  default     = 162978253
}

variable "github_repo_id" {
  description = "Identifiant numérique du dépôt GitHub (claim sub)"
  type        = number
  default     = 1371595020
}

variable "github_oidc_provider_arn" {
  description = "ARN d'un fournisseur OIDC GitHub existant dans le compte. Vide = création."
  type        = string
  default     = ""
}

# --- Ressources existantes, importées (valeurs générées par scripts/discover.sh) ---

variable "site_bucket_name" {
  description = "Bucket S3 qui héberge le site (origine CloudFront)"
  type        = string
}

variable "site_bucket_region" {
  description = "Région du bucket du site"
  type        = string
  default     = "eu-west-3"
}

variable "cloudfront_distribution_id" {
  description = "ID de la distribution CloudFront existante (d1bedazj92888q.cloudfront.net)"
  type        = string
}

variable "cloudfront_oac_id" {
  description = "ID de l'Origin Access Control existant, vide si la distribution utilise un OAI ou rien"
  type        = string
  default     = ""
}

variable "lambda_function_name" {
  description = "Nom de la Lambda qui reçoit les suggestions"
  type        = string
}

variable "lambda_role_name" {
  description = "Nom du rôle IAM d'exécution de la Lambda (référencé, non géré)"
  type        = string
}

variable "lambda_runtime" {
  type    = string
  default = "nodejs20.x"
}

variable "lambda_handler" {
  type    = string
  default = "index.handler"
}

variable "lambda_timeout" {
  type    = number
  default = 10
}

variable "lambda_memory_size" {
  type    = number
  default = 128
}

variable "lambda_architecture" {
  type    = string
  default = "x86_64"
}

variable "suggestions_bucket_name" {
  description = "Bucket S3 où la Lambda enregistre les suggestions"
  type        = string
  default     = "elroutardo"
}

variable "sns_topic_name" {
  description = "Topic SNS notifié à chaque suggestion"
  type        = string
  default     = "elroutardo-suggestions"
}
