# ZOMBIE-COOP

## Engine: Godot 4.7.1-stable. Sintaxis de Godot 4, nunca de Godot 3.

Godot 3 domina el training data, así que el default es equivocarse. Declarar la versión
explícitamente corta esa contaminación aproximadamente a la mitad, y es la única medida
con efecto medido (`docs/investigacion-claude-code.md`). Por eso está acá arriba.

La tabla de reemplazos de Godot 3 → 4.7 y el checklist de los 10 pitfalls están en
`.claude/rules/gdscript.md`, que se carga solo al tocar cualquier `.gd`. Si dudás de que
una clase, método o propiedad exista en **Godot 4.7**, verificá en la documentación antes
de escribirla. Ver `.claude/rules/limites.md` → "Avisá cuando estés adivinando".

---

Survival co-op en primera persona para 2-4 jugadores. GDScript con static typing.
Proyecto hobby de dos personas que saben programar pero es su primer videojuego.
Sin fecha de entrega. Prioridad: entender lo que se construye, no llegar rápido.

## Comandos

Godot **no está en el PATH**. Definir la ruta una vez por sesión de PowerShell:

```powershell
$godot = "C:\Godot\Godot_v4.7.1-stable_win64.exe"
```

La ruta es distinta en cada máquina. Para no repetirlo, agregar esa carpeta al PATH del
usuario y usar `godot` directo.

```powershell
& $godot --path . --editor             # abrir el editor
& $godot --path .                      # correr el juego (main_scene = lobby.tscn)
& $godot --headless --path . --import  # importar y verificar que no haya errores

# Correr una escena en un proceso limpio y salir a los 90 frames. Agarra errores
# de parseo y de @onready, y sirve para distinguir "el código está mal" de "el
# editor abierto tiene una copia vieja" (ver docs/bitacora.md → Problemas).
& $godot --headless --path . res://scenes/main/world.tscn --quit-after 90

# Rehornear el NavMesh del greybox. CORRERLO SIEMPRE después de tocar la geometría
# de scenes/main/yard.tscn, y después correr el skill barrido-navmesh: si no, hay
# vanos que quedan sin NavMesh y el zombie no entra (ADR-0008). Sale con código 1.
& $godot --headless --path . -s res://tools/bake_navmesh.gd
```

`--import` es el flag correcto para verificar el proyecto: importa los recursos y sale.

Tests (gdUnit4 v6.2.0, instalado). Sin `--ignoreHeadlessMode` sale con código 103 y no
corre nada. Los reportes van a `reports/`, que está en `.gitignore`:
```powershell
& $godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests
```

## Estructura (única versión — `docs/plan.md` §5 apunta acá, no la repite)

- `scenes/` — escenas `.tscn` por sistema: `main/`, `player/`, `enemies/`, `items/`
- `scripts/` — lógica por sistema: `net/`, `player/`, `enemies/`, `combat/`, `survival/`,
  `inventory/`, `world/`, `ui/`
- `resources/` — datos como `.tres`: items, tipos de zombie, loot tables
- `assets/` — `models/` (.glb), `textures/`, `audio/`
- `tests/` — suites de gdUnit4, nombradas `*_test.gd` (`docs/plan.md` → v0.3)
- `tools/` — scripts que se corren con `-s` desde línea de comandos, no son parte del
  juego. Hoy solo el horneado del NavMesh
- `docs/` — `plan.md` (arquitectura, stack y milestones), `design.md` (qué es el juego),
  `netcode.md` (reglas de red), `bitacora.md` (decisiones tomadas y problemas ya resueltos),
  `proceso.md` (cómo commiteamos, cómo documentamos y cómo buscamos errores),
  `investigacion-claude-code.md` (modos de falla medidos de la IA en gamedev, los 10
  pitfalls de GDScript y las reglas operativas que salen de ahí), `decisions/` (ADRs)
- `addons/` — plugins de terceros. **No editar nada acá dentro.**

