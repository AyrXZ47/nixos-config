{ config, pkgs, lib, ... }:

# Ollama 0.32.12 desde los binarios oficiales de la release. nixpkgs-unstable
# va con dias de retraso (0.32.7) y qwen3.8 exige >= 0.32.12; el tarball
# oficial es la via corta: fetch + copy, sin compilar.
#
# El instalador oficial descarga DOS tarballs (scripts/install.sh):
#   1. ollama-linux-amd64.tar.zst        -> bin/ollama + lib/ollama/ (runners CPU)
#   2. ollama-linux-amd64-rocm.tar.zst   -> addon ROCm extraido ENCIMA (lib/ollama/rocm_v7_2/)
# El binario busca los runners en ../lib/ollama relativo a si mismo, asi que
# copiar ambos a $out preserva esa ruta. Hashes del API de GitHub (release v0.32.12).
let
  ollamaBin = pkgs.stdenv.mkDerivation {
    pname = "ollama";
    version = "0.32.12";

    src = pkgs.fetchurl {
      url = "https://github.com/ollama/ollama/releases/download/v0.32.12/ollama-linux-amd64.tar.zst";
      sha256 = "sha256-T93v9w9YpQPnPUZ40fh1bs/3L7qnQODRTBqxfFYMXoM=";
    };

    ollamaRocm = pkgs.fetchurl {
      url = "https://github.com/ollama/ollama/releases/download/v0.32.12/ollama-linux-amd64-rocm.tar.zst";
      sha256 = "cc8e1c1f4d9db9a299e38b2e238eb55be419dbc06223ea5d759bc480ddb48b85";
    };

    nativeBuildInputs = [ pkgs.zstd ];

    sourceRoot = ".";
    unpackPhase = ''
      tar --zstd -xf $src
      tar --zstd -xf $ollamaRocm
    '';

    installPhase = ''
      mkdir -p $out
      cp -r bin lib $out/
    '';

    meta = {
      description = "Ollama 0.32.12 (binario oficial, ROCm)";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
      mainProgram = "ollama";
    };
  };
in
{
  services.ollama.package = ollamaBin;
}
