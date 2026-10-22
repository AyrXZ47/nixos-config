{ config, pkgs, lib, ... }:

{
  # ── Endurecimiento base, compartido por los 4 hosts ────────────────────────
  # Solo lo que no cuesta rendimiento ni rompe nada: sysctl de kernel, límites
  # de superficie en sshd y alcance de sudo. Lo que sí cuesta (SELinux/AppArmor
  # con perfiles, init_on_alloc, slab_nomerge, mitigaciones de CPU) queda fuera
  # a propósito: este repo prioriza rendimiento y esas piezas necesitan
  # mantenimiento por app o pegan duro en juegos/IA (ver README, sección
  # seguridad).
  #
  # Ya venían puestos por NixOS y NO se repiten aquí: randomize_va_space=2,
  # yama.ptrace_scope=1, dmesg_restrict=1, unprivileged_bpf_disabled=2,
  # fs.protected_{hardlinks,symlinks,fifos,regular}=1, tcp_syncookies=1,
  # accept_redirects=0, accept_source_route=0, mmap_min_addr=65536,
  # core_pattern -> systemd-coredump, trusted-users = root.

  boot.kernel.sysctl = {
    # Ni siquiera root ve punteros del kernel por /proc (kptr_restrict=1 los
    # ocultaba solo a no-root). Sin costo medible.
    "kernel.kptr_restrict" = 2;
    # Un usuario sin privilegios no puede cargar una imagen de kernel con
    # kexec (root tampoco: es one-way; se reinicia para desactivarlo).
    "kernel.kexec_load_disabled" = 1;
    # Un binario setuid que crashea no deja core dump legible por otros.
    "fs.suid_dumpable" = 0;
    # No reenviar ICMP redirects: en una LAN doméstica nadie debería
    # reescribir la ruta por nosotros (MITM).
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    # TIME_WAIT de sockets con RST: cierra el agujero de ventana de
    # reutilización (RFC 1337) sin impacto en throughput.
    "net.ipv4.tcp_rfc1337" = 1;
  };

  # ── sshd ───────────────────────────────────────────────────────────────────
  # El firewall deja el 22 cerrado en todas las interfaces salvo tailscale0
  # (trustedInterfaces en modules/core/tailscale.nix): el SSH de estos hosts
  # solo se alcanza por la tailnet. Aun así se acota quién y cómo:
  services.openssh.settings = {
    # No existe ninguna clave de root: "no" en vez de "prohibit-password"
    # elimina la rama de login de root por completo.
    PermitRootLogin = "no";
    AllowUsers = [ "yovick" ];
    # Contraseña habilitada A PROPÓSITO: todavía no hay authorized_keys en
    # ningún host (solo ~/.ssh/id_ed25519 local), así que apagarla dejaría el
    # SSH inaccesible. Antes de pasar a false: instalar la pubkey en
    # ~/.ssh/authorized_keys de cada host y probar `ssh -o
    # PasswordAuthentication=no` desde otro nodo de la tailnet.
    PasswordAuthentication = true;
    MaxAuthTries = 3;
    LoginGraceTime = "30s";
  };

  # sudo solo lo puede ejecutar el grupo wheel (si alguien deja un binario
  # setuid suid-root que llama a sudo, ya no le sirve). wheelNeedsPassword ya
  # es true en modules/core/user.nix.
  security.sudo.execWheelOnly = true;
}
