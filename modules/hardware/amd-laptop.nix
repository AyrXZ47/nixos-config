{ config, pkgs, lib, ... }:

let
  # Script compartido por el servicio de arranque y la regla udev: aplica el EPP
  # del CPU y platform_profile segun el cargador. El wallpaper ya NO se toca
  # aqui: lo pausa/reanuda mpvpaper-autopause.sh (usuario) por bateria + ventanas
  # visibles. Puro eventos: se corre al enchufar/desenchufar (udev) y una vez al
  # boot; NADA escucha en bucle.
  eppSwitch = pkgs.writeShellScript "epp-switch" ''
    # Bateria = un supply de SISTEMA (scope=System) descargandose. Antes se
    # miraba AC/online, que depende del nombre del supply. El predicado es el
    # mismo de wallpaper-set.sh: una sola semantica en todo el repo.
    on_battery() {
      for s in /sys/class/power_supply/*/status; do
        [ -f "$s" ] || continue
        sc="''${s%/status}/scope"
        { [ ! -f "$sc" ] || [ "$(cat "$sc" 2>/dev/null)" = System ]; } || continue
        [ "$(cat "$s" 2>/dev/null)" = Discharging ] && return 0
      done
      return 1
    }
    if on_battery; then
      epp=power
      # platform_profile: el TECHO de potencia que impone el firmware (ACPI
      # platform profile del ThinkPad). En bateria low-power; en AC performance,
      # o sea boost sin freno. El governor/EPP decide a que frecuencia ir dentro
      # de ese techo; esto decide cuanto puede pedir. Antes quedaba fijo en
      # `balanced` en los dos modos: se pagaba bateria de mas y se perdia boost.
      profile=low-power
    else
      epp=performance
      profile=performance
    fi
    for d in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/energy_performance_preference; do
      echo "$epp" > "$d" 2>/dev/null || true
    done
    if [ -w /sys/firmware/acpi/platform_profile ]; then
      echo "$profile" > /sys/firmware/acpi/platform_profile 2>/dev/null || true
    fi
    # Wi-Fi powersave: ON en batería, OFF en AC. Es por-interfaz (iw), no
    # perfil de NM, así que se reaplica al cambiar el cargador y cuando NM
    # activa/desactiva la conexión (dispatcher de abajo).
    for dev in /sys/class/net/*; do
      [ -d "$dev/wireless" ] || continue
      iface="''${dev##*/}"
      if on_battery; then
        ${pkgs.iw}/bin/iw dev "$iface" set power_save on 2>/dev/null || true
      else
        ${pkgs.iw}/bin/iw dev "$iface" set power_save off 2>/dev/null || true
      fi
    done
    # Visualizer de Caelestia: off en batería, on en AC. Corre como yovick
    # porque shell.json es suyo; Caelestia lo recarga en caliente.
    if [ -x /home/yovick/.config/hypr/scripts/visualizer-power.sh ]; then
      mode=on
      on_battery && mode=off
      ${pkgs.util-linux}/bin/runuser -u yovick -- env HOME=/home/yovick \
        /home/yovick/.config/hypr/scripts/visualizer-power.sh "$mode" \
        >/dev/null 2>&1 || true
    fi
  '';
