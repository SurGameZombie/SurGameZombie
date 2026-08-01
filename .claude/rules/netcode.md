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

## Antes de escribir cualquier función que cambie estado

Preguntarse: ¿esto es el movimiento del propio jugador? Si no lo es, corre en el host.

## Los dos patrones

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

Si lo que estás escribiendo no entra en ninguno de los dos, preguntá antes de seguir.

## Sincronización

- `MultiplayerSynchronizer` para estado continuo (posición, rotación). Replica **desde la
  autoridad del nodo hacia los demás**: la autoridad define la dirección de los datos.
- `MultiplayerSpawner` para instanciar/destruir en red. Solo el host instancia.
- Los RPC son para eventos discretos, no para estado que cambia cada frame.

`set_multiplayer_authority(id, recursive)` tiene `recursive = true` por default: llamarla
en la raíz del jugador arrastra también los nodos de stats, que tienen que quedar en el
host. Reasignarlos explícitamente.
