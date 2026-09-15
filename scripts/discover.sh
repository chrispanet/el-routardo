#!/usr/bin/env bash
# Découvre les ressources AWS existantes du site El Routardo et génère infra/terraform.tfvars
# Prérequis : AWS CLI v2 authentifié (profil local), jq.
set -euo pipefail
cd "$(dirname "$0")/.."
CF_DOMAIN="${CF_DOMAIN:-d1bedazj92888q.cloudfront.net}"
LAMBDA_URL_HOST="${LAMBDA_URL_HOST:-jppdyxoqienfydufsycuxsajy40ydoer.lambda-url.eu-west-3.on.aws}"
REGION="${AWS_REGION:-eu-west-3}"
OUT_DIR=infra/discovery; mkdir -p "$OUT_DIR"

echo "==> Compte : $(aws sts get-caller-identity --query Account --output text)"

echo "==> Distribution CloudFront pour $CF_DOMAIN"
DIST_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?DomainName=='$CF_DOMAIN'].Id | [0]" --output text)
[ "$DIST_ID" != "None" ] && [ -n "$DIST_ID" ] || { echo "Distribution introuvable" >&2; exit 1; }
aws cloudfront get-distribution-config --id "$DIST_ID" > "$OUT_DIR/cloudfront.json"
ORIGIN_DOMAIN=$(jq -r '.DistributionConfig.Origins.Items[0].DomainName' "$OUT_DIR/cloudfront.json")
OAC_ID=$(jq -r '.DistributionConfig.Origins.Items[0].OriginAccessControlId // ""' "$OUT_DIR/cloudfront.json")
OAI=$(jq -r '.DistributionConfig.Origins.Items[0].S3OriginConfig.OriginAccessIdentity // ""' "$OUT_DIR/cloudfront.json")
BUCKET="${ORIGIN_DOMAIN%%.s3*}"
echo "    distribution=$DIST_ID origine=$ORIGIN_DOMAIN bucket=$BUCKET oac=${OAC_ID:-aucun} oai=${OAI:-aucun}"

echo "==> Bucket S3 $BUCKET"
BUCKET_REGION=$(aws s3api get-bucket-location --bucket "$BUCKET" --query LocationConstraint --output text)
[ "$BUCKET_REGION" = "None" ] && BUCKET_REGION=us-east-1
aws s3api get-bucket-policy --bucket "$BUCKET" --query Policy --output text 2>/dev/null | jq . > "$OUT_DIR/bucket-policy.json" || echo '{}' > "$OUT_DIR/bucket-policy.json"
echo "    region=$BUCKET_REGION"

echo "==> Lambda dont la Function URL est $LAMBDA_URL_HOST"
LAMBDA_NAME=""
for fn in $(aws lambda list-functions --region "$REGION" --query 'Functions[].FunctionName' --output text); do
  url=$(aws lambda list-function-url-configs --region "$REGION" --function-name "$fn" --query 'FunctionUrlConfigs[0].FunctionUrl' --output text 2>/dev/null || true)
  if [[ "$url" == *"$LAMBDA_URL_HOST"* ]]; then LAMBDA_NAME="$fn"; break; fi
done
[ -n "$LAMBDA_NAME" ] || { echo "Lambda introuvable en $REGION" >&2; exit 1; }
aws lambda get-function --region "$REGION" --function-name "$LAMBDA_NAME" > "$OUT_DIR/lambda.json"
aws lambda get-function-url-config --region "$REGION" --function-name "$LAMBDA_NAME" > "$OUT_DIR/lambda-url.json"
LAMBDA_ROLE_ARN=$(jq -r '.Configuration.Role' "$OUT_DIR/lambda.json")
LAMBDA_ROLE_NAME="${LAMBDA_ROLE_ARN##*/}"
RUNTIME=$(jq -r '.Configuration.Runtime' "$OUT_DIR/lambda.json")
HANDLER=$(jq -r '.Configuration.Handler' "$OUT_DIR/lambda.json")
TIMEOUT=$(jq -r '.Configuration.Timeout' "$OUT_DIR/lambda.json")
MEMORY=$(jq -r '.Configuration.MemorySize' "$OUT_DIR/lambda.json")
ARCH=$(jq -r '.Configuration.Architectures[0] // "x86_64"' "$OUT_DIR/lambda.json")
echo "    lambda=$LAMBDA_NAME role=$LAMBDA_ROLE_NAME runtime=$RUNTIME handler=$HANDLER"

echo "==> Fournisseur OIDC GitHub"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" >/dev/null 2>&1; then
  echo "    oidc=$OIDC_ARN (existant)"
elif aws iam list-open-id-connect-providers >/dev/null 2>&1; then
  OIDC_ARN=""; echo "    oidc=aucun, sera créé"
else
  echo "    oidc=$OIDC_ARN (lecture IAM refusée, ARN conventionnel supposé existant)"
fi

cat > infra/terraform.tfvars <<TFV
# Généré par scripts/discover.sh le $(date -u +%FT%TZ). Identifiants non secrets.
aws_region                 = "$REGION"
site_bucket_name           = "$BUCKET"
site_bucket_region         = "$BUCKET_REGION"
cloudfront_distribution_id = "$DIST_ID"
cloudfront_oac_id          = "$OAC_ID"
lambda_function_name       = "$LAMBDA_NAME"
lambda_role_name           = "$LAMBDA_ROLE_NAME"
lambda_runtime             = "$RUNTIME"
lambda_handler             = "$HANDLER"
lambda_timeout             = $TIMEOUT
lambda_memory_size         = $MEMORY
lambda_architecture        = "$ARCH"
github_oidc_provider_arn   = "$OIDC_ARN"
TFV
echo "==> infra/terraform.tfvars écrit. Détails bruts dans $OUT_DIR/ (ignorés par git)."
echo "    Comparer infra/cloudfront.tf avec $OUT_DIR/cloudfront.json avant le premier plan."
