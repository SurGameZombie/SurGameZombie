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

## Godot 4.7, no Godot 3

`@onready` no `onready` · `@export` no `export` · `await` no `yield` ·
`Node3D` no `Spatial` · `CharacterBody3D` no `KinematicBody`

Si dudás de que una clase o método exista en Godot 4.7, verificá en la documentación
antes de escribirlo.

---

# Checklist de autorrevisión

**Pasar esta lista sobre cualquier `.gd` antes de entregarlo.** Son los 10 pitfalls que
un analizador estático escrito específicamente para GDScript generado por IA detecta con
más frecuencia (`docs/investigacion-claude-code.md`).

### 1. API de Godot 3 usada en Godot 4 — **empezar por acá**

Dentro de este punto, el caso que más duele es `connect()` con la firma vieja, porque
**no conecta nada**:

```gdscript
# Godot 3 — no conecta
button.connect("pressed", self, "_on_pressed")

# Godot 4.7 — las dos válidas, preferir la primera
button.pressed.connect(_on_pressed)
button.connect("pressed", _on_pressed)
```

Verificado en 4.7.1: con tipado estático es **error de parseo** y el script directamente
no carga; sobre un `Variant` es error de runtime (`Cannot connect to 'x': the provided
callable is null`) y el juego sigue andando con la señal desconectada. Ese segundo caso es
el peligroso: el botón se ve bien y no hace nada, y el error queda solo en el panel
Debugger. Con static typing obligatorio no debería llegar nunca a runtime — es una razón
más para el tipado.

El resto de la API vieja: ver la tabla de arriba y la de `CLAUDE.md`.

### 2. Scripts gigantes

El límite duro registrado es el de función: 30 líneas. Para un script no hay número
fijado, pero si uno maneja input, física, red y UI a la vez, se parte.

### 3. `:=` sobre un `Variant`

`:=` infiere el tipo del lado derecho. Si ese lado devuelve `Variant` —un valor de
`Dictionary`, un `JSON` parseado, `get_meta()`— la variable queda `Variant` y se pierde
el tipado sin que nada avise.

```gdscript
var amount := data["amount"]        # Variant, silenciosamente
var amount: int = data["amount"]    # tipado de verdad
```

### 4. Acoplamiento fuerte entre nodos

Sin `get_node("../../..")`. `@export` o señales. Ya está arriba; se revisa igual.

### 5. Re-entrancia de señales

Un handler que —directo o a través de otro nodo— termina emitiendo la señal que lo
invocó. Da recursión infinita o estado mutado en medio de una iteración. Si un handler
escribe sobre el estado que dispara esa misma señal, revisar el ciclo.

### 6. Mal uso de autoloads

Un autoload es estado global y **no tiene noción de autoridad de red**: existe igual en el
host y en cada cliente, y no se replica solo. Antes de meter estado de juego en uno,
preguntar. El único autoload registrado hoy es `_mcp_game_helper`, del plugin del MCP.

### 7. Señales que no se desconectan

Los zombies y los items dropeados se crean y se destruyen todo el tiempo. Si un nodo que
puede volver a entrar al árbol se conecta a otro que vive más que él (un manager, un
autoload), la conexión se duplica y el handler corre dos veces:

```gdscript
if not health_changed.is_connected(_on_health_changed):
    health_changed.connect(_on_health_changed)
```

Nunca conectar la misma señal desde el editor **y** desde código.

### 8. Timing de `_init()`

`_init()` corre al construir el objeto, antes de entrar al árbol: los `@onready` todavía
son `null`, `get_node()` falla y `get_tree()` es `null`. Todo lo que dependa del árbol va
en `_ready()`.

### 9. Python-ismos que no compilan

`null` / `true` / `false`, no `None` / `True` / `False`. No hay list comprehensions, ni
`try`/`except`, ni `import`, ni `def`, ni f-strings.

### 10. `static func` en un autoload

Un `static func` no ve el estado de la instancia. Si la función necesita tocar variables
del singleton, no puede ser `static`.

---

## Dos misses recurrentes de Claude

- **Generación procedural dentro de `_ready()` sin `await`.** Bloquea el frame y el juego
  arranca congelado. Si el trabajo es pesado, va con `await` o `WorkerThreadPool`.
- **Nombres de clases de C# con sintaxis de GDScript.** Este proyecto usa la versión
  standard de Godot, no la .NET: no existe nada de C# acá.
