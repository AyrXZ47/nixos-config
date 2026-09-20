# Brief: Wave 3 · Executor 1

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Añadir en `README.md`, como nueva subsección `### Edición de vídeo` dentro de
`## Software`, una sección corta que documente la decisión de editor de vídeo de
la pc (RX 7600): **se sigue con Shotcut**. Contenido requerido:

1. Shotcut ya está en el config (`modules/apps/common-packages.nix`) y su
   aceleración por GPU está verificada en esta máquina (VA-API con radeonsi:
   H.264/HEVC/VP9/AV1 con decode Y encode por hardware).
2. Por qué NO DaVinci Resolve free: H.264/H.265 se procesan por CPU en la
   versión free (hardware accel = Studio, y en Linux NVIDIA-only); por eso el
   flujo previo del usuario exigía convertir a mov (ProRes → cientos de GB).
   Instalarlo en NixOS es posible (existe en nixpkgs) pero no arregla eso.
3. Por qué NO Filmora (no existe build para Linux — solo Windows/macOS/móvil),
   ni kdenlive (el usuario lo descartó), ni Blender VSE (sin LUTs reales, export
   por CPU).
4. La salida REAL del smoke test VA-API que el executor corre (abajo), pegada
   literalmente en la sección como evidencia.
5. Tip: exportar a AV1 por hardware (la RX 7600 lo soporta) → archivos mucho más
   pequeños a calidad similar.
6. Nota: si Shotcut crasheara en NixOS, primero desactivar hardware decode en
   Ajustes → Reproductor y reportarlo al planner (ola futura) — NO parchear a
   mano ni cambiar de editor.

NO tocar ningún otro archivo. NO añadir paquetes, módulos ni scripts (YAGNI:
ya está todo instalado y funcionando). Escalera ponytail: esto es documentación,
no código.

## Definition of done

- La subsección `### Edición de vídeo` existe en README.md, en español, con el
  estilo del resto del README.
- La salida real del smoke test VA-API está pegada en la sección (sin inventar).
- El smoke test corre sin errores (`h264_vaapi` en la salida de ffmpeg).
- `nix flake check` pasa.
- Un solo commit con la sección.

## Files you own

- `README.md`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/**`, `home/**`, `hosts/**`,
  `bootstrap.sh`, `.workflow/**` y cualquier otro archivo del repo. Aunque te
  parezca "obvio" que hay que arreglarlo → repórtalo al planner, no lo toques.

## Read first

- `README.md` — estructura y estilo (sección `## Software`, idioma español,
  formato de las subsecciones).
- `AGENTS.md` — reglas de commit, territorio y convenciones (comentarios y
  commits en español).
- `.workflow/plan.md` → sección «Wave 3» (contexto y evidencia ya recogida por
  el planner; NO modificar plan.md).

## Verify command

```bash
# 1) Smoke test VA-API REAL en esta máquina (nixos-pc, RX 7600).
#    Debe terminar sin errores y mostrar h264_vaapi en la salida:
ffmpeg -hide_banner -f lavfi -i testsrc=duration=1:size=640x360:rate=30 \
  -vaapi_device /dev/dri/renderD128 -vf 'format=nv12,hwupload' \
  -c:v h264_vaapi -f null - 2>&1 | grep -E "h264_vaapi|error|Error" | head -5
#    (si `ffmpeg` no está en PATH, anteponer:
#     nix run 'github:NixOS/nixpkgs/0e251e24a4f24e036a084b6b4b2d2491af4167f4#ffmpeg' -c )

# 2) El repo sigue evaluando:
nix flake check
```

Esperado del smoke test: línea `Stream #0:0: Video: h264_vaapi (...)` SIN
`error`/`Error`. Si falla: NO arreglar — detente y reporta al planner (un fallo
de VA-API sería una tarea nueva, no esta ola de docs).

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line
  (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, `perf:`,
  `style:`, `build:`, `ci:`, `revert:`, optional `(scope)`). Under ~72 chars.
  No AI attribution, no trailers.
- One logical change per commit. One commit per task.
- Commit ONLY your owned files.
- BRANCH ISOLATION (mandatory): commit and push ONLY to your own worktree
  branch — `git push origin wave3-executor-1` — after each commit. Never push
  to `main` or another branch; never merge, rebase, or fast-forward anyone
  else's branch. Your branch is yours; theirs are theirs.
- Mensaje sugerido: `docs(readme): sección edición de vídeo — decisión Shotcut + verificación VA-API`

## Report back

- Salida real del smoke test VA-API.
- Diff de README.md (resumen).
- Confirmación de que `nix flake check` pasa.
- Desviaciones u observaciones (p. ej. si el smoke test falló).
