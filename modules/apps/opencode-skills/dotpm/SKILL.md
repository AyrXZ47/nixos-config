---
name: dotpm
description: >
  Procedimiento para leer, crear, actualizar y cerrar tareas en dotpm, el
  tablero central del vault de Obsidian. Usala al arrancar o cerrar una
  sesión de trabajo, al incorporar un repo al flujo, al sincronizar un repo
  con el tablero, al hacer la revisión semanal, o cuando haya que decidir
  qué sigue. También cuando el usuario diga "dotpm", "tablero", "backlog",
  "qué sigue" o "cierra la tarea".
---

# dotpm — tablero central de trabajo

dotpm es la fuente de **intención y prioridad**. El repo y los commits son
la fuente del **estado real**. Nunca cierres una tarea sin evidencia en el
repo; nunca dejes una tarea abierta si el commit ya la cerró.

## Cuándo usarla

- Arranca una sesión de trabajo en cualquier repo.
- Piden crear, mover, priorizar o cerrar una tarea.
- Hay que incorporar un repo nuevo al flujo.
- Hay que sincronizar el tablero con el estado real del repo.
- Revisión semanal o decisión de "qué sigue".

## Reglas duras

1. Un solo backlog: el vault `~/Sync/Notes/Projects`. No `TODO.md` en repos.
2. Todo lo de código va al proyecto `💻 Dev`, salvo que exista un proyecto
   dedicado (ej. `🚀 DST` para la tesis); materias/clientes/áreas ya tienen su
   proyecto.
3. Título `Ámbito: Tarea` con un solo `: `. Ámbito = repo, materia o cliente.
4. Tag = slug del ámbito en kebab-case. Sin sub-ámbito no hay tag.
5. Antes de crear: `get_project` + `list_tasks`/`search_tasks` para no
   duplicar. Leé el proyecto para conocer los ids de estado y prioridad.
6. Antes de escribir una tarea: leé el repo (código, docs, git log).
7. Toda tarea lleva descripción con contexto, evidencia y criterio de cierre.
8. `in-progress` máximo 1–2 por proyecto. El resto es `todo`.
9. La tarea se cierra en el mismo turno que el commit que la cierra.
10. No edites a mano el frontmatter `pm-task`/`pm-project`, `id`,
    `taskIds`, `subtaskIds` ni `## Tasks`. Usá el MCP o el comando `dotpm`.
11. Un solo escritor por proyecto a la vez. Si otra sesión está escribiendo,
    leé y proponé; no compitas por el mismo archivo.
12. Si el tablero no responde, no inventes un backlog paralelo.
13. Los `odd/tasks/*.md`, `docs/ROADMAP.md` y documentos de diseño son
    **contexto y especificación**, no el backlog. El estado vivo (qué falta,
    qué está en progreso) va en dotpm. Si el doc y el tablero discrepan,
    mandan el repo y dotpm.

## Proyectos conocidos (2026-10-31)

- `💻 Dev` — `wy3tldvjmqq4s6sf`: todo lo de código (PIGNUS, Crescit, NixOS…).
- `🚀 DST` — `xx946xuqmq4bmtsi`: tesis de ignición.
- `🏛️ Academic` — `2259bxr2mq4bc2n3`: materias.
- `🧑‍💻 Work` — `bcom4fscmq4bf5xv`: trabajos y clientes.
- `🧑‍🚀 Personal` — `hams63y0mq4alwdz`.
- `📸 Social Media` — `1gj3jigumqq70bx7`.
- `🥇 Goals` — `zdeveho9mq4atcfp`.

Si un id no coincide, `list_projects` es la verdad. No hardcodees ids en
las notas de tarea.

## Arranque de sesión (checklist)

1. Identificá el ámbito (repo/materia/cliente).
2. `get_project` del proyecto que corresponda.
3. `search_tasks` por el nombre del ámbito y por el tema que te pidieron.
4. Leé las tareas `in-progress`, `review` y `blocked` del ámbito.
5. Mirá `git status`, `git log -10` y el `AGENTS.md` del repo.
6. Decidí: continuar una tarea existente, crear una nueva o cerrar una.
   No empieces código sin tarea.

