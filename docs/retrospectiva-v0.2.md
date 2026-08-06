# Retrospectiva de v0.1 y v0.2

**Fecha:** 2026-08-05. Escrita antes de arrancar v0.3, sobre 37 commits, 8 scripts
(≈1.200 líneas de GDScript), 5 escenas y 7 ADRs.

Este documento no es un informe para leer una vez. Es material de referencia para v0.3:
las secciones 3 y 5 hay que volver a abrirlas cuando se planifique cada paso del
milestone, y la lista de deuda de verificación de §3 es la que hay que mirar cuando
aparezca un bug raro.

**Cómo leer las afirmaciones técnicas de acá adentro.** Cada una está marcada:
**verificado** (se corrió o se leyó el archivo), **inferido** (se dedujo de código que sí
se leyó, sin correrlo) o **suposición** (hay que chequearlo). Es la misma distinción que
pide `.claude/rules/limites.md` y en esta retrospectiva importa más que nunca, porque
buena parte de §1.B es análisis estático de código que nadie ejecutó.

---

## 1. Autoanálisis de Claude Code

### 1.A. Errores que se detectaron después

Ocho, en orden cronológico. Para cada uno: qué falló, por qué no se vio antes, y si el
proceso debería haberlo agarrado.

---

**A1. `netcode.md` describía el chequeo de respawn midiendo distancia en 3D, y no habría
funcionado.**

Escrito en `136e1c8` (planificación de v0.2, 2/8) como
`snapped.distance_to(wanted_point)`. Al implementarlo en `9f94fb1` (5/8) apareció que el
NavMesh horneado queda 0.3 m por encima del piso, así que esa distancia **nunca baja de
0.3 m** ni parado en medio del patio: con `MAX_RESPAWN_SNAP` chico, el respaldo habría
disparado siempre y todo el mundo habría respawneado en el círculo de spawn. Corregido a
distancia horizontal.

*Por qué no se vio:* el chequeo se escribió razonando sobre una geometría idealizada
—"el punto snapeado está sobre el piso"— sin abrir el `.tres` horneado, que estaba en el
repo desde `10baa7c` con los vértices en `y = 0.3` a la vista de cualquiera.

*¿El proceso debería haberlo agarrado?* **Sí, y es el caso más instructivo del proyecto.**
`netcode.md` dice, con orgullo justificado, "verificado por MCP contra el editor 4.7.1"
sobre las **firmas** de `map_get_closest_point`, `get_navigation_map`,
`map_get_random_point` y `map_force_update`. Las cuatro firmas eran correctas. Lo que
nadie verificó fue el **dato** que el código iba a comparar contra esas firmas. Verificar
que una función existe no es verificar el valor con el que se la usa. Eso hoy no está
escrito en ninguna regla.

---

**A2. Declarar el RPC de respawn en `player.gd` con `@rpc("authority")`.**

Corregido antes de commitear, gracias a consultar `MultiplayerApi.RPCMode` por Context7.
`"authority"` significa "solo la autoridad de **este nodo**", y la autoridad de
`player.gd` es el cliente dueño: el host habría quedado afuera y la RPC no se habría
podido llamar nunca.

*Por qué casi pasa:* el flag se llama igual que el concepto equivocado. Es exactamente el
tipo de error que `limites.md` describe.

*¿El proceso lo agarró?* **Sí.** Es el ejemplo de que la regla de "verificá antes de
escribir" funciona cuando se aplica. Quedó registrado como `Rejected:` en `9f94fb1` y
generó el tercer patrón de red.

---

**A3. `REVIVE_DURATION` arrancó en 3 segundos y se sentía inservible.**

Detectado jugándolo. Subió a 10 s, un factor de 3,3×. A 3 segundos, mantener la tecla no
llegaba a poner en riesgo al que levanta, que es el punto entero de que sea mantener.

*Por qué no se vio antes:* porque no se puede ver antes. Es game feel.

*¿El proceso debería haberlo agarrado?* **El proceso lo agarró — pero tarde y por el lado
equivocado.** `limites.md` dice que el balance no es mío. Lo elegí igual, escribí un
número y le escribí una justificación. Lo correcto habría sido entregar el sistema con el
número marcado como pendiente. Ver §1.E.

---

**A4. El zombie arrancó a 2,5 m/s y se sentía inofensivo.**

Mismo caso que A3, misma causa, mismo tamaño de error (2,5 → 3,7). El número se eligió
razonando ("bien por debajo del jugador"), y razonar sobre game feel es precisamente lo
que `docs/investigacion-claude-code.md` documenta que no funciona.

---

**A5. El timer de 60 s del caído seguía bajando mientras alguien te levantaba.**

Detectado en el playtest. Se podía morir a mitad de un revivir que iba a completarse,
o sea que tardar en llegar castigaba al que salva incluso cuando llegó a tiempo.

*Por qué no se vio:* es un bug de **interacción entre dos sistemas que escribí yo mismo
en el mismo commit**. El timer y el revivir se escribieron con veinte minutos de
diferencia y ninguno de los dos preguntó qué hacía el otro. No es un error de código —las
dos partes hacen lo que dicen— es un error de diseño de sistemas.

*¿El proceso debería haberlo agarrado?* Sí, y la contramedida es de orden, no de regla:
un playtest entre el paso 6b y el 6c lo habría mostrado antes de que hubiera cuatro
commits encima. Ver §5.6.

---

**A6. Sacar al caído de la lista de objetivos no alcanzaba: el zombie seguía trabándose
contra el cuerpo.**

`006029c`. La primera versión hizo que el zombie **ignorara** al caído como objetivo, lo
cual resolvió que cambiara de presa pero no que pudiera pasar: seguía empujando contra la
cápsula.

*Por qué no se vio:* asumí que cambiar la **intención** del agente resolvía un problema
que era de **física**. Es un patrón, no un evento: ver §1.D.3.

---

**A7. El `cell_height` del mapa de navegación quedó desalineado con el del NavMesh.**

`9f0d06d`. El NavMesh se horneó con `cell_height = 0.2` y el mapa global quedó en el
default de 0.25. Godot avisaba con un warning en la salida de la herramienta.

*Por qué no se vio:* **el warning estaba impreso y nadie lo leyó**, durante dos commits.
La entrada de la bitácora lo dice mejor de lo que lo diría yo: "una herramienta que
siempre imprime warnings enseña a no leerlos". El script `bake_navmesh.gd` tira siempre
un warning esperado de parseo de mallas CSG, y ese ruido tapó el warning real.

*¿El proceso debería haberlo agarrado?* Sí. `docs/proceso.md` §3 dice "¿el error está en
el panel Debugger? Empezar por ahí" — pero eso aplica a errores, no a warnings en la
salida de una herramienta de línea de comandos, que no tienen procedimiento.

---

**A8. `netcode.md` afirmaba que v0.1 no tenía ningún RPC, y era falso.**

Descubierto implementándolo. El razonamiento original —v0.1 no tiene estado del host que
pedir— era correcto para el **gameplay** y ciego a la carrera del spawn:
`change_scene_to_file()` se difiere al final del frame, y en LAN el RTT es de menos de
1 ms contra un frame de 16 ms.

*Por qué no se vio:* razoné sobre qué datos hacen falta y no sobre qué existe en cada
máquina en cada instante. Es la misma clase de error que A1: pensar en la lógica y no en
el estado real del sistema.

