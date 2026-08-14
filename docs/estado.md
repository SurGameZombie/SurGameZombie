# Estado

Foto del proyecto y tabla de ruteo. **No manda nada:** lo normativo vive en `CLAUDE.md`, en
`.claude/rules/` y en los ADRs. Acá se contesta "¿cómo está esto?" y "¿dónde va este dato?",
que hasta ahora no las contestaba ningún archivo.

## Dónde va cada cosa

Una fila por destino. Las filas **apuntan**, no copian: cada copia nueva es un par sin
comparador (`inventario-pares.md`).

| Destino | Qué tipo de hecho va ahí |
|---|---|
| `CLAUDE.md` | Comandos, árbol de carpetas y reglas de código. Lo que hace falta en toda sesión, sin importar qué archivo se toque |
| `.claude/rules/commits.md` | Mecánica del commit y de los cinco trailers. Es la versión que gobierna |
| `.claude/rules/gdscript.md` | Sintaxis y pitfalls de GDScript 4.7. Carga sola al tocar cualquier `.gd` |
| `.claude/rules/herramientas.md` | Procedimiento antes de sumar un MCP, skill, plugin, connector o hook |
| `.claude/rules/limites.md` | Qué no se puede verificar desde acá, qué no se adivina, qué decide Mathi |
| `.claude/rules/netcode.md` | La restricción de autoridad al escribir código. Carga al tocar `scripts/<sistema>/` o `scenes/` |
| `docs/plan.md` | Stack, milestones en prosa, y cómo se reparten las instrucciones entre `CLAUDE.md`, rules, skills y hooks |
| `docs/design.md` | Qué es el juego: decisión de diseño con su porqué, números decididos, huecos abiertos |
| `docs/netcode.md` | Regla de red con su porqué, los tres patrones con código, qué entra al save |
| `docs/bitacora.md` | Narrativa y mutable: estado, bug que costó más de 30 min, pendientes, registro cronológico |
| `docs/proceso.md` | El porqué de los commits, de las ADRs y del orden para diagnosticar |
| `docs/investigacion-claude-code.md` | Dato externo medido sobre IA en gamedev. No lleva decisiones del proyecto |
| `docs/retrospectiva-v0.2.md` | Autoanálisis del 5/8/2026. **Congelado:** no se actualiza, se cita |
| `docs/decisions/` | Decisión arquitectónica que alguien puede cuestionar en dos meses. Inmutable, una ADR por decisión |
| `.claude/skills/barrido-navmesh/` | Procedimiento largo que se corre a veces. Solo carga al invocarlo |
| `docs/estado.md` | Este archivo: la foto fechada y esta tabla |
| `docs/reestructuracion/` | **Temporal.** Documentos de trabajo; se absorben o se borran |

Dos destinos que no son archivos de prosa: **lo que quedó sin verificar** va en el trailer
`Not-tested:` del commit, y **un dato que tiene que decir lo mismo en dos archivos** va como
caso nuevo en `tests/consistencia_test.gd`.

---

## 1. Qué es SurGameZombie

Survival co-op en primera persona para 2-4 jugadores: un tipo de zombie, recursos escasos,
combate torpe y peligroso. Godot 4.7.1-stable con GDScript tipado. Proyecto hobby de dos
personas que saben programar pero es su primer videojuego. Sin fecha de entrega: la
prioridad es entender lo que se construye, no llegar rápido.

## 2. Frescura

Esta versión: **14/8/2026**, sobre el commit **`06a102c`** (el que la agrega es el
siguiente). Para saber si envejeció: `git log -1 --format='%h %ad' --date=short`.

**Si algo de acá contradice al código, manda el código: este archivo está viejo.**

Lo que revalida la foto, con la ruta definida una vez por sesión (`CLAUDE.md` § Comandos):

```powershell
$godot = "C:\Godot\Godot_v4.7.1-stable_win64.exe"
& $godot --headless --path . --import                    # §4: importa sin errores
& $godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd `
    --ignoreHeadlessMode -a res://tests                   # §6: la suite