## Crear una tarea

Usá `create_task` con:

- `projectId`: el proyecto que corresponda (`💻 Dev` para código general,
  `🚀 DST` para la tesis, etc.).
- `title`: `Ámbito: Tarea`.
- `description`:
  ```
  Contexto: qué problema resuelve y por qué ahora.
  Evidencia: archivo/línea/commit/doc que lo respalda.
  Criterio de cierre: qué tiene que existir para marcarla done.
  ```
- `status`: `todo` por defecto; `in-progress` solo si ya empezó.
- `priority`: `critical` si bloquea producción/dinero/seguridad/legal;
  `high` si es pedido explícito o deuda peligrosa; `medium` si es producto;
  `low` si es limpieza o futuro.
- `tags`: `[slug-del-ámbito]`.
- `start`: fecha de hoy (YYYY-MM-DD). `due` solo si hay fecha real.

## Cerrar una tarea

1. Verificá la evidencia: commit, archivo, endpoint, test o documento.
2. Actualizá `description` con el resultado y la evidencia.
3. `update_task` a `done` y `progress: 100`.
4. Si el commit aún no existe, no la cierres: dejá `review` o `in-progress`.
5. Si el trabajo era más grande, creá las tareas hijas o nuevas antes de
   cerrar la padre.

## Incorporar un repo nuevo

Checklist:

- [ ] Leer `AGENTS.md`, `README.md`, `docs/**`, `TODO*`, `ROADMAP*`.
- [ ] `git status`, `git branch -a`, `git log` de los últimos 2–3 meses.
- [ ] Identificar stack, build/test y si se pueden correr sin secretos.
- [ ] Correr los checks posibles (o reportar por qué no).
- [ ] Separar: hecho, en progreso, pendiente, bloqueado, nuevo.
- [ ] Crear tareas `done` con evidencia (no solo “ya está”).
- [ ] Crear tareas `in-progress` solo para trabajo realmente empezado.
- [ ] Crear el backlog `todo` con prioridades.
- [ ] Migrar el `TODO.md`/roadmap local; después borrarlo o dejarlo como
      puntero a dotpm.
- [ ] Actualizar el `AGENTS.md` del repo: “el backlog vive en dotpm
      (💻 Dev o el proyecto dedicado, títulos `Ámbito: ...`); no crear
      TODO.md”.
- [ ] Si el repo tiene documentación desactualizada, crear una tarea para
      corregirla, no corregirla en silencio dentro de la importación.

## Revisión semanal (15 min)

1. `list_tasks` del proyecto; mirar `in-progress`, `review` y `blocked`.
2. Cerrar lo que ya tiene evidencia; mover a `todo` lo que se abandonó.
3. Elegir 3–5 tareas para la semana y priorizarlas.
4. Archivar `done` viejas si el proyecto se ve ruidoso.
5. Crear una tarea para cualquier trabajo nuevo que haya aparecido.
6. No reescribir el pasado: el progreso narrativo va fechado.

## Errores típicos

- **Drift**: tablero dice `todo`, el commit ya lo hizo. Solución: leer el
  repo antes de escribir y cerrar con evidencia.
- **Inflación**: 60 tareas para un repo. Solución: 15–25 tareas
  significativas; el resto se crea cuando se empieza.
- **Duplicados**: la misma tarea con dos títulos. Solución: `search_tasks`
  antes de crear.
- **Tablero paralelo**: un `TODO.md` “por si acaso”. Solución: migrarlo y
  dejar un puntero.
- **Dos escritores**: dos sesiones actualizan el mismo proyecto. Solución:
  un escritor por proyecto; la otra sesión propone.

## Comandos de referencia

MCP preferido: `get_project`, `list_tasks`, `search_tasks`, `create_task`,
`update_task`, `move_task`, `archive_task`.

CLI de respaldo: `dotpm projects`, `dotpm project <id> --tasks`,
`dotpm search`, `dotpm create`, `dotpm update`.

Si el MCP y el CLI no coinciden, manda el MCP; el CLI es para cuando el
agente no tiene el servidor disponible.
