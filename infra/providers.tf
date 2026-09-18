provider "aws" {
  region = var.aws_region

  # Tags identiques à ceux déjà présents sur les ressources importées.
  default_tags {
    tags = {
      Project     = "elroutardo"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

# Le bucket des suggestions ("elroutardo") vit en eu-west-1.
provider "aws" {
  alias  = "eu-west-1"
  region = "eu-west-1"

  default_tags {
    tags = {
      Project     = "elroutardo"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

# ACM pour CloudFront doit vivre en us-east-1.
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "elroutardo"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}
