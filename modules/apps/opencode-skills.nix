{ pkgs, lib, ... }:

let
  securityAudit = pkgs.fetchFromGitHub {
    owner = "cloudflare";
    repo = "security-audit-skill";
    rev = "c1c8a8c1471069fb0e188eeaff69b8e8db6564a8";
    hash = "sha256-oVVACjotkHvllQGxEP8yWaEt4c3GxT0d909TUM5P3NM=";
  };

  ponytail = pkgs.fetchFromGitHub {
    owner = "DietrichGebert";
    repo = "ponytail";
    rev = "96608e078b2d5ea607c5c3b8b5a54d1c1fba6846";
    hash = "sha256-PhPtZbeX2wBp19GtWRy+fV93+fFYZe5S487eXPDl/us=";
  };

  anthropicSkills = pkgs.fetchFromGitHub {
    owner = "anthropics";
    repo = "skills";
    rev = "ca45fc496a3436251f191354091d557da31c15b5";
    hash = "sha256-MkCOANBAqCc1WmNf7S8PsyAphGJAIzEXGyCm8RrCR9M=";
  };

  ponytailCommands = [
    "ponytail"
    "ponytail-audit"
    "ponytail-debt"
    "ponytail-gain"
    "ponytail-help"
    "ponytail-review"
  ];

  globalAgents = ''
    # Reglas globales de OpenCode

    ## Ponytail: lazy senior dev

    Antes de escribir código, entendé el problema y el flujo completo. Después
    subí por esta escalera y quedate en el primer peldaño que alcance:

    1. ¿Hace falta construirlo? (YAGNI)
    2. ¿Ya existe en este repo? Reusá el helper o patrón.
    3. ¿Lo resuelve la stdlib?
    4. ¿Lo resuelve una feature nativa de la plataforma?
    5. ¿Lo resuelve una dependencia ya instalada?
    6. ¿Se puede en una línea?
    7. Si no: el mínimo código que funcione.

    Bug fix = causa raíz. Grepeá todos los callers de la función que tocás y
    arreglá una vez en el código compartido, no en el camino que nombró el
    ticket.

    Reglas: sin abstracciones no pedidas, sin dependencias evitables, sin
    boilerplate. Borrar gana a agregar. Aburrido gana a clever. El diff más
    corto que entiende el problema. Marcá un atajo con `ponytail: <techo>`
    cuando corta una esquina real.

    No seas lazy con: validación en bordes de confianza, manejo de errores que
    evita pérdida de datos, seguridad, accesibilidad, calibración de hardware,
    ni nada pedido explícitamente. Lógica no trivial deja UN check runnable.

    ## Commits

    Conventional commits: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`,
    `test:`, `perf:`, `style:`, `build:`, `ci:`, `revert:`. Resumen imperativo,
    minúsculas, una línea, <72 caracteres. Sin atribución de IA ni trailers. Un
    cambio lógico por commit.

    ## Flujo en OpenCode

    - Una sola sesión. No hay planner/executor/integrator/auditor manuales.
    - Tarea chica y entendida: Build directo.
    - Tarea grande o ambigua: Plan primero, después Build.
    - Exploración: subagente `explore` para no contaminar el hilo padre.
    - Review: `/ponytail-review` en la sesión; si querés contexto aislado,
      pasale el mismo prompt al subagente `general`.
    - Tareas largas: `/goal` con objetivo y verificación explícitos.
    - Trabajo riesgoso o paralelo: worktree.
    - El padre es dueño de decisiones, commits y push.

    ## Archivos y permisos

    - El auto-approve está activo. No pidas confirmación para acciones
      triviales; solo para decisiones de producto irreversibles o secretos.
    - Imágenes: usá `read` nativo.
    - PDF: convertí con `pdf2md` y leé el Markdown; no inventes contenido.
    - CSV/texto: `read` directo.
    - Web: usá el MCP `duckduckgo` (`search`/`fetch_content`) o `webfetch`;
      citá fuentes. No hay proveedor pago configurado.
    - Memoria: Basic Memory guarda las decisiones y el contexto durable del
      proyecto en `~/Sync/Notes/PC & AI/Memory`. Usá sus tools (`bm_search`,
      `bm_write`, `bm_context`) cuando necesites contexto pasado; verificá lo
      que devuelve contra el código antes de confiar en ello.

    ## Tablero de trabajo (dotpm)

    El backlog vive en UN solo lugar: el vault, `~/Sync/Notes/Projects`.
    Todo proyecto y toda tarea son notas Markdown con frontmatter `pm-project`
    / `pm-task`, y el kanban/gantt los lee de ahí. **No hay `TODO.md` en los
    repos ni listas de pendientes por sesión.**

    ### Regla de oro

    El tablero es la fuente de **intención y prioridad**; el repo y los commits
    son la fuente del **estado real**. Antes de escribir una tarea, leé el repo;
    antes de cerrarla, verificá el commit o el archivo que la cierra. Los
    `odd/tasks/*.md`, `docs/ROADMAP.md` y documentos de diseño son contexto, no
    el backlog: el estado vivo va en dotpm.

    ### Flujo obligatorio de cada sesión

    1. **Al arrancar**: leé el proyecto en dotpm (`get_project`) y sus tareas
       (`list_tasks`); buscá si la tarea que te pidieron ya existe. No crees
       duplicados.
    2. **Antes de empezar trabajo nuevo**: si no existe la tarea, creala con
       `create_task` antes de tocar código.
    3. **Mientras trabajás**: si cambia el alcance, actualizá la tarea
       (`update_task`) o creá una nueva. El progreso narrativo va en el cuerpo,
       fechado.
    4. **Al cerrar**: la tarea pasa a `done` en el mismo turno que el commit que
       la cierra, y la descripción apunta al commit/archivo/endpoint de
       evidencia. Si el commit no existe, la tarea no se cierra.
    5. **Si el tablero no responde**: no inventes un backlog paralelo; decilo,
       seguí con el trabajo y anotá el pendiente cuando vuelva.

    ### Contrato de una tarea

    - Título: `Ámbito: Tarea` (un solo `: `). El ámbito es el repo, la materia
      o el cliente. Ejemplos: `PIGNUS: ...`, `Crescit: ...`, `DST: ...`.
    - Tag: slug del ámbito en kebab-case (`pignus`, `crescit`,
      `dst-ignition-system`). Sin sub-ámbito no hay tag.
    - Proyecto: todo lo de código va a `💻 Dev`, salvo que exista un proyecto
      dedicado (ej. `🚀 DST` para la tesis). Materias, clientes y áreas de vida
      ya tienen su proyecto.
    - Estados: `todo`, `in-progress`, `review`, `done`, `blocked`, `cancelled`.
    - Prioridades: `critical`, `high`, `medium`, `low`.
    - Descripción mínima: contexto, evidencia (archivo/línea/commit) y criterio
      de cierre. Si no se puede verificar, no es una tarea, es una idea.
    - `in-progress` es un compromiso: máximo 1–2 por proyecto. El resto es
      `todo`.
    - No edites a mano `pm-project`/`pm-task`, `id`, `taskIds`, `subtaskIds` ni
      la sección `## Tasks`: los reescribe el plugin. Título y tags sí son tuyos.

    ### Repo nuevo en el flujo

    Para incorporar un repo: leé `AGENTS.md`, `README.md`, docs y `git log`;
    corré los tests/checks que no necesiten secretos; creá las tareas `done`
    con evidencia, las `in-progress` reales y el backlog pendiente; actualizá
    el `AGENTS.md` del repo para que diga que el backlog vive en dotpm. Después
    de la primera pasada, el repo no necesita un `TODO.md`.

    Para el procedimiento completo, plantillas y revisión semanal, cargá la
    skill `dotpm` (`~/.config/opencode/skills/dotpm/SKILL.md`).
  '';
in
{
  home.file = {
    ".config/opencode/skills/security-audit".source = "${securityAudit}/skills/security-audit";
    ".config/opencode/skills/ponytail".source = "${ponytail}/skills/ponytail";
    ".config/opencode/skills/frontend-design".source = "${anthropicSkills}/skills/frontend-design";
    ".config/opencode/skills/dotpm".source = ./opencode-skills/dotpm;
    ".config/opencode/AGENTS.md".text = globalAgents;
  } // builtins.listToAttrs (map
    (name: {
      name = ".config/opencode/commands/${name}.md";
      value.source = "${ponytail}/.opencode/command/${name}.md";
    })
    ponytailCommands);
}