in
{
  imports = [
    ./amd-common.nix
  ];

  # amdgpu + modesetting los declara amd-common.nix (igual que la pc).

  # PSR (Panel Self Refresh) apagado: en Renoir/Cezanne (5650U) el firmware
  # DMCUB del display falla ("dc_dmub_srv_log_diagnostic_data: DMCUB error") y
  # cuelga el sistema entero. Visto 2026-09-26 18:35 (DMCUB error) -> freeze
  # 18:40 sin ninguna traza mas (ni hung_task ni soft lockup). 0x10 = bit de
  # DC_DEBUG_MASK para desactivar PSR. Coste: un poco mas de bateria.
  boot.kernelParams = [ "amdgpu.dcdebugmask=0x10" ];

  # Ollama en GPU: Vulkan funciona con cualquier Radeon/APU (RADV) sin rocm pesado.
  services.ollama.package = pkgs.ollama-vulkan;

  # Laptop = eficiencia: governor powersave, sin max_cstate=1 (la CPU entra en
  # C-states profundos al reposo) y GPU dpm en auto (no hereda el amdgpu-perf de
  # amd-desktop). OJO: bajo amd_pstate=active el governor NO es un techo de
  # frecuencia — el hardware elige la frecuencia y el governor solo expone el
  # EPP. El techo real de potencia lo pone platform_profile (ver eppSwitch) y el
  # EPP decide como se gasta dentro de ese techo.
  # power-profiles-daemon NO se toca aca: su default ya es false y nada en el
  # repo lo habilita (antes habia un mkForce inutil). Si algun dia alguien lo
  # prende, escribiria el mismo EPP que eppSwitch -> dos duenos del mismo sysfs.
  powerManagement.cpuFreqGovernor = "powersave";

  # Sched-ext scx_lavd: el mismo reparto por criticidad que en la pc, pensado
  # para latencia + consumo (es el scheduler que usa Steam Deck). Encaja con
  # `powersave` + EPP: el governor fija el techo de frecuencia, scx el turno.
  # scx-loader reemplaza al viejo services.scx (removido en nixpkgs 26.11).
  services.scx-loader = {
    enable = true;
    config = {
      default_sched = "scx_lavd";
      # En bateria el modo --powersave del scheduler (empaqueta tareas en menos
      # nucleos, deja al resto dormir) es justo lo que estira las horas. En AC
      # el boost lo dan igual el EPP=performance y platform_profile=performance
      # del script de arriba: aca se cambia DONDE se acomodan las tareas, no la
      # freq. Para A/B en AC: scxctl set-mode gaming|lowlatency.
      default_mode = "PowerSave";
      scheds.scx_lavd.powersave_mode = [ "--powersave" ];
    };
  };

  # Boot: NetworkManager-wait-online bloquea multi-user.target esperando que
  # "haya red", y en una laptop con wifi eso son varios segundos de nada.
  # Solo lo consultan servicios que aca ya corren tarde (cups, etc.).
  systemd.services.NetworkManager-wait-online.enable = false;

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

  # Re-evalua EPP/platform_profile al instante cuando cambia CUALQUIER supply.
  # Antes filtraba KERNEL=="AC" y en este ThinkPad el evento de AC no siempre
  # llega (queda BAT0 cambiando de estado): el servicio se quedaba con el perfil
  # de bateria estando enchufado (visto 2026-10-27: AC online=1 con EPP=power y
  # platform_profile=low-power). El script es idempotente y barato, asi que se
  # dispara con cualquier cambio de power_supply y decide el mismo.
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ACTION=="change", RUN+="${eppSwitch}"
  '';

  # NetworkManager puede aplicar `wifi.powersave = true` al activar el perfil;
  # este dispatcher reaplica el estado real (AC = off, batería = on) después de
  # cada up/down/DHCP.
  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = pkgs.writeShellScript "nm-power-profile" ''
        case "$2" in
          up|down|dhcp4-change|dhcp6-change) exec ${eppSwitch} ;;
        esac
      '';
    }
  ];

  # Salud de la bateria: umbrales 85/90.
  # El EC venia en 95/100 de fabrica: la bateria viviendo entre 95 y 100% es el
  # peor escenario para una Li-ion. Medido 2026-10-21: 81.4% de salud (41.5 Wh
  # reales vs 51 Wh de diseno) con 378 ciclos.
  # 85/90 = corta en 90%, arranca bajo 85%. Baja el plateau de voltaje un
  # escalon mas que 90/95 a cambio de ~30 min de autonomia (41.5 Wh * 5%).
  # OJO: el que degrada al 100% no es el calor (cerca del tope la carga entra en
  # corriente constante y calienta MENOS) sino el voltaje alto sostenido, o sea
  # envejecimiento de calendario. El pico de calor está entre 20 y 80%, no arriba.
  # Ajuste en vivo si hace falta una salida larga (vuelve a 95 al reiniciar):
  #   echo 100 | sudo tee /sys/class/power_supply/BAT0/charge_control_end_threshold
  systemd.services.battery-charge-thresholds = {
    description = "Limita la carga de BAT0 a 90% (salud de la bateria)";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      echo 90 > /sys/class/power_supply/BAT0/charge_control_end_threshold
      echo 85 > /sys/class/power_supply/BAT0/charge_control_start_threshold
    '';
  };

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
