# Compatibilidad: el contenido de este archivo se partió por rol en
# common-cli.nix (los 4 hosts), desktop.nix (pc/laptop/vm), engineering.nix,
# media.nix y dev.nix (pc/laptop). Este alias mantiene el nombre viejo para
# cualquier import que todavía lo use; los hosts ya importan los módulos por rol
# directamente.
{ ... }:
{
  imports = [ ./common-cli.nix ];
}
