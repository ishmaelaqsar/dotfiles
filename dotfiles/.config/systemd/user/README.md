# systemd user units

The Linux counterpart of a macOS LaunchAgent. Put `*.service`, `*.timer`, or
`*.socket` files in this directory. `lib/sync-dotfiles` symlinks them to
`~/.config/systemd/user/`, then `install.sh` runs `systemctl --user
daemon-reload` and enables every unit that has an `[Install]` section.
`cleanup.sh` disables them again.

systemd ignores this README, because the name does not end in a unit suffix.

Notes:

* A unit with no `[Install]` section is installed but not enabled. Use this for
  units that another unit pulls in.
* Test a change with `systemctl --user daemon-reload && systemctl --user
  restart <unit>`. Read the logs with `journalctl --user -u <unit>`.
* A user unit runs only while the user is logged in. Run `loginctl
  enable-linger` for a unit that must survive logout.
