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
    - Memoria: no hay memoria automática. Las decisiones durables van al
      `AGENTS.md` del repo o a las notas; no inventes contexto que no esté
      respaldado por el código o la documentación.
  '';
in
{
  home.file = {
    ".config/opencode/skills/security-audit".source = "${securityAudit}/skills/security-audit";
    ".config/opencode/skills/ponytail".source = "${ponytail}/skills/ponytail";
    ".config/opencode/skills/frontend-design".source = "${anthropicSkills}/skills/frontend-design";
    ".config/opencode/AGENTS.md".text = globalAgents;
  } // builtins.listToAttrs (map
    (name: {
      name = ".config/opencode/commands/${name}.md";
      value.source = "${ponytail}/.opencode/command/${name}.md";
    })
    ponytailCommands);
}
