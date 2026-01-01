#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
WG_PORT=51820
WG_SUBNET="10.0.0"
WG_INTERFACE="wg0"
CONFIG_DIR="/etc/wireguard"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENTS_DIR="${PROJECT_DIR}/clients"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}   WireGuard VPN Server Setup${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}"
   echo "Try: sudo ./setup.sh"
   exit 1
fi

# Detect public IP
detect_public_ip() {
    # Try multiple services in case one is down
    PUBLIC_IP=$(curl -s -4 ifconfig.me || curl -s -4 icanhazip.com || curl -s -4 ipinfo.io/ip)
    if [[ -z "$PUBLIC_IP" ]]; then
        echo -e "${RED}Error: Could not detect public IP${NC}"
        exit 1
    fi
    echo "$PUBLIC_IP"
}

# Detect main network interface
detect_interface() {
    ip route | grep default | awk '{print $5}' | head -n1
}

echo -e "\n${YELLOW}[1/6] Installing WireGuard...${NC}"
apt-get update -qq
apt-get install -y wireguard qrencode

echo -e "${YELLOW}[2/6] Detecting network configuration...${NC}"
SERVER_PUBLIC_IP=$(detect_public_ip)
NETWORK_INTERFACE=$(detect_interface)
echo "  • Public IP: ${SERVER_PUBLIC_IP}"
echo "  • Network interface: ${NETWORK_INTERFACE}"

echo -e "${YELLOW}[3/6] Generating server keys...${NC}"
mkdir -p ${CONFIG_DIR}
chmod 700 ${CONFIG_DIR}

# Generate keys only if they don't exist (idempotent)
if [[ ! -f ${CONFIG_DIR}/server_private.key ]]; then
    wg genkey | tee ${CONFIG_DIR}/server_private.key | wg pubkey > ${CONFIG_DIR}/server_public.key
    chmod 600 ${CONFIG_DIR}/server_private.key
    echo "  • Generated new server keypair"
else
    echo "  • Using existing server keypair"
fi

SERVER_PRIVATE_KEY=$(cat ${CONFIG_DIR}/server_private.key)
SERVER_PUBLIC_KEY=$(cat ${CONFIG_DIR}/server_public.key)

echo -e "${YELLOW}[4/6] Creating server configuration...${NC}"
cat > ${CONFIG_DIR}/${WG_INTERFACE}.conf << EOF
[Interface]
Address = ${WG_SUBNET}.1/24
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIVATE_KEY}

# NAT and forwarding
PostUp = iptables -t nat -A POSTROUTING -o ${NETWORK_INTERFACE} -j MASQUERADE
PostUp = iptables -A FORWARD -i %i -j ACCEPT
PostUp = iptables -A FORWARD -o %i -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o ${NETWORK_INTERFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT
PostDown = iptables -D FORWARD -o %i -j ACCEPT

# Peers will be added below by add-client.sh
EOF

chmod 600 ${CONFIG_DIR}/${WG_INTERFACE}.conf
echo "  • Created ${CONFIG_DIR}/${WG_INTERFACE}.conf"

echo -e "${YELLOW}[5/6] Configuring system...${NC}"

# Enable IP forwarding (persistent)
if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi
sysctl -w net.ipv4.ip_forward=1 > /dev/null
echo "  • Enabled IP forwarding"

# Configure UFW if installed
if command -v ufw &> /dev/null; then
    ufw allow ${WG_PORT}/udp > /dev/null 2>&1 || true
    ufw allow OpenSSH > /dev/null 2>&1 || true
    echo "  • Configured UFW firewall"
fi

echo -e "${YELLOW}[6/6] Starting WireGuard service...${NC}"
systemctl enable wg-quick@${WG_INTERFACE} > /dev/null 2>&1
systemctl restart wg-quick@${WG_INTERFACE}
echo "  • WireGuard service started and enabled"

# Create clients directory
mkdir -p "${CLIENTS_DIR}"

# Save server info for add-client.sh
cat > ${CONFIG_DIR}/server.info << EOF
SERVER_PUBLIC_IP=${SERVER_PUBLIC_IP}
SERVER_PUBLIC_KEY=${SERVER_PUBLIC_KEY}
WG_PORT=${WG_PORT}
WG_SUBNET=${WG_SUBNET}
WG_INTERFACE=${WG_INTERFACE}
NETWORK_INTERFACE=${NETWORK_INTERFACE}
NEXT_IP=2
EOF

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}   ✓ WireGuard VPN Server is Ready!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Server Public Key: ${SERVER_PUBLIC_KEY}"
echo "Server Endpoint:   ${SERVER_PUBLIC_IP}:${WG_PORT}"
echo "VPN Subnet:        ${WG_SUBNET}.0/24"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  Add a client:  sudo ./add-client.sh <client-name>"
echo "  Example:       sudo ./add-client.sh phone"
echo "                 sudo ./add-client.sh laptop"
echo ""
echo "  Check status:  sudo wg show"
echo ""
