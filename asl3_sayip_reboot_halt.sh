#!/bin/sh -e

# Enhanced script for configuring sayip/reboot/halt for AllStar Link (ASL3)
# Copyright (C) 2025 Jory A. Pratt - W5GLE
# Released under the GNU General Public License v2 or later.

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root or with sudo"
    exit 1
fi

# Validate input arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <NodeNumber>"
    exit 1
fi

NODE_NUMBER=$1
if ! echo "$NODE_NUMBER" | grep -qE '^[0-9]+$'; then
    echo "Error: NodeNumber must be a positive integer."
    exit 1
fi

echo "Installing required dependency: libnet-ifconfig-wrapper-perl..."
if ! apt-get update >/dev/null 2>&1; then
    echo "ERROR: Failed to run apt-get update. Please check your internet connection and repository configuration."
    exit 1
fi
if ! apt-get install -y libnet-ifconfig-wrapper-perl >/dev/null 2>&1; then
    echo "ERROR: Failed to install libnet-ifconfig-wrapper-perl. Please install it manually with:"
    echo "       sudo apt-get install libnet-ifconfig-wrapper-perl"
    exit 1
fi
echo "Dependency installed successfully."

BASE_URL="https://raw.githubusercontent.com/hardenedpenguin/sayip-reboot-halt-saypublicip/main"
TARGET_DIR="/etc/asterisk/local"
PL_FILES="halt.pl reboot.pl sayip.pl saypublicip.pl speaktext.pl"
ULAW_FILES="halt.ulaw reboot.ulaw ip-address.ulaw public-ip-address.ulaw"
FILES_TO_DOWNLOAD="$PL_FILES $ULAW_FILES"
CUSTOM_DIR="/etc/asterisk/custom"
CUSTOM_RPT_DIR="$CUSTOM_DIR/rpt"
CUSTOM_SAYIP_CONF="$CUSTOM_RPT_DIR/sayip.conf"

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR" || {
    echo "Failed to create directory $TARGET_DIR"
    exit 1
}

# Ensure target directory is owned by asterisk:asterisk
chown -R asterisk:asterisk "$TARGET_DIR" || {
    echo "Failed to set ownership of $TARGET_DIR to asterisk:asterisk"
    exit 1
}

# Download required files
cd "$TARGET_DIR" || {
    echo "Failed to change directory to $TARGET_DIR"
    exit 1
}

for FILE in $FILES_TO_DOWNLOAD; do
    if [ -f "$FILE" ]; then
        echo "$FILE already exists, skipping download."
        continue
    fi
    echo "Downloading $FILE..."
    if ! curl -sf --max-time 30 -O "$BASE_URL/$FILE"; then
        echo "ERROR: Failed to download $FILE"
        exit 1
    fi
done

# Set permissions for the downloaded files
for file in $PL_FILES; do
    [ -f "$file" ] && chmod 750 "$file" && chown asterisk:asterisk "$file" 2>/dev/null || true
done
for file in $ULAW_FILES; do
    [ -f "$file" ] && chmod 640 "$file" && chown asterisk:asterisk "$file" 2>/dev/null || true
done

cat <<EOF > /etc/systemd/system/allstar-sayip.service
[Unit]
Description=AllStar SayIP Service
After=asterisk.service
Requires=asterisk.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'sleep 5s && /etc/asterisk/local/sayip.pl $NODE_NUMBER'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable allstar-sayip

# Create custom rpt directory and write SayIP configuration
mkdir -p "$CUSTOM_RPT_DIR" || {
    echo "Failed to create directory $CUSTOM_RPT_DIR"
    exit 1
}

if [ -f "$CUSTOM_SAYIP_CONF" ]; then
    cp "$CUSTOM_SAYIP_CONF" "${CUSTOM_SAYIP_CONF}.bak-$(date +%Y%m%d-%H%M%S)"
fi

cat <<EOF > "$CUSTOM_SAYIP_CONF"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;; SayIP Customization ;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;MENU:sayip:functions:Say local/public IP and reboot/halt via DTMF
;
; [functions] overrides for SayIP tools
;
[functions-sayip](!)
A1 = cmd,/etc/asterisk/local/sayip.pl $NODE_NUMBER
A3 = cmd,/etc/asterisk/local/saypublicip.pl $NODE_NUMBER
B1 = cmd,/etc/asterisk/local/halt.pl $NODE_NUMBER
B3 = cmd,/etc/asterisk/local/reboot.pl $NODE_NUMBER
EOF

chmod 644 "$CUSTOM_SAYIP_CONF"
chown asterisk:asterisk "$CUSTOM_SAYIP_CONF" 2>/dev/null || true

# Final success message
echo ""
echo "========================================================================"
echo "SUCCESS: ASL3 support for sayip/reboot/halt is configured for node $NODE_NUMBER"
echo "========================================================================"
echo ""
echo "DTMF commands were written to $CUSTOM_SAYIP_CONF."
echo "Ensure your main rpt.conf includes custom/rpt/*.conf (ASL3 does this by default)."
echo ""
echo "SayIP menu entry:"
echo "  Category: sayip"
echo "  Commands:"
echo "  *A1 - Say Local IP address"
echo "  *A3 - Say Public IP address"
echo "  *B1 - Halt the system"
echo "  *B3 - Reboot the system"
echo ""
echo "To disable boot announcement: sudo systemctl disable allstar-sayip"
echo "To uninstall: sudo ./asl3_sayip_uninstall.sh"
echo ""