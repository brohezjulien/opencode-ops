#!/bin/sh
# =============================================================================
# smoke-test.sh — vérifie que l'image dérivée est COMPLÈTE et FONCTIONNELLE.
#
# Un seul fichier, deux usages (pas deux vérités) :
#   1. la CI GitHub Actions l'exécute AVANT de publier l'image → une image
#      cassée ne peut pas arriver en production ;
#   2. infra/apply-image.sh l'exécute en mode --build-only (secours).
#
# Usage :
#   sh smoke-test.sh                       # attend opencode 2.1.2
#   EXPECT_OPENCODE=2.0.32 sh smoke-test.sh
#
# Chaque outil est testé FONCTIONNELLEMENT (pas seulement `--version`) :
#   - Blender  : import de bpy en headless
#   - FreeCAD  : exécution d'un script Python dans FreeCADCmd
#   - chromium : rendu réel d'une page (--dump-dom)
#   - tmux     : création + vérification + destruction d'une session
#   - qrencode : production d'un PNG non vide
#   - oc/ocp   : présents, syntaxe valide, et cible correcte (4096 / auth/connect)
#   - ollama   : démarrage + réponse de l'API
#   - PDF/SVG  : conversion SVG -> PNG réelle
#   - polices  : DejaVu/Noto présentes (sinon texte rendu en carrés)
# =============================================================================
set -eu

ATTENDU="${EXPECT_OPENCODE:-2.1.2}"
fail() { echo "ECHEC : $*" >&2; exit 1; }
ok()   { echo "  ok  $*"; }

echo "== smoke test (opencode attendu : $ATTENDU)"

# --- OpenCode (base officielle) ---------------------------------------------
V=$(opencode --version 2>&1)
case "$V" in
  *"$ATTENDU"*) ok "$V" ;;
  *)            fail "opencode : '$V' (attendu $ATTENDU)" ;;
esac

# --- tmux : version + session réelle ----------------------------------------
tmux -V >/dev/null 2>&1 || fail "tmux absent"
tmux new -d -s smoke 'sleep 2' || fail "tmux ne crée pas de session"
tmux has-session -t smoke 2>/dev/null || fail "tmux : session introuvable"
tmux kill-session -t smoke 2>/dev/null || true
ok "tmux $(tmux -V | awk '{print $2}')"

# --- qrencode : vrai QR, non vide -------------------------------------------
printf 'smoke' | qrencode -o /tmp/q.png -s 1 || fail "qrencode ne génère rien"
[ -s /tmp/q.png ] || fail "qrencode : PNG vide"
ok "qrencode $(qrencode --version 2>&1 | head -1 | awk '{print $3}')"

# --- oc / ocp : présents, exécutables, syntaxe, cible -----------------------
for S in /usr/local/bin/oc /usr/local/bin/ocp; do
  [ -x "$S" ] || fail "$S absent ou non exécutable"
  sh -n "$S"  || fail "$S : erreur de syntaxe"
done
grep -q '4096'          /usr/local/bin/oc  || fail "oc ne vise pas le port 4096"
grep -q 'auth/connect'  /usr/local/bin/ocp || fail "ocp ne demande pas de code d'appairage"
ok "oc + ocp"

# --- Blender : version + import de bpy en headless --------------------------
blender --version >/dev/null 2>&1 || fail "blender absent"
blender -b --factory-startup --python-expr \
  'import bpy,sys; print("BPY",bpy.app.version_string)' 2>/dev/null \
  | grep -q '^BPY' || fail "blender : bpy ne se charge pas"
ok "blender $(blender --version 2>&1 | head -1 | awk '{print $2}')"

# --- FreeCAD : version + exécution d'un script Python -----------------------
FreeCADCmd --version >/dev/null 2>&1 || fail "FreeCADCmd absent"
printf 'import FreeCAD\nprint("FC", FreeCAD.Version()[0])\n' > /tmp/fc.py
FreeCADCmd /tmp/fc.py 2>/dev/null | grep -q '^FC' || fail "FreeCAD : module Python KO"
ok "FreeCAD $(FreeCADCmd --version 2>&1 | head -1)"

# --- chromium : rendu réel ---------------------------------------------------
chromium --version >/dev/null 2>&1 || fail "chromium absent"
DOM=$(chromium --headless --no-sandbox --disable-gpu --dump-dom \
        "data:text/html,<b>ok</b>" 2>/dev/null)
printf '%s' "$DOM" | grep -q '<b>ok</b>' || fail "chromium : rendu impossible"
ok "chromium $(chromium --version 2>&1 | awk '{print $2}')"

# --- polices (sinon texte en carrés) ----------------------------------------
fc-list 2>/dev/null | grep -qi -E 'DejaVu|Noto' || fail "aucune police DejaVu/Noto"
ok "polices DejaVu/Noto"

# --- ollama : démarrage + API réelle ----------------------------------------
ollama --version >/dev/null 2>&1 || fail "ollama absent"
if ! wget -qO- http://127.0.0.1:11434/api/version >/tmp/ollama-api.json 2>/dev/null; then
  ollama serve >/tmp/ollama.log 2>&1 &
  i=0
  while [ "$i" -lt 20 ]; do
    wget -qO- http://127.0.0.1:11434/api/version >/tmp/ollama-api.json 2>/dev/null && break
    i=$((i + 1)); sleep 1
  done
fi
[ -s /tmp/ollama-api.json ] || { cat /tmp/ollama.log 2>/dev/null; fail "ollama : API injoignable"; }
ok "ollama $(cat /tmp/ollama-api.json)"

# --- chaîne PDF/SVG : présence + conversion réelle ---------------------------
for B in inkscape pdftocairo pdftoppm pdftotext rsvg-convert qpdf gs mutool; do
  command -v "$B" >/dev/null 2>&1 || fail "$B absent"
done
printf '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10"/></svg>' > /tmp/t.svg
rsvg-convert /tmp/t.svg -o /tmp/t.png 2>/dev/null || fail "rsvg-convert : conversion KO"
[ -s /tmp/t.png ] || fail "rsvg-convert : sortie vide"
ok "PDF/SVG : inkscape, poppler, rsvg, qpdf, gs, mutool"

# --- runtime dev -------------------------------------------------------------
for B in node npm python3 git curl; do
  command -v "$B" >/dev/null 2>&1 || fail "$B absent"
done
ok "node $(node -v) / npm $(npm -v) / python $(python3 -V 2>&1 | awk '{print $2}') / git $(git --version | awk '{print $3}')"

# --- signalé, non bloquant ---------------------------------------------------
command -v git-lfs >/dev/null 2>&1 && ok "git-lfs" || echo "  info : git-lfs absent (non bloquant)"

echo "SMOKE TEST : OK"
