# Linux-Setup — CLAUDE.md

Automated, idempotent dotfiles for **Debian 13 + KDE Plasma 6 (Wayland)**.
Theme: Catppuccin modular (default: mocha/mauve) + dynamic matugen palette on wallpaper change.

## Repo layout

```
setup.sh                    # Master installer — 14 numbered phases, run as normal user
install.conf.yaml           # Dotbot symlinks (safe, always)
install-plasma.conf.yaml    # Dotbot symlinks (Plasma configs — skip before major KDE upgrades)
scripts/
  wallpaper-next.sh         # Pick random wallpaper, set via setWallpaper D-Bus
  wallpaper-apply.sh        # Run matugen + live-reload all themed apps
  wallpaper-fetch.sh        # Download wallpaper pool to ~/.local/share/wallpapers/ricing
  lib/wallpaper-watcher.py  # D-Bus signal listener → calls wallpaper-apply.sh
  theme-switch.sh           # Manual Catppuccin flavor/accent switch
  configure-dock.sh         # Create KDE panels (requires live Plasma session)
  setup-first-login.sh      # One-shot autostart: panels + first wallpaper
themes/matugen/
  config.toml               # matugen template list
  templates/                # kde.colors, kitty.conf, btop.theme, starship.toml, …
systemd/
  wallpaper-rotation.{service,timer}   # Periodic wallpaper rotation
  wallpaper-watcher.service            # Event-driven wallpaper → theme daemon
```

## Dynamic theme pipeline

```
wallpaper-next.sh / System Settings
  └─ setWallpaper D-Bus  →  wallpaperChanged signal
       └─ wallpaper-watcher.service
            └─ wallpaper-apply.sh --wallpaper <path>
                 └─ matugen image <path>
                      ├─ KDE color scheme  (plasma-apply-colorscheme, live)
                      ├─ kitty             (SIGUSR1, live)
                      ├─ Panel Colorizer   (D-Bus, live)
                      ├─ starship / fzf    (next shell)
                      ├─ btop              (next launch)
                      ├─ tidal-hifi CSS    (live if active.css configured)
                      └─ SDDM             (next login, via sudo install)
```

## Test VM

**VMX:** `C:\Users\Mathias\Documents\Virtual Machines\Debian 13 KDE\Debian 13 KDE.vmx`
**Shorthand:** `$VMX` used in all examples below.

```powershell
$VMX = "C:\Users\Mathias\Documents\Virtual Machines\Debian 13 KDE\Debian 13 KDE.vmx"
$VMRUN = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
```

### VM control

```bash
# Start (headless)
& $VMRUN -T ws start $VMX nogui

# Start (with GUI)
& $VMRUN -T ws start $VMX

# Suspend / stop
& $VMRUN -T ws suspend $VMX
& $VMRUN -T ws stop $VMX soft

# Get current IP (wait ~10s after boot)
& $VMRUN -T ws getGuestIPAddress $VMX

# Take snapshot / revert
& $VMRUN -T ws snapshot $VMX "clean-state"
& $VMRUN -T ws revertToSnapshot $VMX "clean-state"

# List snapshots
& $VMRUN -T ws listSnapshots $VMX
```

### SSH access

```bash
# Credentials: user=mathias  password=azerty  key=~/.ssh/id_ed25519
VM_IP=$(& $VMRUN -T ws getGuestIPAddress $VMX)
ssh mathias@$VM_IP

# One-liner remote command
ssh mathias@$VM_IP "bash -lc 'some command'"
```

### End-to-end test run

The VM has the git repo at `~/Documents/Linux-Setup`. Pull and run from there.

```bash
# 1. Get VM IP
VM_IP=$(& $VMRUN -T ws getGuestIPAddress $VMX)

# 2. Pull latest branch on VM
ssh mathias@$VM_IP "git -C ~/Documents/Linux-Setup fetch && git -C ~/Documents/Linux-Setup checkout feat/matugen-walls && git -C ~/Documents/Linux-Setup pull"

# 3. Run setup.sh end-to-end (stream output)
ssh mathias@$VM_IP "cd ~/Documents/Linux-Setup && bash setup.sh 2>&1" | tee setup-run.log

# 4. Revert to clean snapshot between runs
& $VMRUN -T ws revertToSnapshot $VMX "Pre-setup"
```

### Testing individual scripts

```bash
# Wallpaper pipeline
ssh mathias@$VM_IP "bash ~/Documents/Linux-Setup/scripts/wallpaper-fetch.sh"
ssh mathias@$VM_IP "bash ~/Documents/Linux-Setup/scripts/wallpaper-next.sh --first-login"
ssh mathias@$VM_IP "bash ~/Documents/Linux-Setup/scripts/wallpaper-apply.sh"

# Check watcher service
ssh mathias@$VM_IP "systemctl --user status wallpaper-watcher.service"
ssh mathias@$VM_IP "journalctl --user -u wallpaper-watcher.service -f"

# Dotbot only
ssh mathias@$VM_IP "cd ~/Documents/Linux-Setup && ./install"
```

## setup.sh phases (summary)

| Phase | What it does |
|-------|-------------|
| 1–1e  | APT base packages, Node LTS, Neovim, modern CLI tools, matugen |
| 2     | Fonts (Inter, JetBrains Mono Nerd Font) |
| 3–6   | Catppuccin KDE + Kvantum + GTK + Papirus icons |
| 7–7c  | KWin blur, kwin-better-blur, Klassy decorations |
| 8     | Krohnkite tiling |
| 9–9b  | Dock/panels, Panel Colorizer |
| 10–11b| Kitty, Zsh+Starship, Tidal HiFi |
| 12–13 | SDDM, GRUB (Catppuccin) |
| 14    | Dotbot, wallpaper fetch+rotation, watcher service, SDDM sudoers |

## Key constraints

- Runs on **Debian 13** only — no Ubuntu/Arch shims
- `configure-dock.sh` and `setup-first-login.sh` **require a live Plasma session** (D-Bus)
- `install-plasma.conf.yaml` links `kwinrc` etc. — skip before major KDE upgrades
- matugen templates use `{{ colors.<token>.dark.hex }}` syntax (not `${}`)
- `wallpaper-next.sh` uses `setWallpaper` D-Bus (not `evaluateScript`) so the `wallpaperChanged` signal fires
