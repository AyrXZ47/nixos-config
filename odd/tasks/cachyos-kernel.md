# Kernel CachyOS (chaotic-nyx) — kernel 7.3.0 LTO/O3 en los 4 hosts

Filosofía: exprimir cada gramo de silicio. Base: `nixos-unstable`, flake, 4 hosts.

## Specs

- **S1** — "quiero el kernel de cachy os hoy mismo en todos mis hosts."
- **S2** — "Los 4 con cachyos-lto" (respuesta a "¿qué hosts cambian de kernel?").
- **S3** — "está bien genérico, sin embargo, tenemos la versión gratuita de cachix de la cual ya se usó 1GB, si cabe perfectamente el kernel de mucho mayor rendimiento y no tenemos que nadar compilando nada en cada actualización, la opción es esa, cachix con tal de obtener el kernel que de mucho mayor rendimiento aunque sea un 1% más."
- **S4** — "Y sí, si la config "sched_ext (scx_lavd)" que mencionas da aún más rendimiento, incluilo de inmediato."
- **S5** — "No te sesgues por la conversación con qwen, cuestiona primero para finalmente obtener el plan mas optimo." → la fuente de verdad es `chaotic-cx/nyx` y el árbol de nixpkgs, no el chat.

## Tasks

| ID | Specs | Ruta | Estado | Commit |
| -- | ----- | ---- | ------ | ------ |
| T1 | S1 S2 | input `chaotic` + `nyx-overlay`/`nyx-cache` + `linuxPackages_cachyos` en pc/laptop/server/vm | hecha | (ver Log) |
| T2 | S4 | `services.scx` con `scx_lavd` en pc y laptop | hecha | (ver Log) |
| T3 | S3 | kernel `GENERIC_V3` compilado en pc + push a Cachix + flip de los 4 hosts | bloqueada: falta token de Cachix | — |
| T4 | S1 | verificación: `nix flake check` verde + kernel/módulos se sustituyen + ddcci compila contra 7.3.0 | hecha | (ver Log) |

## Log

- **L1** — pedido original del usuario (verbatim):

  > estaba "charlando" con qwen, si algo he dicho hasta el cansansio y de verdad quiero que quede grabado en algún lugar es que busco exprimir al máximo cada gramo de silicio. Te mando el contexto de aquella conversación para ahorrar tiempo:
  >
  > > "hola!, oye... en su momento la estabilidad me era importante y usaba el kernel lts de linux, luego me preocupó la seguridad y use el hardened, pero ahora estoy mil veces mas interesado en el maximo rendimiento absoluto al que se puede exprimir el hardware, según yo ese sería el kernel zen, pero, habrá alguno aún mejor para esta filosofía?" … (Qwen: zen < XanMod < CachyOS; propone `linuxPackages_xanmod_latest`, nyx, y `cachyOverride { mArch = "ZEN3"; }`; recomienda `amd_pstate=active` + `schedutil`)
  >
  > bien, pues eso quiero, quiero el kernel de cachy os hoy mismo en todos mis hosts.
  >
  > No te sesgues por la conversación con qwen, cuestiona primero para finalmente obtener el plan mas optimo.

- **L2** — correcciones a la propuesta de Qwen (evidencia: árbol de nyx en `/nix/store/lnaqa2c8l8zfpivd715ni15p2x5s7jkx-source` y nixpkgs del lock):
  - nixpkgs no trae CachyOS (`pkgs/os-specific/linux/kernel/` solo zen/xanmod/lqx/mainline) → hace falta `chaotic-cx/nyx`.
  - `cachyOverride` no acepta `mArch`; el knob es `cachyVars._processor_opt` ∈ {`GENERIC_V2`,`GENERIC_V3`,`GENERIC_V4`,`ZEN4`}. `-lto-znver4` es Zen4+ (el 5700X es Zen3).
  - nyx advierte "We don't provide cache for these" → un `-march` propio compila el kernel en cada host y en cada bump: por eso S3 usa Cachix, no compilación por host.
  - CachyOS ya no es "LTO + BORE": el default (`cachyos-lto`) usa su scheduler propio (`_cpusched = cachyos`); `-bore` es variante aparte.
  - `amd_pstate=active` ya estaba (`modules/hardware/amd-common.nix`); el governor ya es `performance` en pc/server y `powersave` en laptop. zen 7.2.11 ya tiene `SCHED_CLASS_EXT`.

- **L3** — decisión del usuario (respuestas literales): S2 y S3/S4 de arriba.

- **L4** — estado de partida: `pkgs.linuxPackages_zen` (7.2.11) en `amd-common.nix:8` y `vm/configuration.nix:36`. `nix flake check` verde.

- **L5** — T1 hecho: kernel `linuxPackages_cachyos` (7.3.0, clang thin LTO, `-O3`, PREEMPT full, HZ 1000, hugepages always, sched_ext) en los 4 hosts. `chaotic` sin `nixpkgs.follows`: nyx compila contra su propio pin y ese es el hash de nyx-cache (con follows cada host compilaría el kernel). Cache verificado con `curl` al narinfo: kernel 28 MB + módulos 177 MB.

- **L6** — T2 hecho: `services.scx.scheduler = "scx_lavd"` en pc (amd-desktop) y laptop (amd-laptop). Server y vm quedan con el scheduler del kernel.

- **L7** — T3 bloqueada: `cachix` no está instalado ni hay token en `~/.config/cachix`, así que el push del kernel `GENERIC_V3` a `ayrxz47-nixos-config.cachix.org` requiere un paso humano (`cachix authtoken`). Sin artefacto en la cache, flipear los hosts a v3 los haría compilar, que es justo lo que S3 prohíbe.
