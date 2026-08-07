extends GdUnitTestSuite

## El único test del proyecto que mira autoridad de red, y existe por un motivo
## concreto: `player.gd::_enter_tree()` llama
## `set_multiplayer_authority(name.to_int())` con `recursive` en true, así que se
## lleva TODOS sus hijos al peer dueño — incluidos los que son estado del host.
##
## Cada nodo de estado del host tiene que volver a reclamarla en su propio
## `_enter_tree()`, que corre después por ser hijo. Si alguno se olvida, sus
## `@rpc("authority")` dejan afuera al host y no se pueden llamar nunca. Es el error
## que v0.2 casi comete con la vida (docs/netcode.md → "Paso 2: el segundo
## Synchronizer") y que la primera versión de `inventory.gd` sí cometía.
##
## **Un jugador con nombre "1" no prueba nada:** ahí `name.to_int()` ya vale 1 y la
## trampa no se puede manifestar. Por eso el jugador de este test se llama con un ID
## de cliente.

## Un ID de peer cualquiera que no sea el host.
const CLIENT_ID: int = 1043872

## El ID del host en Godot es siempre 1.
const HOST_ID: int = 1

var _world: Node
var _player: Node


func before_test() -> void:
	# Se arma World/Players/<id> y no se cuelga el jugador de cualquier lado porque
	# player.gd resuelve world_path como "../..": sin esos dos niveles, su @onready
	# falla al entrar al árbol.
	_world = auto_free(Node.new())
	_world.name = "World"
	var players: Node3D = Node3D.new()
	players.name = "Players"
	_world.add_child(players)
	add_child(_world)

	_player = load("res://scenes/player/player.tscn").instantiate()
	_player.name = str(CLIENT_ID)
	players.add_child(_player)


func after_test() -> void:
	_player = null
	_world = null


# El cuerpo es del peer dueño: es la mitad de la regla que NO se toca
# (docs/netcode.md → "La regla").
func test_el_cuerpo_queda_en_el_peer_dueno() -> void:
	assert_int(_player.get_multiplayer_authority()).is_equal(CLIENT_ID)


# Y todo el resto vuelve al host. Un fallo acá no rompe ningún test de lógica y no
# da ningún error en pantalla: se ve recién con tres jugadores conectados.
func test_las_stats_vuelven_al_host() -> void:
	assert_int(_player.get_node("Stats").get_multiplayer_authority()).is_equal(HOST_ID)


func test_el_inventario_vuelve_al_host() -> void:
	assert_int(_player.get_node("Inventory").get_multiplayer_authority()).is_equal(HOST_ID)


func test_el_inventory_sync_vuelve_al_host() -> void:
	var sync: Node = _player.get_node("Inventory/InventorySync")
	assert_int(sync.get_multiplayer_authority()).is_equal(HOST_ID)


# El inventario del jugador arranca con la capacidad de base, sin mochila.
func test_el_inventario_del_jugador_arranca_en_la_capacidad_de_base() -> void:
	var inventory: Inventory = _player.get_node("Inventory") as Inventory
	assert_float(inventory.capacity).is_equal(inventory.base_capacity)
	assert_bool(inventory.is_empty()).is_true()


# El contenedor no cuelga de ningún jugador, así que nadie le toca la autoridad:
# tiene que quedar en el host igual, y con lo que dice su debug_contents adentro.
func test_el_contenedor_es_del_host_y_siembra_su_contenido() -> void:
	var container: StorageContainer = load(
		"res://scenes/items/storage_container.tscn"
	).instantiate() as StorageContainer
	container.container_id = "test_container"
	container.debug_contents = PackedStringArray(["ammo_9mm:45", "crowbar:1"])
	add_child(container)

	assert_int(container.get_multiplayer_authority()).is_equal(HOST_ID)
	assert_int(
		container.get_node("Inventory/InventorySync").get_multiplayer_authority()
	).is_equal(HOST_ID)
	# 45 balas entran en dos stacks de 30 y 15; la palanca en uno propio.
	assert_int(container.inventory.stacks.size()).is_equal(3)
	assert_int(container.inventory.amount_of("ammo_9mm")).is_equal(45)
	assert_float(container.inventory.capacity).is_equal(container.capacity)

	container.queue_free()
