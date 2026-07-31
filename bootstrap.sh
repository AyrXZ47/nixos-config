#!/usr/bin/env bash
# bootstrap.sh <host> — despliega el flake en una maquina recien instalada.
# Genera hardware-configuration.nix solo si falta, hace switch y registra el archivo.
set -euo pipefail

HOST="${1:?uso: ./bootstrap.sh <host>  (pc|laptop|server|vm)}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [ ! -f "hosts/$HOST/hardware-configuration.nix" ]; then
  echo "[bootstrap] generando hardware-configuration para $HOST..."
  sudo nixos-generate-config --dir "hosts/$HOST"
  sudo chown -R "$(id -u):$(id -g)" "hosts/$HOST"
fi

echo "[bootstrap] rebuilding $HOST..."
sudo nixos-rebuild switch --flake "$ROOT#$HOST"

git add "hosts/$HOST/hardware-configuration.nix"
if ! git diff --cached --quiet; then
  git commit -m "chore($HOST): registra hardware-configuration"
  echo "[bootstrap] hardware-configuration commiteado. Falta: git push"
fi
