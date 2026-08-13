{ config, pkgs, lib, ... }:

# Roles del flujo planner → executors → integrator → auditor.
# Fuente de verdad: ./opencode-agents/*.md (LEGIBLES y versionados aquí).
# home-manager los copia a ~/.config/opencode/agent/*.md en cada rebuild;
# opencode los carga como agentes con Tab (prompt + modelo + color).
# Para editar un rol: edita el .md de este directorio, NO una copia suelta.
{
  home.file = {
    ".config/opencode/agent/planner.md".source = ./opencode-agents/planner.md;
    ".config/opencode/agent/executor.md".source = ./opencode-agents/executor.md;
    ".config/opencode/agent/integrator.md".source = ./opencode-agents/integrator.md;
    ".config/opencode/agent/auditor.md".source = ./opencode-agents/auditor.md;
  };
}
