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
| `config/opencode.jsonc` | **source de vérité** de la config OpenCode globale (copiée dans `~/.config/opencode/`) |
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

## Config OpenCode (globale)

`config/opencode.jsonc` est la copie versionnée de `~/.config/opencode/opencode.jsonc`
(et de `elearning7P/infra/opencode-global.jsonc`). Règles :

- **un seul niveau commun** : agents, modèle, compaction, permissions, commandes ;
  le spécifique à un projet (MCP, watcher) reste dans son `opencode.json` ;
- **modèles en `opencode/…`** : 2.2.5 a fusionné l'ancien fournisseur `opencode-go`
  dans `opencode` — un `opencode-go/…` ne résout plus et retombe sur un modèle gratuit ;
- **`compaction.buffer: "60%"`** (pourcentage, plus de bloc `providers.limit`) ;
- **`update: "disable"`** : la version est celle du tag d'image, pas d'auto-update.

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

## Configuration OpenCode (config/opencode.jsonc)

La config **globale** (agents, permissions, compaction, modèle, commandes) est
versionnée ici et copiée dans le conteneur :

```bash
docker compose cp config/opencode.jsonc opencode:/root/.config/opencode/opencode.jsonc
```

Règles retenues (01/11/2026) :

- **Modèles en `opencode/...`** : depuis 2.2.5, l'ancien fournisseur `opencode-go`
  est fusionné dans `opencode`. Un `opencode-go/...` ne résout plus → les sessions
  retombent sur un modèle gratuit, refusé par le serveur.
- **Config de projet séparée** : le commun vit dans la globale ; le spécifique
  (MCP, watcher) reste dans l'`opencode.json` du projet. Les deux sont fusionnés —
  un projet qui redéclare `model` masque donc la globale.
- **`update: "disable"`** : la version est celle de l'image (tag figé) ; pas
  d'auto-update dans un conteneur.
- **`compaction.buffer: "60%"`** en pourcentage, pas en tokens.
