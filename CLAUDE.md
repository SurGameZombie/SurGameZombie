# ZOMBIE-COOP

Survival co-op en primera persona para 2-4 jugadores. Godot 4.7 + GDScript.
Proyecto hobby de dos personas que saben programar pero es su primer videojuego.
Sin fecha de entrega. Prioridad: entender lo que se construye, no llegar rápido.

## Comandos

```
godot --path . --editor          # abrir el editor
godot --path .                   # correr el juego
godot --headless --path . --quit # verificar que el proyecto importa sin errores
```

Tests (una vez instalado gdUnit4 desde el AssetLib):
```
godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --run-tests
```

## Estructura

- `scenes/` — escenas `.tscn` por sistema: `main/`, `player/`, `enemies/`, `items/`
- `scripts/` — lógica por sistema: `net/`, `survival/`, `inventory/`, `combat/`, `world/`
- `resources/` — datos como `.tres`: items, tipos de zombie, loot tables
- `assets/` — `models/` (.glb), `textures/`, `audio/`
- `tests/` — suites de gdUnit4
- `docs/` — `plan.md` (arquitectura, stack y milestones), `design.md` (qué es el juego),
  `netcode.md` (reglas de red), `bitacora.md` (decisiones tomadas y problemas ya resueltos),
  `decisions/` (ADRs)
- `addons/` — plugins de terceros. **No editar nada acá dentro.**

Leer `docs/plan.md` y `docs/bitacora.md` antes de proponer cambios estructurales.

## Reglas de código

- **Static typing obligatorio.** `var health: float = 100.0`, `func take_damage(amount: int) -> void:`.
  Nunca declarar sin tipo. Sin tipos no hay detección de errores hasta runtime.
- Archivos y variables en `snake_case`. Clases y nodos en `PascalCase`.
- Un script por escena, mismo nombre que la escena.
- Preferir señales sobre acoplamiento directo entre nodos.
- Nada de `get_node("../../..")`. Usar `@export` o señales.
- Si una función pasa las 30 líneas, partirla.

## Datos como Resources

Items, tipos de zombie y loot tables se definen como archivos `.tres` en `resources/`,
nunca hardcodeados en GDScript. El script `Resource` de cada tipo va en `scripts/<sistema>/`.

Razón: los `.tres` son texto, así que se generan en lote, se revisan en el diff de git,
y se balancean sin tocar código.

## Netcode

Detalle completo en `docs/netcode.md`. Regla que no se negocia:

> **El host es autoridad sobre todo el estado. Los clientes mandan input, el host simula y replica.**

Antes de escribir cualquier función que cambie estado, verificar que corra en el host.

---

## Cómo trabajar en este proyecto

Estas instrucciones existen porque son los modos de falla documentados de los agentes en
gamedev. No son sugerencias.

### Preguntá antes de asumir

Si un pedido admite más de una interpretación y elegir mal implica rehacer trabajo,
**preguntá una cosa concreta antes de escribir código.** No adivines en silencio.

Ejemplos de cosas que hay que preguntar y no asumir: si algo lo decide el host o el
cliente, si un valor va hardcodeado o como `.tres`, si algo debe replicarse o es local,
si un sistema nuevo tiene que funcionar en multiplayer desde el día uno.

Si la duda es menor, asumí lo razonable y decí explícitamente qué asumiste.

### Decí siempre qué NO pudiste verificar

No podés apretar play ni ver el juego corriendo. Sé explícito sobre eso.

Al terminar cualquier tarea, cerrá con tres cosas:

1. **Qué verificaste** (compila, importa sin errores, tests en verde)
2. **Qué NO pudiste verificar** (si se ve bien, si se siente bien, si los números están
   balanceados, si la latencia se nota)
3. **Qué tienen que probar ellos a mano**, con pasos concretos y qué debería pasar
   si está bien

### Los tests en verde no significan que esté terminado

El fallo característico de este tipo de trabajo es: los tests pasan, el código compila,
el juego arranca, y el juego es injugable.

**Nunca declares una tarea de gameplay terminada porque los tests pasen.** Los tests miden
corrección, no diversión, ni ritmo, ni sensación. Cuando toques algo que afecta cómo se
juega, decilo así y pediles que lo jueguen.

### Están aprendiendo — explicá

Es su primer videojuego. Si el hobby se muere va a ser porque perdieron el contacto con
su propio código, no por falta de features.

- Explicá el porqué de las decisiones de diseño de juego, no solo el código.
- Si usás una convención de Godot que no es obvia (autoloads, señales, el ciclo de vida
  de los nodos, `_process` vs `_physics_process`), explicala en una línea.
- Si un archivo que escribiste es complejo, ofrecé explicarlo antes de que lo commiteen.
- Si te preguntan "por qué hiciste esto así", es una pregunta real. Contestala en serio,
  y si había una alternativa mejor decilo.

### Avisá cuando estés adivinando

GDScript está poco representado en el training data y tiene unas 850 clases. Alucinar una
API que no existe es el error más común acá.

Si no estás seguro de que una clase, método o propiedad exista en **Godot 4.7**, decilo
antes de escribirla y verificá en la documentación. Es preferible decir "no estoy seguro
de que esto exista, dejame chequear" que entregar código que no compila.

Distinguí siempre: dato verificado, inferencia, y suposición.

### Tareas chicas

Si un pedido es demasiado grande para hacerlo bien de una, **proponé partirlo antes de
arrancar** en vez de escribir mil líneas.

Si la sesión se está haciendo larga y notás que estás perdiendo el hilo de qué archivos ya
tocaste, decilo y sugerí cortar ahí y arrancar limpio.

### Lo que no es tuyo

El diseño del mundo, la sensación al caminar y disparar, el balance, la elección de assets
y la coherencia visual los deciden ellos. Podés opinar si te preguntan, pero no lo resuelvas
solo ni asumas que tu criterio de "se ve bien" vale acá.

## Qué NO hacer

- **No inventar APIs de Godot.** Ver arriba.
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
