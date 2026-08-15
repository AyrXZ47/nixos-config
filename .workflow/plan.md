# Plan rodante: ola 2 ollama + GC (done) · ola 3 editor de vídeo (detallada)

> Single source of truth for the work. Committed, survives any session.
> ONLY the next wave is detailed (rolling plan). When a session dies, a new
> instance resumes from this file — never from memory.

## Goal

En `pc` y `laptop` corre ollama **0.32.12** (binario oficial, ROCm en pc /
Vulkan en laptop) para poder hacer `ollama pull qwen3.8:27b-mtp-q4_K_M`, y el
GC de Nix deja **máximo 3 generaciones** del perfil de sistema siempre (por
conteo, no por edad). Se considera hecho cuando `nixos-rebuild switch --flake .#pc`
aplica sin errores, `ollama --version` reporta 0.32.12 y el pull del modelo
funciona, y tras un rebuild `nix-env -p /nix/var/nix/profiles/system
--list-generations` muestra ≤ 3 generaciones.

Segundo proyecto (ola 3): decidir con evidencia y dejar documentado el editor de
vídeo de la pc (RX 7600). Se considera hecho cuando el README tiene una sección
«Edición de vídeo» con la decisión (**Shotcut**) y la verificación VA-API real
(H.264/HEVC/AV1 decode+encode por hardware), y `nix flake check` pasa. Nada se
instala de nuevo (YAGNI: shotcut ya está en `common-packages.nix`).

## Stack & constraints

- NixOS flake (`nixos-unstable` pinneado en `flake.lock`, revisión
  `f13ff45` del 2026-08-07 — la buena; la del 08-13 tiene nanoemoji roto).
- 4 hosts (`pc`, `laptop`, `server`, `vm`), Home Manager usuario `yovick`.
- `services.ollama.enable = true` en `modules/apps/common-packages.nix`
  (con `OLLAMA_CONTEXT_LENGTH=16384` y `OLLAMA_GPU_OVERHEAD=1GiB`).
  El paquete se elige por host: `amd-desktop.nix` → `ollama-rocm`,
  `amd-laptop.nix` → `ollama-vulkan`.
- `nix flake check` es la única verificación del repo.
- Solo PC en esta ola para ollama: qwen3.8 27B necesita ≥ 0.32.12 (release de
  hoy, 2026-08-14) y nixpkgs-unstable va con días de retraso (0.32.7). El
  binario oficial es la vía (override, sin compilar desde fuente).
- Laptop se deja como está en esta ola (ollama-vulkan nixpkgs sigue
  funcionando; el pull de qwen3.8 en laptop es secundario).
- Hash del tarball rocm v0.32.12: `cc8e1c1f4d9db9a299e38b2e238eb55be419dbc06223ea5d759bc480ddb48b85`
  (del asset oficial de GitHub). El executor DEBE verificarlo con
  `nix-prefetch-url` antes de confiar en él.

## Waves

| Wave | Focus | Status |
|------|-------|--------|
| 1 | <ya integrada — historial previo> | done |
| 2 | ollama 0.32.12 binario (pc) + límite duro 3 generaciones | audited (excepciones P1–P4) |
| 3 | Editor de vídeo: decisión documentada + verificación VA-API (Shotcut) | in-flight |
| 4 | pull qwen3.8 y calibración tps en pc — **prioridad alta (R1 auditoría ola 2)** | planned |

> Status legend: planned → in-flight → integrated → audited → done.
> Update after each step, by whoever ran the step.

---

## Wave 2 (current)

### File ownership map

Dos ejecutores, archivos disjuntos. Nadie toca `flake.lock` ni
`modules/apps/common-packages.nix`.

| File/glob | Owner |
|-----------|-------|
| `modules/apps/ollama-bin.nix` (nuevo) + `modules/hardware/amd-desktop.nix` | executor-1 |
| `modules/core/nix-optimization.nix` | executor-2 |

### Tasks

- [x] T1: override de ollama a 0.32.12 binario oficial (rocm) en pc →
      brief: `.workflow/briefs/wave2-executor-1.md`
- [x] T2: GC de Nix por conteo: máximo 3 generaciones siempre →
      brief: `.workflow/briefs/wave2-executor-2.md`

### Integration plan

- Orden de merge: **executor-2 primero** (GC, cero riesgo, no toca ollama),
  luego executor-1 (ollama). Ambos sobre `main`.
- Comandos en el árbol integrado:
  ```bash
  nix flake check
  nix build .#nixosConfigurations.pc.config.services.ollama.package --no-link
  ```
- El humano corre `sudo nixos-rebuild switch --flake .#pc` DESPUÉS del commit
  (regla AGENTS.md), luego `ollama --version` debe dar 0.32.12 y
  `ollama pull qwen3.8:27b-mtp-q4_K_M` debe funcionar.