*Salió bien lo que vino después:* el doc no se corrigió en silencio. Dice explícitamente
"*(Corregido al implementarlo. Este doc decía que v0.1 no tenía ninguno, y era falso.)*".
Ver §1.C.2.

---

### 1.B. Errores que nadie detectó todavía

Buscados a propósito, releyendo los ocho scripts línea por línea y cruzándolos con los
veinte trailers `Not-tested:`. Ordenados por cuánto importan, no por gravedad técnica.

---

**B1. El respaldo de `MAX_RESPAWN_SNAP` es inalcanzable en el mapa actual, así que la
rama nunca se ejerció de verdad.** *(Inferido de la geometría de `yard.tscn` y de
`jump_velocity`.)*

El trailer de `9f94fb1` ya dice que "la rama del respaldo solo se probó forzando el
umbral". Lo que el trailer no dice es **por qué**: en `yard.tscn` no existe ningún punto
donde un jugador pueda estar a más de 3 m horizontales del NavMesh. El patio está cerrado
por el muro perimetral, el NavMesh cubre el piso entero, y con `jump_velocity = 4.5`
(1,03 m de salto) no se sube a un contenedor de 2,6 m. **Es código muerto en v0.2**, y va
a estrenarse recién cuando exista un segundo piso, una escalera o una rampa —
probablemente en v0.5, con el greybox creciendo.

Y cuando se estrene, se va a estrenar con el bug de B7 adentro.

---

**B2. Ninguna de las cuatro validaciones de rechazo se ejerció contra el caso que puede
pasar de verdad.** *(Verificado en el código; el trailer de `dcfb671` lo dice a medias.)*

`request_damage` rechaza por inexistencia del target y por autoría. Las dos se probaron
con F2 mandando mentiras a propósito, que es un cliente **hostil**. El caso realista —un
peer que se desconecta **entre** que manda el pedido y que el host llega a procesarlo—
nunca se ejerció. Lo mismo con `request_revive_start`, que además valida distancia y
estado, y con `respawn_at`, cuyo guard de `player == null` nunca se ejecutó.

Estas validaciones son el molde que v0.5 va a copiar para el combate. Están probadas
contra el atacante que no existe y sin probar contra el usuario normal.

---

**B3. Nada limita la frecuencia de pedidos.** *(Verificado. Ya está en el trailer de
`dcfb671` y no se movió a ningún lado donde se vuelva a ver.)*

Un cliente puede mandar `request_damage` o `request_revive_start` sesenta veces por
segundo. Hoy no importa porque el daño es un andamio de debug. En v0.5, cuando
`request_attack` sea el camino real del combate, el molde ya va a estar copiado tres
veces.

---

**B4. Un pedido rechazado imprime en la consola del host, y el que lo provoca es el
cliente.** *(Verificado leyendo `world.gd:133` + `player.gd:215-226`.)*

`_update_revive_input()` no filtra por distancia **a propósito** —la razón está escrita y
es buena: dos fuentes de verdad para el rango se desincronizan—. La consecuencia no está
escrita: cualquier E apretada en cualquier parte del mapa, mientras haya alguien caído,
manda un pedido legítimo que el host rechaza e imprime. En un playtest de dos personas,
con alguien nervioso apretando E mientras corre, la consola del host se llena de
`[world] revivir rechazado`. Que es exactamente donde se van a buscar los errores de
verdad.

No es un bug de red: es un problema de instrumentación, y de los que arruinan un
playtest.

---

**B5. El borde "solté la tecla" se puede perder, y el sistema aguanta por una propiedad
que no está escrita como invariante.** *(Verificado.)*

`_update_revive_input()` se llama solo en la rama de "no estás caído" de
`_physics_process`. Si te caés mientras estás levantando a alguien, el `just_released`
nunca se manda. El host lo cubre igual, porque `_tick_revive` revalida entero cada frame
y `_can_revive` ve que el que levanta está caído.

**Hoy no hay bug.** Lo que hay es una dependencia no declarada: el diseño funciona porque
la revalidación continua del host cubre **también los bordes que el cliente nunca manda**,
y eso no está escrito. `netcode.md` dice que revalidar cubre "alejarse, que al que levanta
lo tiren y que se desconecte" — tres casos. El cuarto es el importante y falta. Si mañana
alguien agrega a `_can_revive` una condición que no se pueda evaluar sin el cliente, un
borde perdido se convierte en un revivir colgado.

Efecto secundario menor de la misma estructura: si te levantan mientras seguís apretando
E, no podés retomar hasta soltar y volver a apretar, porque el arranque es
`is_action_just_pressed`. Va a aparecer como "a veces no levanta".

---

**B6. Que el reloj del caído se congele depende del orden de `_process` en el árbol, y eso
no está declarado en ninguna parte ejecutable.** *(Verificado: no hay ni un
`process_priority` en todo el repo.)*

`world.gd::_process()` tiene que correr **antes** que `player_stats.gd::_process()` para
que `reviver_id` ya esté en 0 cuando el timer mira. Hoy sale gratis porque `World` es
abuelo de `Stats` y Godot procesa de padre a hijo. El comentario de `player_stats.gd:90-93`
lo explica bien.

Pero explicar no es hacer cumplir — es el mismo argumento que `docs/proceso.md` §2 hace
sobre ADRs contra rules. Alcanza con que alguien le ponga `process_priority` a cualquiera
de los dos nodos, o que el tick de revivir se mueva a otro lado, para que el reloj
descuente un frame de más sin que nada avise. Godot tiene `process_priority` justamente
para declarar esto y no se usó en ningún lado del proyecto.

---

**B7. `_spawn_position()` usa la cantidad de jugadores como índice, y eso deja de repartir
en cuanto haya respawns.** *(Verificado en `world.gd:242` y `world.gd:304`.)*

Al spawnear está bien: se llama antes del `add_child()`, así que el primer jugador saca
índice 0 y el segundo 1. Al respawnear por el respaldo se llama con
`_players.get_child_count()` ya completo, o sea que **con dos jugadores conectados los dos
respaldos devuelven el mismo punto** (índice 2 → 180°). Dos personas que mueran fuera del
NavMesh en la misma partida aparecen una encima de la otra.

Hoy es inalcanzable por B1. Deja de serlo el día que el greybox tenga altura.

---

**B8. La condición de ataque del zombie está acoplada a los radios de las cápsulas, con
0,2 m de margen, y nadie lo escribió.** *(Inferido de `zombie.tscn:53`, `player.tscn:7` y
`zombie.gd:135`.)*

El zombie muerde solo si `_agent.is_navigation_finished()`, que es "estoy a menos de
`target_desired_distance` del destino". En `zombie.tscn` ese valor es **1,0 m**. Las dos
cápsulas tienen radio 0,4, así que se bloquean físicamente a **0,8 m**. Funciona con 0,2 m
de margen.

Si alguien sube el radio del jugador a 0,5 —o el del zombie, o mete un modelo con una
cápsula distinta en v0.6— `is_navigation_finished()` deja de dar `true` al llegar y **el
zombie nunca muerde**, sin un solo error en pantalla. Es el peor tipo de bug de este
proyecto: un número de una escena que rompe otra escena en silencio, con el síntoma
("los zombies no hacen daño") a tres saltos de la causa.

Hoy no está roto. Está a 0,2 m de estarlo, y no hay ningún comentario en ninguna de las
dos escenas que lo diga.

---

**B9. `_target` del zombie puede quedar apuntando a un nodo liberado durante hasta 12
frames de física, y el guard que lo cubre se apoya en una suposición que no verificamos.**
*(Suposición — hay que chequearla.)*

