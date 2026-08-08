{ config, pkgs, lib, wayland-wheeltani, ... }:

let
  cfg = config.modules.hardware.wheeltani;

  pkg = pkgs.rustPlatform.buildRustPackage {
    pname = "wayland-wheeltani";
    version = "1.3.2";
    src = wayland-wheeltani;
    cargoLock.lockFile = wayland-wheeltani + "/Cargo.lock";
    # El workspace declara default-members = [middle-scroll-core]; sin --workspace
    # solo se compila el core y el binario no existe.
    cargoBuildFlags = [ "--workspace" ];
    meta.mainProgram = "wayland-wheeltani";
  };
in
{
  options.modules.hardware.wheeltani = {
    enable = lib.mkEnableOption "wayland-wheeltani (autoscroll con el boton central)";
    device = {
      vendorId = lib.mkOption {
        type = lib.types.str;
        description = "USB vendor id del mouse (hex, `lsusb`).";
      };
      productId = lib.mkOption {
        type = lib.types.str;
        description = "USB product id del mouse (hex, `lsusb`).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkg ];

    boot.kernelModules = lib.mkBefore [ "uinput" ];

    # /dev/uinput nace 0600 root:root; el grupo input lo da para escribir (el
    # daemon crea ahi el mouse virtual). /dev/input/event* ya es 0660 root:input
    # por defecto en NixOS, asi que el grupo input cubre leer + EVIOCGRAB (grab).
    services.udev.extraRules = ''
      KERNEL=="uinput", MODE="0660", GROUP="input"
    '';

    users.users.yovick.extraGroups = lib.mkAfter [ "input" ];

    home-manager.users.yovick = {
      xdg.configFile."wayland-wheeltani/config.toml".text = ''
        [device_match]
        vendor_id = "${cfg.device.vendorId}"
        product_id = "${cfg.device.productId}"
      '';

      systemd.user.services.wayland-wheeltani = {
        Unit = {
          Description = "Autoscroll progresivo con el boton central (Wayland-Wheeltani)";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          Type = "simple";
          ExecStart = "${pkg}/bin/wayland-wheeltani --no-interactive";
          Restart = "on-failure";
          RestartSec = 2;
          PrivateTmp = true;
          NoNewPrivileges = true;
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
  };
}