- Tras el rebuild: `nix-env -p /nix/var/nix/profiles/system --list-generations`
  → ≤ 3. Nota: el GC diario corre a las 00:00; si se quiere forzar:
  `sudo systemctl start nix-gc.service` + `nix-collect-garbage -d`.

### Audit gate

- Auditor corre en el árbol integrado (tras merge):
  - `nix flake check` pasa.
  - `nix eval .#nixosConfigurations.pc.config.services.ollama.package.version`
    → `"0.32.12"`.
  - GC: `nix.gc` queda SIN options (GC puro) y el conteo vive en el servicio
    diario `trim-generations` (`nix-env --delete-generations +3` +
    `nix-collect-garbage`) — ver CORRECCIÓN del decision log y auditoría ola 2.
  - Ningún archivo fuera de los owned files fue modificado
    (`git diff main..HEAD --stat` vs mapa de propiedad).
  - Sin findings CRITICAL/HIGH en `skills/security-audit` si aplica
    (release gate: esto no se distribuye; auditoría ligera basta).

---

## Wave 3 (next) — editor de vídeo: decisión + verificación

> Gate: ola 2 auditada (APPROVED WITH EXCEPTIONS P1–P4, no bloquean — ver
> `.workflow/audits/wave2.md`) y decisión humana confirmada el 2026-08-14:
> **Shotcut**. Ambas condiciones cumplidas → ola en curso. El branch B (Resolve)
> queda cancelado/archivado salvo que el humano lo pida explícitamente.

### Scope — evidencia recogida el 2026-08-14 en la máquina real (`nixos-pc`, RX 7600)

- **Shotcut ya está instalado** (`modules/apps/common-packages.nix`) y su vía GPU
  funciona: `vainfo` → VA-API 1.24, radeonsi 26.2.0 (Navi 33), perfiles
  H.264/HEVC(Main+Main10)/VP9/AV1 con `VAEntrypointVLD` + `VAEntrypointEncSlice`
  → decode Y encode por hardware. Es el ÚNICO NLE libre que usa la GPU de AMD
  para H.264 en Linux (motor FFmpeg/MLT).
- **DaVinci Resolve 21.0.4 (free) SÍ está en el nixpkgs pinneado** (rev
  `0e251e24`): `broken=false`, unfree (ya permitido globalmente en
  `modules/core/user.nix`), empaquetado (AppImage oficial + FHS env con ocl-icd).
  **NO resuelve los dolores del humano**: H.264/H.265 en la versión free se
  procesan por CPU (hardware encode/decode = feature de Studio y en Linux
  NVIDIA-only), así que el flujo ProRes→mov→cientos de GB seguiría siendo
  necesario. El «no soporta mi GPU» = OpenCL sin ICD: `clinfo` → 0 platforms en
  este sistema AHORA. Arreglar OpenCL (rusticl) es posible, pero no arregla los
  codecs — no existe «parche» para eso (es licencia de Blackmagic).
- **Filmora: descartado** — oficialmente solo Windows/macOS/móvil (descargas
  `.exe`/`.dmg`), no hay build Linux.
- **kdenlive** existe (`kdePackages.kdenlive` 26.04.3; el attr `kdenlive` a secas
  ya no existe) pero el humano lo descartó. Blender VSE: sin LUTs reales y export
  por CPU (descartado por el humano). Olive está muerto; OpenShot/Pitivi/
  Flowblade no son profesionales.
- Decisión: **seguir con Shotcut**. Los cierres que sufrió el humano eran en
  Fedora (otro build/drivers); en NixOS el stack es el de nixpkgs y VA-API está
  vivo. Bonus: exportar a AV1 por hardware (RX 7600 lo soporta) → archivos mucho
  más pequeños que H.264 a calidad similar.

### File ownership map

| File/glob | Owner |
|-----------|-------|
| `README.md` (solo la nueva subsección «Edición de vídeo» bajo `## Software`) | executor-1 |

Ola de docs: un solo ejecutor, un solo archivo. Nadie más toca `README.md` y el
executor no toca NADA más.

### Tasks

- [ ] T1: sección README «Edición de vídeo»: decisión (Shotcut), evidencia
      (VA-API verificado + salida real del smoke test), por qué NO Resolve free /
      Filmora / kdenlive / Blender VSE, tip AV1, y qué hacer si Shotcut crashea
      en NixOS (desactivar hw decode en ajustes y reportar → ola futura). →
      brief: `.workflow/briefs/wave3-executor-1.md`

### Branch B (solo si el humano elige Resolve)

Activar solo tras la decisión; el planner escribe los briefs en ese momento.
Dos ejecutores, propietarios disjuntos:

