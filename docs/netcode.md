# Netcode

## Modelo: listen server con autoridad dividida

Un jugador corre el juego **y** la lógica de servidor en el mismo proceso. Los otros 1-3
se conectan como clientes. No hay servidor dedicado.

## La regla

La autoridad está partida en dos, y de qué lado cae cada cosa no se decide caso por caso:

> **El cuerpo del propio jugador es autoridad del peer dueño.
> Todo el resto del estado del juego es autoridad del host.**

| Estado | Autoridad | Check en código |
|---|---|---|
| Posición y rotación del propio jugador | Peer dueño | `is_multiplayer_authority()` |
| Vida, hambre, sed, stamina | Host | `multiplayer.is_server()` |
| Daño, muerte, respawn | Host | `multiplayer.is_server()` |
| Inventario, pickup, drop, contenedores | Host | `multiplayer.is_server()` |
| Zombies: spawn, IA, vida, ataque | Host | `multiplayer.is_server()` |
| Loot, día/noche, estado del mundo | Host | `multiplayer.is_server()` |

Un cliente mueve su propia cápsula y el `MultiplayerSynchronizer` la replica hacia afuera.
Pero un cliente nunca decide que le pegó a un zombie, que agarró un item, o que su hambre
bajó: manda "quiero atacar" / "quiero agarrar esto" por RPC y el host resuelve.

**Por qué el host es autoridad de todo lo demás:** no es anti-cheat (son 4 amigos). Es que
sin una única fuente de verdad, el estado diverge entre máquinas y aparecen bugs imposibles
de reproducir. Y retrofitear autoridad después es una reescritura completa, no un refactor.

**Por qué el movimiento es la excepción:** la alternativa —el cliente manda input, el host
simula, el host devuelve la posición— hace que cada paso se vea con un round-trip de
retraso. Para que eso no se sienta horrible hace falta *client-side prediction*: el cliente
simula localmente, guarda cada input, y cuando llega la corrección del host la reaplica
sobre el estado corregido. Es de las cosas más difíciles del netcode y no es por donde se
arranca un primer juego. Como no hay PvP ni nada que defender, confiarle al cliente su
propia posición cuesta cero y hace que el movimiento se sienta bien desde el día uno.

**El límite de la excepción:** el cliente es autoridad de *dónde está*, no de *qué implica*
estar ahí. Toda consecuencia de la posición —si llega a agarrar ese item, si el zombie lo
alcanza, si el disparo impacta— la sigue resolviendo el host, usando la posición ya
replicada. Si algún día el movimiento pasa a importar (PvP, competitivo, gente que no
conocemos), esto se revisa.

### Consecuencia: el jugador tiene la autoridad partida adentro

La escena del jugador no tiene un solo dueño. El cuerpo es del cliente, las stats son del
host. En la práctica son dos `MultiplayerSynchronizer` en la misma escena con autoridades
distintas:

- Uno sobre el transform del `CharacterBody3D` → autoridad del peer dueño.
- Otro sobre el nodo de stats (vida, hambre, sed, stamina) → autoridad del host (peer 1).

**Cuidado con `set_multiplayer_authority()`:** su firma es
`set_multiplayer_authority(id: int, recursive: bool = true)`. El `recursive` es `true` por
default, así que llamarla en la raíz del jugador se la aplica **también al nodo de stats**
y te lleva silenciosamente el estado de vida y hambre al cliente. Hay que volver a poner
las stats en el host explícitamente después, o pasar `recursive = false` y asignar a mano.

Tenerlo claro ahora evita el refactor de v0.2 y v0.4, cuando aparezcan vida y hambre y haya
que meterlas en una escena que asumía un solo dueño.

### El estado caído no reasigna autoridad

Cuando un jugador queda caído (v0.2), su cuerpo **sigue siendo autoridad del peer dueño**.
No se llama `set_multiplayer_authority()` en runtime para pasárselo al host y devolvérselo
al levantarlo.

| | Quién |
|---|---|
| Decidir que quedaste caído, el timer de 60 s, la muerte real y el respawn | Host |
| Que un compañero te levante | Host, por RPC del patrón 2 |
| Dejar de moverte mientras estás caído | El cliente, respetando su propio flag |

