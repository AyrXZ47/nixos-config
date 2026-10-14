{ pkgs, lib, ... }:

{
  # virt-manager 5.x lee sus conexiones de dconf, no de un archivo propio:
  # /connections/uris lista los URIs del administrador y /connections/autoconnect
  # cuales se abren solos (ver virtManager/config.py: get_conn_uris,
  # get_conn_autoconnect). NixOS no declara ninguna, y sin esta entrada la GUI
  # abre con "Could not detect a default hypervisor" AUNQUE libvirtd este
  # activo y `virsh -c qemu:///system` responda bien (verificado 2026-10-14:
  # el daemon corria, los sockets existian y la GUI seguia fallando).
  #
  # Va como activation de home-manager (no como servicio de sistema) porque
  # dconf es por sesion de usuario y un oneshot de root no tiene HOME ni bus de
  # sesion. Se escribe solo si falta: si ya la registraste o cambiaste de
  # conexion con la GUI, el rebuild no lo pisa.
  home.activation.virtManagerDefaultConnection = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ${pkgs.dconf}/bin/dconf read /org/virt-manager/virt-manager/connections/uris 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q "qemu:///system"; then
      :
    else
      ${pkgs.dconf}/bin/dconf write /org/virt-manager/virt-manager/connections/uris "['qemu:///system']" 2>/dev/null || true
      ${pkgs.dconf}/bin/dconf write /org/virt-manager/virt-manager/connections/autoconnect "['qemu:///system']" 2>/dev/null || true
    fi
  '';
}
