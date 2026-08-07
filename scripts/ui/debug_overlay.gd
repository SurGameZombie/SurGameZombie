extends CanvasLayer

## Andamio de debug del paso 2 de v0.2. Muestra en pantalla, en las dos máquinas
## a la vez, la vida de TODOS los jugadores y de quién es la autoridad de cada
## nodo. Existe para poder verificar que la vida vive en el host antes de que
## haya nada que quite vida.
##
## Todo el andamio está en este archivo a propósito: cuando entre el HUD de
## verdad se borran el script, el nodo de world.tscn y las acciones debug_hurt,
## debug_hurt_invalid, debug_pause_zombies y debug_inventory_attack, y no queda
## nada suelto.

## Un peer que no existe. Sirve para pedirle al host daño sobre un jugador
## inventado y ver que lo rechaza.
const GHOST_PEER_ID: int = 999999

## El contenedor de jugadores de world.tscn. La ruta va por @export para que
## viva en la escena y no hardcodeada acá adentro (CLAUDE.md → "Reglas de
## código"). Se exporta la NodePath y no el Node3D directo porque un export de
## nodo no se resuelve cuando el .tscn se escribe a mano: queda en null.
@export var players_root_path: NodePath = ^"../Players"

## Dónde vive request_damage(). Mismo motivo que arriba para que sea NodePath.
@export var world_path: NodePath = ^".."

## El contenedor de zombies. Mismo motivo.
@export var zombies_root_path: NodePath = ^"../Zombies"

## Dónde viven las RPC de pedido de inventario. Mismo motivo.
@export var requests_path: NodePath = ^"../InventoryRequests"

## Si los zombies están congelados por F3. Vive acá y no adentro del zombie
## porque es estado del andamio: se borra junto con este archivo.
var _zombies_paused: bool = false

@onready var _label: Label = $StatsLabel
@onready var _players_root: Node3D = get_node(players_root_path)
@onready var _world: Node = get_node(world_path)
@onready var _zombies_root: Node3D = get_node(zombies_root_path)
@onready var _requests: Node = get_node(requests_path)


func _process(_delta: float) -> void:
	# Polling y no señal: es debug, y así no depende de que el
	# MultiplayerSynchronizer dispare el setter de GDScript al escribir la
	# propiedad del lado del cliente, que es algo que todavía no verificamos.
	_label.text = _build_text()


# Las dos teclas mandan el MISMO RPC: lo único que cambia es si el pedido es
# legítimo. Ya no se escribe health desde acá — hasta el paso 2 esta función lo
# hacía directo y se salteaba al host, que es justo lo que
# .claude/rules/netcode.md prohíbe.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_hurt"):
		# Daño sobre vos mismo, que es lo único que el host acepta. Hace de
		# zombie hasta que exista el zombie de verdad (paso 4).
		_world.request_damage.rpc_id(1, multiplayer.get_unique_id())
	elif event.is_action_pressed("debug_hurt_invalid"):
		_send_invalid_requests()
	elif event.is_action_pressed("debug_pause_zombies"):
		_toggle_zombie_pause()
	elif event.is_action_pressed("debug_inventory_attack"):
		_send_invalid_inventory_requests()


# Congela a los zombies y nada más. Apaga su _physics_process, que es donde
# corre toda su IA: sin él no repathea, no pide velocidad y no llama a
# move_and_slide(), así que se queda donde está.
#
# NO usa get_tree().paused a propósito: eso frenaría el árbol entero, jugadores
# incluidos, y lo que hace falta al testear es exactamente lo contrario —
# caminar tranquilo con los zombies quietos, para mirar geometría, NavMesh o el
# cuerpo de un caído sin que te muerdan mientras.
#
# Corre SOLO en el host porque la IA vive ahí (docs/netcode.md → "La regla"). En
# el cliente el _physics_process del zombie ya está apagado a propósito, así que
# apretar F3 allá no tiene nada que apagar: avisa por consola y no hace nada. Es
# correcto, no un bug.
#
# OJO PARA v0.5: esto recorre los zombies que existen en el momento de apretar la
# tecla, así que uno que spawnee DESPUÉS de pausar arranca en marcha y no hereda
# el estado. Hoy da igual —hay un solo zombie fijo, puesto por world.gd— pero
# cuando entre el sistema de spawn real la pausa va a quedar a medias sin que
# nada avise. La solución es al revés de esta: que el zombie consulte el estado
# de pausa al entrar al árbol, en vez de que la pausa vaya a buscar a los
# zombies.
func _toggle_zombie_pause() -> void:
	if not multiplayer.is_server():
		print("[debug] F3 solo hace algo en el host: la IA del zombie corre ahí")
		return

	_zombies_paused = not _zombies_paused
	for zombie: Zombie in _zombies_root.get_children():
		zombie.set_physics_process(not _zombies_paused)
	print("[debug] zombies %s (%d en la escena)" % [
		"PAUSADOS" if _zombies_paused else "en marcha",
		_zombies_root.get_child_count(),
	])


