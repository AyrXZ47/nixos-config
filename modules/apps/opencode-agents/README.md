# Agentes del flujo AI (fuente de verdad)

Estos 4 archivos son la fuente de verdad de los roles del flujo
planner → executors → integrator → auditor. NO edites copias sueltas:
edita AQUÍ.

## Cómo se propagan

1. Este directorio vive en el repo `nixos-config` (commiteado y pusheado).
2. `modules/apps/opencode.nix` los copia con home-manager a
   `~/.config/opencode/agent/*.md` en el próximo rebuild del host.
3. opencode los carga como agentes seleccionables con **Tab** (prompt +
   modelo + color del frontmatter).

Flujo de cambio: editar aquí → commit + push → `git pull` + rebuild en cada
host (los archivos del store sustituyen a los locales).

## Notas por rol

- **Trato con V**: V (yovick) es el operador que lanza los roles. Todos los
  agentes se dirigen a él en segunda persona ("tú") y nunca lo llaman "el
  humano" en tercera persona; si fueron lanzados como subagentes, tratan a su
  invocador como par.

- **planner.md** — planifica, nunca codea. Puede leer fuera del repo (vault,
  repos hermanos); escribir fuera solo a petición explícita de V.
- **executor.md** — aislamiento total de territorio: sin checkout/switch,
  sin cd fuera de su worktree; solo lecturas externas que su brief pida.
- **integrator.md** — merge de ramas de ola a main; ante conflicto, para y
  reporta (nunca resuelve con criterio propio).
- **auditor.md** — verifica el árbol integrado con evidencia de comandos;
  sesión siempre nueva (nunca la del planner).

## Modelos y colores

| Rol | Modelo | Color |
|-----|--------|-------|
| planner | opencode-go/glm-5.3-flash | warning (ámbar) |
| executor | opencode-go/glm-5.3-flash | success (verde) |
| integrator | opencode-go/glm-5.3-flash | accent (púrpura) |
| auditor | opencode-go/glm-5.3-flash | error (rojo) |
