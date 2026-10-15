{ pkgs, lib, ... }:
# Voces neuronales de Microsoft (las de Edge/Azure) desde la terminal, sin
# Windows, sin cuenta y sin API key: `edge-tts` habla con el endpoint público
# de "read aloud" de Edge. Voces mexicanas: es-MX-DaliaNeural (F) y
# es-MX-JorgeNeural (M); el resto se lista con `edge-tts --list-voices`.
#
# El paquete de nixpkgs está en 7.2.8 y da 403: Microsoft rota el token
# Sec-MS-GEC y esa versión lo firma mal. 7.3.1 lo arregla. Solo cambia el src,
# así que el override conserva las dependencias ya curadas por nixpkgs.
#
# ponytail: techo conocido — cuando nixpkgs suba a >= 7.3.1, borrar este
# override y usar pkgs.python313Packages.edge-tts directamente.
let
  edgeTts = pkgs.python313Packages.edge-tts.overridePythonAttrs (old: rec {
    version = "7.3.1";
    src = pkgs.fetchFromGitHub {
      owner = "rany2";
      repo = "edge-tts";
      tag = version;
      hash = "sha256-1Ji1IqOC3iB36N00Ud6LRXyAwRbUrm5iFd1MyCxkbVc=";
    };
  });
in
{
  home.packages = [ edgeTts ];
}
