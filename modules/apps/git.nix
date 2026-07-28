{ config, pkgs, lib, ... }:

{
  programs.git = {
    enable = true;
    userName = "Yovick R. Z.";
    userEmail = "yovickrz@gmail.com";

    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      credential.helper = "libsecret";
      safe.directory = "*";
    };

    aliases = {
      st = "status";
      co = "checkout";
      br = "branch";
      ci = "commit";
      df = "diff";
      lg = "log --oneline --graph --decorate --all";
      undo = "reset --soft HEAD~1";
      amend = "commit --amend --no-edit";
    };
  };
}
