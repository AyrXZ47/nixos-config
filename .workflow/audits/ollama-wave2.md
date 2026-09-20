# Auditoría · Ola 2 — ollama 0.32.12 binario (pc) + GC por conteo ≤ 3 generaciones

- Fecha: 2026-08-14
- Auditor: sesión fresca (no la del planner)
- Árbol: `main` integrado (HEAD `a063866`), máquina real `nixos-pc`
- Ola a auditar: la 2 del plan (indicada por el humano con su queja de ollama)

---

## 1. Integridad de la integración

- [x] **Cambios de la ola presentes en main.** Commits de la ola 2: `232d9ca`
  (ollama-bin.nix + amd-desktop.nix), `2d97db5` + `e40d842` (nix-optimization.nix),
  `8152b05` (README). Todos en `main`.
- [x] **`git status` limpio, sin stashes.**
  ```
  On branch main
  Your branch is ahead of 'origin/main' by 1 commit.
  nothing to commit, working tree clean
  git stash list → (vacío)
  ```
- [~] **Merge de worktrees.** NO hay merge commits de la ola 2 ni refs
  `wave2-*` (local o remoto; solo queda `wave1-executor1`). La ola se integró
  por commits directos a `main` (historial lineal). El aislamiento de ramas
  de executor no es verificable a posteriori. **Hallazgo P1.**
- [x] **Diff vs plan (mapa de propiedad).** Los archivos owned de la ola 2:
  `modules/apps/ollama-bin.nix` (nuevo) ✓, `modules/hardware/amd-desktop.nix` ✓,
  `modules/core/nix-optimization.nix` ✓. `modules/hardware/amd-laptop.nix` y
  `modules/apps/common-packages.nix` intactos (verificado: no aparecen en
  `git diff 232d9ca^..HEAD --stat`). Fuera del mapa:
  - `README.md` (commits `e40d842`, `8152b05`): docs de la corrección GC.
    Contenido correcto y coherente, pero README es propiedad de la ola 3
    según el mapa. **Hallazgo P2** (menor, contenido verificado correcto).
  - `hosts/pc/configuration.nix` (commit `44badb3`, MTU 1400): fix directo
    del humano fuera de la ola, no está en el plan. **Hallazgo P2.**
  - `flake.lock` (`de9c36c` bump + `33265c8` revert): neto cero, quedó en
    `f13ff45afd1bb73e640eaa08a7066dbed07e3238` (la «buena» del decision log).
    El plan decía «nadie toca flake.lock»; el revert lo devuelve. **Hallazgo P2**
    (documentado en decision log, aceptable).
- [x] **`main` adelantado 1 commit vs origin** (`a063866` sin pushear). El
  integrador debía pushear `main`. **Hallazgo P3** (handoff).

## 2. Build y tests (árbol integrado)

- [x] `nix flake check` → `all checks passed!` (exit 0)
  ```
  evaluating flake...
  checking flake output 'nixosConfigurations'...
  checking NixOS configuration 'nixosConfigurations.pc'...
  checking NixOS configuration 'nixosConfigurations.laptop'...
  checking NixOS configuration 'nixosConfigurations.server'...
  checking NixOS configuration 'nixosConfigurations.vm'...
  all checks passed!
  ```
- [x] Verify brief executor-1 (árbol integrado):
  ```
  nix build .#nixosConfigurations.pc.config.services.ollama.package --no-link → exit 0
  nix eval --raw .#nixosConfigurations.pc.config.services.ollama.package.version → 0.32.12
  ```