El flag de caído va en el nodo de stats, así que es estado del host y baja replicado como
la vida. El cliente lo lee y sale temprano de `_physics_process`, igual que ya sale cuando
no es la autoridad del nodo.

**Por qué le confiamos esto al cliente:** un cliente que ignore su propio flag puede
caminar estando caído, y eso es todo lo que puede hacer — el host sigue decidiendo si lo
levantan, si muere y dónde respawnea. La alternativa es cambiar la autoridad del cuerpo en
caliente, que toca el `MultiplayerSynchronizer` mientras está corriendo y es de las cosas
que más bugs raros dan y peor se debuggean. Sin PvP ni nada que defender, no vale el
riesgo en un primer proyecto.

*Rejected: reasignar la autoridad del cuerpo al host mientras dura el caído | toca el
Synchronizer en caliente a cambio de defender algo que no existe.*

## Herramientas de Godot

| | Para qué |
|---|---|
| `MultiplayerSynchronizer` | Estado continuo que cambia todo el tiempo: posición, rotación, animación |
| `MultiplayerSpawner` | Instanciar y destruir nodos en red: zombies, items dropeados, jugadores |
| `@rpc` | Eventos discretos: "disparé", "agarré esto", "abrí esta puerta" |

No usar RPC para estado que cambia cada frame. Para eso está el Synchronizer.

El `MultiplayerSynchronizer` replica **desde la autoridad del nodo hacia todos los demás**.
O sea que la autoridad no es un permiso: es la dirección en la que fluyen los datos. Por eso
el transform del jugador tiene autoridad del cliente (fluye cliente → host → resto) y las
stats tienen autoridad del host (fluye host → todos).

### Advertencia para v0.3: el Synchronizer no sincroniza el inventario

El `MultiplayerSynchronizer` maneja **primitivas y tipos built-in**: `float`, `int`, `bool`,
`Vector3`, `Transform3D`. Vida, hambre, sed y stamina entran ahí sin problema, y por eso
v0.1, v0.2 y v0.4 no se topan con este límite.

El inventario sí. Un inventario es una estructura anidada —una lista de slots, cada uno con
un item, una cantidad y quizás durabilidad— y eso **no lo replica el Synchronizer solo**.
Hay que encodearlo y decodearlo a mano en un `PackedByteArray`. Unity trae `SyncList` y
`SyncDictionary` para esto; Godot no trae equivalente.

**No asumir que el Synchronizer lo resuelve.** Cuando llegue v0.3, la serialización del
inventario es una tarea propia con su propio presupuesto de tiempo, no un detalle de la
tarea de inventario. Si el diseño del inventario se elige asumiendo que la replicación es
gratis, se elige mal.

## Los tres patrones

Todo el código de red del proyecto entra en uno de estos tres moldes. Si estás escribiendo
algo que no encaja en ninguno, pará y preguntá antes de seguir.

*(Eran dos hasta el paso 6 de v0.2. El tercero apareció al implementar el respawn: hacía
falta que el host moviera un cuerpo que no es suyo.)*

### 1. Movimiento propio — el cliente manda

```gdscript
# En el script del jugador. Solo el dueño lee input y mueve el cuerpo;
# el Synchronizer del transform se encarga de replicarlo hacia afuera.
func _physics_process(delta: float) -> void:
    if not is_multiplayer_authority():
        return
    # leer input, mover, move_and_slide()
```

### 2. Todo lo demás — el cliente pide, el host decide

```gdscript
# Cliente pide, host decide, host replica.
@rpc("any_peer", "call_local", "reliable")
func request_pickup(item_id: String) -> void:
    if not multiplayer.is_server():
        return
    var sender_id: int = multiplayer.get_remote_sender_id()
    # 1. validar (¿existe el item? ¿está cerca? ¿le entra en el inventario?)
    # 2. aplicar en el host
    # 3. el resultado se replica por Synchronizer o por un RPC de confirmación
```

El parámetro es un **ID, no un `NodePath`** — la razón está abajo, en "El mundo es del
host".

