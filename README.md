# El Routardo

Guide pratique pour Palma de Majorque : site statique servi par S3 + CloudFront
(`https://routardo.azean.com`, l'URL d'origine `https://d1bedazj92888q.cloudfront.net`
reste valable), formulaire de suggestions branché sur une Lambda Function URL (eu-west-3).

Projet interne : le site n'est pas destiné à être référencé. `site/robots.txt`,
les balises `meta robots` des pages et l'en-tête `X-Robots-Tag` servi par
CloudFront le tiennent hors des moteurs de recherche. Le nom de domaine reste
toutefois visible dans les journaux de transparence des certificats (voir plus bas).

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
| Zone Route 53 `azean.com` | `Z0076746426XHFSVXWRW` (partagée, **non gérée** par ce dépôt) | global |
| Certificat ACM `routardo.azean.com` | créé par Terraform | us-east-1 |

Ces ressources ont été créées le 12 mars 2026 par un Terraform dont le state est perdu :
on repart de zéro en important les ressources existantes (`infra/imports.tf`), sans rien recréer.

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

## Nom de domaine

Le site répond sur `routardo.azean.com`.

Il n'y a **pas** de zone hébergée dédiée. La zone `azean.com` existe déjà dans le
compte et sert déjà `api.azean.com` et `splunkbeautify.azean.com` sur le même
modèle. Une zone enfant déléguée coûterait 0,50 $/mois, imposerait d'y maintenir
des enregistrements NS et n'apporterait rien tant que tout vit dans le même compte.

`infra/dns.tf` crée donc, dans la zone existante :

| Ressource | Rôle |
|---|---|
| Certificat ACM (us-east-1) | TLS pour CloudFront, validé par DNS |
| CNAME de validation | posé et retiré par Terraform |
| Enregistrement **alias A** `routardo.azean.com` | pointe sur la distribution |

Un alias plutôt qu'un CNAME : la requête Route 53 n'est pas facturée, la
résolution est directe, et l'alias suit la distribution si elle change d'adresse.

La zone parente est référencée par son identifiant (`parent_hosted_zone_id`), pas
importée : elle porte les enregistrements d'autres projets, qui n'ont rien à faire
dans le state de ce dépôt.

Pas d'enregistrement AAAA : la distribution a `is_ipv6_enabled = false`. Pour
servir en IPv6, basculer ce champ et ajouter un second enregistrement alias.

### Non-indexation

Trois garde-fous, à trois niveaux :

1. `site/robots.txt` en `Disallow: /`.
2. `meta robots noindex, nofollow, noarchive, nosnippet` sur les quatre pages.
3. En-tête `X-Robots-Tag` servi par CloudFront (`elroutardo-noindex`), qui couvre
   aussi le CSS et s'applique même si `robots.txt` n'est pas lu.

**Limite à connaître :** le nom `routardo.azean.com` apparaîtra dans les journaux
publics de transparence des certificats (consultables sur crt.sh). AWS l'indique
explicitement : « All public certificates issued by ACM are automatically recorded
in certificate transparency logs. Per browser policy requirements, you cannot opt
out of certificate transparency logging. » Le nom est donc découvrable, même si le
contenu n'est pas indexé. Pour masquer aussi le nom, il faudrait un certificat
générique `*.azean.com` : seul `*.azean.com` serait alors publié. Si l'accès doit
être réellement restreint et pas seulement discret, c'est une authentification
qu'il faut ajouter, pas du DNS.

## Débloquer la CI Terraform (une seule fois)

Le rôle `el-routardo-gha` n'avait pas assez de droits en lecture S3 : rafraîchir
un `aws_s3_bucket` appelle `GetBucketAccelerateConfiguration`, dont l'action IAM
s'appelle `s3:GetAccelerateConfiguration` et n'était donc pas couverte par
`s3:GetBucket*`. Tout `terraform plan` en CI meurt en 403 là-dessus.

Le correctif est dans `infra/iam-github.tf`, mais il ne peut pas s'appliquer tout
seul : le job `apply` dépend du job `plan`, qui échoue justement par manque de ce
droit. Il faut donc une fois, en local, avec un profil AWS disposant des droits
IAM (la clé des sessions Claude ne les a pas) :

```bash
make init plan
make apply
```

Ensuite la CI tourne seule : les plans sur PR et les applies sur `main` passent.
