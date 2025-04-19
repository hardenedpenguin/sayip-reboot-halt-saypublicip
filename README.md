![SayIP Logo](https://github.com/KD5FMU/SayIP-for-ASL3/blob/main/sayip.jpg)

# SayIP for ASL3

This is a script for AllStarLink V3 nodes that speaks the node’s IP address at boot. It can announce the **local** or **public** IP address and includes features to **halt** or **reboot** the node using DTMF commands.

---

## 🔧 Installation

1. **Download the installer script:**

   ```bash
   wget https://raw.githubusercontent.com/hardenedpenguin/sayip-reboot-halt-saypublicip/refs/heads/main/asl3_sayip_reboot_halt.sh
   ```

2. **Make the script executable:**

   ```bash
   chmod +x asl3_sayip_reboot_halt.sh
   ```

3. **Run the installer with your node number:**

   ```bash
   sudo ./asl3_sayip_reboot_halt.sh YOUR_NODE_NUMBER
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

## 🔇 Disable IP Announcement on Boot

If you prefer not to announce the IP address at boot, disable the systemd service:

```bash
sudo systemctl disable allstar-sayip
```