| File/glob | Owner |
|-----------|-------|
| `modules/apps/davinci-resolve.nix` (nuevo: paquete solo en pc) | executor-1 |
| `modules/hardware/amd-desktop.nix` (`hardware.graphics.extraPackages = [ pkgs.mesa.opencl ]` → rusticl) | executor-2 |

Advertencia explícita que debe quedar escrita: H.264 seguirá en CPU; el OpenCL
arregla color/efectos de Resolve, NO los codecs.

### Integration plan

- Orden de merge: executor-1 sobre `main` (único).
- Comandos en el árbol integrado:
  ```bash
  nix flake check
  ```
- La decisión ya quedó confirmada ANTES de la ola (gate); el README la registra.

### Audit gate

- Auditor corre en el árbol integrado:
  - `nix flake check` pasa.
  - `git diff main..HEAD --stat` = solo `README.md`.
  - La sección «Edición de vídeo» existe, en español, y cita evidencia
    verificable (vainfo / smoke test con su salida real) — sin claims
    inventados.
  - Decision log actualizado.

---

## Decision log

| Date | Decision | Why |
|------|----------|-----|
| 2026-08-14 | Revertir `flake.lock` a `f13ff45` (2026-08-07) y NO usar la revisión del 08-13 | La del 08-13 tiene hash mismatch de nanoemoji (PyPI re-subió el tarball) que bloquea todo el build; la anterior compila y ya está cacheada |
| 2026-08-14 | Ollama vía binario oficial (tarball release) en vez de override de la derivación nixpkgs | nixpkgs-unstable solo tiene 0.32.7; compilar desde fuente con overrideAttrs implica re-pinear vendorHash + llama.cpp pin (frágil). El tarball oficial es 1 línea de fetchurl + copy |
| 2026-08-14 | GC por conteo `--delete-generations +3` reemplaza al `--delete-older-than 3d` | Por edad conservaba 16 generaciones con rebuilds frecuentes; por conteo garantiza ≤ 3 siempre |
| 2026-08-14 | CORRECCIÓN: `nix-collect-garbage` NO acepta `--delete-generations` (error `unrecognised flag`); el conteo va en un servicio `trim-generations` DIARIO con `nix-env --delete-generations +3` + GC, y `nix.gc` queda sin options (GC puro) | Verificado con `nix-collect-garbage --help` y dry-run en la máquina real |
| 2026-08-14 | Editor de vídeo: SE SIGUE CON SHOTCUT (recomendado; pendiente confirmación humana) | VA-API verificado en la RX 7600 real (`vainfo`: H.264/HEVC/VP9/AV1 VLD+EncSlice con radeonsi 26.2). Resolve free 21.0.4 existe en nixpkgs (`0e251e24`, `broken=false`) PERO H.264/H.265 quedan en CPU (hw accel = Studio, NVIDIA-only en Linux) → no resuelve los dolores del humano. Filmora no tiene build Linux (solo .exe/.dmg). kdenlive existe (`kdePackages.kdenlive` 26.04.3) pero el humano lo descartó |
| 2026-08-14 | OpenCL está inoperativo en pc AHORA mismo: `clinfo` → 0 platforms (loader ocl-icd sí, ICD de proveedor no) | Explica el «no soporta mi GPU» previo del humano con Resolve. Vía corta si se activa branch B: `hardware.graphics.extraPackages = [ pkgs.mesa.opencl ]` (rusticl, mesa 26.2 lo compila). No se instala nada hasta que el humano decida (YAGNI) |
| 2026-08-14 | La evaluación de paquetes de esta ola se hizo contra el lock ACTUAL (`0e251e24`, 2026-08-12, la «buena» tras el revert `33265c8`) | Si el lock cambia antes de activar branch B, re-evaluar davinci-resolve/mesa antes de escribir los briefs |
| 2026-08-14 | Humano confirmó la decisión de editor de vídeo: **SHOTCUT** (ola 3 arranca; branch B Resolve archivado salvo petición explícita) | Tras leer la evidencia (VA-API verificado, Resolve free = H.264 por CPU, Filmora sin Linux) |
| 2026-08-14 | Aprendizaje R1 (auditoría ola 2): `OLLAMA_CONTEXT_LENGTH=16384` NO aplica a modelos que definen `num_ctx` propio (qwen3.8:27b lo fija a 131072) → 10/66 capas en 8 GiB VRAM, 0.23 t/s, 154% CPU, 22.8 GB RSS, escritorio se traba | Ola 4 pasa a prioridad alta: forzar `num_ctx` por request/Modelfile (no por env var) y/o modelo ≤ 8B; medir tps tras el ajuste |
| 2026-08-14 | P4 (auditoría ola 2): audit gate del plan y verify del brief executor-2 corregidos a la lógica real (nix.gc sin options + trim-generations diario) | El verify literal del brief quedó obsoleto frente a la CORRECCIÓN del GC; la implementación seguía el decision log (fuente más reciente) |
