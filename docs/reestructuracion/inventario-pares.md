# Inventario de pares de datos duplicados sin comparador

> **Documento de trabajo de la reestructuración en curso. No es documentación final del
> proyecto. Se absorbe en `ESTADO.md` y `PLAN.md` cuando lleguen esas partes, o se borra si
> deja de hacer falta.**

Salió del barrido completo de los 109 archivos versionados fuera de `addons/`, el
10/8/2026. Quedan **53 pares abiertos**: 50 que encontró el barrido y 3 que ya estaban
identificados antes (A20, A21, A22), incluidos acá para que la familia esté completa. Los
que la Parte 1 cerró están listados al final para que nadie los vuelva a reportar.

## Qué es un par sin comparador

Un hecho —un número, un nombre, una ruta— que **tiene que decir lo mismo en dos o más
lugares del repo y hoy nada verifica**. No es duplicación de texto: es duplicación de
*verdad*. El costo no se paga al escribirlo, se paga el día que uno de los lados cambia y
el otro no, y el síntoma aparece lejos de la causa.

Cuatro de estos ya rompieron algo en este proyecto. Están marcados.

## Cómo leer las tablas

| Marca | Qué significa |
|---|---|
| **(A)** | Accidental. Nadie decidió duplicarlo; pasó |
| **(D)** | Duplicación deliberada, pero sin nada que la verifique |
| 💥 | Ya causó un bug o un falso verde en este repo |
| 🔒 | Comparable automáticamente con el molde de `tests/consistencia_test.gd` |

---

## A. Números de gameplay: `docs/design.md` ↔ código y escenas

**Es el patrón dominante y es sistemático.** La tabla "Escala y números base" de
`design.md` tiene 25 filas; 18 de ellas siguen teniendo una segunda copia ejecutable que
nadie compara. En la práctica `design.md` funciona como un segundo binario del juego que
no se ejecuta nunca.

| # | Dato | Lado A | Lado B | |
|---|---|---|---|---|
| A1 | Altura del jugador **1.8 m** | `design.md` tabla | `player.tscn` ×3 · `zombie.tscn` ×3 · `yard_navmesh.tres:agent_height` | (A) 🔒 |
| A2 | Radio de cápsula **0.4 m** | `design.md` tabla | `player.tscn` ×3 · `zombie.tscn` ×2 | (A) 💥 🔒 — *parcial: la Parte 1 compara los radios entre sí dentro de cada escena, pero nadie los compara contra `design.md`* |
| A3 | Altura de cámara **1.65 m** | `design.md` tabla | `player.tscn:Camera3D` y `player.tscn:FrontMarker` | (A) 🔒 — `player.gd:77` lee la cámara de la escena, que es lo correcto; el FrontMarker copia el número a mano |
| A4 | Caminata **4 m/s** | `design.md` tabla | `player.gd` `walk_speed` | (D) 🔒 |
| A5 | Corrida **7 m/s** | `design.md` tabla | `player.gd` `sprint_speed` | (D) 🔒 |
| A6 | Zombie **3.7 m/s** | `design.md` tabla + sección propia | `zombie.gd` `move_speed` | (D) 🔒 |
| A7 | **Techo duro 4.0 m/s** | prosa de `design.md`, `zombie.gd`, `bitacora.md` | invariante `zombie.move_speed < player.walk_speed` | (A) 🔒 — es una **regla de diseño escrita solo en prosa**: "un zombie solo nunca alcanza a alguien que se mueve". Nada falla si alguien sube uno de los dos |
| A8 | Control en el aire **0.25** | `design.md` tabla + sección | `player.gd` `air_control` | (D) 🔒 |
| A9 | Caído **60 s** | `design.md` tabla | `player_stats.gd` `downed_duration` | (D) 🔒 |
| A10 | Rango de revivir **2 m** | `design.md` tabla | `world.gd` `REVIVE_RANGE` | (D) 🔒 |
| A11 | Mantener tecla **10 s** | `design.md` tabla + prosa | `world.gd` `REVIVE_DURATION` | (D) 🔒 |
| A13 | Greybox **60 × 60 m** | `design.md` tabla + "Ambientación" | `yard.tscn:Floor` `size` | (A) 🔒 |
| A14 | Puerta industrial **2.0 m** | `design.md` tabla | `yard.tscn` `Warehouse*Lintel` ×2 | (A) 🔒 |
| A15 | Puerta interior **1.4 m** | `design.md` tabla + nota de dimensionado | `yard.tscn` `OfficeDoor*Lintel` ×4 | (A) 💥 🔒 — el bug de tres semanas de ADR-0008 vivió acá |
| A16 | Contenedor **2.4 × 6 × 2.6 m** | `design.md` tabla | `yard.tscn` `Container1..7` | (A) 🔒 |
| A17 | Alto de nave **6 m** | `design.md` tabla | `yard.tscn` `Warehouse*` ×9 | (A) 🔒 |
| A18 | Alto de oficina y muro **3 m** | `design.md` tabla | `yard.tscn` `Office*` + `Perimeter*` ×12 | (A) 🔒 |
| A19 | **2-4 jugadores** | `design.md` "Qué es" | `network_manager.gd` `MAX_CLIENTS=3` · `world.tscn` `spawn_limit=4` · `world.gd` `/ 4.0` | (A) 🔒 — cuatro copias del mismo "4", cada una con otra forma |
| A20 | Capacidad **25 / 40 kg** | `design.md` tabla + "Slots de equipo" | `inventory.gd` `base_capacity` / `backpack_capacity` | (D) 🔒 — *ya estaba identificado antes de este inventario* |
| A21 | `cell_size` **0.10 m** | `design.md` tabla | `yard_navmesh.tres` · `project.godot` `default_cell_size` | (D) 💥 🔒 — *ya identificado.* El hermano `cell_height` rompió de verdad en `9f0d06d` |
| A22 | **`DOWNED_CAMERA_HEIGHT` 0.3** | `plan.md` v0.5 (ancla antropométrica) | `player.gd` | (D) — *ya identificado* |

