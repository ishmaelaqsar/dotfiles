# 📓 Logseq Self-Hosted Hub: The "Messy" Thinking Master Blueprint
**Hardware:** Raspberry Pi Zero 2W  
**OS:** Raspberry Pi OS Lite (64-bit)  
**Primary Tech:** Forgejo (v14.0.1) + Cloudflare Tunnel + Rclone  
**Goal:** Unstructured, auto-linked notes synced across all devices with daily Google Drive backups.

---

## 🏗️ Phase 1: System Foundation
### 1. OS Preparation
* **Tool:** Raspberry Pi Imager.
* **OS:** Raspberry Pi OS Lite (64-bit).
* **Settings:** Enable **SSH**, configure **Wi-Fi**, and set username: `<your-username>`.

### 2. SD Card Longevity (Log2Ram)
To prevent SD card wear from constant logging by writing logs to RAM instead of disk:
```bash
curl -L [https://github.com/azlux/log2ram/archive/master.tar.gz](https://github.com/azlux/log2ram/archive/master.tar.gz) | tar zx
cd log2ram-master && sudo ./install.sh
sudo reboot
```

---

## 🛠️ Phase 2: Forgejo Git Server (v14.0.1)
This acts as the "Single Source of Truth" for your notes.

### 1. Installation & Directory Setup
```bash
# Create dedicated git user
sudo adduser --system --shell /bin/bash --group --disabled-password --home /home/git git

# Create required directories
sudo mkdir -p /var/lib/forgejo/{custom,data,log} /etc/forgejo
sudo chown -R git:git /var/lib/forgejo/
sudo chown root:git /etc/forgejo && sudo chmod 770 /etc/forgejo

# Download and Install Forgejo v14.0.1 (ARM64)
wget [https://codeberg.org/forgejo/forgejo/releases/download/v14.0.1/forgejo-14.0.1-linux-arm64](https://codeberg.org/forgejo/forgejo/releases/download/v14.0.1/forgejo-14.0.1-linux-arm64)
sudo mv forgejo-14.0.1-linux-arm64 /usr/local/bin/forgejo
sudo chmod +x /usr/local/bin/forgejo
```

### 2. Configure System Service
`sudo nano /etc/systemd/system/forgejo.service`
```ini
[Unit]
Description=Forgejo (Logseq Hub)
After=network.target

[Service]
Type=simple
User=git
Group=git
WorkingDirectory=/var/lib/forgejo/
ExecStart=/usr/local/bin/forgejo web -c /etc/forgejo/app.ini
Restart=always
Environment=USER=git HOME=/home/git GITEA_WORK_DIR=/var/lib/forgejo

[Install]
WantedBy=multi-user.target
```
`sudo systemctl enable --now forgejo`

---

## 🌐 Phase 3: Global Access (Cloudflare Tunnel)
Exposes your Git server securely without opening router ports.

### 1. System-Wide Setup
```bash
# Install Cloudflared
curl -L [https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb](https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb) -o cloudflared.deb
sudo dpkg -i cloudflared.deb

# Authenticate & Create Tunnel
cloudflared tunnel login
cloudflared tunnel create logseq-tunnel
cloudflared tunnel route dns logseq-tunnel git.<your-domain>.com

# Move credentials to system path for sudo access
sudo mkdir -p /etc/cloudflared
sudo cp ~/.cloudflared/*.json /etc/cloudflared/
```

### 2. Global Config: `sudo nano /etc/cloudflared/config.yml`
```yaml
tunnel: <YOUR-TUNNEL-UUID>
credentials-file: /etc/cloudflared/<YOUR-TUNNEL-UUID>.json

ingress:
  - hostname: git.<your-domain>.com
    service: http://localhost:3000
  - service: http_status:404
```
`sudo cloudflared service install && sudo systemctl start cloudflared`

---

## 💾 Phase 4: Automated Backups (Google Drive)
### 1. Rclone Configuration
Run `rclone config`, name it `gdrive`, and follow the OAuth process (authorize via your computer's browser when prompted).

### 2. The Backup Script: `nano /home/<your-username>/sync_notes.sh`
```bash
#!/bin/bash
# 1. Stop service for database integrity
sudo systemctl stop forgejo

# 2. Sync to GDrive using sudo + pointer to user config
sudo rclone sync /var/lib/forgejo/ gdrive:Forgejo_Backup \
--config /home/<your-username>/.config/rclone/rclone.conf \
--progress

# 3. Restart service
sudo systemctl start forgejo
```
`chmod +x /home/<your-username>/sync_notes.sh`

---

## 📱 Phase 5: Device Synchronization
### Mac / Linux Desktop
* **App:** Install Logseq.
* **Sync:** Go to Settings > Version Control. Enable **Auto Commit** and **Auto Push**.
* **Git:** Initialize your folder and link to `https://git.<your-domain>.com/<user>/logseq-notes.git`.

### iPhone Automation
1. **App:** Install **Working Copy**. Clone your repository.
2. **App:** In **Logseq**, "Add New Graph" and select the folder inside Working Copy.
3. **Shortcuts App:** Create a "Personal Automation" triggered when **Logseq is closed**:
    * **Logic:** Working Copy `Pull` → `Stage All` → `Commit` → `Push`.

---

## ⚙️ Phase 6: Maintenance (Crontab)
Run `crontab -e` and paste this block:

```bash
# === DAILY ===
# 03:00 - Sync Forgejo to Google Drive
0 3 * * * /bin/bash /home/<your-username>/sync_notes.sh

# 03:30 - Write logs to SD (Log2Ram maintenance)
30 3 * * * /usr/sbin/log2ram write >> /home/<your-username>/maintenance.log 2>&1

# === WEEKLY ===
# Sun 04:00 - System OS Updates
0 4 * * 0 sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y

# Sun 04:30 - Weekly Reboot for stability
30 4 * * 0 /sbin/reboot
```

---

## 🆘 Phase 7: Disaster Recovery (Restoration Guide)
If your Pi Zero's SD card dies, follow these steps to restore your entire ecosystem.

### 1. Re-initialize System
Follow **Phase 1, 2, 3, and 4 (Step 1)** of this guide on a new SD card to get the OS, Forgejo service, and Rclone config back in place. **Do not run the web installer yet.**

### 2. Stop Services
```bash
sudo systemctl stop forgejo
```

### 3. Pull Data from Google Drive
```bash
sudo rclone copy gdrive:Forgejo_Backup /var/lib/forgejo/ \
--config /home/<your-username>/.config/rclone/rclone.conf \
--progress
```

### 4. Restore Permissions & Start
```bash
# Ensure the 'git' user owns the restored files
sudo chown -R git:git /var/lib/forgejo/
sudo chmod -R 750 /var/lib/forgejo/

# Restart Forgejo
sudo systemctl start forgejo
```

### 5. Final Step
Visit `https://git.<your-domain>.com`. Your login, repositories, and messy note history will be exactly where you left them.
