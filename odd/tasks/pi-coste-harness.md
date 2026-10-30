# Coste real del harness de pi: medido, no estimado

Medición del contexto que se paga antes de leer un archivo, con el comando
`pi -p --no-session --mode json "hi"` y leyendo `usage.input` del primer mensaje.
Variando flags (`-nc`, `-ns`, `-xt <tools>`) se aísla cada componente.

## Specs

S1. Reportar el coste medido, no estimado: "siento que pi o mejor dicho, gentle-ai
gasta una cantidad de tokens impresionante, si quisiera trabajar con AI local, los
modelos definitivamente se ahogarían por puro contexto del harness".

S2. Comparar contra opencode con el mismo modelo y el mismo repositorio, usando sus
propias sesiones (fuente: `~/.local/share/opencode/opencode.db`, tabla `message`).

S3. No aplicar un recorte que cueste capacidad sin decirlo: cada palanca se reporta con
su precio funcional.

## Números (repo nixos-config, turno 1, sin leer nada)

| Configuración | tokens de arranque |
|---|---|
| pi con la config actual (6 paquetes, 21 skills) | **31.851** |
| pi + skills apagadas (`-ns`) | 29.545 |
| pi + tools `orchestrator_*` fuera | 30.008 |
| pi + tools web fuera (`web_search`, `source_check`, `fetch_content`, `get_search_content`) | 30.371 |
| pi + `codegraph` fuera | 31.572 |
| pi sin AGENTS.md (`-nc`) | 28.445 |
| pi sin tools `mem_*` (15 tools de engram) | 28.207 |
| pi sin tools `gentle_*` (review/RDD) | 27.201 |
| pi sin extensiones ni paquetes (`-ne`) | 24.365 |
| pi sin extensions y sin tools (`-ne -nt`) | 1.449 |
| pi sin extensions, tools, skills ni contexto | **528** |

Comparación con opencode v2 (mismo repo, mismo modelo `deepseek-v4.1-flash`, 34
sesiones propias): **17.711 de mediana** en el primer turno (min 17.711, max 19.286).

## Conclusiones

C1. pi pelado cuesta 528–1.449 tokens: el 4.5% del total. **El coste es del harness que
le colgamos, no de pi.**

C2. Ninguna palanca individual llega a 10k. El recorte sin pérdida funcional es de
~2,3k (skills) y el resto exige apagar capacidades concretas: memoria (−3,6k),
review/RDD (−4,6k), coordinación entre sesiones (−1,8k), búsqueda web (−1,5k). Un
recorte de 10k equivale a **dejar de ser gentle-ai**, así que no se aplica.

C3. `skills` en `settings.json` con exclusiones `!**/name/**` **no afecta** a las skills
de paquetes (medido: 31.851 → 31.851, 21 skills). Para recortar skills hay que usar
`pi config` (TUI) o desinstalar el paquete.

C4. Con modelo local: con 31,8k de base, un modelo de 32k no arranca y en 128k se
consume el 25% de la ventana antes de trabajar. El harness de gentle-ai asume ventana
grande y caché barata; es incompatible con modelos locales chicos por diseño, no por
configuración.

C5. Sobre YOLO y las preguntas: no hay ninguna confirmación de permisos registrada en
las últimas 25 sesiones y el default global ya es `yolo`. La fricción que reporta el
dueño no viene del guard de permisos.

## Log

L1. Pedido del dueño (2026-10-30): "siento que pi o mejor dicho, gentle-ai gasta una
cantidad de tokens impresionante, si quisiera trabajar con AI local, los modelos
definitivamente se ahogarían por puro contexto del harness".

L2. Segunda unidad elegida por el dueño: recorte del harness y después el experimento
pi vs opencode ("Todo lo anterior, en ese orden").

L3. Resultado: se midió todo, no se aplicó recorte porque ninguna palanca ahorra >2,3k
sin apagar memoria o review. Se documenta el precio de cada una en vez de vender un
ahorro que no existe.
