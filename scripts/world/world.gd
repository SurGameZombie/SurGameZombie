extends Node3D

## Escena de juego de v0.1. Todo lo que se decide acá corre en el host: quién
## existe, dónde aparece y cuándo se va (docs/netcode.md → "La regla").

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

## Radio del círculo donde aparecen los jugadores, para que no spawneen uno
## adentro del otro.
const SPAWN_RADIUS: float = 2.0

## Cuánto baja un pedido de daño. Vive en el host y NO viaja por la red: es la
## única forma de que un cliente no pueda pedir 999999 de daño. Un valor de
## gameplay que no cruza la red no puede mentir.
const DAMAGE_PER_REQUEST: float = 10.0

@onready var _players: Node3D = $Players


func _ready() -> void:
	if not multiplayer.is_server():
		# El cliente avisa que ya tiene esta escena cargada, y el host lo
		# spawnea recién ahí.
		#
		# Sin este aviso hay una carrera que en LAN se pierde casi siempre: el
		# host spawnearía al recibir peer_connected, pero del lado del cliente
		# change_scene_to_file() se difiere al final del frame. Con un RTT de
		# menos de 1 ms contra un frame de 16 ms, el paquete de spawn llega
		# antes de que exista el MultiplayerSpawner acá y se descarta. El
		# síntoma sería "a veces el otro jugador no aparece".
		notify_world_ready.rpc_id(1)
		return

	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_spawn_player(multiplayer.get_unique_id())


## La llama un cliente cuando terminó de cargar esta escena. Corre en el host.
@rpc("any_peer", "reliable")
func notify_world_ready() -> void:
	if not multiplayer.is_server():
		return
	_spawn_player(multiplayer.get_remote_sender_id())


## La llama un cliente para pedir que le bajen vida a un jugador. Corre en el
## host, que valida contra su propio estado y recién ahí aplica.
@rpc("any_peer", "call_local", "reliable")
func request_damage(target_peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	# Verificado corriendo 4.7.1: en una llamada local por rpc_id() —el host
	# pidiéndose a sí mismo— esto devuelve el ID local, NO 0. El 0 que dice la
	# documentación es para cuando la función se llama directo, sin pasar por rpc.
	# O sea que acá nunca hay que normalizarlo.
	var sender_id: int = multiplayer.get_remote_sender_id()

	# 1. ¿El target existe? Un cliente puede mandar un ID inventado, o uno que se
	#    desconectó entre que mandó el pedido y que el host llegó a procesarlo.
	var stats: PlayerStats = _find_stats(target_peer_id)
	if stats == null:
		print("[world] daño rechazado: el peer %d no tiene jugador" % target_peer_id)
		return

	# 2. ¿Se lo pide sobre sí mismo? Hoy no hay PvP ni armas de jugador, así que
	#    pedir daño sobre otro todavía no es un caso legítimo.
	if sender_id != target_peer_id:
		print("[world] daño rechazado: el peer %d lo pidió sobre %d" % [sender_id, target_peer_id])
		return

	# 3. Aplicar. El resultado baja solo por el Synchronizer del nodo Stats.
	stats.take_damage(DAMAGE_PER_REQUEST)


func _find_stats(peer_id: int) -> PlayerStats:
	var player: Node = _players.get_node_or_null(NodePath(str(peer_id)))
	if player == null:
		return null
	return player.get_node_or_null("Stats") as PlayerStats


func _spawn_player(peer_id: int) -> void:
	var player: CharacterBody3D = PLAYER_SCENE.instantiate()
	# El nombre del nodo ES el ID del peer: player.gd lo lee en _enter_tree()
	# para saber de quién es la autoridad. Tiene que estar puesto ANTES del
	# add_child(), porque _enter_tree() corre adentro de esa llamada.
	player.name = str(peer_id)
	player.position = _spawn_position(_players.get_child_count())
	# Solo agregarlo al árbol: el MultiplayerSpawner ve el hijo nuevo y lo
	# replica al resto. El host es el único que llega hasta acá.
	_players.add_child(player)
	print("[world] jugador spawneado para el peer %d" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	var player: Node = _players.get_node_or_null(NodePath(str(peer_id)))
	if player == null:
		return
	# Borrarlo en el host alcanza: el Spawner replica el despawn. Sin esto queda
	# una cápsula fantasma parada para siempre en las otras máquinas.
	player.queue_free()
	print("[world] jugador borrado del peer %d" % peer_id)


func _spawn_position(index: int) -> Vector3:
	# Repartidos en círculo: con los 4 jugadores de docs/design.md quedan a 90°
	# uno del otro. El 0.1 de alto es para no arrancar clavado en el piso.
	var angle: float = TAU * float(index) / 4.0
	return Vector3(cos(angle) * SPAWN_RADIUS, 0.1, sin(angle) * SPAWN_RADIUS)
