# NixOS Configuration — Cyberpunk, Modular, Flake-Driven

[![License: GPL v3](https://img.shields.io/badge/Source%20Code-GPLv3-blue.svg)](LICENSE-SOFTWARE)
[![License: CERN-OHL-S](https://img.shields.io/badge/Hardware-CERN--OHL--S%20v2-orange.svg)](LICENSE-HARDWARE)
[![License: CC BY-SA 4.0](https://img.shields.io/badge/Docs%20%26%20Media-CC%20BY--SA%204.0-lightgrey.svg)](LICENSE-MEDIA)

Personal NixOS configuration, 100% declarative and modular. Cyberpunk-themed,
AMD-powered, Hyprland-driven. Same config runs on a VM, a desktop, a laptop and a
headless server — the idea is that whatever works in the VM works identically on
real hardware.

Built on `nixos-unstable` (nixpkgs rev `624af665418d`), Nix flakes, Home Manager,
and a hand-rolled cyberpunk theme (magenta `#ff0066` / cyan `#00f0ff` on deep navy).

## Hosts

| Host     | Role      | Hardware                  | GPU          | Tuning                                    |
| -------- | --------- | ------------------------- | ------------ | ----------------------------------------- |
| `pc`     | Desktop   | Ryzen 5700X               | RX 7600      | `amd_pstate=active`, governor `performance` |
| `laptop` | Mobile    | AMD laptop (ThinkPad-ish) | Integrated   | `amd_pstate=guided`, governor `schedutil`, power-profiles-daemon |
| `server` | Headless  | AMD                       | (none)       | `amd-common` only, no desktop             |
| `vm`     | Virtual   | QEMU/VMware               | virtio/vmwgfx| virtio initrd, LUKS + btrfs subvols      |

Every host is `x86_64-linux`, runs the Zen kernel, enables the `yovick` user with
Home Manager, and stores its mounts in `hosts/<name>/hardware-configuration.nix`
(`disk-by-label` for `pc`/`laptop`/`server`, generated for `vm`).

## Architecture

```
flake.nix              # Entry point — hosts & shared modules
├── hosts/             # Per-machine configuration
│   ├── pc/            # Desktop (Ryzen 5700X + RX 7600)
│   ├── laptop/        # AMD laptop / ThinkPad
│   ├── server/        # Headless server
│   └── vm/            # QEMU/VMware guest
├── modules/
│   ├── apps/          # Applications (system + home)
│   ├── core/          # User & Nix daemon tuning
│   ├── desktop/       # Hyprland (system + home), rofi
│   ├── hardware/      # AMD tuning (common, desktop, laptop)
│   └── theming/       # Cursor/fonts, Plymouth, wallpapers
├── home/              # Home Manager entry point (user `yovick`)
├── assets/            # Wallpapers (mp4 via mpvpaper) & fastfetch logo
└── bootstrap.sh       # One-shot deploy on a fresh machine
```

`flake.nix` defines a single `mkHost` wrapper: every host gets Home Manager (user
`yovick` + `home/default.nix`), the Nix optimization module, and then its own
`hosts/<name>/configuration.nix` on top.

## Software

### Desktop
- **Hyprland** — dwindle layout, 5px/10px gaps, 12px rounding, blur (12/3 passes),
  shadows, opacity 0.8/0.75, overshoot/bounce animations, animated gradient borders.
- **SDDM** — Wayland, `sddm-astronaut` "cyberpunk" theme.
- **wayle** — right-side cyberpunk bar: workspaces, clock, notifications, battery,
  clipboard, wallpaper, dashboard (lock/logout/reboot/poweroff).
- **rofi** — drun/run launchers with a custom `cyberpunk.rasi` theme.
- **hyprlock / swayidle**, polkit-gnome agent, `cliphist` clipboard manager,
  `hyprshot` screenshots, animated wallpapers via **mpvpaper** (looped mp4).

### Shell & Terminal
- **Zsh** + Oh My Zsh (`git`, `sudo`) + **powerlevel10k** (instant prompt) +
  autosuggestions + syntax highlighting; word-wise bindings; fzf integration.
- **WezTerm** — Cyberdyne scheme, JetBrains Mono Nerd, 14px, 0.66 background
  opacity, no decorations, hidden tab bar, maximizes on start.
- Aliases: `cat→bat`, `du→dust`, `ps→procs`, `top→btop`, `tree→eza --tree`.
- **fastfetch** on terminal open, with the repo logo via kitty image protocol.

### Editor & Dev
- **Neovim** (LazyVim) — `cyberneon` theme, smear-cursor, render-markdown,
  obsidian.nvim (`~/Sync/Notes`), img-clip paste, ollama.nvim (`qwen3.6:35b-a3b-mtp-q4_K_M`),
  mason, rainbow-delimiters, treesitter-context, lsp_lines; LSPs: lua-language-server,
  stylua, typescript-language-server, pyright, gcc.
- **OpenCode** + **Ollama** + **aider-chat** (local AI stack, `OLLAMA_API_BASE` set).
- **Headroom** — installed via `uv tool` (Python 3.13) with a user proxy on port
  `8787`; shell wrappers `headroom wrap opencode|aider`.
  - `headroom-ai` is PyPI-only (not in nixpkgs), so it is managed with `uv`: the
    binary lives at `~/.local/bin/headroom` and the env at
    `~/.local/share/uv/tools` (not in the Nix store — no rebuild needed for updates).
  - **Boot install is guarded** (`[ -x ~/.local/bin/headroom ]`): it only installs
    on the first boot, so it never stalls the boot-critical path.
  - **Updates are automatic**: the `headroom-update.timer` user timer runs weekly
    (`uv tool upgrade`) in the background and restarts the proxy. Nothing to do by
    hand. Manual checks: `uv tool list` (installed version) or
    `uv tool upgrade headroom-ai` (immediate update).

### Gaming
- **Steam** (gamescope session, Remote Play + dedicated server + LAN transfers
  firewalls, protontricks) with **Proton GE**.
- **GameMode**, **MangoHud**, **Gamescope**, **ProtonUp-Qt**, Wine (Wayland),
  Winetricks.

### Toolchains (system-wide)
- **Android**: `android-tools` (adb/fastboot).
- **Arduino**: `arduino-cli`.
- **Embedded (ESP32 / STM32)**: `esptool`, `stm32flash`, `openocd` (debug/flash).
- **Raspberry Pi**: `rpiboot` (mass-storage boot), `raspberrypi-eeprom`,
  `picocom` (serial console).
- **Rust**: `rustup` (toolchains on demand). **JS**: `pnpm`.
- **Flatpak** (pc/laptop/vm): service enabled + Flathub remote auto-added at first
  login (`flatpak-flathub.service`, idempotent oneshot).

### Applications
Productivity: LibreOffice, Obsidian, KeePassXC, Syncthing, Firefox (autohide
toolbox via userChrome.css).
Creative: Blender, Krita, GIMP, Inkscape, Audacity, Mixxx, Shotcut, OBS Studio,
VLC.
Engineering: KiCad, FreeCAD, OpenRocket, OpenMotor, Qucs-S, SimulIDE,
Logisim-Evolution, Octave.
Utilities: 1Password CLI, `gh`, btop, cava, pipes-rs, scrcpy, virt-manager,
proton-vpn, openrgb, qpwgraph, dolphin, kdeconnect, tor-browser, yt-dlp.
Fun: `cbonsai`.

## Performance & Tuning

### Nix daemon (`modules/core/nix-optimization.nix`)
- `cores = 0`, `max-jobs = auto` — uses every core/thread.
- CPU/IO scheduler `idle` while building → no freezes on the desktop.
- Substituters: `cache.nixos.org` + `hyprland.cachix.org` (avoids compiling Hyprland).
- Daily GC keeping 3 generations; automatic store optimisation.

### Hardware (`modules/hardware/`)
- Zen kernel everywhere, AMD microcode, `hardware.graphics` 32-bit.
- `zramSwap` at 50% memory.
- Common kernel params: `quiet splash loglevel=3 nowatchdog split_lock_detect=off`.
- Desktop: `amd_pstate=active`, `mitigations=off`, `max_cstate=1`, `performance`
  governor, amdgpu in initrd (early KMS).
- Laptop: `amd_pstate=guided`, `schedutil`, power-profiles-daemon, libinput
  touchpad (clickfinger, natural scrolling), iio sensors, NetworkManager with iwd.
- VM: virtio/VMware guest modules, QEMU guest agent, SPICE.

### Boot
- **systemd-boot** on every host; `boot.initrd.systemd` + Plymouth (`ironman`
  theme from `adi1090x-plymouth-themes`); quiet boot.
- PipeWire (ALSA/Pulse/JACK) + rtkit for pro audio; ZRAM swap.

## Keybindings (Hyprland)

| Keys | Action |
| ---- | ------ |
| `SUPER Backspace` | Terminal (wezterm) |
| `SUPER A` / `SUPER R` | rofi drun / run |
| `SUPER Delete` | Kill window |
| `SUPER M` | Exit session |
| `SUPER V` | Toggle floating |
| `SUPER J` | Toggle split |
| `SUPER arrows` / `SUPER SHIFT arrows` | Focus / move window |
| `SUPER 1-9` / `SUPER SHIFT 1-9` | Switch / move to workspace |
| `SUPER W` | *time-to-work*: Mixxx → Obsidian → Firefox on ws 1-3 |
| `SUPER N` | *netrunner*: btop + nvtop split |
| `SUPER SPACE` | Switch keyboard layout (latam/us) |
| `SUPER L` | Lock session |
| `SUPER P` variants | Screenshot region (`SUPER SHIFT P`) / window (`SUPER ALT P`) / screen (`SUPER P`) |
| Media keys | Volume (wpctl), mic mute, brightness (brightnessctl) |

## Custom Commands

- `dev [repo]` — full dev workspace in WezTerm panes (editor, AI, cava, pipes);
  con directorio opcional entra al repo antes de partir paneles.
- `netrunner` — nvtop + btop split.
- `SecDesk` / `Mirror` (+ `_WiFi <ip>`) — scrcpy tablet mirroring, 85 fps,
  h265/opus, virtual 1920x1080 display for a secure desk setup.
- `ytsong` / `ytlist` — download audio from clipboard (yt-dlp, cookies from Firefox).
- `estabilizar_clips` / `estabilizar_clips_gpu` — re-encode clips to CFR 30 (CPU x264
  or VA-API h264) for stable editing.
- `subtitular <video>` — Whisper (whisper.cpp) Spanish subtitles with VAD.
- `update-obsidian <version>` — rebuild & install the Obsidian RPM (Fedora tooling).

## Installation on a New Machine

1. Install NixOS with the official installer (any partitioning).
2. `git clone https://github.com/<you>/nixos-config && cd nixos-config`
3. `./bootstrap.sh <host>` — regenerates `hardware-configuration.nix` from the real
   disks, runs `sudo nixos-rebuild switch --flake .#<host>`, and commits the file.

That's it — no manual hardware step, no `gh`/GitHub auth required (the repo is public
and only the local file is touched). First login uses `initialPassword` (see
`modules/core/user.nix`); change it with `passwd`.

## Adding a New Host

1. `cp -r hosts/vm hosts/<name>`
2. Edit `hosts/<name>/configuration.nix`: hostname, hardware module imports
   (`modules/hardware/*`), desktop enablement.
3. Register it in `flake.nix` under `nixosConfigurations` with `mkHost`.
4. `./bootstrap.sh <name>`.

## Day-to-Day

```bash
sudo nixos-rebuild switch --flake .#<host>   # apply system + home changes
home-manager switch --flake .#<host>          # Home Manager only
nix flake update                              # bump inputs
nix flake check                               # evaluate all hosts
```

## Security Notes

- **Nothing secret is committed**: no SSH keys, no tokens, no credentials.
- `initialPassword` only applies when the `yovick` user is created (first boot) and
  never overrides an existing password.
- **For people cloning this repo:** the config builds the `yovick` user with that
  initial password — rename the user (`flake.nix`, `modules/core/user.nix`), hostname,
  and `git remote` to your own, then change the password after first login. Only the
  repo owner (or granted collaborators) can push; anyone can clone and fork.

## License

- **Source code** (`flake.nix`, `modules/`, `hosts/`, `home/`): [GNU GPLv3](LICENSE-SOFTWARE)
- **Hardware** (`hardware/`): [CERN-OHL-S v2](LICENSE-HARDWARE)
- **Documentation & media** (`docs/`, `assets/`): [CC BY-SA 4.0](LICENSE-MEDIA)
