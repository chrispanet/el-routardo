provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "el-routardo"
      ManagedBy = "terraform"
      Repo      = var.github_repo
    }
  }
}
