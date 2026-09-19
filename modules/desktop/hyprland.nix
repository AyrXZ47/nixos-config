{ config, pkgs, lib, ... }:

let
  cfg = config.modules.desktop.hyprland;
in
{
  options.modules.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland window manager";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.yovick = {
      imports = [ ./hyprland-home.nix ];
      gtk = {
        enable = true;
        theme = {
          name = "Adwaita-dark";
          package = pkgs.gnome-themes-extra;
        };
        iconTheme = {
          name = "Papirus-Dark";
          package = pkgs.papirus-icon-theme;
        };
        # Cursor por gsettings: GTK y el platform theme gtk3 de Qt (QT_QPA_...
        # = gtk3, ver abajo) leen gtk-cursor-theme-name, NO el XCURSOR_THEME de
        # entorno. Sin esto apps Qt como KeepassXC se quedan con el cursor de
        # fábrica aunque XCURSOR_THEME diga Bibata-Material-Deep-Blue. Es el
        # mismo paquete que theme-base.nix usa en home.pointerCursor.
        cursorTheme = {
          name = "Bibata-Material-Deep-Blue";
          package = pkgs.bibata-material-deep-blue;
          size = 30;
        };
        gtk3.extraConfig = {
          gtk-application-prefer-dark-theme = 1;
        };
        gtk4.extraConfig = {
          gtk-application-prefer-dark-theme = 1;
        };
      };
      qt = {
        enable = true;
        platformTheme.name = "gtk3";
        style = {
          name = "adwaita-dark";
          package = pkgs.adwaita-qt;
        };
      };
      xdg.configFile."kdeglobals" = {
        text = ''
          [KDE]
          ColorScheme=BreezeDark
          widgetStyle=Breeze
          [General]
          colorScheme=BreezeDark
        '';
      };
      home.sessionVariables = {
        GTK_THEME = "Adwaita:dark";
        QT_QPA_PLATFORMTHEME = "gtk3";
        # Hyprland, no KDE: XDG_CURRENT_DESKTOP=KDE hace que xdg-open use kfmclient
        # (no instalado) y nunca abra el navegador (rompía gh auth login).
        XDG_CURRENT_DESKTOP = "Hyprland";
      };
    };

    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      theme = "sddm-astronaut-theme";
      extraPackages = with pkgs; [
        (sddm-astronaut.override { embeddedTheme = "cyberpunk"; })
      ];
    };

    # udisks2: Dolphin lista/monta los discos extra (sda/sdb) sin fstab
    services.udisks2.enable = true;
    # Solo el contenedor del root (nvme0n1p2) va con UDISKS_IGNORE
    # (HintIgnore -> StorageVolume.ignored): lo monta el initrd, nunca se
    # desbloquea desde el escritorio, y el volumen desencriptado ya aparece
    # via fstab. El contenedor de Mikoshi se DEJA visible a proposito: es la
    # unica forma de que Dolphin ofrezca el desbloqueo (click -> dialogo de
    # passphrase de soliduiserver, kded de plasma-workspace). Al desbloquear
    # KFilePlacesModel (kio) muestra contenedor + volumen duplicados (no hay
    # dedup); se esconde el del volumen (/dev/mapper/...) una vez con click
    # derecho -> Hide, y persiste en kfileplaces.xml (bookmark por uuid), asi
    # el contenedor queda solo: desbloquea y navega al mountpoint.
    services.udev.extraRules = ''
      # root (nvme0n1p2): contenedor LUKS, siempre montado por el initrd
      SUBSYSTEM=="block", ENV{ID_FS_TYPE}=="crypto_LUKS", ENV{ID_FS_UUID}=="b6a58d8d-5ccb-436d-8837-bbeebc89a57b", ENV{UDISKS_IGNORE}="1"
    '';
    # Daemons runtime del dashboard de Wayle (red, bluetooth, batería)
    hardware.bluetooth.enable = true;
    # Los clones de DS4 emparejan SIN bonding (Bonded: no) y el plugin input de
    # bluez >= 5.69 rechaza HID de dispositivos !bonded ("Rejected connection
    # from !bonded device") a menos que se relaje esta opción. Es el workaround
    # documentado para mandos genéricos de PS4.
    # ponytail: ClassicBondedOnly=false permite conexiones HID sin cifrar por
    # bonding (superficie del CVE-2020-27263); si algún día los mandos bondan
    # de verdad, borrar este bloque.
    hardware.bluetooth.input.General.ClassicBondedOnly = false;
    services.upower.enable = true;
    # Brillo de monitores externos via DDC/CI (i2c) con ddcutil
    hardware.i2c.enable = true;
    services.udev.packages = [ pkgs.ddcutil ];
    services.displayManager.gdm.enable = lib.mkForce false;
    services.desktopManager.gnome.enable = lib.mkForce false;

    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      WLR_NO_HARDWARE_CURSORS = "1";
    };

    environment.systemPackages = with pkgs; [
      mpvpaper
      cliphist
      (sddm-astronaut.override { embeddedTheme = "cyberpunk"; })
      # wayle fuera: el shell es Caelestia (modules/desktop/caelestia.nix).
      # El lock/idle tambien son de Caelestia, no hyprlock/hypridle.
      wl-clipboard
      # Color picker del portal: xdg-desktop-portal-hyprland necesita hyprpicker
      # (o slurp) para implementar PickColor (el "eyedropper" del Chroma Key de
      # Shotcut y cualquier app que use el portal Screenshot). Sin él:
      # "[ERR] Neither slurp nor hyprpicker found. We can't pick colors."
      hyprpicker
      polkit_gnome
      brightnessctl
      ddcutil
      jq # parsing de hyprctl -j en monitor-mirror.sh
    ];

    # security.pam.services.hyprlock ya no aplica: hyprlock se elimino y el lock
    # de Caelestia usa sus propias unidades PAM dentro del paquete
    # (assets/pam.d/{passwd,fprint}), no /etc/pam.d. El trap de fprintAuth
    # (default true con fprintd) sigue afectando a login/sddm/sudo, por eso el
    # modulo fingerprint mantiene login/sddm en fprintAuth=false.

    security.polkit.enable = true;
    # Montar/desbloquear discos (udisks2) sin pedir contraseña al usuario wheel
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (subject.isInGroup("wheel") &&
            (action.id == "org.freedesktop.udisks2.filesystem-mount" ||
             action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
             action.id == "org.freedesktop.udisks2.filesystem-unmount-others" ||
             action.id == "org.freedesktop.udisks2.filesystem-unmount-others-seat" ||
             action.id == "org.freedesktop.udisks2.encrypted-unlock" ||
             action.id == "org.freedesktop.udisks2.encrypted-unlock-system" ||
             action.id == "org.freedesktop.udisks2.encrypted-lock")) {
          return polkit.Result.YES;
        }
      });
    '';

    xdg.portal = {
      enable = true;
      wlr.enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    fonts.packages = with pkgs; [
      jetbrains-mono
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
    ];

    # El agente polkit corre via exec-once en hyprland-home.nix; este servicio
    # nunca arrancaba (graphical-session.target inactivo con systemd.enable=false).
    # Nota: dos agentes polkit a la vez rompen los diálogos de autenticación.

  };
}
