# Brief: Wave 6 · Executor 5

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Kitty como el wezterm del humano: el tema `kitty-cyberpunk` y keybindings de
navegación/splits.

1. **Vendorizar el tema**: descarga
   `https://raw.githubusercontent.com/johndrews/kitty-cyberpunk/main/cyberpunk.conf`
   y guárdalo en el repo como `assets/kitty-cyberpunk.conf` (es MIT y ya trae
   cabecera con autor/origen; consérvala). NO lo traigas por `fetchurl` en
   runtime: se versiona como asset (mismo patrón que `assets/`).
2. **`modules/apps/kitty.nix`**:
   - Aplica el tema incluyéndolo al final de la config:
     `programs.kitty.extraConfig = "include ${../../assets/kitty-cyberpunk.conf}";`
     (o `xdg.configFile."kitty/cyberpunk.conf".source = ../../assets/kitty-cyberpunk.conf`
     + `include` con ruta absoluta, si `extraConfig` no acepta el path relativo
     — usa lo que evalúe).
   - Quita de `settings` los colores (`background`, `foreground`, `color0..15`,
     `cursor`, `cursor_text_color`, `selection_*`) que ahora pone el tema; deja
     `background_opacity`, `dynamic_background_opacity`, `cursor_trail*`,
     `window_padding_width`, `confirm_os_window_close`, `enable_audio_bell`,
     `allow_remote_control`, `shell_integration`.
   - `settings.enabled_layouts = "splits";`
   - `keybindings`:
     - `"ctrl+page_up" = "previous_window";`
     - `"ctrl+page_down" = "next_window";`
     - `"ctrl+shift+alt+percent" = "launch --location=vsplit --cwd=current";`
     - `"ctrl+shift+alt+quotedbl" = "launch --location=hsplit --cwd=current";`
     (`percent`/`quotedbl` son nombres de keysym XKB válidos; kitty los resuelve
     por `xkb_keysym_from_name`.)
   - Añade un comentario breve en español explicando que el tema es de
     johndrews/kitty-cyberpunk (MIT) y por qué se vendoriza.

## Definition of done

- `assets/kitty-cyberpunk.conf` existe con el contenido upstream.
- El theme se incluye y los colores ya no están duplicados en `settings`.
- Los 4 keybindings y `enabled_layouts` están puestos.
- El verify command pasa. Solo `modules/apps/kitty.nix` y
  `assets/kitty-cyberpunk.conf` (nuevo) modificados.

## Files you own

- `modules/apps/kitty.nix`
- `assets/kitty-cyberpunk.conf` (nuevo)

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/apps/shell.nix`, `modules/desktop/**`,
  `home/**`, `hosts/**`, `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- Módulo home-side; no hay activations.

## Read first

- `modules/apps/kitty.nix` (lo que dejó la ola 5).
- El repo upstream `johndrews/kitty-cyberpunk` (`cyberpunk.conf`).
- `.workflow/plan.md` → Wave 6 T5.

## Verify command

```bash
nix flake check --no-build && nix eval --json '.#nixosConfigurations.pc.config.home-manager.users.yovick.programs.kitty.keybindings' | jq -e '.["ctrl+page_up"] and .["ctrl+shift+alt+percent"]' && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.programs.kitty.settings.enabled_layouts' | grep -q splits
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- One commit: `feat(kitty): tema cyberpunk de johndrews y keybinds wezterm-like`.
- Commit ONLY your owned files.
- BRANCH ISOLATION (mandatory): `git push origin wave6-executor-5`. Nunca a
  `main` ni a otra rama.

## Report back

- Diff, salida del verify, y la ruta exacta del `include` del tema.
