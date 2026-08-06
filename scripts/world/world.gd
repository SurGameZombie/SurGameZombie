extends Node3D

## Escena de juego. Todo lo que se decide acá corre en el host: quién existe,
## dónde aparece, cuándo se va, quién levanta a quién y dónde respawnea
## (docs/netcode.md → "La regla").

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ZOMBIE_SCENE: PackedScene = preload("res://scenes/enemies/zombie.tscn")

## Radio del círculo donde aparecen los jugadores, para que no spawneen uno
## adentro del otro.
const SPAWN_RADIUS: float = 2.0

## Cuánto baja un pedido de daño. Vive en el host y NO viaja por la red: es la
## única forma de que un cliente no pueda pedir 999999 de daño. Un valor de
## gameplay que no cruza la red no puede mentir.
const DAMAGE_PER_REQUEST: float = 10.0

## Cuánto puede alejarse el punto de respawn del lugar donde caíste, en metros,
## medido SOLO en horizontal. Si se pasa, se usa el círculo de spawn de respaldo.
##
## Horizontal y no en 3D porque el NavMesh horneado de yard.tscn queda 0.3 m por
## encima del piso (sus vértices están en y = 0.3 y la cara de arriba del Floor
## en y = 0.0). Una distancia en 3D nunca bajaría de esos 0.3 m ni parado en medio
## del patio, así que un umbral chico dispararía el respaldo siempre.
const MAX_RESPAWN_SNAP: float = 3.0

## Cuánto puede terminar un camino lejos del punto pedido para darlo por alcanzado,
## en metros. Es tolerancia de la consulta de navegación, no un número de gameplay:
## map_get_path() devuelve el último punto navegable, que nunca cae exacto sobre el
## pedido.
const REACHABLE_TOLERANCE: float = 1.0

## A qué distancia se puede levantar a un caído, en metros. Valor de arranque.
const REVIVE_RANGE: float = 2.0

## Cuánto hay que mantener la tecla para levantar a alguien, en segundos. Salido
## del playtest: 3 s se sentían demasiado cortos, no alcanzaban a poner en riesgo
## al que levanta. Con 10 s, contra un zombie a 3.7 m/s, quedarse quieto deja que
## uno que estaba a 37 m te alcance — o sea que ya no es "mirá si hay uno cerca"
## sino "mirá dónde está el que hay en el mapa".
const REVIVE_DURATION: float = 10.0

## Con cuánta vida queda el que fue levantado. Entra por un solo lugar a propósito:
## en v0.3 este número lo va a decidir el item médico que se haya usado.
const REVIVE_HEALTH: float = 30.0

@onready var _players: Node3D = $Players
@onready var _zombies: Node3D = $Zombies
@onready var _zombie_spawn: Marker3D = $ZombieSpawn


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
	_spawn_zombie()


## La llama un cliente cuando terminó de cargar esta escena. Corre en el host.
@rpc("any_peer", "reliable")
func notify_world_ready() -> void:
	if not multiplayer.is_server():
		return
	_spawn_player(multiplayer.get_remote_sender_id())


# Avanza los revivires en curso. Corre solo en el host.
#
# Itera los hijos vivos en vez de guardar un diccionario de quién levanta a quién:
# si el que levanta o el caído se desconectan dejan de estar en la lista, y no
# queda ninguna referencia colgada. Es la misma razón por la que el timer del
# caído vive adentro de su propio nodo de stats.
func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	for player: Node in _players.get_children():
		var stats: PlayerStats = player.get_node("Stats")
		if stats.reviver_id != 0:
			_tick_revive(player as Node3D, stats, delta)


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


