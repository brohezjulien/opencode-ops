# Image OpenCode dérivée pour le projet « Chantier 7PB ».
#
# Part de l'image OFFICIELLE et y ajoute les outils des missions :
#   - dev / build / déploiement du jeu (node, git, ssh…)
#   - 3D : Blender (headless) + FreeCAD
#   - plans PDF/SVG : inkscape, poppler, rsvg, qpdf, ghostscript, mupdf
#   - python3 + py3-pip (scripts). PDF vectoriel : mutool (mupdf-tools), poppler,
#     qpdf, ghostscript — suffisants, et présents en paquets APK précompilés.
#     ⚠️ PyMuPDF a été RETIRÉ le 21/10/2026 : l'image de base 2.1.2 embarque
#     Python 3.14, pour lequel il n'existe pas de wheel musllinux → pip tentait
#     de compiler mupdf depuis les sources et échouait (`cc: not found`).
#     Il n'était utilisé nulle part dans le code (aucun `import fitz`).
#   - navigateur : chromium ~314 Mo (MCP Playwright — le binaire que
#     Playwright télécharge lui-même est glibc, inutilisable sur Alpine/musl ;
#     SEUL le chromium Alpine fonctionne) + polices font-noto / font-dejavu
#     (sinon texte rendu en carrés)
#   - ollama 0.17.7-r1 : binaire de la mémoire vectorielle opencode-mem
#     (les modèles restent sur le volume ./data → pas de coût image)
#   - tmux : terminal persistant CÔTÉ SERVEUR → le TUI (et donc le tour en cours)
#     survit à la déconnexion du client (PC éteint, SSH coupé). Voir plus bas.
#
# BUT : les outils installés « à la main » dans le conteneur sont perdus à chaque mise à jour.
# En construisant cette image sur l'hôte OVH, ils sont « cuits » dedans → permanents.
#
# Construction : par la CI (GitHub Actions -> ghcr.io), JAMAIS sur la prod.
#   .github/workflows/image.yml : build -> smoke-test.sh -> publication
# En secours seulement, sur l'hôte :
#   docker build -t opencode-toolbox:secours .
FROM ghcr.io/anomalyco/opencode:2.1.2

RUN apk add --no-cache \
      nodejs npm git openssh-client curl tar gzip unzip \
      blender-headless blender-shared freecad \
      inkscape poppler-utils rsvg-convert qpdf ghostscript mupdf-tools \
      chromium font-noto font-dejavu ollama \
      python3 py3-pip \
 && mkdir -p /usr/local/bin && ln -sf /usr/bin/blender-headless /usr/local/bin/blender

# Vérification (non bloquante : on journalise seulement).
RUN blender --version 2>&1 | head -1; FreeCADCmd --version 2>&1 | head -1; rsvg-convert --version 2>&1 | head -1; chromium --version 2>&1 | head -1; ollama --version 2>&1 | head -1

# tmux : terminal persistant CÔTÉ SERVEUR. Sans lui, fermer le client (PC éteint,
# SSH coupé) annule le tour en cours ; avec lui, on détache et on reprend plus tard :
#   tmux new -s oc      → lancer opencode dedans
#   Ctrl-b puis d       → se détacher (facultatif : éteindre directement suffit)
#   tmux attach -t oc   → reprendre l'écran
# VOLONTAIREMENT une ligne `RUN` séparée : la grosse couche « apk add » ci-dessus
# reste en cache au rebuild (sinon Blender/FreeCAD/chromium seraient retéléchargés).
RUN apk add --no-cache tmux

# Raccourci `oc` = « rejoins ma session » (attach ou création + opencode dedans).
# Source versionnée : infra/oc.sh. Le contexte de build EST le dossier infra/,
# donc ce COPY reste minuscule (~4 Ko) — on ne pousse toujours PAS le workspace.
COPY oc.sh /usr/local/bin/oc
RUN chmod 0755 /usr/local/bin/oc

# Raccourci `ocp` = appairer un téléphone : affiche un QR code à scanner.
# Nécessite `qrencode` (paquet libqrencode-tools). Ligne `RUN` DÉDIÉE : la grosse
# couche « apk add » reste en cache.
COPY ocp.sh /usr/local/bin/ocp
RUN apk add --no-cache libqrencode-tools \
 && chmod 0755 /usr/local/bin/ocp
