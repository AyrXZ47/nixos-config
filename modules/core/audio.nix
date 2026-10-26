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
    jack.enable = true;
  };

  # Prioridad realtime para pipewire (necesita RT para latencia baja sin xruns).
  security.rtkit.enable = true;
}
