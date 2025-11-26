#!/bin/bash
#
# Wheel of Names - Client Setup for macOS/Linux
# Adds the server's custom hostname to this device's hosts file
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo ""
echo -e "${CYAN}  ╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}  ║     🎡 WHEEL OF NAMES - CLIENT DEVICE SETUP 🎡       ║${NC}"
echo -e "${CYAN}  ╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# Check for root/sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}  ⚠️  This script needs root privileges.${NC}"
    echo "  Please run with sudo: sudo $0 $@"
    exit 1
fi

echo -e "${GREEN}  ✓ Running with root privileges${NC}"
echo ""

# Configuration
DEFAULT_HOSTNAME="wheel.local"
HOSTS_FILE="/etc/hosts"

# Parse arguments
if [ "$1" = "--remove" ]; then
    HOSTNAME="${2:-$DEFAULT_HOSTNAME}"
    echo "  Removing $HOSTNAME from hosts file..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "/$HOSTNAME/d" "$HOSTS_FILE"
    else
        sed -i "/$HOSTNAME/d" "$HOSTS_FILE"
    fi
    # Flush DNS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        dscacheutil -flushcache
        killall -HUP mDNSResponder 2>/dev/null || true
    else
        systemctl restart systemd-resolved 2>/dev/null || service nscd restart 2>/dev/null || true
    fi
    echo -e "${GREEN}  ✅ Removed!${NC}"
    exit 0
fi

# Get server IP
if [ -z "$1" ]; then
    read -p "  Enter server IP address: " SERVER_IP
else
    SERVER_IP="$1"
fi

# Get hostname
if [ -z "$2" ]; then
    read -p "  Enter hostname [$DEFAULT_HOSTNAME]: " HOSTNAME
    HOSTNAME="${HOSTNAME:-$DEFAULT_HOSTNAME}"
else
    HOSTNAME="$2"
fi

echo ""
echo -e "${CYAN}  ─────────────────────────────────────────────────────────${NC}"
echo "  Configuration:"
echo -e "${CYAN}  ─────────────────────────────────────────────────────────${NC}"
echo "    Server IP: $SERVER_IP"
echo "    Hostname:  $HOSTNAME"
echo -e "${CYAN}  ─────────────────────────────────────────────────────────${NC}"
echo ""

# Validate IP
if [ -z "$SERVER_IP" ]; then
    echo -e "${RED}  ❌ ERROR: Server IP is required${NC}"
    echo ""
    echo "  Usage: sudo $0 [SERVER_IP] [HOSTNAME]"
    echo "  Example: sudo $0 192.168.1.100 wheel.local"
    exit 1
fi

# Remove existing entry if present
if grep -q "$HOSTNAME" "$HOSTS_FILE"; then
    echo "  ⚠️  Entry for $HOSTNAME already exists, updating..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "/$HOSTNAME/d" "$HOSTS_FILE"
    else
        sed -i "/$HOSTNAME/d" "$HOSTS_FILE"
    fi
fi

# Add new entry
echo "$SERVER_IP $HOSTNAME" >> "$HOSTS_FILE"

# Flush DNS cache
echo "  Flushing DNS cache..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    dscacheutil -flushcache
    killall -HUP mDNSResponder 2>/dev/null || true
else
    systemctl restart systemd-resolved 2>/dev/null || service nscd restart 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}  ✅ Setup complete!${NC}"
echo ""
echo -e "${CYAN}  ─────────────────────────────────────────────────────────${NC}"
echo "  You can now access the wheel at:"
echo -e "${CYAN}  ─────────────────────────────────────────────────────────${NC}"
echo -e "    ${GREEN}https://$HOSTNAME${NC}"
echo "    http://$HOSTNAME"
echo -e "${CYAN}  ─────────────────────────────────────────────────────────${NC}"
echo ""
echo -e "${YELLOW}  ⚠️  NOTE: Your browser may show a certificate warning.${NC}"
echo "      This is normal for local SSL certificates."
echo "      Click \"Advanced\" then \"Proceed\" to continue."
echo ""
echo "  To REMOVE this configuration later, run:"
echo "    sudo $0 --remove $HOSTNAME"
echo ""
