# Brief: Wave 5 · Executor 2

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Crear `modules/apps/kitty.nix` con el Home Manager module `programs.kitty`
(kitty 0.48.2 ya está en nixpkgs) y agregar su import en `home/default.nix`.
wezterm se queda instalado como fallback (no lo borres).

Kitty debe quedar con la paleta cyberpunk de Wayle, fondo translúcido y smear
cursor nativo. Valores de partida (ajústalos si el module lo pide distinto):

```nix
{ ... }:
{
  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 14.0;
    };
    settings = {
      # Vidrio (0.66 como el resto de Caelestia; el blur lo da Hyprland)
      background_opacity = "0.66";
      dynamic_background_opacity = "yes";
      background = "#0a0a12";
      foreground = "#d4d4f0";
      cursor = "#ff0066";
      cursor_text_color = "#0a0a12";
      selection_background = "#1e1e3a";
      selection_foreground = "#d4d4f0";
      # Paleta cyberpunk (16 colores)
      color0  = "#0a0a12"; color8  = "#555577";
      color1  = "#ff0040"; color9  = "#ff4d80";
      color2  = "#00ff88"; color10 = "#66ffb0";
      color3  = "#ffcc00"; color11 = "#ffe680";
      color4  = "#00aaff"; color12 = "#80ccff";
      color5  = "#ff0066"; color13 = "#ff66a0";
      color6  = "#00d4d4"; color14 = "#66e0e0";
      color7  = "#d4d4f0"; color15 = "#ffffff";
      # Smear cursor (nativo de kitty)
      cursor_trail = "1";
      cursor_trail_decay = "0.1 0.3";
      cursor_trail_start_threshold = "1";
      # Ventana
      window_padding_width = "10";
      confirm_os_window_close = "0";
      enable_audio_bell = "no";
      # Control remoto para que `kitty @ launch` funcione (lo usa hyprdev)
      allow_remote_control = "yes";
      shell_integration = "enabled";
    };
  };
}
```

En `home/default.nix`, agrega `../modules/apps/kitty.nix` al bloque `imports`
(junto a `wezterm.nix`, que se queda).

## Definition of done

- `programs.kitty.enable = true` con la paleta, `background_opacity`,
  `cursor_trail` y `allow_remote_control`.
- `home/default.nix` importa `kitty.nix`.
- El verify command pasa. Solo `modules/apps/kitty.nix` (nuevo) y
  `home/default.nix` modificados.

## Files you own

- `modules/apps/kitty.nix` (nuevo)
- `home/default.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/apps/wezterm.nix`,
  `modules/apps/shell.nix`, `modules/desktop/**`, `hosts/**`, `.workflow/**`
  (salvo leer).

## Notas de scope (Nix)

- Módulo home-side; no hay activations.

## Read first

- `modules/apps/wezterm.nix` (look actual para paridad).
- `.workflow/plan.md` → Wave 5 T2.
- HM `programs.kitty`: usa `settings` (claves de `kitty.conf`), `font`.

## Verify command

```bash
nix flake check --no-build && nix eval '.#nixosConfigurations.pc.config.home-manager.users.yovick.programs.kitty.enable' | grep -q true && nix eval --json '.#nixosConfigurations.pc.config.home-manager.users.yovick.programs.kitty.settings' | jq -e '.cursor_trail != null and .background_opacity != null and .allow_remote_control != null'
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- One commit: `feat(kitty): terminal cyberpunk con smear cursor`.
- Commit ONLY your owned files.
- BRANCH ISOLATION (mandatory): `git push origin wave5-executor-2`. Nunca a
  `main` ni a otra rama.

## Report back

- Diff, salida del verify y cualquier opción que el module HM haya rechazado
  (reporta, no inventes).