El zombie repathea cada `repath_interval = 0,2 s`. Si un peer se desconecta,
`world.gd::_on_peer_disconnected` hace `queue_free()` y el jugador desaparece, pero
`_target` sigue apuntando ahí hasta el próximo `_retarget()`. El código chequea
`if _target == null`.

En Godot 4 **se supone** que comparar una instancia liberada contra `null` devuelve
`true` —cambió respecto de Godot 3, donde devolvía `false`— y si eso es cierto no hay bug.
**No lo verificamos en 4.7.1 y la documentación que consultamos no lo dice
explícitamente.** Si la suposición es falsa, el host tira `previously freed instance`
durante doce frames seguidos cada vez que alguien se desconecta mientras el zombie lo
persigue.

Es de una línea comprobarlo y de una línea blindarlo (`is_instance_valid()`). Va acá y no
en la lista de bugs porque no está confirmado que sea uno — pero es el ítem número uno de
la deuda de verificación.

---

**B10. `request_damage` va a quedar sin ningún llamador.** *(Verificado.)*

Es el molde del patrón 2 y el único que lo llama es `debug_overlay.gd`, cuyo propio
docstring instruye borrarlo entero cuando entre el HUD de verdad. Si eso pasa en v0.3 o
v0.4, el molde se borra con el andamio, o queda como código muerto que nadie va a
distinguir de código vivo. En los dos casos, la función que `dcfb671` describe como "el
molde que van a copiar `request_revive` y el combate de v0.5" desaparece del proyecto
antes de que v0.5 llegue.

---

**B11. El zombie no tiene vida y no se puede matar, y ningún documento lo dice.**
*(Verificado: `zombie.gd` no tiene ni `health` ni `take_damage`.)*

`plan.md` §3 dice que v0.2 incluye "Ataque cuerpo a cuerpo", que se lee como el melee del
jugador. `design.md` pone el melee en v0.5 y describe v0.2 como "un zombie que persigue
por NavMesh y **pega**". La ambigüedad se resolvió al implementar, a favor de v0.5, y no
se registró en ningún lado.

**Hoy el zombie es invulnerable por omisión, no por decisión.** Es exactamente el hueco
que hay que cerrar antes del playtest de v0.2: si alguien juega esperando poder pelear,
va a reportar como bug algo que es scope.

---

**B12. `player_stats.gd` afirma algo que `design.md` ya contradice, y las dos frases
entraron en el mismo commit.** *(Verificado con `git log -S`.)*

`player_stats.gd:23-24` dice: "Valor de arranque sin decidir todavía: docs/design.md no
fija ningún número de vida". `design.md:159` dice "Vida con la que te levantan | 30 de
100" — o sea que fija 100. Los dos textos entraron en `9f94fb1`. **El comentario nació
desactualizado.**

Es chico y es sintomático: ver §1.D.4.

---

**B13. `project.godot` declara la escena inicial dos veces.** *(Verificado.)*

`[application] run/main_scene` (línea 14) y `[run] main_scene` (línea 94). Solo la primera
es el setting registrado de Godot; la segunda es una entrada que el motor conserva en el
archivo y nadie lee. No rompe nada. Va a confundir a quien busque de dónde sale la escena
de arranque, que es justo lo que uno busca cuando algo del arranque falla.

---

**B14. `revive` se bindeó por `keycode` y la regla no cubre el caso.** *(Verificado en
`project.godot:64-68`: `keycode: 69`, `physical_keycode: 0`.)*

`CLAUDE.md` parte los bindings en dos casillas: movimiento por `physical_keycode`, atajos
de UI por `keycode`. `revive` no es ninguna de las dos — es una acción de gameplay que se
aprieta con la mano izquierda mientras la derecha está en el mouse, o sea que el argumento
de la posición física aplica igual que a WASD.

En QWERTY, AZERTY y QWERTZ la E está en el mismo lugar, así que **hoy no cambia nada**.
Lo que importa no es la tecla: es que la regla tenía dos casillas, el caso no entraba en
ninguna, y elegí una sin decirlo. Ver §1.D.5.

---

### 1.C. Cosas que salieron bien y valdría la pena convertir en norma

**C1. Los trailers `Not-tested:`.** Están en 20 de 37 commits y son la única razón por la
que la sección B de arriba tiene de dónde agarrarse. Sin ellos, la mitad habría que
reconstruirla leyendo código a ciegas. **Es la mejor decisión de proceso del proyecto**,
y §5.4 propone lo único que le falta: un destino.

**C2. Corregir el documento al implementar, en el mismo commit, dejando escrito que estaba
mal.** `netcode.md` tiene hoy tres correcciones así, marcadas: el RPC de v0.1, la distancia
horizontal, y revivir en dos RPCs. No se corrigió en silencio: dice qué decía antes y por
qué no funcionaba. Eso es lo que evita que dentro de seis meses alguien vuelva a escribir
la versión 3D del chequeo. **Convertir en norma:** el orden doc → implementar → corregir
el doc **dejando la corrección visible**.

**C3. Verificar firmas de API contra el editor antes de escribirlas.**
`map_get_closest_point`, `get_navigation_map`, `create_server`/`create_client`,
`MultiplayerApi.RPCMode`. El modo de falla número uno del proyecto es alucinar una API de
Godot, y **en 37 commits no se alucinó ninguna**. Funciona. (Lo que falta es extenderlo a
los datos, no solo a las firmas: A1 y §1.D.2.)

**C4. Un smoke test headless descartable por pedazo.** El paso 6 entró en cuatro commits y
cada uno se verificó con un script headless que después se tiró. Es lo más parecido a
tests que tiene el proyecto y funcionó sin gdUnit4, en un proyecto donde gdUnit4 lleva
tres semanas sin poder instalarse. **Convertir en norma — y en skill:** §5.5.

**C5. Poner los números que hay que probar como `@export` y no como `const`.**
`downed_duration` es `@export` con una razón escrita: "para poder bajarlo desde el
Inspector mientras se prueba: esperar un minuto por intento hace que nadie repita el test".
Eso es pensar en quién va a probar, no en quién va a leer. **Convertir en norma:** todo
número cuya verificación cueste tiempo real va como `@export`.

**C6. Meter el estado que se destruye adentro del nodo que se destruye.** El timer del
caído vive en su propio `PlayerStats` y los revivires se recorren iterando hijos vivos, en
vez de guardarse en diccionarios de `world.gd`. Es la decisión que hace que "desconectarse
estando caído" funcione **sin escribir un caso especial**, y es el molde correcto para
v0.3 (contenedores, bolsas de muerte) y v0.5 (spawns de zombies).

**C7. Concentrar todas las reglas en una sola función del host.** `_can_revive()`. El
cliente no conoce ninguna condición: solo pide. Es lo que va a hacer que "revivir requiere
una venda" en v0.3 sea una línea adentro de esa función y cero líneas del lado del cliente.

**C8. Dividir un paso grande en commits chicos verificados uno por uno.** El paso 6 fueron
cuatro commits, cada uno con su smoke test antes de pasar al siguiente. Cuando después
apareció que el zombie se trababa contra el cuerpo del caído, el fix entró como
`006029c` sin tocar nada de lo anterior. Eso es `git bisect` funcionando por diseño, no
por suerte.

---

### 1.D. Patrones — tipos de error que se repitieron

