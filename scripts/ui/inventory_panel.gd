extends CanvasLayer

## UI mínima del inventario. **Greybox de UI, como el greybox del mapa:** existe
## para poder jugar el inventario, no para que se vea bien. Cómo se ve de verdad
## se decide en v0.6 y es de Mathi (.claude/rules/limites.md → "Lo que no es
## tuyo").
##
## Muestra dos columnas —lo que llevás encima y lo que hay en el contenedor que
## tengas al lado— y el número que este milestone existe para probar: peso actual
## contra capacidad.
##
## **Este script no decide nada.** Cada botón manda un pedido al host y espera; lo
## que se ve sale de las señales del Inventory, que las escribe el host y bajan
## replicadas (.claude/rules/netcode.md → patrón 2). Si el host rechaza, acá no
## pasa nada y el número no se mueve, que es exactamente lo que tiene que pasar.

## Dónde cuelgan los jugadores.
@export var players_path: NodePath = ^"../Players"

## Dónde viven las RPC de pedido.
@export var requests_path: NodePath = ^"../InventoryRequests"

## El inventario del jugador local. Se resuelve tarde: cuando este nodo entra al
## árbol, el host todavía no spawneó a nadie.
var _mine: Inventory

## El contenedor al alcance de la mano, o null.
var _container: StorageContainer

## Si hay que repintar. Se marca desde las señales y se consume en _process, en vez
## de repintar adentro del handler: repintar borra los botones, y borrar un botón
## mientras se está procesando su propio `pressed` es la re-entrancia de señales
## del pitfall 5 de .claude/rules/gdscript.md.
var _dirty: bool = true

@onready var _players: Node3D = get_node(players_path)
@onready var _requests: Node = get_node(requests_path)
@onready var _root: Control = $Root
@onready var _mine_title: Label = $Root/Panel/Columns/Mine/Title
@onready var _mine_items: VBoxContainer = $Root/Panel/Columns/Mine/Items
@onready var _backpack_button: Button = $Root/Panel/Columns/Mine/BackpackButton
@onready var _container_title: Label = $Root/Panel/Columns/Container/Title
@onready var _container_items: VBoxContainer = $Root/Panel/Columns/Container/Items


