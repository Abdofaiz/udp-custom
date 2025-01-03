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

install_docker() {
    log "Installing Docker..."
    
    # Install Docker dependencies
    apt-get update
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # Set up stable repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/download/v2.5.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
}

deploy_containers() {
    log "Deploying UDP Custom containers..."
    
    # Create necessary directories
    mkdir -p config logs
    
    # Copy configuration files
    cp config/* config/
    
    # Build and start containers
    docker-compose up -d --build
    
    # Check if containers are running
    if docker ps | grep -q "udp-custom"; then
        log "UDP Custom container started successfully"
    else
        log "Failed to start UDP Custom container"
        exit 1
    fi
}

main() {
    check_root
    log "Starting Docker installation..."
    
    install_docker
    deploy_containers
    
    log "Installation completed successfully!"
    echo -e "${GREEN}UDP Custom is now running in Docker containers${NC}"
    echo -e "${YELLOW}Check logs with: docker logs udp-custom${NC}"
}

main 