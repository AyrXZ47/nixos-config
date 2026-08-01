# Reglas de trabajo — NixOS config

## Flujo obligatorio al terminar cada tarea

1. Al terminar, usa todas las herramientas que nix pone a disposición para **evaluar y auditar el código hasta que compile sin errores**. La verificación es `nix flake check` (evalúa los 4 hosts: pc, laptop, server, vm).
2. **Siempre haz `git commit` al finalizar** la tarea. No dejar trabajo sin commitear.
3. **NUNCA hacer `nixos-rebuild switch` sin que el código tenga commit previo.** El rebuild lo corre el usuario solo, después del commit.

## Estilo de commits

- En español, conventional-commit (`feat(hyprland):`, `fix(deploy):`, `chore(host):`).

## Contexto del repo

- Flake-driven, 4 hosts, single user `yovick` via Home Manager.
- Ver también `mem:memory_maintenance` para el modelo de memorias.
