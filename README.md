# OpenProject + Traefik + Nginx Deployment

🌐 **English** | [Français](README.fr.md)

Deployment of OpenProject (all-in-one image with built-in PostgreSQL and memcached) behind Traefik as an internal reverse proxy, with Nginx (already configured) as the external reverse proxy handling SSL/TLS.

## 📂 Structure

```
~/openproject/
├── docker-compose.yml    # Docker Compose configuration (Traefik + OpenProject)
├── .env                  # Environment variables (CONFIDENTIAL — never in Git)
├── .env.example          # .env template (versioned)
├── .gitignore            # Files excluded from Git (.env, backups…)
├── setup.sh              # Automated installation script
├── Makefile              # Shortcut commands
├── README.md             # This documentation (English)
├── README.fr.md          # Documentation (French)
└── backups/              # PostgreSQL backups (created automatically)
```

## 🔧 Architecture

```
Internet (nexus.bestcash.me)
    ↓
Nginx (port 443 - SSL/TLS Certbot) [ALREADY CONFIGURED]
    ↓ (proxy_pass http://127.0.0.1:8080)
Traefik (host 8080 → entrypoint web :80)
    ↓ (routing Host(`nexus.bestcash.me`))
OpenProject (internal port 80 — all-in-one image)
    ├── Built-in PostgreSQL  → /var/lib/openproject/pgdata
    ├── Built-in Memcached
    └── Assets/attachments   → /var/lib/openproject/assets
```

Key points:

- **All-in-one image** `openproject/openproject:17`: PostgreSQL and memcached run INSIDE the container — no external database to create.
- **Persistence** on the host through bind mounts: `/var/lib/openproject/pgdata` (database) and `/var/lib/openproject/assets` (attachments).
- **Traefik** listens on host port `8080` (the same target as the existing Nginx `proxy_pass` — no Nginx change required). Dashboard on `127.0.0.1:8081` only.
- **`OPENPROJECT_HTTPS: "true"`**: OpenProject generates https URLs because TLS is terminated upstream by Nginx.
- **`OPENPROJECT_HOST__NAME`**: the double underscore is mandatory (`HOST__NAME`).

## ⚡ Prerequisites

- ✅ Docker + Docker Compose installed
- ✅ Nginx already configured with SSL/TLS (Certbot) and `proxy_pass http://127.0.0.1:8080`
- ✅ sudo access (to create `/var/lib/openproject`)

## 🚀 Quick Start

```bash
bash setup.sh
```

The script will:

1. ✅ Check Docker / Docker Compose
2. ✅ Create the data directories `/var/lib/openproject/{pgdata,assets}`
3. ✅ Create the `.env` file with a generated `SECRET_KEY_BASE` (or keep the existing one)
4. ✅ Start the containers (Traefik + OpenProject)

⏳ **First start**: OpenProject initializes its internal database — allow several minutes before the site responds.

### Manual .env setup

```bash
cp .env.example .env
chmod 600 .env
# then fill in SECRET_KEY_BASE (openssl rand -hex 64)
```

### Migrating from an existing installation

If you already have a working installation, put **your** existing `SECRET_KEY_BASE` in `.env` **before** the first `docker-compose up`:

```bash
echo "SECRET_KEY_BASE=your_existing_key" > .env
chmod 600 .env
```

### Access

```
🌐 https://nexus.bestcash.me
🖥  Traefik dashboard: http://127.0.0.1:8081 (local only, or via SSH tunnel)
```

## 📋 Main Commands

### With Make (recommended)

```bash
make help           # List all commands
make start          # Start the services
make stop           # Stop the services
make restart        # Restart
make logs           # Show logs
make status         # Service status
```

### With Docker Compose

```bash
docker-compose up -d        # Start
docker-compose down         # Stop
docker-compose restart      # Restart
docker-compose logs -f      # Logs
docker-compose ps           # Status
```

## 🔐 Security

