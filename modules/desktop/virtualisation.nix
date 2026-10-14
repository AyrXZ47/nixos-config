{ config, pkgs, lib, ... }:

let
  cfg = config.modules.desktop.virtualisation;
in
{
  options.modules.desktop.virtualisation.enable = lib.mkEnableOption "virtualizacion KVM/QEMU + libvirt (virt-manager)";

  config = lib.mkIf cfg.enable {
    # El paquete virt-manager ya lo instala modules/apps/common-packages.nix en
    # los 4 hosts, pero eso es SOLO el cliente. Esto habilita el backend.
    virtualisation.libvirtd.enable = true;

    # virt-manager habla con libvirt por el socket del sistema como usuario no
    # root; sin este grupo la conexion qemu:///system pide contraseña de root
    # en cada operacion. Requiere cerrar sesion y volver a entrar.
    users.users.yovick.extraGroups = [ "libvirtd" ];

    # KVM del kernel ya viene cargado (kvm_amd en pc). `enableKVM` fue
    # retirado en nixpkgs (avisa "no longer has any effect") y su reemplazo
    # documentado es fijar el paquete de qemu.
    virtualisation.libvirtd.qemu.package = pkgs.qemu_kvm;

    # --- Los TRES defaults que virt-manager necesita para no decir "Could not
    # detect a default hypervisor". El daemon solo no alcanza: verificado el
    # 2026-10-14, con libvirtd activo y `virsh -c qemu:///system` funcionando,
    # la GUI seguia mostrando ese dialogo. Le faltaba la conexion registrada.
    #
    # 1) Conexion por defecto, en dconf (virt-manager 5.x lee
    #    /connections/uris y /connections/autoconnect, ver
    #    virtManager/config.py: get_conn_uris/get_conn_autoconnect). En
    #    NixOS home-manager no las declara, asi que se escriben con un script
    #    idempotente: si no hay sesion dconf (SSH, TTY) no falla el switch.
    #
    # 2) Red NAT por defecto (`default`, virbr0 en 192.168.122.1/24), activa
    #    y con autostart. Sin ella la VM arranca sin red.
    #
    # 3) Storage pool `default` sobre /var/lib/libvirt/images, con autostart.
    #    Sin pool, virt-manager no tiene donde poner el disco de la VM.
    #
    # Los puntos 2 y 3 son idempotentes: en cada rebuild reafirman el estado
    # sin recrear nada (net-start/pool-start fallan con "already active" y se
    # ignoran a proposito con `|| true`).
    systemd.services.libvirt-defaults = {
      description = "Registra la conexion, red y pool por defecto de virt-manager";
      wantedBy = [ "multi-user.target" ];
      # Despues de que libvirtd levante sus sockets: los comandos de abajo
      # hablan con el daemon por qemu:///system.
      after = [ "libvirtd.service" ];
      requires = [ "libvirtd.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -eu
        vsh="${pkgs.libvirt}/bin/virsh -c qemu:///system"

        # Red NAT por defecto. `net-list --all` la trae ya definida por el
        # modulo, asi que basta con arrancarla y marcarla de autostart.
        $vsh net-start default 2>/dev/null || true
        $vsh net-autostart default 2>/dev/null || true

        # Storage pool default. `pool-define-as` solo falla si ya existe;
        # build/start/autostart son idempotentes.
        if ! $vsh pool-info default >/dev/null 2>&1; then
          ${pkgs.coreutils}/bin/mkdir -p /var/lib/libvirt/images
          $vsh pool-define-as default dir --target /var/lib/libvirt/images
          $vsh pool-build default
        fi
        $vsh pool-start default 2>/dev/null || true
        $vsh pool-autostart default 2>/dev/null || true
      '';
    };

    # La conexion por defecto de la GUI vive en un modulo home aparte: el
    # activation escribe en el dconf del USUARIO, y dconf es por sesion (un
    # oneshot de root no tiene HOME ni bus de sesion). Mismo patron que
    # hyprland.nix -> hyprland-home.nix.
    home-manager.users.yovick = {
      imports = [ ./virtualisation-home.nix ];
    };
  };
}