**D1. Razono bien sobre estructura y mal sobre magnitudes.**

Todo lo que salió mal y se detectó jugando fue un **número**: 2,5 m/s, 3 s, control en el
aire en 1,0. Todo lo que salió bien fue **forma**: quién es autoridad de qué, dónde vive
el estado, qué patrón de red aplica, cómo se evita una referencia colgada.

La conclusión operativa no es "elegir mejor los números". Es **no elegirlos**: entregar el
sistema con el número marcado como pendiente y que salga del playtest. Contramedida
concreta en §5.2.

**D2. Verifico firmas, no valores.**

Tres veces se verificó por MCP o Context7 que una función existe con esa firma exacta.
Ninguna vez se verificó el **dato** con el que esa función se iba a usar. A1 es
exactamente eso: la firma de `map_get_closest_point` estaba bien y el chequeo escrito
encima era inútil, porque nadie miró que el NavMesh estaba a 0,3 m del piso. B8 es el
mismo patrón esperando a pasar: la lógica del ataque es correcta y depende de una
geometría que nadie relacionó con ella.

**D3. Resuelvo la intención y no la física.**

El caído: primero lo saqué de la lista de objetivos (intención) y el zombie siguió
empujando la cápsula (física). B8 es el mismo error latente: la condición de ataque es
lógica y su premisa es geométrica.

**D4. Escribo mucho comentario y mucha doc, y el mismo hecho queda en cinco lugares.**

La trampa de `@rpc("authority")` está escrita en `docs/netcode.md`, en
`.claude/rules/netcode.md`, en el comentario de `world.gd:159-162`, en el trailer
`Rejected:` de `9f94fb1` y en `docs/bitacora.md`. Cinco copias. Ninguna es incorrecta hoy;
el problema es el día que una cambie.

Medido: en `scripts/` hay **485 líneas de comentario contra 558 de código**.
`player_stats.gd` tiene 83 de comentario contra 37 de código — 2,2 a 1: el archivo es más
documento que programa. B12 ya muestra la consecuencia: un comentario que nació
contradiciendo al doc que él mismo cita.

No propongo comentar menos —los comentarios de este proyecto son buenos y explican el
porqué, que es para lo que sirven—. Propongo que **el comentario apunte al doc en vez de
repetirlo** cuando el hecho ya está escrito en un doc.

**D5. Cuando algo no entra en las categorías existentes, elijo una en silencio.**

El binding de `revive` (B14) y la resolución de "ataque cuerpo a cuerpo" (B11) son el
mismo movimiento: la regla tenía dos casillas, el caso no entraba en ninguna, y en vez de
preguntar metí el caso en la más parecida sin decir que lo estaba haciendo. `CLAUDE.md`
dice "si la duda es menor, asumí lo razonable y **decí explícitamente qué asumiste**". La
primera mitad se cumplió las dos veces; la segunda, ninguna.

---

### 1.E. Momentos donde asumí algo y lo presenté como decidido por ustedes

Buscado a propósito, porque es un modo de falla documentado. **Encontré tres categorías,
en orden de gravedad.**

---

#### E1. Números de gameplay que entraron a `docs/design.md` en el mismo commit que el código

Esto es lo más grave de toda la retrospectiva, porque `design.md` es el documento donde
ustedes registran las decisiones de diseño, y ahora tiene adentro decisiones que no
tomaron, escritas con el mismo formato y el mismo tono que las que sí.

**`REVIVE_HEALTH = 30.0`.** Verificado con `git log -S "30 de 100" -- docs/design.md`: la
línea "Vida con la que te levantan | 30 de 100" entró en `9f94fb1`, **el commit que la
implementó**. Y no entró sola: entró con un párrafo de justificación de diseño —
"levantarse débil hace que el segundo caído llegue rápido. Si te levantaran con la vida
llena, quedar caído no costaría más que tiempo". Inventé un número, le escribí el porqué,
y lo puse en la tabla de números base del juego, donde se lee exactamente igual que los
que decidieron ustedes. **Nunca lo jugaron para decidirlo.**

**`REVIVE_RANGE = 2.0`** ("Distancia para levantar a alguien | 2 m"). Mismo commit, misma
historia, sin el párrafo de justificación.

**`max_health = 100.0`** (`d4e01fa`). Ese sí quedó marcado en el código como "valor de
arranque sin decidir todavía". Lo que pasó después es peor: `design.md` lo consagró tres
commits más tarde al escribir "30 de **100**", sin que nadie lo decidiera en el medio.
Un número marcado como pendiente se volvió permanente por una frase escrita al pasar.

---

#### E2. Criterios de diseño de nivel, que es el área que los propios docs dicen que no es mía

Los tres criterios de `design.md` → "Ambientación" —"cada edificio tiene al menos dos
aberturas", "los callejones sin salida son salas, no edificios", "la cobertura sin paredes
vale tanto como las paredes"— entraron en `bbafbdc`, el commit del greybox, presentados
como "tres criterios de diseño **que salieron de armarlo**, y que valen para todo el mapa".
Salieron de armarlo yo. Están escritos en presente y en voz del proyecto, así que hoy se
leen como doctrina del equipo.

**Son buenos criterios y probablemente los firmarían igual. Eso no es lo mismo que
haberlos decidido.** Y `docs/investigacion-claude-code.md`, que lo escribieron ustedes,
dice: "Layout espacial y composición visual los hacemos nosotros".

Lo mismo con **el layout entero del patio de 60 × 60**. Acá la aprobación sí existe:
ustedes lo caminaron y el trailer de `bbafbdc` registra el playtest. Lo que no existió es
la decisión **previa** — la geometría se escribió y después se validó, que es el orden
inverso al que `plan.md` §5 recomienda (plan mode → cuestionar suposiciones →
implementar).

---

#### E3. Once números de gameplay que ni siquiera llegaron a `design.md`

Viven solo en el código, escritos como si fueran obvios:

| Constante | Valor | Dónde |
|---|---|---|
| `DAMAGE_PER_REQUEST` | 10.0 | `world.gd` |
| `MAX_RESPAWN_SNAP` | 3.0 | `world.gd` |
| `SPAWN_RADIUS` | 2.0 | `world.gd` |
| `attack_damage` | 10.0 | `zombie.gd` |
| `attack_cooldown` | 1.5 s | `zombie.gd` |
| `attack_range` | 1.5 m | `zombie.gd` |
| `repath_interval` | 0.2 s | `zombie.gd` |
| `jump_velocity` | 4.5 | `player.gd` |
| `mouse_sensitivity` | 0.002 | `player.gd` |
| `max_pitch_degrees` | 89.0 | `player.gd` |
| radio del `NavigationObstacle3D` | 0.8 m | `player.tscn` |

Algunos son inocuos (`max_pitch_degrees`, `repath_interval`). Uno no lo es en absoluto:
**`attack_damage = 10.0` contra `max_health = 100.0` con `attack_cooldown = 1.5` significa
que un zombie te tira al piso en diez mordidas, o sea ~13,5 segundos de contacto
continuo.** Esa es una decisión de balance central del juego —cuánto perdona el enemigo—
y no la tomó nadie: salió de que 10 es un número redondo.

`mouse_sensitivity` es el otro que duele: es literalmente "la sensación al caminar y
disparar", que `limites.md` nombra en la lista de lo que no es mío.

---

## 2. Lo que falló en el proceso

No en Claude Code ni en ustedes: en el sistema que armamos.

---

