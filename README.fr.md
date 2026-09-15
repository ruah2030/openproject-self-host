# OpenProject + Traefik + Nginx Deployment

🌐 [English](README.md) | **Français**

Déploiement d'OpenProject (image tout-en-un avec PostgreSQL et memcached intégrés) derrière Traefik en reverse proxy interne, et Nginx (déjà configuré) comme reverse proxy externe avec SSL/TLS.

## 📂 Structure

```
~/openproject/
├── docker-compose.yml    # Configuration Docker Compose (Traefik + OpenProject)
├── .env                  # Variables d'environnement (CONFIDENTIEL — jamais en Git)
├── .env.example          # Modèle du .env (versionné)
├── .gitignore            # Fichiers exclus de Git (.env, backups…)
├── setup.sh              # Script d'installation automatique
├── Makefile              # Commandes rapides
├── README.md             # Documentation (anglais)
├── README.fr.md          # Cette documentation (français)
└── backups/              # Sauvegardes PostgreSQL (créé automatiquement)
```

## 🔧 Architecture

```
Internet (nexus.bestcash.me)
    ↓
Nginx (port 443 - SSL/TLS Certbot) [DÉJÀ CONFIGURÉ]
    ↓ (proxy_pass http://127.0.0.1:8080)
Traefik (host 8080 → entrypoint web :80)
    ↓ (routing Host(`nexus.bestcash.me`))
OpenProject (port 80 interne — image tout-en-un)
    ├── PostgreSQL intégré  → /var/lib/openproject/pgdata
    ├── Memcached intégré
    └── Assets/pièces jointes → /var/lib/openproject/assets
```

Points clés :

- **Image tout-en-un** `openproject/openproject:17` : PostgreSQL et memcached tournent DANS le container — pas de base externe à créer.
- **Persistance** sur l'hôte via bind mounts : `/var/lib/openproject/pgdata` (base de données) et `/var/lib/openproject/assets` (pièces jointes).
- **Traefik** écoute sur le port hôte `8080` (la même cible que le `proxy_pass` Nginx existant — aucun changement Nginx nécessaire). Dashboard sur `127.0.0.1:8081` uniquement.
- **`OPENPROJECT_HTTPS: "true"`** : OpenProject génère des URLs en https car le TLS est terminé par Nginx en amont.
- **`OPENPROJECT_HOST__NAME`** : double underscore obligatoire (`HOST__NAME`).

## ⚡ Prérequis

- ✅ Docker + Docker Compose installés
- ✅ Nginx déjà configuré avec SSL/TLS (Certbot) et `proxy_pass http://127.0.0.1:8080`
- ✅ Accès sudo (création de `/var/lib/openproject`)

## 🚀 Démarrage Rapide

```bash
bash setup.sh
```

Le script va :

