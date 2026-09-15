#!/usr/bin/env bash
# Télécharge le code déployé de la Lambda suggestions dans lambda/suggestions/
set -euo pipefail
cd "$(dirname "$0")/.."
REGION="${AWS_REGION:-eu-west-3}"
NAME="${LAMBDA_FUNCTION_NAME:-$(grep -E '^lambda_function_name' infra/terraform.tfvars | sed -E 's/.*= *"(.*)"/\1/')}"
[ -n "$NAME" ] || { echo "Nom de Lambda inconnu : lancer scripts/discover.sh ou définir LAMBDA_FUNCTION_NAME" >&2; exit 1; }
URL=$(aws lambda get-function --region "$REGION" --function-name "$NAME" --query Code.Location --output text)
TMP=$(mktemp -d)
curl -fsS -o "$TMP/code.zip" "$URL"
rm -rf lambda/suggestions/src && mkdir -p lambda/suggestions/src
unzip -q "$TMP/code.zip" -d lambda/suggestions/src
rm -rf "$TMP"
echo "Code extrait dans lambda/suggestions/src/ :"; find lambda/suggestions/src -type f | head -50
echo "Étape suivante : commiter, puis retirer ignore_changes dans infra/lambda.tf"
