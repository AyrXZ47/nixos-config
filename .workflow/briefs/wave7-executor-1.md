# Brief: Wave 7 · Executor 1

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

**HOTFIX bloqueante**: `hyprdev` y `netrunner` no abren ninguna ventana porque
pasan `kitty --cwd`, y **kitty 0.48 no tiene ese flag** (`Unknown flag: --cwd`
→ kitty sale al instante; el `>/dev/null 2>&1` lo oculta).

1. En `modules/apps/shell.nix` (`netrunner()` ~58–62 y `hyprdev()` ~71–95),
   reemplazar TODOS los `kitty --cwd` por `kitty -d` (o
   `--working-directory`). Verifica que no quede ningún `--cwd`.
2. En `modules/apps/kitty.nix`, corregir el comentario obsoleto que dice que
   `allow_remote_control` "lo usa hyprdev" (H2 de la auditoría): hyprdev ya no
   usa `kitty @`. Deja el flag (no estorba) pero comenta la verdad (control
   remoto disponible para uso manual). No cambies más `settings`.

## Definition of done

- `shell.nix` sin `--cwd`; `hyprdev`/`netrunner` usan `kitty -d`.
- Comentario de `kitty.nix` corregido.
- El verify command pasa. Solo `modules/apps/shell.nix` y
  `modules/apps/kitty.nix` modificados.

## Files you own

- `modules/apps/shell.nix`
- `modules/apps/kitty.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/desktop/**`, `home/**`, `hosts/**`,
  `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- Módulos home-side; no hay activations.

## Read first

- `modules/apps/shell.nix`: `netrunner()` y `hyprdev()`.
- `kitty --help` → `-d, --working-directory, --directory`.
- `.workflow/plan.md` → Wave 7 T1.

## Verify command

```bash
nix flake check --no-build && ! nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.programs.zsh.initContent' | grep -q -- '--cwd' && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.programs.zsh.initContent' | grep -q 'kitty -d' && ! grep -q 'kitty @' modules/apps/kitty.nix
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- Un commit: `fix(kitty): -d en vez del inexistente --cwd en hyprdev/netrunner`.
- Commit ONLY your owned files.
- BRANCH ISOLATION (mandatory): `git push origin wave7-executor-1`. Nunca a
  `main` ni a otra rama.

## Report back

- Diff, salida del verify, y confirmar que `hyprdev` abre 4 ventanas kitty.