### SSL certificate (Nginx)

✅ Already configured with Certbot + Let's Encrypt. Automatic renewal through `certbot.timer`.

```bash
sudo certbot certificates
```

### ⚠️ Important: SECRET_KEY_BASE

The `.env` file contains the **SECRET_KEY_BASE** (Rails encryption key).

```
❌ NEVER COMMIT .env to Git
❌ NEVER SHARE this key
❌ NEVER CHANGE the key (without a valid reason)
❌ NEVER LOSE this file

If SECRET_KEY_BASE changes:
  - All sessions will be invalidated
  - Encrypted data will become unreadable
  - Users will have to log in again
```

```bash
chmod 600 .env
cp .env .env.backup && chmod 600 .env.backup
```

## 💾 PostgreSQL Database (built-in)

The database runs **inside** the OpenProject container; its data is persisted on the host in `/var/lib/openproject/pgdata`.

### Backup

```bash
make backup
# or manually:
docker-compose exec -T openproject su postgres -c "pg_dump openproject" > backup.sql
```

### Restore

```bash
docker-compose exec -T openproject su postgres -c "psql openproject" < backup.sql
```

### Direct access

```bash
make db
# or:
docker-compose exec openproject su postgres -c "psql openproject"

# Once connected:
\dt          # List tables
\l           # List databases
```

## 🧪 Troubleshooting

### ERR_TOO_MANY_REDIRECTS (redirect loop)

With `OPENPROJECT_HTTPS: "true"`, OpenProject redirects to https any request it
believes is plain http. Since TLS is terminated by Nginx, the
`X-Forwarded-Proto: https` header must reach OpenProject — that is the job of
the `op-forwarded-proto` Traefik middleware in `docker-compose.yml`:

```yaml
- "traefik.http.routers.openproject.middlewares=op-forwarded-proto"
- "traefik.http.middlewares.op-forwarded-proto.headers.customrequestheaders.X-Forwarded-Proto=https"
```

After any change: `docker-compose up -d` (recreates the containers), then
clear the site's cookies in your browser and try again.

Also make sure the Nginx block forwards the Host header:

```nginx
location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
}
```

(Without `Host $host`, Traefik does not match the router → 404.)

### Error: "Connection refused" / 502 Bad Gateway

1. Check the containers:

```bash
make status
docker ps
```

2. Check that Traefik is listening on 8080:

```bash
curl -H "Host: nexus.bestcash.me" http://127.0.0.1:8080/
```

3. Check Nginx:

```bash
sudo systemctl status nginx
sudo nginx -t
```

### OpenProject container does not start

```bash
make logs
docker-compose restart openproject
```

On first start, database initialization can take several minutes — wait before concluding there is a problem.

### Traefik does not route to OpenProject

```bash
# Check Traefik logs
docker-compose logs -f traefik

# Check the router in the dashboard (local)
curl http://127.0.0.1:8081/api/http/routers
```

### Permissions on /var/lib/openproject

```bash
sudo ls -la /var/lib/openproject/
# pgdata and assets must exist and be writable by the container
```

## 🔄 Maintenance

### Restart Nginx

```bash
make nginx-reload
```

### Docker update

```bash
make backup                 # ALWAYS back up first
docker-compose pull
docker-compose up -d
```

### Cleanup

```bash
docker system prune -a
```

## 📈 Monitoring

- Logs capped at 10MB per file, 3 files max (`json-file`).
- `docker stats` for memory/CPU, `docker system df` for disk usage.

## 🔗 Resources

- **OpenProject**: https://docs.openproject.org/
- **Traefik**: https://doc.traefik.io/traefik/
- **Nginx**: https://nginx.org/
- **Docker**: https://docs.docker.com/

---

**Last updated**: 2026-09-15
**OpenProject Version**: 17 (all-in-one image)
**Stack**: Docker + Traefik + Nginx + PostgreSQL (built-in)
