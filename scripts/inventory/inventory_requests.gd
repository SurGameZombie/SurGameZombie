class_name InventoryRequests
extends Node

## Todo lo que un cliente le puede pedir al host sobre inventarios. Vive en
## world.tscn, al lado de los RPC de daño y de revivir, y sigue el mismo molde: el
## cliente pide, el host valida contra su propio estado, el host aplica
## (.claude/rules/netcode.md → patrón 2).
##
## **Ninguna de estas RPC acepta una referencia a un inventario de jugador**, y eso
## no es un descuido: es la defensa. El host resuelve el inventario del que pide a
## partir de get_remote_sender_id(), así que un cliente no tiene con qué nombrar el
## inventario de otro. Una validación se puede olvidar; un parámetro que no existe,
## no.
##
## El addon de expressobits hace lo contrario —sus RPC reciben el NodePath del
## inventario y hacen get_node() sin preguntar de quién es—, y ese fue uno de los
## motivos para no adoptarlo.
##
## Los contenedores sí necesitan chequeo, porque son de todos. Está entero en
## _can_access(), una sola función del host, con el molde de
## world.gd::_can_revive(): el cliente no conoce ninguna de esas reglas, solo pide.

## El item que sube la capacidad de carga. docs/design.md → "Slots de equipo".
const BACKPACK_ID: String = "backpack"

## A qué distancia se puede usar un contenedor, en metros.
##
## PROVISORIO: no salió de jugarlo. Arranca igual que REVIVE_RANGE de world.gd
## —2 m— más medio metro, porque un contenedor tiene volumen y el jugador se frena
## contra su collider antes de llegarle al centro. El número real sale del
## playtest y es de Mathi.
const CONTAINER_RANGE: float = 2.5

## Dónde cuelgan los jugadores. Por NodePath y no hardcodeado, igual que
## debug_overlay.gd.
@export var players_path: NodePath = ^"../Players"

@onready var _players: Node3D = get_node(players_path)


## La llama un cliente para sacar algo de un contenedor. Corre en el host.
##
## Manda el container_id y no un NodePath: el árbol de escena del cliente no tiene
## por qué ser idéntico al del host (docs/netcode.md → "El mundo es del host").
@rpc("any_peer", "call_local", "reliable")
func request_take_from_container(container_id: String, item_id: String, amount: int) -> void:
	if not multiplayer.is_server():
		return
	_transfer(multiplayer.get_remote_sender_id(), container_id, item_id, amount, true)


## La llama un cliente para guardar algo en un contenedor. Corre en el host.
@rpc("any_peer", "call_local", "reliable")
func request_put_in_container(container_id: String, item_id: String, amount: int) -> void:
	if not multiplayer.is_server():
		return
	_transfer(multiplayer.get_remote_sender_id(), container_id, item_id, amount, false)


## La llama un cliente para equipar o sacarse la mochila. Corre en el host.
##
## Es lo único que hace algo de los diez items de v0.3: el resto entra inerte a
## propósito (docs/design.md → "Qué mecánica necesita cada item").
@rpc("any_peer", "call_local", "reliable")
func request_equip_backpack(equip: bool) -> void:
	if not multiplayer.is_server():
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	var inventory: Inventory = _inventory_of(peer_id)
	if inventory == null:
		_reject("mochila", peer_id, "no tiene inventario")
		return
	if equip and inventory.amount_of(BACKPACK_ID) <= 0:
		_reject("mochila", peer_id, "no tiene ninguna mochila encima")
		return

	# Sacarse la mochila estando cargado NO tira nada al piso: docs/design.md dice
	# que pasarte de la capacidad te frena, no que te bloquee. Quedás en sobrepeso.
	if equip:
		inventory.apply_backpack_capacity()
	else:
		inventory.reset_capacity()


