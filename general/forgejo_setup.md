# 📓 Logseq Self-Hosted Hub
**Hardware:** Raspberry Pi Zero 2W (512MB RAM)  
**OS:** Raspberry Pi OS Lite (64-bit)  
**Security:** AppArmor (Enforced) + fail2ban (Active) + Caddy (DNS-01 TLS)  
**Goal:** Trusted mail delivery, high-speed local Git pushes, and secure global access.

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
  sudo apt install apparmor apparmor-utils msmtp msmtp-mta fail2ban ca-certificates curl wget rclone -y
  ```

### 2. SD Card Longevity (Log2Ram)
```bash
curl -L https://github.com/azlux/log2ram/archive/master.tar.gz | tar zx
cd log2ram-master && sudo ./install.sh
sudo reboot
```

---

## 📧 Phase 2: Multi-Identity Mail Relay (msmtp)
Configures the Pi to send trusted mail from your custom domain aliases using Google’s SMTP.

### 1. Configure Relay: `sudo nano /etc/msmtprc`
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

BASE=https://codeberg.org/forgejo/forgejo/releases/download/v14.0.1
wget "$BASE/forgejo-14.0.1-linux-arm64" "$BASE/forgejo-14.0.1-linux-arm64.sha256"

# Verify before you install. This binary runs as a service.
sha256sum -c forgejo-14.0.1-linux-arm64.sha256 || { echo "CHECKSUM FAILED"; exit 1; }

sudo mv forgejo-14.0.1-linux-arm64 /usr/local/bin/forgejo
sudo chmod +x /usr/local/bin/forgejo
```

### 2. Config Enhancements: `sudo nano /etc/forgejo/app.ini`
```ini
[server]
DOMAIN = git.<your-domain>.dev
ROOT_URL = https://git.<your-domain>.dev/
TRUSTED_PROXIES = 127.0.0.1

[mailer]
ENABLED = true
PROTOCOL = sendmail
SENDMAIL_PATH = /usr/bin/msmtp -a dev
FROM = "Logseq Hub" <<dev-alias>@<your-domain>.dev>
```

`TRUSTED_PROXIES` gives Forgejo the real client IP from Caddy. Do **not** add
`REVERSE_PROXY_AUTHENTICATION_USER` here. That key names the header which
carries an authenticated **username** (its default is `X-WEBAUTH-USER`), not
the client IP. Point it at `X-Forwarded-For` and a client-supplied header
becomes a login name as soon as `[service] ENABLE_REVERSE_PROXY_AUTHENTICATION`
is on.

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
curl -JL "https://caddyserver.com/api/download?os=linux&arch=arm64&p=github.com/caddy-dns/cloudflare" -o caddy
chmod +x caddy
sudo mv caddy /usr/local/bin/caddy
sudo setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/caddy

# The API builds this binary on demand, so there is no published checksum to
# check against. Confirm what you installed instead:
caddy version
caddy list-modules | grep cloudflare
```

### 2. Caddyfile Setup: `nano ~/Caddyfile`
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

[Service]
User=<your-username>
Group=<your-username>
EnvironmentFile=/home/<your-username>/.caddy_env
ExecStart=/usr/local/bin/caddy run --environ --config /home/<your-username>/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /home/<your-username>/Caddyfile --force
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
Restart=on-failure

[Install]
WantedBy=multi-user.target
```
`sudo systemctl daemon-reload && sudo systemctl enable --now caddy`

---

## 🌐 Phase 5: Global Access (Cloudflare Tunnel)
### 1. Install & Authenticate
```bash
# Install from Cloudflare's signed apt repository. A bare .deb from the
# releases page carries no signature, and apt also keeps this one updated.
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
    | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" \
    | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt-get update && sudo apt-get install -y cloudflared

cloudflared tunnel login
cloudflared tunnel create logseq-tunnel
cloudflared tunnel route dns logseq-tunnel git.<your-domain>.dev
```

### 2. Config: `sudo nano /etc/cloudflared/config.yml`
```yaml
tunnel: <TUNNEL-UUID>
credentials-file: /home/<your-username>/.cloudflared/<TUNNEL-UUID>.json

ingress:
  - hostname: git.<your-domain>.dev
    service: http://localhost:3000
  - service: http_status:404
```
`sudo cloudflared service install && sudo systemctl start cloudflared`

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
set -euo pipefail

# Always bring Forgejo back, even if rclone hangs or the script is killed.
# Without this trap, one bad run leaves the server down until you notice.
trap 'sudo systemctl start forgejo' EXIT

notify() {
    printf 'Subject: %s\n\n%s\n' "$1" "$2" | msmtp -a dev <user>@<your-domain>.dev
}

sudo systemctl stop forgejo

# No --progress: cron has no tty, so it only fills the mail with noise.
if rclone sync /var/lib/forgejo/ gdrive:Forgejo_Backup; then
    notify "Backup Success" "rclone sync completed."
else
    notify "BACKUP FAILED" "rclone sync failed. Check the rclone log."
fi
```

### 2. Automation (`crontab -e`)
```bash
# Daily Backup at 3 AM
0 3 * * * /bin/bash /home/<your-username>/sync_notes.sh
# Weekly Update & Reboot. apt-get needs the noninteractive settings, or an
# unattended upgrade blocks on a config-file prompt and never reboots.
0 4 * * 0 sudo DEBIAN_FRONTEND=noninteractive apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=--force-confold upgrade && /sbin/reboot
```

### 3. Sudo Rights for Cron
Both jobs run from a user crontab and call `sudo`, where no password prompt is
possible. Grant the exact commands with
`sudo visudo -f /etc/sudoers.d/forgejo-backup`:
```text
<your-username> ALL=(root) NOPASSWD: /usr/bin/systemctl start forgejo, /usr/bin/systemctl stop forgejo
```

---

## 📱 Phase 8: Mobile & Networking
* **Split-Brain DNS:** Map `git.<your-domain>.dev` to Pi's internal IP in your router for local speed.
* **SPF Record:** TXT record `v=spf1 include:_spf.mx.cloudflare.net include:_spf.google.com ~all`.
* **Mobile Mail:** Sync identities to Gmail App using "Send Mail As" (Desktop Settings) with `smtp.gmail.com` and App Password.

---

## 🆘 Phase 9: Disaster Recovery (Restoration Guide)
### 1. Re-initialize
Follow **Phases 1-4** on a new SD card. **Do not run the web installer.**

### 2. Restore Data
```bash
sudo systemctl stop forgejo
sudo rclone copy gdrive:Forgejo_Backup /var/lib/forgejo/ --progress
```

### 3. Permissions & Restart
```bash
sudo chown -R git:git /var/lib/forgejo/
sudo chmod -R 750 /var/lib/forgejo/
sudo systemctl start forgejo
```

---

## 🩹 Phase 10: Troubleshooting
**Tunnel Connectivity:** If the tunnel fails after a reboot, check logs:
`journalctl -u cloudflared`. Often caused by system time being out of sync (Pi Zero quirk).
**SMTP Failures:** Check `tail -f /var/log/msmtp.log`. Common fix: Renew Google App Password.
