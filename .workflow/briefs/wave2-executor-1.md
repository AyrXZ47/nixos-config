# Brief: Wave 2 · Executor 1

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Crear el módulo `modules/apps/ollama-bin.nix` que instala **ollama 0.32.12**
desde el binario oficial de la release de GitHub (tarball ROCm para la RX
7600) y fijarlo como `services.ollama.package` en el host `pc`. El objetivo
es poder hacer `ollama pull qwen3.8:27b-mtp-q4_K_M` (requiere ≥ 0.32.12;
nixpkgs-unstable solo tiene 0.32.7).

El módulo nuevo importa la derivación (fetchurl del tarball + copy de
`bin/` y `lib/`), y `modules/hardware/amd-desktop.nix` se edita para
importar ese módulo y **eliminar** su línea `services.ollama.package =
pkgs.ollama-rocm;` (el paquete pasa a decidirlo ollama-bin.nix). Laptop
NO cambia en esta ola: sigue con `pkgs.ollama-vulkan`.

El tarball oficial extrae `bin/ollama` y `lib/ollama/` en la raíz; copiarlos
a `$out/` preserva la ruta relativa `../lib/ollama` que el binario usa para
encontrar los runners. Necesitas `pkgs.zstd` en `nativeBuildInputs` para que
`tar --zstd` funcione en el sandbox.

Ponytail: es un fetch + copy, no una compilación. Si la derivación intenta
hacer build, está mal.

## Definition of done

- `modules/apps/ollama-bin.nix` existe con la derivación ollama 0.32.12
  (tarball `ollama-linux-amd64-rocm.tar.zst`).
- `modules/hardware/amd-desktop.nix` importa ollama-bin.nix y ya no define
  `services.ollama.package`.
- `modules/hardware/amd-laptop.nix` y `modules/apps/common-packages.nix`
  intactos.
- Hash del tarball VERIFICADO con `nix-prefetch-url <url>` antes de fijarlo
  en el `sha256` (el valor del plan es orientativo, del API de GitHub).
- La verificación de abajo pasa.

## Files you own

- `modules/apps/ollama-bin.nix` (nuevo)
- `modules/hardware/amd-desktop.nix`

## Files forbidden

- `modules/hardware/amd-laptop.nix` (sigue en ollama-vulkan — fuera de ola)
- `modules/apps/common-packages.nix` (enable + env vars de ollama: no tocar)
- `flake.lock`, `flake.nix`, `.workflow/**`
- Cualquier otro archivo del repo

## Read first

- `modules/hardware/amd-desktop.nix` (la línea a eliminar y el patrón de
  imports del host)
- `modules/hardware/amd-laptop.nix` (referencia: patrón que NO debes tocar)
- `modules/apps/common-packages.nix` líneas 48-61 (enable, context length,
  GPU overhead — contexto de cómo se sirve ollama)
- `.workflow/plan.md` (decisión log: por qué tarball oficial y no override
  de la derivación nixpkgs)

## Verify command

```bash
nix flake check && nix build .#nixosConfigurations.pc.config.services.ollama.package --no-link && nix eval --raw .#nixosConfigurations.pc.config.services.ollama.package.version
```

Debe terminar sin errores y el último comando imprime `0.32.12`. Si el build
falla por el hash del fetchurl, corregir con el hash real de
`nix-prefetch-url` y reintentar.

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line
  (`feat:`/`fix:`/`chore:`/`docs:`). Under ~72 chars. No AI attribution, no
  trailers. En español, estilo del repo.
- One logical change per commit. One commit per task.
- Commit ONLY your owned files.
- BRANCH ISOLATION (mandatory): worktree branch `wave2-executor-1`; commit
  and push ONLY to it (`git push origin wave2-executor-1`). Never push to
  `main` or another branch. No `git checkout`/`switch`/`branch`/`worktree`
  ajenos.

## Report back

- Archivos cambiados, salida del verify, hash real del tarball usado,
  desviaciones (si el layout del tarball resultó distinto), dudas abiertas.
