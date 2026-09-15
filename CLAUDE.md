# Consignes pour les sessions Claude Code

- Le site est dans `site/` : 4 pages HTML (`index`, `arrivee`, `decouvrir`, `depart`) et `style.css`.
  Pas de build, pas de framework : les fichiers sont servis tels quels par CloudFront.
- Les demandes de modification portent en général sur le contenu de `site/`.
  Éditer directement, garder le français, garder les liens Google Maps existants.
- Le déploiement est automatique : fusion sur `main` => workflow `deploy-site.yml`
  (sync S3 + invalidation). Ne pas déployer à la main sauf demande explicite.
- `infra/` est du Terraform. Toute modification passe par une PR (plan automatique)
  puis apply sur `main`. Ne jamais lancer `terraform apply` depuis une session sans accord.
- Le formulaire de `depart.html` poste vers la Lambda Function URL codée en dur dans le script inline.
  Ne pas changer cette URL sans mettre à jour `infra/`.
- Vérification locale rapide : `make check` (HTML valide, liens internes présents).
