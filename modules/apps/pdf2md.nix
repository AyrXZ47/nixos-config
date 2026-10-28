# pdf2md: PDF -> Markdown, para darle contexto a un LLM (o leerlo cómodo en
# terminal). Un PDF no se puede leer crudo: sus streams de contenido van
# comprimidos, así que mandarlo tal cual es basura.
#
# Sale de la capa de texto con pymupdf (CPU, sin modelos): un PDF nacido digital
# ya trae el texto vectorial, y extraerlo son milisegundos. Nada de OCR acá.
#
# ponytail: techo conocido — no hace OCR. Un escaneo no se convierte: el script
# avisa y no escribe nada, en vez de devolver un markdown incompleto que después
# se usaría como contexto sin que nadie note lo que falta. Si algún día hace
# falta, el camino es deepseek-ocr sobre el ollama que ya corre en la pc, como
# fallback explícito y no reemplazando esta extracción.
{ pkgs }:
pkgs.writeShellApplication {
  name = "pdf2md";
  runtimeInputs = [ (pkgs.python3.withPackages (ps: [ ps.pymupdf ])) ];
  text = ''
    exec python3 ${./pdf2md.py} "$@"
  '';
}
