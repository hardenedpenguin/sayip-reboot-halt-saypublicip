# SayIP for ASL3

![GitHub total downloads](https://img.shields.io/github/downloads/hardenedpenguin/sayip-reboot-halt-saypublicip/total?style=flat-square)

This is a Debian package for AllStarLink V3 nodes that speaks the node's IP address at boot. It can announce the **local** or **public** IP address and includes features to **halt** or **reboot** the node using DTMF commands.

IPv4 is supported for IP discovery and announcement. IPv6 addresses are intentionally ignored.

---

## 🔧 Installation

Packages are published in the [hardenedpenguin APT repository](https://github.com/hardenedpenguin/hardenedpenguin-apt). One-time setup:

```bash
cd /tmp
curl -fsSLO https://hardenedpenguin.github.io/hardenedpenguin-apt/pool/main/h/hardenedpenguin-archive-keyring/hardenedpenguin-archive-keyring_1.0_all.deb
sudo apt install ./hardenedpenguin-archive-keyring_1.0_all.deb
sudo apt update
```

The keyring package adds the GPG signing key and `/etc/apt/sources.list.d/hardenedpenguin.list`.

Install **sayip-node-utils** (replace `12345` with your AllStarLink node number):

```bash
sudo NODE_NUMBER=12345 apt install sayip-node-utils
```

On an interactive install, debconf may prompt for the node number instead. Upgrades reuse the node number from your existing `sayip.conf` — you do not need to pass `NODE_NUMBER` again:

```bash
sudo apt update
sudo apt upgrade sayip-node-utils
```

### What gets installed

This will:
- Install the `sayip-node-utils` Ruby script to `/usr/sbin/sayip-node-utils`
- Install the core library and `configure-rpt-sayip.sh` to `/usr/lib/sayip-node-utils/`
- Install audio files to `/usr/local/share/asterisk/sounds/`
- Install `/etc/default/sayip` and `/etc/sudoers.d/sayip-node-utils`
- Create `/etc/asterisk/custom/rpt/sayip.conf` with DTMF commands for your node (existing customized files are left alone unless the node number changes)
- Update `/etc/asterisk/rpt.conf` so `functions`, `phone_functions`, and `link_functions` use your node's SayIP function table (needed for IAX/phone DTMF)
- Enable a systemd service (`allstar-sayip.service`) that announces the local IP on boot

The node number can be supplied at install time via the `NODE_NUMBER` environment variable, debconf, or an interactive prompt.

### Post-Installation

After installation:

1. **Reload app_rpt** so DTMF and `rpt.conf` changes take effect:
   ```bash
   sudo asterisk -rx "module reload app_rpt.so"
   ```

   If the node stanza did not exist yet when the package was installed, add the node with `asl-menu`, then either reinstall or run:
   ```bash
   sudo /usr/lib/sayip-node-utils/configure-rpt-sayip.sh YOUR_NODE_NUMBER
   sudo asterisk -rx "module reload app_rpt.so"
   ```

2. Optional: use **asl-menu → Customization** if you prefer managing other custom function packs there; SayIP wiring is applied by the package itself.

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

Playback timing, sound paths, local IP filtering, and busy-channel behavior are tuned in `/etc/default/sayip`. The package creates this file on first install; upgrades do not overwrite your changes.

**Edit settings:**

```bash
sudo nano /etc/default/sayip
```

Use `KEY=value` lines (no `export`). Changes apply on the **next** DTMF command or boot-time announcement — no Asterisk restart is required.

**After upgrading the package**, compare your file with the shipped example for any new options:

```bash
diff -u /etc/default/sayip /usr/share/doc/sayip-node-utils/sayip.example
```

Copy only the variables you want to add or change; leave your existing values in place.

| Variable | Purpose |
|----------|---------|
| `ASTSND` | Asterisk sound directory for digits and letters |
| `CUSTOM_SOUNDS` | Directory for package prompt files |
| `PLAYBACK_PADDING` | Extra seconds added after calculated ulaw playback |
| `SLEEP_AFTER_INTRO` | Fixed intro delay; `0` derives delay from audio file size |
| `SKIP_IF_PREFIX` | Comma-separated interface prefixes to skip in `all` mode (docker, veth, etc.) |
| `LOCAL_IP_MODE` | `default_route` uses the kernel default route; `all` announces every non-skipped address |
| `LOCAL_IP_INTERFACE` | Announce only this interface (overrides other local IP settings) |
| `PREFER_INTERFACES` | Comma-separated interfaces to try before `LOCAL_IP_MODE` fallback |
| `USER_AGENT` | HTTP User-Agent for public IP lookups |
| `BUSY_CHECK` | `yes`/`no` — skip or defer IP announcements when the repeater is busy |
| `BUSY_WAIT_MAX` | Seconds to wait for idle channel before skipping (`0` = skip immediately if busy) |
| `BUSY_POLL_INTERVAL` | Seconds between busy checks while waiting |

Before announcing local or public IP, the script checks `rpt xnode` and `rpt stats` for **local RX** activity and an ID **queued in tail**. Transmitter keyed alone (hangtime or linked audio) and Identifier `QUEUED FOR CLEANUP` (normal ASL3 idle) are not treated as busy, so `*A1`/`*A3` work on connected nodes. If the receiver is busy or an ID is queued in the tail, it waits up to `BUSY_WAIT_MAX` seconds (default 120), then skips if still busy. Set `BUSY_CHECK=no` to restore always-announce behavior.

`LOCAL_IP_MODE=default_route` follows the kernel default route. If your default route is `wlan0` but you reach the node over a VPN such as `wrinkles`, set either:

```bash
LOCAL_IP_INTERFACE=wrinkles
```

or:

```bash
PREFER_INTERFACES=wrinkles
```

Loopback addresses are never announced.

Full defaults and comments: `/usr/share/doc/sayip-node-utils/sayip.example`

### Halt and reboot permissions

DTMF and the boot service run as the `asterisk` user. The package installs `/etc/sudoers.d/sayip-node-utils`, allowing `asterisk` to run `/usr/sbin/poweroff` and `/usr/sbin/reboot` without a password.

Manual use as root still works directly; non-root manual use requires `sudo`.

### Changing the Node Number

If you need to change the node number after installation:

1. Edit `/etc/asterisk/custom/rpt/sayip.conf` and replace the node number in the DTMF commands
2. Edit `/etc/systemd/system/allstar-sayip.service` and update the node number in the `ExecStart` line
3. Reload systemd: `sudo systemctl daemon-reload`
4. Reload app_rpt: `sudo asterisk -rx "module reload app_rpt.so"` or `sudo systemctl restart asterisk`

Alternatively, reinstall with a node number to update both files automatically:

```bash
sudo NODE_NUMBER=NEW_NODE_NUMBER apt install --reinstall sayip-node-utils
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
sudo apt remove sayip-node-utils
```

This will:
- Remove the `sayip-node-utils` script and library
- Remove the audio files
- Stop and disable the systemd service
- **Note:** `/etc/asterisk/custom/rpt/sayip.conf` is preserved

To remove package-owned configuration as well:

```bash
sudo apt purge sayip-node-utils
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
for f in test/test_*.rb; do ruby -Itest "$f"; done
```

---

## 📝 License

This package is licensed under the GPL-2+ license.

---

## 👤 Maintainer

Jory A. Pratt, W5GLE <geekypenguin@gmail.com>
