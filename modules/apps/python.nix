# Python científico global (reemplazo de MATLAB) + mplcyberpunk.
#
# El rumor «no hay python3» era cierto: hasta ahora solo existía el pythonEnv
# aislado de omnetpp (importado desde ese módulo, no visible globalmente).
# Este módulo expone un `python3` con pip + el stack que sustituye a MATLAB:
#   numpy (+ scipy) = el cómputo vectorial/álgebra lineal de MATLAB
#   matplotlib     = las gráficas (el `plot`/`surf` de MATLAB)
#   pandas        = el workspace de tablas (equivalente a las tables de MATLAB)
#   ipython       = la REPL de MATLAB desde terminal
# pip queda disponible para instalar cualquier paquete extra ad hoc.
#
# mplcyberpunk NO está en nixpkgs (verificado), así que se empaqueta aquí desde
# PyPI (buildPythonPackage + fetchPypi). Solo cuelga de numpy+matplotlib.
{ config, pkgs, lib, ... }:

let
  mplcyberpunk = pkgs.python3.pkgs.buildPythonPackage rec {
    pname = "mplcyberpunk";
    version = "0.7.6";
    pyproject = true;
    src = pkgs.fetchPypi {
      inherit pname version;
      sha256 = "sha256-eXyza14eF456PaX08hXkae8Tk1/YyZ0c0gES6Qu6fiI=";
    };
    build-system = [ pkgs.python3.pkgs.hatchling ];
    dependencies = with pkgs.python3.pkgs; [ matplotlib numpy ];
    pythonImportsCheck = [ "mplcyberpunk" ];
  };

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.numpy
    ps.scipy
    ps.pandas
    ps.matplotlib
    ps.ipython
    ps.pip
    # sympy = el Symbolic Math Toolbox de MATLAB (álgebra simbólica)
    ps.sympy
    mplcyberpunk
  ]);
in
{
  environment.systemPackages = [ pythonEnv ];
}
