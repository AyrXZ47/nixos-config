# Auditoría · Ola 3 — docs editor de vídeo (decisión Shotcut + verificación VA-API)

- Fecha: 2026-08-14
- Auditor: sesión fresca (no la del planner, executor ni integrador de esta ola)
- Árbol: `main` integrado (HEAD `bd8ed9c`), máquina real `nixos-pc` (RX 7600)
- Ola a auditar: la 3 del plan — única subsección `### Edición de vídeo` en README.md
- Commit del executor: `749bb54` (rama `wave3-executor-1`, también en main)

---

## 1. Integridad de la integración

- [x] **`git status` limpio, sin stashes.**
  ```
  On branch main
  Your branch is up to date with 'origin/main'.
  nothing to commit, working tree clean
  git stash list → (vacío)
  ```
- [x] **Commit del executor integrado en main.**
  ```
  git log --oneline -3 → bd8ed9c docs(workflow): ola 2 marcada como completada
                            749bb54 docs(readme): sección edición de vídeo — decisión Shotcut + verificación VA-API
                            581d94a docs(workflow): ola 3 confirmada (Shotcut) + fix P4 audit gate GC
  ```
  El mismo hash `749bb54` está en `main` y en la punta de `wave3-executor-1`
  (`git rev-parse main → bd8ed9c...`, `wave3-executor-1 → 749bb54...`): la rama
  del executor se integró limpia (fast-forward/cherry del commit exacto, no un
  cherry-pick con hash distinto). A diferencia de la ola 2 (P1), el aislamiento
  de rama SÍ es verificable a posteriori.
- [x] **Rama del executor conservada** local y remota:
  ```
  git branch -a → * main, wave1-executor1, + wave3-executor-1,
                  remotes/origin/{main,wave1-executor1,wave3-executor-1}
  ```
  `git show wave3-executor-1 --stat` = README.md, 32 inserciones (mismo commit).
- [x] **Diff vs plan (mapa de propiedad).** Único archivo owned: `README.md`.
  ```
  git diff 749bb54^..749bb54 --stat → README.md | 32 ++++++++++++++++++++++++
  git diff --name-only 749bb54^..749bb54 → README.md
  ```
  Nada fuera del mapa. El commit `bd8ed9c` (post-merge) es docs de workflow
  (.workflow/plan.md, status de ola 2), propiedad del planner, correcto.

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
- [x] Verify del brief (smoke test VA-API) en el árbol integrado: **reproducido
  por el auditor** en `nixos-pc` con el mismo comando del brief.
  ```
  $ ffmpeg -hide_banner -f lavfi -i testsrc=duration=1:size=640x360:rate=30 \
      -vaapi_device /dev/dri/renderD128 -vf 'format=nv12,hwupload' -c:v h264_vaapi -f null -
  Stream #0:0: Video: h264 (High), vaapi(tv, progressive), 640x360 [SAR 1:1 DAR 16:9], q=2-31, 30 fps, 30 tbn
      encoder         : Lavc62.28.102 h264_vaapi
  frame= 30 fps=0.0 q=-0.0 Lsize=N/A time=00:00:00.96 bitrate=N/A speed=15.4x
  ```
  Sin errores; `h264_vaapi` activo en encode por hardware. `/dev/dri/renderD128`
  presente, `ffmpeg` en PATH del usuario.

## 3. Contenido de la sección README

- [x] `### Edición de vídeo` existe bajo `## Software` (línea 112, entre
  `### Applications` y `## Performance & Tuning`), en español, estilo del resto.
- [x] **Decisión Shotcut** declarada: «Editor: Shotcut (ya en
  `modules/apps/common-packages.nix`). Aceleración GPU verificada en `pc`
  (RX 7600): VA-API con radeonsi — H.264/HEVC/VP9/AV1 con decode Y encode por
  hardware».
- [x] **Porqués correctos**, sin claims inventados:
  - Resolve free: «H.264/H.265 se procesan por CPU (el hardware accel es de
    Studio y en Linux NVIDIA-only)» → NO afirma aceleración GPU por Resolve
    (correcto; coincide con decision log). Menciona el flujo ProRes→mov.
  - Filmora: «no existe build Linux — solo Windows/macOS/móvil».
  - kdenlive «descartado», Blender VSE «sin LUTs reales, export por CPU».
- [x] **Smoke test con salida REAL pegada**: la ejecución del auditor produce la
  misma salida (stream `h264_vaapi`, `Lavc62.28.102`, `frame= 30 ...
  time=00:00:00.96 bitrate=N/A`). Única diferencia: `speed=28.3x` en el README
  vs `15.4x` en la re-ejecución — métrica de runtime dependiente de la carga,
  no una incoherencia. El bloque de salida es genuino, no fabricado.