# Un movimiento entre el inventario del que pide y un contenedor. Corre en el host.
#
# `taking` en true saca del contenedor; en false, guarda.
func _transfer(peer_id: int, container_id: String, item_id: String, amount: int, taking: bool) -> void:
	var action: String = "sacar" if taking else "guardar"
	# El item_id lo manda el cliente, así que puede ser inventado.
	if amount <= 0 or not Inventory.CATALOG.has_item(item_id):
		_reject(action, peer_id, "pedido inválido: %d de '%s'" % [amount, item_id])
		return

	var player: Node3D = _find_player(peer_id)
	var container: StorageContainer = _find_container(container_id)
	if player == null or container == null:
		_reject(action, peer_id, "no existe el jugador o el contenedor '%s'" % container_id)
		return
	if not _can_access(player, container):
		_reject(action, peer_id, "no puede usar el contenedor '%s'" % container_id)
		return

	var mine: Inventory = player.get_node_or_null("Inventory") as Inventory
	if mine == null:
		_reject(action, peer_id, "no tiene inventario")
		return

	var source: Inventory = container.inventory if taking else mine
	var destination: Inventory = mine if taking else container.inventory
	var moved: int = _move(source, destination, item_id, amount)
	print("[inventory] peer %d %s %d de '%s' en '%s'" % [
		peer_id, action, moved, item_id, container_id,
	])


# Mueve lo que se pueda de un inventario al otro y devuelve cuánto movió.
#
# Mete PRIMERO y saca después, con exactamente lo que entró. Al revés —sacar y
# después meter— un destino lleno haría desaparecer items sin dejar rastro, que es
# el peor bug que puede tener un inventario: nadie lo reporta como bug, lo reportan
# como "me parece que tenía más balas".
func _move(source: Inventory, destination: Inventory, item_id: String, amount: int) -> int:
	var wanted: int = mini(amount, source.amount_of(item_id))
	if wanted <= 0:
		return 0
	var leftover: int = destination.add(item_id, wanted)
	var moved: int = wanted - leftover
	if moved > 0:
		source.remove(item_id, moved)
	return moved


# Las condiciones para usar un contenedor, todas juntas y todas del host.
#
# El cliente no conoce ninguna: solo pide. Es el molde de world.gd::_can_revive(),
# y por lo mismo — el día que un contenedor necesite una llave, se agrega una línea
# acá adentro y cero líneas del lado del cliente.
func _can_access(player: Node3D, container: StorageContainer) -> bool:
	# 1. Un caído no saquea.
	var stats: PlayerStats = player.get_node_or_null("Stats") as PlayerStats
	if stats == null or stats.is_downed:
		return false

	# 2. Tiene que estar al lado, medido con la posición que el host YA tiene
	#    replicada. Nunca con una distancia que mande el cliente: el cliente decide
	#    dónde está, el host decide qué implica estar ahí (docs/netcode.md → "El
	#    límite de la excepción").
	return player.global_position.distance_to(container.global_position) <= CONTAINER_RANGE


func _find_player(peer_id: int) -> Node3D:
	return _players.get_node_or_null(NodePath(str(peer_id))) as Node3D


func _inventory_of(peer_id: int) -> Inventory:
	var player: Node3D = _find_player(peer_id)
	if player == null:
		return null
	return player.get_node_or_null("Inventory") as Inventory


# Por container_id y no por ruta: recorre el grupo donde los contenedores se
# registran solos (docs/netcode.md → "Los contenedores necesitan ID persistente").
func _find_container(container_id: String) -> StorageContainer:
	if container_id.is_empty():
		return null
	for node: Node in get_tree().get_nodes_in_group(StorageContainer.GROUP):
		var container: StorageContainer = node as StorageContainer
		if container != null and container.container_id == container_id:
			return container
	return null


# Los rechazos se imprimen en la consola DEL HOST, no en la de quien los provocó.
# Es a propósito: es la única forma de saber si el host está validando o
# aceptando todo, porque un cliente que se porta bien se ve igual en los dos casos.
func _reject(action: String, peer_id: int, reason: String) -> void:
	print("[inventory] %s rechazado para el peer %d: %s" % [action, peer_id, reason])
