# NixOS Configuration — Modular, Cyberpunk, Flake-Driven

[![License: GPL v3](https://img.shields.io/badge/Source%20Code-GPLv3-blue.svg)](LICENSE-SOFTWARE)
[![License: CERN-OHL-S](https://img.shields.io/badge/Hardware-CERN--OHL--S%20v2-orange.svg)](LICENSE-HARDWARE)
[![License: CC BY-SA 4.0](https://img.shields.io/badge/Docs%20%26%20Media-CC%20BY--SA%204.0-lightgrey.svg)](LICENSE-MEDIA)

Personal NixOS configuration managed with [Nix flakes](https://nixos.wiki/wiki/Flakes), [Home Manager](https://github.com/nix-community/home-manager), and [Stylix](https://github.com/danth/stylix). Cyberpunk-themed, AMD-powered, Hyprland-driven.

## Architecture

```
flake.nix              # Entry point — defines hosts & shared modules
├── hosts/             # Per-machine configuration
│   ├── pc/            # Desktop (Ryzen 5700X + RX 7600)
│   ├── laptop/        # ThinkPad / AMD laptop
│   ├── server/        # Headless server
│   └── vm/            # QEMU/VMware guest
├── modules/           # Reusable NixOS & Home Manager modules
│   ├── apps/          # Application configs (shell, neovim, firefox, git, etc.)
│   ├── core/          # System-level user config
│   ├── desktop/       # Hyprland compositor (system + home)
│   ├── hardware/      # AMD-specific tuning (common, desktop, laptop)
│   └── theming/       # Stylix, Plymouth, wallpapers
├── home/              # Home Manager user entry point
└── docs/              # Documentation
```

## Hosts

| Host   | Role      | Hardware                    | GPU          | Kernel      |
| ------ | --------- | --------------------------- | ------------ | ----------- |
| `pc`   | Desktop   | Ryzen 5700X                 | RX 7600      | Zen + pstate active |
| `laptop` | Mobile  | AMD laptop (e.g., ThinkPad) | Integrated   | Zen + pstate guided |
| `server` | Server  | AMD headless                | (none)       | Zen + mitigations |
| `vm`   | Virtual   | QEMU/VMware                 | virtio/vmwgfx | Zen + virtio |

## Features

### System

- **AMD-optimized**: Zen kernel, microcode, GPU enablement, power management profiles per host
- **Hyprland**: Dynamic tiling Wayland compositor with cyberpunk-themed keybinds, animations, and autohiding bars
- **Stylix**: Catppuccin Mocha base16 theme across the entire desktop (GTK, Firefox, cursor, fonts)
- **Plymouth**: Custom boot splash with `sddm-astronaut` (cyberpunk theme)
- **PipeWire**: Pro-audio setup (ALSA, PulseAudio, JACK)
- **ZRAM**: 50% memory compression
- **Gaming**: Steam + Gamescope + MangoHud + Proton GE + GameMode

### Shell & UX

- **Zsh** + Oh My Zsh + Powerlevel10k with custom keybinds
- **WezTerm**: GPU-accelerated terminal with Cyberdyne color scheme, tabless autohide
- **Neovim**: LazyVim-based with cyberneon theme, Ollama integration, markdown rendering, Obsidian.nvim
- **fastfetch**: Cyberpunk-styled system info on terminal open
- **MPD + ncmpcpp**: Music playback with spectrum visualizer
- **Firefox**: Autohiding toolbar, dark theme via userChrome.css

### Custom Scripts

- `dev()` — Splits WezTerm into a full dev layout (code, terminal, cava, pipes)
- `SecDesk` / `Mirror` — scrcpy-based tablet mirroring over USB or WiFi
- `ytsong` / `ytlist` — Download YouTube audio from clipboard
- `estabilizar_clips` / `subtitular` — Video stabilisation & Whisper-based subtitle generation

### Applications

Development: Neovim, Ollama, Aider, Git, OpenCode, OBS Studio  
Creative: Blender, Krita, GIMP, Inkscape, Audacity, Mixxx, Shotcut  
Engineering: KiCad, FreeCAD, OpenRocket, QUCS-S, SimulIDE, Logisim  
Productivity: LibreOffice, Obsidian, KeePassXC, Syncthing  
Gaming: Steam, Proton GE, Wine, MangoHud

## Quick Start

```bash
# Build a host configuration
sudo nixos-rebuild switch --flake .#pc

# Build with Home Manager changes only
home-manager switch --flake .#pc

# Update flake inputs
nix flake update
```

## Applying to a New Machine

1. Install NixOS on the machine (official installer).
2. Clone this repo: `git clone https://github.com/<you>/nixos-config && cd nixos-config`
3. Deploy with `./bootstrap.sh <host>` — regenerates `hardware-configuration.nix`
   from the real disks (no manual step needed), runs `nixos-rebuild switch --flake .#<host>`
   and commits the file.
4. Add your host under `hosts/<name>/configuration.nix`, import the relevant
   modules from `modules/`, and register it in `flake.nix` under `nixosConfigurations`.

> **For people cloning this repo:** nothing machine-specific or secret is committed.
> The config builds the `yovick` user with an `initialPassword` that only applies when
> the user is created (first boot) — change it with `passwd` and rename the user,
> hostname and `git remote` to your own.

## License

This project uses a multi-license model:

- **Source code** (`flake.nix`, `modules/`, `hosts/`, `home/`): [GNU GPLv3](LICENSE-SOFTWARE)
- **Hardware** (`hardware/`): [CERN-OHL-S v2](LICENSE-HARDWARE)
- **Documentation & media** (`docs/`, wallpapers): [CC BY-SA 4.0](LICENSE-MEDIA)
