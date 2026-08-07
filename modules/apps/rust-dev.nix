# Toolchain de desarrollo Rust para PYMZA y cualquier proyecto Dioxus/Axum.
# Provee: rustup (gestor de toolchains), dx (Dioxus CLI), mongodb (base de datos
# local), mongosh, pkg-config + openssl.dev (el driver mongodb compila openssl-sys
# via pkg-config; sin PKG_CONFIG_PATH no encuentra el .pc y falla el build).
#
# Despues del primer rebuild, una sola vez por maquina:
#   rustup default stable
#   rustup target add wasm32-unknown-unknown
#
# mongodb: nixpkgs NO distribuye binario por su licencia SSPL y lo compila desde
# fuente (~1h). Aqui se usa el binario oficial de mongodb.com (misma version
# 7.0.x que nixpkgs) descargado como tarball: instalacion en segundos en
# cualquier maquina nueva. mongod/mongos van enlazados contra glibc/openssl/curl
# de Ubuntu; autoPatchelfHook los re-enlaza con las libs de nixpkgs.
{ config, pkgs, lib, ... }:

let
  mongodb = pkgs.stdenv.mkDerivation {
    pname = "mongodb";
    version = "7.0.37";
    src = pkgs.fetchurl {
      url = "https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-ubuntu2204-7.0.37.tgz";
      sha256 = "sha256-Ls3PjGk5tehXLkuy/wy+d9whfLUdPzEv7+cry9ClnFQ=";
    };
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.openssl pkgs.curl pkgs.gcc.cc.lib ];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      cp bin/mongod bin/mongos $out/bin/
      runHook postInstall
    '';
  };
in
{
  environment.systemPackages = with pkgs; [
    rustup
    dioxus-cli
    mongodb
    mongosh
    pkg-config
  ];

  environment.variables.PKG_CONFIG_PATH = [ "${pkgs.openssl.dev}/lib/pkgconfig" ];
}
