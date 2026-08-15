# Plan rodante: olas 2–3 done · ola 4 resuelta directo (sin ola formal)

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

Tercer proyecto (ola 4): resolver la queja «los modelos locales en Obsidian
Copilot tardan una eternidad y traban la PC». Diagnóstico cerrado (ver ola 2,
R1): el fix es de configuración del PLUGIN, no del repo. RESUELTO DIRECTO por
el planner (el humano autorizó hacerlo sin ola formal): valores exactos dados
en el chat, comentario R1 corregido en `common-packages.nix` (hecho), modelo
recomendado para >22 t/s = **qwen3.6:35b-a3b-mtp-q4_K_M** (MoE 3B activos; los
27b densos no llegan a 22 t/s con 8 GiB VRAM). SIN sección nueva en README (el
humano no la quiere — feedback: demasiada burocracia para consultas triviales).

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
| 3 | Editor de vídeo: decisión documentada + verificación VA-API (Shotcut) | audited (excepción P1 menor) |
| 4 | Calibración ollama/Obsidian Copilot — resuelta directo (sin ola formal) | done |

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

## Wave 4 (done — resuelta directo, sin ola formal)

> Queja del humano 2026-08-14: «los modelos locales en Obsidian tardan una
> eternidad y traban toda la PC». Diagnóstico cerrado con evidencia real (ver
> decision log) y **resuelto DIRECTO por el planner**: el humano autorizó
> explícitamente hacerlo sin ola formal, sin executor ni auditoría — feedback:
> «demasiado burocrático». Escalera ponytail peldaño 1: no hay nada que
> construir; el fix es configuración del plugin (vive en el vault de Obsidian,
> no en el repo).

### Diagnóstico (evidencia real, 2026-08-14)

- **Causa raíz** = Obsidian Copilot envía **`num_ctx: 131072`** en cada request
  (valor configurado en el plugin; sobreescribe cualquier default del servidor
  — `OLLAMA_CONTEXT_LENGTH` ni se consulta para modelos con num_ctx propio, lección
  R1). El KV cache de 131k tokens no cabe en 8 GiB VRAM → 10/66 capas en GPU →
  inferencia mayormente en CPU (0.23 t/s, 22.8 GB RSS) → la máquina se traba.
- **El terminal demuestra que ollama está sano**: qwen3.8:27b-mtp-q4_K_M →
  prompt 106 t/s, generación **4.85 t/s** (MTP, aceptación 0.47); qwen3.5:9b →
  **37.6 t/s**. El problema NO es ollama ni NixOS.
- Agravantes del plugin: Token limit 16800 (puede generar 16.8k tokens a ~5 t/s
  = decenas de minutos), Reasoning ON (qwen3 «piensa» miles de tokens antes de
  responder), Vision ON con modelos de texto, Websearch ON (más requests, prompt
  más gordo).
- **Modelo para >22 t/s**: los qwen3.8:27b son DENSOS (18 GB) → ~5 t/s en esta
  máquina, no llegan a 22. El que daba 22 t/s en Fedora es el **MoE
  qwen3.6:35b-a3b** (solo 3B parámetros activos por token) → **pull
  `qwen3.6:35b-a3b-mtp-q4_K_M`** (23 GB, 256k ctx) para >22 t/s sin colapsar.
- **Modelos nube (API opencode-go)**: num_ctx lo decide el servidor (el valor
  del cliente es inerte ahí); Token limit 4–8k basta; Reasoning ON solo si el
  modelo lo soporta.

### Qué se hizo (directo, en esta sesión)

- [x] Comentario R1 corregido en `modules/apps/common-packages.nix` (lección
      num_ctx; sin cambio de comportamiento — `OLLAMA_CONTEXT_LENGTH=16384` y
      `OLLAMA_GPU_OVERHEAD=1073741824` intactos).
- [x] Limpieza: `aider-chat` eliminado de `common-packages.nix` (el workflow usa
      opencode, no aider — autorizado por el humano) y función `update-obsidian`
      (herencia Fedora RPM) eliminada de `shell.nix`; referencias en README.
