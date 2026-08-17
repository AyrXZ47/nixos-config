{ config, pkgs, lib, ... }:

let
  # Script compartido por el servicio de arranque y la regla udev: aplica el EPP
  # del CPU segun el cargador. Medido 2026-08-17: la iGPU (wallpaper) drenaba
  # 22W -> 12.6W al pausarla; el wallpaper se pausa POR MPV NATIVO (pause IPC,
  # ver wallpaper-set.sh y el timer wallpaper-power-state en hyprland-home.nix),
  # no con señales: este script solo gestiona los watts del SoC.
  eppSwitch = pkgs.writeShellScript "epp-switch" ''
    online=$(cat /sys/class/power_supply/AC/online 2>/dev/null)
    if [ "$online" = 1 ]; then epp=performance; else epp=power; fi
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

  # Touchpad Synaptics LEN2073: SIN psmouse.synaptics_intertouch (quitado
  # 2026-08-17). Ese param solo servia para el gesto de 3 dedos de workspaces,
  # que jamas funciono y el user no usa ni quiere (no toca el touchpad). Sin el,
  # el touchpad vuelve a PS/2 simple y el trackpoint (que cuelga del mismo
  # controlador por pass-through) pierde la ruta SMBus por donde se le colgaba
  # el estado de los clicks (drag/seleccion pegados; se destrababan con ESC,
  # evidencia 2026-08-17: era un grab de la UI, no del kernel).

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
