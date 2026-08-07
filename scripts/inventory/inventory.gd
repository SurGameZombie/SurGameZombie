class_name Inventory
extends Node

## Un inventario limitado por peso: una lista plana de stacks y una capacidad en
## kg. Sin slots, sin grilla, sin posiciones (docs/design.md → "Inventario:
## limitado por peso").
##
## Lo usan el jugador y los contenedores del mundo, sin diferencia: un contenedor
## es este mismo nodo con otra capacidad.
##
## **Este script no tiene una sola línea de red, a propósito.** Toda la replicación
## vive en inventory_sync.gd, que se cuelga de las señales de acá. Dos razones:
## este archivo se puede instanciar en un test de gdUnit4 sin peer —que es
## justamente la "lógica pura" que docs/plan.md §5 dice que hay que testear—, y el
## día que algo replique mal se sabe en cuál de los dos archivos mirar.
##
## Quién puede llamar a add() y remove() tampoco se decide acá: es estado del host
## (.claude/rules/netcode.md), y quien lo hace cumplir es inventory_requests.gd.
##
## Lo único de red que tiene son las tres líneas de _enter_tree(), que declaran que
## este nodo es del host. El porqué está ahí abajo.

## Un stack nuevo al final de la lista. La escucha inventory_sync.gd para mandar
## el delta.
signal stack_added(index: int)

## A un stack le cambió la cantidad, sin cambiar de lugar.
signal stack_updated(index: int)

## Un stack llegó a cero y se fue de la lista. Los índices posteriores se corren.
signal stack_removed(index: int)

## Cambió la capacidad máxima: equiparon o desequiparon la mochila.
signal capacity_changed(capacity: float)

## La lista se reemplazó entera de una. La emite deserialize() y nada más: es lo
## que pasa cuando un cliente recibe el snapshot completo, y ahí los índices
## viejos no significan nada.
signal contents_changed()

## Entraron unidades de un item. Es la señal de gameplay —para logs y para la UI—,
## no la de replicación: no dice en qué stacks cayeron.
signal item_added(item_id: String, amount: int)

## Salieron unidades de un item.
signal item_removed(item_id: String, amount: int)

## El ID del host en Godot es siempre 1.
const HOST_PEER_ID: int = 1

## El catálogo, como const y no como autoload: es dato estático, idéntico en las
## tres máquinas y sin nada que replicar (.claude/rules/gdscript.md → pitfall 6).
const CATALOG: ItemCatalog = preload("res://resources/item_catalog.tres")

## Margen para que la división por peso no se coma una unidad por error de coma
## flotante. Son 0.1 gramos: irrelevante para cualquier balance, y suficiente para
## que un "25.0 - 24.0" que en float da 0.99999994 no responda "no entra".
const WEIGHT_EPSILON: float = 0.0001

## Cuánto podés cargar sin mochila, en kg.
## docs/design.md:163 — "| Capacidad de carga sin mochila | 25 kg |".
@export var base_capacity: float = 25.0

## Cuánto podés cargar con la mochila equipada, en kg.
## docs/design.md:164 — "| Capacidad de carga con mochila | 40 kg |".
##
## Es el total, no un bonus: los dos números están escritos en el doc de diseño y
## el 15 de diferencia no está escrito en ningún lado.
@export var backpack_capacity: float = 40.0

## Los stacks, en el orden en que se fueron creando. El índice es lo que viaja en
## los deltas de red, así que las dos máquinas tienen que aplicar las mismas
## operaciones en el mismo orden para que signifique lo mismo.
var stacks: Array[ItemStack] = []

## La capacidad que rige ahora, en kg. La escribe el host al equipar o desequipar
## la mochila; en el cliente la pisa el snapshot.
##
## Tiene setter para que asignarla emita la señal sí o sí: si fuera una variable
## pelada, un `inventory.capacity = 40.0` desde cualquier lado dejaría la UI y a
## los clientes mostrando el número viejo, y eso no da error en ningún lado.
var capacity: float = 25.0:
	set(value):
		if is_equal_approx(capacity, value):
			return
		capacity = value
		capacity_changed.emit(capacity)


# La autoridad de este nodo es el host, siempre, en las tres máquinas.
#
# Cuando el inventario cuelga del jugador, player.gd::_enter_tree() ya llamó
# set_multiplayer_authority(name.to_int()) con recursive en true y se lo llevó al
# peer dueño. Esta llamada corre después —_enter_tree() va de padre a hijo— y lo
# devuelve al host, exactamente como hace player_stats.gd:69-70 con las stats.
#
# Hoy nadie LEE la autoridad de este nodo: los @rpc los tiene su hijo InventorySync,
# y acá no hay ni RPCs ni MultiplayerSynchronizer. Se declara igual, por dos razones.
#
# La primera es que el contenido de un inventario es estado del host, y en este
# proyecto la autoridad no es un permiso sino la dirección en la que fluyen los datos
# (docs/netcode.md → "Herramientas de Godot"). Dejarlo marcado como del cliente es
# decir algo falso sobre el árbol, y lo primero que hace alguien debuggeando un bug
# de inventario es mirar de quién es cada nodo.
#
# La segunda es que la alternativa era un comentario avisando "si algún día le ponés
# un Synchronizer, acordate de esto". Explicar no es hacer cumplir
# (docs/retrospectiva-v0.2.md → B6): la primera versión de este archivo tenía ese
# comentario en vez de estas tres líneas, y lo que lo cambió fue ver el árbol real.
func _enter_tree() -> void:
	set_multiplayer_authority(HOST_PEER_ID)


