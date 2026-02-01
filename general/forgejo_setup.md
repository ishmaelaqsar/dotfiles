# 📓 Logseq Self-Hosted Hub: The "Messy" Thinking Master Blueprint
**Hardware:** Raspberry Pi Zero 2W  
**OS:** Raspberry Pi OS Lite (64-bit)  
**Primary Tech:** Forgejo + Caddy (DNS-01) + Cloudflare Tunnel + Rclone  
**Goal:** Trusted SSL for local git pushes, secure global access, and daily cloud backups.

---

## 🏗️ Phase 1: System Foundation
### 1. OS Preparation
* **Tool:** Raspberry Pi Imager.
* **OS:** Raspberry Pi OS Lite (64-bit).
* **Settings:** Enable **SSH**, configure **Wi-Fi**, and set username: `<your-username>`.

### 2. SD Card Longevity (Log2Ram)
To prevent SD card wear from constant logging by writing logs to RAM:
```bash
curl -L [https://github.com/azlux/log2ram/archive/master.tar.gz](https://github.com/azlux/log2ram/archive/master.tar.gz) | tar zx
cd log2ram-master && sudo ./install.sh
sudo reboot
```

---

## 🛠️ Phase 2: Forgejo Git Server (v14.0.1)
### 1. Installation & Directory Setup
```bash
# Create dedicated git user
sudo adduser --system --shell /bin/bash --group --disabled-password --home /home/git git

# Create required directories
sudo mkdir -p /var/lib/forgejo/{custom,data,log} /etc/forgejo
sudo chown -R git:git /var/lib/forgejo/
sudo chown root:git /etc/forgejo && sudo chmod 770 /etc/forgejo

# Download Forgejo v14.0.1 (ARM64)
wget [https://codeberg.org/forgejo/forgejo/releases/download/v14.0.1/forgejo-14.0.1-linux-arm64](https://codeberg.org/forgejo/forgejo/releases/download/v14.0.1/forgejo-14.0.1-linux-arm64)
sudo mv forgejo-14.0.1-linux-arm64 /usr/local/bin/forgejo
sudo chmod +x /usr/local/bin/forgejo
```

### 2. Configure System Service: `sudo nano /etc/systemd/system/forgejo.service`
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

## 🔐 Phase 3: Local HTTPS Gateway (Caddy)
This ensures that when you are at home, you get a "Green Lock" (trusted SSL) without needing a local CA, and allows for high-speed local Git syncing.

### 1. Install Custom Caddy (ARM64 + Cloudflare Plugin)
```bash
# Download binary with Cloudflare DNS module
curl -JL "[https://caddyserver.com/api/download?os=linux&arch=arm64&p=github.com/caddy-dns/cloudflare](https://caddyserver.com/api/download?os=linux&arch=arm64&p=github.com/caddy-dns/cloudflare)" -o caddy
chmod +x caddy
sudo mv caddy /usr/local/bin/caddy

# Grant permission to use ports 80/443 without root
sudo setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/caddy
```

### 2. Environment & Config
Create the token file: `nano ~/.caddy_env`
> `CF_API_TOKEN=your_cloudflare_dns_edit_token`

Create the Caddyfile in your home directory: `nano ~/Caddyfile`
```caddy
{
    email <your-email>
}

git.<your-domain>.dev {
    tls {
        dns cloudflare {env.CF_API_TOKEN}
        resolvers 1.1.1.1 1.0.0.1
    }
    reverse_proxy localhost:3000
}
```

### 3. Caddy Service: `sudo nano /etc/systemd/system/caddy.service`
```ini
[Unit]
Description=Caddy SSL Gateway
After=network.target network-online.target
Requires=network-online.target

[Service]
User=<your-username>
Group=<your-username>
EnvironmentFile=/home/<your-username>/.caddy_env
ExecStart=/usr/local/bin/caddy run --environ --config /home/<your-username>/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /home/<your-username>/Caddyfile --force
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
Restart=on-failure
TimeoutStopSec=5s

[Install]
WantedBy=multi-user.target
```
`sudo systemctl daemon-reload`
`sudo systemctl enable --now caddy`

---

## 🌐 Phase 4: Global Access (Cloudflare Tunnel)
Exposes your Git server securely when outside your home network.

### 1. Setup Tunnel
```bash
# Install Cloudflared
curl -L [https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb](https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb) -o cloudflared.deb
sudo dpkg -i cloudflared.deb

cloudflared tunnel login
cloudflared tunnel create logseq-tunnel
```

### 2. Global Config: `sudo nano /etc/cloudflared/config.yml`
```yaml
tunnel: <TUNNEL-UUID>
credentials-file: /etc/cloudflared/<TUNNEL-UUID>.json

ingress:
  - hostname: git.<your-domain>.dev
    service: http://localhost:3000  # Connects directly to Forgejo
  - service: http_status:404
```
`sudo cloudflared service install && sudo systemctl start cloudflared`

---

## 💾 Phase 5: Backups & Maintenance
### 1. Rclone Backup Script: `nano ~/sync_notes.sh`
```bash
#!/bin/bash
# Stop service for database integrity
sudo systemctl stop forgejo
# Sync to GDrive
rclone sync /var/lib/forgejo/ gdrive:Forgejo_Backup --progress
# Restart service
sudo systemctl start forgejo
```

### 2. Automation (`crontab -e`)
```bash
# Daily Backup at 3 AM
0 3 * * * /bin/bash /home/<your-username>/sync_notes.sh
# Weekly Update & Reboot
0 4 * * 0 sudo apt update && sudo apt upgrade -y && /sbin/reboot
```

---

## 📱 Phase 6: Device Setup & Networking


* **Router Setting:** Map `git.<your-domain>.dev` to your Pi Zero's **internal IP**.
* **Split-Brain Logic:**
    * **At Home:** Your devices hit the Router -> Pi Zero (Caddy) -> Forgejo. Result: **High speed, trusted SSL.**
    * **Away:** Your devices hit Cloudflare -> Tunnel -> Pi Zero (Forgejo). Result: **Secure global access.**
* **Forgejo Config:** Ensure `/etc/forgejo/app.ini` has `ROOT_URL = https://git.<your-domain>.dev/`.

---

## 🆘 Phase 7: Disaster Recovery
1.  Reinstall OS and Phase 1–4.
2.  Stop Forgejo: `sudo systemctl stop forgejo`.
3.  Restore data: `rclone copy gdrive:Forgejo_Backup /var/lib/forgejo/`.
4.  Fix permissions: `sudo chown -R git:git /var/lib/forgejo/`.
5.  Start Forgejo: `sudo systemctl start forgejo`.
