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
- `docs/` — `design.md` (qué es el juego), `netcode.md` (reglas de red), `decisions/` (ADRs)
- `addons/` — plugins de terceros. **No editar nada acá dentro.**

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

## Qué NO hacer

- **No inventar APIs de Godot.** Si no estás seguro de que una clase o método existe en
  Godot 4.7, decilo y verificá en la documentación antes de escribir. GDScript está poco
  representado en el training data: la alucinación de APIs acá es el error más común.
- **No usar sintaxis de Godot 3.** En Godot 4 es `@onready`, `@export`, `await`
  (no `onready`, `export`, `yield`).
- No refactorizar archivos que no se pidieron tocar.
- No crear abstracciones "por si acaso". El proyecto es chico y va a seguir siéndolo un tiempo.
- No commitear sin que lo revisemos.
- No dar por terminada una tarea porque los tests pasan. Los tests miden corrección,
  no si el juego es jugable.

## Cómo trabajar con nosotros

Somos dos personas aprendiendo gamedev. Explicá el porqué de las decisiones de diseño de
juego, no solo el código. Si algo es una convención de Godot que no es obvia, decilo.

Tareas chicas y verificables. Si un pedido es demasiado grande, proponé partirlo antes de
arrancar en vez de escribir mil líneas de una.

Si detectás que algo de este archivo quedó desactualizado respecto al código, avisá.