# La capacidad arranca en la de base, y se fija acá y no en la declaración por lo
# mismo que player_stats.gd:82 con la vida: los valores de @export de un .tscn se
# aplican DESPUÉS de construir el objeto, así que un `var capacity := base_capacity`
# se quedaría con el 25.0 del script y cambiar base_capacity desde el Inspector no
# haría nada.
func _ready() -> void:
	reset_capacity()


## Cuánto pesa todo lo que hay adentro, en kg. La llaman la UI y el chequeo de
## capacidad.
##
## Se recalcula en vez de llevarse acumulada: son diez stacks como mucho, y un
## total acumulado es un segundo estado que se puede desincronizar del primero.
func get_weight() -> float:
	var total: float = 0.0
	for stack: ItemStack in stacks:
		var definition: ItemDefinition = CATALOG.get_item(stack.item_id)
		if definition == null:
			continue
		total += definition.weight * float(stack.amount)
	return total


## Cuántas unidades de este item entran por peso, hasta un máximo de `wanted`.
## Devuelve 0 si el id no existe.
##
## **Este es el único lugar del proyecto donde se decide si algo entra.** No mira
## el equipo ni la mochila: mira `capacity`, y quién mueve `capacity` es problema
## de otro. Que el chequeo esté en un solo lugar es lo que hace que agregar una
## fuente de capacidad no sea tocar cada operación del inventario.
func space_for(item_id: String, wanted: int) -> int:
	var definition: ItemDefinition = CATALOG.get_item(item_id)
	if definition == null or wanted <= 0:
		return 0
	# Un item sin peso no puede llenar nada, así que entran todos. Hoy no hay
	# ninguno; existe para que un peso en 0 por error no divida por cero.
	if definition.weight <= 0.0:
		return wanted
	var free: float = capacity - get_weight()
	if free <= 0.0:
		return 0
	return mini(wanted, floori((free + WEIGHT_EPSILON) / definition.weight))


## Si entra la cantidad entera. La llama el host antes de aceptar un pedido.
func has_space_for(item_id: String, amount: int = 1) -> bool:
	return space_for(item_id, amount) == amount


## Cuántas unidades de este item hay en total, sumando todos los stacks.
func amount_of(item_id: String) -> int:
	var total: int = 0
	for stack: ItemStack in stacks:
		if stack.item_id == item_id:
			total += stack.amount
	return total


## Si no hay nada adentro.
func is_empty() -> bool:
	return stacks.is_empty()


