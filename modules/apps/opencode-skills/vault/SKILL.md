---
name: vault
description: >
  Cómo usar el vault de Obsidian (~/Sync/Notes) como memoria de largo plazo:
  mapa de carpetas, recetas de búsqueda con rg, dónde y cómo escribir una
  decisión, y qué nunca tocar. Usala cuando falte contexto que no está en la
  conversación, cuando el usuario diga "lo que decidimos", "dónde lo anoté",
  "busca en mis notas", o antes de crear una nota nueva.
---

# El vault como memoria

No hay base de datos de memoria ni índice que mantener: el vault **es** la
memoria, y se consulta con `rg` cuando hace falta. Buscar es barato; leer el
vault entero no.

## Mapa

| Ruta | Qué hay |
|---|---|
| `Projects/<Ámbito>/` | Tablero dotpm: `<Ámbito>.md` (índice) + `_tasks/<slug>.md`. **Frontmatter y `## Tasks` son del plugin**: no editar a mano, usar el MCP `dotpm`. |
| `PC & AI/` | Infra y agentes. `Nix.md` = ritual de updates; `AI Agents.md` = decisiones de harnesses. |
| `Topics/<Categoría>/` | Conocimiento por tema (Linux, IA, multimedia, herramientas…). |
| `Academic/`, `Finances/`, `Calendar/`, `Goals/`, `Ideas/`, `Lifestyle/`, `Personal/`, `Latice/`, `Tourism/` | Áreas de vida. |
| `AGENTS.md` (raíz) | Reglas del vault (léelo si vas a escribir mucho). |

## Buscar: el "RAG" es rg

1. **Por tag** (frontmatter en lista): `rg -l '^\s+- nixos-config$' ~/Sync/Notes --glob '*.md'`
2. **Por tema**: `rg -l -i 'pipewire|audio' ~/Sync/Notes --glob '*.md'`
3. **Por wikilink**: `rg -l '\[\[Nix\]\]' ~/Sync/Notes`
4. **Por título de nota**: `fd -t f -i 'nix' ~/Sync/Notes`
5. Leé **solo** los archivos que matchean. Si son muchos, ordená por fecha
   (`ls -t`) y abrí los 2–3 más recientes.

Antes de preguntarle algo al usuario que ya podría estar escrito, buscá acá.
Antes de escribir, buscá también: si la nota existe, se edita, no se duplica.

## Escribir

- **Decisión nueva** → la nota del tema, con una sección fechada:

  ```markdown
  ## 2026-11-04 — <decisión en una línea>

  Por qué, qué se descartó y qué la revierte.
  ```

- **Tema sin nota** → crear en la carpeta correcta, con frontmatter de tags
  (`tags: [AI, linux, dev]`) y enlazar con `[[wikilinks]]` a la nota padre.
- **Idioma**: español, igual que el resto del vault.
- **Una decisión, un lugar.** Si ya está en `PC & AI/Nix.md`, no la repitas en
  `Topics/`; enlazala.

## Nunca tocar

`.obsidian/` (incluye `copilot-index-*.json`), `.smart-env/`, `LocalLlmHub/`,
`copilot/`, `Calendar/`, `Assets/` binarios, y el frontmatter gestionado de
`Projects/`. Son bases de plugins: editarlas corrompe y Syncthing replica el
daño a todos los dispositivos.

## Reparto de fuentes

- **Intención y prioridad** → dotpm (`Projects/`).
- **Decisiones y conocimiento durable** → el vault (esta skill).
- **Qué pasó y por qué** → `session-search` (sesiones pasadas) o `git log`.
- El repo siempre gana sobre la nota cuando hay conflicto: verificá el commit.
