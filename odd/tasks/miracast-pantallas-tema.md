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
- **S7** — "quiero que la convención sea inglés: Mirror/Extended" (decidido; reemplaza la nota anterior de mantener español)
- **S8** — "Entonces cuál es cuál? yo le picaba una vez a super d y era modo espejo y la siguiente vez... ahora mandaba modo extended" → bindings deterministas, sin toggle
- **S9** — "hubo un momento en la historia de este repo en que tuve wayle y no caelestia... subir y bajar el brillo era instantaneo, quiero que esto se arregle de una vez por todas"
- **S10** — "MI LAPTOP DEBE SER ESPEJO DE MI PC Y VICEVERSA... espero eso deje de ser un problema"
- **S11** — "el modo extended... los escritorios 1,2,3,4,5,6... al infinito deberían de funcionar solamente en el monitor principal, mientras que el segundo monitor se queda sin nada a la espera de que le arrastre alguna ventana"
- **S13** — "busca como estaba resuelto el tema del brillo porque funcionaba en ese entonces 'a tiempo real'. Literal solo es simular como funciona la pantalla de la laptop. Sé que el problema no es el monitor."
- **S14** — "que sea el workspace 9 porque puedo presionar super 9 y llegar cómodamente a él, jamás llego a usar hasta el workspace 9, por lo que que quede clavado el segundo monitor a los workspaces del 9 en adelante me sirve"

## Tasks

| ID | Specs | Ruta | Estado | Commit |
| -- | ----- | ---- | ------ | ------ |
| T1 | S1 | `dnsmasq` al módulo home compartido + puertos 67/123/7236 a `modules/core/networking.nix`; quitar el bloque duplicado de `hosts/laptop` | hecha | `bb3eb3c` |
| T2 | S5 | `programs.dconf.enable` + `dconf.settings` con `color-scheme = prefer-dark` (libadwaita no lee `gtk-application-prefer-dark-theme`) | hecha | `5c42987` |
| T3 | S2 S3 S4 | `monitor-mirror.sh`: no tocar el primario al extender, alinear el modo del espejado al del primario, borrar el filtro HEADLESS (el modo tablet ya no existe) | hecha + test de shim (4/4) | `e0c2653` |
| T4 | S6 S5 | README: Miracast, espejo/extender y dark mode | hecha | `fa8f2f7` |
| T5 | S7 S8 | `SUPER+D` = Mirror y `SUPER+SHIFT+D` = Extended, sin toggle; notificaciones en inglés | hecha | este commit |
| T6 | S9 | brillo: fuera `repeating = true` (66 ms por write DDC/CI medidos; el repeat encolaba ~15 writes/s y el panel quedaba segundos atrás) | hecha | este commit |
| T7 | S11 S12 | `workspace-bind.sh`: 1..12 atados al monitor principal al arrancar y al pasar a Extended; el secundario recibe el siguiente número libre y queda vacío | hecha + verificado con salida HEADLESS (el secundario tomó 13) | este commit |
| T8 | S10 | regla de paridad pc/laptop en `AGENTS.md` | hecha | este commit |
| T9 | S1 | GND sigue fallando **igual en pc y laptop** después del rebuild: barra gris y desconexión sola a los minutos. Bloqueada: falta el log `G_MESSAGES_DEBUG=all` y confirmar si la ONN alguna vez aceptó Miracast (Win+K) desde Windows | bloqueada | — |
| T10 | S13 | `options ddcci delay=20` (el default de 60 ms es el 90% de los 66 ms medidos por write); verificado que el resto del camino es correcto (`getvcp 10` lee 30/100 después de escribir) | hecha, sin verificar en vivo (necesita rebuild) | este commit |
| T11 | S14 | `workspace-bind.sh` con corte: 1..8 al principal, 9..12 al primer secundario | hecha + **verificado con dos monitores reales** (kitty en ws 10 nació en HDMI-A-2) | este commit |

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

