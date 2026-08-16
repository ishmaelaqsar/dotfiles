# general/

Assets and reference material that are **not** dotfiles. Only `0xProto/` is
consumed by the tooling. Everything else is documentation you read by hand.

| Path | Used by | What it is |
|---|---|---|
| `0xProto/` | `install.sh`, `cleanup.sh` | Vendored 0xProto Nerd Font. `install.sh` copies the `.ttf` files to the user font directory; `cleanup.sh` removes them again. |
| `forgejo-setup.md` | — | Build notes for a self-hosted Forgejo git server on a Raspberry Pi Zero 2W: msmtp relay, Caddy with DNS-01 TLS, a Cloudflare tunnel, fail2ban, and rclone backups. |
| `jellyfin-setup.md` | — | Build notes for a Raspberry Pi 5 media stack: Jellyfin, qBittorrent, MeTube, FileBrowser and Caddy, all under Docker Compose. |
| `pi-hole-crontab.example` | — | Maintenance crontab for the Pi-hole host. |
| `pi-hole-msmtprc.example` | — | msmtp relay configuration for the Pi-hole host. |
| `night-street-wallpapers.jpg` | — | Desktop wallpaper. |

## Conventions

The `.example` files are **redacted templates**, not restorable backups.
Placeholders use angle brackets, such as `<your-email>`. Substitute them by
hand: neither cron nor msmtp expands shell variables in its configuration file,
so a `$VAR` left in place is used as that literal string.

Keep secrets out of this directory. It is a public repository. Read a password
through `passwordeval` or an equivalent indirection instead of writing it down.