## Mete unidades de un item y devuelve **cuántas NO entraron**. Con 0 entró todo.
##
## Devuelve el sobrante en vez de un bool a propósito: quien llama necesita saber
## qué hacer con lo que no entró —dejarlo en el contenedor, tirarlo al piso— y un
## bool le haría recalcular la cuenta que esta función ya hizo.
func add(item_id: String, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	var to_add: int = space_for(item_id, amount)
	if to_add <= 0:
		return amount
	_distribute(item_id, to_add)
	item_added.emit(item_id, to_add)
	return amount - to_add


## Saca unidades de un item y devuelve **cuántas NO se pudieron sacar**. Con 0 se
## sacó todo lo pedido.
func remove(item_id: String, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	var left: int = amount
	# Se recorre de atrás para adelante por dos razones. Una es de gameplay: sacás
	# primero del stack más nuevo, que es el que quedó a medio llenar. La otra es
	# que borrar el último stack no corre ningún índice, y los stacks que se vacían
	# suelen ser los últimos. Cuando sí se borra uno del medio, los índices
	# posteriores se corren igual — el cliente aplica el mismo remove_at() en el
	# mismo orden, así que las dos listas quedan iguales.
	for index: int in range(stacks.size() - 1, -1, -1):
		if left <= 0:
			break
		left = _take_from_stack(index, item_id, left)
	var removed: int = amount - left
	if removed > 0:
		item_removed.emit(item_id, removed)
	return left


## Vacía el inventario entero. La usa el host al morir un jugador.
func clear() -> void:
	for index: int in range(stacks.size() - 1, -1, -1):
		stacks.remove_at(index)
		stack_removed.emit(index)


## Devuelve la capacidad a la de base, sin mochila. La llaman _ready() y el host
## al desequipar.
func reset_capacity() -> void:
	capacity = base_capacity


## Sube la capacidad a la de la mochila. La llama el host al equipar.
func apply_backpack_capacity() -> void:
	capacity = backpack_capacity


## Mete un stack ya armado en una posición. La usa inventory_sync.gd al aplicar un
## delta del host; el juego normal usa add(), que decide sola dónde va.
##
## Las tres de abajo —insert_stack, set_stack_amount, erase_stack— existen para
## que la capa de red no meta la mano adentro de `stacks` sin emitir señales: si lo
## hiciera, la UI del cliente mostraría el contenido viejo y no habría error en
## ningún lado.
func insert_stack(index: int, item_id: String, amount: int) -> void:
	if index < 0 or index > stacks.size():
		push_error("[inventory] insert_stack fuera de rango: %d con %d stacks" % [index, stacks.size()])
		return
	stacks.insert(index, ItemStack.new(item_id, amount))
	stack_added.emit(index)


## Le cambia la cantidad a un stack. Misma razón que insert_stack().
func set_stack_amount(index: int, amount: int) -> void:
	if index < 0 or index >= stacks.size():
		push_error("[inventory] set_stack_amount fuera de rango: %d con %d stacks" % [index, stacks.size()])
		return
	stacks[index].amount = amount
	stack_updated.emit(index)


## Saca un stack por índice. Misma razón que insert_stack().
func erase_stack(index: int) -> void:
	if index < 0 or index >= stacks.size():
		push_error("[inventory] erase_stack fuera de rango: %d con %d stacks" % [index, stacks.size()])
		return
	stacks.remove_at(index)
	stack_removed.emit(index)


## El inventario entero como primitivas, para mandarlo por RPC o guardarlo.
##
## **Dictionary y no PackedByteArray, y el porqué importa:** docs/netcode.md →
## "Advertencia para v0.3" decía que había que encodear el inventario a mano en un
## PackedByteArray. Eso es cierto del MultiplayerSynchronizer, que solo maneja
## primitivas y tipos built-in — y es por eso que este nodo NO tiene uno. Pero los
## argumentos de un @rpc los encodea Godot como Variant, y Dictionary y Array son
## Variant, así que la estructura anidada viaja sola.
##
## El límite real es otro y sí manda acá: **"RPCs do not serialize Objects"**
## (documentación de high-level multiplayer de Godot). Lo que no puede viajar no es
## el anidamiento: es ItemStack, que es un Resource, o sea un Object. Por eso esto
## aplana cada stack a `[item_id, amount]` en vez de mandar los stacks.
##
## Prender `allow_object_decoding` en el SceneMultiplayer los dejaría viajar, y la
## propia documentación lo marca como riesgo de ejecución de código arbitrario. No
## se toca.
func serialize() -> Dictionary:
	var data: Array = []
	for stack: ItemStack in stacks:
		data.append([stack.item_id, stack.amount])
	return {"stacks": data, "capacity": capacity}


## Reemplaza el contenido entero por el de un serialize(). La llama el cliente al
## recibir el snapshot del host.
##
## Emite contents_changed() y ninguna señal por stack: después de esto los índices
## viejos no significan nada, así que quien escuche tiene que repintar todo.
func deserialize(data: Dictionary) -> void:
	if not data.has("stacks") or not data.has("capacity"):
		push_error("[inventory] snapshot inválido: %s" % data)
		return
	stacks.clear()
	var entries: Array = data["stacks"]
	for entry: Array in entries:
		stacks.append(ItemStack.new(entry[0] as String, entry[1] as int))
	capacity = data["capacity"] as float
	contents_changed.emit()


# Reparte una cantidad que YA se sabe que entra: primero completando stacks del
# mismo item que estén a medio llenar, después abriendo stacks nuevos.
#
# Se completa antes de abrir para que treinta balas sean una línea en la UI y no
# treinta. Sin esto, cada pickup abriría un stack propio.
func _distribute(item_id: String, amount: int) -> void:
	var definition: ItemDefinition = CATALOG.get_item(item_id)
	var stack_size: int = definition.stack_size()
	var left: int = amount

	for index: int in stacks.size():
		if left <= 0:
			break
		var stack: ItemStack = stacks[index]
		if stack.item_id != item_id or stack.amount >= stack_size:
			continue
		var fits: int = mini(left, stack_size - stack.amount)
		stack.amount += fits
		left -= fits
		stack_updated.emit(index)

	while left > 0:
		var chunk: int = mini(left, stack_size)
		stacks.append(ItemStack.new(item_id, chunk))
		left -= chunk
		stack_added.emit(stacks.size() - 1)


# Saca de un stack lo que pueda y devuelve cuánto sigue faltando.
func _take_from_stack(index: int, item_id: String, wanted: int) -> int:
	var stack: ItemStack = stacks[index]
	if stack.item_id != item_id:
		return wanted
	var taken: int = mini(wanted, stack.amount)
	stack.amount -= taken
	if stack.amount <= 0:
		stacks.remove_at(index)
		stack_removed.emit(index)
	else:
		stack_updated.emit(index)
	return wanted - taken
