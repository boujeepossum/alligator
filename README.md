# WireGuard VPN Server

One-command WireGuard VPN setup for Digital Ocean (or any Ubuntu server).

## Quick Start

### 1. Create a Droplet

- **Image:** Ubuntu 24.04 LTS
- **Size:** Basic $6/mo (1GB RAM) is plenty
- **Region:** Choose one close to you
- **Authentication:** SSH key (recommended)

### 2. SSH and Setup

```bash
ssh root@YOUR_DROPLET_IP

git clone https://github.com/YOUR_USERNAME/alligator.git
cd alligator
chmod +x *.sh
./setup.sh
```

That's it. Server is running.

### 3. Add Clients

```bash
# Add a phone
./add-client.sh phone

# Add a laptop
./add-client.sh laptop

# Add work computer
./add-client.sh work
```

Each client gets:
- A config file in `./clients/`
- A QR code displayed in terminal (for mobile)

### 4. Connect Your Devices

**Mobile (iOS/Android):**
1. Install [WireGuard app](https://www.wireguard.com/install/)
2. Tap + → Scan QR Code
3. Enable the tunnel

**macOS:**
1. Install from [App Store](https://apps.apple.com/us/app/wireguard/id1451685025)
2. Copy `clients/YOUR_CLIENT.conf` to your Mac
3. File → Import Tunnel(s) from File
4. Activate

**Linux:**
```bash
# Copy config to your machine, then:
sudo apt install wireguard
sudo cp YOUR_CLIENT.conf /etc/wireguard/
sudo wg-quick up YOUR_CLIENT
```

**Windows:**
1. Install from [wireguard.com](https://www.wireguard.com/install/)
2. Import tunnel from file
3. Activate

## Commands Reference

| Command | Description |
|---------|-------------|
| `sudo ./setup.sh` | Initial server setup |
| `sudo ./add-client.sh <name>` | Add a new client |
| `sudo wg show` | Show active connections |
| `sudo systemctl status wg-quick@wg0` | Check service status |
| `sudo systemctl restart wg-quick@wg0` | Restart WireGuard |

## Configuration

Default settings (edit `setup.sh` before running to change):

| Setting | Default | Description |
|---------|---------|-------------|
| Port | 51820/UDP | WireGuard listen port |
| Subnet | 10.0.0.0/24 | VPN internal network |
| DNS | 1.1.1.1 | Cloudflare DNS for clients |

## Verify It's Working

After connecting a client:

1. **Check your IP:** Visit [whatismyip.com](https://whatismyip.com) - should show droplet IP
2. **On the server:** `sudo wg show` - should show your peer with recent handshake

## Security Notes

- Server private key stored in `/etc/wireguard/server_private.key`
- Client configs in `./clients/` contain private keys - **don't commit these!**
- Each client has a unique preshared key for extra security
- The `clients/` directory is gitignored by default

## Troubleshooting

**Client can't connect:**
```bash
# Check if WireGuard is running
sudo systemctl status wg-quick@wg0

# Check firewall
sudo ufw status

# Make sure port is open
sudo ufw allow 51820/udp
```

**No internet through VPN:**
```bash
# Check IP forwarding
cat /proc/sys/net/ipv4/ip_forward  # Should be 1

# Check NAT rules
sudo iptables -t nat -L POSTROUTING
```

**View logs:**
```bash
sudo journalctl -u wg-quick@wg0 -f
```

## File Structure

```
alligator/
├── setup.sh          # Run once to setup server
├── add-client.sh     # Run to add each client
├── README.md         # This file
├── .gitignore        # Ignores clients/ directory
└── clients/          # Generated client configs (gitignored)
    ├── phone.conf
    ├── laptop.conf
    └── ...
```

## Uninstall

```bash
sudo systemctl stop wg-quick@wg0
sudo systemctl disable wg-quick@wg0
sudo apt remove wireguard
sudo rm -rf /etc/wireguard
```

## License

MIT - Do whatever you want with it.
