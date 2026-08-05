---
paths:
  - "scripts/net/**"
  - "scripts/combat/**"
  - "scripts/survival/**"
  - "scripts/inventory/**"
  - "scripts/world/**"
  - "scripts/player/**"
  - "scripts/enemies/**"
  - "scripts/ui/**"
  - "scenes/**"
---

# Autoridad de red

La autoridad está partida en dos. Detalle completo y el porqué en `docs/netcode.md`.

> **El cuerpo del propio jugador es autoridad del peer dueño.
> Todo el resto del estado del juego es autoridad del host.**

## Qué check usar

| Estás tocando | Check |
|---|---|
| Movimiento / rotación del propio jugador | `is_multiplayer_authority()` |
| Vida, daño, muerte, respawn | `multiplayer.is_server()` |
| Hambre, sed, stamina | `multiplayer.is_server()` |
| Inventario, pickup, drop, contenedores | `multiplayer.is_server()` |
| Zombies: spawn, IA, vida, ataque | `multiplayer.is_server()` |
| Loot, día/noche, estado del mundo | `multiplayer.is_server()` |

Los dos no son intercambiables. `multiplayer.is_server()` es "¿soy el host?".
`is_multiplayer_authority()` es "¿soy la autoridad **de este nodo**?", que en el cuerpo del
jugador es el cliente dueño. Usar uno donde va el otro compila, corre, y rompe el estado
de formas que no se ven hasta que hay tres jugadores conectados.

## Reglas duras

- Los clientes NUNCA modifican salud, inventario, hambre, sed, stamina, el estado de un
  zombie, ni la posición de **otro** peer. Su propia posición sí, y solo eso.
- Para todo lo que no sea su propio movimiento, los clientes mandan intención vía
  `@rpc("any_peer", "call_local", "reliable")`. El host valida, aplica y replica.
- El host nunca confía en un valor de gameplay mandado por el cliente. La posición se
  acepta; "le pegué a este zombie" o "agarré esto" se valida contra el estado del host.
- La creación del `MultiplayerPeer` vive solo en `scripts/net/network_manager.gd`.
  Ningún otro archivo debe saber si el transporte es ENet, Steam o noray.
- **La autoridad no se reasigna en runtime.** El cuerpo del jugador es del peer dueño
  siempre, incluso caído o muerto. Nada de `set_multiplayer_authority()` fuera del momento
  en que el host instancia al jugador.
- Lo que el save tiene que volver a encontrar (contenedores, puertas, spawns) se
  identifica por un **ID propio y estable**, no por `NodePath`. Los RPC también mandan ID.

## Antes de escribir cualquier función que cambie estado

Preguntarse: ¿esto es el movimiento del propio jugador? Si no lo es, corre en el host.

## Los tres patrones

```gdscript
# 1. Movimiento propio: solo el dueño simula.
func _physics_process(delta: float) -> void:
    if not is_multiplayer_authority():
        return
    # leer input, mover, move_and_slide()
```

```gdscript
# 2. Todo lo demás: cliente pide, host decide.
@rpc("any_peer", "call_local", "reliable")
func request_pickup(item_id: String) -> void:
    if not multiplayer.is_server():
        return
    var sender_id: int = multiplayer.get_remote_sender_id()
    # validar, aplicar, replicar
```

```gdscript
# 3. El host decide algo sobre el cuerpo de un cliente: se lo ORDENA al dueño.
# El host no puede escribirle la posición — el Synchronizer del dueño se la pisa.
# Va en world.gd, NO en player.gd: ver la trampa de abajo.
@rpc("authority", "call_local", "reliable")
func respawn_at(point: Vector3) -> void:
    # corre en la máquina del dueño; busca su propio jugador y lo mueve
```

**Trampa de `@rpc("authority")`:** significa *"solo la autoridad de **este nodo**"*, no
*"solo el host"*. En un nodo con autoridad de cliente —`player.gd`, que hace
`set_multiplayer_authority(name.to_int())`— el flag deja afuera al host y la RPC no se
puede mandar nunca. Poner esas RPC en un nodo cuya autoridad no se reasigna (`world.gd`), o
usar `"any_peer"` y validar `get_remote_sender_id() == 1` a mano.

Si lo que estás escribiendo no entra en ninguno de los tres, preguntá antes de seguir.

## Donde se tocan: el modificador de velocidad

Estado del host que se consume dentro del movimiento del cliente. Aplica a stamina (v0.4),
sobrepeso (v0.3) y a todo lo que venga después que cambie cuánto corrés.

> El host calcula el modificador y lo replica. El cliente lo recibe y lo multiplica por su
> velocidad. **El cliente nunca calcula el modificador.**

```gdscript
# El nodo de stats (host) expone el número; el jugador (cliente dueño) lo usa.
var speed: float = base_speed * stats.speed_multiplier
```

Mismo molde para el estado caído: el host decide que estás caído, el cliente lee el flag y
deja de leer input. No se le saca la autoridad del cuerpo.

## Sincronización

- `MultiplayerSynchronizer` para estado continuo (posición, rotación). Replica **desde la
  autoridad del nodo hacia los demás**: la autoridad define la dirección de los datos.
- `MultiplayerSpawner` para instanciar/destruir en red. Solo el host instancia.
- Los RPC son para eventos discretos, no para estado que cambia cada frame.

`set_multiplayer_authority(id, recursive)` tiene `recursive = true` por default: llamarla
en la raíz del jugador arrastra también los nodos de stats, que tienen que quedar en el
host. Reasignarlos explícitamente.