# Los dos pedidos que el host tiene que rechazar, uno por cada validación.
#
# Sin esto no hay forma de saber si el host valida o si acepta todo: un cliente
# que se porta bien manda pedidos válidos, y eso se ve idéntico en los dos casos.
# Los rechazos se imprimen en la consola DEL HOST, no en la de quien los manda.
func _send_invalid_requests() -> void:
	# Mentira 1: un peer que no existe. Rebota en el chequeo de existencia.
	_world.request_damage.rpc_id(1, GHOST_PEER_ID)
	# Mentira 2: daño sobre otro jugador. Rebota en el chequeo de autoría.
	var other_id: int = _other_peer_id()
	if other_id != 0:
		_world.request_damage.rpc_id(1, other_id)


# El control negativo del inventario: los tres pedidos que el host TIENE que
# rechazar. F4.
#
# Es obligatorio antes de dar la réplica por probada, por lo mismo que el de daño:
# un cliente que se porta bien se ve idéntico contra un host que valida y contra
# uno que acepta todo. Los rechazos se imprimen en la consola DEL HOST.
func _send_invalid_inventory_requests() -> void:
	var container: StorageContainer = _any_container()
	if container != null:
		var distance: float = _distance_to(container)
		print("[debug] mentira 1: sacar de '%s' estando a %.1f m (el límite es %.1f)" % [
			container.container_id, distance, InventoryRequests.CONTAINER_RANGE,
		])
		if distance <= InventoryRequests.CONTAINER_RANGE:
			print("[debug]   OJO: estás DENTRO del rango, así que este pedido es legítimo")
		# Rebota en el chequeo de distancia de _can_access() — si estás lejos.
		_requests.request_take_from_container.rpc_id(1, container.container_id, "crowbar", 1)

	# Mentira 2: un contenedor que no existe. Rebota en el buscador por id.
	_requests.request_take_from_container.rpc_id(1, "no_existe_este_contenedor", "crowbar", 1)

	_lie_about_another_inventory()


# Mentira 3, y es la que de verdad importa: escribirle un delta al inventario de
# OTRO jugador, pasándole el path directo, que es el hueco que tiene el addon de
# expressobits.
#
# apply_stack_added es @rpc("authority") y la autoridad de ese nodo es el host, así
# que el host tiene que rechazarla. **Si esto funciona, la reasignación de
# autoridad del _enter_tree() no está andando y todo el paso 3 está apoyado en
# nada.** Se ve mirando si al otro jugador le aparecen 99 palancas.
func _lie_about_another_inventory() -> void:
	var other_id: int = _other_peer_id()
	if other_id == 0:
		print("[debug] mentira 3 salteada: hace falta un segundo jugador conectado")
		return
	var sync: Node = _players_root.get_node_or_null(
		NodePath("%d/Inventory/InventorySync" % other_id)
	)
	if sync == null:
		print("[debug] mentira 3 salteada: no encuentro el InventorySync del peer %d" % other_id)
		return
	print("[debug] mentira 3: mando 99 palancas al inventario del peer %d" % other_id)
	sync.apply_stack_added.rpc_id(1, 0, "crowbar", 99)


func _any_container() -> StorageContainer:
	for node: Node in get_tree().get_nodes_in_group(StorageContainer.GROUP):
		var container: StorageContainer = node as StorageContainer
		if container != null:
			return container
	return null


func _distance_to(container: StorageContainer) -> float:
	var me: Node3D = _players_root.get_node_or_null(
		NodePath(str(multiplayer.get_unique_id()))
	) as Node3D
	if me == null:
		return INF
	return me.global_position.distance_to(container.global_position)


