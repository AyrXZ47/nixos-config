# NixOS config — ponytail, lazy senior dev

Flake-driven NixOS config for 4 hosts (pc, laptop, server, vm), x86_64-linux, single user yovick via Home Manager. README.md is the canonical doc (keybindings, fingerprint, host tuning).

Source map:
- flake.nix: `mkHost` gives EVERY host home-manager (user yovick + home/default.nix) + modules/core/nix-optimization.nix + its own hosts/<name>/configuration.nix. Also holds the `kdeconnectRemoteInputOverlay` (hypr-kdeconnect-fix package — NOT in nixpkgs).
- modules/{core,apps,desktop,hardware,theming}: two flavors — enable-flag modules (hardware/*, desktop/hyprland.nix via `modules.<category>.<name>.enable`, flipped by hosts) vs plain imports (core/*, theming/*, home-side apps).
- modules/apps: home-side (shell, wezterm, neovim, fastfetch, git, mpd, firefox, serena) imported by home/default.nix vs system-side (common-packages, flatpak, gaming) imported by host configs.
- hosts/*/hardware-configuration.nix: GENERATED, never hand-edit; `./bootstrap.sh <host>` regenerates/rebuilds/commits.

Invariants:
- yovick hardcoded in flake.nix, home/default.nix, modules/core/user.nix (user.nix also holds initialPassword; user.nix sets nixpkgs.config.allowUnfree=true).
- New feature = new file under modules/, imported by hosts that want it (NOT added to flake.nix). Match category pattern (enable-option vs plain import).
- Nothing secret committed; result*, .direnv, *.iso, *.qcow2, .aider* gitignored.
- Comments + commits in Spanish, conventional-commit style.
- Session is Hyprland (Wayland) + SDDM; XDG_CURRENT_DESKTOP=Hyprland.
- Wiring gotchas (kdeconnect, portals): see mem:portals.