Leer `docs/plan.md` y `docs/bitacora.md` antes de proponer cambios estructurales.
Leer `docs/proceso.md` antes de escribir cualquier mensaje de commit.
Leer `docs/investigacion-claude-code.md` antes de proponer cambios de proceso o de
herramientas.

## Reglas de código

- **Static typing obligatorio.** `var health: float = 100.0`, `func take_damage(amount: int) -> void:`.
  Nunca declarar sin tipo. Sin tipos no hay detección de errores hasta runtime.
- **Idioma: código en inglés, prosa en español.** Identificadores, funciones, variables,
  clases y nombres de nodos en inglés (`take_damage`, `health`, `PlayerBody`). Comentarios,
  documentación y commits en español. La API de Godot es en inglés: mezclar
  `func tomar_daño()` con `move_and_slide()` en la misma línea se lee mal.
- Archivos y variables en `snake_case`. Clases y nodos en `PascalCase`.
- Un script por escena, mismo nombre que la escena.
- Preferir señales sobre acoplamiento directo entre nodos.
- Nada de `get_node("../../..")`. Usar `@export` o señales.
- Si una función pasa las 30 líneas, partirla.
- **Input map: movimiento por `physical_keycode`, atajos de UI por `keycode`.** El
  movimiento va por posición física de la tecla, así que en un teclado AZERTY o QWERTZ
  caen las mismas cuatro teclas bajo los dedos. Los atajos por letra (`I` = inventario)
  van por `keycode`, para que la tecla que dice I sea la que abre el inventario.

## Datos como Resources

Items, tipos de zombie y loot tables se definen como archivos `.tres` en `resources/`,
nunca hardcodeados en GDScript. El script `Resource` de cada tipo va en `scripts/<sistema>/`.

Razón: los `.tres` son texto, así que se generan en lote, se revisan en el diff de git,
y se balancean sin tocar código.

## Netcode

Detalle completo y el porqué en `docs/netcode.md`. La autoridad está partida en dos:

> **El cuerpo del propio jugador es autoridad del peer dueño → `is_multiplayer_authority()`.
> Todo el resto del estado es autoridad del host → `multiplayer.is_server()`.**

El cliente mueve su propia cápsula y el `MultiplayerSynchronizer` la replica. Vida, daño,
inventario, hambre, sed, stamina, zombies, loot y mundo los resuelve el host: el cliente
pide por RPC. Los dos checks no son intercambiables.

Antes de escribir cualquier función que cambie estado: ¿esto es el movimiento del propio
jugador? Si no lo es, corre en el host.

---

## Cómo trabajar en este proyecto

Estas instrucciones existen porque son los modos de falla documentados de los agentes en
gamedev. No son sugerencias.

Joaco programa y Mathi no: toda tarea que no requiera código va marcada como delegable a
Mathi. Ver `.claude/rules/limites.md` → "Lo que no es tuyo".

### Preguntá antes de asumir

Si un pedido admite más de una interpretación y elegir mal implica rehacer trabajo,
**preguntá una cosa concreta antes de escribir código.** No adivines en silencio.

Ejemplos de cosas que hay que preguntar y no asumir: si algo lo decide el host o el
cliente, si un valor va hardcodeado o como `.tres`, si algo debe replicarse o es local,
si un sistema nuevo tiene que funcionar en multiplayer desde el día uno.

Si la duda es menor, asumí lo razonable y decí explícitamente qué asumiste.

### Formato de las respuestas

El cierre de una tarea tiene tres partes, en este orden. Las que no aplican se
omiten enteras, no se escriben vacías.

**Qué cambié** — una o dos frases. Qué hace ahora el código. No repitas el diff,
lo vamos a leer.

**Probá vos** — solo lo que no podés verificar: si se ve bien, si se siente bien,
si los números están balanceados, si la latencia se nota. Formato: acción concreta
→ qué debería pasar si está bien. Si no hay nada, omitila.