1. ✅ Vérifier Docker / Docker Compose
2. ✅ Créer les répertoires de données `/var/lib/openproject/{pgdata,assets}`
3. ✅ Créer le fichier `.env` avec une `SECRET_KEY_BASE` générée (ou conserver l'existant)
4. ✅ Lancer les containers (Traefik + OpenProject)

⏳ **Premier démarrage** : OpenProject initialise sa base de données interne — comptez plusieurs minutes avant que le site réponde.

### Configuration manuelle du .env

```bash
cp .env.example .env
chmod 600 .env
# puis renseigner SECRET_KEY_BASE (openssl rand -hex 64)
```

### Migration depuis une installation existante

Si vous avez déjà une installation qui fonctionne, mettez **votre** `SECRET_KEY_BASE` existante dans `.env` **avant** le premier `docker-compose up` :

```bash
echo "SECRET_KEY_BASE=votre_clé_existante" > .env
chmod 600 .env
```

### Accès

```
🌐 https://nexus.bestcash.me
🖥  Dashboard Traefik : http://127.0.0.1:8081 (local uniquement, ou via tunnel SSH)
```

## 📋 Commandes Principales

### Avec Make (recommandé)

```bash
make help           # Voir toutes les commandes
make start          # Démarrer les services
make stop           # Arrêter les services
make restart        # Redémarrer
make logs           # Voir les logs
make status         # Statut des services
```

### Avec Docker Compose

```bash
docker-compose up -d        # Démarrer
docker-compose down         # Arrêter
docker-compose restart      # Redémarrer
docker-compose logs -f      # Logs
docker-compose ps           # Statut
```

## 🔐 Sécurité

### Certificat SSL (Nginx)

✅ Déjà configuré avec Certbot + Let's Encrypt. Renouvellement automatique via `certbot.timer`.

```bash
sudo certbot certificates
```

### ⚠️ Important : SECRET_KEY_BASE

Le fichier `.env` contient la **SECRET_KEY_BASE** (clé de chiffrement Rails).

```
❌ NE JAMAIS COMMITER .env en Git
❌ NE JAMAIS PARTAGER cette clé
❌ NE JAMAIS CHANGER la clé (sans raison valide)
❌ NE JAMAIS PERDRE ce fichier

Si SECRET_KEY_BASE change :
  - Toutes les sessions seront invalidées
  - Les données chiffrées deviendront illisibles
  - Les utilisateurs devront se reconnecter
```

```bash
chmod 600 .env
cp .env .env.backup && chmod 600 .env.backup
```

## 💾 Base de Données PostgreSQL (intégrée)

La base tourne **dans** le container OpenProject ; ses données sont persistées sur l'hôte dans `/var/lib/openproject/pgdata`.

### Sauvegarde

```bash
make backup
# ou manuellement :
docker-compose exec -T openproject su postgres -c "pg_dump openproject" > backup.sql
```

### Restauration

```bash
docker-compose exec -T openproject su postgres -c "psql openproject" < backup.sql
```

### Accès Direct

```bash
make db
# ou :
docker-compose exec openproject su postgres -c "psql openproject"

# Une fois connecté :
\dt          # Voir les tables
\l           # Voir les bases de données
```

## 🧪 Dépannage

### ERR_TOO_MANY_REDIRECTS (boucle de redirection)

Avec `OPENPROJECT_HTTPS: "true"`, OpenProject redirige vers https toute requête
qu'il croit être en http. Comme le TLS est terminé par Nginx, il faut que
l'en-tête `X-Forwarded-Proto: https` arrive jusqu'à OpenProject — c'est le rôle
du middleware Traefik `op-forwarded-proto` dans `docker-compose.yml` :

```yaml
- "traefik.http.routers.openproject.middlewares=op-forwarded-proto"
- "traefik.http.middlewares.op-forwarded-proto.headers.customrequestheaders.X-Forwarded-Proto=https"
```

Après modification : `docker-compose up -d` (recrée les containers), puis
vider les cookies du site dans le navigateur et réessayer.

Vérifiez aussi que le bloc Nginx transmet bien le Host :

```nginx
location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
}
```

(Sans `Host $host`, Traefik ne matche pas le routeur → 404.)

### Erreur : "Connection refused" / 502 Bad Gateway

1. Vérifier les containers :

```bash
make status
docker ps
```

2. Vérifier que Traefik écoute sur 8080 :

```bash
curl -H "Host: nexus.bestcash.me" http://127.0.0.1:8080/
```

3. Vérifier Nginx :

```bash
sudo systemctl status nginx
sudo nginx -t
```

### Container OpenProject ne démarre pas

```bash
make logs
docker-compose restart openproject
```

Au premier démarrage, l'initialisation de la base peut prendre plusieurs minutes — patientez avant de conclure à un problème.

### Traefik ne route pas vers OpenProject

```bash
# Vérifier les logs Traefik
docker-compose logs -f traefik

# Vérifier le routeur dans le dashboard (local)
curl http://127.0.0.1:8081/api/http/routers
```

### Permissions sur /var/lib/openproject

```bash
sudo ls -la /var/lib/openproject/
# pgdata et assets doivent exister et être accessibles en écriture par le container
```

## 🔄 Maintenance

### Redémarrage Nginx

```bash
make nginx-reload
```

### Mise à jour Docker

```bash
make backup                 # TOUJOURS sauvegarder avant
docker-compose pull
docker-compose up -d
```

### Nettoyage

```bash
docker system prune -a
```

## 📈 Monitoring

- Logs limités à 10MB par fichier, max 3 fichiers (`json-file`).
- `docker stats` pour mémoire/CPU, `docker system df` pour le disque.

## 🔗 Ressources

- **OpenProject** : https://docs.openproject.org/
- **Traefik** : https://doc.traefik.io/traefik/
- **Nginx** : https://nginx.org/
- **Docker** : https://docs.docker.com/

---

**Dernière mise à jour** : 2026-09-15
**OpenProject Version** : 17 (image tout-en-un)
**Stack** : Docker + Traefik + Nginx + PostgreSQL (intégré)