Flags de `@rpc`:
- `"any_peer"` — cualquiera puede llamarla (necesario para que el cliente pida algo)
- `"authority"` — solo el host puede llamarla (para confirmaciones host → clientes)
- `"call_local"` — se ejecuta también en quien la llamó
- `"reliable"` — garantiza entrega. Usar por defecto. `"unreliable"` solo para cosas que
  se mandan constantemente y da igual perder alguna

### 3. La orden del host al dueño del cuerpo

Para cuando el host decide algo sobre el cuerpo de un cliente. Hoy hay un solo caso —el
respawn— pero va a haber más: teletransportes, empujones, que un zombie te agarre.

**El host no puede escribirle la posición a un cuerpo que no es suyo.** El
`MultiplayerSynchronizer` replica desde la autoridad hacia afuera, y la autoridad del
cuerpo es el peer dueño: si el host escribe `player.global_position`, el cliente se la pisa
en el tick siguiente con la suya. Entonces el host no mueve el cuerpo, **le ordena al dueño
que se mueva**:

```gdscript
# En world.gd. La manda el host; corre en la máquina del dueño, que se mueve a sí
# mismo y replica hacia afuera como siempre.
@rpc("authority", "call_local", "reliable")
func respawn_at(point: Vector3) -> void:
    var player: Player = _players.get_node_or_null(
        NodePath(str(multiplayer.get_unique_id()))
    ) as Player
    if player == null:
        return
    player.teleport_to(point)   # método normal, no RPC

# host: respawn_at.rpc_id(peer_id, point)
```

**La trampa, y es fácil de comer:** `"authority"` significa *"solo la autoridad de **este
nodo** puede llamarla"*, no *"solo el host"*. Verificado en la doc de 4.7
(`MultiplayerApi.RPCMode`): `RPC_MODE_AUTHORITY` restringe la llamada a la autoridad actual
del nodo, que es el host **solo si nadie la reasignó**.

Por eso esta RPC va en `world.gd` y no en `player.gd`. La autoridad de `World` es el peer 1
en las tres máquinas; la de `player.gd` es el **cliente dueño**, así que declarada ahí el
flag diría lo contrario de lo que queremos y el host no podría llamarla nunca.

> **Regla práctica: una RPC con `"authority"` solo hace lo que parece si está en un nodo
> cuya autoridad no se reasigna.** En cualquier nodo con autoridad de cliente, va
> `"any_peer"` y se valida `get_remote_sender_id() == 1` a mano.

El método que toca el transform (`teleport_to()`) vive en `player.gd` y es una función
normal. La RPC solo elige la máquina; quién escribe el cuerpo sigue siendo su dueño.

## El patrón del modificador: el host manda el número, el cliente lo aplica

Es donde se tocan los dos patrones de arriba, y se va a repetir cada vez que aparezca algo
que cambie cuánto corrés. Por eso tiene nombre propio.

> **El host calcula el modificador de velocidad y lo replica. El cliente lo recibe y lo
> multiplica por su velocidad al moverse. El cliente nunca calcula el modificador: solo lo
> recibe y lo usa.**

```gdscript
# En el nodo de stats — autoridad del host, baja replicado como la vida.
var speed_multiplier: float = 1.0

# En el script del jugador — el movimiento sigue siendo del cliente dueño,
# el número no.
func _physics_process(delta: float) -> void:
    if not is_multiplayer_authority():
        return
    var speed: float = base_speed * stats.speed_multiplier
    # leer input, mover, move_and_slide()
```

**Ya aplica hoy a la stamina.** Cuánta stamina te queda es estado del host
(`multiplayer.is_server()`, ver la tabla de arriba), así que la penalización por quedarte
sin aire entra por acá: el host baja la stamina, el host baja el `speed_multiplier`, el
cliente se mueve más lento sin haber decidido nada.

Casos que ya sabemos que van a usar el mismo molde:

| Caso | Milestone |
|---|---|
| Sobrepeso: pasarte de la capacidad de carga | v0.3 |
| Stamina agotada al correr | v0.4 |
| Heridas, temperatura | v2, si llegan |

