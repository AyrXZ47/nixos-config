# Brief: Wave 6 · Executor 6

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Que el tema de Neovim (`NeoCyberVim`) **quede para siempre en este repo** y no
dependa de que `DonJulve/NeoCyberVim` siga existiendo en GitHub.

1. **Vendorizar**: clona `https://github.com/DonJulve/NeoCyberVim` dentro de
   `assets/nvim/NeoCyberVim/` y **borra `.git/`**. Deja SOLO los archivos del
   tema (`colors/`, `lua/`, `after/`, `LICENSE`, `README.md`). Es MIT; conserva
   `LICENSE`.
2. **`modules/apps/neovim.nix`**: en el spec de Lazy del tema
   (`.config/nvim/lua/plugins/theme.lua`), carga el plugin desde la ruta local
   en vez del repo de GitHub:
   ```lua
   return {
     {
       dir = "${../../assets/nvim/NeoCyberVim}",
       name = "NeoCyberVim",
       lazy = false,
       priority = 1000,
       opts = { transparent = true },
     },
   }
   ```
   Deja `theme = "NeoCyberVim"` (no toques `install.colorscheme` ni
   `vim.cmd.colorscheme`). Añade un comentario en español: tema de
   `DonJulve/NeoCyberVim` (MIT), vendorizado para que no se pierda si upstream
   borra el repo.
   - Si Lazy no acepta `dir` o da problemas en el arranque, la alternativa es
     `vim.opt.rtp:prepend("${../../assets/nvim/NeoCyberVim}")` + 
     `require("NeoCyberVim").setup({ transparent = true })` en el `initLua`,
     quitando el entry de Lazy. Usa lo que funcione y repórtalo.

## Definition of done

- `assets/nvim/NeoCyberVim/` existe (sin `.git`) con `colors/NeoCyberVim.lua`.
- El spec del tema apunta a la ruta local, no a `DonJulve/NeoCyberVim`.
- `theme` sigue siendo `NeoCyberVim` y la transparencia se mantiene.
- El verify command pasa. Solo `modules/apps/neovim.nix` y
  `assets/nvim/NeoCyberVim/**` (nuevo) modificados.

## Files you own

- `modules/apps/neovim.nix`
- `assets/nvim/NeoCyberVim/**` (nuevo)

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/apps/kitty.nix`, `modules/desktop/**`,
  `home/**`, `hosts/**`, `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- Módulo home-side; no hay activations.

## Read first

- `modules/apps/neovim.nix`: `theme` (línea 4) y el plugin `theme.lua` (~7–17).
- Repo upstream `DonJulve/NeoCyberVim`.

## Verify command

```bash
nix flake check --no-build && test -f assets/nvim/NeoCyberVim/colors/NeoCyberVim.lua && test ! -d assets/nvim/NeoCyberVim/.git && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.home.file.".config/nvim/lua/plugins/theme.lua".text' | grep -q 'assets/nvim/NeoCyberVim'
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- One commit: `chore(nvim): vendorizar NeoCyberVim en assets/`.
- Commit ONLY your owned files.
- BRANCH ISOLATION (mandatory): `git push origin wave6-executor-6`. Nunca a
  `main` ni a otra rama.

## Report back

- Diff resumido, salida del verify, y si Lazy `dir` funcionó o hubo que usar
  `rtp:prepend`.
