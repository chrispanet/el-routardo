# Lambda suggestions

Reçoit les suggestions du formulaire de `site/depart.html` (POST JSON : `name`, `categories`, `review`)
via une Function URL publique (`https://jppdyxoqienfydufsycuxsajy40ydoer.lambda-url.eu-west-3.on.aws/`).

`src/index.py` est le code tel que déployé (récupéré le 2026-09-15 avec `make fetch-lambda`).
Il écrit chaque suggestion dans le bucket `elroutardo` (eu-west-1, préfixe `suggestions/`)
et publie une notification sur le topic SNS `elroutardo-suggestions`.

Terraform zippe `src/` (`infra/lambda.tf`) : toute modification commitée ici est déployée par
le workflow `terraform.yml`.