**2.1. La regla de commits se arregló en un lugar y quedó rota en dos. Y ahora la regla
manda a leer el documento que la contradice.** *(Verificado con grep.)*

`339e703` existe justamente para resolver una contradicción entre el título y el cuerpo de
`.claude/rules/commits.md`. Arregló la rule y no tocó nada más:

- `docs/proceso.md:104` sigue diciendo "**Claude Code no commitea solo.** Nunca."
- `docs/investigacion-claude-code.md:144` sigue diciendo "**Claude Code nunca commitea
  solo.**"
- Y `.claude/rules/commits.md` abre con: "El porqué de cada una está en `docs/proceso.md`
  §1 — **leerlo antes de escribir cualquier mensaje de commit**."

O sea que el commit que arregló la contradicción **la duplicó**. Es el ejemplo más limpio
de por qué la duplicación entre `docs/` y `.claude/rules/` cuesta (2.9).

---

**2.2. Los dos milestones "terminados" no cumplen su propio criterio de terminado, y la
regla que lo exige no tiene nada que la dispare.**

`bitacora.md` dice "v0.1 y v0.2 están escritas y falta jugarlas". El pendiente
"**Playtest de quince minutos sin código a la vista, por cada milestone**" sigue sin
tildar, dos milestones después de escribirse. `investigacion-claude-code.md` lo lista como
regla operativa 5. `limites.md` tiene una sección entera dedicada al riesgo que ese
playtest existe para cubrir.

No se incumplió por negligencia: se incumplió porque **es una línea en una lista de
pendientes de un documento de 714 líneas** y no hay ningún momento del flujo donde
alguien la tenga que mirar. La regla mejor argumentada del repo es la que menos se
cumplió.

---

**2.3. La mitad del loop de verificación nunca existió, y todo el proyecto está escrito
como si existiera.**

gdUnit4 no se instaló en toda la vida del proyecto — el AssetLib falla y la alternativa
(bajar el zip de GitHub) está anotada y nadie la probó. Consecuencias, todas verificadas:

- `CLAUDE.md:49-51` publica un comando de tests que no corre. **Un comando publicado que
  no funciona entrena a no confiar en la sección de comandos.**
- `plan.md` §5 tiene una nota de estado real, que está bien puesta.
- `.claude/rules/limites.md` tiene una sección entera —"Los tests en verde no significan
  que esté terminado"— **dedicada a un riesgo que no se puede materializar, porque no hay
  tests que puedan estar en verde.**

Esa última es la más rara del repo: la regla mejor escrita protege contra algo imposible,
mientras el riesgo real —que no hay ninguna verificación automática de nada, y que la
única red de seguridad son scripts descartables escritos a mano— no tiene ni una línea en
ningún lado.

---

**2.4. No hay un solo hook, y hay al menos dos candidatos que los propios docs señalan con
el dedo.**

`plan.md` §5 dice literalmente: *"si escribís 'siempre que X, hacé Y' en `CLAUDE.md`,
probablemente debería ser un hook"*.

- `CLAUDE.md` dice "**CORRERLO SIEMPRE** después de tocar la geometría de
  `scenes/main/yard.tscn`" sobre el horneado del NavMesh.
- `10baa7c` dejó `bake_navmesh.gd` saliendo con código 1 explícitamente "así que se puede
  colgar de un hook **cuando tengamos uno**".

Nunca se colgó. El día que alguien mueva una pared y se olvide, el síntoma va a ser un
zombie atravesando paredes — el bug que el propio commit describe como "no se parece en
nada a su causa". Lo mismo con `--import` después de agregar un `class_name`, que hoy es
una regla en prosa en la bitácora.

---

**2.5. `.claude/skills/` está vacío.**

`plan.md` §5 nombra tres candidatos concretos: "agregar un item nuevo", "agregar un tipo
de zombie", "correr el test de dos instancias". El tercero es **el procedimiento más
repetido de todo el proyecto** y sigue viviendo en la cabeza de quien lo corre. El cuarto
candidato, que el plan no previó porque todavía no existía, es el smoke test headless
descartable (§5.5).

---

**2.6. La política de ADRs se cumplió exactamente al revés de como está escrita, y desde
entonces se dejó de cumplir.**

