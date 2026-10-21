#!/bin/sh
# =============================================================================
# ocp — APPAIRER un nouvel appareil (téléphone, autre PC) : affiche un QR code
# à scanner, valable 5 minutes et à usage unique.
#
# Pourquoi ce script plutôt que `opencode pair` : dans ce conteneur, `opencode
# pair` émet le code sur le SERVICE D'ARRIÈRE-PLAN (49374), alors que le lien
# public `code.jbrohez.be` tombe sur le serveur `serve` (4096) → le code est
# refusé (401, vérifié). Ici on demande le code AU BON serveur et on encode
# l'URL PUBLIQUE.
#
# Après l'appairage : session d'environ 30 jours (cookie). Changer le mot de
# passe du serveur déconnecte tous les appareils.
#
# Usage :  ocp
# =============================================================================
set -e

SERVEUR="${OPENCODE_SERVER_URL:-http://127.0.0.1:4096}"
PUBLIC="${OPENCODE_PUBLIC_URL:-https://code.jbrohez.be}"
USER="${OPENCODE_SERVER_USERNAME:-opencode}"
: "${OPENCODE_SERVER_PASSWORD:?OPENCODE_SERVER_PASSWORD absent de l'environnement}"

command -v qrencode >/dev/null || { echo "ocp : qrencode absent (paquet libqrencode-tools)"; exit 1; }

CODE=$(curl -s -u "$USER:$OPENCODE_SERVER_PASSWORD" -X POST "$SERVEUR/api/pair" \
       | python3 -c 'import sys,json;print(json.load(sys.stdin).get("code",""))' 2>/dev/null)

if [ -z "$CODE" ]; then
  echo "ocp : aucun code reçu du serveur $SERVEUR (injoignable, ou mot de passe incorrect ?)"
  exit 1
fi

URL="$PUBLIC/auth/connect/$CODE"

echo
echo "  📱  Scanne ce QR code avec ton téléphone (Chrome, ou l'appareil photo)."
echo "      Valable 5 minutes, usage unique."
echo
qrencode -t ANSIUTF8 "$URL"
echo
echo "  Lien à copier si tu préfères :"
echo "    $URL"
echo