**Ojo con el sobrepeso: "no podés correr" no es un multiplicador, es un permiso.** El host
manda las dos cosas —el número que te frena y un `can_sprint: bool`— y el cliente respeta
las dos. Un multiplicador solo te hace más lento; no apaga la corrida.

**Por qué el cliente no lo calcula:** no tiene con qué. El peso que carga, si la mochila
está equipada, cuánta stamina le queda y cuál es la capacidad máxima son estado del host.
Si el cliente estimara el modificador por su cuenta, las dos máquinas tendrían reglas
paralelas que se van a desincronizar apenas una de las dos cambie, y el bug aparece como
"a veces corro raro", que es de los peores de encontrar. Con una sola fuente del número,
el cliente no tiene nada que adivinar.

Igual que con el estado caído, esto es confianza: si un cliente ignora el modificador,
corre rápido con sobrepeso. Es la misma decisión tomada dos veces y por la misma razón —
no hay nada que defender.

## El mundo es del host

El estado del mundo —contenedores vaciados, loot en el piso, bolsas de muerte, día/noche—
es del host, así que **el guardado de v0.5 es un archivo en la máquina de quien hostea.**

Consecuencia aceptada: **si hostea el otro, es otro mundo.** No hay migración de partida
entre máquinas, ni save compartido. Es la opción simple y alcanza para dos personas.

→ Si en algún momento molesta, la solución es **que hostee siempre el mismo**, no
sincronizar saves. Sincronizarlos es un sistema nuevo entero (¿quién gana si los dos
jugaron?) y no lo vale.

### Los contenedores necesitan ID persistente, no `NodePath`

Todo lo que el save tenga que volver a encontrar después —contenedores, puertas, spawns—
se identifica por un **ID estable propio**, no por su ruta en el árbol de escena:

```gdscript
@export var container_id: String = ""   # único y estable, no se cambia nunca más
```

Un `NodePath` es la posición del nodo en el árbol, así que renombrar un nodo, moverlo de
lugar o reordenar hermanos lo cambia. Un save viejo pasa entonces a apuntar a otro
contenedor o a ninguno, y el síntoma —"el armario que había vaciado volvió a tener loot"—
no se parece en nada a la causa. Con `@export`, el ID queda escrito en el `.tscn` y se
revisa en el diff.

Lo mismo vale para los RPC del patrón 2: el cliente manda el ID del contenedor o del item,
no un `NodePath`, porque el árbol de escena del cliente no tiene por qué ser idéntico al
del host.

**Dónde aparece cada mitad:** los IDs se crean en **v0.3**, cuando entran los contenedores
registrables. El save que los lee es **v0.5**. Que la primera mitad llegue dos milestones
antes que la segunda es justo el problema — si en v0.3 se usan node paths porque "todavía
no hay save", en v0.5 hay que volver a tocar cada contenedor del mapa.

### Qué entra al save

Lista viva. Se completa en v0.5, pero cada cosa que entre acá impone requisitos **antes**
—un ID estable, un formato serializable— así que se anota cuando se decide, no cuando se
implementa.

| Entra al save | Qué guarda | Se decidió en |
|---|---|---|
| Contenedores | Qué le queda a cada uno, por `container_id` | v0.3 |
| **Bolsas de muerte** | Posición, contenido e ID propio (ver abajo) | v0.3 |
| Hora del día | Dónde quedó el ciclo | v0.5 |

**No registrado todavía** —y hay que decidirlo antes de escribir el save, no después:

- **Los items tirados en el piso**, ¿sobreviven al cierre del juego o se pierden? Si
  sobreviven, necesitan ID propio igual que los contenedores.
- **El inventario y las stats de cada jugador**, ¿persisten entre sesiones? Y si persisten,
  ¿qué pasa con el inventario de alguien que no está conectado cuando el host guarda?
- **Los zombies**, que probablemente no entren —respawnean— pero conviene decirlo
  explícitamente en vez de que quede implícito.

## La bolsa de muerte es una entidad de red, no un item

Cuando morís de verdad (v0.3), el inventario queda en una bolsa donde caíste. **Es la
entidad más cara de v0.3 y es fácil subestimarla porque en el diseño ocupa dos renglones.**

