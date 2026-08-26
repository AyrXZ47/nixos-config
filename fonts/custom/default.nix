{ stdenv, lib }:
stdenv.mkDerivation {
  pname = "custom-fonts";
  version = "2026-08-25";
  src = ./.;

  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/fonts/truetype/custom"
    cp "$src"/*.ttf "$src"/*.otf "$out/share/fonts/truetype/custom/"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Fuentes locales: coleccion de Mikoshi (display/script) + Google Fonts display (Rubik Glitch, Rubik Wet Paint)";
    license = licenses.free;
    platforms = platforms.linux;
  };
}