- [x] Verify audit gate ollama: `nix eval` del version → `0.32.12` ✓
- [x] GC por conteo: el `trim-generations` DIARIO hace el conteo
  (`nix-env --delete-generations +3` + `nix-collect-garbage`), y `nix.gc`
  queda sin options (GC puro) — exactamente la CORRECCIÓN del decision log
  (2026-08-14, `nix-collect-garbage` no acepta `--delete-generations`).
  ```
  nix eval --raw .#nixosConfigurations.pc.config.nix.gc.options → (vacío) ✓
  nix eval --raw .#nixosConfigurations.pc.config.systemd.services.trim-generations.script
  → .../nix-env -p /nix/var/nix/profiles/system --delete-generations +3
  → .../nix-collect-garbage
  systemd.services.trim-generations.serviceConfig.Type → oneshot
  systemd.timers.trim-generations.timerConfig.OnCalendar → daily
  ```
  Runtime real en `nixos-pc`:
  ```
  ● trim-generations.timer — active (waiting), Trigger: Sat 2026-08-15 00:00:00
  ● trim-generations.service — status=0/SUCCESS, 133 store paths deleted, 5.7 GiB freed
  ```
- [~] El verify literal del brief executor-2 (`nix.gc.options` → `--delete-generations +3`)
  NO pasa (devuelve vacío) — el brief quedó obsoleto frente a la corrección del
  decision log; la implementación sigue el decision log (fuente de verdad más
  reciente, con evidencia propia). **Hallazgo P4**: el audit gate del plan.md
  y el verify del brief no se actualizaron tras la corrección.
- [~] `nix-env -p /nix/var/nix/profiles/system --list-generations` no ejecutable
  por el auditor (requiere root; `sudo` pide password). Evidencia indirecta:
  trim-generations corrió OK con `nix-env --delete-generations +3` (ver arriba).
  Verificación final queda para el humano tras el próximo rebuild (regla del plan).

## 3. Disciplina ponytail

- [x] `ollama-bin.nix`: 50 líneas, fetch + copy (sin build), `zstd` en
  nativeBuildInputs para `tar --zstd`, comentarios en español, hash rocm =
  `cc8e1c1f...` (coincide con el plan). Mínimo y sin abstracciones.
- [x] `amd-desktop.nix`: diff de 4 líneas (import + quitar `services.ollama.package`).
- [x] `nix-optimization.nix`: comentarios actualizados a la lógica por conteo;
  conserva `nix.optimise.automatic`, journald 100M, autoUpgrade, substituters,
  schedulers idle (intactos). Duplicación menor: dos servicios diarios corren
  GC (`nix-gc` puro + `trim-generations`) — justificado por el decision log.
- [x] Sin dependencias nuevas no pedidas; nada fuera de los briefs.

## 4. Seguridad

- [x] Scan de secretos en el diff de la ola y en el repo: el único match de
  `ghp_|AKIA|PRIVATE KEY` es el **guard anti-fuga** de `modules/apps/git.nix`
  (regex de bloqueo, no un secreto). Sin secretos commiteados.
- [x] Trust boundaries: config declarativa, sin inputs externos nuevos.
- [x] Release gate: no aplica (config personal, no se distribuye); auditoría
  ligera OK según plan.

## 5. Runtime — queja del humano (ollama lento / sistema se traba)

Evidencia recogida en `nixos-pc` (journal + estado del sistema):

- [x] `ollama --version` → `0.32.12` ✓ (paquete de la ola 2 corriendo).
- [x] ROCm detectado: `inference compute ... library=ROCm compute=gfx1102
  name=ROCm0 "AMD Radeon RX 7600" total=8.0 GiB` ✓.
- [x] `OLLAMA_GPU_OVERHEAD=1GiB` (el «giga») **SÍ se respeta** en el cálculo:
  `gpu memory ... available="6.5 GiB" free="7.9 GiB" minimum="457.0 MiB"
  overhead="1.0 GiB"`.
- [x] **CAUSA RAIZ del freeze**: el modelo `qwen3.8:27b-mtp-q4_K_M` (26 GB)
  corre con **contexto 131072** (el Modelfile define `num_ctx` propio y
  sobreescribe `OLLAMA_CONTEXT_LENGTH=16384`; el env var solo aplica si el
  modelo no define num_ctx). Solo **10/66 capas** caben en la VRAM de 8 GiB
  (`load_tensors: offloaded 10/66 layers to GPU`) → **83%/17% CPU/GPU** →
  generación a **0.22–0.24 t/s** (prompt processing 7–10 t/s) y `llama-server`
  a **154% CPU + 22.8 GB RSS** → el escritorio se traba.
