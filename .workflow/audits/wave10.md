# Auditoría — Ola 10 (reproducibilidad del seed de `shell.json`)

- **Árbol auditado**: `main` @ `537ab6a` (`merge: wave 10 wave10-executor-1`
  sobre `ce926e2`).
- **Base de la ola**: `0658aa7` (`docs: planificar ola 10`).
- **Fecha**: 2026-09-21 00:55 CST.
- **Alcance**: 1 ejecutor, 1 archivo (`modules/desktop/caelestia.nix`).
- **Veredicto**: **APPROVED**. Sin excepciones de código; solo findings
  informativos (§5).

Evidencia > narración: cada check es un comando ejecutado por el auditor sobre el
árbol integrado; se transcribe la salida.

---

## 1. Integridad de integración

- `git status --porcelain` → vacío (0 líneas). `git stash list` → vacío.
- `HEAD = 537ab6a merge: wave 10 wave10-executor-1`; padres
  `0658aa7` (main previo) y `ce926e2` (executor). El commit del ejecutor es
  ancestro de `HEAD` (`git merge-base --is-ancestor ce926e2 HEAD` → OK).
- La ola tocó **exactamente** el mapa de propiedad (un solo archivo):

  ```
  $ git diff --name-status 0658aa7..HEAD
  M  modules/desktop/caelestia.nix

  $ git log --stat ce926e2 -1
   modules/desktop/caelestia.nix | 29 +++++++++++++++++++----------
   1 file changed, 19 insertions(+), 10 deletions(-)
  ```

  Mapa de la ola: `modules/desktop/caelestia.nix` → executor-1. Sin invasiones de
  territorio.
- `flake.lock` **intacto**: `git diff 0658aa7..HEAD -- flake.lock` → 0 líneas.
  Sin dependencias nuevas.
- Commit no-merge en conventional-commit español, una línea, imperativo:
  `ce926e2 feat(caelestia): re-sembrar shell.json al cambiar el seed`.
- `origin/main` = local (`537ab6a`), `origin/wave10-executor-1` = `ce926e2`
  (push del ejecutor correcto, no tocó `main`).

## 2. Build & tests

| Check | Comando | Resultado |
|-------|---------|-----------|
| Flake check (todos los hosts) | `nix flake check` | `all checks passed!` · EXIT=0 |
| Toplevel pc | `nix build --no-link .#nixosConfigurations.pc.config.system.build.toplevel` | EXIT=0 (sin salida) |
| Verify del brief (árbol integrado) | comando completo del brief | EXIT=0 |
| Hash en eval | `builtins.hashString "sha256"` vs `sha256sum` del seed | coinciden |

### Verify del brief — re-seed + preservación

Comando exacto del brief sobre el árbol integrado (`nix flake check --no-build`,
build de `shellJsonPath`, activation con `HOME` temporal, seed stale →
re-sembrado, edición → preservada):

```
$ nix flake check --no-build && nix build --no-link --print-out-paths \
    '.#nixosConfigurations.pc.config.modules.desktop.caelestia.shellJsonPath' \
    >/dev/null && d="$(nix eval --raw \
    '.#nixosConfigurations.pc.config.home-manager.users.yovick.home.activation.caelestiaSeedConfig.data')" \
  && ... (secuencia completa del brief)
all checks passed!
VERIFY EXIT=0
```

### Verificación independiente más fuerte (3 semánticas + hash + bordes)

El verify del brief solo cubre dos caminos; el auditor reprodujo las tres
semánticas exigidas por el plan y los bordes de migración:

```
seed store path: /nix/store/h764yzvq6rrkjira2yi1j5kym8g74ycv-caelestia-shell.json
sha256 del seed : 90104453273a61ddc95386e5be4072108fd74c60c9d1015f015c50068f395b1f
hash en el data : 90104453273a61ddc95386e5be4072108fd74c60c9d1015f015c50068f395b1f

--- [1] archivo ausente -> siembra ---
OK siembra: shell.json existe
OK contenido == seed
sidecar=90104453273a61ddc95386e5be4072108fd74c60c9d1015f015c50068f395b1f

--- [2] hash del sidecar == sha256 del seed ---
OK sidecar correcto

--- [3] archivo editado + seed sin cambios -> preserva ---
OK preserva edicion

--- [4] archivo stale + sidecar distinto (seed cambio) -> re-siembra ---
OK re-sembro con el seed
sidecar restaurado=90104453273a61ddc95386e5be4072108fd74c60c9d1015f015c50068f395b1f

--- [5] symlink al store (migracion vieja) -> reemplazado por copia real ---
OK symlink reemplazado por archivo regular

--- [6] idempotencia: dos corridas no cambian nada ---
OK idempotente
```

- **Hash calculado en eval, no en runtime**: el `data` del activation contiene el
  hash literal (`new="9010…"`) y `sha256sum` del seed del store coincide
  exactamente con él. `builtins.hashString "sha256"` confirmado en
  `modules/desktop/caelestia.nix:622`.