No es un item: un item vive adentro de un inventario. La bolsa **contiene** un inventario
entero y existe sola en el mundo. Lo que arrastra:

| Necesita | Por qué |
|---|---|
| `MultiplayerSpawner` | Nace en runtime, no está en la escena. Solo el host la instancia |
| La serialización de inventario de v0.3 | Contiene un inventario entero — el mismo problema del `PackedByteArray` de arriba, otra vez |
| RPC del patrón 2 para sacar cosas | El host valida quién saca qué. Solo jugadores: los zombies no la tocan |
| Chequeo de vacío en el host | Cada vez que alguien saca algo, el host mira si quedó vacía y recién ahí la despawnea. **No despawnea por tiempo** |
| ID persistente propio | Entra al save de v0.5. Misma razón que los contenedores |

**La consecuencia que se pasa por alto:** una bolsa que nadie vació tiene que **sobrevivir
a que se cierre el juego**. Se muere a las once de la noche, se apaga todo, y al día
siguiente la bolsa tiene que estar donde estaba y con lo mismo adentro. Eso la mete en el
save de v0.5 sí o sí, y significa que en v0.3 la bolsa se escribe pensando en que va a
tener que serializarse — no como un nodo temporal que vive lo que dura la sesión.

Si en v0.3 la bolsa se hace "rápido" como algo que existe solo en memoria, v0.5 la
reescribe entera.

## Transporte: plan de migración

La creación del peer vive **solo** en `scripts/net/network_manager.gd`. El resto del
código nunca sabe qué transporte se usa. Cambiar de uno a otro tiene que ser un cambio de
diez líneas en un archivo.

| Etapa | Transporte | Qué resuelve | Costo |
|---|---|---|---|
| **Ahora → v0.6** | `ENetMultiplayerPeer` | Conexión por IP. Anda en LAN sin configurar nada. Por internet el host abre puerto en el router | $0 |
| **v1.0** | `netfox.noray` | NAT punchthrough + relay de respaldo. Los amigos se conectan con un código, sin tocar el router | $0 |
| **Si algún día va a Steam** | `SteamMultiplayerPeer` (expressobits) + GodotSteam | Steam maneja NAT, lobbies e invitaciones por el overlay. En desarrollo se usa el App ID 480 (Spacewar) gratis | USD 100 por App ID, recuperable a los USD 1.000 de revenue |

## Testear en una sola máquina

Godot corre varias instancias del proyecto a la vez: **Debug → Customize Run Instances**.
Levantar host + 2 clientes en la misma PC. Sin esto, testear multiplayer es insoportable.

## Objetivo de la v0.1

Dos cápsulas moviéndose sincronizadas en una caja, host + 1 cliente por IP en LAN, en
primera persona. Sin zombies, sin items, sin UI más allá de dos botones.

Es el milestone más importante del proyecto: si el esqueleto de red no está limpio acá,
todo lo que se construya encima hereda el problema.

### Cómo se resuelve v0.1 con este modelo

Concreto, para que no haya que decidirlo mientras se escribe:

1. `scripts/net/network_manager.gd` crea el `ENetMultiplayerPeer` — hostear en un puerto
   fijo, o conectarse a una IP. Es el único archivo que sabe qué transporte se usa.
2. El **host** es el único que instancia jugadores. Un `MultiplayerSpawner` en la escena
   del mundo replica cada instancia al resto.
3. **La autoridad no se replica: cada máquina la deduce del nombre del nodo.** El host
   nombra al jugador con el ID de su peer (`"1"`, `"1043872"`), el nombre viaja con el
   spawn, y el script del jugador hace `set_multiplayer_authority(name.to_int())` en su
   `_enter_tree()`. Va en `_enter_tree()` y no en `_ready()` porque el
   `MultiplayerSynchronizer` hijo ya necesita saber quién manda al entrar al árbol.
   Acá `recursive = true` es lo correcto —el Synchronizer necesita la misma autoridad que
   la raíz—; la trampa aparece en v0.2 con el nodo de stats.
