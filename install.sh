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
    
    # Create necessary directories
    mkdir -p /etc/udp
    mkdir -p /var/log/udp-custom
    
    # Copy and set permissions for binary
    cp bin/udp-custom-linux-amd64 /usr/local/bin/udp-custom
    chmod +x /usr/local/bin/udp-custom
    
    # Install service files
    cp config/udpgw.service /etc/systemd/system/
    cp config/udp-custom.service /etc/systemd/system/
    
    # Copy configuration
    cp config/config.json /etc/udp/
    
    # Setup limiter
    cp module/limiter.sh /usr/local/bin/
    chmod +x /usr/local/bin/limiter.sh
    
    # Install UDP command
    cp module/udp /usr/local/bin/udp
    chmod +x /usr/local/bin/udp
    
    # Set correct SELinux context if applicable
    if command -v semanage >/dev/null 2>&1; then
        semanage fcontext -a -t bin_t "/usr/local/bin/udp-custom"
        restorecon -v "/usr/local/bin/udp-custom"
    fi
    
    # Ensure log directory exists with proper permissions
    mkdir -p /var/log/udp-custom
    chown root:root /var/log/udp-custom
    chmod 755 /var/log/udp-custom
    
    # Set proper permissions
    chown root:root /usr/local/bin/udp-custom
    chmod 755 /usr/local/bin/udp-custom
    chown -R root:root /etc/udp
    chmod 755 /etc/udp
    chmod 644 /etc/udp/config.json
    
    # Ensure binary is in the correct location
    if [ ! -f "/usr/local/bin/udp-custom" ]; then
        cp bin/udp-custom-linux-amd64 /usr/local/bin/udp-custom
        chmod +x /usr/local/bin/udp-custom
    fi
    
    # Create log file
    touch /var/log/udp-custom.log
    chmod 644 /var/log/udp-custom.log
    
    # Reload systemd
    systemctl daemon-reload
    
    # Install user management
    cp module/user-management /usr/local/bin/udp-user
    chmod +x /usr/local/bin/udp-user
    
    # Create user database directory
    mkdir -p /etc/udp
    touch /etc/udp/users.db
    touch /etc/udp/users.conf
    chmod 644 /etc/udp/users.db
    chmod 644 /etc/udp/users.conf
    
    # Setup iptables monitoring
    iptables -N udp-custom 2>/dev/null
    iptables -F udp-custom
    iptables -A INPUT -p tcp --dport 36712 -j udp-custom
    
    # Save iptables rules
    if command -v iptables-save >/dev/null 2>&1; then
        iptables-save > /etc/iptables.rules
        echo "iptables-restore < /etc/iptables.rules" >> /etc/rc.local
    fi
}

start_services() {
    log "Starting services..."
    systemctl enable udpgw
    systemctl enable udp-custom
    
    log "Starting UDPGW service..."
    systemctl start udpgw || log "Failed to start UDPGW service"
    
    log "Starting UDP Custom service..."
    systemctl start udp-custom || log "Failed to start UDP Custom service"
    
    # Verify services
    if systemctl is-active --quiet udp-custom; then
        log "UDP Custom service started successfully"
    else
        log "UDP Custom service failed to start. Check logs with: journalctl -u udp-custom"
    fi
}

# Add this function to optimize system
optimize_system() {
    log "Optimizing system for better UDP performance..."
    
    # TCP optimization
    cat > /etc/sysctl.d/99-network-performance.conf <<EOL
# TCP optimization
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_rmem = 8192 87380 33554432
net.ipv4.tcp_wmem = 8192 87380 33554432
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576
net.core.netdev_budget = 600
net.core.netdev_budget_usecs = 20000

# UDP optimization
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
net.core.netdev_max_backlog = 100000
net.ipv4.udp_mem = 8192 87380 33554432
EOL

    # Apply sysctl settings
    sysctl -p /etc/sysctl.d/99-network-performance.conf
    
    # Enable BBR
    if ! grep -q "tcp_bbr" /etc/modules-load.d/modules.conf; then
        echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
    fi
    modprobe tcp_bbr
    
    # Set BBR as default TCP congestion control
    echo "bbr" > /proc/sys/net/ipv4/tcp_congestion_control
}

main() {
    check_root
    log "Starting installation..."
    
    install_dependencies
    install_services
    optimize_system
    start_services
    
    log "Installation completed successfully!"
}

main
