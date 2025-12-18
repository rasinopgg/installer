#!/usr/bin/env bash
set -euo pipefail

# =========================
#  Pterodactyl Panel Installer
# =========================

clear

# ---- Colors ----
GREEN="\e[1;32m"; RED="\e[1;31m"; YELLOW="\e[1;33m"; BLUE="\e[1;34m"; NC="\e[0m"

# ---- Root check ----
if [[ "$EUID" -ne 0 ]]; then
  echo -e "${RED}❌ Please run this script as root.${NC}"; exit 1
fi

# ---- Input ----
read -rp "Enter your domain (e.g., panel.example.com): " DOMAIN
read -rp "Enter DB name [panel]: " DB_NAME; DB_NAME=${DB_NAME:-panel}
read -rp "Enter DB user [pterodactyl]: " DB_USER; DB_USER=${DB_USER:-pterodactyl}
DB_PASS=$(openssl rand -base64 16)
PHP_VERSION="8.3"

# ---- OS Detection ----
OS=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)

echo -e "${BLUE}ℹ Detected OS: $OS ($CODENAME)${NC}"

# ---- Base deps ----
apt update
apt install -y curl ca-certificates gnupg lsb-release software-properties-common unzip git sudo cron

# ---- PHP Repo ----
if [[ "$OS" == "ubuntu" ]]; then
  add-apt-repository -y ppa:ondrej/php
elif [[ "$OS" == "debian" ]]; then
  curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg
  echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ $CODENAME main" \
    > /etc/apt/sources.list.d/sury-php.list
else
  echo -e "${RED}Unsupported OS${NC}"; exit 1
fi

# ---- Redis Repo ----
curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis.gpg
echo "deb [signed-by=/usr/share/keyrings/redis.gpg] https://packages.redis.io/deb $CODENAME main" \
  > /etc/apt/sources.list.d/redis.list

apt update

# ---- Install services ----
apt install -y \
  nginx mariadb-server redis-server \
  php${PHP_VERSION} php${PHP_VERSION}-{cli,fpm,common,mysql,mbstring,bcmath,xml,zip,curl,gd}

# ---- Composer ----
if ! command -v composer &>/dev/null; then
  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
fi

# ---- Panel download ----
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl

curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzf panel.tar.gz
rm -f panel.tar.gz

chmod -R 755 storage bootstrap/cache

# ---- Database ----
mysql <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF

# ---- ENV ----
cp .env.example .env
sed -i "s|APP_URL=.*|APP_URL=https://${DOMAIN}|" .env
sed -i "s|DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|" .env
sed -i "s|DB_USERNAME=.*|DB_USERNAME=${DB_USER}|" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|" .env

# ---- Install deps ----
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
php artisan key:generate --force
php artisan migrate --seed --force

# ---- Permissions ----
chown -R www-data:www-data /var/www/pterodactyl

# ---- Cron ----
systemctl enable --now cron
(crontab -l 2>/dev/null; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -

# ---- SSL (self-signed) ----
mkdir -p /etc/certs/panel
openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
  -keyout /etc/certs/panel/privkey.pem \
  -out /etc/certs/panel/fullchain.pem \
  -subj "/CN=${DOMAIN}"

# ---- Nginx ----
cat > /etc/nginx/sites-available/pterodactyl.conf <<EOF
server {
  listen 80;
  server_name ${DOMAIN};
  return 301 https://\$host\$request_uri;
}

server {
  listen 443 ssl http2;
  server_name ${DOMAIN};

  root /var/www/pterodactyl/public;
  index index.php;

  ssl_certificate /etc/certs/panel/fullchain.pem;
  ssl_certificate_key /etc/certs/panel/privkey.pem;

  client_max_body_size 100m;

  location / {
    try_files \$uri \$uri/ /index.php?\$query_string;
  }

  location ~ \\.php$ {
    include fastcgi_params;
    fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
  }
}
EOF

ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
nginx -t && systemctl restart nginx

# ---- Queue worker ----
cat > /etc/systemd/system/pteroq.service <<'EOF'
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --sleep=3 --tries=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now redis-server pteroq.service

# ---- Finish ----
clear

cat <<'BANNER'
╔══════════════════════════════════════════════════════╗
║              🚀 PTERODACTYL PANEL READY             ║
╚══════════════════════════════════════════════════════╝
BANNER

sleep 0.4

echo -e "${BLUE}Finalizing services${NC}"
for i in {1..6}; do echo -ne "${BLUE}▮${NC}"; sleep 0.15; done

echo -e "
"

cat <<EOF
${GREEN}✔ Installation Completed Successfully!${NC}

${YELLOW}🌐 Panel URL:${NC}      https://${DOMAIN}
${YELLOW}📁 Install Path:${NC}   /var/www/pterodactyl
${YELLOW}🐘 PHP Version:${NC}    ${PHP_VERSION}
${YELLOW}🗄 Database:${NC}       ${DB_NAME}
${YELLOW}👤 DB User:${NC}        ${DB_USER}
${YELLOW}🔐 DB Password:${NC}    ${DB_PASS}

${BLUE}Next Steps:${NC}
  ➤ Create admin user:
    ${GREEN}cd /var/www/pterodactyl && php artisan p:user:make${NC}

  ➤ (Recommended) Replace self‑signed SSL with Let's Encrypt

${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
EOF
