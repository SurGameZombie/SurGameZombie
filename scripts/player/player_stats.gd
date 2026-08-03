class_name PlayerStats
extends Node

## Estado del jugador que resuelve el host. Hoy solo vida; en v0.4 entran hambre,
## sed y stamina, y en el paso 6 de v0.2 el flag de caído. Todo lo que viva acá
## adentro es autoridad del host (docs/netcode.md → "La regla").
##
## Es la otra mitad de la autoridad partida de la escena del jugador: el cuerpo
## (player.gd) es del peer dueño, esto es del host. Los dos conviven adentro de
## player.tscn con un MultiplayerSynchronizer cada uno.

## El ID del host en Godot es siempre 1.
const HOST_PEER_ID: int = 1

## Vida máxima. NO se replica: está horneada en player.tscn, así que las tres
## máquinas ya la tienen igual. Solo se replica lo que cambia en runtime.
##
## Valor de arranque sin decidir todavía: docs/design.md no fija ningún número
## de vida.
@export var max_health: float = 100.0

## Vida actual. Es la única propiedad del MultiplayerSynchronizer hijo. La
## escribe el host y baja replicada; el cliente solo la lee.
var health: float = 100.0


# La autoridad de este nodo es el host, siempre, en las tres máquinas.
#
# Corre acá y no en player.gd a propósito: _enter_tree() va de padre a hijo, así
# que cuando esta línea corre, player.gd ya llamó
# set_multiplayer_authority(name.to_int()) con recursive en true y arrastró este
# nodo al peer dueño. Esta llamada corre después y lo devuelve al host.
#
# Cada nodo declara su propia autoridad: es el mismo patrón que ya usa player.gd,
# y escala solo cuando en v0.4 aparezcan más nodos de estado del host.
func _enter_tree() -> void:
	set_multiplayer_authority(HOST_PEER_ID)


## Le baja vida a este jugador. La llama SOLO el host.
##
## En el paso 4 el zombie la va a llamar DIRECTO, sin pasar por
## world.gd::request_damage(): el zombie ya corre en el host, así que pedirse
## permiso a sí mismo por red no tendría sentido. El RPC es la puerta para los
## clientes, no el camino del daño.
func take_damage(amount: float) -> void:
	if not multiplayer.is_server():
		return
	# Clampear en 0 es provisorio: morir, caer y respawnear son el paso 6.
	health = maxf(0.0, health - amount)
