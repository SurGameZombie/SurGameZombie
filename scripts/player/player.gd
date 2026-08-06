class_name Player
extends CharacterBody3D

## Controller en primera persona. El cuerpo es autoridad del peer dueño: solo él
## lee input y se mueve, y el MultiplayerSynchronizer replica el transform hacia
## afuera (docs/netcode.md → "Los tres patrones", molde 1).
##
## Lo que este script NO decide: su vida, si está caído y dónde respawnea. Eso es
## del host y entra por el nodo Stats o por una orden como teleport_to().

## Altura de la cámara estando caído, en metros. **PROVISORIO** — es game feel y
## sale del playtest, así que todavía NO está en docs/design.md.
##
## Sale de una proporción antropométrica real, no de un número inventado, y el
## ancla es la pose decidida: **arrastrándose boca abajo**, no gateando. La
## profundidad de pecho de un adulto es ~0.25 m contra ~1.75 m de estatura
## (percentil 50, adultos británicos y estadounidenses), o sea que boca abajo
## medís alrededor del 14% de lo que medís parado, más ~0.04 m por ropa de
## exterior. Sobre el 1.8 m de este proyecto da ~0.30 m.
##
## El mismo número está presupuestado en docs/plan.md → v0.5 para la altura del
## obstáculo cuando el zombie pueda saltar por encima. Si la pose cambia, cambian
## los dos.
##
## Solo cambia la ALTURA. El ángulo de la cámara no se toca a propósito: el caído
## se arrastra mirando al frente, no boca arriba.
const DOWNED_CAMERA_HEIGHT: float = 0.3

## Velocidad caminando, en m/s. docs/design.md → "Escala y números base".
@export var walk_speed: float = 4.0

## Velocidad corriendo, en m/s.
@export var sprint_speed: float = 7.0

## Impulso vertical del salto, en m/s. Con gravedad 9.8 da ~1.03 m de alto:
## altura = (jump_velocity ^ 2) / (2 * gravedad).
@export var jump_velocity: float = 4.5

## Cuánto se puede corregir la dirección estando en el aire, como fracción de
## la velocidad por segundo. 0.0 = la trayectoria del salto es fija y no se
## puede tocar; 1.0 = se puede cambiar la velocidad entera en un segundo, que
## para un salto de ~0.9 s es prácticamente control total.
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.25

## Radianes de giro por pixel de movimiento del mouse.
@export var mouse_sensitivity: float = 0.002

## Hasta dónde se puede mirar arriba y abajo. 90° sería mirar recto al cenit;
## 89 deja un margen para que la cámara nunca llegue a darse vuelta.
@export var max_pitch_degrees: float = 89.0

## Dónde vive world.gd, que es donde están los RPC del patrón 2. Va por NodePath
## y no hardcodeado acá adentro, igual que en debug_overlay.gd. Al jugador lo
## cuelga siempre el host de World/Players/<id>, así que "../.." resuelve igual
## en las tres máquinas.
@export var world_path: NodePath = ^"../.."

@onready var _camera: Camera3D = $Camera3D

## La cápsula visible y la marca de orientación. Se apagan en la instancia local
## porque la cámara está adentro de la cápsula.
@onready var _body: Node3D = $Body

## El estado que resuelve el host. Desde acá solo se LEE: vida y caído los
## escribe el host y bajan replicados (docs/netcode.md → "La regla").
@onready var _stats: PlayerStats = $Stats

@onready var _world: Node = get_node(world_path)

## Lo que hace que el zombie rodee tu cuerpo en vez de trabarse contra él. Solo
## se prende estando caído: si estuviera prendido siempre, el zombie esquivaría
## también al jugador que persigue y nunca llegaría a morderlo.
@onready var _obstacle: NavigationObstacle3D = $NavigationObstacle3D

## La altura de la cámara de pie, leída de player.tscn en vez de hardcodeada, para
## que mover la cámara en el editor no deje este script desincronizado.
@onready var _standing_camera_height: float = _camera.position.y


