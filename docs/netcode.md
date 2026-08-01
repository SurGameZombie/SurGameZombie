# Netcode

## Modelo: listen server con autoridad del host

Un jugador corre el juego **y** la lógica de servidor en el mismo proceso. Los otros 1-3
se conectan como clientes. No hay servidor dedicado.

## La regla

> **El host es autoridad sobre todo el estado. Los clientes mandan input, el host simula
> y replica estado.**

Un cliente nunca decide que le pegó a un zombie, que agarró un item, o que su hambre bajó.
Manda "quiero atacar" / "quiero agarrar esto" y el host resuelve.

**Por qué importa tanto:** no es anti-cheat (son 4 amigos). Es que sin una única fuente de
verdad, el estado diverge entre máquinas y aparecen bugs imposibles de reproducir. Y
retrofitear autoridad después es una reescritura completa, no un refactor.

## Herramientas de Godot

| | Para qué |
|---|---|
| `MultiplayerSynchronizer` | Estado continuo que cambia todo el tiempo: posición, rotación, animación |
| `MultiplayerSpawner` | Instanciar y destruir nodos en red: zombies, items dropeados, jugadores |
| `@rpc` | Eventos discretos: "disparé", "agarré esto", "abrí esta puerta" |

No usar RPC para estado que cambia cada frame. Para eso está el Synchronizer.

## Patrón de RPC

```gdscript
# Cliente pide, host decide, host replica.
@rpc("any_peer", "call_local", "reliable")
func request_pickup(item_path: NodePath) -> void:
    if not multiplayer.is_server():
        return
    var sender_id: int = multiplayer.get_remote_sender_id()
    # 1. validar (¿existe el item? ¿está cerca? ¿le entra en el inventario?)
    # 2. aplicar en el host
    # 3. el resultado se replica por Synchronizer o por un RPC de confirmación
```

Flags de `@rpc`:
- `"any_peer"` — cualquiera puede llamarla (necesario para que el cliente pida algo)
- `"authority"` — solo el host puede llamarla (para confirmaciones host → clientes)
- `"call_local"` — se ejecuta también en quien la llamó
- `"reliable"` — garantiza entrega. Usar por defecto. `"unreliable"` solo para cosas que
  se mandan constantemente y da igual perder alguna

## Transporte: plan de migración

La creación del peer vive **solo** en `scripts/net/network_manager.gd`. El resto del
código nunca sabe qué transporte se usa. Cambiar de uno a otro tiene que ser un cambio de
diez líneas en un archivo.

| Etapa | Transporte | Qué resuelve | Costo |
|---|---|---|---|
| **Ahora → v0.5** | `ENetMultiplayerPeer` | Conexión por IP. Anda en LAN sin configurar nada. Por internet el host abre puerto en el router | $0 |
| **v1.0** | `netfox.noray` | NAT punchthrough + relay de respaldo. Los amigos se conectan con un código, sin tocar el router | $0 |
| **Si algún día va a Steam** | `SteamMultiplayerPeer` (expressobits) + GodotSteam | Steam maneja NAT, lobbies e invitaciones por el overlay. En desarrollo se usa el App ID 480 (Spacewar) gratis | USD 100 por App ID, recuperable a los USD 1.000 de revenue |

## Testear en una sola máquina

Godot corre varias instancias del proyecto a la vez: **Debug → Customize Run Instances**.
Levantar host + 2 clientes en la misma PC. Sin esto, testear multiplayer es insoportable.

## Objetivo de la v0.1

Dos cápsulas moviéndose sincronizadas en una caja, host + 1 cliente por IP en LAN.
Sin zombies, sin items, sin UI más allá de dos botones.

Es el milestone más importante del proyecto: si el esqueleto de red no está limpio acá,
todo lo que se construya encima hereda el problema.
