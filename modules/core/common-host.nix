{ ... }:

{
  # Politica comun a los 4 hosts. Antes vivia copiada en hosts/*/configuration.nix
  # (cuatro copias = cuatro oportunidades de divergir sin que nadie lo note).
  # Lo que NO va aca porque es de cada maquina: system.stateVersion (refleja
  # cuando se instalo), networking.hostName y todo lo de hardware.

  # systemd-boot en todos: ESP unica, GRUB en ninguno.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Misma persona, misma zona, mismo idioma en los cuatro.
  time.timeZone = "America/Mexico_City";
  i18n.defaultLocale = "en_US.UTF-8";

  services.openssh.enable = true;

  # Identidad de git: se define aca y NO en modules/apps/git.nix, para que quien
  # clone el repo no herede la identidad del autor (el default de ese modulo es
  # null y home-manager omite la clave). Un host puede pisarla si hace falta.
  home-manager.users.yovick.modules.apps.git = {
    name = "Yovick RZ";
    email = "66042604+AyrXZ47@users.noreply.github.com";
  };
}