# La autoridad NO se replica sola: cada máquina la deduce del nombre del nodo.
# El host nombra a cada jugador con el ID de su peer ("1", "1043872"), el nombre
# viaja con el spawn, y así las tres máquinas llegan a la misma conclusión.
#
# Va en _enter_tree() y no en _ready() porque el MultiplayerSynchronizer hijo ya
# necesita saber quién manda cuando entra al árbol.
#
# recursive es true por default y acá eso es lo que queremos: el Synchronizer
# del transform tiene que tener la misma autoridad que la raíz para que el
# transform fluya cliente -> host -> resto.
#
# Pero recursive también arrastra el nodo Stats, que es estado del host y no
# puede terminar en el cliente. Eso lo arregla player_stats.gd, que se vuelve a
# asignar al host en SU propio _enter_tree(): como _enter_tree() va de padre a
# hijo, esa llamada corre después que esta y gana
# (docs/netcode.md → "Paso 2: el segundo Synchronizer").
func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	# El zombie busca objetivos por grupo, así no necesita saber de qué nodo
	# cuelgan los jugadores (scripts/enemies/zombie.gd).
	#
	# Va ANTES del return de autoridad de más abajo, y eso NO es un detalle: en
	# el host, las cápsulas de los clientes no son autoridad suya. Si esta línea
	# quedara después del return, al grupo entraría solo el jugador del propio
	# host y el zombie perseguiría siempre al mismo, ignorando a los clientes.
	add_to_group("players")

	# Paso 6 de docs/netcode.md: la cámara se activa SOLO en la instancia local.
	# Si no, cada cliente termina viendo por los ojos de la última cápsula que se
	# spawneó, que es de los bugs más desconcertantes de un primer multiplayer.
	_camera.current = is_multiplayer_authority()

	# La cámara vive adentro de la cápsula, así que la malla propia se apaga:
	# desde la instancia local no hay cuerpo que ver. Las remotas sí lo tienen.
	#
	# La alternativa era adelantar la cámara para que quede fuera de la malla,
	# pero eso saca la cámara del cuerpo: pegado a una pared verías a través.
	# Cuando haya un modelo de verdad, esto se cambia por esconder solo la
	# cabeza y dejar el cuerpo visible al mirar para abajo.
	_body.visible = not is_multiplayer_authority()

	if not is_multiplayer_authority():
		return
	# Captura el mouse: se esconde el cursor y el movimiento pasa a ser relativo
	# e infinito, sin chocar contra el borde de la pantalla.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# Corre en TODAS las máquinas, sin gate de autoridad, y eso es el punto: el que
# necesita el obstáculo prendido es el HOST, porque es donde el zombie navega, y
# el cuerpo de un cliente caído en la máquina del host es una instancia que no es
# autoridad suya. is_downed baja replicado, así que las tres llegan a lo mismo.
#
# Se compara antes de asignar porque esto corre todos los frames y el setter
# registra y desregistra el obstáculo en el NavigationServer.
func _process(_delta: float) -> void:
	if _obstacle.avoidance_enabled != _stats.is_downed:
		_obstacle.avoidance_enabled = _stats.is_downed
	_update_camera_height()


# Lo único que hace visible el estado caído hasta que haya animaciones: la cámara
# baja al piso. Sin esto, un caído se ve idéntico a alguien parado que no camina, y
# el playtest de v0.2 mide justo ese sistema.
#
# Se toca SOLO position.y. La rotación queda como está: el pitch lo maneja _look()
# y el caído se arrastra mirando al frente.
func _update_camera_height() -> void:
	var target: float = DOWNED_CAMERA_HEIGHT if _stats.is_downed else _standing_camera_height
	if not is_equal_approx(_camera.position.y, target):
		_camera.position.y = target


