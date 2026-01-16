#!/bin/bash
set -euo pipefail

# ---------------------------
# Helpers
# ---------------------------
show_help() {
cat <<EOF
Usage: $0 [options]

Options:
  --postgres               Use PostgreSQL (required)
  --db-name NAME           Database name
  --user NAME              Database user
  --password PASSWORD      Database user password
  --orm ORM                prisma | typeorm | sequelize | django | generic
  --owner                  Make user database owner
  --existing-user          Use existing PostgreSQL user
  --help                   Show this help message
EOF
exit 0
}

# ---------------------------
# Defaults
# ---------------------------
DB_NAME=""
DB_USER=""
DB_PASS=""
ORM=""
MAKE_OWNER="n"
USE_EXISTING_USER="n"
USE_POSTGRES="n"

# ---------------------------
# Parse flags
# ---------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --postgres)
      USE_POSTGRES="y"; shift ;;
    --db-name)
      DB_NAME="$2"; shift 2 ;;
    --user)
      DB_USER="$2"; shift 2 ;;
    --password)
      DB_PASS="$2"; shift 2 ;;
    --orm)
      ORM="$2"; shift 2 ;;
    --owner)
      MAKE_OWNER="y"; shift ;;
    --existing-user)
      USE_EXISTING_USER="y"; shift ;;
    --help)
      show_help ;;
    *)
      echo "Unknown option: $1"
      show_help ;;
  esac
done

[[ "$USE_POSTGRES" != "y" ]] && {
  echo "Error: --postgres flag is required."
  exit 1
}

# ---------------------------
# Interactive fallbacks
# ---------------------------
[[ -z "$DB_NAME" ]] && read -r -p "Enter database name: " DB_NAME
[[ -z "$DB_USER" ]] && read -r -p "Enter database user: " DB_USER

if [[ "$USE_EXISTING_USER" != "y" && -z "$DB_PASS" ]]; then
  read -rs -p "Enter password for user: " DB_PASS
  echo
fi

[[ -z "$ORM" ]] && read -r -p "ORM (prisma/typeorm/sequelize/django/generic): " ORM

# ---------------------------
# Create role (safe in transaction)
# ---------------------------
if [[ "$USE_EXISTING_USER" != "y" ]]; then
sudo -u postgres psql <<EOF
DO \$\$
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_roles WHERE rolname = '${DB_USER}'
  ) THEN
    CREATE ROLE "${DB_USER}" LOGIN PASSWORD '${DB_PASS}';
  END IF;
END
\$\$;
EOF
fi

# ---------------------------
# Create database (MUST NOT be in transaction)
# ---------------------------
DB_EXISTS=$(sudo -u postgres psql -tAc \
  "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'")

if [[ -z "$DB_EXISTS" ]]; then
  sudo -u postgres psql -c "CREATE DATABASE \"${DB_NAME}\";"
fi

# ---------------------------
# Ownership or privileges
# ---------------------------
if [[ "$MAKE_OWNER" == "y" ]]; then
  sudo -u postgres psql -c \
    "ALTER DATABASE \"${DB_NAME}\" OWNER TO \"${DB_USER}\";"
  echo "User '${DB_USER}' set as owner of database '${DB_NAME}'."
  exit 0
fi

sudo -u postgres psql -c \
  "GRANT CONNECT ON DATABASE \"${DB_NAME}\" TO \"${DB_USER}\";"

case "$ORM" in
  prisma|typeorm|sequelize|django)
sudo -u postgres psql -d "${DB_NAME}" <<EOF
GRANT USAGE, CREATE ON SCHEMA public TO "${DB_USER}";

GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA public TO "${DB_USER}";

GRANT USAGE, SELECT, UPDATE
ON ALL SEQUENCES IN SCHEMA public TO "${DB_USER}";

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "${DB_USER}";

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO "${DB_USER}";
EOF
    ;;
  generic)
sudo -u postgres psql -d "${DB_NAME}" <<EOF
GRANT USAGE ON SCHEMA public TO "${DB_USER}";

GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA public TO "${DB_USER}";

GRANT USAGE, SELECT
ON ALL SEQUENCES IN SCHEMA public TO "${DB_USER}";

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "${DB_USER}";
EOF
    ;;
  *)
    echo "Invalid ORM specified: $ORM"
    exit 1 ;;
esac

echo "Database '${DB_NAME}' configured for user '${DB_USER}' using ORM '${ORM}'."
