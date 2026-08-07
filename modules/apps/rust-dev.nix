# Toolchain de desarrollo Rust para PYMZA y cualquier proyecto Dioxus/Axum.
# Provee: rustup (gestor de toolchains), dx (Dioxus CLI), mongodb (base de datos
# local), mongosh, pkg-config + openssl.dev (el driver mongodb compila openssl-sys
# via pkg-config; sin PKG_CONFIG_PATH no encuentra el .pc y falla el build).
#
# Despues del primer rebuild, una sola vez por maquina:
#   rustup default stable
#   rustup target add wasm32-unknown-unknown
{ config, pkgs, lib, ... }:

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
