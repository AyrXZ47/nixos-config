{ ... }:
{
  # Perfil declarativo: las cuentas se configuran a mano dentro del perfil
  # (~/.thunderbird/yovick), pero el chrome y las preferencias base quedan
  # versionados. El wrapper de home-manager trae MIME y los .desktop.
  programs.thunderbird = {
    enable = true;

    profiles.yovick = {
      isDefault = true;

      # Sin este pref Thunderbird ignora chrome/userChrome.css.
      settings."toolkit.legacyUserProfileCustomizations.stylesheets" = true;

      # Paleta Cyberpunk Neon, la misma que usa Firefox.
      userChrome = builtins.readFile ../../assets/thunderbird/userChrome.css;
      userContent = builtins.readFile ../../assets/thunderbird/userContent.css;
    };
  };
}