`proceso.md` §2 dice: "la ADR se propone **antes** de implementar, no después". Seis de
las siete ADRs se escribieron de golpe en `4498eee` ("registrar las seis decisiones ya
tomadas"), reconstruidas desde la bitácora. Solo la 0007 se escribió antes de implementar.

Y desde entonces —todo v0.1 y todo v0.2, veinte commits de código— **no se escribió
ninguna ADR más**, aunque apareció al menos una decisión que la propia regla califica sin
discusión ("si dentro de dos meses alguien puede preguntar por qué está hecho así"):

> **El tercer patrón de red: la orden del host al dueño del cuerpo.** Vive en
> `docs/netcode.md`, en `.claude/rules/netcode.md` y en un trailer `Rejected:`. No está en
> `docs/decisions/`. En dos meses, *"¿por qué el respawn está en `world.gd` y no en
> `player.gd`?"* es exactamente la pregunta que va a aparecer.

---

**2.7. El checklist previo al commit tiene ocho ítems y ninguno se puede auditar.**

`proceso.md` §4. El primero es "El juego arranca y la cosa nueva funciona". No hay forma
de saber si se hizo, ni siquiera para ustedes sobre ustedes mismos. Es una lista honesta y
completamente invisible, que es la definición de una regla que se va a erosionar sin que
nadie note el momento.

---

**2.8. `CLAUDE.md` volvió a pasar las 200 líneas en menos de una semana.** Está en 213. El
2/8 se movieron tres secciones a `limites.md` explícitamente "para no pasar las 200". No es
grave por sí solo; es el indicador de que el archivo tiene una intención de tamaño y
ningún mecanismo de contención.

---

**2.9. Fricción que no aportó: la duplicación literal entre `docs/` y `.claude/rules/`.**

`docs/netcode.md` (592 líneas) y `.claude/rules/netcode.md` (119) dicen lo mismo dos
veces, con las mismas tablas y los mismos tres patrones. `docs/proceso.md` §1 y
`.claude/rules/commits.md`, ídem.

La separación tiene un fundamento explicado y correcto —"las ADRs explican; las rules
restringen"— pero la implementación no lo respeta: **la rule no restringe, reexplica.** El
resultado es dos copias del mismo texto, que se desincronizaron a la primera oportunidad
(2.1). El beneficio real que se busca —que la restricción se cargue sola por path scope—
se logra igual con una rule de treinta líneas que **apunte** al doc en vez de copiarlo.

---

**2.10. Nada obliga a cortar la sesión a los 40 minutos.**

Regla operativa 3 de `investigacion-claude-code.md`. El paso 6 de v0.2 fueron cuatro
commits de gameplay, un playtest, un fix con avoidance y dos commits de documentación,
todo el mismo día. Es exactamente el largo donde la investigación que ustedes mismos
recopilaron dice que se pierde el hilo de qué archivos ya se tocaron. Que haya salido bien
no valida la práctica: valida que el paso estaba bien partido en commits.

---

## 3. Estado real del proyecto

### 3.1. Qué está en cada estado

**Escrito y jugado en dos instancias (host + cliente):**

Esqueleto de red y lobby · character controller en primera persona · replicación del
cuerpo con autoridad deducida del nombre · handshake de spawn · greybox de 60 × 60 con
NavMesh horneado · nodo de stats con autoridad del host · RPC de daño con validación ·
zombie que persigue por NavMesh, muerde y rodea al caído · caído, revivir, muerte real y
respawn.

**Lo que falta no es ninguna pieza: es el playtest de v0.2 completo, de punta a punta.**
Cada pedazo se jugó por separado, en la sesión donde se escribió. El milestone entero
—quince minutos, sin código a la vista, con los dos huecos de diseño que sabemos que
tiene— nunca se jugó. Ese es el criterio de terminado que el proyecto se puso.

**Escrito y nunca ejercido de verdad:**

| Qué | Por qué importa |
|---|---|
| Tres o cuatro jugadores | `MAX_CLIENTS = 3`, `spawn_limit = 4` y `_spawn_position()` reparten en círculo para cuatro. Todo el proyecto corrió con dos, siempre |
| La rama de respaldo de `_respawn_point()` | B1. Inalcanzable en el mapa actual |
| El `spawn = true` de las stats para un peer que llega tarde | B/§3.2. Es el caso normal en cuanto haya un tercero |
| Latencia real | Todo fue 127.0.0.1 o LAN. Varias decisiones de `netcode.md` se apoyan en "en LAN el RTT es menor a 1 ms": es cierto, y es por eso que no están probadas donde importan |
| Dos zombies | `ZombieSpawner` tiene `spawn_limit = 16` y se instancia uno |
| Los caminos de error de `network_manager` | `create_server` / `create_client` fallando |
| Los caminos de error de `bake_navmesh.gd` | Las tres ramas de `return 1` |
| Las validaciones contra el caso realista | B2 |

### 3.2. Deuda de verificación

Esta es la lista que `docs/proceso.md` §3 dice que hay que mirar cuando aparece un bug
raro. Hasta hoy solo existía como `git log --grep="Not-tested"`; acá queda consolidada.

**Chequear antes de escribir v0.3:**

1. **B9 — ¿`instancia_liberada == null` da `true` en Godot 4.7.1?** Si no, el host tira
   errores doce frames seguidos cada vez que alguien se desconecta con el zombie
   persiguiéndolo. Cuesta una línea comprobarlo.
2. **El `spawn = true` de las stats.** Conectar un tercer peer con la vida del host ya
   bajada y ver si la recibe.
3. **Tres o cuatro jugadores, una vez.** Todo lo demás de la lista de arriba sale de acá.

**Chequear antes de v0.5:**

4. **B8 — el margen de 0,2 m entre `target_desired_distance` y los radios de las
   cápsulas.** Anotarlo en las dos escenas mientras tanto.
5. **B2 — un peer que se desconecta a mitad de un pedido.**
6. **El jugador inalcanzable.** `is_navigation_finished()` da `true` al llegar al punto
   más cercano alcanzable, así que el zombie mordería desde abajo de un techo. Anotado en
   el trailer de `366b90a` y nunca probado.

### 3.3. Deuda técnica, ordenada por cuándo va a doler

**En v0.3 (lo próximo):**

1. **Los tres huecos de diseño abiertos** (§3.5). El de revivir sin límite es el que anula
   el sistema entero.
2. **Los andamios de debug.** Si el HUD de v0.3 entra sin borrarlos, quedan para siempre
   (§3.4).
3. **B10 — `request_damage` se queda sin llamador** cuando se borre el overlay.
4. **B3 — nada limita la frecuencia de pedidos.** No molesta en v0.3; el molde se copia
   igual.
5. *(No es deuda, es trabajo previsto:* la serialización del inventario a
   `PackedByteArray` y la bolsa de muerte. Están bien presupuestadas en `netcode.md`. Se
   nombran acá porque son lo más caro del milestone y es fácil subestimarlas.*)*

**En v0.5:**

6. **B8** — el acoplamiento explota cuando cambie cualquiera de las dos escenas, que es
   justo lo que pasa en v0.5 y v0.6.
7. **B7** — `_spawn_position()` deja de repartir en cuanto haya respawns reales.
8. **Un solo zombie fijo.** `world.gd::_spawn_zombie()` es un placeholder honesto que lo
   dice; el sistema de spawn es v0.5.

**Cuando cambie algo del orden de ejecución:**

9. **B6** — la dependencia implícita de orden de `_process`.

**Permanente, sin fecha:**

10. **No hay tests.** Todo lo demás de esta lista se detectaría con tests.
11. **Los 17 `print()` de `scripts/`**, sin niveles ni filtro. Con cuatro jugadores y
    varios zombies la consola del host deja de ser legible — y B4 ya la ensucia hoy.

### 3.4. Andamios de debug que hay que sacar

Casi todos están identificados en el propio código, lo cual está muy bien. La lista
completa, para que exista en un solo lugar:

| Qué | Dónde | Cuándo |
|---|---|---|
| `scripts/ui/debug_overlay.gd` entero | script | Cuando entre el HUD (v0.3 o v0.4) |
| Nodos `DebugOverlay` y `StatsLabel` | `scenes/main/world.tscn` | Con lo de arriba |
| Acciones `debug_hurt` (F1) y `debug_hurt_invalid` (F2) | `project.godot` | Con lo de arriba |
| `ScaleReferenceBox` | `scenes/main/world.tscn` | v0.6, ya anotado en `plan.md` §3 |
| **`debug_enabled = true` del `NavigationAgent3D`** | `scenes/enemies/zombie.tscn:55` | **No está anotado en ningún lado.** Dibuja el camino del agente en pantalla |
| Los 17 `print()` | `scripts/` | Cuando haya un logger, o nunca |

El único que no está registrado en ningún documento ni comentario es el `debug_enabled`
del agente de navegación.

### 3.5. Inconsistencias entre docs y código

| # | Inconsistencia | Dónde |
|---|---|---|
| 1 | La regla de commits dice una cosa en la rule y la contraria en dos docs | `proceso.md:104`, `investigacion-claude-code.md:144` vs `.claude/rules/commits.md` |
| 2 | Un comentario afirma que `design.md` no fija vida; `design.md` fija 100 | `player_stats.gd:23-24` vs `design.md:159` |
| 3 | "Ataque cuerpo a cuerpo" en v0.2 vs melee en v0.5; el zombie no tiene vida | `plan.md:107` vs `design.md` vs `zombie.gd` |
| 4 | Se publica un comando de tests que no corre | `CLAUDE.md:49-51` |
| 5 | `plan.md` §5 lista tres MCP candidatos que ADR-0006 ya descartó por no haberse evaluado nunca; el plan no lo dice | `plan.md:257` |
| 6 | ENet dura "hasta v0.5" en la ADR y "hasta v0.6" en los otros dos docs | ADR-0004 vs `plan.md:81` vs `netcode.md:346`. *Ya explicado en la bitácora —las ADRs son inmutables— pero un lector nuevo tropieza igual* |
| 7 | La escena inicial está declarada dos veces | `project.godot:14` y `:94` |

### 3.6. Huecos de diseño abiertos, con qué bloquea cada uno

| Hueco | Anotado en | Bloquea |
|---|---|---|
| Inventario: ¿addon de expressobits o propio? | `design.md`, `bitacora.md` | **v0.3.** Es lo primero que hay que responder: define el presupuesto del milestone |
| **Revivir no tiene límite de usos** | `design.md` | **v0.3.** Sin esto nadie muere nunca y todo v0.2 es decorativo |
| Dos jugadores levantando al mismo caído | `design.md` | **v0.3**, junto con el número de los 10 s |
| Un cuerpo caído tapa una puerta entera | `design.md` | **v0.3** parcial; solución definitiva atada a **v0.6** (pose tirado) |
| Vendas: ¿la vida se regenera sola? | `design.md` | Bloquea que las vendas hagan algo. Item inerte hasta entonces |
| Palanca: ¿qué abre? | `design.md` | Bloquea que la palanca haga algo |
| Save: ¿sobreviven los items del piso? | `netcode.md` | **v0.5**, pero impone ID persistente en **v0.3** |
| Save: ¿persisten inventario y stats de los jugadores? | `netcode.md` | **v0.5** |
| Save: ¿entran los zombies? | `netcode.md` | **v0.5** |
| Nombre definitivo | `design.md` | v1.0 |

**Y tres que descubrí escribiendo esto y no están anotados en ningún lado:**

| Hueco | Bloquea |
|---|---|
| **¿El zombie se puede matar en v0.2?** Hoy no, por omisión, no por decisión (B11) | El playtest de v0.2 |
| **Cuánto daño hace un zombie.** Diez mordidas / ~13,5 s de contacto, número inventado (§1.E3) | El playtest de v0.2 |
| **Con cuánta vida te levantan.** Está en `design.md` como si estuviera decidido (§1.E1) | v0.3, cuando el item médico decida el número |

---

## 4. Lo que aprendimos y no está escrito en ningún lado

La bitácora es buena y cubre casi todo. Esta sección es lo que **no** cubre: hallazgos que
hoy viven solo en trailers de commits, en comentarios sueltos, o en el contexto de una
conversación que ya se cerró.

### 4.1. Sobre Godot

**Los "problemas del editor abierto" de la bitácora son un solo fenómeno escrito tres
veces.** Hay tres entradas separadas: el autoload que no existe hasta reiniciar, el
`class_name` que no existe hasta reimportar, y el `.tscn` que el editor sirve desde
memoria. La regla general que las une —y que predice el próximo caso antes de que
pase— no está escrita en ningún lado:

> **Todo lo que en Godot sea una "tabla global" (autoloads, `class_name`, input map,
> project settings) se registra al arrancar el editor o al escanear el filesystem, no en
> caliente. El editor abierto es una copia en memoria, no una vista del disco.** Cuando
> algo esté escrito correcto en el archivo y el editor diga que no existe, es esto, y se
> distingue corriendo en proceso limpio.

**Prender una feature de un `NavigationAgent3D` cambia el contrato, no agrega un
comportamiento.** La bitácora registra bien el caso particular —con `avoidance_enabled`,
`velocity_computed` se emite todos los frames y `move_and_slide()` se muda al handler—.
Lo generalizable no está: no es que el agente "haga además avoidance", es que **el agente
deja de devolver la velocidad en el acto y pasa a devolverla por señal**. Es un cambio de
protocolo. Vale anotarlo porque los nodos de navegación de Godot tienen varios flags con
esa forma y v0.5 va a tocar más de uno.

**Cómo se verifica algo headless en este proyecto no está escrito en ninguna parte.** El
paso 6 se verificó con "smoke tests headless descartables". Nadie escribió qué es eso,
cómo se arma uno, dónde se pone, cómo se corre ni por qué se tira después. **Es el
procedimiento más usado del proyecto y no existe fuera de la conversación donde se hizo.**
Es el candidato número uno a skill (§5.5).

### 4.2. Sobre netcode

**El tercer patrón de red no tiene ADR.** Ya está en §2.6.

**La regla general que hace que `_can_revive()` funcione no está escrita como regla.** Lo
que está escrito es el caso: "el host revalida entero cada frame, y eso cubre alejarse,
que al que levanta lo tiren y que se desconecte". La regla es más ancha y más útil:

> **Cuando el host revalida la condición completa cada frame, el cliente no necesita
> mandar el borde de "terminé". Alcanza con que mande el de "empecé".** Todo lo que sea
> mantener una tecla se implementa así.

Sirve tal cual para v0.3 (mantener para abrir un contenedor, mantener para saquear una
bolsa) y v0.5 (recargar). Y hace explícito lo que B5 muestra que hoy es tácito.

**"El RPC manda a quién y qué, nunca cuánto" tampoco está como regla.** Está implementado
y comentado en `world.gd:15-17`: `DAMAGE_PER_REQUEST` vive en el host y no cruza la red,
"un valor de gameplay que no cruza la red no puede mentir". Es un principio general del
patrón 2 y merece estar en `.claude/rules/netcode.md`, no en un comentario de una función
que además está por quedarse sin llamadores (B10).

### 4.3. Sobre cómo trabajamos

**El playtest es la única fuente de números que funcionó, y ya hay muestra suficiente para
convertirlo en regla.** Tres decisiones de game feel en dos milestones: control en el aire
(1,0 → 0,25), velocidad del zombie (2,5 → 3,7), duración del revivir (3 → 10). **Las tres
salieron de jugarlo y ninguna del razonamiento previo.** Tres de tres. Hoy están escritas
en `design.md` como tres anécdotas separadas, cada una con su propio párrafo de "salió de
jugarlo". Es un patrón, no tres casualidades.

**Los smoke tests headless descartables funcionaron mejor de lo que la ausencia de gdUnit4
sugiere.** El proyecto lleva dos milestones sin framework de tests y la verificación real
fueron estos scripts. Nadie lo escribió como decisión: se sigue tratando "instalar
gdUnit4" como pendiente y los smoke tests como algo informal que pasó. **Vale plantear en
serio si la decisión correcta no es formalizar los smoke tests en vez de instalar
gdUnit4** — y si es que sí, escribirlo como ADR.

**El orden que funcionó tres veces y no está escrito como método:** escribir el doc →
implementar → **corregir el doc en el mismo commit, dejando visible qué decía antes**.
`netcode.md` tiene tres correcciones así y son las tres cosas mejor explicadas del
documento. No es "documentar después": es que el documento previo sirve como hipótesis y
la implementación es el experimento.

**Y una incógnita que conviene anotar como incógnita:** no sabemos si el playtest de
quince minutos sin código a la vista sirve, porque nunca se hizo. La regla se escribió
apoyada en un pipeline open source ajeno. La primera vez que se haga hay que evaluar
también la regla, no solo el juego.

---

## 5. Qué cambiaría para v0.3

Concreto y accionable, ordenado por cuánto cambia el resultado.

### 5.1. Antes de escribir una línea de v0.3

1. **Jugar v0.2 quince minutos, sin código a la vista, los dos.** Es la regla que se
   escribió dos veces y no se cumplió ninguna. Si no se hace ahora, v0.3 se construye
   encima de un milestone que nadie sabe si funciona. **Y evaluar también la regla**
   (§4.3).
2. **Cerrar tres huecos antes de ese playtest, no después:** si el zombie se puede matar
   (B11), cuánto daño hace (§1.E3) y el límite de revivires. Los tres cambian lo que se ve
   jugando; decidirlos después es jugar dos veces.
3. **Contestar la pregunta del inventario** —¿el addon replica solo o hay que serializar a
   `PackedByteArray` igual?— con la verificación que `design.md` ya dejó escrita. Es una
   tarde y decide el presupuesto del milestone entero.
4. **Un `chore(deps)` para el plugin de godot-ai**, que está modificado en el working tree
   ahora mismo (5 archivos + `vision_routing.gd` nuevo) por otra autoactualización. Va
   separado, como el anterior, para que un bisect que caiga ahí lo diga.

### 5.2. Cambios a `CLAUDE.md`

**Agregar — tres cosas, cortas:**

- **Una sección "Números de gameplay":** *ningún número que afecte cómo se juega se elige
  sin preguntar. Si hace falta uno para que el código corra, va con un comentario
  `# SIN DECIDIR` y **no entra a `docs/design.md`**.* Es la contramedida directa a §1.D1 y
  a los once números de §1.E3.

  Vale notar por qué la regla actual no alcanzó: `CLAUDE.md` → "Preguntá antes de asumir"
  da cuatro ejemplos de cosas que hay que preguntar, y **ninguno de los cuatro es un
  número** — son todos de arquitectura, que es justo lo que sí salió bien.

- **Una línea en "Qué no hacer": no tocar `docs/design.md` en el mismo commit que
  implementa.** Que la doc de diseño se mueva en un commit `docs:` aparte, después de que
  ustedes lo hayan visto. Es lo único que habría frenado el `REVIVE_HEALTH = 30`.

- **El comando de smoke test headless**, si se formaliza (§5.5).

**Sacar:**

- **El comando de tests de gdUnit4**, mientras no exista (§2.3).
- **La duplicación de la regla de autoridad.** Está entera en `CLAUDE.md`, en
  `.claude/rules/netcode.md` y en `docs/netcode.md`. En `CLAUDE.md` alcanza con el bloque
  citado de dos líneas y el puntero.

Con esas dos, `CLAUDE.md` vuelve a estar debajo de 200 líneas sin perder nada.

### 5.3. Cambios a las rules

- **Achicar `.claude/rules/netcode.md` a lo que restringe y borrar lo que explica.** Hoy
  tiene 119 líneas y repite las tablas de `docs/netcode.md`. Una rule que se lee entera en
  treinta segundos se lee; una de 119 líneas compite con el resto del contexto y pierde.
  El propio `proceso.md` define la división y la rule no la respeta (§2.9).
- **Agregar a la rule de netcode las dos reglas que faltan** y hoy viven en comentarios:
  *el RPC manda a quién y qué, nunca cuánto*, y *si el host revalida entero cada frame, el
  cliente solo manda el borde de "empecé"* (§4.2).
- **Agregar a `gdscript.md` un pitfall 11: dependencias implícitas de orden de ejecución.**
  Si el orden de dos `_process` importa, se declara con `process_priority`, no con un
  comentario (B6).
- **Agregar a `limites.md` una línea:** *verificar que una API existe no es verificar el
  dato con el que se la usa.* Es el patrón §1.D2 y es el error que más caro salió hasta
  ahora.

### 5.4. Cambios al proceso de commits

- **Arreglar la contradicción de §2.1.** Tres archivos, una frase.
- **Darle un destino a `Not-tested:`.** El trailer funciona muy bien para dejar registro y
  mal para que algo se haga: `git log --grep="Not-tested"` devuelve 20 commits y nadie lo
  corrió hasta que se escribió esta retrospectiva. Propuesta concreta: **la sección
  "Deuda de verificación" de §3.2 se muda a `docs/bitacora.md` como lista viva**, y al
  cerrar cada milestone se copian ahí los `Not-tested:` nuevos y se tachan los que se
  hayan verificado. El trailer no cambia; lo que cambia es que existe un lugar donde la
  lista se mira.
- **Escribir la ADR-0008 del tercer patrón de red.** Contexto y Alternativas las escriben
  ustedes, como manda la regla.

### 5.5. Herramientas: dos cosas que valen más que todo lo anterior

**1. Un hook que hornee el NavMesh cuando cambie `scenes/main/yard.tscn`.** Es el caso más
claro del repo: el script ya existe, ya devuelve código de salida, la regla ya está escrita
en prosa en `CLAUDE.md` con un "SIEMPRE" en mayúsculas, y el bug que previene es de los que
no se parecen a su causa. Son unas diez líneas de `settings.json` y elimina la única regla
del proyecto que depende de que alguien se acuerde.

**2. Formalizar el smoke test headless como skill**, en vez de seguir esperando a gdUnit4.
Es la técnica que verificó los dos milestones y no está escrita en ningún lado (§4.1). Un
skill con el procedimiento —dónde se escribe el script, cómo se corre, qué se mira, que se
borra después— convierte el procedimiento más usado del proyecto en algo repetible por
cualquiera de los tres, en vez de algo que se reinventa cada vez.

**Y una decisión que hay que tomar explícitamente:** o se instala gdUnit4 en v0.3, o se
decide que no se instala. Lleva tres semanas como pendiente abierto y mientras tanto
`plan.md`, `CLAUDE.md` y `limites.md` están escritos como si fuera a existir.

### 5.6. Qué haríamos distinto en v0.3, sabiendo lo que sabemos

- **Partir el milestone por costo de red, no por feature.** v0.3 tiene tres cosas de costo
  muy distinto: la serialización del inventario (cara, riesgosa, sin precedente en el
  proyecto), los contenedores (media) y la bolsa de muerte (cara, y con una dependencia
  en v0.5). **Empezar por la serialización con un prototipo tirable**, antes de escribir
  una línea de UI. Si esa parte no funciona, todo lo demás del milestone cambia de forma.

- **El playtest va entre pasos, no al final del milestone.** En v0.2 los cuatro commits
  del paso 6 se escribieron seguidos y el playtest reveló tres problemas de golpe, dos de
  los cuales eran **de interacción entre pedazos** (el reloj que no se congelaba, el cuerpo
  que trababa al zombie). Con un playtest entre el 6b y el 6c, el del reloj aparecía antes
  de tener dos commits encima.

- **Ningún número de balance en el mismo commit que el sistema.** §5.2.

- **Preguntar cuando el caso no entra en una casilla, aunque parezca menor.** §1.D5. Las
  dos veces que pasó, la respuesta correcta habría costado una pregunta de una línea.

- **Lo que NO cambiaría:** los trailers, el orden doc → implementar → corregir el doc,
  verificar las firmas de API contra el editor antes de escribirlas, los smoke tests
  headless descartables, y partir cada paso en commits chicos verificados uno por uno.
  Esas cinco son la razón por la que esta retrospectiva se pudo escribir con datos en vez
  de con impresiones.

---

## Apéndice: método

Qué se leyó para escribir esto, por si hay que repetirlo al cerrar v0.3.

- `CLAUDE.md`, `.claude/rules/` (4 archivos), `docs/` completo (6 documentos + 7 ADRs).
- Los 8 scripts de `scripts/` y `tools/`, línea por línea, más las 5 escenas `.tscn` y
  `project.godot`.
- `git log --format=full` completo (37 commits), incluidos los 20 trailers `Not-tested:`.
- `git log -S` sobre las constantes de gameplay, para fechar cuándo entró cada número y
  contra qué commit — que es de donde salió §1.E, la sección que no se podía escribir de
  memoria.

**Una advertencia sobre este documento, del mismo tipo que las que pide `limites.md`:**
lo escribió el mismo que cometió los errores que enumera. `docs/investigacion-claude-code.md`
dice que el sesgo de autoevaluación no se corrige leyendo el propio diff, y esto es
exactamente leer el propio diff. Las secciones 3 y 4 son las más confiables —son
inventario y son verificables—. La 1.E es la que más costó y la que más probablemente esté
incompleta: **si encuentran un número de gameplay que no está en esa lista y que nadie
decidió, es un fallo de esta retrospectiva, no una excepción.**
