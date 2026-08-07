class_name StorageContainer
extends StaticBody3D

## Un contenedor del mundo: un armario, una estantería, la guantera de un auto.
## Por dentro no es nada especial — es el mismo nodo Inventory que usa el jugador,
## con otra capacidad.
##
## Su contenido es estado del host (.claude/rules/netcode.md) y baja replicado por
## el InventorySync que cuelga del Inventory. Un cliente nunca lo modifica: pide
## por RPC a inventory_requests.gd.

## El grupo donde se registran todos. inventory_requests.gd lo recorre para
## resolver un container_id, en vez de conocer dónde cuelgan en el árbol.
##
## Mismo patrón que el grupo "players" de player.gd:108, y por lo mismo: el árbol
## de escena del cliente no tiene por qué ser idéntico al del host.
const GROUP: StringName = &"containers"

## ID propio y estable, único en todo el mapa. **No se cambia nunca.**
##
## Va por @export y no por NodePath a propósito: el save de v0.5 va a buscar cada
## contenedor por este ID, y una ruta en el árbol cambia si alguien renombra o
## mueve un nodo. El síntoma sería "el armario que había vaciado volvió a tener
## loot", que no se parece en nada a su causa (docs/netcode.md → "Los contenedores
## necesitan ID persistente, no NodePath").
##
## Queda escrito en el .tscn, así que se revisa en el diff.
@export var container_id: String = ""

## Cuánto entra acá adentro, en kg. PROVISORIO, igual que los pesos de los items:
## es balance y no salió de jugarlo (.claude/rules/limites.md → "Lo que no es
## tuyo").
@export var capacity: float = 60.0

## Con qué arranca adentro. Una entrada por stack, con formato `"item_id:cantidad"`
## — por ejemplo `"ammo_9mm:45"`.
##
## **ANDAMIO. Lo reemplaza la loot table de v0.5** (`docs/plan.md` → v0.5), que es
## la que va a decidir de verdad qué hay en cada contenedor. Existe porque sin esto
## no hay ninguna forma de meter un item en el juego: nada llama a `add()` todavía,
## así que el inventario quedaría montado y sin poder ejercerse ni una vez.
##
## Cuando entre la loot table, se borra este campo y el `_seed_debug_contents()` de
## abajo, y las entradas que hayan quedado escritas en `yard.tscn` se van con él.
##
## Va por `@export` y no hardcodeado para que se escriba en el `.tscn` y se revise
## en el diff, igual que `container_id`.
@export var debug_contents: PackedStringArray = PackedStringArray()

@onready var inventory: Inventory = $Inventory


func _ready() -> void:
	add_to_group(GROUP)
	_check_id()
	# La capacidad la fija el contenedor y no el Inventory, para que dos
	# contenedores del mismo mapa puedan tener capacidades distintas sin duplicar
	# la escena. Corre en las tres máquinas: es dato de la escena, no estado.
	inventory.base_capacity = capacity
	inventory.reset_capacity()
	# Va ÚLTIMO y no antes: sembrar con la capacidad todavía en el default de
	# Inventory (25 kg) dejaría afuera lo que sí entra en los 60 de este contenedor,
	# y el síntoma sería "el armario arranca con menos de lo que dice yard.tscn".
	_seed_debug_contents()


# ANDAMIO — se borra junto con debug_contents cuando entre la loot table de v0.5.
#
# Corre SOLO en el host: el contenido de un contenedor es estado del host
# (.claude/rules/netcode.md), y los clientes lo reciben por el snapshot de
# InventorySync. Si corriera en las tres máquinas, cada una sembraría su propia
# copia y después el snapshot la pisaría — o peor, no la pisaría y quedarían
# distintas.
func _seed_debug_contents() -> void:
	if not multiplayer.is_server():
		return
	for entry: String in debug_contents:
		var parts: PackedStringArray = entry.split(":", false)
		if parts.size() != 2 or not parts[1].is_valid_int():
			push_error("[inventory] '%s' de %s no tiene formato item_id:cantidad" % [
				entry, get_path(),
			])
			continue
		var item_id: String = parts[0]
		if not Inventory.CATALOG.has_item(item_id):
			push_error("[inventory] '%s' de %s no existe en el catálogo" % [item_id, get_path()])
			continue
		# El sobrante no es un error: puede ser que el contenedor no dé para tanto,
		# y eso es una decisión de quien escribió el .tscn. Se avisa y se sigue.
		var leftover: int = inventory.add(item_id, parts[1].to_int())
		if leftover > 0:
			print("[inventory] a '%s' no le entraron %d de '%s' por peso" % [
				container_id, leftover, item_id,
			])


# Un container_id vacío o repetido no da error en el momento: da un contenedor que
# el save de v0.5 no encuentra, o dos que se pisan. Misma razón por la que
# ItemCatalog revienta con un item_id duplicado.
#
# No usa assert() porque acá el chequeo depende de qué otros nodos ya entraron al
# árbol, y eso lo hace sensible al orden de carga de la escena: un assert
# convertiría un problema de datos en un cuelgue difícil de leer. El push_error
# aparece en el panel Debugger igual.
func _check_id() -> void:
	if container_id.is_empty():
		push_error("[inventory] contenedor sin container_id en %s" % get_path())
		return
	for other: Node in get_tree().get_nodes_in_group(GROUP):
		if other == self:
			continue
		var container: StorageContainer = other as StorageContainer
		if container != null and container.container_id == container_id:
			push_error("[inventory] container_id duplicado: '%s' en %s y en %s" % [
				container_id, container.get_path(), get_path(),
			])
			return
