# Task completion

1. `nix flake check` — must pass (evaluates all 4 hosts; only verification available).
2. If a package was added/changed: build it via `nix build .#nixosConfigurations.<host>.pkgs.<attr>` (validates hash + compile + doCheck).
3. `git commit` — mandatory, never leave work uncommitted. Spanish conventional-commit message.
4. The user runs the rebuild (`sudo nixos-rebuild switch --flake .#<host>` or `home-manager switch`) AFTER the commit; agents never rebuild.