- **L3** — correcciones del usuario después del primer merge (verbatim, extracto):

  > tanto pc como laptop fallaban igual con gnd, así que no era que uno si funcionara y el otro no.
  > Ambos fallaron igual al tratar de hacer la conexión.
  >
  > Entonces cuál es cuál? yo le picaba una vez a super d y era modo espejo y la siguiente vez hacía
  > lo mismo, presionaba super d y ahora mandaba modo extended.
  >
  > quiero que la convención sea inglés: Mirror/Extended
  >
  > hubo un momento en la historia de este repo en que tuve wayle y no caelestia. Cuando tuve wayle
  > juro por mi vida que subir y bajar el brillo era instantaneo, quiero que esto se arregle de una vez
  > por todas.
  >
  > Me intriga mucho eso de que mi laptop tenía configs individuales que mi pc no tenía siendo que
  > como regla MI LAPTOP DEBE SER ESPEJO DE MI PC Y VICEVERSA.
  >
  > Ya corrí rebuild switch, onn sigue sin conectar, solo muestra una barra de carga gris y desconecta
  > solo a los pocos mins. FUNCIONA IGUAL EN PC Y EN LAPTOP.
  >
  > modo extended honestamente, carece de sentido... los errores reportados anteriormente quedaron
  > solucionados, no tuve error de nada. El modo extended debería de funcionar igual que en gnome:
  > los escritorios 1,2,3,4,5,6... al infinito deberían de funcionar solamente en el monitor
  > principal, mientras que el segundo monitor se queda sin nada a la espera de que le arrastre
  > alguna ventana y punto, luego el problema es que lanzo el comando "time to work" (super w) y en
  > mi pantalla veo todo menos lo de un escritorio que se va a la segunda pantalla. Eso está mal.

- **L4** — mediciones de esta tanda (2026-10-28, host `pc`):
  - `brightnessctl -d ddcci8 set N%` = **66 ms** por write (10 encadenados = 653 ms, el driver
    serializa); `get` = 1 ms (caché del kernel). El `repeating = true` de las teclas de brillo
    encolaba ~15 writes/s: ese era el retardo, no la latencia del monitor.
  - `hl.workspace_rule({ workspace = "N", monitor = "X" })` funciona por `hyprctl eval` y sí ata el
    escritorio al monitor, pero **no mueve** un workspace que ya existe en otro monitor, y no hay
    dispatcher `move_workspace_to_monitor` en la API Lua (`hl.dsp.move_workspace_to_monitor` es nil).
    Por eso el diseño es por orden: atar 1..12 al principal *antes* de que aparezca el secundario;
    al hotplug, Hyprland le da el siguiente número libre.
  - Verificado con salida `HEADLESS`: con 1..12 atados a `DP-1`, un segundo monitor recién creado
    tomó el escritorio **13** y los numerados se quedaron en `DP-1`.

- **L5** — arqueología del brillo (2026-10-28), pedido de S13:
  - Hasta `c24c715` (2026-09-20, migración a Caelestia) el camino era `brightness.sh`, y para un
    monitor externo con ddcci cargado el branch que corría era `brightnessctl s ±10%` — **el mismo
    `sysfs` de ddcci que usa Caelestia hoy**. El branch `ddcutil setvcp` + `flock` era el fallback
    para hosts sin ddcci. O sea: el script viejo no era más rápido que el actual.
  - `modinfo ddcci` → **`parm: delay` = "default delay after bus writes (in ms, default 60)"**. Los
    66 ms medidos son 60 de delay del driver + ~6 de trabajo real. Ese costo estaba igual en la
    época "instantánea": lo que cambió no fue el script.
  - Palanca real: `options ddcci delay=20` → ~26 ms por write. Si el panel empieza a perder writes
    (discrepancia entre el kernel y `ddcutil --bus 8 getvcp 10`), subir a 30-40. Latencia cero real
    solo con backlight por software (gamma), no con DDC/CI.

- **L6** — causa raíz del brillo (2026-10-29, la encontró el humano): **AI Vision**
  del OSD del MSI MAG 255XF. Con AI Vision activo el escalador del panel sube el
  brillo a máximo por su cuenta, sin que el host escriba nada; por eso ningún log
  ni `getvcp 10` lo explicaba y parecía que "el brillo se reseteaba solo al
  cambiar de workspace". Solución: OSD -> AI Vision -> cambiarlo a "Night Vision =
  AI". **Lección**: antes de pelear con el camino DDC/CI, descartar los modos
  automáticos del panel (AI Vision, HDCR, ECO, sensor de luz). El host no puede
  verlos ni sobrescribirlos.
  Revertidos ese mismo día por precaución y por no aportar nada: `options ddcci
  delay=20` (b80f `bf82431`) y `misc.vrr = 1` + `vrr` por monitor; quedan en los
  valores previos a la sesión (delay de fábrica 60 ms, `vrr = 2`).

