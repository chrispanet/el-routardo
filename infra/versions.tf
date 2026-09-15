terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.6"
    }
  }

  # bucket et region fournis par -backend-config (make init / workflow)
  backend "s3" {
    key          = "el-routardo/terraform.tfstate"
    use_lockfile = true
    encrypt      = true
  }
}
