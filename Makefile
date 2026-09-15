SHELL := /bin/bash
TF_DIR := infra
AWS_REGION ?= eu-west-3
TF_STATE_BUCKET ?= el-routardo-tfstate
CF_URL := https://d1bedazj92888q.cloudfront.net

.PHONY: help discover bootstrap-state init plan apply deploy fetch-site fetch-lambda check

help:
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-16s %s\n", $$1, $$2}'

discover: ## Découvre les IDs AWS existants et écrit infra/terraform.tfvars
	./scripts/discover.sh

bootstrap-state: ## Crée le bucket S3 de state Terraform (versionné, chiffré, privé)
	aws s3api create-bucket --bucket $(TF_STATE_BUCKET) --region $(AWS_REGION) \
	  --create-bucket-configuration LocationConstraint=$(AWS_REGION)
	aws s3api put-bucket-versioning --bucket $(TF_STATE_BUCKET) --versioning-configuration Status=Enabled
	aws s3api put-public-access-block --bucket $(TF_STATE_BUCKET) --public-access-block-configuration \
	  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
	aws s3api put-bucket-encryption --bucket $(TF_STATE_BUCKET) --server-side-encryption-configuration \
	  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

init: ## terraform init (backend S3)
	cd $(TF_DIR) && terraform init -backend-config="bucket=$(TF_STATE_BUCKET)" -backend-config="region=$(AWS_REGION)"

plan: ## terraform plan
	cd $(TF_DIR) && terraform plan -out=tfplan

apply: ## terraform apply du dernier plan
	cd $(TF_DIR) && terraform apply tfplan

deploy: ## Déploiement manuel du contenu (S3 sync + invalidation), nécessite S3_BUCKET et CLOUDFRONT_DISTRIBUTION_ID
	./scripts/deploy.sh

fetch-site: ## Retélécharge les fichiers servis par CloudFront dans site/
	for f in index.html arrivee.html decouvrir.html depart.html style.css; do \
	  curl -fsS -o site/$$f $(CF_URL)/$$f && echo "ok $$f"; done

fetch-lambda: ## Télécharge le code déployé de la Lambda dans lambda/suggestions/
	./scripts/fetch-lambda.sh

check: ## Vérifications rapides du contenu
	./scripts/check.sh
