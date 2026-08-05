class_name Zombie
extends CharacterBody3D

## Zombie de v0.2. Persigue al jugador más cercano por el NavMesh de yard.tscn y
## muerde cuando llega.
##
## La IA corre SOLO en el host (docs/netcode.md → "La regla"). Es el primer
## sistema del proyecto sin contraparte en el cliente: los clientes reciben
## posición, rotación y estado por el MultiplayerSynchronizer y no simulan nada.

## Persiguiendo o mordiendo. Se replica para que más adelante los clientes puedan
## animarlo; hoy lo lee solo el overlay de debug.
enum State { CHASING, ATTACKING }

const HOST_PEER_ID: int = 1

## Velocidad de persecución, en m/s. Salió de jugarlo: a 2.5 se sentía
## inofensivo (docs/design.md → "Velocidad del zombie: 3.7 m/s").
##
## 4.0 es techo duro y no se toca: es lo que camina el jugador, y todo el diseño
## del enemigo se apoya en que uno solo nunca alcanza a alguien que se mueve. A
## 3.7 el margen caminando es de 0.3 m/s, así que te escapás en línea recta y en
## campo abierto, no doblando ni entre obstáculos.
@export var move_speed: float = 3.7

## Cuánta vida saca cada mordida.
@export var attack_damage: float = 10.0

## Cuánto espera entre una mordida y la siguiente, en segundos. Sin esto muerde
## una vez por frame.
@export var attack_cooldown: float = 1.5

## Hasta dónde llega a morder, en metros. Las dos cápsulas tienen 0.4 m de radio,
## así que se tocan a 0.8: esto deja margen.
@export var attack_range: float = 1.5

## Cada cuánto recalcula el camino, en segundos. Repathear cada frame contra un
## objetivo que se mueve es tirar CPU al pedo. Con un zombie da igual; con los
## de v0.5 no.
@export var repath_interval: float = 0.2

## Persiguiendo o mordiendo. Lo escribe el host y baja replicado.
var state: State = State.CHASING

var _target: Node3D = null
var _attack_cooldown_left: float = 0.0
var _repath_left: float = 0.0

@onready var _agent: NavigationAgent3D = $NavigationAgent3D


# El zombie es del host entero: no hay nada suyo que decida un cliente. A
# diferencia del jugador, acá no hay autoridad partida que cuidar.
func _enter_tree() -> void:
	set_multiplayer_authority(HOST_PEER_ID)


func _ready() -> void:
	# Arranca apagado en las dos puntas y solo el host lo vuelve a prender. En el
	# cliente, simular sería pelearle el transform al Synchronizer.
	set_physics_process(false)
	if not multiplayer.is_server():
		return
	# El NavigationServer sincroniza su mapa al final del primer frame de física.
	# Pedirle un camino antes de eso devuelve vacío y el zombie arranca quieto.
	await get_tree().physics_frame
	if is_inside_tree():
		set_physics_process(true)


func _physics_process(delta: float) -> void:
	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)

	_repath_left -= delta
	if _repath_left <= 0.0:
		_repath_left = repath_interval
		_retarget()

	if _target == null:
		# No queda nadie parado: o están todos caídos, o todavía no spawneó
		# ninguno. Frena en el lugar en vez de quedarse con la velocidad del
		# último frame.
		state = State.CHASING
		_stop(delta)
		return

	_try_attack()
	_move(delta)


# Elige al jugador más cercano y le apunta el agente.
func _retarget() -> void:
	_target = _nearest_player()
	if _target != null:
		_agent.target_position = _target.global_position


# Por grupo y no por ruta: al zombie lo instancia un MultiplayerSpawner, así que
# no tiene por qué saber de qué nodo cuelgan los jugadores.
func _nearest_player() -> Node3D:
	var best: Node3D = null
	var best_distance: float = INF
	for player: Node3D in get_tree().get_nodes_in_group("players"):
		# Los caídos no cuentan como objetivo: el zombie va por el que sigue
		# parado. Es lo que hace que levantar a alguien sea una decisión con
		# riesgo y no un trámite — el que se agacha a levantarlo es el que queda
		# expuesto, no el que está en el piso.
		var stats: PlayerStats = player.get_node_or_null("Stats") as PlayerStats
		if stats == null or stats.is_downed:
			continue
		var distance: float = global_position.distance_to(player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = player
	return best


func _try_attack() -> void:
	var distance: float = global_position.distance_to(_target.global_position)
	# Las DOS condiciones. La navegación terminada es lo que evita morder a
	# través de una pared: si estás del otro lado, el camino rodea por la puerta
	# y el agente todavía no llegó al final.
	var in_reach: bool = distance <= attack_range and _agent.is_navigation_finished()
	state = State.ATTACKING if in_reach else State.CHASING

	if not in_reach or _attack_cooldown_left > 0.0:
		return

	var stats: PlayerStats = _target.get_node_or_null("Stats") as PlayerStats
	if stats == null:
		return
	# Directo, sin pasar por world.gd::request_damage(): el zombie YA corre en el
	# host, así que pedirse permiso a sí mismo por RPC no tendría sentido.
	stats.take_damage(attack_damage)
	_attack_cooldown_left = attack_cooldown


func _move(delta: float) -> void:
	if state == State.ATTACKING or _agent.is_navigation_finished():
		_stop(delta)
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	# get_next_path_position() devuelve el siguiente vértice del camino, no la
	# posición del jugador: es acá donde el NavMesh hace que rodee las paredes.
	var next_point: Vector3 = _agent.get_next_path_position()
	var direction: Vector3 = global_position.direction_to(next_point)
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	_face(next_point)
	move_and_slide()


# Frena donde está, sin dejar de caer.
func _stop(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()


# Mira hacia donde camina, solo en horizontal: si el punto tuviera otra altura,
# look_at lo inclinaría hacia el piso.
func _face(target_point: Vector3) -> void:
	var flat: Vector3 = Vector3(target_point.x, global_position.y, target_point.z)
	# look_at revienta si el objetivo coincide con la posición.
	if flat.distance_to(global_position) < 0.01:
		return
	look_at(flat, Vector3.UP)
