{ ... }:
{
  # Perfil declarativo: las cuentas se configuran a mano dentro del perfil
  # (~/.thunderbird/yovick), pero las preferencias base quedan versionadas.
  # El wrapper de home-manager trae MIME y los .desktop.
  programs.thunderbird = {
    enable = true;

    profiles.yovick = {
      isDefault = true;

      settings = {
        # Sin CSS propio: deja el aspecto original de Thunderbird.
        "toolkit.legacyUserProfileCustomizations.stylesheets" = false;

        # Mantiene el icono en la bandeja (Linux) y usa las notificaciones
        # nativas: TB sigue avisando aunque la ventana esté oculta.
        "mail.biff.show_tray_icon_always" = true;
        "mail.biff.show_alert" = true;
        "mail.biff.use_system_alert" = true;
      };
    };
  };
}
