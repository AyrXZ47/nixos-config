#!/usr/bin/env bash
# bootstrap.sh <host> — despliega el flake en una maquina recien instalada.
# Regenera hardware-configuration.nix a partir de los discos reales, hace switch y lo commitea.
set -euo pipefail

HOST="${1:?uso: ./bootstrap.sh <host>  (pc|laptop|server|vm)}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# Password del usuario yovick para el PRIMER boot. Ya no está en el repo: vive en
# /etc/nixos-secrets/yovick-password (solo root, se crea aquí si falta). En una
# maquina ya instalada se ignora (el usuario ya existe y /etc/shadow manda).
# Se puede pasar con NIXOS_INITIAL_PASSWORD=... o se pregunta interactivamente.
if [ ! -f /etc/nixos-secrets/yovick-password ]; then
  sudo mkdir -p /etc/nixos-secrets
  if [ -n "${NIXOS_INITIAL_PASSWORD:-}" ]; then
    echo "$NIXOS_INITIAL_PASSWORD" | sudo tee /etc/nixos-secrets/yovick-password >/dev/null
  else
    read -r -s -p "[bootstrap] Password inicial para yovick (solo primer boot): " P
    echo
    echo "$P" | sudo tee /etc/nixos-secrets/yovick-password >/dev/null
  fi
  sudo chmod 600 /etc/nixos-secrets/yovick-password
fi

echo "[bootstrap] generando hardware-configuration para $HOST..."
sudo nixos-generate-config --dir "hosts/$HOST"
sudo chown -R "$(id -u):$(id -g)" "hosts/$HOST"

echo "[bootstrap] rebuilding $HOST..."
sudo nixos-rebuild --impure switch --flake "$ROOT#$HOST"

git add "hosts/$HOST/hardware-configuration.nix"
if ! git diff --cached --quiet; then
  git commit -m "chore($HOST): actualiza hardware-configuration"
  echo "[bootstrap] hardware-configuration commiteado. Falta: git push"
fi
