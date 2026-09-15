# El Routardo

Guide pratique pour Palma de Majorque : site statique servi par S3 + CloudFront
(`https://d1bedazj92888q.cloudfront.net`), formulaire de suggestions branché sur
une Lambda Function URL (eu-west-3).

## Arborescence

| Chemin | Rôle |
|---|---|
| `site/` | Les fichiers du site tels que servis (HTML + CSS). Modifier ici, c'est modifier le site. |
| `infra/` | Terraform : bucket S3, distribution CloudFront, Lambda + Function URL, rôle OIDC GitHub Actions. |
| `lambda/suggestions/` | Code de la Lambda "suggestions" (à récupérer depuis AWS, voir plus bas). |
| `scripts/discover.sh` | Découvre les identifiants AWS existants et génère `infra/terraform.tfvars`. |
| `.github/workflows/deploy-site.yml` | Push sur `main` touchant `site/` : sync S3 + invalidation CloudFront. |
| `.github/workflows/terraform.yml` | PR touchant `infra/` : plan. Push sur `main` : apply. |

## Déploiement du contenu

Toute modification fusionnée sur `main` dans `site/` est déployée automatiquement
(sync S3 avec `--delete`, puis invalidation `/*`). Rien d'autre à faire.

## Mise en place initiale (une seule fois)

1. **Découverte des ressources existantes** (avec un profil AWS local) :
   ```bash
   ./scripts/discover.sh            # écrit infra/terraform.tfvars + infra/discovery/*.json
   ```
2. **Bucket de state Terraform** (si absent) :
   ```bash
   make bootstrap-state TF_STATE_BUCKET=el-routardo-tfstate
   ```
3. **Import et premier apply** en local (crée le rôle OIDC, importe S3 / CloudFront / Lambda) :
   ```bash
   make init plan      # vérifier que le plan n'a que des imports et des changements attendus
   make apply
   ```
4. **Variables du dépôt GitHub** (Settings > Secrets and variables > Actions > Variables) :

   | Variable | Valeur |
   |---|---|
   | `AWS_REGION` | `eu-west-3` |
   | `AWS_ROLE_ARN` | sortie Terraform `gha_role_arn` |
   | `S3_BUCKET` | nom du bucket du site |
   | `CLOUDFRONT_DISTRIBUTION_ID` | ID de la distribution |
   | `TF_STATE_BUCKET` | bucket de state |

5. **Code de la Lambda** : `make fetch-lambda` télécharge le code déployé dans
   `lambda/suggestions/`. Une fois commité, retirer le bloc `ignore_changes` dans
   `infra/lambda.tf` pour que Terraform gère aussi le code.

## Récupérer le site tel que servi

```bash
make fetch-site   # retélécharge les 5 fichiers depuis CloudFront dans site/
```
