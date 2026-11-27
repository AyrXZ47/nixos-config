{ ... }:

{
  # El stack de audio no es especifico de AMD ni del escritorio: la VM tambien lo
  # usa. Antes estaba duplicado byte por byte en amd-common.nix y en
  # hosts/vm/configuration.nix.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # jack.enable se quito: nixpkgs lo depreco porque exporta LD_LIBRARY_PATH
    # global (impureza). El unico consumidor era Mixxx, que ahora se envuelve
    # con el pw-jack de pipewire.jack en modules/apps/media.nix.
  };

  # Prioridad realtime para pipewire (necesita RT para latencia baja sin xruns).
  security.rtkit.enable = true;
}