*(A12 —la vida "30 de 100"— pasó a la Parte 1. A20, A21 y A22 estaban en la lista previa
al inventario y se dejan acá para que la familia esté completa.)*

---

## B. Duplicaciones internas del código

| # | Par | Dónde | |
|---|---|---|---|
| B1 | **`HOST_PEER_ID = 1`** | Declarado 4 veces (`player_stats.gd`, `zombie.gd`, `inventory.gd`, `inventory_sync.gd`) + `HOST_ID` en un test + **literal `1` en 11 `rpc_id(1)`** | (A) — el número más repetido del proyecto. El mismo archivo usa la constante y sus vecinos el literal |
| B2 | **`capacity` arranca en 25.0 dos veces** | `inventory.gd` `base_capacity = 25.0` y `var capacity: float = 25.0` | (A) — es el bug de `53fba21` (`health` vs `max_health`) repetido en otro archivo. Hoy no muerde porque `_ready()` llama `reset_capacity()` |
| B3 | **Grupo `"players"`** | `player.gd` ×2, `zombie.gd` ×1, sin constante | (A) — `StorageContainer.GROUP` lo hace bien y su propio comentario cita a `player.gd`. Se copió el patrón sin copiar la constante |
| B4 | **`"backpack"`** | `inventory_requests.gd` `BACKPACK_ID` · `inventory_panel.gd` **literal** · `backpack.tres:id` | (A) — `inventory_panel.gd` tiene 4 líneas de comentario explicando por qué reusa `CONTAINER_RANGE`, y 57 líneas abajo escribe `"backpack"` a mano |
| B5 | **`"crowbar"`** | `debug_overlay.gd` ×3 · `crowbar.tres:id` | (D) — es andamio, pero F4 se rompe en silencio si el id cambia |
| B6 | **Nombres de nodo por string** | `"Stats"` ×11 · `"Inventory"` ×5 · `"InventorySync"` ×3 · `"NavigationAgent3D"` ×1, contra `player.tscn` y `storage_container.tscn` | (A) — renombrar el nodo `Stats` rompe 11 sitios sin un error de parseo |
| B7 | **Offset `y = 0.9`** = altura ÷ 2 | `player.tscn` ×2 · `zombie.tscn` ×2 | (A) — derivado de A1 |
| B8 | **`attack_range 1.5` ↔ `target_desired_distance 1.0` ↔ radios 0.4 + 0.4** | `zombie.gd` · `zombie.tscn` · las dos cápsulas | (A) — es B8 de la retrospectiva, que pidió "anotarlo en las dos escenas mientras tanto". **No se anotó.** Sigue a 0,2 m de romperse en silencio |
| B9 | **`CONTAINER_RANGE 2.5` derivado de `REVIVE_RANGE 2.0`** | `inventory_requests.gd` explica la relación en prosa y copia el 2.0 | (D) — si `REVIVE_RANGE` cambia, el comentario miente |
| B10 | **"diez mordidas / ~13,5 s"** = 100 ÷ 10 × 1.5 | `zombie.gd` · `bitacora.md` · retrospectiva §1.E3 | (A) — 3 copias en prosa de un cálculo sobre 3 constantes de 2 archivos |
| B11 | **El NavMesh queda a `y = 0.3` del piso** | `world.gd` (justifica `MAX_RESPAWN_SNAP`) · `netcode.md` ×2 · `bitacora.md` | (A) — 3 copias en prosa de un número que **nadie escribió**: es una salida del horneado. Rehornear con otro `cell_height` lo cambia y las tres quedan mintiendo. `_respawn_point()` depende de él |
| B12 | **`0.3` con dos significados sin relación** | `player.gd` `DOWNED_CAMERA_HEIGHT` (antropometría) · el offset del NavMesh de B11 (rasterización) | (A) — no es duplicación, es **colisión**: quien lea los dos archivos en la misma sesión va a asumir que uno sale del otro |
| B13 | **Convención `*_test.gd`** | `plan.md` (por el `McpTestSuite` del MCP) · `runner_smoke_test.gd` · los 6 archivos de `tests/` | (D) 🔒 — nada valida el nombre. Un `test_algo.gd` rompería el otro runner sin aviso |

