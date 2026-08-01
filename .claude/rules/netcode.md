---
paths:
  - "scripts/net/**"
  - "scripts/combat/**"
  - "scripts/survival/**"
  - "scripts/inventory/**"
  - "scripts/world/**"
---

# Autoridad de red

Todo cambio de estado del juego se resuelve en el host.

## Reglas duras

- Los clientes NUNCA modifican salud, inventario, hambre, sed, stamina, posición de otro
  peer, ni el estado de un zombie.
- Los clientes mandan intención vía `@rpc("any_peer", "call_local", "reliable")`.
- El host valida, aplica el cambio y replica el resultado.
- Usar `is_multiplayer_authority()` para verificar. Nunca asumir.
- La creación del `MultiplayerPeer` vive solo en `scripts/net/network_manager.gd`.
  Ningún otro archivo debe saber si el transporte es ENet, Steam o noray.

## Antes de escribir cualquier función que cambie estado

Preguntarse: ¿esto corre en el host? Si puede correr en un cliente, está mal.

## Patrón esperado

```gdscript
# Cliente pide, host decide.
@rpc("any_peer", "call_local", "reliable")
func request_pickup(item_id: String) -> void:
    if not multiplayer.is_server():
        return
    var sender_id: int = multiplayer.get_remote_sender_id()
    # validar, aplicar, replicar
```

## Sincronización

Para estado continuo (posición, rotación) usar `MultiplayerSynchronizer`.
Para instanciar/destruir en red usar `MultiplayerSpawner`.
Los RPC son para eventos discretos, no para estado que cambia cada frame.
