extends CanvasLayer

## Andamio de debug del paso 2 de v0.2. Muestra en pantalla, en las dos máquinas
## a la vez, la vida de TODOS los jugadores y de quién es la autoridad de cada
## nodo. Existe para poder verificar que la vida vive en el host antes de que
## haya nada que quite vida.
##
## Todo el andamio está en este archivo a propósito: cuando entre el HUD de
## verdad se borran el script, el nodo de world.tscn y las acciones debug_hurt y
## debug_hurt_invalid, y no queda nada suelto.

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

@onready var _label: Label = $StatsLabel
@onready var _players_root: Node3D = get_node(players_root_path)
@onready var _world: Node = get_node(world_path)
@onready var _zombies_root: Node3D = get_node(zombies_root_path)


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
	var lines: PackedStringArray = PackedStringArray([
		"soy %d (%s)" % [multiplayer.get_unique_id(), role],
	])
	# Todos los jugadores, no solo el propio: es lo que hace comparables las dos
	# pantallas de un vistazo.
	for player: Node in _players_root.get_children():
		var stats: PlayerStats = player.get_node("Stats")
		lines.append("%-9s vida %3.0f   cuerpo@%-9d stats@%d" % [
			player.name,
			stats.health,
			player.get_multiplayer_authority(),
			stats.get_multiplayer_authority(),
		])
	for zombie: Zombie in _zombies_root.get_children():
		lines.append(_zombie_line(zombie))
	return "\n".join(lines)


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
