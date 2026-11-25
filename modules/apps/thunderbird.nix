{ ... }:
{
  # Perfil declarativo: las cuentas se configuran a mano dentro del perfil
  # (~/.thunderbird/yovick), pero el chrome y las preferencias base quedan
  # versionados. El wrapper de home-manager trae MIME y los .desktop.
  programs.thunderbird = {
    enable = true;

    profiles.yovick = {
      isDefault = true;

      settings = {
        # Sin este pref Thunderbird ignora chrome/userChrome.css.
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

        # Mantiene el icono en la bandeja (Linux) y usa las notificaciones
        # nativas: TB sigue avisando aunque la ventana esté oculta.
        "mail.biff.show_tray_icon_always" = true;
        "mail.biff.show_alert" = true;
        "mail.biff.use_system_alert" = true;
      };

      # Paleta Cyberpunk Neon, la misma que usa Firefox.
      userChrome = builtins.readFile ../../assets/thunderbird/userChrome.css;
      userContent = builtins.readFile ../../assets/thunderbird/userContent.css;
    };
  };
}
