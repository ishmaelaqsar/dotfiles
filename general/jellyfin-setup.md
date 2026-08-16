# Raspberry Pi 5 Media Stack

This configuration is for a **2GB Raspberry Pi 5**.

---

## 1. Prerequisites & OS Tuning
Install **Log2Ram** to protect the SD card. Enable **cgroups**, so that Docker can limit the RAM of a container.

```bash
# Update system
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git-core

# 1. Install Log2Ram
curl -L https://github.com/azlux/log2ram/archive/master.tar.gz | tar zx
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

### Make Docker wait for the drive
Every container except Caddy bind-mounts `/mnt/media`. Those containers fail to
start if Docker starts first, or if the drive is off. `restart: unless-stopped`
does not try them again. Caddy stays up, so the site answers with a 502 error.
The host then looks healthy.

```bash
sudo systemctl edit docker.service
```
```ini
[Unit]
RequiresMountsFor=/mnt/media
```
`nofail` in fstab still lets the Pi boot without the drive. This drop-in only
prevents a race between Docker and the mount.

---

## 3. Docker & Directory Setup
Install Docker and prepare the persistence folders.

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh
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
    restart: unless-stopped

  caddy:
    build:
      context: .
      dockerfile_inline: |
        FROM caddy:builder AS builder
        RUN xcaddy build --with github.com/caddy-dns/cloudflare
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

# 1. Pre-initialize the FileBrowser database.
# Docker creates a directory for a bind mount whose source is absent, so the
# file must exist first. `touch` gives it your UID, which matches the
# container's 1000:1000 — no chmod is needed.
touch ./filebrowser/filebrowser.db

# 2. Final ownership check
sudo chown -R $USER:$USER ~/media-stack

# 3. Launch
docker compose build caddy
docker compose up -d
```

---

## 6. Initial Configuration Tips

1.  **FileBrowser:** Read the log with `docker logs filebrowser` to find the **initial admin password**. Change that password immediately.
2.  **qBittorrent:** Go to Advanced Settings. Set **"Physical memory usage limit"** to **128 MiB**.
3.  **Jellyfin:** Set Hardware Acceleration to **V4L2**.
4.  **ZRAM:** Run `zramctl`. Make sure the swap is in compressed RAM, for better performance.

---

## 7. Watchdog

This stack fails quietly. The drive goes off, four containers stop, and Caddy
keeps answering, so nothing looks wrong. A watchdog turns that silence into an
alarm.

Create a check at healthchecks.io. Set the period to 15 minutes and the grace
time to 30 minutes. This Pi has no msmtp relay, so healthchecks.io sends the
mail.

```bash
sudo tee /etc/media-stack-check.env >/dev/null <<'EOF'
HC_URL=https://hc-ping.com/<your-uuid>
EOF
sudo chmod 600 /etc/media-stack-check.env
```

### `sudo nano /usr/local/bin/media-stack-check.sh`
```bash
#!/bin/bash
set -euo pipefail

# shellcheck source=/dev/null
[ -r /etc/media-stack-check.env ] && . /etc/media-stack-check.env
HC_URL="${HC_URL:-}"
cd /home/<your-username>/media-stack

hc() {   # $1 = "" | /fail
    [ -n "$HC_URL" ] || return 0
    curl -fsS -m 10 -o /dev/null "${HC_URL}$1" || true
}

# 1. The media drive. This is the usual cause.
mountpoint -q /mnt/media || { hc /fail; exit 1; }

# 2. Every service runs. Compare the count, because a container that fails to
#    create does not appear in `docker compose ps` at all.
running=$(docker compose ps --services --filter status=running | wc -l)
expected=$(docker compose config --services | wc -l)
[ "$running" -eq "$expected" ] || { hc /fail; exit 1; }

# 3. Caddy answers.
curl -fsS -m 10 -o /dev/null http://localhost/ || { hc /fail; exit 1; }

hc
```
```bash
sudo chown root:root /usr/local/bin/media-stack-check.sh
sudo chmod 700 /usr/local/bin/media-stack-check.sh
sudo /usr/local/bin/media-stack-check.sh && echo OK
```

Schedule it in root's crontab with `sudo crontab -e`:
```bash
*/15 * * * * /usr/local/bin/media-stack-check.sh
```

---

## 8. Troubleshooting

### The site returns 502, but SSH works
Caddy is up, and the other containers are not. Check the media drive first. It
is the usual cause. A drive that is off looks the same as a drive that failed.

```bash
cd ~/media-stack
docker compose ps -a          # `ps` alone hides stopped containers
ls /mnt/media                 # force the automount
findmnt /mnt/media            # must show ext4, not only autofs
```
`Exited (128)` on every container that mounts `/mnt/media` confirms the cause.
Turn the drive on, then run `docker compose up -d`.

The 502 log line is misleading. It gives the **host** address, not a container:
```
dial tcp 192.168.1.252:8096: connect: connection refused
```
The embedded DNS of Docker has no record for `jellyfin` when the container is
absent. Caddy then asks the host resolver, which is often the LAN DNS server.
That resolver answers with the address of the Pi. No service listens on that
port. The Caddyfile is not at fault.

### Do not test Jellyfin with `curl localhost:8096`
Caddy is the only service in this stack that publishes a host port. You can
reach Jellyfin only on the Docker network, so that test always fails. Use one
of these commands instead:
```bash
curl -I http://localhost                                   # through Caddy
docker exec caddy wget -qS -O /dev/null http://jellyfin:8096/
```
Wait 30-60 seconds after `up -d` before you decide. The first start on a Pi is
slow.

### Containers will not start after a kernel upgrade
Check the cgroup flags. A kernel package can rewrite `cmdline.txt`, and
Jellyfin's memory limit needs the memory controller:
```bash
grep memory /proc/cgroups     # the "enabled" column must read 1
```
Raspberry Pi OS ships `cgroup_disable=memory`. Remove that flag. Do not add
`cgroup_enable=memory` after it. Both flags on one line work only because of
the parse order.
