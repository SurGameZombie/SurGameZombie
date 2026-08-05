# Diseño

**Nombre: SurGameZombie**, provisorio. Es el mismo nombre del repo y de la organización.
El definitivo se elige en v1.0; hasta entonces no bloquea nada.

## Qué es

Survival co-op en primera persona para 2-4 jugadores. Un jugador hostea y juega en el
mismo proceso; el resto se conecta.

El loop central: explorar → lootear → consumir → sobrevivir un poco más. Los zombies
son la presión, la escasez es la dificultad.

Referencias de tono: SurrounDead, DayZ, Road to Vostok. Realismo por escasez y
consecuencia, no por cantidad de sistemas.

## Ambientación

**Un complejo industrial:** fábrica, depósitos, oficinas, playa de camiones.

Por qué: 250 × 250 m son unas 2 × 2 manzanas, así que "pueblo" no entra. Un complejo es
lo más fácil de greyboxear, justifica interiores densos y encaja con el loot elegido
(palanca, llaves, bidones).

**El greybox de v0.2 es un patio de 60 × 60 m**: un depósito con columnas, un bloque de
oficinas, una playa de camiones con contenedores y un patio abierto. No es el mapa final —
es el pedazo mínimo donde una persecución significa algo. Las medidas que fija están abajo
y son contra las que se dimensiona el resto del complejo cuando crezca.

Tres criterios de diseño que salieron de armarlo, y que valen para todo el mapa:

- **Cada edificio tiene al menos dos aberturas.** Un edificio con una sola puerta no es un
  espacio, es una trampa mortal sin decisión: entrás y ya perdiste. Los loops son lo que
  hace que huir sea jugar.
- **Los callejones sin salida son salas, no edificios.** Se cuelgan de un pasillo que sí
  tiene salida, así que meterte en uno es una decisión mala tuya y no del mapa.
- **La cobertura sin paredes vale tanto como las paredes.** Los contenedores cortan la
  línea de visión sin cerrar el espacio, y son lo que permite perder de vista a algo que te
  persigue.

## Qué NO es

- No es mundo abierto. Un mapa cerrado y denso, de sesión de 30-60 minutos.
- No es un shooter. El combate es escaso, torpe y peligroso.
- No es PvP. Solo cooperativo contra el entorno.
- No tiene personalización de personaje en la v1.
- No tiene base building en la v1.
- No tiene crafteo profundo en la v1.
- **No tiene condición de victoria.** Supervivencia infinita: la sesión termina cuando
  termina, no cuando se gana.

## Sistemas de la v1

**Stats:** vida, hambre, sed, stamina. Nada más.
Temperatura, heridas y enfermedad quedan para después, si el loop base funciona.

**Enemigo:** un solo tipo de zombie. Lento, peligroso en grupo, ruidoso al detectarte.

**Inventario: limitado por peso.** No por slots ni por grid. Los items ocupan espacio
real, llevar munición cuesta.

Por qué el peso: es lo coherente con supervivencia realista — te obliga a elegir entre
agua y balas.

*Rejected: grid tipo Tarkov (peso + posición en cuadrícula) | duplica el trabajo de UI y
empeora la serialización de red, porque cada item pasa a guardar posición y rotación
además de cantidad. Si más adelante se siente plano, migrar es reescribir la UI de
inventario entera.*

**Capacidad: 25 kg sin mochila, 40 kg con mochila equipada.** Valores de arranque.

Al pasarte de la capacidad **caminás más lento y no podés correr**. No hay bloqueo duro:
levantás lo que quieras, lo pagás moviéndote. El multiplicador exacto se tunea jugando.
Lo que sí está decidido es que correr se apaga del todo y no se penaliza un poco: una
penalización suave no cambia ninguna decisión, y el punto del peso es que te obligue a
dejar algo atrás.

En red esto es el **patrón del modificador** (`docs/netcode.md`): el host calcula cuánto
te frena el peso, el cliente lo aplica al moverse. Igual que la stamina.

**Slots de equipo: dos, mochila y arma en mano.** Aparte del inventario por peso.

