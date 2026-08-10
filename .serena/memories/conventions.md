# Conventions

- Nix files: per-host flake layout; modules get `{ config, pkgs, lib, ... }`. Home-manager blocks use `home-manager.users.yovick`.
- Every non-obvious decision gets a SHORT Spanish comment explaining the why (hardware quirks, nixpkgs version traps, wayland gotchas). Comments in Lua config (hyprland) too.
- Commits: Spanish, conventional-commit style (feat/fix/chore + scope, e.g. `fix(hyprland):`).
- Ponytail rules: reuse over rewrite, no new deps unless needed, deletion over addition, mark deliberate corners with `ponytail:` comment, non-trivial logic leaves one runnable check.
- Window rules in hyprland-home.nix use the Lua DSL: hl.window_rule({ name, match = { class = "..." }, no_blur = true, opacity = "1 override" }) — kebab-case hyprlang rules become snake_case lua fields.
- hyprland config is Lua (configType = "lua", Hyprland 0.57+, hyprlang deprecated): hl.config/hl.monitor/hl.bind/hl.exec_cmd etc.
