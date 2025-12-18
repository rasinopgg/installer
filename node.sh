#!/bin/bash
set -e

# ==============================
#   Nodes Install – Wings Setup
# ==============================

# ---- Colors ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ---- UI Helpers ----
print_header() {
    echo -e "\n${BLUE}──────────────────────────────────────────────${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${BLUE}──────────────────────────────────────────────${NC}\n"
}

print_status()  { echo -e "${YELLOW}→ $1...${NC}"; }
print_success() { echo -e "${GREEN}✔ $1${NC}"; }
print_error()   { echo -e "${RED}✖ $1${NC}"; }

check_success() {
    if [ $? -eq 0 ]; then
        print_success "$1"
    else
        print_error "$2"
        exit 1
    fi
}

# ---- Welcome ----
clear
echo -e "${BLUE}──────────────────────────────────────────────${NC}"
echo -e "${CYAN}            NODES INSTALL – WINGS${NC}"
echo -e "${BLUE}──────────────────────────────────────────────${NC}\n"

# ---- Root Check ----
if [ "$EUID" -ne 0 ]; then
    print_error "Run this installer as root"
    exit 1
fi

print_header "INITIALIZING NODE INSTALLATION"

# ------------------------
# 1. Docker Installation
# ------------------------
print_header "INSTALLING DOCKER"

print_status "Downloading Docker (stable)"
curl -sSL https://get.docker.com | CHANNEL=stable bash > /dev/null 2>&1
check_success "Docker installed" "Docker installation failed"

print_status "Starting Docker service"
systemctl enable --now docker > /dev/null 2>&1
check_success "Docker service running" "Docker service failed"

# ------------------------
# 2. GRUB Configuration
# ------------------------
print_header "SYSTEM CONFIGURATION"

GRUB_FILE="/etc/default/grub"
if [ -f "$GRUB_FILE" ]; then
    print_status "Applying GRUB swap accounting"
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="swapaccount=1"/' "$GRUB_FILE"
    update-grub > /dev/null 2>&1
    check_success "GRUB updated" "GRUB update failed"
else
    print_status "GRUB file not found, skipping"
fi

# ------------------------
# 3. Wings Installation
# ------------------------
print_header "INSTALLING WINGS"

print_status "Creating directories"
mkdir -p /etc/pterodactyl
check_success "Directories ready" "Directory creation failed"

ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH="amd64"
else
    ARCH="arm64"
fi
print_success "Architecture: $ARCH"

print_status "Downloading Wings binary"
curl -L -o /usr/local/bin/wings \
"https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${ARCH}" \
> /dev/null 2>&1
check_success "Wings downloaded" "Wings download failed"

print_status "Setting executable permission"
chmod +x /usr/local/bin/wings
check_success "Permissions applied" "Permission setting failed"

# ------------------------
# 4. Wings Service
# ------------------------
print_header "CONFIGURING SERVICE"

print_status "Creating systemd service"
cat > /etc/systemd/system/wings.service <<EOF
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
ExecStart=/usr/local/bin/wings
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
check_success "Service file created" "Service file failed"

print_status "Reloading systemd"
systemctl daemon-reload > /dev/null 2>&1
systemctl enable wings > /dev/null 2>&1
check_success "Wings service enabled" "Service enable failed"

# ------------------------
# 5. SSL Certificate
# ------------------------
print_header "SSL SETUP"

print_status "Generating self-signed certificate"
mkdir -p /etc/certs/wing
openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
-keyout /etc/certs/wing/privkey.pem \
-out /etc/certs/wing/fullchain.pem \
-subj "/CN=NodesInstall" \
> /dev/null 2>&1
check_success "SSL certificate ready" "SSL generation failed"

# ------------------------
# 6. Helper Command
# ------------------------
print_header "HELPER COMMAND"

print_status "Creating 'wing' helper"
cat > /usr/local/bin/wing <<'EOF'
#!/bin/bash
echo "Wings Helper"
echo "────────────"
echo "Start:   systemctl start wings"
echo "Status:  systemctl status wings"
echo "Logs:    journalctl -u wings -f"
EOF
chmod +x /usr/local/bin/wing
check_success "Helper installed" "Helper creation failed"

# ------------------------
# Installation Complete
# ------------------------
print_header "INSTALLATION COMPLETE"

echo -e "${GREEN}Wings installed successfully.${NC}\n"

echo -e "${YELLOW}Next steps:${NC}"
echo -e "  ${CYAN}1.${NC} Add this node in your panel"
echo -e "  ${CYAN}2.${NC} Configure Wings"
echo -e "  ${CYAN}3.${NC} Start service:"
echo -e "     ${GREEN}systemctl start wings${NC}\n"

echo -e "${YELLOW}Useful commands:${NC}"
echo -e "  ${GREEN}wing${NC}"
echo -e "  ${GREEN}systemctl status wings${NC}"
echo -e "  ${GREEN}journalctl -u wings -f${NC}"

# ------------------------
# Optional Auto Config
# ------------------------
echo
read -rp "$(echo -e "${YELLOW}Auto-configure Wings now? (y/N): ${NC}")" AUTO

if [[ "$AUTO" =~ ^[Yy]$ ]]; then
    print_header "AUTO CONFIGURATION"

    read -rp "UUID: " UUID
    read -rp "Token ID: " TOKEN_ID
    read -rp "Token: " TOKEN
    read -rp "Panel URL: " REMOTE

    cat > /etc/pterodactyl/config.yml <<CFG
debug: false
uuid: ${UUID}
token_id: ${TOKEN_ID}
token: ${TOKEN}
api:
  host: 0.0.0.0
  port: 8080
  ssl:
    enabled: true
    cert: /etc/certs/wing/fullchain.pem
    key: /etc/certs/wing/privkey.pem
system:
  data: /var/lib/pterodactyl/volumes
remote: '${REMOTE}'
CFG

    systemctl restart wings
    print_success "Auto-configuration completed"
else
    echo -e "${YELLOW}Auto-configuration skipped.${NC}"
fi

echo
echo -e "${BLUE}──────────────────────────────────────────────${NC}"
echo -e "${CYAN}  Nodes Install finished successfully.${NC}"
echo -e "${BLUE}──────────────────────────────────────────────${NC}"
echo
