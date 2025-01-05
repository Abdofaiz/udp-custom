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
    
    # Install BadVPN
    log "Installing BadVPN..."
    apt-get install -y cmake make gcc
    cd /usr/src/
    wget https://github.com/ambrop72/badvpn/archive/refs/tags/1.999.130.tar.gz
    tar xf 1.999.130.tar.gz
    cd badvpn-1.999.130/
    cmake -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1
    make install
    
    # Create BadVPN service
    cat > /etc/systemd/system/badvpn.service <<EOL
[Unit]
Description=BadVPN UDPGW Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 10 --client-socket-sndbuf 10000
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOL

    # Set permissions
    chmod 644 /etc/systemd/system/badvpn.service
    
    # Create necessary directories
    mkdir -p /etc/udp
    mkdir -p /var/log/udp-custom
    
    # Create Python settings files for gaming
    cat > /etc/udp/settings.py <<EOL
class GameUDPSettings:
    def __init__(self):
        self.GAME_PORTS = {
            'pubg': {
                'ports': [10012, 17500],
                'buffer': 8192,         # Larger buffer for PUBG
                'max_latency': 150      # Higher latency tolerance
            },
            'fifa': {
                'ports': [3659, 14000],
                'buffer': 4096,         # Standard buffer
                'max_latency': 80       # Lower latency requirement
            },
            'general': {
                'ports': [7100, 7200, 7300],
                'buffer': 4096,
                'max_latency': 100
            }
        }
        
        self.GAMING_CONFIG = {
            'timeout': 3,
            'keepalive': 2,
            'priority_queue': True,
            'qos_enabled': True,        # Added QoS
            'packet_compression': True,  # Added compression
            'fast_open': True           # TCP fast open
        }
EOL

    # Create gaming handler
    cat > /etc/udp/gaming_handler.py <<EOL
import socket
import threading
import time
from settings import GameUDPSettings

class GameUDPHandler:
    def __init__(self):
        self.active = True
        self.sockets = {}
        self.settings = GameUDPSettings()
        self.GAME_PORTS = self.settings.GAME_PORTS
        
    def setup_gaming_ports(self):
        for game, ports in self.GAME_PORTS.items():
            for port in ports:
                sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 65535)
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 65535)
                sock.setsockopt(socket.IPPROTO_UDP, socket.SO_REUSEADDR, 1)
                sock.bind(('0.0.0.0', port))
                sock.setblocking(False)
                self.sockets[port] = sock
                print(f"[+] Optimized gaming port {port} for {game}")

    def process_game_packet(self, data, addr, port):
        self.sockets[port].sendto(data, addr)

    def handle_game_traffic(self, port):
        sock = self.sockets[port]
        while self.active:
            try:
                data, addr = sock.recvfrom(4096)
                if data:
                    self.process_game_packet(data, addr, port)
            except BlockingIOError:
                time.sleep(0.001)
            except Exception as e:
                print(f"[-] Error on port {port}: {e}")

    def start(self):
        try:
            print("[*] Starting optimized UDP handler for games")
            print("[*] Configured for: PUBG, FIFA")
            print("[*] Using BadVPN ports: 7100, 7200, 7300")
            
            self.setup_gaming_ports()
            
            for port in self.sockets:
                thread = threading.Thread(target=self.handle_game_traffic, args=(port,))
                thread.daemon = True
                thread.start()
                
            while self.active:
                time.sleep(1)
                
        except KeyboardInterrupt:
            self.shutdown()
    
    def shutdown(self):
        self.active = False
        for sock in self.sockets.values():
            sock.close()
        print("\n[*] Shutting down UDP handler...")

if __name__ == "__main__":
    handler = GameUDPHandler()
    handler.start()
EOL

    # Create gaming service
    cat > /etc/systemd/system/udp-gaming.service <<EOL
[Unit]
Description=UDP Gaming Optimization Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /etc/udp/gaming_handler.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOL

    # Set permissions
    chmod 644 /etc/udp/settings.py
    chmod 644 /etc/udp/gaming_handler.py
    chmod 644 /etc/systemd/system/udp-gaming.service
    
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
    chown root:root /var/log/udp-custom.log
    
    # Clear old log
    echo "" > /var/log/udp-custom.log
    
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
    
    # Start BadVPN
    log "Starting BadVPN service..."
    systemctl enable badvpn
    systemctl start badvpn || log "Failed to start BadVPN service"
    
    # Verify BadVPN service
    if systemctl is-active --quiet badvpn; then
        log "BadVPN service started successfully"
    else
        log "BadVPN service failed to start. Check logs with: journalctl -u badvpn"
    fi
    
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
    
    # Start gaming service
    log "Starting UDP Gaming service..."
    systemctl enable udp-gaming
    systemctl start udp-gaming || log "Failed to start UDP Gaming service"
    
    # Verify gaming service
    if systemctl is-active --quiet udp-gaming; then
        log "UDP Gaming service started successfully"
    else
        log "UDP Gaming service failed to start. Check logs with: journalctl -u udp-gaming"
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

# Gaming optimizations
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_max_syn_backlog = 100000
net.ipv4.tcp_max_tw_buckets = 100000
net.ipv4.ip_local_port_range = 1024 65535

# BadVPN optimizations
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
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