func _ready() -> void:
	_backpack_button.pressed.connect(_on_backpack_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("toggle_inventory"):
		return
	_root.visible = not _root.visible
	# El mouse se suelta para poder clickear y se vuelve a capturar al cerrar. El
	# Root cubre la pantalla entera con mouse_filter en STOP a propósito: si no,
	# un click al lado del panel llegaría a player.gd y recapturaría el mouse con
	# el inventario abierto.
	Input.mouse_mode = (
		Input.MOUSE_MODE_VISIBLE if _root.visible else Input.MOUSE_MODE_CAPTURED
	)
	_dirty = true


func _process(_delta: float) -> void:
	if not _root.visible:
		return
	_resolve_mine()
	_resolve_container()
	if _dirty:
		_dirty = false
		_rebuild()


## Marca que hay que repintar. Es pública porque la conectan las señales del
## Inventory, que traen argumentos distintos según cuál sea.
func mark_dirty(_a: Variant = null, _b: Variant = null) -> void:
	_dirty = true


# El jugador local recién existe cuando el host lo spawnea, así que esto se
# reintenta hasta que aparece en vez de resolverse en _ready().
func _resolve_mine() -> void:
	if _mine != null:
		return
	var player: Node = _players.get_node_or_null(NodePath(str(multiplayer.get_unique_id())))
	if player == null:
		return
	_mine = player.get_node_or_null("Inventory") as Inventory
	if _mine != null:
		_connect(_mine)


# El contenedor más cercano que esté al alcance, o null.
#
# El rango sale de InventoryRequests.CONTAINER_RANGE, o sea de la MISMA constante
# que usa el host para validar, leída desde acá. No es duplicar el número: es una
# constante con dos lectores, horneada igual en las tres máquinas. Escribir un 2.5
# a mano acá sí serían dos fuentes de verdad, y se desincronizarían apenas alguien
# tocara una.
func _resolve_container() -> void:
	if _mine == null:
		return
	var me: Node3D = _mine.get_parent() as Node3D
	var best: StorageContainer = null
	var best_distance: float = InventoryRequests.CONTAINER_RANGE
	for node: Node in get_tree().get_nodes_in_group(StorageContainer.GROUP):
		var candidate: StorageContainer = node as StorageContainer
		if candidate == null:
			continue
		var distance: float = me.global_position.distance_to(candidate.global_position)
		if distance <= best_distance:
			best_distance = distance
			best = candidate

	if best == _container:
		return
	if _container != null:
		_disconnect(_container.inventory)
	_container = best
	if _container != null:
		_connect(_container.inventory)
	_dirty = true


func _connect(inventory: Inventory) -> void:
	inventory.contents_changed.connect(mark_dirty)
	inventory.stack_added.connect(mark_dirty)
	inventory.stack_updated.connect(mark_dirty)
	inventory.stack_removed.connect(mark_dirty)
	inventory.capacity_changed.connect(mark_dirty)


# Se desconecta al alejarse de un contenedor. Sin esto la conexión se duplicaría
# al volver a acercarse (pitfall 7 de .claude/rules/gdscript.md), y encima
# quedaría escuchando a un nodo que ya no se está mirando.
func _disconnect(inventory: Inventory) -> void:
	inventory.contents_changed.disconnect(mark_dirty)
	inventory.stack_added.disconnect(mark_dirty)
	inventory.stack_updated.disconnect(mark_dirty)
	inventory.stack_removed.disconnect(mark_dirty)
	inventory.capacity_changed.disconnect(mark_dirty)


func _rebuild() -> void:
	_rebuild_mine()
	_rebuild_container()


func _rebuild_mine() -> void:
	if _mine == null:
		_mine_title.text = "ENCIMA — sin jugador"
		return
	_mine_title.text = "ENCIMA — %.2f / %.1f kg" % [_mine.get_weight(), _mine.capacity]
	var equipped: bool = is_equal_approx(_mine.capacity, _mine.backpack_capacity)
	_backpack_button.text = "Sacarse la mochila" if equipped else "Equipar mochila"
	_backpack_button.disabled = not equipped and _mine.amount_of("backpack") <= 0
	_fill(_mine_items, _mine, false)


func _rebuild_container() -> void:
	if _container == null:
		_container_title.text = "SIN CONTENEDOR AL ALCANCE"
		_clear(_container_items)
		return
	var inventory: Inventory = _container.inventory
	_container_title.text = "%s — %.2f / %.1f kg" % [
		_container.container_id, inventory.get_weight(), inventory.capacity,
	]
	_fill(_container_items, inventory, true)


# Un botón por stack. `taking` en true saca del contenedor; en false, guarda.
func _fill(box: VBoxContainer, inventory: Inventory, taking: bool) -> void:
	_clear(box)
	# Con el contenedor lejos no se puede mover nada, pero el inventario propio se
	# sigue mostrando: mirar cuánto pesás no debería necesitar estar al lado de un
	# armario.
	var enabled: bool = _container != null
	for stack: ItemStack in inventory.stacks:
		var definition: ItemDefinition = Inventory.CATALOG.get_item(stack.item_id)
		var label: String = definition.display_name if definition != null else stack.item_id
		var button: Button = Button.new()
		button.text = "%s x%d" % [label, stack.amount]
		button.disabled = not enabled
		button.pressed.connect(_on_item_pressed.bind(stack.item_id, stack.amount, taking))
		box.add_child(button)


func _clear(box: VBoxContainer) -> void:
	for child: Node in box.get_children():
		child.queue_free()
		box.remove_child(child)


# Un click mueve el stack entero. Partirlo es una decisión de UI que todavía no
# está tomada, y el host ya acepta cualquier cantidad.
func _on_item_pressed(item_id: String, amount: int, taking: bool) -> void:
	if _container == null:
		return
	if taking:
		_requests.request_take_from_container.rpc_id(1, _container.container_id, item_id, amount)
	else:
		_requests.request_put_in_container.rpc_id(1, _container.container_id, item_id, amount)


func _on_backpack_pressed() -> void:
	if _mine == null:
		return
	var equipped: bool = is_equal_approx(_mine.capacity, _mine.backpack_capacity)
	_requests.request_equip_backpack.rpc_id(1, not equipped)
