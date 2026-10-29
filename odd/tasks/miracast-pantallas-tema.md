# Miracast, espejo/extender y dark mode — que dejen de fallar

Ámbito: `modules/apps/miracast.nix`, `modules/core/networking.nix`,
`hosts/{pc,laptop}/configuration.nix`, `modules/desktop/hyprland.nix`,
`modules/desktop/hyprland-home.nix` (monitor-mirror.sh), README.

## Specs

- **S1** — "gnd no para de fallar"
- **S2** — "tanto el modo extender como el espejo fallan"
- **S3** — "no me pueden estar fallando"
- **S4** — "además no uso el modo de segunda pantalla por tablet jamás, deberíamos borrar ese modo"
- **S5** — "GN Displays sale en color blanco en pc pero en laptop si tiene dark mode, absolutamente todo debe estar dark mode en todos lados en todos mis hosts, ese es otro error a corregir junto con actualizar la documentación."
- **S6** — "investigar por qué en la laptop hp vieja con windows dió menos errores que mis hosts nixos"
- **S7** — "deberían llamarse mirror y extended no? o bueno, como se llamen" (nombres de los modos: se mantiene el vocabulario del repo, en español)

## Tasks

| ID | Specs | Ruta | Estado | Commit |
| -- | ----- | ---- | ------ | ------ |
| T1 | S1 | `dnsmasq` al módulo home compartido + puertos 67/123/7236 a `modules/core/networking.nix`; quitar el bloque duplicado de `hosts/laptop` | hecha | `bb3eb3c` |
| T2 | S5 | `programs.dconf.enable` + `dconf.settings` con `color-scheme = prefer-dark` (libadwaita no lee `gtk-application-prefer-dark-theme`) | hecha | `5c42987` |
| T3 | S2 S3 S4 | `monitor-mirror.sh`: no tocar el primario al extender, alinear el modo del espejado al del primario, borrar el filtro HEADLESS (el modo tablet ya no existe) | hecha + test de shim (4/4) | `e0c2653` |
| T4 | S6 S5 | README: Miracast, espejo/extender y dark mode | hecha | este commit |

## Log

- **L1** — pedido original del usuario (verbatim):

  > gnd no para de fallar, y tanto el modo extener como el espejo fallan, además deberían llamarse
  > mirror y extended no? o bueno, como se llamen, el punto es que no me pueden estar fallando, además
  > no uso el modo de segunda pantalla por tablet jamás, deberíamos borrar ese modo e investigar por
  > qué en la laptop hp vieja con windows dió menos errores que mis hosts nixos.
  >
  > (…) GN Displays sale en color blanco en pc pero en laptop si tiene dark mode, absolutamente todo
  > debe estar dark mode en todos lados en todos mis hosts, ese es otro error a corregir junto con
  > actualizar la documentación.

- **L2** — evidencia recogida en el host `pc` (2026-10-28), antes de tocar nada:
  - `gnome-network-displays` está instalado en los 4 hosts (`home/default.nix` importa
    `modules/apps/miracast.nix`), pero `dnsmasq` solo existía en `environment.systemPackages` de la
    laptop y los puertos 67/123/7236 solo en `hosts/laptop/configuration.nix`. El `pc` quedó
    exactamente en el estado pre-fix que el propio comentario de la laptop documenta: "el link se
    arma pero la TV nunca recibe IP / nunca conecta la sesión de video, y GND aborta con 'connection
    established .. connection lost'". Eso es el "falla en silencio después de 5 minutos".
  - `p2p-dev-wlp4s0` existe y está `disconnected` en el `pc` → el P2P arranca; lo que falta es el
    DHCP/RTSP.
  - No hay `programs.dconf.enable` en ningún host: `xdg-desktop-portal-gtk` corre, pero
    `org.freedesktop.appearance color-scheme` sale del default del schema (`default` = claro).
    libadwaita (GNOME Network Displays es GTK4/libadwaita) **ignora**
    `gtk-application-prefer-dark-theme`, que es lo único que hoy está seteado.
  - `hl.monitor({ ..., mirror = "none" })` sí des-espeja (verificado creando `HEADLESS-1`,
    espejándolo a `DP-1` y volviéndolo: `mirrorOf` pasa de `"1"` a `"none"`). O sea que el bug de
    extender no está en cómo se apaga el espejo, sino en que el script reaplica
    `mode = preferred, position = auto, scale = 1` a **todos** los monitores, incluido el primario:
    al extender se pierde la geometría configurada del principal.
  - `modules/apps/vnc.nix` (el `cast-tablet`) ya no existe desde la migración a Caelestia; del modo
    tablet solo quedaba el filtro `HEADLESS` defensivo dentro de `monitor-mirror.sh`.
