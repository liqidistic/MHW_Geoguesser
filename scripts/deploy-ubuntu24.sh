#!/usr/bin/env bash
#
# Déploiement Ubuntu 24.04 : Node + MySQL + Nginx + HTTPS (Let's Encrypt)
# Domaine : cratec.fr → 217.160.173.156 (enregistrement DNS A obligatoire avant Certbot)
# Code : https://github.com/liqidistic/MHW_Geoguesser
#
# Usage sur le serveur :
#   sudo apt install -y curl
#   curl -fsSL https://raw.githubusercontent.com/liqidistic/MHW_Geoguesser/master/scripts/deploy-ubuntu24.sh | sudo bash
#   (ou copier ce fichier et : sudo bash deploy-ubuntu24.sh)
#
# Variables optionnelles :
#   CERTBOT_EMAIL   e-mail Let's Encrypt (défaut : admin@cratec.fr)
#   SQL_DUMP        chemin ou nom du dump (défaut : monster_hunter_geoguesser_light.sql)
#   GIT_BRANCH      branche Git (défaut : master)
#
set -euo pipefail

DOMAIN="${DOMAIN:-cratec.fr}"
GIT_REPO="${GIT_REPO:-https://github.com/liqidistic/MHW_Geoguesser.git}"
GIT_BRANCH="${GIT_BRANCH:-master}"
APP_DIR="${APP_DIR:-/var/www/mhw-geoguesser}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-admin@cratec.fr}"
SQL_DUMP="${SQL_DUMP:-monster_hunter_geoguesser_light.sql}"

if [[ "${EUID:-0}" -ne 0 ]]; then
  echo "Lance ce script en root : sudo bash $0" >&2
  exit 1
fi

echo "=== Mise à jour système ==="
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
apt-get install -y curl ca-certificates git ufw nginx mysql-server

echo "=== Pare-feu ==="
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable || true

echo "=== Node.js 22 (NodeSource) ==="
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

echo "=== Mot de passe MySQL applicatif ==="
DB_PASS_FILE="/etc/mhw-geoguesser.dbpassword"
if [[ -f "$DB_PASS_FILE" ]]; then
  MYSQL_APP_PASSWORD="$(cat "$DB_PASS_FILE")"
  echo "Réutilisation du mot de passe existant ($DB_PASS_FILE)."
else
  MYSQL_APP_PASSWORD="$(openssl rand -base64 24)"
  umask 077
  echo -n "$MYSQL_APP_PASSWORD" >"$DB_PASS_FILE"
  umask 022
  echo "Mot de passe MySQL pour mhw_app enregistré dans $DB_PASS_FILE"
fi

echo "=== Base MySQL ==="
sql_escape() { printf '%s' "$1" | sed "s/'/''/g"; }
PW_SQL_ESC="$(sql_escape "$MYSQL_APP_PASSWORD")"
mysql --protocol=socket -u root <<EOSQL
CREATE DATABASE IF NOT EXISTS monster_hunter_geoguesser CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'mhw_app'@'localhost' IDENTIFIED BY '${PW_SQL_ESC}';
ALTER USER 'mhw_app'@'localhost' IDENTIFIED BY '${PW_SQL_ESC}';
GRANT ALL PRIVILEGES ON monster_hunter_geoguesser.* TO 'mhw_app'@'localhost';
FLUSH PRIVILEGES;
EOSQL

echo "=== Dépôt Git ==="
if [[ -d "$APP_DIR" && ! -d "$APP_DIR/.git" ]]; then
  echo "Répertoire occupé sans Git : $APP_DIR" >&2
  exit 1
fi
if [[ ! -d "$APP_DIR/.git" ]]; then
  git clone --branch "$GIT_BRANCH" --depth 1 "$GIT_REPO" "$APP_DIR"
else
  git -C "$APP_DIR" fetch --depth 1 origin "$GIT_BRANCH"
  git -C "$APP_DIR" checkout "$GIT_BRANCH"
  git -C "$APP_DIR" pull --ff-only origin "$GIT_BRANCH"
fi

SQL_PATH="$APP_DIR/$SQL_DUMP"
if [[ ! -f "$SQL_PATH" ]]; then
  echo "Fichier SQL introuvable : $SQL_PATH (SQL_DUMP=$SQL_DUMP)" >&2
  exit 1
fi
echo "=== Import SQL : $SQL_PATH ==="
mysql monster_hunter_geoguesser <"$SQL_PATH"

echo "=== Build frontend + deps ==="
# www-data a souvent HOME=/var/www ; un npm lancé en root y laisse un cache propriétaire root → EACCES
if [[ -d /var/www/.npm ]]; then
  chown -R www-data:www-data /var/www/.npm
fi
chown -R www-data:www-data "$APP_DIR"
cd "$APP_DIR"
rm -rf node_modules dist
# Cache + config npm dans le projet (évite /var/www/.npm mélangé avec d’autres apps)
sudo -u www-data env HOME="$APP_DIR" npm ci
sudo -u www-data env HOME="$APP_DIR" npm run build

echo "=== Fichier d'environnement API ==="
umask 077
cat >/etc/mhw-geoguesser.env <<EOF
NODE_ENV=production
MYSQL_HOST=localhost
MYSQL_USER=mhw_app
MYSQL_PASSWORD=${MYSQL_APP_PASSWORD}
MYSQL_DATABASE=monster_hunter_geoguesser
EOF
chmod 600 /etc/mhw-geoguesser.env
umask 022

echo "=== systemd : mhw-api ==="
cat >/etc/systemd/system/mhw-api.service <<EOF
[Unit]
Description=MHW Geoguesser API (Express)
After=network.target mysql.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=${APP_DIR}
EnvironmentFile=/etc/mhw-geoguesser.env
ExecStart=/usr/bin/node server/index.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now mhw-api.service

echo "=== Nginx (HTTP d'abord, Certbot ensuite) ==="
cat >/etc/nginx/sites-available/mhw-geoguesser <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    root ${APP_DIR}/dist;
    index index.html;

    location /api/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        client_max_body_size 12M;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF

ln -sf /etc/nginx/sites-available/mhw-geoguesser /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

echo "=== Certbot (HTTPS) ==="
apt-get install -y certbot python3-certbot-nginx
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$CERTBOT_EMAIL" --redirect

echo "=== Terminé ==="
echo "Site : https://${DOMAIN}"
echo "Mot de passe BDD (copie sécurisée) : fichier $DB_PASS_FILE"
echo "Logs API : journalctl -u mhw-api -f"
