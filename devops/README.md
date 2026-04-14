# devops/

Scripts for provisioning machines — local dev environments and production servers.

All scripts are interactive wizards by default. They detect what's already installed, let you pick components, show a review before executing, and are safe to re-run (idempotent).

## Scripts

### `pc-setup`

Sets up a local development machine (Ubuntu/Debian).

```bash
./pc-setup           # interactive wizard
./pc-setup --all     # install everything, no prompts
```

**Components:**

| Category | What gets installed |
|---|---|
| Core | Zsh, Oh My Zsh (syntax-highlighting + autosuggestions), bundled `.zshrc`, Ghostty terminal (snap) |
| Languages | NVM + Node.js LTS, pnpm, Bun, Python3 + pip + venv |
| Services | PostgreSQL (PGDG), nginx, certbot, Docker, Redis, UFW |

Your `.zshrc` is **embedded in the script** — robbyrussell theme, plugins, nvm/pnpm/bun paths. On a fresh machine it restores the full shell config automatically.

---

### `server-setup`

Provisions a production server (Ubuntu/Debian). Run as root or a sudo user.

```bash
./server-setup                          # interactive wizard
./server-setup --all                    # install everything
./server-setup --deploy-user myapp      # custom deploy user name
```

**Modules:**

| Module | What it does |
|---|---|
| System | apt update/upgrade, git, curl, wget, htop, jq, build-essential, timezone, locale |
| Security | deploy user with sudo, SSH hardening (no root login, no password auth), UFW (SSH + HTTP/S), fail2ban (SSH jail), unattended security upgrades, raised file descriptor limits (65536) |
| Swap | auto-sized swap file (1–4GB based on RAM), swappiness tuned to 10 |
| Node.js | NVM + LTS + PM2 with systemd startup hook (installed for deploy user) |
| Python | python3 + pip + venv |
| PostgreSQL | latest from PGDG repo, started + enabled |
| nginx | installed, server_tokens off, security headers snippet, gzip, client_max_body_size 64m |
| Certbot | Let's Encrypt + python3-certbot-nginx + auto-renewal timer |
| Redis | installed, bound to localhost only |
| Docker | Docker Engine + Compose + Buildx, deploy user added to docker group |
| Logrotate | daily rotation for `/var/log/apps/*.log`, 14 day retention, compressed |

---

### `create-pg-database`

Interactive PostgreSQL database and user provisioner.

```bash
# Create database + user
./create-pg-database                                              # interactive wizard
./create-pg-database --db-name myapp --user myuser --orm prisma   # partial flags
./create-pg-database --db-name myapp --user myuser --password secret --orm prisma --non-interactive

# Inspect
./create-pg-database --list-users                                 # all roles + access map
./create-pg-database --list-databases                             # all databases + sizes + table counts
./create-pg-database --db-info --db-name myapp                    # tables, indexes, extensions, roles
./create-pg-database --connection-test --db-name myapp --user mu  # test connectivity + privileges

# Manage users
./create-pg-database --change-password                            # change a user's password
./create-pg-database --change-password --user myuser              # change specific user
./create-pg-database --drop-user --user olduser                   # drop a role

# Manage databases
./create-pg-database --drop-database --db-name oldapp             # drop a database (double confirm)

# Backup & restore
./create-pg-database --backup --db-name myapp                     # backup to ./myapp_<date>.dump
./create-pg-database --backup --db-name myapp --file /tmp/bk.dump --format plain
./create-pg-database --restore --db-name myapp --file bk.dump     # restore from backup
```

**Commands:**

| Command | What it does |
|---|---|
| *(default)* | Interactive wizard — create database + user with ORM-aware grants |
| `--list-users` | All roles with login/superuser/createdb flags, owned databases, access map |
| `--list-databases` | All databases with size, owner, table counts |
| `--db-info` | Deep inspect: tables with sizes + row estimates, indexes, extensions, connected roles |
| `--connection-test` | Verify user can connect — checks server, auth, SELECT, schema access, TEMP tables |
| `--change-password` | Interactive password change with confirmation |
| `--drop-database` | Drop database with size/table warning + double confirmation (type name to confirm) |
| `--drop-user` | Drop role, auto-reassigns owned objects, prevents dropping `postgres` |
| `--backup` | `pg_dump` wrapper — custom/plain/directory formats, auto-named output files |
| `--restore` | `pg_restore`/`psql` wrapper — auto-detects format, creates database if missing |

**Features:**
- ORM-aware permissions: `prisma`, `typeorm`, `sequelize`, `django`, `generic`
- `--owner` mode for full database ownership
- `--existing-user` to skip role creation
- Prints ready-to-paste connection strings (Prisma `.env`, Django `settings.py`, TypeORM, Sequelize)

---

### `deploy-app`

End-to-end app deployment wizard. Ties everything together: git clone → install → build → `.env` → database → nginx site → SSL → pm2.

```bash
# Deploy a new app (interactive)
./deploy-app

# Partial flags
./deploy-app --name myapp --repo git@github.com:me/myapp.git --domain myapp.com

# Manage deployed apps
./deploy-app --list                         # all deployed apps with status
./deploy-app --redeploy myapp               # git pull + install + build + reload
./deploy-app --logs myapp                   # tail pm2 logs
./deploy-app --restart myapp                # pm2 restart
./deploy-app --remove myapp                 # tear down (nginx + pm2 + files)
```

**Auto-detection:**
- Framework from repo files: Node.js (`package.json`), Python (`requirements.txt`/`pyproject.toml`), Docker (`Dockerfile`), Static (`index.html`)
- Node sub-framework: Next.js, Vite, Astro, SvelteKit, Nuxt, Express, Fastify, NestJS
- Package manager: pnpm, yarn, bun, npm (from lockfile)
- Suggests install / build / start commands per framework
- DNS check: verifies the domain points at this server before requesting SSL

**Commands:**

| Command | What it does |
|---|---|
| *(default)* | Full wizard: source → framework → domain → SSL → DB → .env → deploy |
| `--list` | All deployed apps with nginx/pm2 status and domain |
| `--redeploy NAME` | Quick redeploy: git pull, re-run install/build from saved state, pm2 reload |
| `--logs NAME` | Tail pm2 logs for an app |
| `--restart NAME` | `pm2 restart` an app |
| `--remove NAME` | Remove nginx config, pm2 process, and `/var/www/<name>` (double confirm) |

**What it writes:**
- `/var/www/<name>/` — source code
- `/var/www/<name>/.env` — env vars (chmod 600, with auto-appended `DATABASE_URL` and `PORT`)
- `/var/www/<name>/.deploy-state` — saved config for `--redeploy`
- `/etc/nginx/sites-available/<name>` — site config (reverse proxy or static files)
- `/etc/nginx/sites-enabled/<name>` — symlink
- Let's Encrypt cert for the domain (via `certbot --nginx`)
- pm2 process + `pm2 save` for boot persistence

---

## Typical workflow

**New dev machine:**
```bash
./pc-setup
```

**New production server:**
```bash
# 1. Provision the server
./server-setup

# 2. Deploy an app end-to-end (creates DB, nginx, SSL, pm2)
./deploy-app
```

**Deploying subsequent updates:**
```bash
./deploy-app --redeploy myapp
```
