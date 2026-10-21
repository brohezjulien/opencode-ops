#!/bin/sh
# =============================================================================
# oc — « ma session de travail » : REJOINT la session tmux du projet, ou la CRÉE
# (avec opencode lancé dedans), et relance opencode si tu es déjà dedans.
#
# Pourquoi tmux : un tour d'agent est ANNULÉ dès que le client se déconnecte
# (navigateur fermé, PC éteint). Dans tmux, la session vit SUR le serveur →
# tu peux tout fermer, ça continue.
#
# Pourquoi --server : le conteneur fait tourner UN serveur public (PID 1, port
# 4096, exposé par Traefik sur code.jbrohez.be). Sans --server, le TUI en
# démarre un SECOND (49374) → deux serveurs, des codes d'appairage qui ne
# traversent pas, et l'UI web qui ne voit pas l'état en direct. Avec --server,
# tout le monde parle au MÊME serveur (c'est le montage que décrit la doc).
#
# Usage :
#   oc                    # projet par défaut : ecoledigitale
#   oc elearning7P        # un autre projet de /root/workspace
#   tmux ls               # voir les sessions
#   tmux kill-session -t oc-ecoledigitale
#
# Installé dans /usr/local/bin (déjà dans le PATH) — utilisable tel quel depuis
# le terminal web de code.jbrohez.be comme depuis un SSH.
# =============================================================================
set -e

PROJET="${1:-ecoledigitale}"
DIR="/root/workspace/$PROJET"
SESSION="oc-$PROJET"
SERVEUR="${OPENCODE_SERVER_URL:-http://127.0.0.1:4096}"

if [ ! -d "$DIR" ]; then
  echo "oc : dossier introuvable : $DIR"
  echo "     projets disponibles :"
  ls -d /root/workspace/*/ 2>/dev/null | sed 's|.*/\([^/]*\)/|       \1|'
  exit 1
fi

command -v tmux >/dev/null || { echo "oc : tmux absent de l'image"; exit 1; }

# Déjà DANS la session (typiquement après avoir quitté opencode) → on relance
# simplement l'agent, sur le serveur public.
if [ -n "${TMUX:-}" ] && [ "$(tmux display-message -p '#S' 2>/dev/null)" = "$SESSION" ]; then
  exec opencode --server "$SERVEUR"
fi

# Session déjà là → on s'y rattache.
if tmux has-session -t "$SESSION" 2>/dev/null; then
  exec tmux attach -t "$SESSION"
fi

# Sinon : création DÉTACHÉE (survit à ta déconnexion), avec opencode dedans.
# On laisse un shell sous l'agent : si opencode se ferme, la session reste.
tmux new-session -d -s "$SESSION" -c "$DIR"
tmux send-keys -t "$SESSION" "opencode --server $SERVEUR" C-m

echo "Session « $SESSION » ouverte dans $DIR, connectée à $SERVEUR."
echo "Tu peux fermer ton navigateur / éteindre ton PC : elle continue sur le serveur."
echo "Pour y revenir : tape simplement « oc $PROJET »."
exec tmux attach -t "$SESSION"
