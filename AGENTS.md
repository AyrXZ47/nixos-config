# NixOS config — repo-specific guide

Flake-driven NixOS config (`nixos-unstable`, pinned in `flake.lock`) for 4 hosts: `pc`, `laptop`, `server`, `vm`. All `x86_64-linux`, single user `yovick` via Home Manager.

`README.md` is the canonical detailed doc (keybindings, fingerprint workflow, host tuning, adding a host) — read it before touching those areas.

## Wiring (not obvious from filenames)

- `flake.nix` `mkHost` gives EVERY host: home-manager (user `yovick` + `home/default.nix`) + `modules/core/nix-optimization.nix` + its own `hosts/<name>/configuration.nix`. Hosts differ only in which modules they import.
- Two module flavors under `modules/{core,apps,desktop,hardware,theming}`:
  - `modules/hardware/*` (fingerprint, mtp, openrgb) and `modules/desktop/hyprland.nix` declare `options.modules.<category>.<name>.enable`; hosts flip it (`modules.desktop.hyprland.enable = true`).
  - Everything else (`core/*`, `theming/*`, the apps below) is a plain import with no enable flag.
- `modules/apps/` is split: home-side files imported by `home/default.nix` (shell, kitty, neovim, fastfetch, git, mpd, firefox, serena) vs system-side files imported by host configs (common-packages, gaming).
- New feature = new file under `modules/`, imported by the hosts that want it (or `home/default.nix` for home-side apps), NOT added to `flake.nix`. Match the category's existing pattern (enable-option vs plain import).
- `hosts/*/hardware-configuration.nix` is GENERATED (`nixos-generate-config`, disk-by-label on pc/laptop/server). Never hand-edit; regenerate. `./bootstrap.sh <host>` regenerates, rebuilds, and commits it.
- **pc y laptop son espejo uno del otro.** Lo que aplique a los dos va en `modules/` (o `home/default.nix`); en `hosts/<name>/configuration.nix` solo queda lo que es físicamente de ese equipo (hardware, GPU, fingerprint, discos, hostName). Un fix escrito en un host y que sirve para los dos es un bug diferido: el otro se queda sin él en silencio. Ya pasó con Miracast — `dnsmasq` y los puertos del firewall vivían solo en `hosts/laptop` mientras la app la importa `home/default.nix` en los 4 hosts, así que el `pc` tenía GND instalado y roto. Antes de tocar `hosts/*`, preguntarse si no corresponde a un módulo compartido.

## Commands

```bash
sudo nixos-rebuild switch --flake .#<host>   # apply system + home (host ∈ pc|laptop|server|vm)
home-manager switch --flake .#<host>         # Home Manager only
nix flake check                              # evaluate all hosts — closest thing to a test suite
nix flake update                             # bump inputs (home-manager follows nixpkgs)
```

No tests, no CI, no formatter/linter config. `nix flake check` is the only verification; run it after any change.

## Regla de flujo (obligatoria al terminar cada tarea)

- Al terminar, usa todas las herramientas que nix pone a nuestra disposición para evaluar y auditar el código hasta que compile sin errores (`nix flake check`).
- Al finalizar, siempre haz `git commit`. No dejar trabajo sin commitear.
- Nunca hacer `nixos-rebuild switch` sin que el código tenga commit previo; el rebuild lo corre el usuario, después del commit.

## Recursos: GPU siempre que se pueda, CPU siempre con todos los núcleos (obligatorio)

La directiva del repo es **rendimiento al tope**: ningún trabajo CPU-only corre en
un solo núcleo, y cualquier trabajo que tenga variante GPU usa la GPU.

- **GPU primero.** Si el paquete tiene variante acelerada por GPU, se elige esa:
  `whisperVulkan` (no `whisper-cpp`), `ffmpeg-full` con Vulkan/VAAPI (no `ffmpeg`
  plano), `obs-studio` por NVENC/VA-API, `shotcut`/`melt` por GPU, `libplacebo`
  para tonemap HDR, códecs por `hardware.graphics.extraPackages`. Si nixpkgs no
  trae variante GPU, se deja una línea de por qué se eligió la de CPU.
- **CPU: todos los núcleos, siempre.** Los builds de Nix ya lo hacen
  (`nix.settings.max-jobs = "auto"` y `cores = 0` en
  `modules/core/nix-optimization.nix`). Para herramientas fuera de Nix hay que
  pasarlo explícito: `make -j"$(nproc)"`, `cargo -j"$(nproc)"`,
  `xargs -P"$(nproc)"`, `pnpm --workspace-concurrency "$(nproc)"`. Nunca dejar un
  proceso CPU-only en un hilo si acepta `-j`.
## Lo que el agente hace solo y lo que NO (obligatorio)

**Hace solo, sin preguntar:** `mantenimiento audit` y `mantenimiento all` (trim,
scrub, poda, GC, optimise, test corto de NVMe) en cualquier host, `nix flake
update`, `nix flake check`, commits y push del repo, `deploy <host>`.

**Nunca hace solo:** `fwupdmgr update` — el flash de firmware. Un corte a mitad
no lo cubre el rollback de NixOS, así que lo corre el humano, con la máquina
enchufada y quieta.

