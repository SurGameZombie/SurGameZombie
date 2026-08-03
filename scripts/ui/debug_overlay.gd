extends CanvasLayer

## Andamio de debug del paso 2 de v0.2. Muestra en pantalla, en las dos máquinas
## a la vez, la vida de TODOS los jugadores y de quién es la autoridad de cada
## nodo. Existe para poder verificar que la vida vive en el host antes de que
## haya nada que quite vida.
##
## Todo el andamio está en este archivo a propósito: cuando entre el HUD de
## verdad se borra el script, el nodo de world.tscn y la acción debug_hurt, y no
## queda nada suelto.

## Cuánta vida saca la tecla de debug. Ver _unhandled_input().
const DEBUG_DAMAGE: float = 10.0

## El contenedor de jugadores de world.tscn. La ruta va por @export para que
## viva en la escena y no hardcodeada acá adentro (CLAUDE.md → "Reglas de
## código"). Se exporta la NodePath y no el Node3D directo porque un export de
## nodo no se resuelve cuando el .tscn se escribe a mano: queda en null.
@export var players_root_path: NodePath = ^"../Players"

@onready var _label: Label = $StatsLabel
@onready var _players_root: Node3D = get_node(players_root_path)


func _process(_delta: float) -> void:
	# Polling y no señal: es debug, y así no depende de que el
	# MultiplayerSynchronizer dispare el setter de GDScript al escribir la
	# propiedad del lado del cliente, que es algo que todavía no verificamos.
	_label.text = _build_text()


# SIN chequeo de autoridad, a propósito. Es una sonda, no el patrón: viola la
# regla de que los clientes nunca escriben vida (.claude/rules/netcode.md) justo
# para poder ver qué pasa cuando lo intentan.
#
#  - Apretada en el HOST: es autoridad de todos los Stats, así que la escritura
#    sale y los números bajan en las dos pantallas.
#  - Apretada en un CLIENTE: no es autoridad de ninguno, así que su escritura se
#    queda en su máquina y la pantalla del host no se mueve. Si se moviera, la
#    trampa del recursive no está resuelta.
#
# En el paso 3 esto se reemplaza por request_damage.rpc_id(1, …) y el gate vuelve.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("debug_hurt"):
		return
	for player: Node in _players_root.get_children():
		var stats: PlayerStats = player.get_node("Stats")
		stats.health = maxf(0.0, stats.health - DEBUG_DAMAGE)


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
	return "\n".join(lines)
