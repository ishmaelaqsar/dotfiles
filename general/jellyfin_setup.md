# Raspberry Pi 5 Media Stack (Single Hostname Setup)

This configuration is optimized for an ASUS router environment where only one hostname (`jellyfin-pi.internal`) is assigned to the Pi.

## 1. Prerequisites & OS Tuning
Protect your SD card by moving high-frequency log writes to RAM.

```bash
# Update system
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git-core

# Install Log2Ram
curl -L [https://github.com/azlux/log2ram/archive/master.tar.gz](https://github.com/azlux/log2ram/archive/master.tar.gz) | tar zx
cd log2ram-master && sudo ./install.sh
cd ..
```

## 2. Mount External HDD
Mount your media drive. This assumes your movies and shows are in the root of the drive.

```bash
# 1. Identify UUID (e.g., /dev/sda1)
sudo blkid

# 2. Create mount point
sudo mkdir -p /mnt/media
sudo chown -R $USER:$USER /mnt/media

# 3. Add to fstab for auto-mount (replace YOUR-UUID-HERE)
sudo nano /etc/fstab
# Add this line:
# UUID=YOUR-UUID-HERE /mnt/media ext4 defaults,nofail 0 2

# 4. Mount the drive
sudo mount -a
```

## 3. Docker & Directory Setup
Install Docker and create the necessary persistence folders.

```bash
# Install Docker
curl -fsSL [https://get.docker.com](https://get.docker.com) -o get-docker.sh && sudo sh get-docker.sh
sudo usermod -aG docker $USER
# Force apply group permissions
newgrp docker 

# Create configuration directories
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
      - /mnt/media:/media:ro
    devices:
      - /dev/dri:/dev/dri      # Pi 5 Hardware Acceleration
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
      - /mnt/media:/downloads  # Torrents download to HDD root
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
This configuration routes your single hostname to two different apps.

```caddy
jellyfin-pi.internal {
    tls internal

    # Route for qBittorrent (Subpath)
    # Note: The trailing slash in /torrent/ is important
    handle_path /torrent/* {
        reverse_proxy qbittorrent:8080 {
            header_up Host {upstream_hostport}
            header_up X-Forwarded-Host {host}
        }
    }

    # Default route for Jellyfin (Root)
    handle {
        reverse_proxy jellyfin:8096
    }
}
```

## 5. Permissions & Deployment
Fix ownership issues before launching.

```bash
# Reclaim ownership of config folders
sudo chown -R $USER:$USER ~/media-stack

# Launch the stack
docker compose up -d
```

## 6. Initial Configuration Tips

1.  **ASUS Router:** Set the Pi's hostname to `jellyfin-pi` in your DHCP reservation.
2.  **Jellyfin:** Access at `https://jellyfin-pi.internal`. In **Playback settings**, enable **V4L2** and check **HEVC** for hardware acceleration.
3.  **qBittorrent:** Access at `https://jellyfin-pi.internal/torrent/`. 
    * *Note:* If you get a white screen, go to **Settings > WebUI** (via the local IP `192.168.1.x:8080`) and uncheck **"Enable Cross-Site Request Forgery (CSRF) protection"**.

## 7. Maintenance Schedule (Cron)
Run `crontab -e` and add your maintenance logic.

```bash
# === DAILY ===
# 03:30 - Write logs to SD (Log2Ram)
30 3 * * * /usr/sbin/log2ram write >> /home/ishmael/maintenance.log 2>&1

# === WEEKLY ===
# Sun 04:00 - OS Updates
0 4 * * 0 sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y

# Sun 04:15 - Pull newest Docker images
15 4 * * 0 cd /home/ishmael/media-stack && /usr/bin/docker compose pull && /usr/bin/docker compose up -d

# Sun 04:30 - Weekly Reboot
30 4 * * 0 /sbin/reboot
```
