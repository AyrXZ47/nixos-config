# Escritorio gráfico para pc/laptop/vm: navegador, Dolphin + stack KDE,
# OnlyOffice, apps de escritorio y el cliente de virt-manager. Las suites
# pesadas (engineering/media/dev) NO se importan acá: la VM conserva GUI sin
# arrastrarlas.
{ config, pkgs, lib, ... }:

{
  # KDE Connect: daemon + puertos 1714-1764. Solo hosts con GUI; server/vm no
  # lo necesitan (la VM sí, porque conserva escritorio).
  programs.kdeconnect.enable = true;

  # Miracast / Wi-Fi Display: puertos del DHCP-P2P, NTP y RTSP de WFD. La app
  # y dnsmasq viven en home vía ./miracast.nix.
  networking.firewall.allowedTCPPorts = [ 7236 ];
  networking.firewall.allowedUDPPorts = [ 67 123 7236 ];

  # Apps de escritorio que se configuran desde Home Manager.
  home-manager.users.yovick = {
    imports = [
      ./dolphin.nix
      ./gtkwave.nix
      ./miracast.nix
      ./pantalla.nix
    ];

    home.packages = [
      # Obsidian con el electron del canal (43.8.3): verificado 2026-11-05, la
      # ventana renderiza bien. Sin override para no arrastrar electron_42
      # (EOL). `glib` (gio) viaja en home/default.nix para el trash del sistema.
      pkgs.obsidian
    ];
  };

  # OnlyOffice reemplaza a LibreOffice. El módulo (no solo el paquete) pasa
  # las fuentes del sistema al FHS env; sin él OnlyOffice no usa fontconfig.
  programs.onlyoffice.enable = true;

  # Menú de aplicaciones estándar: sin esto algunas apps (KDE/Electron) no
  # aparecen en los lanzadores porque no hay applications.menu en xdg/menus.
  environment.etc."xdg/menus/applications.menu".text = ''
    <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
      "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
    <Menu>
      <Name>Applications</Name>
      <DefaultAppDirs/>
      <DefaultDirectoryDirs/>
      <DefaultMergeDirs/>
      <Layout>
        <Merge type="all"/>
      </Layout>
    </Menu>
  '';

  # Extensiones de Brave instaladas por política:
  # - OpenCode Browse: `normal_installed` la instala sola pero deja
  #   desactivarla; el pairing (`browse pair`) sigue siendo un consentimiento
  #   del navegador. El CLI/MCP vive en modules/apps/opencode.nix.
  # - Obsidian Web Clipper: oficial, guarda la página como nota del vault.
  environment.etc."brave/policies/managed/extensions.json".text =
    builtins.toJSON {
      ExtensionSettings = {
        "mfnicocicmmlkpjnaffgihfjhdgjkdjg" = {
          installation_mode = "normal_installed";
          update_url = "https://clients2.google.com/service/update2/crx";
        };
        "cnjifjpddelmedmihgijeibhnjfabmlf" = {
          installation_mode = "normal_installed";
          update_url = "https://clients2.google.com/service/update2/crx";
        };
      };
    };

  # Defaults de Brave: sin política a propósito. El navegador arranca con lo
  # que tenga el perfil y el usuario elige todo desde la UI. La única policy
  # que queda es la de opencode-browse (instala la extensión de browse, no
  # cambia preferencias del navegador).

  environment.systemPackages = with pkgs; [
    # Navegador único. Brave incluye "Private Window with Tor" (no es el Tor
    # Browser endurecido, pero cubre onion y circunvención).
    brave

    keepassxc
    # Ferdium: agregador de mensajería. Arranca desde SUPER+W (time-to-work),
    # oculto en el workspace especial "communication"; no al encender el host.
    ferdium

    # Cliente de virt-manager. En pc/laptop el daemon lo habilita
    # modules.desktop.virtualisation; en la VM queda solo el cliente (no hay
    # libvirtd anidado).
    virt-manager

    # Audio Routing
    qpwgraph

    # Ventoy copia ISOs; popsicle es la GUI para el mismo flujo.
    popsicle
  ] ++ (with pkgs.kdePackages; [
    # Dolphin standalone (sin Plasma) necesita el stack KIO completo para
    # desbloquear/montar discos (kded, kio-extras: prompts de passphrase,
    # kioslaves). plasma-workspace aporta el modulo kded "soliduiserver" que
    # muestra el dialogo de passphrase al hacer click en un disco LUKS (Solid
    # depende de el: llama a org.kde.kded6 /modules/soliduiserver; sin el, el
    # click se cuelga). kdeconnect-kde NO va acá: lo provee
    # programs.kdeconnect (modules/core/networking.nix).
    dolphin
    kio
    kio-extras
    kio-fuse
    kded
    plasma-workspace
    ark
    okular
    partitionmanager
    filelight
  ]);
}
