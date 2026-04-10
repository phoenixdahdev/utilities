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
./create-pg-database                                              # interactive wizard
./create-pg-database --list-users                                 # show all roles + access
./create-pg-database --change-password                            # change a user's password
./create-pg-database --change-password --user myuser              # change specific user's password
./create-pg-database --db-name myapp --user myuser --orm prisma   # partial flags
./create-pg-database --db-name myapp --user myuser --password secret --orm prisma --non-interactive
```

**Features:**
- Detects PostgreSQL version, port, connections, existing databases and roles
- Creates role + database + grants in one flow
- ORM-aware permissions: `prisma`, `typeorm`, `sequelize`, `django`, `generic`
- `--owner` mode for full database ownership
- `--existing-user` to skip role creation
- `--list-users` shows all roles with login/superuser/createdb flags, owned databases, and database access map
- `--change-password` interactive password change with confirmation
- Prints ready-to-paste connection strings (Prisma `.env`, Django `settings.py`, TypeORM, Sequelize)

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

# 2. SSH in as deploy user, create a database
./create-pg-database

# 3. Get SSL
sudo certbot --nginx -d yourdomain.com
```
