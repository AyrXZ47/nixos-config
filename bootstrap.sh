#!/usr/bin/env bash
# bootstrap.sh <host> — despliega el flake en una maquina recien instalada.
# Regenera hardware-configuration.nix a partir de los discos reales, hace switch y lo commitea.
set -euo pipefail

HOST="${1:?uso: ./bootstrap.sh <host>  (pc|laptop|server|vm)}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "[bootstrap] generando hardware-configuration para $HOST..."
sudo nixos-generate-config --dir "hosts/$HOST"
sudo chown -R "$(id -u):$(id -g)" "hosts/$HOST"

echo "[bootstrap] rebuilding $HOST..."
sudo nixos-rebuild switch --flake "$ROOT#$HOST"

git add "hosts/$HOST/hardware-configuration.nix"
if ! git diff --cached --quiet; then
  git commit -m "chore($HOST): actualiza hardware-configuration"
  echo "[bootstrap] hardware-configuration commiteado. Falta: git push"
fi
