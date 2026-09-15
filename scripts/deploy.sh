#!/usr/bin/env bash
# Déploie site/ vers S3 puis invalide CloudFront. Utilisé par le workflow et en local.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${S3_BUCKET:?S3_BUCKET requis}"
: "${CLOUDFRONT_DISTRIBUTION_ID:?CLOUDFRONT_DISTRIBUTION_ID requis}"

# HTML : cache court (le contenu change souvent). CSS : cache d'un jour, invalidé de toute façon.
aws s3 sync site/ "s3://$S3_BUCKET/" --delete --exclude ".*" --exclude "*.html" \
  --cache-control "public, max-age=86400"
aws s3 sync site/ "s3://$S3_BUCKET/" --exclude "*" --include "*.html" \
  --content-type "text/html; charset=utf-8" --cache-control "public, max-age=300"

INV=$(aws cloudfront create-invalidation --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" --paths "/*" --query Invalidation.Id --output text)
echo "Invalidation $INV créée"
aws cloudfront wait invalidation-completed --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" --id "$INV"
echo "Déploiement terminé"
