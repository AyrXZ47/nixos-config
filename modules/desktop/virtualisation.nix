{ config, pkgs, lib, ... }:

let
  cfg = config.modules.desktop.virtualisation;
in
{
  options.modules.desktop.virtualisation.enable = lib.mkEnableOption "virtualizacion KVM/QEMU + libvirt (virt-manager)";

  config = lib.mkIf cfg.enable {
    # El paquete virt-manager ya lo instala modules/apps/common-packages.nix en
    # los 4 hosts, pero eso es SOLO el cliente: virt-manager abre con "Could
    # not detect a default hypervisor" porque no hay daemon ni socket
    # (libvirtd.service no existe en el sistema, no hay `virsh`). Esto habilita
    # el backend, que es lo que el cliente necesita para autodetectarlo.
    virtualisation.libvirtd.enable = true;

    # virt-manager habla con libvirt por D-Bus como usuario no root; sin este
    # grupo la conexion QEMU:///system pide contraseña de root en cada
    # operacion. Requiere cerrar sesion y volver a entrar para tomar efecto.
    users.users.yovick.extraGroups = [ "libvirtd" ];

    # KVM del kernel ya viene cargado (kvm_amd en pc). `enableKVM` fue
    # retirado en nixpkgs (avisa "no longer has any effect") y su reemplazo
    # documentado es fijar el paquete de qemu.
    virtualisation.libvirtd.qemu.package = pkgs.qemu_kvm;
  };
}
