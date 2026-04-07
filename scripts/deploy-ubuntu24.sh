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
#   SKIP_SQL=1      ne pas réimporter le fichier SQL (réparation, base déjà remplie)
#   SKIP_CERTBOT=1  ne pas lancer Let’s Encrypt (test HTTP d’abord)
#   INCLUDE_WWW=0   certificat et vhost pour cratec.fr seulement (si pas d’enregistrement DNS www)
#
set -euo pipefail

DOMAIN="${DOMAIN:-cratec.fr}"
INCLUDE_WWW="${INCLUDE_WWW:-1}"
GIT_REPO="${GIT_REPO:-https://github.com/liqidistic/MHW_Geoguesser.git}"
GIT_BRANCH="${GIT_BRANCH:-master}"
APP_DIR="${APP_DIR:-/var/www/mhw-geoguesser}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-admin@cratec.fr}"
SQL_DUMP="${SQL_DUMP:-monster_hunter_geoguesser_light.sql}"
SKIP_SQL="${SKIP_SQL:-0}"
SKIP_CERTBOT="${SKIP_CERTBOT:-0}"

if [[ "$INCLUDE_WWW" == "1" ]]; then
  NGX_SERVER_NAME="${DOMAIN} www.${DOMAIN}"
else
  NGX_SERVER_NAME="${DOMAIN}"
  echo "INCLUDE_WWW=0 : uniquement ${DOMAIN} (ajoute un A pour www chez IONOS puis INCLUDE_WWW=1 pour étendre le certificat)."
fi

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
  # Le dépôt est en général propriété de www-data ; Git refuse root si safe.directory absent
  _git() { git -c safe.directory="$APP_DIR" -C "$APP_DIR" "$@"; }
  _git fetch --depth 1 origin "$GIT_BRANCH"
  _git checkout "$GIT_BRANCH"
  _git pull --ff-only origin "$GIT_BRANCH"
fi

SQL_PATH="$APP_DIR/$SQL_DUMP"
if [[ ! -f "$SQL_PATH" ]]; then
  echo "Fichier SQL introuvable : $SQL_PATH (SQL_DUMP=$SQL_DUMP)" >&2
  exit 1
fi
if [[ "$SKIP_SQL" == "1" ]]; then
  echo "=== SKIP_SQL=1 : import SQL ignoré (la base existante est conservée) ==="
else
  echo "=== Import SQL : $SQL_PATH ==="
  set +e
  mysql monster_hunter_geoguesser <"$SQL_PATH" 2>/tmp/mhw-geoguesser-sql.err
  _sql_st=$?
  set -e
  if [[ "$_sql_st" -ne 0 ]]; then
    if grep -qE 'already exists|\(42S01\)' /tmp/mhw-geoguesser-sql.err; then
      echo "=== Import SQL partiellement ignoré (schéma/données déjà présents) — poursuite ==="
      tail -5 /tmp/mhw-geoguesser-sql.err || true
    else
      echo "=== Échec import SQL ===" >&2
      cat /tmp/mhw-geoguesser-sql.err >&2
      exit 1
    fi
  fi
fi

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
systemctl enable mhw-api.service
systemctl restart mhw-api.service

echo "=== Nginx (HTTP d'abord, Certbot ensuite) ==="
cat >/etc/nginx/sites-available/mhw-geoguesser <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${NGX_SERVER_NAME};

    root ${APP_DIR}/dist;
    index index.html;

    # ^~ : toutes les requêtes /api* passent au Node (évite qu’un fichier statique masque l’API)
    location ^~ /api {
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
systemctl enable nginx
systemctl restart nginx

echo "=== Certbot (HTTPS) ==="
if [[ "$SKIP_CERTBOT" == "1" ]]; then
  echo "SKIP_CERTBOT=1 : pas de Let’s Encrypt. Teste http://${DOMAIN}/ puis relance sans SKIP_CERTBOT."
else
  apt-get install -y certbot python3-certbot-nginx
  if [[ "$INCLUDE_WWW" == "1" ]]; then
    certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" --non-interactive --agree-tos -m "$CERTBOT_EMAIL" --redirect
  else
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$CERTBOT_EMAIL" --redirect
  fi
fi

echo "=== Terminé ==="
if [[ "$INCLUDE_WWW" == "1" ]]; then
  echo "Sites : https://${DOMAIN} et https://www.${DOMAIN} (HTTP seul si SKIP_CERTBOT=1)"
  echo "DNS : A pour @ et www → IP du VPS."
else
  echo "Site : https://${DOMAIN} seulement. Pour www : créer l’enregistrement DNS puis INCLUDE_WWW=1 et certbot --nginx -d ${DOMAIN} -d www.${DOMAIN} --expand"
fi
echo "Mot de passe BDD (copie sécurisée) : fichier $DB_PASS_FILE"
echo "Logs API : journalctl -u mhw-api -f"
