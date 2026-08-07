extends GdUnitTestSuite

## Los pedidos del cliente al host: qué acepta y qué rechaza.
##
## Arma un árbol mínimo a mano —Players, un jugador, InventoryRequests y un
## contenedor— en vez de cargar world.tscn: así no entran el zombie ni el NavMesh,
## que no tienen nada que ver con esto.
##
## Los pedidos se mandan por rpc_id(1) y no llamando la función directo, porque no
## es lo mismo: llamada directo, get_remote_sender_id() devuelve 0 y el host no
## encuentra a nadie. Por rpc_id, incluso cuando el host se lo manda a sí mismo,
## devuelve el ID local (verificado en 4.7.1, ver el comentario de
## world.gd::request_damage).
##
## **Esto NO prueba que un RPC cruce el cable.** Corre en un solo proceso: prueba
## las reglas del host, no la red. Eso lo cierra el playtest de dos instancias.

## El jugador local en un proceso sin peer es el 1.
const LOCAL_ID: int = 1

const CONTAINER_ID: String = "test_shelf"

var _world: Node3D
var _player: Node3D
var _mine: Inventory
var _requests: InventoryRequests
var _container: StorageContainer


func before_test() -> void:
	_world = auto_free(Node3D.new())
	_world.name = "World"
	var players: Node3D = Node3D.new()
	players.name = "Players"
	_world.add_child(players)

	_requests = load("res://scripts/inventory/inventory_requests.gd").new() as InventoryRequests
	_requests.name = "InventoryRequests"
	_world.add_child(_requests)

	_container = load(
		"res://scenes/items/storage_container.tscn"
	).instantiate() as StorageContainer
	_container.container_id = CONTAINER_ID
	_container.debug_contents = PackedStringArray(["ammo_9mm:45", "crowbar:1"])
	_container.position = Vector3.ZERO
	_world.add_child(_container)

	add_child(_world)

	_player = load("res://scenes/player/player.tscn").instantiate()
	_player.name = str(LOCAL_ID)
	players.add_child(_player)
	_mine = _player.get_node("Inventory") as Inventory


func after_test() -> void:
	_player = null
	_mine = null
	_requests = null
	_container = null
	_world = null


# Estando al lado, el host acepta y el item cambia de inventario.
func test_sacar_de_un_contenedor_al_lado_funciona() -> void:
	_player.global_position = Vector3(0, 0, 1.0)
	_requests.request_take_from_container.rpc_id(LOCAL_ID, CONTAINER_ID, "crowbar", 1)

	assert_int(_mine.amount_of("crowbar")).is_equal(1)
	assert_int(_container.inventory.amount_of("crowbar")).is_equal(0)


# La regla de docs/design.md que este milestone existe para probar.
func test_estando_lejos_el_host_rechaza() -> void:
	_player.global_position = Vector3(0, 0, 30.0)
	_requests.request_take_from_container.rpc_id(LOCAL_ID, CONTAINER_ID, "crowbar", 1)

	assert_int(_mine.amount_of("crowbar")).is_equal(0)
	assert_int(_container.inventory.amount_of("crowbar")).is_equal(1)


# El container_id lo manda el cliente, así que puede ser inventado.
func test_un_container_id_que_no_existe_se_rechaza() -> void:
	_player.global_position = Vector3(0, 0, 1.0)
	_requests.request_take_from_container.rpc_id(LOCAL_ID, "no_existe", "crowbar", 1)

	assert_bool(_mine.is_empty()).is_true()
	assert_int(_container.inventory.amount_of("crowbar")).is_equal(1)


# El item_id también lo manda el cliente.
func test_un_item_id_que_no_existe_se_rechaza() -> void:
	_player.global_position = Vector3(0, 0, 1.0)
	_requests.request_take_from_container.rpc_id(LOCAL_ID, CONTAINER_ID, "no_existe", 1)

	assert_bool(_mine.is_empty()).is_true()


# Un caído no saquea.
func test_un_caido_no_saquea() -> void:
	_player.global_position = Vector3(0, 0, 1.0)
	var stats: PlayerStats = _player.get_node("Stats")
	stats.is_downed = true
	_requests.request_take_from_container.rpc_id(LOCAL_ID, CONTAINER_ID, "crowbar", 1)

	assert_bool(_mine.is_empty()).is_true()


# **La garantía que más importa de todo el archivo:** si el destino no da, lo que
# no entra NO desaparece. Mueve metiendo primero y sacando después, con exactamente
# lo que entró — al revés, un destino lleno haría evaporar items sin dejar rastro.
func test_lo_que_no_entra_por_peso_se_queda_en_el_contenedor() -> void:
	_player.global_position = Vector3(0, 0, 1.0)
	# 45 balas pesan 0.54 kg y entran; el jugador arranca con 25 kg de capacidad,
	# así que se le baja a mano para forzar que no entre casi nada.
	_mine.capacity = 0.2
	_requests.request_take_from_container.rpc_id(LOCAL_ID, CONTAINER_ID, "ammo_9mm", 45)

	var arriba: int = _mine.amount_of("ammo_9mm")
	var abajo: int = _container.inventory.amount_of("ammo_9mm")
	assert_int(arriba).is_less(45)
	assert_int(arriba + abajo).is_equal(45)


func test_guardar_en_el_contenedor_es_el_camino_de_vuelta() -> void:
	_player.global_position = Vector3(0, 0, 1.0)
	_requests.request_take_from_container.rpc_id(LOCAL_ID, CONTAINER_ID, "crowbar", 1)
	assert_int(_mine.amount_of("crowbar")).is_equal(1)

	_requests.request_put_in_container.rpc_id(LOCAL_ID, CONTAINER_ID, "crowbar", 1)
	assert_int(_mine.amount_of("crowbar")).is_equal(0)
	assert_int(_container.inventory.amount_of("crowbar")).is_equal(1)


# La mochila es lo único de los diez items que hace algo en v0.3.
func test_la_mochila_sube_la_capacidad_solo_si_la_tenes() -> void:
	_requests.request_equip_backpack.rpc_id(LOCAL_ID, true)
	assert_float(_mine.capacity).is_equal(_mine.base_capacity)

	_mine.add("backpack", 1)
	_requests.request_equip_backpack.rpc_id(LOCAL_ID, true)
	assert_float(_mine.capacity).is_equal(_mine.backpack_capacity)

	_requests.request_equip_backpack.rpc_id(LOCAL_ID, false)
	assert_float(_mine.capacity).is_equal(_mine.base_capacity)
