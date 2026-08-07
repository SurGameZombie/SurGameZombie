class_name InventorySync
extends Node

## Replica un Inventory del host hacia los clientes. Es la única parte del
## inventario que sabe que existe la red: inventory.gd no tiene una sola línea.
##
## Va como hijo del Inventory que replica. Sirve igual para el inventario de un
## jugador y para el de un contenedor del mundo — los dos son estado del host
## (.claude/rules/netcode.md).
##
## El patrón —deltas por señal y snapshot completo— es el de
## `sync_grid_inventory.gd` del addon de expressobits, mirado como referencia de
## diseño. No se copió una línea de su código, y las dos diferencias que tiene con
## el original son a propósito: quién pide el snapshot y qué pasa si un delta llega
## fuera de lugar. Están explicadas abajo.
##
## **Por qué no un MultiplayerSynchronizer:** solo maneja primitivas y tipos
## built-in, y un inventario es una lista anidada (docs/netcode.md → "Advertencia
## para v0.3"). Lo que sí puede cruzar la red son los argumentos de un @rpc, que
## Godot encodea como Variant — ver el comentario de Inventory.serialize().

## El ID del host en Godot es siempre 1.
const HOST_PEER_ID: int = 1

## Qué inventario replica. Va por NodePath y no por `@export var inventory:
## Inventory` porque un export de nodo no se resuelve cuando el .tscn se escribe a
## mano y queda en null (mismo motivo que debug_overlay.gd:17-19).
@export var inventory_path: NodePath = ^".."

var _inventory: Inventory

## Si ya llegó el snapshot inicial.
##
## En el cliente arranca en false y **todo delta que llegue antes se descarta**.
## No se pierde nada: el canal es reliable y ordenado, así que un delta anterior al
## snapshot ya está adentro del snapshot, y uno posterior llega después. Sin esta
## bandera, un delta que llegue primero se aplicaría por índice sobre una lista
## vacía.
var _synced: bool = false


# La autoridad de este nodo es el host, siempre, en las tres máquinas.
#
# **Esto no es opcional y es la trampa más cara de este archivo.** Cuando el
# InventorySync cuelga del jugador, player.gd::_enter_tree() ya llamó
# set_multiplayer_authority(name.to_int()) con recursive en true y se llevó este
# nodo al peer dueño. Con la autoridad en el cliente, los @rpc("authority") de
# abajo dejan afuera al host y no se pueden llamar nunca.
#
# Es exactamente el error que v0.2 casi comete con la vida (docs/netcode.md →
# "Paso 2: el segundo Synchronizer"), y se arregla igual: _enter_tree() va de padre
# a hijo, así que esta llamada corre después y gana.
func _enter_tree() -> void:
	set_multiplayer_authority(HOST_PEER_ID)


func _ready() -> void:
	_inventory = get_node_or_null(inventory_path) as Inventory
	if _inventory == null:
		push_error("[inventory] InventorySync sin Inventory en '%s'" % inventory_path)
		return

	if multiplayer.is_server():
		_synced = true
		_connect_deltas()
		return

	# **El snapshot lo pide el cliente, no lo empuja el host.**
	#
	# El ejemplo del addon lo manda al recibir multiplayer.peer_connected, y eso
	# tiene la misma carrera que v0.1 (docs/netcode.md → "v0.1 sí tiene un RPC"):
	# el paquete sale antes de que el nodo exista del otro lado y se descarta. Acá
	# el que pide ES el nodo que tiene que existir, así que la carrera no puede
	# pasar.
	request_snapshot.rpc_id(HOST_PEER_ID)


## La llama un cliente apenas su nodo entra al árbol. Corre en el host.
@rpc("any_peer", "reliable")
func request_snapshot() -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	# El host no se contesta a sí mismo: apply_snapshot es "call_remote", y
	# verificado en 4.7.1 un rpc_id() apuntándose a uno mismo con ese flag no se
	# ejecuta, devuelve error 31 y ensucia la consola.
	if sender_id == HOST_PEER_ID:
		return
	apply_snapshot.rpc_id(sender_id, _inventory.serialize())


## El estado completo. La manda el host al cliente que lo pidió.
@rpc("authority", "call_remote", "reliable")
func apply_snapshot(data: Dictionary) -> void:
	_inventory.deserialize(data)
	_synced = true


## Un stack nuevo. La manda el host a todos.
@rpc("authority", "call_remote", "reliable")
func apply_stack_added(index: int, item_id: String, amount: int) -> void:
	if not _synced:
		return
	# El host solo agrega al final. Un índice que no sea el final significa que las
	# dos listas ya divergieron.
	if index != _inventory.stacks.size():
		_resync("stack_added en %d teniendo %d stacks" % [index, _inventory.stacks.size()])
		return
	_inventory.insert_stack(index, item_id, amount)


## Le cambió la cantidad a un stack. La manda el host a todos.
@rpc("authority", "call_remote", "reliable")
func apply_stack_updated(index: int, amount: int) -> void:
	if not _synced:
		return
	if index < 0 or index >= _inventory.stacks.size():
		_resync("stack_updated en %d teniendo %d stacks" % [index, _inventory.stacks.size()])
		return
	_inventory.set_stack_amount(index, amount)


## Se fue un stack. La manda el host a todos.
@rpc("authority", "call_remote", "reliable")
func apply_stack_removed(index: int) -> void:
	if not _synced:
		return
	if index < 0 or index >= _inventory.stacks.size():
		_resync("stack_removed en %d teniendo %d stacks" % [index, _inventory.stacks.size()])
		return
	_inventory.erase_stack(index)


## Cambió la capacidad máxima. La manda el host a todos.
@rpc("authority", "call_remote", "reliable")
func apply_capacity(capacity: float) -> void:
	if not _synced:
		return
	_inventory.capacity = capacity


# En el host: cada señal del inventario sale como un delta.
#
# Se conecta solo en el host. En el cliente estas señales igual se emiten —las
# emite aplicar un delta— y las escucha la UI; lo que no pasa es que un cliente
# reenvíe nada.
func _connect_deltas() -> void:
	_inventory.stack_added.connect(_on_stack_added)
	_inventory.stack_updated.connect(_on_stack_updated)
	_inventory.stack_removed.connect(_on_stack_removed)
	_inventory.capacity_changed.connect(_on_capacity_changed)


func _on_stack_added(index: int) -> void:
	var stack: ItemStack = _inventory.stacks[index]
	apply_stack_added.rpc(index, stack.item_id, stack.amount)


func _on_stack_updated(index: int) -> void:
	apply_stack_updated.rpc(index, _inventory.stacks[index].amount)


func _on_stack_removed(index: int) -> void:
	apply_stack_removed.rpc(index)


func _on_capacity_changed(capacity: float) -> void:
	apply_capacity.rpc(capacity)


# Un delta que no cierra con la lista local. No se intenta adivinar: se avisa y se
# vuelve a pedir el estado completo.
#
# Seguir aplicando deltas encima de dos listas que ya divergieron es lo que
# convierte un bug de red en "a veces me falta un item", que es exactamente la
# clase de bug que docs/netcode.md dice que la autoridad única existe para evitar.
# Acá se paga un snapshot y se sabe que pasó.
func _resync(reason: String) -> void:
	push_error("[inventory] delta fuera de lugar (%s): pido el estado completo" % reason)
	_synced = false
	request_snapshot.rpc_id(HOST_PEER_ID)
