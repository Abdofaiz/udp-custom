#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Check root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

# Update system
apt update
apt upgrade -y

# Install dependencies for Ubuntu 20.04
apt install -y wget curl git cmake make gcc net-tools build-essential

# Install BadVPN
cd /usr/src/
wget https://github.com/ambrop72/badvpn/archive/refs/tags/1.999.130.tar.gz
tar xf 1.999.130.tar.gz
cd badvpn-1.999.130/
cmake -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1
make install

# Create directories
mkdir -p /etc/udp
mkdir -p /var/log/udp-custom

# Create BadVPN service
cat > /etc/systemd/system/badvpn.service <<EOL
[Unit]
Description=BadVPN UDPGW Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Download UDP Custom binary for Ubuntu 20.04
cd /root
wget -O /usr/local/bin/udp-custom https://raw.githubusercontent.com/abdofaiz/udp-custom/main/bin/udp-custom-linux-amd64
chmod +x /usr/local/bin/udp-custom

# Create UDP Custom config
cat > /etc/udp/config.json <<EOL
{
  "listen": ":36712",
  "stream_buffer": 67108864,
  "receive_buffer": 67108864,
  "max_connections": 2000,
  "udp_gateway": "127.0.0.1:7300"
}
EOL

# Create UDP Custom service
cat > /etc/systemd/system/udp-custom.service <<EOL
[Unit]
Description=UDP Custom Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/udp
ExecStart=/usr/local/bin/udp-custom server --config /etc/udp/config.json
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Set permissions
chmod 644 /etc/systemd/system/badvpn.service
chmod 644 /etc/systemd/system/udp-custom.service
chmod 644 /etc/udp/config.json

# Start services
systemctl daemon-reload
systemctl enable badvpn
systemctl enable udp-custom
systemctl start badvpn
systemctl start udp-custom

# Check status
echo -e "${GREEN}Installation completed!${NC}"
echo "Checking services status..."
systemctl status badvpn --no-pager
systemctl status udp-custom --no-pager
netstat -tulpn | grep -E '36712|7300'

# Show installation complete message
echo -e "${GREEN}UDP Custom installation completed!${NC}"
echo -e "BadVPN Port: 7300"
echo -e "UDP Custom Port: 36712"
echo -e "Check status with: systemctl status udp-custom"
