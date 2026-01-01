#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

CONFIG_DIR="/etc/wireguard"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENTS_DIR="${PROJECT_DIR}/clients"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}"
   echo "Try: sudo ./add-client.sh <client-name>"
   exit 1
fi

# Check for client name argument
if [[ -z "$1" ]]; then
    echo -e "${RED}Error: Please provide a client name${NC}"
    echo "Usage: sudo ./add-client.sh <client-name>"
    echo "Example: sudo ./add-client.sh phone"
    exit 1
fi

CLIENT_NAME="$1"

# Validate client name (alphanumeric and hyphens only)
if [[ ! "$CLIENT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo -e "${RED}Error: Client name must contain only letters, numbers, hyphens, and underscores${NC}"
    exit 1
fi

# Check if server is set up
if [[ ! -f "${CONFIG_DIR}/server.info" ]]; then
    echo -e "${RED}Error: Server not configured. Run ./setup.sh first${NC}"
    exit 1
fi

# Load server configuration
source ${CONFIG_DIR}/server.info

# Check if client already exists
if [[ -f "${CLIENTS_DIR}/${CLIENT_NAME}.conf" ]]; then
    echo -e "${YELLOW}Client '${CLIENT_NAME}' already exists.${NC}"
    echo ""
    echo "Config file: ${CLIENTS_DIR}/${CLIENT_NAME}.conf"
    echo ""
    echo -e "${CYAN}QR Code for mobile:${NC}"
    qrencode -t ansiutf8 < "${CLIENTS_DIR}/${CLIENT_NAME}.conf"
    exit 0
fi

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}   Adding WireGuard Client: ${CLIENT_NAME}${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Get next available IP
CLIENT_IP="${WG_SUBNET}.${NEXT_IP}"
NEXT_IP=$((NEXT_IP + 1))

echo -e "\n${YELLOW}[1/3] Generating client keys...${NC}"
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)
CLIENT_PRESHARED_KEY=$(wg genpsk)
echo "  • Client IP: ${CLIENT_IP}"

echo -e "${YELLOW}[2/3] Creating client configuration...${NC}"
mkdir -p "${CLIENTS_DIR}"

# Create client config file
cat > "${CLIENTS_DIR}/${CLIENT_NAME}.conf" << EOF
[Interface]
# Client: ${CLIENT_NAME}
Address = ${CLIENT_IP}/32
PrivateKey = ${CLIENT_PRIVATE_KEY}
DNS = 1.1.1.1, 1.0.0.1

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
PresharedKey = ${CLIENT_PRESHARED_KEY}
Endpoint = ${SERVER_PUBLIC_IP}:${WG_PORT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

chmod 600 "${CLIENTS_DIR}/${CLIENT_NAME}.conf"
echo "  • Created ${CLIENTS_DIR}/${CLIENT_NAME}.conf"

echo -e "${YELLOW}[3/3] Adding peer to server...${NC}"

# Add peer to server config
cat >> ${CONFIG_DIR}/${WG_INTERFACE}.conf << EOF

# Client: ${CLIENT_NAME}
[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
PresharedKey = ${CLIENT_PRESHARED_KEY}
AllowedIPs = ${CLIENT_IP}/32
EOF

# Update NEXT_IP in server.info
sed -i "s/^NEXT_IP=.*/NEXT_IP=${NEXT_IP}/" ${CONFIG_DIR}/server.info

# Reload WireGuard (without dropping existing connections)
wg syncconf ${WG_INTERFACE} <(wg-quick strip ${WG_INTERFACE})
echo "  • Added peer to WireGuard"

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}   ✓ Client '${CLIENT_NAME}' created!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Client IP:     ${CLIENT_IP}"
echo "Config file:   ${CLIENTS_DIR}/${CLIENT_NAME}.conf"
echo ""
echo -e "${CYAN}QR Code (scan with WireGuard mobile app):${NC}"
echo ""
qrencode -t ansiutf8 < "${CLIENTS_DIR}/${CLIENT_NAME}.conf"
echo ""
echo -e "${YELLOW}For desktop/laptop:${NC}"
echo "  Copy the config file to your device and import it into WireGuard"
echo "  macOS/Windows: Import tunnel from file"
echo "  Linux: sudo cp ${CLIENT_NAME}.conf /etc/wireguard/ && sudo wg-quick up ${CLIENT_NAME}"
echo ""