func _unhandled_input(event: InputEvent) -> void:
	# Sin este gate, tu mouse rotaría también el cuerpo de los otros jugadores
	# en tu máquina, y el Synchronizer se pelearía con vos por el transform.
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event as InputEventMouseMotion)
	# Escape suelta el mouse para poder salir de la ventana del juego.
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Y un click lo vuelve a capturar. Recapturar va en el click y no en Escape
	# a propósito: si Escape fuera un toggle, no habría forma de salir del juego.
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	# Paso 4 de docs/netcode.md: solo el dueño simula. Las otras cápsulas no
	# calculan nada — reciben el transform por el MultiplayerSynchronizer.
	if not is_multiplayer_authority():
		return

	# Estando caído dejamos de leer input. El flag lo decide el host: acá solo se
	# respeta, igual que el return de arriba respeta la autoridad.
	if _stats.is_downed:
		_move_downed(delta)
		return

	_update_revive_input()

	# get_gravity() devuelve un Vector3 (dirección incluida) tomado de los
	# project settings. En el aire acumula; en el piso no, para que la velocidad
	# vertical no crezca sin límite mientras caminás.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Acá va a entrar el patrón del modificador de docs/netcode.md cuando
	# lleguen sobrepeso (v0.3) y stamina (v0.4): el host manda el multiplicador
	# y este cliente lo aplica sobre speed.
	var speed: float = sprint_speed if Input.is_action_pressed("sprint") else walk_speed

	# get_vector devuelve un Vector2 ya normalizado en diagonal, así que caminar
	# en diagonal no es más rápido que caminar recto.
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# El input es relativo al jugador; global_basis lo pasa a coordenadas del
	# mundo, que es lo que espera velocity. El Y del Vector2 va al Z del Vector3
	# porque en Godot 3D el eje que apunta "adelante" es -Z.
	var direction: Vector3 = global_basis * Vector3(input.x, 0.0, input.y)

	var target_x: float = direction.x * speed
	var target_z: float = direction.z * speed

	if is_on_floor():
		# En el piso el cambio es instantáneo: soltás la tecla y frenás.
		velocity.x = target_x
		velocity.z = target_z
	else:
		# En el aire solo se puede corregir una fracción de la velocidad por
		# segundo, así que la trayectoria del salto queda casi fija. El delta
		# está adentro para que no dependa de los FPS.
		var max_change: float = speed * air_control * delta
		velocity.x = move_toward(velocity.x, target_x, max_change)
		velocity.z = move_toward(velocity.z, target_z, max_change)

	move_and_slide()


## Mueve el cuerpo a un punto. La llama world.gd::respawn_at(), que corre en esta
## máquina por orden del host.
##
## Corre acá y no en el host a propósito: el Synchronizer replica DESDE la
## autoridad del nodo hacia afuera, y la autoridad del cuerpo es este peer. Si el
## host escribiera la posición, el Synchronizer de esta máquina se la pisaría en
## el tick siguiente (docs/netcode.md).
func teleport_to(point: Vector3) -> void:
	global_position = point
	# Sin esto llegás al punto nuevo con la velocidad de la caída anterior y
	# seguís deslizándote un rato después de aparecer.
	velocity = Vector3.ZERO


# Las dos puntas del revivir: avisar que empezaste y avisar que soltaste. Son
# eventos discretos, así que van por RPC. Lo que NO se manda por RPC es el
# progreso: ese lo lleva el host y baja replicado, porque cambia todos los frames
# (docs/netcode.md → "Herramientas de Godot").
#
# Acá no se chequea nada más que "hay alguien caído": si está lejos, si el que
# pide está vivo, o si en v0.3 le falta la venda lo decide el host en
# world.gd::_can_revive(). El cliente no conoce ninguna regla.
func _update_revive_input() -> void:
	if Input.is_action_just_released("revive"):
		_world.request_revive_stop.rpc_id(1)
		return
	if not Input.is_action_just_pressed("revive"):
		return

	var target: Player = _nearest_downed_player()
	if target == null:
		return
	_world.request_revive_start.rpc_id(1, target.name.to_int())


# El caído más cercano, o null si no hay ninguno. Sin filtro de distancia a
# propósito: el rango es un número del host, y tenerlo también acá serían dos
# fuentes de verdad que se desincronizan apenas una de las dos cambie.
func _nearest_downed_player() -> Player:
	var best: Player = null
	var best_distance: float = INF
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other == self:
			continue
		var stats: PlayerStats = other.get_node_or_null("Stats") as PlayerStats
		if stats == null or not stats.is_downed:
			continue
		var distance: float = global_position.distance_to(other.global_position)
		if distance < best_distance:
			best_distance = distance
			best = other
	return best


# Caído: seguís cayendo por gravedad pero no caminás ni saltás. La mirada NO se
# toca a propósito —_unhandled_input() sigue igual—, así el caído puede mirar
# alrededor y ver si alguien viene a levantarlo.
func _move_downed(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()


func _look(event: InputEventMouseMotion) -> void:
	# Dos rotaciones separadas a propósito:
	# - el giro horizontal (yaw) va en el CUERPO, para que al caminar vayas
	#   hacia donde mirás;
	# - el vertical (pitch) va solo en la CÁMARA. Si fuera en el cuerpo, la
	#   cápsula se inclinaría y caminarías en diagonal hacia el piso.
	rotate_y(-event.relative.x * mouse_sensitivity)
	_camera.rotate_x(-event.relative.y * mouse_sensitivity)

	var limit: float = deg_to_rad(max_pitch_degrees)
	_camera.rotation.x = clampf(_camera.rotation.x, -limit, limit)
