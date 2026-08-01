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

## Los dos patrones

Todo el código de red del proyecto entra en uno de estos dos moldes. Si estás escribiendo
algo que no encaja en ninguno, pará y preguntá antes de seguir.

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
func request_pickup(item_path: NodePath) -> void:
    if not multiplayer.is_server():
        return
    var sender_id: int = multiplayer.get_remote_sender_id()
    # 1. validar (¿existe el item? ¿está cerca? ¿le entra en el inventario?)
    # 2. aplicar en el host
    # 3. el resultado se replica por Synchronizer o por un RPC de confirmación
```

Flags de `@rpc`:
- `"any_peer"` — cualquiera puede llamarla (necesario para que el cliente pida algo)
- `"authority"` — solo el host puede llamarla (para confirmaciones host → clientes)
- `"call_local"` — se ejecuta también en quien la llamó
- `"reliable"` — garantiza entrega. Usar por defecto. `"unreliable"` solo para cosas que
  se mandan constantemente y da igual perder alguna

## Transporte: plan de migración

La creación del peer vive **solo** en `scripts/net/network_manager.gd`. El resto del
código nunca sabe qué transporte se usa. Cambiar de uno a otro tiene que ser un cambio de
diez líneas en un archivo.

| Etapa | Transporte | Qué resuelve | Costo |
|---|---|---|---|
| **Ahora → v0.5** | `ENetMultiplayerPeer` | Conexión por IP. Anda en LAN sin configurar nada. Por internet el host abre puerto en el router | $0 |
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
3. Al instanciar el jugador del peer N, el host llama `set_multiplayer_authority(N)` sobre
   la raíz del jugador. Eso es lo que hace que después `is_multiplayer_authority()` sea
   `true` en la máquina de N y `false` en las demás.
4. El script del jugador lee input y llama `move_and_slide()` **solo si**
   `is_multiplayer_authority()`. Las otras cápsulas no simulan nada: reciben el transform.
5. Un `MultiplayerSynchronizer` en el jugador replica posición y rotación. Su autoridad es
   la del peer dueño, igual que la raíz.
6. La cámara se activa (`current = true`) **solo** en la instancia local. Si no, cada
   cliente ve por los ojos de la última cápsula que se instanció.

**En v0.1 no hay un solo RPC del patrón 2**, porque todavía no hay estado del host que
pedir. El primero aparece en v0.2 con el daño. Que v0.1 no lo necesite es la señal de que
el milestone está bien recortado.

**Criterio de terminado:** host y cliente se ven moverse, en tiempo real, sin tirones, y
al cerrar el cliente el host no crashea. Eso último es la mitad del trabajo y es lo que
se suele olvidar.