# El ID de cualquier otro jugador, o 0 si estás solo y no hay a quién pedírselo.
func _other_peer_id() -> int:
	var own_id: int = multiplayer.get_unique_id()
	for player: Node in _players_root.get_children():
		var id: int = player.name.to_int()
		if id != own_id:
			return id
	return 0


func _build_text() -> String:
	var role: String = "host" if multiplayer.is_server() else "cliente"
	# El estado de pausa va en pantalla y no solo en la consola: sin esto,
	# "los zombies no se mueven" se ve igual que un bug de IA.
	var paused_mark: String = "   [F3: ZOMBIES PAUSADOS]" if _zombies_paused else ""
	var lines: PackedStringArray = PackedStringArray([
		"soy %d (%s)%s" % [multiplayer.get_unique_id(), role, paused_mark],
	])
	# Todos los jugadores, no solo el propio: es lo que hace comparables las dos
	# pantallas de un vistazo.
	for player: Node in _players_root.get_children():
		var stats: PlayerStats = player.get_node("Stats")
		lines.append("%-9s vida %3.0f %-18s cuerpo@%-9d stats@%d" % [
			player.name,
			stats.health,
			_downed_text(stats),
			player.get_multiplayer_authority(),
			stats.get_multiplayer_authority(),
		])
		lines.append(_inventory_line(player))
	for node: Node in get_tree().get_nodes_in_group(StorageContainer.GROUP):
		lines.append(_container_line(node as StorageContainer))
	for zombie: Zombie in _zombies_root.get_children():
		lines.append(_zombie_line(zombie))
	return "\n".join(lines)


# El peso y los stacks de cada jugador, en las dos pantallas a la vez. Es lo que
# hace visible si la réplica del inventario funciona: los dos números tienen que
# leerse IGUAL en el host y en el cliente. Si solo se mueven del lado del host, no
# está replicando.
#
# inv@ es la autoridad del nodo, y tiene que decir 1 SIEMPRE, incluso en la línea
# del jugador de un cliente. Si dice otra cosa, los @rpc("authority") del
# InventorySync están muertos.
func _inventory_line(player: Node) -> String:
	var inventory: Inventory = player.get_node_or_null("Inventory") as Inventory
	if inventory == null:
		return "          (sin Inventory)"
	return "          inv %6.2f / %4.1f kg  %d stacks  inv@%d" % [
		inventory.get_weight(),
		inventory.capacity,
		inventory.stacks.size(),
		inventory.get_multiplayer_authority(),
	]


func _container_line(container: StorageContainer) -> String:
	if container == null:
		return ""
	var inventory: Inventory = container.inventory
	return "%-14s inv %6.2f / %4.1f kg  %d stacks" % [
		container.container_id,
		inventory.get_weight(),
		inventory.capacity,
		inventory.stacks.size(),
	]


# Estado del caído: cuánto le queda y si lo están levantando. Los dos números los
# escribe el host y bajan replicados, así que tienen que leerse IGUAL en las dos
# pantallas. Si el porcentaje solo se mueve en la del host, no está replicando.
func _downed_text(stats: PlayerStats) -> String:
	if not stats.is_downed:
		return ""
	if stats.revive_progress > 0.0:
		return "CAIDO %4.1fs  %3.0f%%" % [
			stats.downed_time_left,
			stats.revive_progress * 100.0,
		]
	return "CAIDO %4.1fs" % stats.downed_time_left


# Los números de navegación solo existen en el host: el agente del cliente nunca
# navega, así que allá daría todo cero y parecería un bug. El estado sí baja
# replicado, y compararlo entre las dos pantallas es lo que prueba que el cliente
# no está simulando por su cuenta.
func _zombie_line(zombie: Zombie) -> String:
	var state_name: String = "ATTACKING" if zombie.state == Zombie.State.ATTACKING else "CHASING"
	if not multiplayer.is_server():
		return "zombie    %-9s  (nav: solo en el host)" % state_name

	var agent: NavigationAgent3D = zombie.get_node("NavigationAgent3D")
	# dist es la línea recta y camino es lo que realmente va a recorrer. Que
	# camino sea bastante mayor que dist es el rodeo por el NavMesh; si son
	# iguales y pts es 2, está yendo derecho.
	var straight: float = zombie.global_position.distance_to(agent.target_position)
	return "zombie    %-9s  dist %5.1f   camino %5.1f (%d pts)" % [
		state_name,
		straight,
		agent.get_path_length(),
		agent.get_current_navigation_path().size(),
	]
