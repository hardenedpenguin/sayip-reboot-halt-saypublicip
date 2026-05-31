# SayIP for ASL3

![GitHub total downloads](https://img.shields.io/github/downloads/hardenedpenguin/sayip-reboot-halt-saypublicip/total?style=flat-square)

This is a Debian package for AllStarLink V3 nodes that speaks the node's IP address at boot. It can announce the **local** or **public** IP address and includes features to **halt** or **reboot** the node using DTMF commands.

IPv4 is supported for IP discovery and announcement. IPv6 addresses are intentionally ignored.

---

## 🔧 Installation

Download and install the package with your node number:

```bash
wget https://github.com/hardenedpenguin/sayip-reboot-halt-saypublicip/releases/download/v1.0.4/sayip-node-utils_1.0.4-1_all.deb
sudo NODE_NUMBER=12345 dpkg -i sayip-node-utils_1.0.4-1_all.deb
```

This will:
- Install the `sayip-node-utils` Ruby script to `/usr/sbin/sayip-node-utils`
- Install the core library to `/usr/lib/sayip-node-utils/`
- Install audio files to `/usr/local/share/asterisk/sounds/`
- Install `/etc/default/sayip` and `/etc/sudoers.d/sayip-node-utils`
- Create `/etc/asterisk/custom/rpt/sayip.conf` with DTMF commands configured for your node number
- Enable a systemd service (`allstar-sayip.service`) that announces the local IP on boot

The node number can be supplied at install time via the `NODE_NUMBER` environment variable, debconf, or an interactive prompt.

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

### Runtime settings (`/etc/default/sayip`)

Playback timing, sound paths, and local IP filtering can be tuned without editing the script:

| Variable | Purpose |
|----------|---------|
| `ASTSND` | Asterisk sound directory for digits and letters |
| `CUSTOM_SOUNDS` | Directory for package prompt files |
| `PLAYBACK_PADDING` | Extra seconds added after calculated ulaw playback |
| `SLEEP_AFTER_INTRO` | Fixed intro delay; `0` derives delay from audio file size |
| `SKIP_IF_PREFIX` | Comma-separated interface prefixes to skip (docker, veth, etc.) |
| `PREFER_DEFAULT_ROUTE` | When `yes`, announce the default-route interface IP first |
| `USER_AGENT` | HTTP User-Agent for public IP lookups |

See `/usr/share/doc/sayip-node-utils/sayip.example` for defaults.

### Halt and reboot permissions

DTMF and the boot service run as the `asterisk` user. The package installs `/etc/sudoers.d/sayip-node-utils`, allowing `asterisk` to run `/usr/sbin/poweroff` and `/usr/sbin/reboot` without a password.

Manual use as root still works directly; non-root manual use requires `sudo`.

### Changing the Node Number

If you need to change the node number after installation:

1. Edit `/etc/asterisk/custom/rpt/sayip.conf` and replace the node number in the DTMF commands
2. Edit `/etc/systemd/system/allstar-sayip.service` and update the node number in the `ExecStart` line
3. Reload systemd: `sudo systemctl daemon-reload`
4. Restart Asterisk: `sudo asterisk -rx "rpt reload"` or `sudo systemctl restart asterisk`

Alternatively, reinstall with a node number to update both files automatically:

```bash
sudo NODE_NUMBER=NEW_NODE_NUMBER dpkg -i sayip-node-utils_1.0.4-1_all.deb
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

To remove the package:

```bash
sudo dpkg -r sayip-node-utils
```

This will:
- Remove the `sayip-node-utils` script and library
- Remove the audio files
- Stop and disable the systemd service
- **Note:** `/etc/asterisk/custom/rpt/sayip.conf` is preserved

To remove package-owned configuration as well:

```bash
sudo dpkg --purge sayip-node-utils
sudo rm -f /etc/asterisk/custom/rpt/sayip.conf
```

Purging also removes `/etc/default/sayip` and `/etc/sudoers.d/sayip-node-utils`.

---

## 📦 Package Contents

- **Script**: `/usr/sbin/sayip-node-utils` - CLI entry point
- **Library**: `/usr/lib/sayip-node-utils/utils.rb` - Core logic
- **Audio Files**: `/usr/local/share/asterisk/sounds/` - Audio prompts (`.ulaw` files)
- **Configuration**: `/etc/asterisk/custom/rpt/sayip.conf` - DTMF command configuration
- **Environment**: `/etc/default/sayip` - Runtime tuning
- **Sudoers**: `/etc/sudoers.d/sayip-node-utils` - Halt/reboot permissions for `asterisk`
- **Systemd Service**: `/etc/systemd/system/allstar-sayip.service` - Boot-time IP announcement service
- **Example Config**: `/usr/share/doc/sayip-node-utils/sayip.conf.example` - Example DTMF configuration

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

Halt and reboot require a valid node number unless `--force` is used (no audio notification):

```bash
sudo /usr/sbin/sayip-node-utils halt --force
sudo /usr/sbin/sayip-node-utils reboot --force
```

---

## 🧪 Development

Run unit tests locally:

```bash
ruby -Itest test/test_sayip_utils.rb
```

---

## 📝 License

This package is licensed under the GPL-2+ license.

---

## 👤 Maintainer

Jory A. Pratt, W5GLE <geekypenguin@gmail.com>
