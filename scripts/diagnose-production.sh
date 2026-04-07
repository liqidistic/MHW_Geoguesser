#!/usr/bin/env bash
# À lancer sur le serveur (sudo recommandé pour journalctl) :
#   curl -fsSL .../diagnose-production.sh | sudo bash
#   ou : sudo bash scripts/diagnose-production.sh
#
set +e
APP_DIR="${APP_DIR:-/var/www/mhw-geoguesser}"
DOMAIN="${DOMAIN:-cratec.fr}"

echo "========== Services =========="
systemctl is-active mysql nginx mhw-api 2>/dev/null || true
systemctl status mhw-api --no-pager -l 2>&1 | tail -n 15

echo ""
echo "========== Fichiers build =========="
ls -la "$APP_DIR/dist/index.html" 2>&1 || echo "dist/index.html introuvable — lance npm run build"

echo ""
echo "========== API Node (127.0.0.1:3000) =========="
code="$(curl -sS -o /tmp/_mhd_loc.json -w '%{http_code}' http://127.0.0.1:3000/api/locations 2>&1)"
echo "HTTP $code"
head -c 300 /tmp/_mhd_loc.json 2>/dev/null; echo

echo ""
echo "========== Nginx → API (HTTPS local, Host: $DOMAIN) =========="
code2="$(curl -skS -o /tmp/_mhd_loc2.json -w '%{http_code}' -H "Host: $DOMAIN" "https://127.0.0.1/api/locations" 2>&1)"
echo "HTTP $code2"
head -c 300 /tmp/_mhd_loc2.json 2>/dev/null; echo

echo ""
echo "========== Nginx → API (HTTPS local, Host: www.$DOMAIN) =========="
code3="$(curl -skS -o /tmp/_mhd_loc3.json -w '%{http_code}' -H "Host: www.$DOMAIN" "https://127.0.0.1/api/locations" 2>&1)"
echo "HTTP $code3 (si échec TLS : cert/nginx sans www)"
head -c 300 /tmp/_mhd_loc3.json 2>/dev/null; echo

echo ""
echo "========== DNS rapide (depuis ce serveur) =========="
command -v getent >/dev/null && getent hosts "www.$DOMAIN" || true

echo ""
echo "========== Bloc listen 443 : présence de /api =========="
if command -v nginx >/dev/null 2>&1; then
  if nginx -T 2>/dev/null | grep -q "listen 443.*ssl"; then
    if nginx -T 2>/dev/null | awk '/listen 443.*ssl/,/^}/' | grep -q "location.*api"; then
      echo "OK : un location / api apparaît dans la zone SSL (extrait approximatif)."
    else
      echo "ATTENTION : pas de 'location' api détecté près du bloc HTTPS — Certbot a peut‑être laissé un vhost incomplet."
      echo "Compare : sudo nginx -T | less   (cherche server { ... listen 443 ... })"
    fi
  else
    echo "Pas de listener 443 dans la config nginx -T (HTTPS non configuré ?)"
  fi
else
  echo "nginx non trouvé dans PATH"
fi

echo ""
echo "========== Derniers logs mhw-api =========="
journalctl -u mhw-api -n 25 --no-pager 2>/dev/null || true

echo ""
echo "========== Interprétation rapide =========="
echo "200 sur port 3000 mais pas via HTTPS → Nginx / Certbot (bloc 443)."
echo "Échec sur 3000 → MySQL, .env, ou crash Node (voir logs ci‑dessus)."
echo "dist/index.html manquant → npm run build non exécuté ou erreur."
