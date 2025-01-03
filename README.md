# UDP Custom Docker
UDP Custom installer with Docker support and gaming optimization

## Features
- BadVPN UDP ports (7100, 7200, 7300)
- Gaming optimized (PUBG, FIFA)
- Docker support
- Auto-installation script

## Quick Install
```bash
curl -s https://raw.githubusercontent.com/abdofaiz/udp-custom-docker/main/install-docker.sh | sudo bash
```

## Manual Install
```bash
# Get root access
sudo -s

# Clone the repository
git clone https://github.com/abdofaiz/udp-custom-docker.git

# Go to directory
cd udp-custom-docker

# Make script executable
chmod +x install-docker.sh

# Run installer
./install-docker.sh
```

## Ports
- 36712 - Main UDP Custom port
- 7300 - BadVPN UDP
- 7100, 7200 - Gaming ports

## Commands
After installation, use these commands:
```bash
# Check service status
docker ps

# View logs
docker logs udp-custom

# Restart service
docker restart udp-custom
```

## Support
- Ubuntu 20.04 (Recommended)
- Debian 10+
- Must have Docker support

## Credits
Modified by: Abdofaiz