- [x] El error `journalctl ollama → Failed to add match 'ollama': Invalid
  argument` es **sintaxis**: journalctl 261 exige `journalctl -u ollama`
  (verificado: funciona y muestra los logs del servicio).
- [x] `free -h`: 62 GiB RAM, 24 GiB usados, swap zram 0 B usada — no hay OOM;
  la saturación es CPU + RAM del runner. `journalctl -b -p err` sin errores
  graves de kernel/servicios (solo warnings de dbus duplicados y amdgpu overdrive).

Conclusión runtime: la ola 2 entregó lo que prometía (binario 0.32.12 ROCm
funcionando, GPU detectada, offload activo). El rendimiento inaceptable es de
**calibración modelo/contexto** — exactamente lo que el plan tiene previsto
como **ola 4** («pull qwen3.8 y calibración tps»), que ahora queda con
prioridad alta.

---

## Hallazgos

| ID | Severidad | Descripción | Evidencia |
|----|-----------|-------------|-----------|
| P1 | Menor (proceso) | Ola 2 sin merge commits ni ramas `wave2-*`; integración por commits directos a main; aislamiento de executor no verificable | `git log --graph --oneline --all` (línea recta, sin merges de ola 2); `git branch -a` |
| P2 | Menor | `README.md`, `hosts/pc/configuration.nix` y `flake.lock` (neto cero) tocados fuera del mapa de propiedad de la ola 2 | `git diff 232d9ca^..HEAD --stat` |
| P3 | Menor | `main` 1 commit adelante de `origin/main` (`a063866` sin pushear) | `git status -sb` |
| P4 | Menor | Audit gate del plan y verify del brief executor-2 desactualizados vs decisión de corrección del GC (nix.gc sin options + trim-generations con nix-env) | `nix eval ... nix.gc.options` vacío vs gate del plan; decision log 2026-08-14 |
| R1 | Alta (runtime, no bloquea la ola) | Modelo 27B con num_ctx 131072 no cabe en 8 GiB VRAM → 0.23 t/s, 154% CPU, 22.8 GB RAM → sistema se traba. `OLLAMA_CONTEXT_LENGTH` no aplica a modelos con num_ctx propio | `ollama ps` (83%/17% CPU/GPU, CONTEXT 131072); journal `offloaded 10/66 layers`; `print_timing tg=0.23 t/s`; `ps aux` (154% CPU, 22.8 GB RSS) |

## Veredicto

**APPROVED WITH EXCEPTIONS**

La ola 2 cumple su definición de hecho: `nix flake check` pasa, ollama 0.32.12
corriendo con ROCm en pc, y el GC por conteo ≤ 3 generaciones implementado y
verificado en runtime (trim-generations diario, corrió OK). Las excepciones
P1–P4 son de proceso, no de funcionalidad, y no bloquean la ola 3.

La excepción de fondo es **R1**: la queja del humano es real y la causa raíz
está identificada con evidencia — no es un fallo de la ola 2, es calibración
(modelo 27B + num_ctx 131072 en 8 GiB VRAM). Debe tratarse en la ola 4, que
pasa a prioridad alta: forzar num_ctx (por request/Modelfile, no por env var)
y/o elegir un modelo que quepa en la GPU; medir tps tras el ajuste.

## Handoff pendiente (quién y qué)

- **Integrador/planner**: pushear `main` (P3); actualizar el audit gate del
  plan y el verify del brief executor-2 a la lógica corregida (P4);
  registrar en el decision log el aprendizaje de R1 (num_ctx del modelo
  sobreescribe OLLAMA_CONTEXT_LENGTH).
- **Planner**: re-planear la **ola 4 con prioridad alta** (calibración tps,
  forzar num_ctx o modelo más pequeño); la ola 3 (docs Shotcut) puede arrancar.
- **Humano**: `journalctl -u ollama` (no `journalctl ollama`); para reducir el
  freeze ya mismo: `ollama run --num-ctx 16384 qwen3.8:27b-mtp-q4_K_M` o un
  modelo ≤ 8B; verificar generaciones con `sudo nix-env ... --list-generations`
  tras el próximo rebuild.