**Cuando algo quede pendiente que requiera manos humanas**, el agente NO lo
ejecuta "para probar": **avisa y deja la lista exacta de comandos**, uno por
línea, listos para copiar, indicando en qué host va cada uno (por ejemplo
`sudo mantenimiento fwupd` para listar, y el `fwupdmgr update` resultante por
host). Si no hay nada pendiente, lo dice en una línea y sigue.

## Overlays: la menor cantidad posible (obligatorio)

Un overlay cambia el hash de la derivacion: la saca de `cache.nixos.org` y la
hace compilar en cada host, en cada `nix flake update` que toque sus entradas.
Por eso:

- **Si algo falla: se arregla por la via normal o se hace downgrade. Punto.** No
  se agrega un overlay para tapar cada cosa que rompe o que uno quiere cambiar.
- **Antes de crear un overlay se PREGUNTA.** La opcion se propone (que se
  parchea, por que, que cuesta) y el dueno decide. Nunca se crea por iniciativa
  propia.
- Un paquete que **no existe** en nixpkgs (omnetpp) no es un overlay: es una
  derivacion propia, y va a la cache de Cachix desde el workflow.
- Un paquete de nixpkgs que se parchea con `overrideAttrs` es deuda doble: se
  compila siempre y nadie lo va a cachear salvo vos. Es el ultimo recurso
  (audacity 2026-10 lo pago caro: el overlay `unstableFixes` era la unica razon
  por la que compilaba en cada update).

- **Elegir variante GPU no justifica parchear.** Si la variante GPU no existe en
  nixpkgs se documenta y se decide; un `overrideAttrs`/overlay cambia el hash,
  saca el paquete de `cache.nixos.org` y lo hace compilar en cada host (ver
  "Gotchas").

## Gestor de paquetes JS (obligatorio)

- Todo lo JS de este repo usa **pnpm**, nunca `npm`: pnpm ≥10 no ejecuta los
  lifecycle scripts de las dependencias por defecto (el vector principal de
  supply-chain en npm). `npm install` solo como excepcion explicita del brief,
  documentada; herramientas globales van con `pnpm add -g`.
- El gestor de extensiones de Pi usa `npm` por defecto. Por eso
  `~/.pi/agent/settings.json` lleva `"npmCommand": ["pnpm"]`: `pi install`,
  `pi update --extensions` y todo lo que toque `~/.pi/agent/npm` pasa por pnpm.
  Si ese campo desaparece, Pi vuelve a npm en silencio.
- pnpm corre con `minimumReleaseAge=1440` (global, `~/.config/pnpm/config.yaml`):
  una version recien publicada espera 24 h antes de poder instalarse. Eso corta
  el patron de los incidentes de octubre 2026 (LiteLLM 1.107.0, tensorlake,
  @subql/common: paquetes maliciosos vivos horas antes de que los bajaran).
  El costo es que un update de Pi o de una dependencia llega un dia despues.
- El binario `npm` sigue existiendo en el host porque viaja dentro del paquete
  `nodejs` de nixpkgs; no se puede quitar sin repaquetar Node. La regla se
  sostiene por configuracion, no por ausencia del binario.

## Gotchas

- `yovick` is hardcoded in `flake.nix`, `home/default.nix`, and `modules/core/user.nix` — the latter holds `initialPassword` (applies only at first boot). Renaming the user touches all three.
- Fingerprint PAM trap: with `services.fprintd.enable`, `security.pam.services.<name>.fprintAuth` **defaults to true** for every PAM service. It's deliberately off for `login`/`sddm` (SDDM has no fingerprint UI and it blocked login waiting for a finger); fingerprint works only in `sudo` + `hyprlock`. See `modules/hardware/fingerprint.nix` + README.
- Nothing secret is ever committed; `result*`, `.direnv`, `*.iso`, `*.qcow2`, `.aider*` are gitignored — never commit build results.
- Comments and commit messages are written in Spanish, conventional-commit style (`feat(hyprland):`, `fix(deploy):`, `chore(host):`). Match that for commits.


---

# AI tooling

OpenCode v2 es el harness por defecto (`hyprdev` lo lanza con `--auto`). Pi
queda instalado pelado como respaldo. Las reglas globales (ponytail, commits,
flujo de subagentes) y las skills viven en `~/.config/opencode/AGENTS.md` y
`~/.config/opencode/skills/`; no se clonan en este repo. gentle-ai, gentle-shell
y engram fueron retirados.

## Preguntas al humano (obligatorio)

Una pregunta modal parquea la sesión entera: si no estoy delante, no hay trabajo.

- No se pregunta para arrancar algo ya autorizado, ni para elegir entre opciones
  reversibles: se elige la reversible, se ejecuta, y la alternativa queda en una línea
  al final del reporte.
- Se pregunta solo por: una decisión de producto irreversible, un consentimiento
  nativo (review, mantenimiento, tokens opacos), o algo que `git` no pueda revertir.
- Ante la duda entre preguntar y seguir: se sigue. Lo reversible se corrige; lo
  parqueado no avanza.
