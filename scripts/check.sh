#!/usr/bin/env bash
# Vérifications rapides du contenu de site/ : fichiers attendus, liens internes, encodage.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0
for f in index.html arrivee.html decouvrir.html depart.html style.css; do
  [ -s "site/$f" ] || { echo "MANQUANT : site/$f"; fail=1; }
done
# Chaque cible de lien interne doit exister
for target in $(grep -ohE 'href="[a-z-]+\.(html|css)' site/*.html | sed -E 's/href="//' | sort -u); do
  [ -f "site/$target" ] || { echo "LIEN CASSÉ : $target"; fail=1; }
done
# Pas de caractères mal encodés
if grep -l $'\xC3\x83' site/*.html >/dev/null 2>&1; then echo "ENCODAGE suspect (double UTF-8)"; fail=1; fi
# Balises de base
for f in site/*.html; do
  grep -q '<title>' "$f" || { echo "PAS DE TITLE : $f"; fail=1; }
  grep -q 'charset="UTF-8"' "$f" || { echo "PAS DE CHARSET : $f"; fail=1; }
done
[ $fail -eq 0 ] && echo "check OK" || exit 1
