# `/goal` en pi: objetivo de sesión con auto-continuación acotada

Extensión propia (`assets/pi/extensions/goal.ts`) que agrega el `/goal` que opencode
anunció: objetivo persistente, continuación automática entre turnos y frenos duros.
Pi ya trae el primitivo (`agent_before_settle` puede devolver `continue: true`), así
que el trabajo real es decidir CUÁNDO continuar.

## Specs

S1. Existe un comando `/goal <objetivo>` que fija un objetivo para la sesión:
"en twitter las corpos presumían mucho del '/goal', hoy opencode lo ha anunciado en
su harness y me llama mucho la atención tenerlo".

S2. Continuación automática: al terminar un turno, el agente arranca el siguiente sin
que el humano escriba nada, mientras el objetivo siga activo.

S3. Presupuesto obligatorio: nunca gastar sin techo. Default 6 continuaciones,
`--budget N` entre 1 y 50.

S4. Se detiene si el humano escribe (`hasPendingMessages`), si el run fue abortado por
Escape o terminó con error, o si el runtime dice que no puede continuar.

S5. No loop de prosa: si el run **entero** no ejecutó ninguna herramienta, no continúa.
Un run de puro texto no produce progreso verificable. Ojo: el último turno de un run
normal nunca usa herramientas (es la respuesta de cierre), así que la señal se acumula
por run y se resetea en `agent_start`; medir solo el último turno daría "sin progreso"
siempre.

S6. El modelo puede rendirse explícitamente: si responde `GOAL BLOCKED: <razón>`, el
goal pasa a `blocked` con esa razón y no continúa más.

S7. El estado vive en la rama de la sesión (`pi.appendEntry`), no en memoria: sobrevive
`/reload` y navegación del árbol. Se relee del branch en cada decisión.

S8. Una sola fuente de verdad: la extensión se instala desde el flake
(`modules/apps/pi.nix`), no a mano por host.

S9. Debe haber un check runnable de la lógica de decisión: `node assets/pi/goal.check.mjs`.

S10. `nix flake check` pasa con el módulo modificado.

S11. Abortar un run no puede ser un solo `escape`: se remapea `app.interrupt` a
`ctrl+shift+c` / `alt+c` desde el flake (`assets/pi/keybindings.json`), y `escape` queda
solo para cancelar diálogos. Motivo del dueño: "opencode sabe que la tecla esc es
sencillo de equivocarse, entonces, para abortar te pide presionar dos veces la tecla
esc [...] aquí al primer esc de error ya me abortó todo".

S12. Verificación de integración real: en modo RPC, un `/goal ... --budget N` seguido de
un turno con herramientas produce exactamente N continuaciones y termina en `blocked`.

## Tasks

T1. Core puro (`decide`, `parseGoalArgs`, `detectBlocked`) + check runnable — commit
T2. Extensión (comando, persistencia, hook `agent_before_settle`) — commit
T3. Cableado en `modules/apps/pi.nix` + verificación RPC — commit
T4. Keybindings: `app.interrupt` fuera de `escape` — commit

## Log

L1. Texto del dueño (2026-10-30): "en twitter las corpos presumían mucho del '/goal',
hoy opencode lo ha anunciado en su harness y me llama mucho la atención tenerlo, aún
así es mejor pi? podemos integrarlo a pi con eso de que es extensible?"

L2. Elección del dueño ante las opciones ofrecidas: "Todo lo anterior, en ese orden"
(`/goal` → recorte del harness → experimento pi vs opencode).

L3. Reporte del dueño (2026-10-30): "no puedo confiar en que pi termine un trabajo sin
mi [...] aún con YOLO activado no deja de preguntar mil veces si apruebo lo que va a
hacer" y "aquí al primer esc de error ya me abortó todo". Diagnóstico propio
(medido): 0 entries de confirmación de permisos en las últimas 25 sesiones; el default
global ya es `yolo` (`~/.pi/gentle-ai/permission-mode.json`); en 40 sesiones hubo 42
`ask_user_*` (≈1 por sesión) y 393 llamadas `gentle_review`, que es donde aparecen las
ventanas de consentimiento.

L4. Hallazgos de implementación (medidos en RPC, no deducidos):
(a) `agent_before_settle` SÍ se dispara en un run normal, con `outcome=completed`.
(b) `event.context.canContinue` llega en `false` justo cuando el turno terminó normal
(último mensaje = assistant); NO es un permiso previo: la continuación la habilita el
`custom_message` que devuelve el hook. Usarlo como guarda bloquea el feature entero.
(c) `pi.appendEntry` dentro del boundary no es transaccional: el estado hay que
devolverlo en `entries` del resultado del hook.
(d) El último turno se cierra sin herramientas, así que el guard de progreso se mide
por run (`agent_start` resetea, `turn_end` acumula).
Evidencia final del test: 5 turnos, estados `active 0 → active 1 → active 2 → blocked 2`,
2 `custom_message` de continuación con `--budget 2`.

L5. Limite de slice: los commits 3b3e122 y 3d92270 suman 496 lineas autoradas
(>400) y cierran esta feature completa: el /goal y los keybindings son dos
capacidades independientes pero chicas, asi que se entregan juntas en la rama
feat/pi-goal-mode en vez de abrir encadenados por dos commits.
