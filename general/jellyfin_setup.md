# Raspberry Pi 5 Media Stack

This configuration is specifically tuned for a **2GB Raspberry Pi 5**.

---

## 1. Prerequisites & OS Tuning
We install **Log2Ram** to protect the SD card and enable **Cgroups** to allow Docker to limit RAM usage.

```bash
# Update system
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git-core

# 1. Install Log2Ram
curl -L [https://github.com/azlux/log2ram/archive/master.tar.gz](https://github.com/azlux/log2ram/archive/master.tar.gz) | tar zx
cd log2ram-master && sudo ./install.sh
cd ..

# 2. Enable Cgroup Memory Support (Required for Docker RAM limits)
# Add parameters to the end of the existing line (do not create a new line)
sudo nano /boot/firmware/cmdline.txt
# Add to end: cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1

# 3. Reboot to apply kernel changes
sudo reboot
```

---

## 2. Mount External HDD
Mount your media drive to `/mnt/media`. 

```bash
# 1. Identify UUID
sudo blkid

# 2. Create mount point
sudo mkdir -p /mnt/media
sudo mkdir -p /mnt/media/YouTube
sudo chown -R $USER:$USER /mnt/media

# 3. Add to fstab for auto-mount (replace YOUR-UUID-HERE)
sudo nano /etc/fstab
# Add line: UUID=YOUR-UUID-HERE /mnt/media ext4 defaults,nofail 0 2

# 4. Mount the drive
sudo mount -a
```

---

## 3. Docker & Directory Setup
Install Docker and prepare the persistence folders.

```bash
# Install Docker
curl -fsSL [https://get.docker.com](https://get.docker.com) -o get-docker.sh && sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker 

# Create configuration directories
mkdir -p ~/media-stack/{jellyfin/config,jellyfin/cache,qbit,metube-config,caddy-data,caddy-config,filebrowser}
cd ~/media-stack

# Create the environment file for Cloudflare API
nano .env
# Paste: CF_API_TOKEN=<YOUR_CLOUDFLARE_TOKEN>
chmod 600 .env
```

---

## 4. Configuration Files

### `docker-compose.yml`
```yaml
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    user: 1000:1000
    volumes:
      - ./jellyfin/config:/config
      - ./jellyfin/cache:/cache
      - /mnt/media:/media:ro
    devices:
      - /dev/dri:/dev/dri
    deploy:
      resources:
        limits:
          memory: 1200M        # Prevents Pi 5 2GB lockups
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

  filebrowser:
    image: filebrowser/filebrowser:latest
    container_name: filebrowser
    user: 1000:1000
    # Forces correct pathing for reverse proxy
    command: ["--address", "0.0.0.0", "--port", "80", "--baseurl", "/files"]
    environment:
      - FB_DATABASE=/database/filebrowser.db
    volumes:
      - /mnt/media:/srv
      - ./filebrowser/filebrowser.db:/database/filebrowser.db
      - ./filebrowser/settings.json:/config/settings.json
    restart: unless-stopped

  caddy:
    build:
      context: .
      dockerfile_inline: |
        FROM caddy:builder AS builder
        RUN xcaddy build --with [github.com/caddy-dns/cloudflare](https://github.com/caddy-dns/cloudflare)
        FROM caddy:latest
        COPY --from=builder /usr/bin/caddy /usr/bin/caddy
    container_name: caddy
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    environment:
      - CF_API_TOKEN=${CF_API_TOKEN}
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./caddy-data:/data
      - ./caddy-config:/config
    restart: unless-stopped
```

### `Caddyfile`
```caddy
jellyfin.<your-domain>.dev {
    tls {
        dns cloudflare {env.CF_API_TOKEN}
        resolvers 1.1.1.1 1.0.0.1
    }

    # File Manager
    handle /files* {
        reverse_proxy filebrowser:80
    }

    # qBittorrent
    handle_path /torrent* {
        reverse_proxy qbittorrent:8080
    }

    # MeTube
    @metube_stuff {
        path /youtube* /scripts-*.js /polyfills-*.js /main-*.js /styles-*.css /favicon.ico /socket.io* /assets/* /version /youtubesocket.io*
    }
    handle @metube_stuff {
        reverse_proxy metube:8081
    }

    # Default Jellyfin
    handle {
        reverse_proxy jellyfin:8096
    }
}
```

---

## 5. Deployment & Permissions
```bash
cd ~/media-stack

# 1. Pre-initialize FileBrowser DB
touch ./filebrowser/filebrowser.db
chmod 666 ./filebrowser/filebrowser.db

# 2. Final ownership check
sudo chown -R $USER:$USER ~/media-stack

# 3. Launch
docker compose build caddy
docker compose up -d
```

---

## 6. Initial Configuration Tips

1.  **FileBrowser:** Check logs (`docker logs filebrowser`) to get your unique **initial admin password**.
2.  **qBittorrent:** Go to Advanced Settings and set **"Physical memory usage limit"** to **128 MiB**.
3.  **Jellyfin:** Ensure Hardware Acceleration is set to **V4L2**.
4.  **ZRAM:** Run `zramctl` to ensure your swap is compressed in RAM for better performance.
