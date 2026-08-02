extends CharacterBody3D

## Controller en primera persona. Por ahora es 100% local: no sabe nada de red.
## Cuando llegue la replicación, el único cambio es un return temprano en
## _physics_process() si no somos la autoridad de este nodo (docs/netcode.md).

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

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	# Captura el mouse: se esconde el cursor y el movimiento pasa a ser relativo
	# e infinito, sin chocar contra el borde de la pantalla.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event as InputEventMouseMotion)
	# Escape suelta el mouse para poder salir de la ventana del juego.
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
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
