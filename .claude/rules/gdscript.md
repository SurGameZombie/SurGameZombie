---
paths:
  - "**/*.gd"
---

# GDScript

## Tipado

Static typing en todas las variables, parámetros y retornos. Sin excepciones.

```gdscript
# Bien
var health: float = 100.0
var targets: Array[Node3D] = []
func take_damage(amount: int, source: Node3D) -> void:

# Mal
var health = 100.0
func take_damage(amount, source):
```

## Estructura de un script

Orden dentro del archivo:

1. `class_name` (solo si el tipo se usa desde otros archivos)
2. `extends`
3. Señales
4. Constantes y enums
5. `@export`
6. Variables públicas
7. Variables privadas (prefijo `_`)
8. `@onready`
9. `_ready()`, `_process()`, `_physics_process()`
10. Métodos públicos
11. Métodos privados (prefijo `_`)

## Convenciones

- Preferir `@export` sobre buscar nodos por path.
- Toda función pública lleva un comentario de una línea: qué hace y quién la llama.
- Señales en pasado: `health_changed`, `item_picked_up`.
- Nada de `get_node("../../..")`.
- Si una función pasa las 30 líneas, partirla.

## Godot 4, no Godot 3

`@onready` no `onready` · `@export` no `export` · `await` no `yield` ·
`Node3D` no `Spatial` · `CharacterBody3D` no `KinematicBody`

Si dudás de que una clase o método exista en Godot 4.7, verificá en la documentación
antes de escribirlo.
