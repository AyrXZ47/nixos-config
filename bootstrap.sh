#!/usr/bin/env bash
# bootstrap.sh <host> — despliega el flake en una maquina recien instalada.
# Regenera hardware-configuration.nix a partir de los discos reales, hace switch
# y lo commitea.
set -euo pipefail

HOST="${1:?uso: ./bootstrap.sh <host>  (pc|laptop|server|vm)}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "[bootstrap] generando hardware-configuration para $HOST..."
sudo nixos-generate-config --dir "hosts/$HOST"
sudo chown -R "$(id -u):$(id -g)" "hosts/$HOST"

echo "[bootstrap] rebuilding $HOST..."
# Evaluación pura: el password inicial ya no se lee en eval.
sudo nixos-rebuild switch --flake "$ROOT#$HOST"

# El usuario se crea sin password en el primer boot; se define aquí, después
# del switch, con chpasswd. bootstrap es SOLO para instalación: en una máquina
# ya instalada este paso cambiaría el password, así que no se corre ahí.
P="${NIXOS_INITIAL_PASSWORD:-}"
while [ -z "$P" ] || [[ "$P" == *:* ]]; do
  if [ -n "$P" ]; then
    echo "[bootstrap] el password no puede contener ':'" >&2
  fi
  read -r -s -p "[bootstrap] Password inicial para yovick: " P
  echo
done
printf 'yovick:%s\n' "$P" | sudo chpasswd
unset P

git add "hosts/$HOST/hardware-configuration.nix"
if ! git diff --cached --quiet; then
  git commit -m "chore($HOST): actualiza hardware-configuration"
  echo "[bootstrap] hardware-configuration commiteado. Falta: git push"
fi
