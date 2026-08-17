{ config, pkgs, lib, ... }:

let
  # Script compartido por el servicio de arranque y la regla udev: aplica el EPP
  # de CPU y el estado del wallpaper segun el cargador. Medido 2026-08-17: la
  # iGPU (wallpaper de video) consume ~20% de busy constante sin importar el EPP
  # de CPU - era la fuente real del calor/ventilador/bateria en reposo. El EPP
  # de CPU solo gestiona los watts del SoC (~15-20W de cap del EC).
  eppSwitch = pkgs.writeShellScript "epp-switch" ''
    online=$(cat /sys/class/power_supply/AC/online 2>/dev/null)
    if [ "$online" = 1 ]; then
      epp=performance
      # En AC el wallpaper de video puede decodificar (para eso se pide).
      pkill -CONT -u yovick -f mpvpaper 2>/dev/null || true
    else
      epp=power
      # En bateria se congela el wallpaper (SIGSTOP: queda la ultima frame fija,
      # ~20% de la iGPU ahorrado). Se reanuda solo al conectar el cargador.
      pkill -STOP -u yovick -f mpvpaper 2>/dev/null || true
    fi
    for d in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/energy_performance_preference; do
      echo "$epp" > "$d" 2>/dev/null || true
    done
  '';
in
{
  imports = [
    ./amd-common.nix
  ];

  services.xserver.videoDrivers = [ "amdgpu" "modesetting" ];

  # Ollama en GPU: Vulkan funciona con cualquier Radeon/APU (RADV) sin rocm pesado.
  services.ollama.package = pkgs.ollama-vulkan;

  # Laptop = eficiencia: governor powersave (amd-pstate-epp gestiona boost y EPP),
  # sin max_cstate=1 (la CPU entra en C-states profundos al reposo) y GPU dpm en
  # auto (no hereda el amdgpu-perf de amd-desktop). power-profiles-daemon sigue
  # deshabilitado porque pelearía con el governor.
  powerManagement.cpuFreqGovernor = "powersave";
  services.power-profiles-daemon.enable = lib.mkForce false;

  # EPP por estado de energia (medido 2026-08-17): balance_power dejaba el CPU
  # clavado en ~1.4GHz en TODOS los escenarios (idle quemando watts sin bajar de
  # P-state y sin boost bajo carga) - lo peor de ambos mundos: ni ahorro ni
  # rendimiento. performance en AC devuelve el boost real (single-core ~2.9GHz
  # con sha256) y power en bateria lleva el idle al minimo. El EC/BIOS ya capa
  # el presupuesto del SoC (~15-20W), el EPP solo decide como gastarlo.
  systemd.services.cpu-epp = {
    description = "Fija el EPP de la CPU segun el estado del cargador";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = eppSwitch;
    };
  };

  # Re-evalua el EPP al instante al conectar/desconectar el cargador
  # (KERNEL=="AC": el supply de Mains de esta laptop se llama "AC").
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="AC", ACTION=="change", RUN+="${eppSwitch}"
  '';

  # Touchpad Synaptics LEN2073: en protocolo PS/2 (synps/2) libinput detecta el
  # swipe de 3 dedos pero lo descarta al instante ("Touch jump", sin updates de
  # movimiento) -> el gesto de workspaces nunca disparaba. Este touchpad soporta
  # RMI4 por SMBus; forzarlo da multitouch real con seguimiento de 3+ dedos.
  boot.kernelParams = [ "psmouse.synaptics_intertouch=1" ];

  # ThinkPad specific
  services.libinput = {
    enable = true;
    touchpad = {
      naturalScrolling = true;
      disableWhileTyping = true;
      clickMethod = "clickfinger";
      accelProfile = "flat";
    };
  };

  hardware.sensor.iio.enable = true;
}
