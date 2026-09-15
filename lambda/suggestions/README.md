# Lambda suggestions

Reçoit les suggestions du formulaire de `site/depart.html` (POST JSON : `name`, `categories`, `review`)
via une Function URL publique (`https://jppdyxoqienfydufsycuxsajy40ydoer.lambda-url.eu-west-3.on.aws/`).

Le code déployé n'a pas encore été rapatrié : lancer `make fetch-lambda`, qui l'extrait dans `src/`.
Tant que `src/` ne contient que le placeholder, `infra/lambda.tf` ignore les changements de code
(`ignore_changes`) pour ne jamais écraser la version en production.
