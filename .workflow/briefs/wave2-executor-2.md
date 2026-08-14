# Brief: Wave 2 · Executor 2

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Cambiar el GC de Nix en `modules/core/nix-optimization.nix` para que el
perfil de sistema tenga **siempre máximo 3 generaciones, por conteo y no por
edad**. Hoy conserva 16 con rebuilds frecuentes porque el GC diario es por
edad (`--delete-older-than 3d`) y `trim-generations` solo corre semanal.

Solución: el GC diario pasa a conteo con `nix.gc.options =
"--delete-generations +3"` (mantiene las 3 más nuevas). Con eso el
`trim-generations` semanal (servicio + timer) se vuelve redundante → se
elimina (deletion over addition). Se conservan los comentarios en español
actualizándolos a la nueva lógica.

## Definition of done

- `nix.gc.options` es `--delete-generations +3` (conteo), ya no
  `--delete-older-than 3d` (edad).
- El servicio `systemd.services.trim-generations` y el timer
  `systemd.timers.trim-generations` ya no existen.
- Comentarios en el archivo actualizados (español), explicando que el GC
  diario es por conteo.
- El resto del archivo intacto: `nix.optimise.automatic`, journald, bootloader,
  autoUpgrade, substituters, schedulers idle.
- La verificación de abajo pasa.

## Files you own

- `modules/core/nix-optimization.nix`

## Files forbidden

- `.workflow/**`, `flake.lock`, `flake.nix`, `modules/apps/**`,
  `modules/hardware/**`, cualquier otro archivo.

## Read first

- `modules/core/nix-optimization.nix` (el archivo entero — entender qué es
  GC por edad vs por conteo y qué NO se debe romper)
- `.workflow/plan.md` (decisión log: por qué conteo y no edad)

## Verify command

```bash
nix flake check && nix eval --raw .#nixosConfigurations.pc.config.nix.gc.options
```

Debe terminar sin errores e imprimir `--delete-generations +3`. Nota: el GC
se aplica en el próximo `nixos-rebuild switch` (el humano lo corre tras el
commit). Tras el switch, `nix-env -p /nix/var/nix/profiles/system
--list-generations` debe mostrar ≤ 3 tras el GC diario.

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line
  (`fix:` o `chore:`). Under ~72 chars. No AI attribution, no trailers.
  En español, estilo del repo.
- One logical change per commit. One commit per task.
- Commit ONLY your owned files.
- BRANCH ISOLATION (mandatory): worktree branch `wave2-executor-2`; commit
  and push ONLY to it (`git push origin wave2-executor-2`). Never push to
  `main` or another branch. No `git checkout`/`switch`/`branch`/`worktree`
  ajenos.

## Report back

- Archivos cambiados, salida del verify, qué se eliminó y por qué, dudas
  abiertas.
