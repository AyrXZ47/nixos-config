# Brief: Wave 7 · Executor 2

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

`modules/apps/kitty.nix` y `modules/desktop/hyprland-home.nix`:

1. **Emoji en kitty**: fontconfig resuelve 🔒 (`U+1F512`) a *Noto Sans Symbols 2*
   (monocromo) antes que a *Noto Color Emoji*, instalado en el sistema. Añade a
   `programs.kitty.settings` los `symbol_map` de los rangos emoji apuntando a
   `Noto Color Emoji`, p.ej.:
   ```
   symbol_map = "U+1F300-U+1FAFF,U+2600-U+27BF,U+2190-U+21FF Noto Color Emoji";
   ```
   (si el nombre exacto de la familia es otro, `fc-list | grep -i "color emoji"`).
   Verifica con `kitty +kitten show_key` o simplemente abriendo `sudo` y viendo
   el candadito.
2. **Comentario obsoleto (H2)**: en `kitty.nix`, donde se justifica
   `allow_remote_control` diciendo que "lo usa hyprdev", corrige el texto:
   hyprdev ya NO usa `kitty @`. Deja el flag (es útil para uso manual) pero
   comenta la verdad.
3. **Bind `SUPER + N`**: en `hyprland-home.nix`, netrunner ahora necesita una
   terminal que lo invoque (reutiliza la invocadora como btop). Cambia el bind a
   `hl.bind("SUPER + N", hl.dsp.exec_cmd("kitty zsh -ic netrunner"))`.

## Definition of done

- `symbol_map` con `Noto Color Emoji` en `settings`.
- Comentario de `kitty.nix` correcto (sin "lo usa hyprdev").
- Bind `SUPER+N` lanza `kitty ... zsh -ic netrunner`.
- El verify command pasa. Solo esos 2 archivos modificados.

## Files you own

- `modules/apps/kitty.nix`
- `modules/desktop/hyprland-home.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/apps/shell.nix`, `modules/desktop/caelestia.nix`,
  `home/**`, `hosts/**`, `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- Módulos home-side; no hay activations.

## Read first

- `modules/apps/kitty.nix` (ola 6).
- `modules/desktop/hyprland-home.nix`: bind `SUPER + N`.
- `.workflow/plan.md` → Wave 7 T2.

## Verify command

```bash
nix flake check --no-build \
  && nix eval --json '.#nixosConfigurations.pc.config.home-manager.users.yovick.programs.kitty.settings' | jq -e '.symbol_map | test("Noto Color Emoji")' \
  && ! grep -q 'lo usa hyprdev' modules/apps/kitty.nix \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.wayland.windowManager.hyprland.extraConfig' | grep -q 'zsh -ic netrunner'
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- Un commit por cambio.
- Commit ONLY your owned files.
- BRANCH ISOLATION (mandatory): `git push origin wave7-executor-2`. Nunca a
  `main` ni a otra rama.

## Report back

- Diff, salida del verify, y si el `symbol_map` bastó para el candadito.
