#!/bin/sh -e

# Uninstall script for sayip/reboot/halt for AllStar Link (ASL3)
# Copyright (C) 2025 Jory A. Pratt - W5GLE
# Released under the GNU General Public License v2 or later.

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root or with sudo"
    exit 1
fi

echo "This will uninstall the AllStar SayIP/reboot/halt functionality."
echo "Press Ctrl+C within 5 seconds to cancel..."
sleep 5

CUSTOM_SAYIP_CONF="/etc/asterisk/custom/rpt/sayip.conf"
TARGET_DIR="/etc/asterisk/local"

# Disable and stop the service
echo "Disabling and stopping allstar-sayip service..."
systemctl stop allstar-sayip 2>/dev/null || true
systemctl disable allstar-sayip 2>/dev/null || true

# Remove the service file
if [ -f "/etc/systemd/system/allstar-sayip.service" ]; then
    echo "Removing systemd service file..."
    rm -f /etc/systemd/system/allstar-sayip.service
    systemctl daemon-reload
fi

# Remove custom SayIP configuration file
if [ -f "$CUSTOM_SAYIP_CONF" ]; then
    echo "Removing $CUSTOM_SAYIP_CONF..."
    cp "$CUSTOM_SAYIP_CONF" "${CUSTOM_SAYIP_CONF}.pre-uninstall-$(date +%Y%m%d-%H%M%S).bak"
    rm -f "$CUSTOM_SAYIP_CONF"
    echo "Custom SayIP configuration removed (backup saved)."
else
    echo "Custom SayIP configuration not found at $CUSTOM_SAYIP_CONF"
fi

# Optionally remove the script files
echo ""
echo "Do you want to remove the script files from $TARGET_DIR? (y/n)"
read -r response
if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
    echo "Removing script files..."
    rm -f "$TARGET_DIR"/sayip.pl "$TARGET_DIR"/saypublicip.pl \
          "$TARGET_DIR"/halt.pl "$TARGET_DIR"/reboot.pl \
          "$TARGET_DIR"/speaktext.pl 2>/dev/null || true
    echo "Script files removed."
else
    echo "Script files left in place."
fi

echo ""
echo "Uninstall complete!"
echo "Note: Audio files (*.ulaw) and backup files were not removed."
echo "To fully clean up, manually remove files from $TARGET_DIR if desired."