4. El script del jugador lee input y llama `move_and_slide()` **solo si**
   `is_multiplayer_authority()`. Las otras cápsulas no simulan nada: reciben el transform.
5. Un `MultiplayerSynchronizer` en el jugador replica posición y rotación. Su autoridad es
   la del peer dueño, igual que la raíz.
6. La cámara se activa (`current = true`) **solo** en la instancia local. Si no, cada
   cliente ve por los ojos de la última cápsula que se instanció.

7. El cliente, apenas termina de cargar el mundo, le avisa al host por RPC. **Recién ahí**
   el host lo spawnea. El porqué está abajo.

### v0.1 sí tiene un RPC, y no es opcional

*(Corregido al implementarlo. Este doc decía que v0.1 no tenía ninguno, y era falso.)*

El razonamiento original era que v0.1 no necesita RPCs porque no hay estado del host que
pedir. Es cierto para el **gameplay** y sigue siendo cierto: no hay vida, ni inventario, ni
nada que validar. Pero el spawn tiene una carrera que no se ve razonándola:

- El host spawnearía al jugador del peer N al recibir `peer_connected(N)`.
- El cliente cambia a `world.tscn` al recibir `connected_to_server`.
- Las dos señales disparan en el mismo instante, pero `change_scene_to_file()` **se difiere
  al final del frame**.

**En LAN el RTT es menor a 1 ms y un frame son 16 ms.** O sea que el paquete de spawn llega
al cliente antes de que exista el `MultiplayerSpawner` de su lado, y se descarta. El
síntoma sería "a veces el otro jugador no aparece", dependiendo de la latencia — justo la
clase de bug que este documento dice que la autoridad única existe para evitar.

La solución es un handshake de una línea: el cliente manda
`notify_world_ready.rpc_id(1)` desde el `_ready()` de `world.gd`, y el host spawnea al
recibirlo. Entra en el patrón 2 —el cliente pide, el host decide y valida el
`get_remote_sender_id()`— aunque no sea gameplay.

**La lección general, que vale para v0.2 en adelante:** cargar una escena no es
instantáneo, así que **nada que dependa de que el otro lado tenga un nodo se puede mandar
al mismo tiempo que la conexión**. Cuando el mundo tarde en cargar de verdad, esto se
agrava, no se alivia.

**Criterio de terminado:** host y cliente se ven moverse, en tiempo real, sin tirones, y
al cerrar el cliente el host no crashea. Eso último es la mitad del trabajo y es lo que
se suele olvidar.

## Cómo se resuelve v0.2

**Objetivo:** un zombie que persigue por NavMesh y pega. Vida del jugador, caído, revivir,
muerte y respawn. Todo el daño resuelto en el host.

**v0.2 suma tres RPCs del patrón 2** —el daño, `request_revive_start` y
`request_revive_stop`— **y el primero del patrón 3**, `respawn_at`. Los del patrón 2 validan
en el host y usan la posición ya replicada, nunca una que mande el cliente. (Son los
primeros de *gameplay*; el primero del proyecto es el handshake de spawn de v0.1.)

### El orden, y qué depende de qué

El orden no es preferencia: hay dependencias reales y una que no es obvia.

| # | Paso | Depende de |
|---|---|---|
| 1 | **Greybox mínimo + `NavigationRegion3D` horneada** | — |
| 2 | **Nodo de stats con autoridad del host + segundo `MultiplayerSynchronizer`** | — |
| 3 | **RPC de daño** (patrón 2) | 2 |
| 4 | **Escena del zombie + `MultiplayerSpawner`**, solo el host instancia | 3 |
| 5 | **IA de persecución**, corre solo en el host | 1, 4 |
| 6 | **Caído, revivir y respawn** | 1, 2, 3 |

**La dependencia que no es obvia es la del paso 1 con el paso 6.** El NavMesh parece cosa
del zombie —hace falta para que persiga—, pero el respawn "cerca de donde caíste" también
lo necesita: hay que validar que el punto de respawn sea navegable. Si el NavMesh se deja
para cuando toque la IA, el último paso del milestone queda bloqueado por algo que se
podría haber hecho primero. **Por eso el NavMesh va antes que el zombie, no con el zombie.**

