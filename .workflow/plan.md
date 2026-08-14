# Plan: ollama 0.32.12 (qwen3.8) + límite duro de 3 generaciones

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
| 2 | ollama 0.32.12 binario (pc) + límite duro 3 generaciones | in-flight |
| 3 | pull qwen3.8 y calibración tps en pc (tras aprobación humana) | planned |

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

- [ ] T1: override de ollama a 0.32.12 binario oficial (rocm) en pc →
      brief: `.workflow/briefs/wave2-executor-1.md`
- [ ] T2: GC de Nix por conteo: máximo 3 generaciones siempre →
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
  - `nix eval .#nixosConfigurations.pc.config.nix.gc.options` → contiene
    `--delete-generations` (conteo), no `--delete-older-than`.
  - Ningún archivo fuera de los owned files fue modificado
    (`git diff main..HEAD --stat` vs mapa de propiedad).
  - Sin findings CRITICAL/HIGH en `skills/security-audit` si aplica
    (release gate: esto no se distribuye; auditoría ligera basta).

---

## Decision log

| Date | Decision | Why |
|------|----------|-----|
| 2026-08-14 | Revertir `flake.lock` a `f13ff45` (2026-08-07) y NO usar la revisión del 08-13 | La del 08-13 tiene hash mismatch de nanoemoji (PyPI re-subió el tarball) que bloquea todo el build; la anterior compila y ya está cacheada |
| 2026-08-14 | Ollama vía binario oficial (tarball release) en vez de override de la derivación nixpkgs | nixpkgs-unstable solo tiene 0.32.7; compilar desde fuente con overrideAttrs implica re-pinear vendorHash + llama.cpp pin (frágil). El tarball oficial es 1 línea de fetchurl + copy |
| 2026-08-14 | GC por conteo `--delete-generations +3` reemplaza al `--delete-older-than 3d` | Por edad conservaba 16 generaciones con rebuilds frecuentes; por conteo garantiza ≤ 3 siempre |
| 2026-08-14 | CORRECCIÓN: `nix-collect-garbage` NO acepta `--delete-generations` (error `unrecognised flag`); el conteo va en un servicio `trim-generations` DIARIO con `nix-env --delete-generations +3` + GC, y `nix.gc` queda sin options (GC puro) | Verificado con `nix-collect-garbage --help` y dry-run en la máquina real |
