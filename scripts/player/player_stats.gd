class_name PlayerStats
extends Node

## Estado del jugador que resuelve el host. Hoy solo vida; en v0.4 entran hambre,
## sed y stamina, y en el paso 6 de v0.2 el flag de caído. Todo lo que viva acá
## adentro es autoridad del host (docs/netcode.md → "La regla").
##
## Es la otra mitad de la autoridad partida de la escena del jugador: el cuerpo
## (player.gd) es del peer dueño, esto es del host. Los dos conviven adentro de
## player.tscn con un MultiplayerSynchronizer cada uno.

## Se acabó el tiempo del caído: muerte real. La emite SOLO el host. La escucha
## world.gd, que es quien decide dónde respawnea — este nodo no sabe nada del
## mundo ni del NavMesh.
signal died

## El ID del host en Godot es siempre 1.
const HOST_PEER_ID: int = 1

## Vida máxima. NO se replica: está horneada en player.tscn, así que las tres
## máquinas ya la tienen igual. Solo se replica lo que cambia en runtime.
##
## Valor de arranque sin decidir todavía: docs/design.md no fija ningún número
## de vida.
@export var max_health: float = 100.0

## Cuánto dura el estado caído antes de morir de verdad, en segundos. Valor de
## arranque de docs/design.md, a tunear jugándolo.
##
## Es @export para poder bajarlo desde el Inspector mientras se prueba: esperar
## un minuto por intento hace que nadie repita el test.
@export var downed_duration: float = 60.0

## Vida actual. La escribe el host y baja replicada; el cliente solo la lee.
var health: float = 100.0

## Caído: la vida llegó a 0 pero todavía no moriste de verdad. Lo decide el host
## y baja replicado. El cliente lo lee para dejar de moverse, y eso es todo lo
## que cambia: el cuerpo sigue siendo suyo (docs/netcode.md → "El estado caído no
## reasigna autoridad").
var is_downed: bool = false

## Cuántos segundos le quedan al caído antes de morir de verdad. Lo escribe el
## host y baja replicado, así el propio caído ve el número y puede decidir si
## grita que vengan o si ya fue.
var downed_time_left: float = 0.0

## Cuánto lleva del revivir en curso, de 0 a 1. Lo escribe world.gd en el host y
## baja replicado: es lo que hace que el caído vea que lo están levantando.
var revive_progress: float = 0.0

## Quién lo está levantando, o 0 si nadie. Lo escribe world.gd y NO se replica:
## es cocina del host, y el cliente no tiene nada que decidir con esto.
var reviver_id: int = 0


# La autoridad de este nodo es el host, siempre, en las tres máquinas.
#
# Corre acá y no en player.gd a propósito: _enter_tree() va de padre a hijo, así
# que cuando esta línea corre, player.gd ya llamó
# set_multiplayer_authority(name.to_int()) con recursive en true y arrastró este
# nodo al peer dueño. Esta llamada corre después y lo devuelve al host.
#
# Cada nodo declara su propia autoridad: es el mismo patrón que ya usa player.gd,
# y escala solo cuando en v0.4 aparezcan más nodos de estado del host.
func _enter_tree() -> void:
	set_multiplayer_authority(HOST_PEER_ID)


# El timer del caído corre SOLO en el host. Si corriera en cada cliente, dos
# máquinas con latencias distintas llegarían a cero en momentos distintos y una
# vería morir a alguien que en la otra sigue caído (docs/netcode.md → "Paso 6").
#
# Vive en este nodo y no en un diccionario de world.gd a propósito: cuando el
# peer se desconecta, world.gd hace queue_free() del jugador y el countdown se va
# con él. Un diccionario quedaría apuntando a un nodo ya liberado.
func _process(delta: float) -> void:
	if not multiplayer.is_server() or not is_downed:
		return

	# Mientras alguien te está levantando, el reloj se para. Es lo que hace que
	# quedarte con un segundo todavía tenga salida: si el otro llega y mantiene la
	# tecla, se congela y da tiempo a salvarte; si suelta, morís al instante.
	#
	# Sin esto, tardar en llegar castiga al que salva incluso cuando llegó.
	#
	# Va contra reviver_id y no contra revive_progress porque el progreso arranca
	# en 0: con el progreso, el primer frame de cada revivir seguiría descontando.
	#
	# El orden importa y sale solo: world.gd es el padre, así que su _process()
	# corre antes que el de este nodo. Si el que levanta soltó o se alejó, para
	# cuando llega esta línea reviver_id ya volvió a 0 y el reloj sigue el mismo
	# frame.
	if reviver_id != 0:
		return

	downed_time_left = maxf(0.0, downed_time_left - delta)
	if downed_time_left > 0.0:
		return

	# emit() es sincrónico: para cuando vuelve, world.gd ya llamó a revive() e
	# is_downed quedó en false, así que el return de arriba corta la vuelta
	# siguiente y esto no se dispara dos veces.
	died.emit()


## Le baja vida a este jugador. La llama SOLO el host.
##
## En el paso 4 el zombie la va a llamar DIRECTO, sin pasar por
## world.gd::request_damage(): el zombie ya corre en el host, así que pedirse
## permiso a sí mismo por red no tendría sentido. El RPC es la puerta para los
## clientes, no el camino del daño.
func take_damage(amount: float) -> void:
	if not multiplayer.is_server():
		return
	# Un caído no recibe más daño: ya está en 0 y lo que corre a partir de ahí es
	# el timer, no la vida. Sin esto, un zombie que siguiera mordiendo lo dejaría
	# en 0 para siempre sin que pasara nada visible.
	if is_downed:
		return

	health = maxf(0.0, health - amount)
	if health <= 0.0:
		is_downed = true
		downed_time_left = downed_duration


## Lo pone de pie de nuevo con la vida que se le pase. La llama SOLO el host: hoy
## al vencerse el timer (muerte real) y en el paso 6d al completarse un revivir.
##
## Recibe la vida por parámetro y no la fija adentro porque son dos casos con
## números distintos —morir devuelve la vida llena, que te levanten devuelve
## menos— y en v0.3 el de revivir lo va a decidir el item médico.
##
## Dónde reaparece el cuerpo NO se decide acá: es cosa de world.gd, que es el que
## conoce el NavMesh.
func revive(amount: float) -> void:
	if not multiplayer.is_server():
		return
	health = clampf(amount, 0.0, max_health)
	is_downed = false
	downed_time_left = 0.0