---

## C. Rutas y nombres

| # | Par | Dónde | |
|---|---|---|---|
| C2 | **Rutas de escena en el autoload** | `network_manager.gd` `LOBBY_SCENE` / `WORLD_SCENE` · `project.godot` `run/main_scene` | (A) 🔒 — mover `lobby.tscn` rompe dos archivos, uno en silencio: el `change_scene_to_file()` de `_on_server_disconnected` solo corre cuando se cae el host |
| C4 | **Ruta de la escena horneada** | `bake_navmesh.gd` `SCENE_PATH` / `OUTPUT_PATH` · `yard.tscn` `navigation_mesh = ExtResource(...)` | (A) 🔒 — si alguien cambia el `.tres` que apunta `yard.tscn`, la herramienta sigue horneando el otro y no falla |
| C6 | **Nombre de archivo ↔ campo `id`** | `resources/items/<x>.tres` ↔ `id = "<x>"` ×10 | (A) 🔒 — `item_catalog_test.gd` valida ids duplicados y vacíos, no que el nombre del archivo coincida |
| C7 | **Catálogo ↔ carpeta de items** | `item_catalog.tres` lista 10 · `resources/items/` tiene 10 | (D) 🔒 — el test compara contra `EXPECTED_ITEM_COUNT = 10`, así que **agregar un `.tres` sin registrarlo no falla nada**: el conteo sigue en 10 |
| C8 | **`uid://` ↔ `.gd.uid`** | 20 archivos `.gd.uid` · los `ext_resource` de las escenas | (A) — **1 de 39 `ext_resource` lleva `uid=`**. Las escenas se escribieron a mano. Es asimetría, no rotura |

---

## D. Versiones y rutas de herramientas

| # | Dato | Copias | |
|---|---|---|---|
| D1 | **gdUnit4 `6.2.0`** | `addons/gdUnit4/plugin.cfg` (fuente) · `CLAUDE.md` · `plan.md` ×3 · `bitacora.md` ×2 | (A) 🔒 |
| D2 | **godot-ai `3.1.2`** | `addons/godot_ai/plugin.cfg` (fuente) · `bitacora.md` | (A) 🔒 — **el plugin se autoactualiza**, así que este par se desincroniza solo, sin que nadie edite nada |
| D3 | **Godot `4.7.1-stable`** | `project.godot` `config/features` · `CLAUDE.md` ×2 · `plan.md` ×3 · `bitacora.md` · ADR-0001 · `rules/gdscript.md` · `netcode.md` | (D) — la repetición es deliberada y está justificada (declarar la versión corta la contaminación de Godot 3), pero son 9 copias a mano el día que actualicen |
| D4 | **Ruta `C:\Godot\Godot_v4.7.1-stable_win64.exe`** | `CLAUDE.md` · `bitacora.md` · `settings.local.json` ×15 · el `$godot` que asume el SKILL | (A) — `CLAUDE.md` dice que la ruta es distinta en cada máquina, o sea que **este par está roto por diseño en la máquina de Mathi** |
| D5 | **Comando de tests** | `CLAUDE.md` (`-a res://tests`, `--ignoreHeadlessMode`, código 103) · `plan.md` describe el estado | (D) — existe en un solo lugar en prosa y sin hook que lo encapsule |

---

## E. Prosa duplicada entre `docs/` y `.claude/rules/`

| # | Par | |
|---|---|---|
| E2 | **La tabla de autoridad de red** — `CLAUDE.md` · `.claude/rules/netcode.md` · `docs/netcode.md` | (A) — 3 copias de la misma tabla de 6 filas. Retrospectiva §2.9 y §5.2 pidieron recortar dos |
| E3 | **La trampa de `@rpc("authority")`** — `docs/netcode.md` ×2 · `rules/netcode.md` · `world.gd` · `bitacora.md` · trailer `Rejected:` de `9f94fb1` | (A) — 6 copias. Es D4 de la retrospectiva |
| E4 | **Tabla Godot 3 → Godot 4** — `CLAUDE.md` · `rules/gdscript.md` | (D) — asumida y anotada en el propio texto |
| E7 | **`CLAUDE.md` bajo 200 líneas** — `plan.md` cita la recomendación · retrospectiva §2.8 midió 213 · **hoy 217** | (A) 🔒 — el número sube solo y no hay mecanismo de contención |