- [x] **Tip AV1**: «exportar a **AV1 por hardware** (la RX 7600 lo soporta) →
  archivos mucho más pequeños a calidad similar» (coherente con vainfo del plan).
- [x] **Nota anti-crash**: «si Shotcut crasheara en NixOS: primero desactivar
  hardware decode en **Ajustes → Reproductor** y reportarlo al planner (ola
  futura) — no parchear a mano ni cambiar de editor».
- [x] Nada de instrucciones falsas; todo lo afirmado tiene evidencia en el plan
  (decision log 2026-08-14) o en la re-ejecución del auditor.

## 4. Disciplina ponytail (ámbito)

- [x] Diff de la ola = SOLO `README.md` (+32). Sin paquetes, módulos ni scripts
  nuevos, sin dependencias nuevas (Shotcut ya estaba en `common-packages.nix`).
- [x] Documentación mínima que cumple los 6 puntos del brief; sin boilerplate,
  sin abstracciones. No aplican `ponytail:` comments (no hay código).
- [x] Escalera ponytail respetada: la verificación ya existía (plan/decision
  log), la ola solo la registra.

## 5. Seguridad

- [x] Scan de secretos en el diff de la ola (README.md @ 749bb54):
  ```
  git grep -n -E "ghp_|AKIA|PRIVATE KEY|BEGIN.*PRIVATE|password|token" 749bb54 -- README.md
  → solo líneas de la sección «Security Notes» (docs de buenas prácticas:
    "Nothing secret is committed", "no SSH keys, no tokens"; initialPassword
    mencionado como mecanismo de primer arranque). Sin secretos reales.
  ```
- [x] Trust boundaries: docs estático, sin inputs externos.
- [x] Release gate: no aplica (config personal, no se distribuye); auditoría
  ligera OK según plan.

## 6. Consistencia con el plan

- [x] `plan.md` Wave 3: status `in-flight` (correcto — la auditoría aún no
  registrada), scope y audit gate coinciden con lo verificado. Decision log
  registra la confirmación humana de **SHOTCUT** (2026-08-14, fila de decisión)
  y la evidencia VA-API; branch B (Resolve) archivado. Coherente.
- [x] La ola 3 no tocó `flake.lock` ni `modules/**` (verificado en el diff).

---

## Hallazgos

| ID | Severidad | Descripción | Evidencia |
|----|-----------|-------------|-----------|
| P1 | Menor (proceso) | Mensaje de commit del executor: 86 chars, sobre el «~72» de AGENTS.md. No bloquea: es EXACTAMENTE el mensaje sugerido por el brief (`.workflow/briefs/wave3-executor-1.md`), así que el executor siguió la instrucción literal | `git log -1 --format="%s" 749bb54 | wc -c` → 87 (incluye \n); brief línea 94 |
| H1 | Handoff (no es hallazgo del executor) | `plan.md` Wave 3 aún en `in-flight` y el decision log no registra aún el resultado de esta auditoría; el auditor NO modifica plan.md (regla) → le toca al planner marcarla `audited` y actualizar el status al acabar | `grep wave3 .workflow/plan.md` → `in-flight` |

## Veredicto

**APPROVED WITH EXCEPTIONS**

La ola 3 cumple su definición de hecho: `nix flake check` pasa, la subsección
`### Edición de vídeo` existe en español con la decisión Shotcut, los porqués
correctos (Resolve free = H.264 por CPU; Filmora sin Linux; kdenlive/Blender VSE
descartados), la salida real del smoke test VA-API verificada por re-ejecución
del auditor (h264_vaapi activo, sin errores), el tip AV1 y la nota anti-crash.
Diff de la ola = solo README.md (+32), sin dependencias ni archivos nuevos, sin
secretos. Aislamiento de rama verificable (P1 de la ola 2 no se repite).

Las excepciones son de proceso y no bloquean: P1 (longitud del mensaje de
commit, heredada de la sugerencia literal del brief) y H1 (actualización de
status en plan.md, que es handoff del planner, no del executor).

## Handoff pendiente (quién y qué)

- **Planner**: marcar Wave 3 como `audited` en `plan.md`, actualizar el status
  del decision log con el resultado de esta auditoría, y re-planear la ola 4
  (calibración tps / num_ctx de qwen3.8 — prioridad alta por R1 de la ola 2).
- **Planner (nit)**: la próxima vez que el brief sugiera un mensaje de commit,
  respetar el límite ~72 chars de AGENTS.md.
- **Humano**: nada pendiente de esta ola (docs). El rebuild de la ola 2 sigue
  siendo verificación suya.
