# opencode-ops — l'environnement OpenCode de Julien

Image Docker **dérivée** d'OpenCode, avec les outils cuits dedans (Blender, FreeCAD,
navigateur, PDF/SVG, tmux, `oc`/`ocp`), construite et **testée par la CI**, jamais sur
la machine de production.

> Ce dépôt ne sert **aucun projet** en particulier : il sert les trois
> (`elearning7P`, `ecoledigitale`, `horairiste-python`).

## Ce qu'il y a ici

| Fichier | Rôle |
|---|---|
| `Dockerfile` | l'image dérivée (base officielle `ghcr.io/anomalyco/opencode` + outils) |
| `smoke-test.sh` | vérifie **fonctionnellement** chaque outil — utilisé par la CI **et** en secours |
| `oc.sh` / `ocp.sh` | raccourcis cuits dans l'image : session tmux persistante / appairage QR |
| `compose.example.yaml` | le compose à installer sur l'hôte |
| `.github/workflows/image.yml` | construit → teste → publie sur `ghcr.io` |
| `docs/RUNBOOK.md` | mise à jour, rollback, pannes |

## Le principe

```
push sur main ──► CI : build ──► smoke test ──┬─ échec ──► RIEN n'est publié
                                              └─ succès ─► ghcr.io/…/opencode-toolbox:<version>-<date>
                                                                     │
                                              hôte : docker compose pull + up -d
```

**La production ne compile jamais.** Mise à jour = télécharger une image publiée.

## Mise à jour (côté hôte)

```bash
cd /opt/stack/opencode
docker compose pull opencode
docker compose up -d opencode
```

## Rollback

```bash
# remettre le tag précédent dans docker-compose.yml, puis :
docker compose up -d --force-recreate opencode
```

## Ce qui est cuit dans l'image

OpenCode + node/npm, git/ssh, Python 3, **Blender** (headless, symlink `blender`),
**FreeCAD** (`FreeCADCmd`), **chromium** + polices Noto/DejaVu, **ollama**,
inkscape, poppler, rsvg, qpdf, ghostscript, mutool, **tmux**, **qrencode**, `oc`, `ocp`.

⚠️ **PyMuPDF n'est pas installé** — décision du 21/10/2026 : aucun code ne l'utilise
(`import fitz` = 0 occurrence), et il n'existe ni paquet Alpine ni wheel pour
Python 3.14/musl. Le PDF reste couvert par `mutool`, `poppler`, `qpdf`, `gs`, `inkscape`.

## Sécurité

- Le mot de passe du serveur va dans `/opt/stack/opencode/.env` (jamais dans le dépôt).
- Les clés SSH du conteneur vivent dans `/root/workspace/.ssh/` (hors dépôt).
