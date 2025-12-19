#!/bin/bash

# =====================================================
# MRDRYNOX HOSTING MANAGER v1.0
# =====================================================

set -e

# ----------------- COLORS -----------------
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Pill Header Colors
L_PILL='\033[48;5;93m\033[38;5;255m' # Purple BG
R_PILL='\033[48;5;39m\033[38;5;16m'  # Cyan BG

# Text Colors
MAIN='\033[38;5;51m'    # Cyan
WHITE='\033[38;5;255m'   # White
GRAY='\033[38;5;242m'    # Gray
SUCCESS='\033[38;5;82m'  # Green

# ----------------- UI UTILS -----------------

header() {
    clear
    echo -e "\n  ${L_PILL}${BOLD} MRDRYNOX ${RESET}${R_PILL}${BOLD} HOSTING MANAGER ${RESET} ${DIM}${RESET}"
    echo -e "  ${GRAY}──────────────────────────────────────────────────────${RESET}"
}

# Used for the detailed System Tools list
info_line() {
    printf "  ${MAIN}%-15s${RESET} ${WHITE}%s${RESET}\n" "$1:" "$2"
}

# ----------------- SYSTEM TOOLS (ALL INFO) -----------------

show_all_info() {
    header
    echo -e "  ${BOLD}${WHITE}FULL SYSTEM DIAGNOSTICS${RESET}\n"
    
    # Hardware Info
    info_line "OS" "$(cat /etc/os-release | grep 'PRETTY_NAME' | cut -d'"' -f2)"
    info_line "CPU" "$(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
    info_line "Cores" "$(nproc) Threads"
    info_line "RAM" "$(free -h | awk '/Mem:/ {print $3 " / " $2}')"
    info_line "Disk" "$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')"
    info_line "Kernel" "$(uname -r)"
    info_line "Uptime" "$(uptime -p)"
    
    echo -e "  ${GRAY}─────────────────────────────────${RESET}"
    
    # Network Info
    echo -e "  ${DIM}Fetching network data...${RESET}"
    pub_ip=$(curl -s --max-time 3 api.ipify.org || echo "N/A")
    isp=$(curl -s --max-time 3 ipinfo.io/org || echo "N/A")
    loc=$(curl -s --max-time 3 ipinfo.io/country || echo "N/A")
    
    info_line "Public IP" "$pub_ip"
    info_line "Local IP" "$(hostname -I | awk '{print $1}')"
    info_line "ISP" "$isp"
    info_line "Country" "$loc"

    echo -e "\n  ${DIM}Press ENTER to return to menu...${RESET}"
    read
}

# ----------------- MAIN LOOP -----------------

while true; do
    header
    echo -e "  ${BOLD}${WHITE}MAIN MENU${RESET}\n"

    # Your original options and names
    printf "  ${MAIN}${BOLD}%s${RESET}  ${WHITE}%-30s${RESET}\n" "1" "Install Pterodactyl Panel"
    printf "  ${MAIN}${BOLD}%s${RESET}  ${WHITE}%-30s${RESET}\n" "2" "Install Wings (Node)"
    printf "  ${MAIN}${BOLD}%s${RESET}  ${WHITE}%-30s${RESET}\n" "3" "Install Blueprints"
    printf "  ${MAIN}${BOLD}%s${RESET}  ${WHITE}%-30s${RESET}\n" "4" "Setup IDX 24/7"
    printf "  ${MAIN}${BOLD}%s${RESET}  ${WHITE}%-30s${RESET}\n" "5" "System Tools"
    echo ""
    printf "  ${MAIN}${BOLD}%s${RESET}  ${WHITE}%-30s${RESET}\n" "0" "Exit"

    echo -e "\n  ${GRAY}──────────────────────────────────────────────────────${RESET}"
    echo -ne "  ${BOLD}Choice ${MAIN}❯${RESET} "
    read -r c

    case "$c" in
        1) bash <(curl -fsSL https://raw.githubusercontent.com/rasinopgg/installer/main/panel.sh) ;;
        2) bash <(curl -fsSL https://raw.githubusercontent.com/rasinopgg/installer/main/node.sh) ;;
        3) bash <(curl -fsSL https://raw.githubusercontent.com/rasinopgg/installer/main/blueprints.sh) ;;
        4) bash <(curl -fsSL https://raw.githubusercontent.com/rasinopgg/installer/main/247) ;;
        5) show_all_info ;;
        0) 
            echo -e "\n  ${SUCCESS}${BOLD}Thanks for using this tool! 🌟${RESET}\n"
            exit 0 
            ;;
        *) 
            echo -e "  \033[31mInvalid option\033[0m"
            sleep 1 
            ;;
    esac
done
