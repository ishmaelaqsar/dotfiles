# 📓 Logseq Self-Hosted Hub
**Hardware:** Raspberry Pi Zero 2W (512MB RAM)  
**OS:** Raspberry Pi OS Lite (64-bit)  
**Primary Tech:** Forgejo + Caddy (TLS) + msmtp (Relay) + fail2ban + Cloudflare Tunnel + Rclone  

---

## 🏗️ Phase 1: System Foundation
### 1. OS & Security Prep
* **OS:** Raspberry Pi OS Lite (64-bit).
* **Enable AppArmor:** 
  ```bash
  sudo sed -i '$ s/$/ lsm=apparmor/' /boot/firmware/cmdline.txt
  ```
* **Install Core Utilities & Security:**
  ```bash
  sudo apt update && sudo apt upgrade -y
  sudo apt install apparmor apparmor-utils msmtp msmtp-mta fail2ban ca-certificates curl wget -y
  ```

### 2. SD Card Longevity (Log2Ram)
```bash
curl -L [https://github.com/azlux/log2ram/archive/master.tar.gz](https://github.com/azlux/log2ram/archive/master.tar.gz) | tar zx
cd log2ram-master && sudo ./install.sh
sudo reboot
```

---

## 📧 Phase 2: Multi-Identity Mail Relay (msmtp)
### 1. Configure the Relay: `sudo nano /etc/msmtprc`
```text
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

# Personal Identity
account        personal
host           smtp.gmail.com
port           587
from           <user>@<your-domain>.dev
user           <your-gmail-username>@gmail.com
password       <16-character-app-password>

# Forgejo/Dev Identity
account        dev
host           smtp.gmail.com
port           587
from           <dev-alias>@<your-domain>.dev
user           <your-gmail-username>@gmail.com
password       <16-character-app-password>

account default : personal
```
`sudo chmod 600 /etc/msmtprc`

### 2. AppArmor Logging Fix
```bash
echo "owner /var/log/msmtp.log rw," | sudo tee /etc/apparmor.d/local/usr.bin.msmtp
sudo systemctl reload apparmor
```

---

## 🛠️ Phase 3: Forgejo Git Server (v14.0.1)
### 1. Installation & Directory Setup
```bash
sudo adduser --system --shell /bin/bash --group --disabled-password --home /home/git git
sudo mkdir -p /var/lib/forgejo/{custom,data,log} /etc/forgejo
sudo chown -R git:git /var/lib/forgejo/
sudo chown root:git /etc/forgejo && sudo chmod 770 /etc/forgejo

wget [https://codeberg.org/forgejo/forgejo/releases/download/v14.0.1/forgejo-14.0.1-linux-arm64](https://codeberg.org/forgejo/forgejo/releases/download/v14.0.1/forgejo-14.0.1-linux-arm64)
sudo mv forgejo-14.0.1-linux-arm64 /usr/local/bin/forgejo
sudo chmod +x /usr/local/bin/forgejo
```

### 2. Forgejo Config: `sudo nano /etc/forgejo/app.ini`
```ini
[server]
DOMAIN = git.<your-domain>.dev
ROOT_URL = https://git.<your-domain>.dev/
TRUSTED_PROXIES = 127.0.0.1
REVERSE_PROXY_AUTHENTICATION_USER = X-Forwarded-For

[mailer]
ENABLED = true
PROTOCOL = sendmail
SENDMAIL_PATH = /usr/bin/msmtp -a dev
FROM = "Logseq Hub" <<dev-alias>@<your-domain>.dev>
```

### 3. Service Setup: `sudo nano /etc/systemd/system/forgejo.service`
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

## 🔐 Phase 4: Local HTTPS Gateway (Caddy)
### 1. Install Custom Caddy (DNS-01)
```bash
curl -JL "[https://caddyserver.com/api/download?os=linux&arch=arm64&p=github.com/caddy-dns/cloudflare](https://caddyserver.com/api/download?os=linux&arch=arm64&p=github.com/caddy-dns/cloudflare)" -o caddy
chmod +x caddy
sudo mv caddy /usr/local/bin/caddy
sudo setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/caddy
```

### 2. Config Setup
`nano ~/.caddy_env` -> `CF_API_TOKEN=<your_token>`

`nano ~/Caddyfile`:
```caddy
{
    email <your-email>
}

git.<your-domain>.dev {
    tls {
        dns cloudflare {env.CF_API_TOKEN}
        resolvers 1.1.1.1
    }
    reverse_proxy localhost:3000 {
        header_up X-Forwarded-For {remote_host}
    }
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
`sudo systemctl daemon-reload && sudo systemctl enable --now caddy`

---

## 🌐 Phase 5: Global Access (Cloudflare Tunnel)
### 1. Install Cloudflared
```bash
curl -L [https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb](https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb) -o cloudflared.deb
sudo dpkg -i cloudflared.deb
```

### 2. Authenticate & Create Tunnel
```bash
# Follow the link provided by this command to log in
cloudflared tunnel login

# Create the tunnel and copy the ID (UUID)
cloudflared tunnel create logseq-tunnel

# Route the tunnel to your domain
cloudflared tunnel route dns logseq-tunnel git.<your-domain>.dev
```

### 3. Tunnel Configuration: `sudo nano /etc/cloudflared/config.yml`
```yaml
tunnel: <YOUR-TUNNEL-UUID>
credentials-file: /home/<your-username>/.cloudflared/<YOUR-TUNNEL-UUID>.json

ingress:
  - hostname: git.<your-domain>.dev
    service: http://localhost:3000
  - service: http_status:404
```

### 4. Install Service
```bash
sudo cloudflared service install
sudo systemctl start cloudflared
```

---

## 🛡️ Phase 6: Active Defense (fail2ban)
### 1. Filter: `sudo nano /etc/fail2ban/filter.d/forgejo.conf`
```text
[Definition]
failregex = ^.*Failed authentication attempt for .* from <HOST>
            ^.*Invalid user .+ from <HOST>
```

### 2. Jail: `sudo nano /etc/fail2ban/jail.d/forgejo.local`
```text
[forgejo]
enabled = true
port = http,https
filter = forgejo
logpath = /var/lib/forgejo/log/forgejo.log
maxretry = 5
bantime = 1h
```
`sudo systemctl restart fail2ban`

---

## 💾 Phase 7: Backups & Automation
### 1. Rclone Backup Script: `nano ~/sync_notes.sh`
```bash
#!/bin/bash
sudo systemctl stop forgejo
if rclone sync /var/lib/forgejo/ gdrive:Forgejo_Backup --progress; then
    echo "Subject: Backup Success" | msmtp <user>@<your-domain>.dev
else
    echo "Subject: BACKUP FAILED" | msmtp -a dev <user>@<your-domain>.dev
fi
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

## 📱 Phase 8: Mobile & Deliverability
* **DNS:** Add TXT record `v=spf1 include:_spf.mx.cloudflare.net include:_spf.google.com ~all`.
* **Gmail:** Add identities in Desktop Gmail Settings (Accounts & Import) using `smtp.gmail.com` and App Password.
