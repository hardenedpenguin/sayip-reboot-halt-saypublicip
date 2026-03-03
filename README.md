# SayIP for ASL3

![GitHub total downloads](https://img.shields.io/github/downloads/hardenedpenguin/sayip-reboot-halt-saypublicip/total?style=flat-square)

This is a Debian package for AllStarLink V3 nodes that speaks the node's IP address at boot. It can announce the **local** or **public** IP address and includes features to **halt** or **reboot** the node using DTMF commands.

---

## 🔧 Installation

Download and install the package with your node number:

```bash
wget https://github.com/hardenedpenguin/sayip-reboot-halt-saypublicip/releases/download/v1.0.0/sayip-node-utils_1.0.0-1_all.deb
sudo NODE_NUMBER=12345 dpkg -i sayip-node-utils_1.0.0-1_all.deb
```

This will:
- Install the `sayip-node-utils` Ruby script to `/usr/sbin/sayip-node-utils`
- Install audio files to `/usr/local/share/asterisk/sounds/`
- Create `/etc/asterisk/custom/rpt/sayip.conf` with DTMF commands configured for your node number
- Enable a systemd service (`allstar-sayip.service`) that announces the local IP on boot

### Post-Installation

After installation:

1. **Run the ASL menu** and enable the DTMF commands in the **Customization** menu:
   ```bash
   asl-menu
   ```
   In the menu, go to **Customization** and enable the DTMF commands for this package.

2. **Restart Asterisk** so the configuration takes effect:
   ```bash
   sudo systemctl restart asterisk
   ```

---

## 🎛️ Operation

Use the following DTMF commands from your AllStar node:

| Command | Action                         |
|---------|--------------------------------|
| `*A1`   | Say **Local IP** address       |
| `*A3`   | Say **Public IP** address      |
| `*B1`   | **Halt** the node              |
| `*B3`   | **Reboot** the node            |

---

## 🔧 Configuration

### Changing the Node Number

If you need to change the node number after installation:

1. Edit `/etc/asterisk/custom/rpt/sayip.conf` and replace the node number in the DTMF commands
2. Edit `/etc/systemd/system/allstar-sayip.service` and update the node number in the `ExecStart` line
3. Reload systemd: `sudo systemctl daemon-reload`
4. Restart Asterisk: `sudo asterisk -rx "rpt reload"` or `sudo systemctl restart asterisk`

Alternatively, you can reinstall the package with a different node number:

```bash
sudo NODE_NUMBER=NEW_NODE_NUMBER dpkg -i sayip-node-utils_1.0.0-1_all.deb
```

---

## 🔇 Disable IP Announcement on Boot

If you prefer not to announce the IP address at boot, disable the systemd service:

```bash
sudo systemctl disable allstar-sayip.service
```

To re-enable it:

```bash
sudo systemctl enable allstar-sayip.service
```

---

## 🗑️ Uninstall

To completely remove the package:

```bash
sudo dpkg -r sayip-node-utils
```

This will:
- Remove the `sayip-node-utils` script
- Remove the audio files
- Remove the systemd service
- **Note:** The configuration file `/etc/asterisk/custom/rpt/sayip.conf` will be preserved (you may want to remove it manually)

To also remove the configuration file:

```bash
sudo dpkg -r sayip-node-utils
sudo rm /etc/asterisk/custom/rpt/sayip.conf
```

---

## 📦 Package Contents

- **Script**: `/usr/sbin/sayip-node-utils` - Main Ruby script for all functionality
- **Audio Files**: `/usr/local/share/asterisk/sounds/` - Audio prompts (`.ulaw` files)
- **Configuration**: `/etc/asterisk/custom/rpt/sayip.conf` - DTMF command configuration
- **Systemd Service**: `/etc/systemd/system/allstar-sayip.service` - Boot-time IP announcement service
- **Example Config**: `/usr/share/doc/sayip-node-utils/sayip.conf.example` - Example configuration file

---

## 🔍 Manual Usage

You can also run the script manually from the command line:

```bash
sudo /usr/sbin/sayip-node-utils local NODE_NUMBER
sudo /usr/sbin/sayip-node-utils public NODE_NUMBER
sudo /usr/sbin/sayip-node-utils halt NODE_NUMBER
sudo /usr/sbin/sayip-node-utils reboot NODE_NUMBER
```

Short options are also available: `l`, `p`, `h`, `r` instead of `local`, `public`, `halt`, `reboot`.

---

## 📝 License

This package is licensed under the GPL-2+ license.

---

## 👤 Maintainer

Jory A. Pratt, W5GLE <geekypenguin@gmail.com>
