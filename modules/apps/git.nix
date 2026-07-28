{ config, pkgs, lib, ... }:

{
  programs.git = {
    enable = true;

    settings = {
      user.name = "Yovick R. Z.";
      user.email = "yovickrz@gmail.com";
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      credential.helper = "libsecret";
      safe.directory = "*";
      alias = {
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
  };
}
