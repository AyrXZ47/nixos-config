{ config, pkgs, lib, ... }:

{
  options.modules.apps.git = {
    email = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Email para los commits de git. Por host, no hardcodeado acá.";
    };
    name = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Nombre para los commits de git. Por host, no hardcodeado acá.";
    };
  };

  config = {
    programs.git = {
      enable = true;

      settings = {
        user.name = lib.mkIf (config.modules.apps.git.name != null) config.modules.apps.git.name;
        user.email = lib.mkIf (config.modules.apps.git.email != null) config.modules.apps.git.email;
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
        credential.helper = "!gh auth git-credential";
        safe.directory = "*";
        core.hooksPath = "/home/yovick/.config/git/hooks";
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

    # Guard anti-fuga global (todos los repos del host):
    #  - gitignore global: memorias de agentes y secretos nunca se trackean.
    #  - pre-commit: bloquea el commit si el contenido staged parece un secreto.
    home.file = {
      ".config/git/ignore" = {
        text = ''
          # Memorias y estado local de agentes (NUNCA al repo)
          .serena/
          .engram/
          .opencode/
          .aider/
          .aider*
          *.aider*

          # Estado y logs locales
          .cache/
          *.local.yml

          # Secretos y credenciales
          .env
          .env.*
          !.env.example
          *.pem
          *.key
          *.p12
          *.pfx
          *.p8
          *.crt
          *.keystore
          id_rsa
          id_ed25519
          id_ecdsa
          credentials
          secrets/
          *.secret
        '';
      };

      ".config/git/hooks/pre-commit" = {
        text = ''
          #!/usr/bin/env sh
          # Guard anti-fuga: bloquea secretos y archivos sensibles en el staging.
          # Escape hatch intencional: git commit --no-verify
          set -e

          candidates=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)

          blocked_files=$(printf '%s\n' "$candidates" | grep -E '(^|/)(\.env|\.env\.[^.]+)$|\.(pem|key|p12|p8|pfx|keystore)$|(^|/)(auth\.json|credentials|id_rsa|id_ed25519|id_ecdsa|secrets/|\.serena/|\.engram/|\.opencode/|\.aider)' | grep -v '\.env\.example$' || true)

          blocked_content=$(git diff --cached --diff-filter=ACM -U0 2>/dev/null | grep -E '^\+' | grep -E -- '-----BEGIN (RSA|OPENSSH|EC|DSA|PGP) PRIVATE KEY-----|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|sk-live-[A-Za-z0-9]{16,}|sk-[A-Za-z0-9]{20,}|AIza[0-9A-Za-z_\-]{35}|xox[baprs]-[A-Za-z0-9\-]+|eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}|(mongodb(\+srv)?|postgres(ql)?|mysql|redis)://[^:/\s]+:[^@\s]+@' || true)

          if [ -n "$blocked_files" ] || [ -n "$blocked_content" ]; then
              echo "BLOQUEADO: se detecto contenido sensible en el staging." >&2
              if [ -n "$blocked_files" ]; then
                  echo "Archivos sensibles:" >&2
                  printf '%s\n' "$blocked_files" | head -20 >&2
              fi
              if [ -n "$blocked_content" ]; then
                  echo "Posibles secretos en lineas anadidas (muestra):" >&2
                  printf '%s\n' "$blocked_content" | sed 's/^+//' | head -10 >&2
              fi
              echo "" >&2
              echo "Si es intencional (ej. fixture de prueba):" >&2
              echo "  git reset <archivo>   # o quita el secreto" >&2
              echo "  git commit --no-verify  # solo si sabes lo que haces" >&2
              exit 1
          fi

          exit 0
        '';
        executable = true;
      };
    };
  };
}