**Decidí vos** — solo si hay una decisión real bloqueada. Una pregunta concreta
con opciones. No un ensayo.

**Toda afirmación numérica va con el comando que la produjo.** Un conteo, una medición o
un porcentaje sin el comando al lado es una cifra que nadie puede desmentir, y las
verificaciones que salen bien son justo donde viven los conteos. Si el número no salió de
un comando, decí de dónde salió.

Objetivo de largo: media pantalla. Si no entra, es señal de que la tarea era
demasiado grande y hay que partirla.

### Qué no escribir nunca

- Lo que verificaste y salió bien. Si compila y los tests pasan, no lo menciones.
  Si algo falló, sí. **Los números son la excepción:** una cifra va con su comando
  aunque la verificación haya salido bien.
- Lo que ya está escrito en CLAUDE.md, en las rules o en los docs.
- Decisiones de diseño ya tomadas y registradas.
- Reformulaciones del pedido antes de contestarlo.
- Resúmenes de lo que vas a hacer, antes de hacerlo.
- Listas de archivos tocados: el diff ya los muestra.

### Cuándo sí extenderte

- Cuando estés adivinando o no puedas verificar algo que importa
- Cuando encuentres un problema que no te pedimos mirar
- Cuando te pidamos explicación explícitamente
- Cuando estés proponiendo un plan

Ahí largo está bien. En el resto, el default es corto.

### La regla que resume todo

Si algo lo podés resolver o verificar vos, resolvelo y no lo cuentes.
Si no podés, decilo en una línea accionable.

La brevedad se aplica a la narración, no a la evidencia: un número siempre lleva su comando.

### Están aprendiendo — explicá

Es su primer videojuego. Si el hobby se muere va a ser porque perdieron el contacto con
su propio código, no por falta de features.

- Explicá el porqué de las decisiones de diseño de juego, no solo el código.
- Si usás una convención de Godot que no es obvia (autoloads, señales, el ciclo de vida
  de los nodos, `_process` vs `_physics_process`), explicala en una línea.
- Si un archivo que escribiste es complejo, ofrecé explicarlo antes de que lo commiteen.
- Si te preguntan "por qué hiciste esto así", es una pregunta real. Contestala en serio,
  y si había una alternativa mejor decilo.

### Tareas chicas

Si un pedido es demasiado grande para hacerlo bien de una, **proponé partirlo antes de
arrancar** en vez de escribir mil líneas.

Si la sesión se está haciendo larga y notás que estás perdiendo el hilo de qué archivos ya
tocaste, decilo y sugerí cortar ahí y arrancar limpio.

## Herramientas nuevas

**Antes de sumar cualquier MCP, skill, plugin, connector o hook se consulta el catálogo**
en `C:\ClaudeMCPsPlugingsSkillsETC`, que ya tiene la decisión tomada sobre cada una y el
porqué. Las reglas —orden de lectura, qué hacer con un veredicto `peligroso`, y dónde deja
este proyecto su propia decisión— están en `.claude/rules/herramientas.md`, que se carga
siempre.

## Qué NO hacer

- **No inventar APIs de Godot.** Ver `.claude/rules/limites.md`.
- **No usar sintaxis de Godot 3.** En Godot 4 es `@onready`, `@export`, `await`
  (no `onready`, `export`, `yield`).
- No refactorizar archivos que no se pidieron tocar.
- No crear abstracciones "por si acaso". El proyecto es chico y va a seguir siéndolo un tiempo.
- No commitear sin que lo revisemos.
- No dar por terminada una tarea porque los tests pasan.
- No editar nada dentro de `addons/`.

## Mantenimiento de este archivo

Si detectás que algo acá quedó desactualizado respecto al código, avisá.

Si notamos que estamos corrigiendo más del 30% de lo que escribís, el problema no es el
modelo: es que este archivo, las rules o el MCP están mal armados. En ese caso, pará y
revisemos el setup antes de seguir produciendo código.
