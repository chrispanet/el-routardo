# El Routardo

Guide pratique pour Palma de Majorque : site statique servi par S3 + CloudFront
(`https://d1bedazj92888q.cloudfront.net`), formulaire de suggestions branché sur
une Lambda Function URL (eu-west-3).

## Arborescence

| Chemin | Rôle |
|---|---|
| `site/` | Les fichiers du site tels que servis (HTML + CSS). Modifier ici, c'est modifier le site. |
| `infra/` | Terraform : bucket S3, distribution CloudFront, Lambda + Function URL, rôle OIDC GitHub Actions. |
| `lambda/suggestions/src/` | Code déployé de la Lambda "suggestions" (Python), zippé par Terraform. |
| `scripts/discover.sh` | Découvre les identifiants AWS existants et génère `infra/terraform.tfvars`. |
| `.github/workflows/deploy-site.yml` | Push sur `main` touchant `site/` : sync S3 + invalidation CloudFront. |
| `.github/workflows/terraform.yml` | PR touchant `infra/` : plan. Push sur `main` : apply. |

## Déploiement du contenu

Toute modification fusionnée sur `main` dans `site/` est déployée automatiquement
(sync S3 avec `--delete`, puis invalidation `/*`). Rien d'autre à faire.

## Ressources AWS (compte 273325727158)

| Ressource | Identifiant | Région |
|---|---|---|
| Distribution CloudFront | `E26V2M8BFYRBGY` (d1bedazj92888q.cloudfront.net) | global |
| Origin Access Control | `E3EDOYM9Z5I8MH` (`elroutardo-oac`) | global |
| Bucket du site | `elroutardo-site` | eu-west-3 |
| Lambda suggestions + Function URL | `elroutardo-suggestions` (Python 3.12) | eu-west-3 |
| Rôle d'exécution Lambda | `elroutardo-suggestions` (référencé, non géré) | global |
| Bucket des suggestions | `elroutardo` | eu-west-1 |
| Topic SNS | `elroutardo-suggestions` | eu-west-3 |

Ces ressources portent déjà les tags `ManagedBy=terraform` (créées le 12 mars 2026 par un
Terraform antérieur). Si ce state d'origine existe encore, il vaut mieux le réutiliser que
d'importer : dans ce cas remplacer le backend de `infra/versions.tf` et supprimer `infra/imports.tf`.

## Mise en place initiale (une seule fois)

`infra/terraform.tfvars` est déjà généré. Un `terraform plan` vérifié le 2026-09-15 donne :
11 imports, 0 création, 0 destruction, 4 changements bénins (tags sur les buckets, ré-upload
du même code Lambda, réécriture identique de la policy du bucket).

1. **Bucket de state Terraform** (si absent) :
   ```bash
   make bootstrap-state TF_STATE_BUCKET=el-routardo-tfstate
   ```
2. **Import et premier apply**, en local avec un profil AWS disposant des droits IAM
   (création du rôle `el-routardo-gha` ; la clé des sessions Claude n'a pas `iam:*`) :
   ```bash
   make init plan      # vérifier : 11 imports, 1 création (rôle GHA), 0 destruction
   make apply
   ```
3. **Variables du dépôt GitHub** (Settings > Secrets and variables > Actions > Variables) :

   | Variable | Valeur |
   |---|---|
   | `AWS_REGION` | `eu-west-3` |
   | `AWS_ROLE_ARN` | sortie Terraform `gha_role_arn` |
   | `S3_BUCKET` | `elroutardo-site` |
   | `CLOUDFRONT_DISTRIBUTION_ID` | `E26V2M8BFYRBGY` |
   | `TF_STATE_BUCKET` | `el-routardo-tfstate` |

4. Créer l'environnement GitHub `production` (Settings > Environments) et, si souhaité,
   y exiger une approbation manuelle avant chaque `terraform apply`.

Pour regénérer `infra/terraform.tfvars` : `make discover` (AWS CLI + jq).

## Récupérer le site tel que servi

```bash
make fetch-site   # retélécharge les 5 fichiers depuis CloudFront dans site/
```
