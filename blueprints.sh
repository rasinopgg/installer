#!/bin/bash
# Blueprint Installer - Red Theme Version

# -----------------------------
# Colors for output (RED THEME)
# -----------------------------
RED='\033[1;31m'
DRED='\033[0;31m'
WHITE='\033[1;37m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# -----------------------------
# Utility Functions
# -----------------------------
print_header() {
    echo -e "\n${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE} $1 ${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_status() { echo -e "${YELLOW}⏳ $1...${NC}"; }
print_success() { echo -e "${WHITE}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${DRED}⚠️ $1${NC}"; }

check_success() {
    if [ $? -eq 0 ]; then
        print_success "$1"
    else
        print_error "$2"
        exit 1
    fi
}

animate_progress() {
    local pid=$1
    local spinstr='|/-\'
    local delay=0.1
    while kill -0 $pid 2>/dev/null; do
        for ((i=0;i<${#spinstr};i++)); do
            printf " [%c]  " "${spinstr:$i:1}"
            sleep $delay
            printf "\b\b\b\b\b\b"
        done
    done
    printf "    \b\b\b\b"
}

check_command() {
    command -v "$1" >/dev/null 2>&1 || {
        print_warning "$1 not found, installing..."
        sudo apt-get install -y "$1" >/dev/null 2>&1
        check_success "$1 installed" "Failed to install $1"
    }
}

# -----------------------------
# Welcome Animation
# -----------------------------
welcome_animation() {
    clear
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}              Blueprint Installer${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    sleep 1
}

# -----------------------------
# Installation Functions
# -----------------------------
install_mahimxyzz() {
    print_header "FRESH INSTALLATION"
    [ "$EUID" -ne 0 ] && print_error "Run as root or with sudo" && return 1

    print_status "Checking dependencies..."
    check_command curl
    check_command wget
    check_command unzip
    check_command git

    print_header "INSTALLING NODE.JS 20.x"
    print_status "Setting up Node.js repository..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
    sudo apt-get update >/dev/null 2>&1 & animate_progress $!

    print_status "Installing Node.js..."
    sudo apt-get install -y nodejs >/dev/null 2>&1 & animate_progress $!
    check_success "Node.js installed" "Failed to install Node.js"

    print_header "INSTALLING YARN & DEPENDENCIES"
    npm install -g yarn >/dev/null 2>&1 & animate_progress $!
    check_success "Yarn installed" "Failed to install Yarn"

    cd /var/www/pterodactyl || { print_error "Panel directory not found!"; return 1; }
    yarn >/dev/null 2>&1 & animate_progress $!
    check_success "Dependencies installed" "Failed to install Yarn dependencies"

    sudo apt install -y zip unzip git curl wget >/dev/null 2>&1 & animate_progress $!
    check_success "Additional packages installed" "Failed to install additional packages"

    print_header "DOWNLOADING BLUEPRINT RELEASE"
    RELEASE_URL=$(curl -s https://api.github.com/repos/BlueprintFramework/framework/releases/latest | grep 'browser_download_url' | cut -d '"' -f 4)
    wget "$RELEASE_URL" -O release.zip >/dev/null 2>&1 & animate_progress $!
    check_success "Release downloaded" "Failed to download release"

    print_status "Extracting release..."
    unzip -o release.zip >/dev/null 2>&1 & animate_progress $!
    check_success "Files extracted" "Failed to extract files"

    print_header "RUNNING BLUEPRINT INSTALLER"
    [ ! -f "blueprint.sh" ] && print_error "blueprint.sh not found" && return 1
    chmod +x blueprint.sh
    bash blueprint.sh
}

reinstall_mahimxyzz() {
    print_header "REINSTALLATION"
    blueprint -rerun-install >/dev/null 2>&1 & animate_progress $!
    check_success "Reinstallation completed" "Reinstallation failed"
}

update_mahimxyzz() {
    print_header "UPDATING"
    blueprint -upgrade >/dev/null 2>&1 & animate_progress $!
    check_success "Update completed" "Update failed"
}

# -----------------------------
# Menu
# -----------------------------
show_menu() {
    clear
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}           🔧 BLUEPRINT INSTALLER${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "${WHITE}1) ${DRED}Fresh Install${NC}"
    echo -e "${WHITE}2) ${DRED}Reinstall${NC}"
    echo -e "${WHITE}3) ${DRED}Update${NC}"
    echo -e "${WHITE}0) ${DRED}Exit${NC}\n"
    echo -ne "${YELLOW}Select an option [0-3]: ${NC}"
}

# -----------------------------
# Main Loop
# -----------------------------
welcome_animation
while true; do
    show_menu
    read -r choice
    case $choice in
        1) install ;;
        2) reinstall ;;
        3) update ;;
        0) 
            echo -e "${WHITE}Exiting Blueprint Installer...${NC}"
            sleep 1
            exit 0
            ;;
        *) print_error "Invalid option, choose 0-3"; sleep 1 ;;
    esac
    read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
done
