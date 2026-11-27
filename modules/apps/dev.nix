# Toolchains de desarrollo para pc/laptop: Python científico, Rust/Dioxus,
# MongoDB y Ollama (GPU AMD). No se importa en server ni vm.
{ config, pkgs, lib, ... }:

{
  imports = [
    ./python.nix
    ./rust-dev.nix
  ];

  environment.systemPackages = with pkgs; [
    # mongodb-tools: mongodump/mongorestore/mongoexport para respaldar y
    # verificar la base de PIGNUS (Atlas M0 no incluye backups: el dump
    # nocturno es la única red).
    mongodb-tools
  ];

  services.ollama.enable = true;

  # Contexto 16k por defecto (el default de ollama es 4096): sesiones largas
  # llenaban el contexto y desactivaban MTP (decodificacion especulativa)
  # ("speculative decoding not supported by this context") -> caia de ~44 a ~18 t/s.
  # OJO (leccion R1): esta env var NO aplica a modelos con num_ctx propio en su
  # Modelfile (qwen3.8:27b fija 131072 y la ignora). El control real es el num_ctx
  # por request (cliente: Obsidian Copilot, `ollama run --num-ctx`). Con 8 GiB de
  # VRAM usar num_ctx <= 8192: el KV cache de 131k no cabe y la maquina se traba.
  services.ollama.environmentVariables = {
    OLLAMA_CONTEXT_LENGTH = "16384";
    # Truco 1: flash attention -> menos VRAM para el KV cache y atencion mas rapida.
    # Truco 2: KV cache en q8_0 (mitad de memoria que f16) -> mas capas caben en la
    # GPU. Ambos suman ~5-15% de t/s; el 2x real viene de MoE a3b + num_ctx 8192.
    OLLAMA_FLASH_ATTENTION = "1";
    OLLAMA_KV_CACHE_TYPE = "q8_0";
    # Reserva VRAM para el escritorio: sin esto ollama se come los 8GiB completos
    # y Hyprland renderiza desde GTT (ram del sistema) -> la UI se arrastra.
    # OLLAMA_GPU_OVERHEAD va en BYTES (envconfig/config.go): el valor previo de
    # 1024 era 1KiB, un no-op -> por eso el desktop seguía congelándose.
    # Medido en la máquina real: escritorio en reposo = 0.9 GiB de VRAM; con
    # overhead 1GiB ollama llega a 7.8 GiB totales -> headroom real 0.2 GiB ->
    # Hyprland cae a GTT -> micro-congelamientos. El overhead debe cubrir el uso
    # del escritorio (0.9 GiB) + margen: 2GiB = ~1.1 GiB libres de verdad.
    # 2147483648 = 2GiB. Cada capa que se queda fuera de la GPU se paga caro
    # (medido: bajar de 11 a 9 capas en el MoE = 25.6 -> 18.6 t/s), asi que subir
    # este overhead "para que el escritorio respire" es la palanca equivocada.
    OLLAMA_GPU_OVERHEAD = "2147483648";
    # Micro-congelamientos parte 2: saturacion de CPU. Medido el 2026-10-28 con
    # un MoE de 36B/3B activos (23 GB) en esta RX 7600:
    #   hilos:  6 -> 26.0 t/s | 8 -> 25.1 | 10 -> 23.4 | 12 -> 22.0 | 16 -> 16.5
    # Mas hilos EMPEORA: el decode es bandwidth-bound (los expertos viven en
    # RAM) y el SMT (16 hilos sobre 8 nucleos) solo agrega contencion al
    # controlador de memoria. 6 hilos deja dos nucleos fisicos libres para
    # Hyprland y ademas es el mas rapido: no hay trade-off.
    OLLAMA_CPU_THREADS = "6";
    # Un solo modelo y un solo slot: cada slot paralelo duplica el KV cache y con
    # 8 GiB eso saca capas de la GPU. Tambien evita que un segundo modelo pelee
    # por la VRAM mientras el primero esta cargado.
    OLLAMA_NUM_PARALLEL = "1";
    OLLAMA_MAX_LOADED_MODELS = "1";
  };
}
