# Raspberry Pi 5 Media Stack (Integrated Single-Hostname Setup)

This configuration is optimized for an ASUS router environment where only one hostname (`jellyfin-pi.internal`) is assigned to the Pi. It includes Jellyfin (Media), qBittorrent (Downloads), and MeTube (YouTube Downloader).

## 1. Prerequisites & OS Tuning
We install **Log2Ram** to prevent frequent log writes from wearing out your SD card.

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
Mount your media drive to `/mnt/media`. This assumes your movies/shows are in the root of the drive.

```bash
# 1. Identify UUID
sudo blkid

# 2. Create mount point & set permissions
sudo mkdir -p /mnt/media
sudo mkdir -p /mnt/media/YouTube
sudo chown -R $USER:$USER /mnt/media

# 3. Add to fstab for auto-mount (replace YOUR-UUID-HERE)
sudo nano /etc/fstab
# Add line: UUID=YOUR-UUID-HERE /mnt/media ext4 defaults,nofail 0 2

# 4. Mount the drive
sudo mount -a
```

## 3. Docker & Directory Setup
Install Docker and prepare the persistence folders.

```bash
# Install Docker
curl -fsSL [https://get.docker.com](https://get.docker.com) -o get-docker.sh && sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker 

# Create configuration directories
mkdir -p ~/media-stack/{jellyfin,qbit,metube-config,caddy-data,caddy-config}
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
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8096/health"]
      interval: 1m
      timeout: 10s

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
      - /mnt/media:/downloads
    restart: unless-stopped

  metube:
    image: alexta69/metube:latest
    container_name: metube
    restart: unless-stopped
    environment:
      - URL_PREFIX=/youtube
      - DOWNLOAD_DIR=/downloads
      - STATE_DIR=/config
      - YTDL_OPTIONS={"format":"bestvideo[height<=1080]+bestaudio/best[height<=1080]"}
      - OUTPUT_TEMPLATE=%(title)s.%(ext)s
    volumes:
      - /mnt/media/YouTube:/downloads
      - ./metube-config:/config

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
jellyfin-pi.internal {
    tls internal

    # Route for qBittorrent
    handle_path /torrent* {
        reverse_proxy qbittorrent:8080 {
            header_up Host {upstream_hostport}
            header_up X-Forwarded-Host {host}
        }
    }

    # Consolidated MeTube Route (Handles subpath + leaked root assets)
    @metube_stuff {
        path /youtube* /scripts-*.js /polyfills-*.js /main-*.js /styles-*.css /favicon.ico /socket.io* /assets/* /version /youtubesocket.io*
    }
    handle @metube_stuff {
        reverse_proxy metube:8081
    }

    # Default route for Jellyfin
    handle {
        reverse_proxy jellyfin:8096
    }
}
```

## 5. Deployment & Permissions
To avoid "Permission Denied" errors, we ensure your user owns everything before launching.

```bash
# Reclaim ownership
sudo chown -R $USER:$USER ~/media-stack

# Launch stack
docker compose up -d
```

## 6. Initial Configuration Tips

1.  **ASUS Router:** Set the Pi's hostname to `jellyfin-pi` in your DHCP reservation list.
2.  **Jellyfin (`/`):** Go to Playback settings. Enable **V4L2** and check **HEVC** for hardware acceleration. Add `/media/YouTube` as a new library.
3.  **qBittorrent (`/torrent/`):** Log in and uncheck **"Enable Cross-Site Request Forgery (CSRF) protection"** in Web UI settings to allow the reverse proxy.
4.  **MeTube (`/youtube/`):** Access the UI and paste any URL. Downloads will automatically be capped at 1080p and saved to the `YouTube` folder on your HDD.

## 7. Maintenance Schedule (Cron)
Run `crontab -e` and add the following:

```bash
# 03:30 - Write logs to SD (Log2Ram)
30 3 * * * /usr/sbin/log2ram write >> /home/ishmael/maintenance.log 2>&1

# Sun 04:00 - Weekly OS and Docker Updates + Reboot
0 4 * * 0 sudo apt-get update && sudo apt-get upgrade -y && cd /home/ishmael/media-stack && /usr/bin/docker compose pull && /usr/bin/docker compose up -d && /sbin/reboot
```
