{ config, pkgs, lib, ... }:

{
  # NetworkManager (wifi + ethernet + DHCP) y firewall, compartidos por todos
  # los hosts. El backend wifi NO se fuerza aquí: se usa el default de
  # NetworkManager (wpa_supplicant). Forzar `iwd` (antes en amd-laptop.nix)
  # dejaba un dispositivo fantasma (`/net/connman/iwd/0`, wifi-p2p disconnected)
  # que salía como "tachita" en la barra y abortaba la asociación del Wi-Fi
  # real (`iwd: Operation aborted`, "cannot connect"). El PC ya funcionaba bien
  # precisamente porque NO definía backend.
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  # ── MSS clamping (PPPoE / MTU 1492 del ISP) ────────────────────────────────
  # El ISP (Telmex) usa PPPoE: el camino hacia internet limita a MTU 1492
  # (verificado: el gateway responde "Frag needed and DF set (mtu = 1492)").
  # NixOS (como Arch) NO hace nada por defecto: la interfaz anuncia MSS 1460,
  # el servidor responde paquetes de 1500 y 8 bytes no caben en el túnel →
  # paquetes caídos en silencio → descargas que se cortan a mitad
  # (SSL_ERROR_SYSCALL). Fedora resuelve esto con MSS clamping en el firewall;
  # aquí se replica, pero con el valor exacto del camino:
  #   MSS = MTU_interface(1500) − 8 (PPPoE) − 40 (IP+TCP) = 1452.
  # NO usar `--clamp-mss-to-pmtu`: clampea contra el MTU de la RUTA (1500) y
  # da 1460 — que sigue excediendo los 1492 reales. Los SYNs salientes a
  # internet anuncian 1452, los datos del servidor llegan de 1492 exactos y
  # caben, sin depender del PMTUD (bug clásico del RTL8168 que no lo absorbe).
  # El tráfico LAN local se excluye: las máquinas de casa sí usan 1500 completo.
  # ponytail: si algún día el ISP migra a fibra simétrica sin PPPoE (MTU 1500),
  # subir el --set-mss a 1460 o borrar el bloque — el techo es el camino, no
  # esta regla.
  networking.firewall.extraCommands = ''
    iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN ! -d 192.168.1.0/24 -j TCPMSS --set-mss 1452
    ip6tables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1452
  '';
  networking.firewall.extraStopCommands = ''
    iptables -t mangle -D POSTROUTING -p tcp --tcp-flags SYN,RST SYN ! -d 192.168.1.0/24 -j TCPMSS --set-mss 1452
    ip6tables -t mangle -D POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1452
  '';

  # ── DNS declarativo (a prueba de DHCP) ─────────────────────────────────────
  # Nombres de servidor FIJOS: Cloudflare primario, Google fallback. El DHCP del
  # router ya los anunciaba así, pero ahora NO dependemos de lo que el router
  # diga: es declarativo y aplica a los 4 hosts.
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

  # DNS cifrado: systemd-resolved como resolvedor local + DoT (DNS-over-TLS) a
  # Cloudflare y Google. NM delega en resolved; cada query va por TLS (puerto
  # 853), nadie en la red (ni el ISP) puede espiar qué dominios consultamos.
  # `FallbackDNS` cubre el caso de que ambos DoT fallen (ej. red corporativa
  # que bloquea 853): cae a Telmex en claro, mejor que DNS roto.
  networking.networkmanager.dns = "systemd-resolved";
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = "1.1.1.1#cloudflare-dns.com 8.8.8.8#dns.google";
      DNSOverTLS = "yes";
      DNSSEC = "true";
      Domains = "~.";
      FallbackDNS = "200.33.146.1 200.33.148.1"; # Telmex (solo si DoT muere)
    };
  };

  # avahi (mDNS): KDE Connect lo usa para descubrir dispositivos en la misma
  # LAN, indistintamente de si van por ethernet, Wi-Fi 2.4G o 5G. Sin este, el
  # daemon corre pero no anuncia/ve a los móviles vía DNS-SD.

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  # El bucle de muerte del pid file stale — por esto avahi "se rompía y rompía"
  # en los 4 hosts. El módulo de nixpkgs crea /run/avahi-daemon como avahi:avahi
  # (tmpfiles `d /run/avahi-daemon - avahi avahi -`) y endurece el daemon con
  # CapabilityBoundingSet SIN CAP_DAC_OVERRIDE: uid 0 dentro del sandbox NO puede
  # borrar nada en un dir de avahi (cae a la clase "other" de un 755 = sin
  # escritura). Cuando avahi muere de forma anómala (crash, kill -9, muerte rara
  # al boot), queda el pid file stale. En el siguiente arranque libdaemon
  # (daemon_pid_file_is_running) intenta borrarlo como root-sin-capacidad →
  # EACCES, y el return del unlink() se IGNORA → el create() posterior con
  # O_EXCL falla con EEXIST ("Failed to create PID file: File exists") → avahi no
  # vuelve a arrancar NUNCA más salvo limpieza manual. Con la red de Telmex caída
  # (eventos de interfaz a mansalva) la muerte anómala era continua → hosts
  # rotos en cadena.
  # Fix: que systemd gestione el dir (RuntimeDirectory). PID 1 crea el dir en cada
  # start y hace rm_rf de TODO el dir en cada stop (síncrono, "this needs to be
  # gone when we start the service next" — funciona aunque avahi muera con kill
  # -9) → un pid stale NO PUEDE sobrevivir a un ciclo stop/start y avahi ni
  # siquiera necesita su unlink.
  # OJO: NO usar RuntimeDirectoryUser — systemd 261 ya no lo reconoce (Unknown
  # key, ignorada; se eliminó del parser hace años). El dir nace root:root 0755 y
  # avahi lo re-chown a sí mismo en make_runtime_dir: por eso VA CAP_CHOWN en el
  # bounding set (sin él, el stat-check de avahi ve root y aborta con "Failed to
  # create runtime directory").
  # El socket de activación del módulo se desactiva: sin él, avahi crea su propio
  # /run/avahi-daemon/socket (como avahi, en su dir) y no quedan sockets fantasma
  # de systemd apuntando a un inode borrado (que al reiniciarse en cada switch
  # chocaban con EADDRINUSE contra el socket vivo).
  systemd.services.avahi-daemon.serviceConfig.RuntimeDirectory = "avahi-daemon";
  systemd.services.avahi-daemon.serviceConfig.CapabilityBoundingSet = [ "CAP_CHOWN" ];
  systemd.sockets.avahi-daemon.enable = lib.mkForce false;
  systemd.services.avahi-daemon.requires = lib.mkForce [];
}
