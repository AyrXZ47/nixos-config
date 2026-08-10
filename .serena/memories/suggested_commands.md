# Commands

- `sudo nixos-rebuild switch --flake .#<host>` — apply system + home (host ∈ pc|laptop|server|vm). Rebuild is ALWAYS run by the user, after the commit.
- `home-manager switch --flake .#<host>` — Home Manager only.
- `nix flake check` — evaluate all hosts; the only verification (no tests/CI/lint). Run after any change.
- `nix flake update` — bump inputs.
- `nix build .#nixosConfigurations.<host>.pkgs.<attr>` — build a single package as the host sees it (e.g. `.pkgs.hypr-kdeconnect-fix`).
- `./bootstrap.sh <host>` — regenerate hardware-configuration.nix, rebuild, commit.
- Bus/portal introspection: `busctl --user introspect org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop org.freedesktop.portal.RemoteDesktop`; `systemctl --user restart xdg-desktop-portal`.
- `nix eval --raw nixpkgs#attr` resolves against the registry (latest unstable), NOT the flake's pinned nixpkgs.
