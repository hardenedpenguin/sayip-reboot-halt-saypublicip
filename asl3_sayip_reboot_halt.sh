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
if ! apt-get update >/dev/null; then
    echo "Failed to run apt-get update. Please check your internet connection and repository configuration."
    exit 1
fi
if ! apt-get install -y libnet-ifconfig-wrapper-perl; then
    echo "Failed to install libnet-ifconfig-wrapper-perl. Please install it manually."
    exit 1
fi

CONF_FILE="/etc/asterisk/rpt.conf"
BASE_URL="https://raw.githubusercontent.com/hardenedpenguin/sayip-reboot-halt-saypublicip/main"
TARGET_DIR="/etc/asterisk/local"
FILES_TO_DOWNLOAD="halt.pl reboot.pl sayip.pl saypublicip.pl speaktext.pl halt.ulaw reboot.ulaw ip-address.ulaw public-ip-address.ulaw"

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
    if [ ! -f "$FILE" ]; then
        echo "Downloading $FILE..."
        if ! curl -s -O "$BASE_URL/$FILE"; then
            echo "Failed to download $FILE"
            exit 1
        fi
    else
        echo "$FILE already exists, skipping download."
    fi
done

# Set permissions for the downloaded files
chmod 750 *.pl
chmod 640 *.ulaw
chown asterisk:asterisk *.pl *.ulaw 2>/dev/null || echo "Unable to set ownership (run as root for this step)"

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

# Backup and modify the configuration file
if ! grep -q "cmd,/etc/asterisk/local/sayip.pl" "$CONF_FILE"; then
    echo "Backing up and modifying $CONF_FILE..."
    cp "$CONF_FILE" "${CONF_FILE}.bak"
    sed -i "/\[functions\]/a \\
A1 = cmd,/etc/asterisk/local/sayip.pl $NODE_NUMBER \\
A3 = cmd,/etc/asterisk/local/saypublicip.pl $NODE_NUMBER \\
B1 = cmd,/etc/asterisk/local/halt.pl $NODE_NUMBER \\
B3 = cmd,/etc/asterisk/local/reboot.pl $NODE_NUMBER \\
" "$CONF_FILE"
else
    echo "Commands already exist in $CONF_FILE, skipping modification."
fi

# Redirect final output to terminal (stdout)
echo "ASL3 support for sayip/reboot/halt is configured for node $NODE_NUMBER."