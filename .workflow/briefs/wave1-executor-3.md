# Brief: Wave 1 · Executor 3

> **CORREGIDO 2026-09-20 (F1 de la auditoría)**: la ruta correcta del esquema
> es `schemes/cyberpunk/default/dark.txt` (con subdirectorio de flavour), NO
> `schemes/cyberpunk/dark.txt`, y el verify DEBE ejecutar el CLI
> (`caelestia scheme list | jq -e '.cyberpunk.default'`), no un `ls`. Este brief
> queda como histórico; el fix real vive en
> `.workflow/briefs/wave2-executor-1.md`.

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Añadir el esquema **`cyberpunk`** (paleta de Wayle del humano) a
`caelestia-cli` mediante un overlay en `flake.nix`, siguiendo el patrón del
overlay existente `caelestiaDedupeOverlay` (líneas ~424–440) y registrándolo en
la lista `nixpkgs.overlays` de `mkHost` (línea ~446).

Por qué: `caelestia-cli` solo lista los esquemas que viven dentro de su propio
paquete (`scheme_data_dir = cli_data_dir / "schemes"`, read-only en el store);
no hay carpeta de esquemas de usuario. El overlay escribe el esquema con
`postInstall`.

1. Nuevo overlay `caelestiaCyberpunkSchemeOverlay = final: prev: {
   caelestia-cli = prev.caelestia-cli.overrideAttrs (old: {
   postInstall = (old.postInstall or "") + ''…''; }); };` que cree
   `$out/lib/python*/site-packages/caelestia/data/schemes/cyberpunk/dark.txt`.
   Usa glob para la versión de Python (`scheme_dir=$(echo
   $out/lib/python*/site-packages/caelestia/data/schemes)`), `mkdir -p` y un
   heredoc `<<'SCHEME'`.
2. Registrar `caelestiaCyberpunkSchemeOverlay` en la lista de overlays de
   `mkHost` (junto a `caelestiaDedupeOverlay`).
3. Contenido EXACTO de `dark.txt` (formato `clave valor`, hex sin `#`, mismas
   claves que `catppuccin/mocha/dark.txt`):

```
primary_paletteKeyColor ff0066
secondary_paletteKeyColor 00aaff
tertiary_paletteKeyColor 00ff88
neutral_paletteKeyColor 141428
neutral_variant_paletteKeyColor 1e1e3a
background 0a0a12
onBackground d4d4f0
surface 0a0a12
surfaceDim 0a0a12
surfaceBright 2a2a44
surfaceContainerLowest 0a0a12
surfaceContainerLow 141428
surfaceContainer 141428
surfaceContainerHigh 1e1e3a
surfaceContainerHighest 2a2a44
onSurface d4d4f0
surfaceVariant 1e1e3a
onSurfaceVariant 8888aa
inverseSurface d4d4f0
inverseOnSurface 141428
outline 8888aa
outlineVariant 1e1e3a
shadow 000000
scrim 000000
surfaceTint ff0066
primary ff0066
onPrimary ffffff
primaryContainer 1e1e3a
onPrimaryContainer ffb3c9
inversePrimary ff0066
secondary 00aaff
onSecondary 001a2e
secondaryContainer 0d2b44
onSecondaryContainer b3e0ff
tertiary 00ff88
onTertiary 002e18
tertiaryContainer 0d4430
onTertiaryContainer b3ffd6
error ff0040
onError ffffff
errorContainer 44001a
onErrorContainer ffb3c4
primaryFixed ffb3c9
primaryFixedDim ff0066
onPrimaryFixed 3a0018
onPrimaryFixedVariant 90083a
secondaryFixed b3e0ff
secondaryFixedDim 00aaff
onSecondaryFixed 001a2e
onSecondaryFixedVariant 005a8a
tertiaryFixed b3ffd6
tertiaryFixedDim 00ff88
onTertiaryFixed 002e18
onTertiaryFixedVariant 00663a
term0 0a0a12
term1 ff0040
term2 00ff88
term3 ffcc00
term4 8888aa
term5 ff0066
term6 00aaff
term7 d4d4f0
term8 555577
term9 ff4d80
term10 66ffb0
term11 ffe680
term12 aaaaCC
term13 ff66a0
term14 80ccff
term15 ffffff
rosewater ffd4e0
flamingo ffb3c9
pink ff66a0
mauve ff0066
red ff0040
maroon c40033
peach ffcc00
yellow ffcc00
green 00ff88
teal 00d4d4
sky 00aaff
sapphire 0088dd
blue 00aaff
lavender 8888aa
klink 00aaff
klinkSelection 00aaff
kvisited ff0066
kvisitedSelection ff0066
knegative ff0040
knegativeSelection ff0040
kneutral 8888aa
kneutralSelection 8888aa
kpositive 00ff88
kpositiveSelection 00ff88
text d4d4f0
subtext1 8888aa
subtext0 555577
overlay2 3a3a5c
overlay1 2a2a44
overlay0 1e1e3a
surface2 2a2a44
surface1 1e1e3a
surface0 141428
base 0a0a12
mantle 0a0a12
crust 08080f
success 00ff88
onSuccess 002e18
successContainer 0d4430
onSuccessContainer b3ffd6
```

## Definition of done

- `flake.nix` define `caelestiaCyberpunkSchemeOverlay` y lo registra en
  `mkHost`.
- Se puede evaluar `.#nixosConfigurations.pc.pkgs.caelestia-cli` y el archivo
  `…/data/schemes/cyberpunk/dark.txt` existe con el contenido de arriba.
- El verify command pasa. Solo `flake.nix` modificado.

## Files you own

- `flake.nix`

## Files forbidden

- `flake.lock`, `modules/desktop/caelestia.nix`,
  `modules/desktop/hyprland-home.nix`, `modules/apps/**`, `hosts/**`,
  `home/**`, `.workflow/**` (salvo leer).

## Read first

- `flake.nix` líneas 413–458 (`caelestiaDedupeOverlay` + `mkHost`).
- Esquema base de ejemplo (formato y claves):
  `/nix/store/kr60l8lq4h4wrpqc34g77rfcbhbwcp34-caelestia-cli-1.1.2/lib/python3.14/site-packages/caelestia/data/schemes/catppuccin/mocha/dark.txt`.
- `.workflow/plan.md` → "Hallazgos" (#4) y Wave 1 T3.

## Verify command

```bash
nix flake check --no-build && nix build --no-link --print-out-paths '.#nixosConfigurations.pc.pkgs.caelestia-cli' | xargs -I{} sh -c 'ls {}/lib/python*/site-packages/caelestia/data/schemes/cyberpunk/dark.txt'
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line
  (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, `perf:`,
  `style:`, `build:`, `ci:`, `revert:`, optional `(scope)`). Under ~72 chars.
  No AI attribution, no trailers. En español, estilo del repo.
- One logical change per commit. One commit per task.
- Commit ONLY your owned files.
- BRANCH ISOLATION (mandatory): commit and push ONLY to your own worktree
  branch — `git push origin wave1-executor-3` — after each commit. Never push
  to `main` or another branch; never merge, rebase, or fast-forward anyone
  else's branch.

## Report back

- Diff resumido, salida del verify, y confirmar que `nix flake check` del árbol
  integrado sigue pasando. Nota: para activar el esquema el humano corre una
  vez `caelestia scheme set -n cyberpunk` (tras integrar y reconstruir).