- [x] NO se añadió subsección README de calibración (el humano no la quiere —
      «solo dime los valores aquí en el chat»).
- [x] Verificación: `nix flake check` pasa; `nix eval` de env vars de ollama
      intactas.

### Pendiente humano (fuera del repo)

1. Aplicar los valores exactos en Obsidian Copilot (local y nube) — dados en el
   chat de la sesión.
2. `ollama pull qwen3.6:35b-a3b-mtp-q4_K_M` y verificar con `ollama ps` →
   CONTEXT ≤ 8192 y tps > 22.

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
| 2026-08-14 | Ola 3 aprobada por auditoría (APPROVED WITH EXCEPTIONS — solo P1 menor: mensaje de commit del executor de 86 chars > ~72, sugerido por el brief) | `.workflow/audits/wave3.md`: diff = solo README.md (+32), smoke test re-ejecutado y salida pegada genuina, `nix flake check` pasa, sin secretos, aislamiento de rama verificable (749bb54 = punta de wave3-executor-1) |
| 2026-08-14 | Diagnóstico Obsidian Copilot: el freeze es client-side — el plugin envía `num_ctx: 131072` en cada request (KV cache no cabe en 8 GiB VRAM → offload CPU), agravado por Token limit 16800 + Reasoning/Vision/Websearch ON | Evidencia: R1 auditoría ola 2 + journalctl del humano (terminal sano: 27b-mtp 4.85 t/s gen / 106 t/s prompt, 9B 37.6 t/s). El fix = ajustes del plugin; nada que construir en este repo |
| 2026-08-14 | Calibración recomendada modelos locales en Obsidian Copilot: num_ctx 8192, Token limit 2048–4096, Reasoning/Vision/Websearch OFF, Temperature 0.6–0.7 (0.66 OK); qwen3.5:9b para chat (37.6 t/s), 27B solo para tareas largas | KV cache de 131k no cabe en 8 GiB VRAM (10/66 capas → 0.23 t/s + 22.8 GB RSS); qwen recomienda temp 0.6–0.7 |
| 2026-08-14 | Modelos nube (API opencode-go): num_ctx lo gestiona el servidor (valor del cliente inerte), Token limit 4–8k basta, Reasoning solo si el modelo lo soporta | Mismos valores que local no dañan, pero el num_ctx ahí no aporta |
| 2026-08-14 | Ola 4 = docs + corrección de comentario únicamente (escalera peldaño 1: nada que construir); SIN Modelfile | La config del plugin vive en el vault de Obsidian, no en el repo; un Modelfile no arregla Obsidian (los parámetros del request sobreescriben los del modelo) |
| 2026-08-14 | Repo limpio al arrancar ola 4: `main` == `origin/main`, árbol limpio, `nix flake check` pasa; nada que arreglar | `.aider.chat.history.md` y `result` están gitignoreados y no trackeados |
| 2026-08-14 | Modelo para >22 t/s en pc (8 GiB VRAM): **`qwen3.6:35b-a3b-mtp-q4_K_M`** (MoE, 3B activos, 23 GB, 256k ctx) — no los qwen3.8:27b densos | Los 27b densos (18 GB) hacen ~5 t/s en esta máquina (medido 4.85 t/s); el a3b es el que daba 22 t/s en Fedora; MTP añade decodificación especulativa. `ollama pull qwen3.6:35b-a3b-mtp-q4_K_M` |
| 2026-08-14 | Ola 4 resuelta DIRECTO por el planner, sin executor ni auditoría (autorizado explícitamente por el humano) | Feedback humano: «demasiado burocrático» para consultas triviales (caso Shotcut). Regla nueva: tareas triviales/consultas → sesión directa, sin ola formal; olas solo para trabajo multi-archivo/paralelo |
| 2026-08-14 | `aider-chat` eliminado de `common-packages.nix` y del README (referencias limpias) | El workflow de este repo usa opencode (AGENTS.md), no aider; el humano autorizó borrarlo («¿te sirve como opencode? si no, bórralo») |
| 2026-08-14 | `update-obsidian` (función RPM de Fedora) eliminada de `shell.nix` y del README | Herencia Fedora inútil en NixOS; el humano autorizó limpiarla |
| 2026-08-14 | NO se añade subsección README de calibración ollama | El humano no la quiere: «solo dime los valores exactos aquí en el chat». La lección R1 queda en el comentario de common-packages.nix (única doc persistente necesaria) |
| 2026-08-14 | Sección README «Edición de vídeo» (ola 3) ELIMINADA — el humano la rechazó («no me interesa el desastre de cosas triviales»); se conserva la decisión Shotcut en el decision log | Menos docs no pedidas = menos ruido; el trabajo de la ola 3 queda registrado en .workflow/ (audits + decision log) para quien lo necesite |
| 2026-08-14 | Trucos config ollama añadidos a common-packages.nix: `OLLAMA_FLASH_ATTENTION=1` y `OLLAMA_KV_CACHE_TYPE=q8_0` | Flash attention libera VRAM del KV cache; KV en q8_0 usa la mitad de memoria que f16 → más capas en la GPU (5–15% t/s). El 2x real viene de MoE a3b + num_ctx 8192 (ver análisis de modelos) |
| 2026-08-14 | Análisis de modelos qwen3.6 (de cero): los MLX y bf16 se descartan (Apple-only / 55–72 GB no caben ni son rápidos); q8_0 = 2× bytes de q4 para ganancia mínima. Ranking por t/s: **35b-a3b-mtp-q4_K_M** (23 GB, MoE 3B activos + MTP) > 35b-a3b-q4_K_M (= `latest`/`35b`, mismo digest 07d35212591f) > 35b-a3b-mtp-q8_0 > 27b-mtp-q4_K_M (~5–7 t/s) | El ganador absoluto es el MoE a3b con MTP: solo 3B parámetros activos por token (el truco de los 22 t/s de Fedora); MTP añade decodificación especulativa encima. `ollama pull qwen3.6:35b-a3b-mtp-q4_K_M` |
| 2026-08-14 | RESULTADO HUMANO: **35.29 t/s** con `qwen3.6:35b-a3b-mtp-q4_K_M` en terminal (draft acceptance 0.68, prompt eval 45.66 t/s) — objetivo superado | journalctl 22:24:35: eval 203 tokens en 5.75 s = 35.29 t/s. Flash attention + KV q8_0 + MoE a3b + MTP funcionando |
| 2026-08-14 | `OLLAMA_GPU_OVERHEAD` subido de 1 GiB a **2 GiB** (2147483648) | Con 1 GiB el desktop aún micro-congelaba (Hyprland caía a GTT con ollama comiéndose la VRAM). Coste aceptado: ~2–4 capas menos en GPU → ~25–30 t/s (sigue > 22). Si persisten los micro-freezes, siguiente paso: num_ctx 8192 también en terminal (`ollama run --num-ctx 8192`) |
| 2026-08-14 | RESULTADO Obsidian: **27 t/s** con qwen3.6:35b-a3b-mtp-q4_K_M (CONTEXT 8192 confirmado en `ollama ps`) — objetivo >22 t/s cumplido desde el plugin | Humano satisfecho: «me siento logrado». El modelo corre 73%/27% CPU/GPU |
| 2026-08-14 | CORRECCIÓN: el 2 GiB de overhead NO eliminó los micro-congelamientos → la causa NO era VRAM/GTT sino **saturación de CPU** (`ollama ps`: 73%/27% CPU/GPU; modelo de 23 GB no cabe en ~6 GiB de VRAM; 16 hilos a tope → Hyprland sin CPU). Solución real: `OLLAMA_CPU_THREADS=12` (deja 4 hilos al escritorio, coste ~10% t/s) + overhead revertido a 1 GiB (más capas en GPU → menos CPU → más t/s) | Evidencia: nproc=16, ollama ps 73%/27%. La hipótesis GTT quedó refutada por el experimento del 2 GiB |