& $godot --headless --path . -s res://tools/bake_navmesh.gd   # §6: rehornea el NavMesh
```

Después del horneado va el skill `barrido-navmesh`: el bake solo no dice si quedaron vanos
sin NavMesh (ADR-0008).

## 3. Mapa del repo

El árbol completo está en `CLAUDE.md`. Acá solo lo que no se deduce del nombre:

- **`tools/` no es parte del juego.** Hoy tiene un archivo, `bake_navmesh.gd`: se corre con
  `-s`, hornea `yard.tscn` hacia `yard_navmesh.tres` y **sale con código 1** si algo falló,
  para poder colgarlo de un hook algún día.
- **`para-mathi/` está gitignoreado** (`.gitignore:36`) y no existe en este clon: es
  material de la máquina de cada uno. Entró el 12/8/2026 (`2461fbf`) porque hasta entonces
  la exclusión vivía solo en un archivo local, así que en cualquier clon nuevo un `git add`
  amplio se la llevaba.
- **`reports/` también está ignorado:** lo escribe el runner de gdUnit4 en cada corrida y
  crece sin límite. **`addons/` no se edita:** es todo de terceros.
- **`.claude/rules/`:** `commits.md`, `herramientas.md` y `limites.md` no declaran `paths:`,
  así que cargan siempre; `gdscript.md` (`**/*.gd`) y `netcode.md` (`scripts/<sistema>/**` y
  `scenes/**`) solo al tocar un archivo que machea.

## 4. Estructura del juego

**Escenas:** `main/lobby.tscn` (es la `main_scene`), `main/world.tscn`, `main/yard.tscn` con
su `yard_navmesh.tres` horneado, `player/player.tscn`, `enemies/zombie.tscn`,
`items/storage_container.tscn`.

**Milestone activo: v0.3, "Se lootea".** v0.2 quedó cerrada el 6/8/2026 con el playtest de
quince minutos, no solo con los tests en verde.

**Implementado:** red ENet con lobby de host y join por IP · character controller en primera
persona · greybox de 60×60 con NavMesh · zombie que persigue y muerde · vida, daño, caído,
revivir y respawn resueltos en el host · inventario por peso, replicado por deltas · sacar y
poner en contenedores · equipar la mochila · los 10 items como `.tres` sueltos · panel de
inventario y overlay de debug, los dos greybox.

**De v0.3 falta** pickup y drop desde el piso, y la bolsa de muerte: los únicos RPC de
inventario son `request_take_from_container`, `request_put_in_container` y
`request_equip_backpack` (`grep -n "^func request_" scripts/inventory/inventory_requests.gd`).
En el mapa hay **un** contenedor, `shelf_warehouse_01`.

## 5. Convenciones, en una pantalla

**El modelo de autoridad de red, resumido.** Listen server: uno hostea y juega en el mismo
proceso. Cada jugador es autoridad de *dónde está su propio cuerpo* y el
`MultiplayerSynchronizer` replica eso hacia afuera; el host es autoridad de **todo lo
demás**, incluida toda consecuencia de esa posición —si el disparo impacta, si el zombie lo
alcanza, si llegó a agarrar el item—. El cliente pide por RPC y el host decide. Los dos
checks, `is_multiplayer_authority()` y `multiplayer.is_server()`, no son intercambiables.
El porqué de la excepción del movimiento, la tabla estado→autoridad y los tres patrones con
código están en `docs/netcode.md`.

**El resto, con la versión completa en `CLAUDE.md`:** static typing obligatorio · código en
inglés y prosa en español · archivos y variables `snake_case`, clases y nodos `PascalCase` ·
un script por escena, mismo nombre · señales o `@export`, nunca `get_node("../../..")` ·
movimiento por `physical_keycode` y atajos de UI por `keycode` · items, zombies y loot como
`.tres`. La mecánica del commit, en `.claude/rules/commits.md`.

## 6. Qué está protegido por verificación automática y qué no

**Esta sección se genera, no se escribe a mano.** Regenerarla:

```bash
git log --grep="^Not-tested:" --format='%h %ad %s' --date=short      # abrió deuda
git log --grep="^Tested-later:" --format=%B | grep '^Tested-later:'  # la pagó, y cuánto
```

La deuda abierta son los hashes del primero que no aparecen citados en el segundo, **más**
los citados cuyo propio trailer declara que el pago fue parcial. El `^` no es decorativo:
sin él, `git log --grep="Not-tested"` devuelve **55** en vez de 52, porque machea tres
commits que nombran el trailer en la prosa sin llevarlo.

Hoy hay **52 commits con `Not-tested:` real** sobre 81 totales y **2 con `Tested-later:`**:
`a2b806b` → `7a4cbdd` y `cb6fd7c` → `2d417f5`. La resta mecánica daría **50 abiertos**, pero
los dos pagos dicen en su propio texto que cubren una parte: **la deuda de verdad son 52**.

**La suite de gdUnit4 pasa entera**, corrida el 14/8/2026 con el comando de §2: 6 de 6
suites, **49 de 49 casos**, 0 errores, 0 fallas, 0 flaky, 0 huérfanos, exit 0. Cubre
matemática del inventario, las reglas con las que el host acepta o rechaza un pedido,
autoridad del inventario, catálogo de items y cuatro pares de datos duplicados. **No cubre
red con dos peers reales ni nada de gameplay:** mide corrección, no diversión.

**El NavMesh está horneado y al día:** `yard_navmesh.tres` es posterior a `yard.tscn` (20:18
contra 20:13 del 6/8/2026, `ls -l --time-style=long-iso scenes/main/`) y los dos viajan en
`50d33d0`. **La conectividad no tiene registro mecánico:** la produce el skill
`barrido-navmesh` y queda en la conversación, no en un archivo.

## 7. Decisiones cerradas

Índice, no argumento. El porqué está en la fuente.

| Decisión | Fecha | Fuente |
|---|---|---|
| Godot 4.7 como engine, no Unreal ni Unity | 1/8/2026 | ADR-0001 |
| GDScript con static typing obligatorio, no C# | 1/8/2026 | ADR-0002 |
| La autoridad de red se parte en dos | 1/8/2026 | ADR-0003 |
| El transporte se elige por etapa: ENet → noray → Steam | 1/8/2026 | ADR-0004 |
| Character controller propio; es decisión de aprendizaje | 1/8/2026 | ADR-0005 |
| `hi-godot/godot-ai` como MCP del editor | 1/8/2026 | ADR-0006 |
| La autoridad no se reasigna en runtime, ni con el caído | 2/8/2026 | ADR-0007 |
| NavMesh con `cell_size` 0,10; un cuerpo caído tapa la puerta | 5/8/2026 | ADR-0008 |
| Que un cuerpo tape la puerta es mecánica, no bug | 5/8/2026 | `design.md` → Huecos |
| Revivir no tiene límite; la regla se implementa en v0.4 | 6/8/2026 | `design.md` → Huecos |
| Al zombie recién se lo puede matar en v0.5 | 6/8/2026 | `design.md` → Huecos |
| `project_manage` e `input_map_manage` fuera del allowlist | 11/8/2026 | §8 |
| `ask` sobre `git commit` y `git push`, en el settings que viaja | 13/8/2026 | `.claude/settings.json` |

## 8. Herramientas y configuración

**`godot-ai` 3.1.2**: MCP contra el editor en vivo, 43 tools, y solo las publica si hay un
editor abierto. **3 están preaprobadas y las tres solo leen** —`editor_state`, `api_manage`,
`session_manage`—; las otras 40 piden confirmación en cada uso. **Context7**: MCP de
documentación, remoto, ataca el version drift que declarar la versión de Godot no cubre.
**gdUnit4 v6.2.0**: la suite headless; su inspector adentro del editor no está prendido. **El
catálogo** de herramientas ya evaluadas vive en `C:\ClaudeMCPsPlugingsSkillsETC`, montado por
`additionalDirectories`, de solo lectura salvo `proyectos/surgamezombie/`.

**Qué viaja y qué no, y por qué.** El corte no es de importancia: es de **rutas absolutas de
máquina**, que en el otro clon apuntan a un home que no existe.

| Viaja con el repo | Se queda en la máquina |
|---|---|
| `.mcp.json` — Context7, que es una URL | El bloque de este proyecto en `~/.claude.json`: godot-ai se lanza por `~/.local/bin/uvx.exe` |
| `.claude/settings.json` — los 2 hooks, los 15 `deny` del catálogo, los 4 `ask` de git | `.claude/settings.local.json` — permisos, con el home de cada uno adentro |
| `CLAUDE.md`, las 5 rules, el skill, `docs/`, `tests/`, `tools/` | `~/.claude/CLAUDE.md`, la skill `catalogo-claude` y la memoria del proyecto |

**Las cuatro reglas `ask` de `git commit` y `git push` están puestas y no se las vio
disparar.** Están en `.claude/settings.json`, que viaja, y la intención era que cualquier
clon nuevo arrancara con el prompt puesto. Medido el 14/8/2026, primera sesión nueva desde
que se escribieron: un `git commit` por Bash y otro por PowerShell pasaron **los dos sin
pedir confirmación**. Causa sin determinar. El sospechoso es `permissions.defaultMode:
"auto"` en `~/.claude/settings.json` —que no viaja, y con el que en esta sesión no prompteó
**ningún** comando, ni los que no machean ninguna regla `allow`—, pero no está confirmado:
no se puede cambiar el modo desde adentro de la sesión que se está midiendo. Detalle en
`bitacora.md` → Problemas.

Lo que sigue copiado a mano en varios lugares es la ruta
`C:\Godot\Godot_v4.7.1-stable_win64.exe` (par D4 de `inventario-pares.md`); poner Godot en
el PATH lo cierra.

## 9. Lo que existe pero no está activo

- **Código comentado no hay.** Buscado sobre `scripts/ tools/ tests/`: los cuatro hits son
  prosa, ninguno es una línea desactivada.
- **Carpetas con solo `.gitkeep`:** `scripts/combat/` y `scripts/survival/`, que se llenan
  en v0.5 y v0.4; `assets/models/`, `assets/textures/` y `assets/audio/`, en v0.6.
- **9 de los 10 items son inertes a propósito.** Solo la mochila hace algo hoy; el resto
  espera a que exista la mecánica que lo usa (`design.md`).
- **Andamios de debug**, que se van cuando entre el HUD: `request_damage()` de `world.gd`,
  `debug_overlay.gd`, y las cuatro acciones `debug_*` del input map.
- **El inspector de tests de gdUnit4 adentro del editor no está habilitado:**
  `project.godot` → `[editor_plugins] enabled` lista solo `godot_ai`. El runner de línea de
  comandos no lo necesita.
- **`McpTestSuite`**, que trae godot-ai, existe y no lo usa nadie. Es la razón de que las
  suites vayan `*_test.gd` y nunca `test_*.gd`: descubre por el prefijo contrario.
