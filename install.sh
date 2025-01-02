#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Log file
LOG_FILE="/var/log/udp-custom-install.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${NC}"
        exit 1
    fi
}

install_dependencies() {
    log "Installing dependencies..."
    apt-get update
    apt-get install -y wget curl git net-tools
}

install_services() {
    log "Installing UDP services..."
    
    # Copy binary
    cp bin/udp-custom-linux-amd64 /usr/local/bin/udp-custom
    chmod +x /usr/local/bin/udp-custom
    
    # Install service files
    cp config/udpgw.service /etc/systemd/system/
    cp config/udp-custom.service /etc/systemd/system/
    
    # Create necessary directories
    mkdir -p /etc/udp
    cp config/config.json /etc/udp/
    
    # Setup limiter
    cp module/limiter.sh /usr/local/bin/
    chmod +x /usr/local/bin/limiter.sh
    
    # Reload systemd
    systemctl daemon-reload
}

start_services() {
    log "Starting services..."
    systemctl enable udpgw
    systemctl enable udp-custom
    systemctl start udpgw
    systemctl start udp-custom
}

main() {
    check_root
    log "Starting installation..."
    
    install_dependencies
    install_services
    start_services
    
    log "Installation completed successfully!"
}

main
