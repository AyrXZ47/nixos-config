{ config, pkgs, lib, ... }:

{
  programs.firefox = {
    enable = true;
    package = pkgs.firefox;

    profiles.yovick = {
      id = 0;
      isDefault = true;

      userChrome = ''
        /* Import your desired components first */

        @import url("chrome/autohide_toolbox.css");
        /* @import url("chrome/toolbars_below_content.css"); */

        /* Apply your custom modifications after imports */

        :root{
          --toolbar-bgcolor: rgb(36,44,59) !important;
          --uc-menu-bkgnd: var(--toolbar-bgcolor);
          --arrowpanel-background: var(--toolbar-bgcolor) !important;
          --autocomplete-popup-background: var(--toolbar-bgcolor) !important;
          --uc-menu-disabled: rgb(90,90,90) !important;
          --lwt-toolbar-field-focus: rgb(36,44,59) !important;
        }

        #sidebar-box{ --sidebar-background-color: var(--toolbar-bgcolor) !important; }
        window.sidebar-panel{ --lwt-sidebar-background-color: rgb(36,44,59) !important; }
      '';
    };
  };

  home.file = {
    ".mozilla/firefox/yovick/chrome/autohide_toolbox.css".text = ''
      /* Source file https://github.com/MrOtherGuy/firefox-csshacks/tree/master/chrome/autohide_toolbox.css made available under Mozilla Public License v. 2.0
      See the above repository for updates as well as full license text. */

      /* Hide the whole toolbar area unless urlbar is focused or cursor is over the toolbar
       * Dimensions on non-Win10 OS probably needs to be adjusted.
       */

      :root{
        --uc-autohide-toolbox-delay: 200ms; /* Wait 0.1s before hiding toolbars */
        --uc-toolbox-rotation: 82deg;  /* This may need to be lower on mac - like 75 or so */
      }

      :root[sizemode="maximized"]{
        --uc-toolbox-rotation: 88.5deg;
      }

      @media  (-moz-platform: windows){
        :root:not([lwtheme]) #navigator-toolbox{ background-color: -moz-dialog !important; }
      }

      :root[sizemode="fullscreen"],
      :root[sizemode="fullscreen"] #navigator-toolbox{ margin-top: 0 !important; }

      #navigator-toolbox{
        --browser-area-z-index-toolbox: 3;
        position: fixed !important;
        background-color: var(--lwt-accent-color,black) !important;
        transition: transform 82ms linear, opacity 82ms linear !important;
        transition-delay: var(--uc-autohide-toolbox-delay) !important;
        transform-origin: top;
        transform: rotateX(var(--uc-toolbox-rotation));
        opacity: 0;
        line-height: 0;
        z-index: 1;
        pointer-events: none;
        width: 100vw;
      }
      :root[sessionrestored] #urlbar[popover]{
        pointer-events: none;
        opacity: 0;
        transition: transform 82ms linear var(--uc-autohide-toolbox-delay), opacity 0ms calc(var(--uc-autohide-toolbox-delay) + 82ms);
        transform-origin: 0px calc(0px - var(--tab-min-height) - var(--tab-block-margin) * 2);
        transform: rotateX(89.9deg);
      }

      :root[window-modal-open] #urlbar[popover],
      #mainPopupSet:has(> [panelopen]:not(#ask-chat-shortcuts,#selection-shortcut-action-panel,#chat-shortcuts-options-panel,#tab-preview-panel)) ~ toolbox #urlbar[popover],
      #navigator-toolbox:is(:hover,:focus-within,[movingtab]) #urlbar[popover],
      #urlbar-container > #urlbar[popover]:is([focused],[open]){
        pointer-events: auto;
        opacity: 1;
        transition-delay: 33ms;
        transform: rotateX(0deg);
      }

      :root[window-modal-open] #navigator-toolbox,
      #mainPopupSet:has(> [panelopen]:not(#ask-chat-shortcuts,#selection-shortcut-action-panel,#chat-shortcuts-options-panel,#tab-preview-panel)) ~ toolbox,
      #navigator-toolbox:has(#urlbar:is([open],[focus-within])),
      #navigator-toolbox:is(:hover,:focus-within,[movingtab]){
        transition-delay: 33ms !important;
        transform: rotateX(0);
        opacity: 1;
      }
      @media (-moz-bool-pref: "userchrome.autohide-toolbox.unhide-by-native-ui.enabled"),
             -moz-pref("userchrome.autohide-toolbox.unhide-by-native-ui.enabled"){
        :root[sizemode="maximized"]:not(:hover){
          #navigator-toolbox:not(:-moz-window-inactive),
          #urlbar[popover]:not(:-moz-window-inactive){
            transition-delay: 33ms !important;
            transform: rotateX(0);
            opacity: 1;
          }
        }
      }

      #navigator-toolbox > *{ line-height: normal; pointer-events: auto }

      :root:not([sessionrestored]) #navigator-toolbox{ transform:none !important }

      :root[customizing] #navigator-toolbox{
        position: relative !important;
        transform: none !important;
        opacity: 1 !important;
      }

      #navigator-toolbox[inFullscreen] > #PersonalToolbar,
      #PersonalToolbar:is([collapsed=""],[collapsed="true"]){ display: none }

      #urlbar[breakout][breakout-extend] > .urlbar-input-container{
        padding-block: calc(min(4px,(var(--urlbar-container-height) - var(--urlbar-height)) / 2) + var(--urlbar-container-padding)) !important;
      }
    '';
  };
}
