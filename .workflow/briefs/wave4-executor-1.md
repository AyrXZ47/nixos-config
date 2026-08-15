# Brief: Wave 4 · Executor 1

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Dos entregables, cero código nuevo (ola de docs + un comentario).

1. **README.md** — nueva subsección `### Ollama + Obsidian Copilot` bajo
   `## Software` (justo después de `### Edición de vídeo`, mismo estilo en
   español). Contenido obligatorio, con estos números REALES (no inventar otros):
   - Tabla de ajustes recomendados del plugin para modelos **locales**:
     `num_ctx 8192` · `Token limit 2048–4096` · `Temperature 0.6–0.7` ·
     `Reasoning OFF` · `Vision OFF` · `Websearch OFF` (top-p y frequency
     penalty desactivados está bien).
   - Porqué: con `num_ctx 131072` el KV cache no cabe en los 8 GiB VRAM de la
     RX 7600 → solo 10/66 capas en GPU → inferencia en CPU a 0.23 t/s con
     22.8 GB RSS → la PC se traba. Token limit 16800 puede generar 16.8k
     tokens a ~5 t/s (decenas de minutos); Reasoning hace que qwen3 «piense»
     miles de tokens antes de responder.
   - Baselines reales de pc (2026-08-14): `qwen3.5:9b` → **37.6 t/s** (el
     modelo para chat interactivo); `qwen3.8:27b-mtp-q4_K_M` → **4.85 t/s**
     generación / 106 t/s prompt (para tareas largas de terminal, no chat).
   - Cómo verificar que quedó bien: `ollama ps` → CONTEXT ≤ 8192 y PROCESSOR
     mayormente GPU, respuesta en segundos sin freeze.
   - Nota modelos nube (API): num_ctx lo gestiona el servidor (el valor del
     cliente es inerte), Token limit 4–8k basta, Reasoning solo si el modelo
     lo soporta.
2. **modules/apps/common-packages.nix** — corregir SOLO el comentario que está
   sobre `OLLAMA_CONTEXT_LENGTH` para registrar la lección R1: esta env var NO
   aplica a modelos que definen su propio `num_ctx` (ej. qwen3.8 fija 131072);
   el control real es el `num_ctx` por request (lo que envía el cliente/plugin,
   ver la sección nueva del README). Dejar el valor `16384` (sigue aplicando a
   modelos sin num_ctx propio, ej. sesiones de aider) y NO tocar
   `OLLAMA_GPU_OVERHEAD` ni ninguna otra línea de comportamiento.

## Definition of done

- La subsección `### Ollama + Obsidian Copilot` existe en README.md bajo
  `## Software`, en español, con la tabla, los porqués y los baselines reales.
- El comentario de `OLLAMA_CONTEXT_LENGTH` en common-packages.nix menciona la
  lección R1; los valores de `environmentVariables` son byte-idénticos.
- The verify command below passes.

## Files you own

- `README.md` (solo la subsección nueva)
- `modules/apps/common-packages.nix` (solo el comentario sobre `OLLAMA_CONTEXT_LENGTH`)

## Files forbidden

- `flake.lock`, `flake.nix`, `modules/apps/ollama-bin.nix`,
  `modules/hardware/amd-desktop.nix`, `modules/hardware/amd-laptop.nix`,
  `modules/core/nix-optimization.nix`, `home/**`, `hosts/**` — y cualquier
  otro archivo no listado en «Files you own». Si ves algo que arreglar ahí,
  repórtalo, no lo toques.

## Read first

- `README.md` — sección `## Software` completa (estilo y ubicación; la ola 3
  añadió `### Edición de vídeo` justo donde va tu subsección).
- `modules/apps/common-packages.nix` líneas 40–70 (bloque ollama).
- `.workflow/audits/wave2.md` sección 5 (evidencia R1: 0.23 t/s, 10/66 capas,
  22.8 GB RSS) y `.workflow/plan.md` → Wave 4 (diagnóstico completo).

## Verify command

```bash
nix flake check && grep -q "Obsidian Copilot" README.md && nix eval --raw .#nixosConfigurations.pc.config.services.ollama.environmentVariables.OLLAMA_CONTEXT_LENGTH && nix eval --raw .#nixosConfigurations.pc.config.services.ollama.environmentVariables.OLLAMA_GPU_OVERHEAD
```

(debe imprimir `16384` y `1073741824` sin errores — prueba de que solo
cambiaron comentarios/docs)

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line
  (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, `perf:`,
  `style:`, `build:`, `ci:`, `revert:`, optional `(scope)`). Under ~72 chars.
  No AI attribution, no trailers.
- Mensaje sugerido (54 chars): `docs(ollama): calibración para Obsidian Copilot`
- One logical change per commit. One commit per task.
- Commit ONLY your owned files.
- BRANCH ISOLATION (mandatory): commit and push ONLY to your own worktree
  branch — `git push origin wave4-executor-1` — after each commit. Never push
  to `main` or another branch; never merge, rebase, or fast-forward anyone
  else's branch. Your branch is yours; theirs are theirs.

## Report back

- Archivos cambiados + salida completa del verify command.
- Confirmación de que `environmentVariables` no cambió de comportamiento.
- Desviaciones del brief (si las hay) y preguntas abiertas.