No contradice "inventario por peso": **el peso limita qué cargás, los slots definen qué
tenés puesto.** Son dos preguntas distintas —cuánto llevás encima, y qué estás usando— y
mezclarlas es lo que vuelve confusos a los inventarios.

| Slot | Qué hace | Cuándo |
|---|---|---|
| Mochila | Sube la capacidad de 25 a 40 kg. Sin mochila equipada, 25 | v0.3 |
| Arma en mano | Qué usás al atacar. Vacío = manos | v0.5 |

**Solo esos dos por ahora.** Nada de casco, chaleco ni ropa: cada slot nuevo es UI,
serialización de red y una decisión de balance más, y ninguno de esos tres cambia el loop.

**Armas:** un melee y una de fuego. La munición es rara. Disparar atrae zombies.

**Muerte: caído primero, muerto después.** Son dos mecánicas que llegan en milestones
distintos.

- **Caído (v0.2).** Al morir quedás caído, no muerto. Un compañero puede levantarte. Si
  nadie llega en **60 segundos** —valor de arranque, a tunear— morís de verdad y
  respawneás cerca de donde caíste.
  Por qué: hace el co-op cooperativo de verdad y mantiene la tensión sin que morir
  arruine la sesión.
  En red, el cuerpo sigue siendo del cliente estando caído: el host decide que caíste y el
  cliente respeta su propio flag dejando de leer input (`docs/netcode.md` → "El estado
  caído no reasigna autoridad").
- **Muerto de verdad (v0.3).** El inventario queda en una **bolsa** donde caíste. Solo
  los jugadores pueden saquearla, los zombies no. La bolsa **no despawnea por tiempo**:
  desaparece cuando queda vacía.
  En red la bolsa **no es un item, es una entidad propia**, y es la pieza más cara de
  v0.3: spawner, inventario entero serializado, chequeo de vacío en el host y guardado en
  v0.5 (`docs/netcode.md` → "La bolsa de muerte es una entidad de red, no un item"). En el
  diseño ocupa dos renglones; en el código, no.
- **El mundo persiste.** Los contenedores vaciados siguen vacíos y el mapa no se resetea.
  **Esto hace que el guardado de v0.5 sea obligatorio, no opcional.**
  El save vive en la máquina de quien hostea, así que **si hostea el otro, es otro
  mundo.** Es la opción simple y la aceptamos. Si en algún momento molesta, la solución es
  que hostee siempre el mismo, no sincronizar saves (ver `docs/netcode.md` → "El mundo es
  del host").

## Escala y números base

**Valores de arranque, para tunear.** Están acá para que nada se escriba con números
inventados, no porque estén balanceados: el ajuste fino sale de jugarlo.

| | |
|---|---|
| Escala del mundo | 1 unidad de Godot = 1 metro |
| Altura del jugador | 1.8 m |
| Radio de la cápsula del jugador | 0.4 m |
| Altura de la cámara | 1.65 m |
| Velocidad de caminata | 4 m/s |
| Velocidad de corrida | 7 m/s |
| Velocidad del zombie | 3.7 m/s |
| Control en el aire | 0.25 |
| Capacidad de carga sin mochila | 25 kg |
| Capacidad de carga con mochila | 40 kg |
| Greybox de v0.2 | 60 × 60 m |
| Ancho de puerta industrial | 2.0 m |
| Ancho de puerta interior | 1.4 m |
| Contenedor de carga | 2.4 × 6 × 2.6 m |
| Alto de nave industrial | 6 m |
| Alto de oficina y muro perimetral | 3 m |
| Tamaño del mapa terminado | 250 × 250 m |

La escala en metros no es cosmética: hace que las físicas de Godot (gravedad, masas,
fricción) den valores realistas sin tener que compensar, y es la referencia contra la que
se ajusta la escala de los assets al importarlos.

Notas de implementación, para la v0.1:

- **1.8 m es la altura del cuerpo**, no la de la cámara. En primera persona la cámara va a
  la altura de los ojos, un poco más abajo: quedó fijada en **1.65 m**. Si se pone a 1.8
  se siente como flotar.
- **El radio de 0.4 m** es el ancho de una persona. Define por dónde pasás: un pasillo de
  menos de 0.8 m no se puede cruzar, y es el número contra el que hay que dimensionar
  puertas e interiores cuando se greyboxee el complejo.
- **250 × 250 m** es el mapa terminado, no el de v0.1 (ver `docs/plan.md` →
  "Progresión del mapa"). A 4 m/s cruzarlo de punta a punta lleva poco más de un minuto:
  vacío sería chiquísimo, pero con loot, interiores y zombies alcanza para la sesión de
  30-60 minutos. Si al jugarlo se siente corto, el arreglo es más densidad, no más metros.
- Referencias del mundo real, para tunear contra algo: una persona camina a ~1.4 m/s,
  trota a ~3 m/s y esprinta a ~8 m/s. O sea que estos valores de arranque son más rápidos
  que la vida real, que es lo normal en juegos porque la velocidad realista se siente
  lentísima. Si el juego tiene que sentirse pesado y torpe, es de acá de donde hay que
  bajar.

### Control en el aire: 0.25

Valor de arranque, salido del primer playtest del controller.

Es cuánto podés corregir la dirección mientras estás en el aire, medido como **fracción de
tu velocidad por segundo**. En **0.0** la trayectoria del salto queda fija desde que
despegás y no la podés tocar. En **1.0** podés cambiar la velocidad entera en un segundo,
que para un salto de ~0.9 s es prácticamente control total: así estaba antes del playtest
y se sentía a volar.

En 0.25, caminando a 4 m/s, podés corregir como mucho ~0.9 m/s en todo el salto. Alcanza
para acomodar un aterrizaje, no para cambiar de idea a mitad de camino.

**Por qué bajo:** en un survival el salto sirve para pasar un obstáculo, no para pelear ni
esquivar. Poco control en el aire obliga a decidir **antes** de saltar, y eso es lo que
hace que el movimiento se sienta con peso. Los shooters de movimiento rápido hacen lo
contrario a propósito, y no es el juego que estamos haciendo.

Es la primera decisión de game feel del proyecto que salió de jugarlo y no de razonarlo.

### Velocidad del zombie: 3.7 m/s

Segunda decisión de game feel salida de jugarlo. Del playtest del zombie de v0.2, el
2026-08-05.

Arrancó en **2.5 m/s** —elegido como "bien por debajo del jugador"— y se sentía
inofensivo: caminando te ibas sin apurarte, así que el zombie no era una amenaza sino un
obstáculo que se movía despacio.

**4.0 m/s es un techo duro, no un número al que acercarse más.** Es la velocidad de
caminata del jugador, y el enemigo está diseñado sobre la premisa de que **un solo zombie
nunca alcanza a alguien que se mueve**: lo que lo hace peligroso es que te acorrale, que
sean varios, o que estés ocupado en otra cosa. Si iguala o pasa los 4.0, esa premisa se
cae y el zombie pasa a ser otro enemigo — uno que te caza solo, sin necesitar ni grupo ni
terreno a favor.

A 3.7 el margen caminando es de **0.3 m/s**, y eso es lo que hay que tener en cuenta al
tunear lo que venga: alcanza para escaparse en línea recta y en campo abierto, pero
cualquier esquina, obstáculo o roce contra una pared se lo come. Correr (7 m/s) sigue
siendo la salida clara, y es la que se va a estrechar sola cuando en v0.4 entre la
stamina.

## Los primeros 10 items

Bate, pistola 9mm, munición 9mm, botella de agua, lata de comida, barra de cereal,
vendas, linterna, mochila, palanca.

Un solo melee y una sola arma de fuego, consistente con v0.5. **Escopeta y fusil quedan
fuera de la v1:** con tres armas de fuego en diez items, el combate deja de ser escaso y
el juego se vuelve un shooter.

### Qué mecánica necesita cada item, y cuándo

Un item no sirve para nada hasta que existe el sistema que lo usa. Esta tabla es para no
confundir "el item está en el juego" con "el item hace algo":

| Item | Mecánica que lo hace servir | Cuándo sirve |
|---|---|---|
| Mochila | Slot de equipo: 25 kg → 40 kg | v0.3 |
| Botella de agua | Consumible de sed | v0.4 |
| Lata de comida | Consumible de hambre | v0.4 |
| Barra de cereal | Consumible de hambre | v0.4 |
| Bate | Combate melee | v0.5 |
| Pistola 9mm | Arma de fuego | v0.5 |
| Munición 9mm | Recarga de la pistola | v0.5 |
| Linterna | Luz, y oscuridad que la justifique | v0.5, con el ciclo día/noche |
| Vendas | Curar vida | **no registrado** |
| Palanca | Abrir algo trabado | **no registrado** |

**En v0.3 vendas, linterna y palanca son items inertes, y está bien que lo sean.** Los
diez entran al juego en v0.3: se lootean, pesan, ocupan lugar y se pueden tirar. De los
diez, solo la mochila hace algo. **Es a propósito:** v0.3 prueba el inventario
—serialización de red, peso, pickup, drop, contenedores—, y para eso un item inerte sirve
igual que uno que cura. Meter las mecánicas en el mismo milestone que el inventario es
poner dos sistemas nuevos abajo del mismo bug.

Los dos **no registrado** son huecos reales, no olvidos de redacción:

- **Vendas:** falta decidir si la vida se regenera sola o solo con items. Hasta que eso
  esté, no hay dónde enchufarlas.
- **Palanca:** hoy no hay puertas ni contenedores trabados en el plan. La palanca supone
  una mecánica de acceso bloqueado que todavía no existe.

Ninguno de los dos bloquea nada: se pueden decidir cuando lleguen.

## Huecos por completar

- [ ] **Inventario: ¿`expressobits/inventory-system` o escribirlo nosotros? — se responde
      en v0.3, no ahora.** La pregunta que lo decide es verificable, no de opinión:
      **¿el addon replica el inventario en red por sí solo, o igual hay que serializar a
      `PackedByteArray` a mano?** (ver `docs/netcode.md` → "Advertencia para v0.3"). Si la
      respuesta es que hay que serializar igual, el addon ahorra mucho menos de lo que
      dice `docs/plan.md`.

      Contra el addon juega el precedente de ADR-0005, que rechazó otro addon de la misma
      gente para no tratar como caja negra lo central del juego. **Acá ese argumento pesa
      menos:** la serialización de red es tediosa, no pedagógica — escribirla a mano no
      enseña Godot, que era el motivo de escribir el character controller.

## Milestones

Cada uno tiene que ser jugable de punta a punta antes de pasar al siguiente.

| | Qué tiene que funcionar |
|---|---|
| **v0.1** | Dos cápsulas sincronizadas moviéndose en una caja. Host + 1 cliente por IP en LAN. Nada más. |
| **v0.2** | Un zombie que persigue por NavMesh y pega. Vida del jugador, muerte, respawn. |
| **v0.3** | Inventario replicado, ~10 items, contenedores registrables, pickup y drop. |
| **v0.4** | Hambre y sed drenando, consumibles, muerte por inanición, stamina al correr. |
| **v0.5** | Melee + arma de fuego con munición escasa. Spawn de zombies. Día/noche. Guardado. |
| **v0.6 "Se ve"** | Pasada de arte sobre el greybox: familia visual, iluminación, post-processing, SFX. |
| **v1.0 "Se juega con amigos"** | Conexión sin port forwarding, lobby, menús, nombre definitivo, balance final. |

**v0.1 es el filtro.** Si en dos semanas eso no está andando limpio, falta base:
conviene hacer un juego más chico primero antes de volver a este.

## Reparto de trabajo

Los dos trabajamos en todo el proyecto. No hay carpetas con dueño fijo, incluido
`project.godot`.

La regla que lo reemplaza:

- Avisarse antes de empezar a trabajar, y decir sobre qué archivos o carpetas.
- Nunca dos personas sobre el mismo archivo al mismo tiempo.
- `git pull` antes de arrancar, siempre.

Última revisión: 2/8/2026
