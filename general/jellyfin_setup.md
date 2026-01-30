# Raspberry Pi 5 Media Stack: Jellyfin, qBittorrent, & Caddy

A high-performance, low-maintenance media server setup for the Raspberry Pi 5 (2GB), optimized for SD card longevity and local `.internal` domain access.

## 1. Prerequisites & OS Tuning
First, we update the system and install **Log2Ram** to protect the SD card from constant log writes.

```bash
# Update system
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git-core

# Install Log2Ram
curl -L [https://github.com/azlux/log2ram/archive/master.tar.gz](https://github.com/azlux/log2ram/archive/master.tar.gz) | tar zx
cd log2ram-master && sudo ./install.sh
cd ..
```

## 2. Mount External HDD (Root Setup)
We will mount your HDD to `/mnt/media`. Since your movies/shows are in the drive's root, this will be our primary media path.

```bash
# 1. Identify UUID (e.g., /dev/sda1)
sudo blkid

# 2. Create mount point & set permissions
sudo mkdir -p /mnt/media
sudo chown -R $USER:$USER /mnt/media

# 3. Add to fstab for auto-mount (replace YOUR-UUID)
sudo nano /etc/fstab
# Add line: UUID=YOUR-UUID-HERE /mnt/media ext4 defaults,nofail 0 2

# 4. Mount now
sudo mount -a
```

## 3. Docker & Directory Structure
Install Docker and create the configuration folders.

```bash
# Install Docker
curl -fsSL [https://get.docker.com](https://get.docker.com) -o get-docker.sh && sudo sh get-docker.sh
sudo usermod -aG docker $USER
# IMPORTANT: Apply group changes for current session
newgrp docker 

# Create directories
mkdir -p ~/media-stack/{jellyfin,qbit,caddy-data,caddy-config}
cd ~/media-stack
```

## 4. Configuration Files

### `docker-compose.yml`
```yaml
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    user: 1000:1000
    volumes:
      - ./jellyfin:/config
      - /mnt/media:/media:ro # Your HDD Root
    devices:
      - /dev/dri:/dev/dri      # Pi 5 HEVC Hardware Accel
    restart: unless-stopped

  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - WEBUI_PORT=8080
    volumes:
      - ./qbit:/config
      - /mnt/media:/downloads  # Downloads to HDD Root
    restart: unless-stopped

  caddy:
    image: caddy:latest
    container_name: caddy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./caddy-data:/data
      - ./caddy-config:/config
    restart: unless-stopped
```

### `Caddyfile`
```caddy
# Jellyfin Route
jellyfin-pi.internal {
    tls internal
    reverse_proxy jellyfin:8096
}

# qBittorrent Route
torrent-pi.internal {
    tls internal
    reverse_proxy qbittorrent:8080
}
```

## 5. Deployment & Permissions
To avoid "Permission Denied" errors, we ensure your user owns the config folders before starting.

```bash
# Set folder ownership
sudo chown -R $USER:$USER ~/media-stack

# Launch stack
docker compose up -d
```

## 6. Initial Service Setup

### DNS
In your router settings, point `jellyfin-pi.internal` and `torrent-pi.internal` to your Pi's Static IP.

### Jellyfin (`https://jellyfin-pi.internal`)
1. **Library:** Add `/media`. Select **Content Type: Mixed Movies and Shows**.
2. **Playback:** Go to Dashboard > Playback.
   - **Hardware Acceleration:** `Video4Linux2 (V4L2)`.
   - **Enable Decoding for:** Check **HEVC** (Pi 5 has a hardware HEVC decoder).
   - **Note:** Do *not* check H.264 (Pi 5 decodes this via CPU).

### qBittorrent (`https://torrent-pi.internal`)
- **Default Login:** `admin` / `adminadmin` (Change immediately in Web UI settings).
- **Save Path:** Ensure "Default Save Path" is set to `/downloads`.

## 7. Maintenance Schedule (Cron)
Add these to your crontab (`crontab -e`) to keep the system healthy.

```bash
# === DAILY ===
# 03:30 - Write logs to SD (Log2Ram)
30 3 * * * /usr/sbin/log2ram write >> /home/ishmael/maintenance.log 2>&1

# === WEEKLY ===
# Sun 04:00 - System OS Updates
0 4 * * 0 sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y

# Sun 04:15 - Update Docker Images
15 4 * * 0 cd /home/ishmael/media-stack && /usr/bin/docker compose pull && /usr/bin/docker compose up -d

# Sun 04:30 - Weekly Reboot
30 4 * * 0 /sbin/reboot
```