---

## F. Estado del proyecto duplicado entre docs

| # | Par | |
|---|---|---|
| F1 | **Lista de andamios de debug** — retrospectiva §3.4 · docstring de `debug_overlay.gd` · `project.godot [input]` | (A) 💥 **ya divergido**: §3.4 lista dos acciones (`debug_hurt`, `debug_hurt_invalid`) y el script lista cuatro. `debug_pause_zombies` y `debug_inventory_attack` entraron después |
| F2 | **Deuda de verificación** — `git log --grep="Not-tested"` (fuente) · retrospectiva §3.2 · `bitacora.md` § Pendiente | (A) — §5.4 propuso mudarla a `bitacora.md` como lista viva y no se hizo. Hoy hay tres listas parciales |
| F3 | **Huecos de diseño abiertos** — `design.md` · `bitacora.md` · retrospectiva §3.6 | (A) — cerrar uno obliga a tocar tres archivos |
| F4 | **Tabla de milestones** — `plan.md` §3 (prosa) · `design.md` § Milestones (tabla) | (D) — ya se desincronizaron una vez: `design.md` puso el item médico en v0.3 y se corrigió el 6/8 |
| F5 | **Los 10 items** — `design.md` (lista + tabla item→mecánica) · `resources/items/` · `item_catalog.tres` · `item_catalog_test.gd` · `resources/items/README.md` | (D) 🔒 — el test compara catálogo↔10, **nada compara `design.md`↔catálogo**. Los nombres en castellano de `design.md` viven aparte de `display_name` |

---

## Lo que NO hay que "arreglar"

Dos entradas del barrido que parecen deuda y no lo son. Van acá para que nadie las
reporte de nuevo ni las toque por error.

- **La estructura de carpetas** (`CLAUDE.md` única versión, `plan.md` §5 apunta ahí).
  **Es el molde a copiar:** estaba escrita en tres lugares desincronizados y la
  colapsaron a una con puntero. Todo lo de la familia E se resuelve así.
- **ENet dura "hasta v0.5" en ADR-0004 y "hasta v0.6" en `plan.md` y `netcode.md`.**
  Divergencia **aceptada a propósito**: las ADRs son inmutables (`proceso.md` §2). Está
  explicado en `bitacora.md`. No se toca.

---

## Cerrado en la Parte 1 — no reportar de nuevo

| Par | Cómo quedó | Commit |
|---|---|---|
| Escenas spawneables: `world.gd` ↔ `world.tscn` | comparador en `tests/consistencia_test.gd` | `f1725bb` |
| Radios de cápsula, dentro de cada escena | comparador (contra `design.md` sigue abierto, ver A2) | `f1725bb` |
| Vida "30 de 100": `design.md` ↔ `world.gd` + `player_stats.gd` | comparador | `f1725bb` |
| Coordenadas de puertas y spawn del SKILL ↔ `yard.tscn` / `world.tscn` | comparador | `f1725bb` |
| El comentario de `max_health` contradecía a `design.md` | corregido | `aaefd2a` |
| `[run] main_scene` ↔ `[application] run/main_scene` | la clave muerta se borró | `2d5097a` |
| "Claude Code no commitea solo" en 3 lugares | consolidado con punteros | `b1a6ec5` |
| `bitacora.md` decía que el repo era privado | corregido | `5cc3d11` |

---

## Candidatos a la tanda 2 del script

Ordenados por lo mismo que ordenó la tanda 1: **qué rompe silencioso y qué ya rompió.**

1. **A15 + A14 + A13 + A16 + A17 + A18** — toda la geometría de `yard.tscn` contra la
   tabla de `design.md`, en un solo test. A15 ya causó el bug más caro del proyecto y el
   parseo del `.tscn` ya está escrito en `consistencia_test.gd`.
2. **B8** — el margen de 0,2 m entre `target_desired_distance` y los radios. La
   retrospectiva pidió anotarlo hace cinco días y sigue sin anotar. Es el próximo A15.
3. **C2 + C4** — rutas de escena que solo se ejercen en caminos raros (host que se cae,
   herramienta de horneado). Baratos y con el molde ya hecho.
4. **A4 a A11** — los números de gameplay sueltos contra la tabla. Mecánicos, todos
   iguales, todos 🔒.
5. **F1** — la lista de andamios ya está divergida y es lo que hay que mirar cuando entre
   el HUD y haya que borrarlos.

**Lo que NO conviene meter en un script:** la familia E (es consolidación de prosa, no
comparación), D3 y D4 (una es deliberada, la otra está rota por diseño entre máquinas), y
B12 (es una colisión de significados, no una desincronización).
