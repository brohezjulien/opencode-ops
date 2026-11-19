# Runbook — opencode-ops

## 1. Publier une nouvelle version d'OpenCode

1. Dans `Dockerfile`, changer **une seule ligne** (le `FROM`) : tag **et** digest.
   ```dockerfile
   FROM ghcr.io/anomalyco/opencode:2.3.2@sha256:be07cc4afd6d668d91b77accf1bc4338c87b39fbacc0a61666eb003781015f5a
   ```
   Le digest se lit avec :
   ```bash
   docker buildx imagetools inspect ghcr.io/anomalyco/opencode:<version> \
     | grep -i '^Digest'
   ```
   ⚠️ **Jamais le tag nu.** Un tag peut être repushé en amont : l'image changerait
   sous nos pieds sans qu'aucun commit ne bouge. Et la CI ne rattrape pas cette
   erreur : `.github/workflows/image.yml:35` lit la version avec
   `s|^FROM .*opencode:\([0-9][^ @]*\).*|`, motif qui s'arrête au `@` et accepte
   donc indifféremment le tag seul ou le tag+digest. Un tag nu passerait le smoke
   test sans être signalé.
2. Commit sur `main` → la CI construit, teste, publie.
3. Noter le tag publié dans le résumé du run : `…:<version>-<AAAAMMJJ>-<sha>`.

> Si le smoke test échoue, **rien n'est publié**. Lire le log du step
> « Smoke test (bloquant) » : il nomme l'outil en défaut.

## 2. Déployer sur l'hôte

```bash
cd /opt/stack/opencode
cp docker-compose.yml docker-compose.yml.bak-$(date +%Y%m%d-%H%M)
# éditer la ligne image: avec le nouveau tag
docker compose pull opencode
docker compose up -d --force-recreate opencode
```

Vérifications :

```bash
docker compose ps opencode
docker compose exec -T opencode sh -c 'opencode --version; tmux -V'
docker exec "$(docker compose ps -q opencode)" sh -c \
  'wget -qO- http://127.0.0.1:4096/ >/dev/null && echo "serveur: OK"'
```

⚠️ **La recréation tue la session tmux** (elle vit dans le conteneur). Ne jamais
déployer pendant un audit en cours.

## 2 bis. Contrôles après recréation

`running` + `healthy` ne suffisent pas : le conteneur peut être en bonne santé
alors que le service managé est tombé (il vit dans la session tmux, que la
recréation vient justement de tuer). Vérifier, dans cet ordre :

```bash
cd /opt/stack/opencode
docker compose ps opencode                                # running + healthy
docker compose exec -T opencode opencode --version         # la version attendue
docker compose exec -T opencode opencode service status    # doit afficher http://127.0.0.1:49374
docker compose exec -T opencode opencode debug paths       # db = /root/.local/share/opencode/opencode.db
docker compose exec -T opencode opencode plugin list       # les plugins attendus
docker compose exec -T opencode opencode session list      # la base répond, code retour 0
```

Toutes ces commandes ont été passées sur l'image **2.3.2 le 19/11/2026**.
`sqlite3` n'est **pas** installé dans l'image : ne pas compter sur lui pour
interroger `opencode.db`, passer par `opencode session list` (ou installer
l'outil dans le `Dockerfile`, jamais à chaud).

## 3. Rollback

```bash
cd /opt/stack/opencode
# remettre le tag précédent dans docker-compose.yml
docker compose up -d --force-recreate opencode
```

Les volumes (`.config`, `workspace`, `data`) ne sont **jamais** touchés : aucune
donnée n'est perdue par un rollback d'image.

## 4. Secours : construire localement (si la CI est indisponible)

```bash
cd /opt/stack/opencode
git -C workspace/elearning7P pull     # les anciens fichiers y sont encore
docker build -f workspace/elearning7P/infra/Dockerfile.7pb \
  -t opencode-toolbox:secours workspace/elearning7P/infra
docker run --rm --entrypoint /bin/sh \
  -v "$PWD/workspace/elearning7P/infra/smoke-test.sh:/smoke-test.sh:ro" \
  opencode-toolbox:secours /smoke-test.sh
```

## 5. Diagnostic

| Symptôme | Piste |
|---|---|
| conteneur `unhealthy` | `docker logs opencode --tail 50` ; vérifier que le port 4096 écoute |
| 401 sur `code.jbrohez.be/api/*` | mot de passe dans `.env` ≠ celui du client |
| `ocp` renvoie 401 | le code est émis par un **autre** serveur (49374) — utiliser `ocp`, pas `opencode pair` |
| zombies en pagaille | vérifier `init: true` dans le compose |
| session tmux perdue | elle vit dans le conteneur : une recréation la supprime |

## 6. Ce qui ne se fait JAMAIS

- `docker compose down -v` (supprime les volumes) ;
- `docker system prune` ;
- déployer pendant un audit en cours ;
- mettre `:latest` dans le compose de production.