## La llama un cliente cuando EMPIEZA a mantener la tecla de revivir. Corre en el
## host.
##
## Manda el ID del caído, no un NodePath ni una distancia: el host revalida todo
## contra su propio estado (docs/netcode.md → "Los dos patrones").
@rpc("any_peer", "call_local", "reliable")
func request_revive_start(target_peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	var healer: Node3D = _find_player(sender_id)
	var target: Node3D = _find_player(target_peer_id)
	if healer == null or target == null or not _can_revive(healer, target):
		print("[world] revivir rechazado: el peer %d sobre %d" % [sender_id, target_peer_id])
		return

	var stats: PlayerStats = target.get_node("Stats")
	stats.reviver_id = sender_id
	stats.revive_progress = 0.0


## La llama un cliente cuando SUELTA la tecla. Corre en el host.
##
## No lleva a quién estaba levantando: el host ya lo sabe, y así un cliente no
## puede cortarle el revivir a otro.
@rpc("any_peer", "call_local", "reliable")
func request_revive_stop() -> void:
	if not multiplayer.is_server():
		return
	_cancel_revives_from(multiplayer.get_remote_sender_id())


## La manda el host al dueño de un cuerpo para que se mueva solo. Corre en la
## máquina del dueño.
##
## Es una orden y no una escritura directa porque el cuerpo es autoridad del peer
## dueño: si el host le escribiera la posición, el MultiplayerSynchronizer del
## dueño se la pisaría en el tick siguiente.
##
## Ojo con el flag: "authority" quiere decir "solo la autoridad de ESTE nodo puede
## llamarla", y la autoridad de World es el host. Declarada en player.gd
## significaría lo contrario —la autoridad de ese nodo es el cliente dueño— y el
## host no podría llamarla nunca.
@rpc("authority", "call_local", "reliable")
func respawn_at(point: Vector3) -> void:
	var player: Player = _players.get_node_or_null(
		NodePath(str(multiplayer.get_unique_id()))
	) as Player
	if player == null:
		return
	player.teleport_to(point)


# Las condiciones para levantar a alguien, todas juntas y todas del host.
#
# En v0.3 "el que levanta tiene una venda" se agrega ACÁ ADENTRO y no se toca nada
# más: el cliente no conoce ninguna de estas reglas, solo pide.
#
# Levantarse a uno mismo ya queda descartado sin chequearlo aparte: si estás
# caído no pasás el punto 2, y si no lo estás no pasás el punto 1.
func _can_revive(healer: Node3D, target: Node3D) -> bool:
	# 1. El objetivo tiene que estar caído.
	var target_stats: PlayerStats = target.get_node("Stats")
	if not target_stats.is_downed:
		return false

	# 2. El que levanta tiene que estar de pie: un caído no levanta a otro caído.
	var healer_stats: PlayerStats = healer.get_node("Stats")
	if healer_stats.is_downed:
		return false

	# 3. Tienen que estar cerca, medido con las posiciones que el host YA tiene
	#    replicadas. Nunca con una distancia que mande el cliente.
	return healer.global_position.distance_to(target.global_position) <= REVIVE_RANGE


# Un revivir en curso. Se revalida ENTERO cada frame y recién después avanza: eso
# es lo que cubre alejarse, que al que levanta lo tiren, y que se desconecte a
# mitad de camino, sin escribir un caso especial para cada uno.
func _tick_revive(target: Node3D, stats: PlayerStats, delta: float) -> void:
	var healer: Node3D = _find_player(stats.reviver_id)
	if healer == null or not _can_revive(healer, target):
		stats.reviver_id = 0
		stats.revive_progress = 0.0
		return

	stats.revive_progress = minf(1.0, stats.revive_progress + delta / REVIVE_DURATION)
	if stats.revive_progress < 1.0:
		return

	stats.reviver_id = 0
	stats.revive_progress = 0.0
	stats.revive(REVIVE_HEALTH)
	print("[world] el peer %s levantó al peer %s" % [healer.name, target.name])


# Corta cualquier revivir que estuviera haciendo este peer.
func _cancel_revives_from(healer_id: int) -> void:
	for player: Node in _players.get_children():
		var stats: PlayerStats = player.get_node("Stats")
		if stats.reviver_id == healer_id:
			stats.reviver_id = 0
			stats.revive_progress = 0.0


func _find_player(peer_id: int) -> Node3D:
	return _players.get_node_or_null(NodePath(str(peer_id))) as Node3D


func _find_stats(peer_id: int) -> PlayerStats:
	var player: Node3D = _find_player(peer_id)
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
	# Solo el host escucha: la señal la emite el timer del caído, que corre
	# únicamente acá. Se conecta antes del add_child() para no perderse nada, y
	# se desconecta sola cuando el jugador se libera al desconectarse el peer.
	var stats: PlayerStats = player.get_node("Stats")
	stats.died.connect(_on_player_died.bind(player))
	# Solo agregarlo al árbol: el MultiplayerSpawner ve el hijo nuevo y lo
	# replica al resto. El host es el único que llega hasta acá.
	_players.add_child(player)
	print("[world] jugador spawneado para el peer %d" % peer_id)


# Un solo zombie fijo, adentro del galpón. El sistema de spawn y la densidad son
# v0.5; esto es solo para que haya de qué escaparse.
func _spawn_zombie() -> void:
	var zombie: CharacterBody3D = ZOMBIE_SCENE.instantiate()
	# La posición vive en el Marker3D de la escena y no acá, para poder
	# arrastrarla en el editor sin tocar código.
	zombie.position = _zombie_spawn.position
	_zombies.add_child(zombie)
	print("[world] zombie spawneado en %v" % zombie.position)


func _on_peer_disconnected(peer_id: int) -> void:
	var player: Node = _players.get_node_or_null(NodePath(str(peer_id)))
	if player == null:
		return
	# Borrarlo en el host alcanza: el Spawner replica el despawn. Sin esto queda
	# una cápsula fantasma parada para siempre en las otras máquinas.
	player.queue_free()
	print("[world] jugador borrado del peer %d" % peer_id)


# Al caído se le acabó el tiempo: muere de verdad y vuelve al juego. Corre en el
# host, que es el único que escucha la señal.
#
# Morir devuelve la vida llena; que te levante un compañero, no (paso 6d). La
# diferencia es a propósito: si las dos cosas dieran lo mismo, quedarse tirado
# esperando los 60 segundos sería la opción cómoda y revivir no significaría nada.
func _on_player_died(player: CharacterBody3D) -> void:
	var stats: PlayerStats = player.get_node("Stats")
	stats.revive(stats.max_health)
	# El punto lo decide el host; moverse hasta ahí es cosa del dueño del cuerpo.
	respawn_at.rpc_id(player.name.to_int(), _respawn_point(player.global_position))
	print("[world] muerte real del peer %s" % player.name)


# Pega el punto donde caíste al NavMesh más cercano. Corre en el host.
#
# map_get_closest_point() devuelve un Vector3, no un bool: NO falla nunca, así que
# "¿es navegable?" no se pregunta, se mide. Sin el chequeo de abajo, morir arriba
# de un techo o metido en una pared te dejaría pegado al polígono más cercano, que
# puede estar del otro lado del mapa.
func _respawn_point(fallen_at: Vector3) -> Vector3:
	var map: RID = get_world_3d().get_navigation_map()
	var snapped_point: Vector3 = NavigationServer3D.map_get_closest_point(map, fallen_at)
	var horizontal: float = Vector2(
		snapped_point.x - fallen_at.x,
		snapped_point.z - fallen_at.z,
	).length()

	if horizontal > MAX_RESPAWN_SNAP:
		return _fallback_respawn("%v está a %.2f m de NavMesh" % [fallen_at, horizontal])

	# Cerca no es lo mismo que alcanzable: ver _is_reachable().
	if not _is_reachable(snapped_point):
		return _fallback_respawn("%v cae en una isla de NavMesh sin salida" % snapped_point)

	print("[world] respawn: %v -> %v (%.2f m en horizontal)" % [
		fallen_at, snapped_point, horizontal,
	])
	return snapped_point


# ¿Se llega caminando desde el círculo de spawn hasta este punto? Corre en el host.
#
# map_get_closest_point() ignora la conectividad: devuelve el polígono más cercano
# aunque sea una isla a la que no se llega desde ningún lado, y entonces alguien que
# muere adentro de un edificio mal horneado respawnea encerrado ahí.
#
# Preguntarle a la región no sirve: map_get_closest_point_owner() y
# region_owns_point() devuelven lo mismo para el patio y para una isla adentro de un
# edificio, porque son la misma región. Verificado corriendo. Lo único que distingue
# es pedir un camino y mirar dónde termina — si el destino es inalcanzable, el
# camino corta antes de llegar.
#
# Medido: 26 µs por consulta, y esto corre una vez por muerte.
func _is_reachable(point: Vector3) -> bool:
	var map: RID = get_world_3d().get_navigation_map()
	# El círculo de spawn es el ancla conocida-buena: si ahí no se puede estar, no
	# hay partida. Se snapea igual por las dudas.
	var from: Vector3 = NavigationServer3D.map_get_closest_point(map, _spawn_position(0))
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, point, true)
	if path.is_empty():
		return false
	# map_get_path() devuelve un camino PARCIAL cuando el destino no se alcanza, así
	# que lo que decide es dónde termina, no que haya devuelto algo.
	var last: Vector3 = path[path.size() - 1]
	return Vector2(last.x - point.x, last.z - point.z).length() <= REACHABLE_TOLERANCE


func _fallback_respawn(reason: String) -> Vector3:
	var fallback: Vector3 = _spawn_position(_players.get_child_count())
	print("[world] respawn: %s, respaldo en %v" % [reason, fallback])
	return fallback


func _spawn_position(index: int) -> Vector3:
	# Repartidos en círculo: con los 4 jugadores de docs/design.md quedan a 90°
	# uno del otro. El 0.1 de alto es para no arrancar clavado en el piso.
	var angle: float = TAU * float(index) / 4.0
	return Vector3(cos(angle) * SPAWN_RADIUS, 0.1, sin(angle) * SPAWN_RADIUS)