Los pasos 2 y 3 se pueden hacer en paralelo con el 1: no se tocan.

### Paso 2: el segundo Synchronizer

Es la primera vez que la escena del jugador tiene dos autoridades adentro (ver "El jugador
tiene la autoridad partida adentro", arriba). El transform sigue siendo del peer dueño; el
nodo de stats —vida, y en v0.4 hambre, sed y stamina— es del host.

**Acá es donde muerde la trampa de `set_multiplayer_authority(id, recursive = true)`.** El
host se la aplica a la raíz del jugador al instanciarlo (paso 3 de v0.1), y con `recursive`
en `true` se lleva también el nodo de stats. En v0.1 no se notaba porque no había stats.
En v0.2 sí: la vida termina siendo autoridad del cliente y el host deja de poder aplicar
daño. Reasignar las stats al host explícitamente, o pasar `recursive = false`.

### Paso 6: caído, revivir y respawn

Las tres cosas son del host. El cliente solo respeta su propio flag de caído y deja de leer
input (ver "El estado caído no reasigna autoridad").

**Revivir es mantener la tecla, y son dos RPCs, no uno.** *(Ajustado al implementarlo: este
doc suponía un `request_revive` de un solo disparo.)* Mantener una tecla es un estado que
dura, y mandarlo por RPC cada frame está prohibido más arriba. Entonces se mandan los dos
**bordes** —empecé, solté— y el progreso lo lleva el host:

```gdscript
@rpc("any_peer", "call_local", "reliable")
func request_revive_start(target_peer_id: int) -> void:
@rpc("any_peer", "call_local", "reliable")
func request_revive_stop() -> void:
```

`request_revive_stop()` **no lleva a quién estaba levantando**: el host ya lo sabe, y así un
cliente no puede cortarle el revivir a otro.

El progreso (0 a 1) vive en el nodo de stats **del caído** y baja replicado, que es lo que
hace que el caído vea que lo están levantando. El host lo avanza y **revalida entero cada
frame**: eso cubre alejarse, que al que levanta lo tiren, y que se desconecte a mitad de
camino, sin escribir un caso especial para cada uno.

**Todas las condiciones viven en una sola función del host**, `_can_revive()`, y el cliente
no conoce ninguna: solo pide. Es a propósito — en v0.3, "el que levanta necesita una venda"
se agrega adentro de esa función y no se toca ni una línea del cliente.

```gdscript
func _can_revive(healer: Node3D, target: Node3D) -> bool:
    # 1. ¿el target está caído?
    # 2. ¿el que levanta está de pie? (un caído no levanta a otro caído)
    # 3. ¿están a menos de REVIVE_RANGE?
    # v0.3: 4. ¿el que levanta tiene una venda?
```

Levantarse a uno mismo queda descartado sin chequearlo aparte: si estás caído no pasás el
punto 2, y si no lo estás no pasás el punto 1.

**La validación de distancia la hace el host con las posiciones que ya tiene replicadas**,
no con una distancia que mande el cliente. Es exactamente el límite de la excepción de
movimiento: el cliente decide dónde está, el host decide qué implica estar ahí.

**Ni el timer del caído ni el revivir se guardan en un diccionario de `world.gd`.** El
countdown vive adentro del nodo de stats de cada jugador, y el revivir se recorre iterando
los hijos vivos de `Players`. Los dos por la misma razón: cuando un peer se desconecta, su
jugador se libera, y un diccionario quedaría apuntando a un nodo que ya no existe. Es
justamente lo que mide el criterio de terminado de abajo.

El timer de 60 segundos también corre en el host. Si corriera en cada cliente, dos máquinas
con latencias distintas llegarían a cero en momentos distintos.

**Y se congela mientras alguien te está levantando.** *(Salió del playtest: hasta entonces
seguía bajando y se podía morir a mitad de un revivir que iba a completarse.)* Es lo que
hace que quedarte con un segundo todavía tenga salida — si el otro llega y mantiene la
tecla, el reloj se para; si suelta, morís al instante. Sin eso, tardar en llegar castiga al
que salva incluso cuando llegó a tiempo.

El chequeo va contra `reviver_id` y no contra `revive_progress`, porque el progreso arranca
en 0 y el primer frame de cada revivir seguiría descontando. El orden sale solo del árbol:
`world.gd` es el padre, así que su `_process()` corre antes y, si el que levanta soltó o se
alejó, `reviver_id` ya volvió a 0 cuando el timer mira — o sea que el reloj sigue el mismo
frame, no el siguiente.

### El respawn tiene que caer sobre el NavMesh

"Respawneás cerca de donde caíste" no es "en el mismo punto donde caíste". Se puede morir
adentro de un contenedor, contra una pared o en un techo, y ahí no hay dónde pararse.

```gdscript
# En el host. Pegar el punto deseado al NavMesh más cercano.
var map: RID = get_world_3d().get_navigation_map()
var snapped: Vector3 = NavigationServer3D.map_get_closest_point(map, wanted_point)
```

**Verificado contra el editor 4.7.1-stable por MCP**, porque es justo el tipo de API que se
alucina:

| Llamada | Firma real en 4.7.1 |
|---|---|
| `World3D.get_navigation_map()` | `-> RID`, sin argumentos |
| `NavigationServer3D.map_get_closest_point()` | `(map: RID, to_point: Vector3) -> Vector3` |
| `NavigationServer3D.map_get_random_point()` | `(map: RID, navigation_layers: int, uniformly: bool) -> Vector3` |
| `NavigationServer3D.map_force_update()` | `(map: RID) -> void` |

**Lo que la firma implica y hay que manejar:** `map_get_closest_point` devuelve un
`Vector3`, no un `bool`. **No falla nunca**: siempre devuelve el punto más cercano del
NavMesh, esté a 10 cm o a 40 metros. Así que "validar que el punto sea navegable" no es
preguntarle a la función, es comparar la distancia contra un umbral.

**Y esa distancia se mide en horizontal, no en 3D.** *(Corregido al implementarlo: la
versión anterior de este doc comparaba `snapped.distance_to(wanted_point)` y no habría
funcionado.)*

El NavMesh horneado de `yard.tscn` queda **0.3 m por encima del piso**: sus vértices están
en `y = 0.3` y la cara de arriba del `Floor` en `y = 0.0`. O sea que una distancia en 3D
**nunca baja de 0.3 m**, ni parado en medio del patio, y un umbral chico dispararía el
respaldo siempre. Medir solo en x/z además es lo que "me respawneó del otro lado del mapa"
significa de verdad.

```gdscript
var horizontal: float = Vector2(
    snapped_point.x - fallen_at.x,
    snapped_point.z - fallen_at.z,
).length()
if horizontal > MAX_RESPAWN_SNAP:
    # demasiado lejos: usar un punto de respawn de respaldo
```

Sin ese chequeo, morir en un lugar sin NavMesh cerca te respawnea pegado al polígono más
próximo, que puede estar del otro lado del mapa.

**Ese mismo offset de 0.3 m resuelve el "enterrado o flotando":** el punto snapeado cae
siempre **por encima** de la superficie caminable, nunca adentro, así que no hay forma de
aparecer enterrado. Aparecés 0.3 m en el aire y la gravedad te apoya en ~0.25 s.

Verificado corriendo 4.7.1 sobre el greybox actual: muriendo en el centro del patio el
punto snapeado da `y = 0.300` exacto, y un segundo después el cuerpo queda en `y = 0.0001`
con `is_on_floor()` en `true`. Muriendo en `(100, _, 100)` —fuera del patio— la distancia
horizontal da 99.70 m y dispara el respaldo.

`map_force_update()` existe y es la salida si una consulta devuelve resultados viejos
porque el mapa todavía no se sincronizó. **Su semántica exacta no la verificamos:** si
aparece el síntoma, chequear la documentación antes de usarla.

**Criterio de terminado:** dos jugadores, un zombie. Uno cae, el otro lo levanta a tiempo.
Uno cae, nadie llega, muere y respawnea parado sobre el piso —no adentro de una pared—.
El host nunca aplica daño dos veces por el mismo golpe, y cerrar el cliente mientras está
caído no cuelga el timer del host.