- **Sin `sha256sum` en runtime**: `rg 'sha256sum'` sobre `modules/` `home/`
  `hosts/` `flake.nix` → sin coincidencias (el único `.sha256` es el sidecar de
  estado del usuario, no un comando).
- **Smoke test de carga de shell: NO obligatorio** — esta ola no toca QML (el
  plan lo declara explícitamente; el cambio es solo el activation). No ejecutado.

## 3. Disciplina ponytail

- Sin dependencias nuevas (`flake.lock` intacto); sin archivos nuevos; diff
  mínimo: +19/−10 en un único archivo, la mayoría reemplazo de comentarios.
- Reutiliza builtins (`builtins.toJSON` ya existente, `builtins.hashString`) y el
  patrón de activation ya presente en el módulo (`{ after; before; data; }`,
  forma correcta para módulo system-side, ya aceptada en olas 2/9).
- Refactor sin cambio de comportamiento: `pkgs.writeText … (builtins.toJSON
  shellConfig)` → `pkgs.writeText … shellJson` (mismo string, mismo store path).
- No se pidió ni se introdujo helper, servicio ni opción nueva. No toca
  `caelestiaCyberpunkScheme` (correcto).
- Sin `ponytail:` nuevos: no hay atajos con techo conocido en este cambio.

## 4. Seguridad

- `git diff 0658aa7..HEAD | grep -iE 'api.?key|secret|token|password|private key'`
  → sin coincidencias. Sin secretos ni archivos sensibles (`.env`, `.pem`,
  `id_rsa`) añadidos.
- Trust boundary evaluado: el activation escribe en `$HOME/.config/caelestia/`.
  Las entradas son (a) el seed desde el store (confiable, interpolado por Nix) y
  (b) el contenido del sidecar, usado **solo en comparación de igualdad**
  `[ "$old" != "$new" ]` — nunca ejecutado ni interpolado en shell. La ruta del
  store se interpola en un `cp`; los store paths de Nix no contienen metacaracteres
  de shell. Sin superficie nueva relevante.
- No se distribuye → release gate (`skills/security-audit`) **no aplica** (plan,
  "Stack & constraints"). Sin licencias nuevas.

## 5. Findings informativos (H)

- **H1 — worktree/rama de la ola sin retirar.** `git worktree list` muestra
  `~/workspaces/nixos-config-wave10-executor-1 [wave10-executor-1]` y
  `origin/wave10-executor-1` sigue en `ce926e2`. Patrón histórico de olas
  2/8/9. Operativo, no bloqueante (lo retira el integrador/humano).
- **H2 — `caelestia-restart.sh` no escribe el sidecar.** El helper self-heal
  (`hyprland-home.nix:654-657`) copia `shell.default.json` → `shell.json` pero no
  toca `.shell-seed.sha256`. **No es un bug**: el contenido copiado es idéntico al
  seed, así que en el siguiente `switch` o bien el hash coincide (preserva, mismo
  contenido) o bien no coincide y re-siembra el mismo contenido. Solo se documenta
  por si a futuro se quiere una única fuente de bookkeeping de la siembra.
- **H3 — Tradeoff aceptado y documentado.** Si V edita `shell.json` en Nexus y el
  seed del repo cambia, la edición se pisa sin aviso. Es exactamente la semántica
  pedida en el brief (reproducibilidad entre hosts); no es una excepción.
- **H4 — Validación en vivo en el `switch` real.** El efecto sobre el
  `shell.json` **vivo** de `pc`/`laptop` (el stale que motivó la ola) solo se ve
  al correr `sudo nixos-rebuild switch`, paso del humano. El auditor valida toda
  la lógica con `HOME` temporal (arriba), incluido el caso stale con hash
  distinto, que es justo lo que hará el activation real.

## 6. Veredicto

**APPROVED.** Integración limpia (un solo archivo del mapa, `flake.lock`
intacto), `nix flake check` + toplevel de `pc` pasan, el verify del brief pasa
sobre el árbol integrado y una verificación independiente más fuerte confirma las
tres semánticas (siembra, preservación, re-siembra al cambiar el seed), el hash
correcto calculado en eval y la ausencia de `sha256sum` en runtime. Los `H` son
informativos y operativos; ninguno bloquea el cierre del proyecto.

## Handoff (para el planner/V)

- Registrar en el decision log: ola 10 **APPROVED**.
- Pasar la fila del plan de la ola 10 de `planned` a `audited · APPROVED`, y
  actualizar el estado del proyecto (el gap de reproducibilidad entre hosts queda
  cerrado por código).
- Paso del humano: `sudo nixos-rebuild switch --flake .#pc` (y `.#laptop`); el
  switch debe re-sembrar el `shell.json` stale. Verificar que desaparece el WARN
  `Unknown option "bar.workspaces.workspaceIcons"` y `caelestia scheme get -n` →
  `cyberpunk`.
- Limpieza opcional: retirar el worktree/rama `wave10-executor-1` (H1).
