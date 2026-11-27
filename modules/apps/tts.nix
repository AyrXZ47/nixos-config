# Voces neuronales de Microsoft (las de Edge/Azure) desde la terminal, sin
# Windows, sin cuenta y sin API key: `edge-tts` habla con el endpoint público
# de "read aloud" de Edge. Voces mexicanas: es-MX-DaliaNeural (F) y
# es-MX-JorgeNeural (M); el resto se lista con `edge-tts --list-voices`.
#
# nixpkgs ya empaqueta 7.3.1 (la versión que corrige el 403 del token
# Sec-MS-GEC). No hay override: se usa el binario precompilado del canal.
{ pkgs, ... }:

{
  home.packages = [ pkgs.python313Packages.edge-tts ];
}
