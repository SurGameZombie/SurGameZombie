# Bitácora

Registro de qué se hizo, qué se decidió y por qué. Se actualiza cuando pasa algo que
alguien va a necesitar recordar en dos meses.

---

## Estado actual

**Setup terminado.** Los dos pueden clonar, editar, subir y bajar cambios.

**v0.1 está desbloqueada.** Las tres decisiones que faltaban para poder escribir el primer
código —modelo de autoridad, primera o tercera persona, idioma del código— están tomadas.
Cómo se resuelven v0.1 **y v0.2** —paso a paso, con las dependencias marcadas— está escrito
en `docs/netcode.md`.

**Pendiente antes de escribir código:** tutorial oficial 3D de Godot, los dos.
Los `[DECIDIR]` que quedan abiertos en `docs/design.md` no bloquean v0.1.

---

## Infraestructura

| | |
|---|---|
| Organización GitHub | `SurGameZombie` |
| Repositorio | `SurGameZombie` (privado) |
| Ruta local | `C:\Proyectos\SurGameZombie` en ambas máquinas |
| Mail del proyecto | Gmail dedicado, con verificación en dos pasos |
| Roles | Ambos Owner de la organización y con permiso de escritura en el repo |

Las cuentas personales de GitHub son de cada uno, con su mail personal. El Gmail del
proyecto es solo para la organización y para futuras cuentas (itch.io, Steam, sitios de
assets), nunca para las cuentas personales.

## Software instalado (ambas máquinas)

- Git for Windows, con `git config --global user.name` y `user.email` configurados
- **Godot 4.7.1-stable, versión standard** (no .NET) — misma versión exacta en las dos
- VS Code + extensión `godot-tools`, configurado como editor externo de Godot
- Blender

## Configuración del proyecto Godot

- Renderer: **Forward+**
- Lenguaje: **GDScript** con static typing obligatorio
- El `project.godot` está en la raíz del repo, no en una subcarpeta

---

## Decisiones tomadas

### Engine: Godot 4.7, no Unreal ni Unity

Tres razones, en orden de peso:

1. **Compatibilidad con Claude Code.** Godot serializa todo en texto (`.tscn`, `.tres`,
   `.gd`), así que un agente puede leer y editar el proyecto entero. Unreal guarda el
   contenido del editor en `.uasset` binario, ilegible para un agente. Unity es texto
   (YAML) pero lleno de GUIDs y frágil de editar a mano.
2. **Hardware.** La máquina de desarrollo tiene una RX 6500 XT de 4 GB de VRAM. Unreal 5
   pide 6 GB como mínimo realista y 8 recomendado. Queda descartado por hardware, no solo
   por preferencia.
3. **Precedentes directos del género.** *Road to Vostok* (survival FPS realista, Early
   Access en Steam desde abril 2026) y *Nevoa* (survival horror 3D multijugador, Expresso
   Bits) están hechos en Godot.

**Trade-off aceptado:** Godot 3D se ve peor out of the box, no tiene terrain system oficial
(hay que usar Terrain3D), y el ecosistema de tutoriales de survival 3D es más chico. El
último 20% de pulido visual lo ponemos nosotros.

### Lenguaje: GDScript, no C#

Es el lenguaje de primera clase de Godot, no tiene paso de compilación (loop de feedback
más corto, que es lo que hace productivo a Claude Code), y toda la documentación y los
addons están en GDScript.

**Static typing obligatorio.** GDScript es dinámico por default y eso rompe la detección
de errores. Sin tipos, ni el editor ni Claude Code agarran nada hasta runtime.

### Red: listen server con autoridad dividida

Un jugador hostea y juega en el mismo proceso. 2-4 jugadores.

**Revisado el 1/8/2026.** La regla original decía "el host es autoridad sobre *todo* el
estado". Resultó demasiado absoluta: aplicada al movimiento del propio jugador obliga a
implementar client-side prediction —el cliente simula, guarda cada input y lo reaplica
cuando llega la corrección del host—, porque si no, cada paso se ve con un round-trip de
retraso. Es de las cosas más difíciles del netcode y no es por donde arranca un primer
juego.

El modelo definitivo afloja **solo** el movimiento:

- El cuerpo del propio jugador es autoridad del peer dueño → `is_multiplayer_authority()`
- Todo el resto (vida, daño, inventario, hambre, sed, stamina, zombies, loot, mundo) es
  autoridad del host → `multiplayer.is_server()`

Se puede aflojar ahí y en ningún otro lado porque no hay PvP ni anti-cheat que defender:
confiarle al cliente su propia posición cuesta cero. Lo que **no** se afloja es la
consecuencia de esa posición: si el disparo impacta, si el zombie lo alcanza o si llega a
agarrar el item lo sigue decidiendo el host. Detalle completo y el porqué en
`docs/netcode.md`, que es la fuente de verdad.

Retrofitear autoridad después sigue siendo una reescritura, por eso el reparto va definido
desde el commit uno.

**Plan de transporte:** ENet por IP ahora → netfox.noray para v1.0 (sin port forwarding) →
SteamMultiplayerPeer si alguna vez va a Steam. La creación del peer vive solo en
`scripts/net/network_manager.gd` para que cambiar sea un cambio de diez líneas.

### Scope de la v1

- 3 stats (vida, hambre, sed) + stamina. Temperatura, heridas y enfermedad quedan para v2.
- Un solo tipo de zombie.
- Un melee y un arma de fuego con munición escasa.
- **Mapa cerrado y denso, no mundo abierto.** Un mundo grande y vacío es más caro en red y
  menos divertido que un pueblo chico bien hecho.

### Character controller: propio, no `expressobits/character-controller`

Lo escribimos nosotros. El addon nos ahorra una tarde a cambio de no entender lo más básico
del juego, y escribirlo a mano es la mejor forma de entender Godot: `CharacterBody3D`,
`_physics_process`, `move_and_slide()` y el manejo de input son la base de todo lo que
viene después.

Es una decisión de aprendizaje, no técnica. El addon seguramente sea mejor código que el
que escribamos la primera vez. Pero el riesgo declarado de este proyecto es perder contacto
con el propio código (ver "Riesgos identificados"), y el controller del jugador es
justamente el archivo que no nos podemos permitir tratar como caja negra.

### Input map: movimiento por `physical_keycode`, atajos de UI por `keycode`

`keycode` sigue el **layout** del teclado; `physical_keycode` sigue la **posición física**
de la tecla. En un AZERTY francés, un WASD bindeado por `keycode` cae en cuatro teclas
desparramadas; bindeado por posición física, el francés aprieta las mismas cuatro teclas
que nosotros aunque le impriman ZQSD.

La convención, en `CLAUDE.md` → "Reglas de código":

- **Movimiento → `physical_keycode`.** La mano va a una posición, no a una letra.
- **Atajos de UI → `keycode`.** Que la tecla que dice I sea la que abre el inventario.

Hoy no cambia nada: las dos máquinas son QWERTY. Se decide igual porque cambiarlo después
es tocar cada binding a mano y nadie se acuerda de por qué estaba así.

**Ojo con el MCP:** `input_map_manage` **solo puede bindear por `keycode`.** No expone
`physical_keycode` ni `InputEventKey.location` (el que distingue Shift izquierdo de
derecho). Los bindings de movimiento hay que escribirlos a mano en `project.godot` o
cargarlos por el diálogo de Input Map del editor, tildando *Physical*.

### Assets: CC0 gratis, una sola familia visual

Kenney + KayKit como base, Quaternius para animaciones y personajes. La coherencia visual
importa más que la calidad individual de los modelos: mezclar packs de estilos distintos da
un asset flip.

### Tooling: MCP server `hi-godot/godot-ai`

Instalado y configurado (commit `37fc970`). El plugin vive en `addons/godot_ai/` y está
commiteado en el repo, así que las dos máquinas corren la misma versión.

Por qué este y no otro:

- Se autoconfigura con Claude Code desde el propio editor, sin editar configs a mano.
- Licencia MIT.
- Mantenimiento activo.
- Expone 43 tools contra el editor en vivo.

No es ninguno de los tres que evalúa `docs/plan.md` §5 (GDAI, Coding-Solo, alexmeckes):
esa lista quedó vieja porque el plan se escribió **antes** de compararlos de verdad.

Registra un autoload `_mcp_game_helper` en `project.godot`. Es esperado, no un accidente.

---

## Problemas que ya nos pasaron

Documentados porque van a volver a pasar.

**El proyecto quedó anidado.** "Create New Project" en Godot crea una subcarpeta con el
nombre del proyecto, así que el `project.godot` terminó un nivel más abajo de la raíz del
repo. Se arregló re-clonando limpio y copiando a mano los archivos del proyecto (sin la
carpeta `.godot`, que se regenera sola).

→ **Regla permanente: nunca "Create New Project". Siempre "Import" apuntando al
`project.godot` del repo clonado.**

**Error 403 al hacer push.** Ser miembro de la organización no da permiso de escritura
sobre los repos. Se arregló dándole rol de administrador. Si vuelve a pasar y los permisos
están bien, la otra causa típica son credenciales viejas de GitHub guardadas en el
Administrador de credenciales de Windows.

**Push rechazado con "fetch first".** El remoto tenía commits que la copia local no tenía.
Se arregla con `git pull` antes del push.

→ **Regla permanente: `git pull` antes de empezar a trabajar, siempre, no solo cuando algo
falla.**

**"nothing to commit, working tree clean" con cambios hechos.** El archivo estaba editado
pero sin guardar. En VS Code, el puntito blanco en la pestaña significa sin guardar.

**gdUnit4 no se pudo instalar desde el AssetLib.** El botón *Download* quedaba
deshabilitado, con la versión colgada en `Version: Loading...` indefinidamente.
**Sin resolver.** Consecuencia: no hay tests headless todavía, así que el comando de tests
de `CLAUDE.md` no corre.

→ Alternativa a probar: bajar el release directo de GitHub y descomprimir `addons/gdUnit4/`
a mano en el repo, salteando el AssetLib.

**Godot pisa los cambios que git hace en `project.godot`.** Si un `git pull` modifica
`project.godot` con el editor abierto, Godot detecta el cambio externo y pregunta qué
hacer. Hay que elegir **"Reload from disk"**.

Nunca **"Ignore external changes"**: eso deja al editor trabajando con la versión vieja en
memoria, y la primera vez que Godot guarde project settings reescribe el archivo con esa
versión y borra lo que bajó de git. Como `project.godot` lo tocan los dos (autoloads, input
map, capas de física), es la forma más fácil de pisarle el trabajo al otro.

→ **Regla permanente: si `project.godot` cambió por git, "Reload from disk". Lo más seguro
es cerrar el editor antes de hacer `git pull`.**

---

## Riesgos identificados

**Claude Code es más débil justo en 3D y en proyectos que dependen de assets.** Rinde bien
en sistemas, lógica y datos; se traba en game feel, balance y todo lo que requiera *ver* el
juego corriendo. Mitigación: MCP server para darle ojos, tests headless, y jugar el juego
nosotros cada milestone.

**El fallo característico documentado: "los tests pasan pero el juego es injugable."**
Los tests miden corrección, no diversión. Ninguna tarea se da por terminada porque los
tests estén verdes.

**El riesgo mayor para nosotros: descargar todo el trabajo cognitivo en la IA.** Hay casos
documentados de gente que abandonó su proyecto porque perdió el contacto con su propio
código y no lo podía arreglar. Estamos aprendiendo gamedev, así que:

→ **Regla permanente: leer el diff antes de commitear. Si un archivo resulta opaco, pedir
que lo expliquen antes de aceptarlo.**

**El multiplayer duplica el costo de cada feature.** Cada sistema tiene que contestar
"quién es dueño de este estado y cómo se replica". Es un impuesto sobre todo el proyecto,
no un feature que se agrega.

---

## Pendiente

- [ ] Tutorial oficial 3D de Godot, los dos por separado
- [ ] **Huecos de diseño abiertos.** Ninguno bloquea v0.1 ni v0.2:
      1. Si el inventario de v0.3 usa `expressobits/inventory-system` o se escribe. Se
         responde **en v0.3**, verificando si el addon replica en red solo o si hay que
         serializar a `PackedByteArray` igual
      2. **Vendas:** falta decidir si la vida se regenera sola o solo con items. Hasta que
         eso esté, las vendas no tienen dónde enchufarse
      3. **Palanca:** no hay puertas ni contenedores trabados en el plan, así que no hay
         mecánica que la use
      4. **Qué entra al save**, tres cosas sin decidir (items tirados en el piso,
         inventario y stats de los jugadores, zombies). Se deciden **antes** de escribir
         el save de v0.5, no después: cada una impone requisitos aguas arriba. Lista en
         `docs/netcode.md` → "Qué entra al save"
- [ ] Definir quién tiene el plan Pro de Claude
- [ ] Instalar gdUnit4 — el AssetLib falla (ver "Problemas"). Probar el `.zip` de GitHub
- [ ] Bajar los packs de assets y decidir la familia visual. **Se puede hacer en paralelo
      desde v0.3**, en los ratos sin código: no bloquea hasta v0.6, pero llegar a v0.6 con
      la familia ya elegida convierte esa pasada de arte en aplicar decisiones, no tomarlas
- [ ] Dibujar el mapa en papel
- [ ] **Playtest de quince minutos sin código a la vista, por cada milestone.** Jugarlo,
      no revisarlo. Es la versión barata del "testigo independiente": el sesgo de
      autoevaluación no se corrige leyendo el propio diff
- [ ] **Al tercer mes, revisar si la velocidad de avance cayó.** Está medido que con IA la
      velocidad sube fuerte el mes 1, la mitad el mes 2 y vuelve a cero el mes 3, mientras
      la complejidad queda +41% permanente (`docs/investigacion-claude-code.md`). Si lo
      sentimos, no es impresión: es el patrón. La contramedida es refactorizar a propósito,
      no acelerar

---

## Registro

**[1/8/2026]** — Setup completo. Organización, repo, estructura de carpetas, `CLAUDE.md`,
rules y docs iniciales. Verificado el ida y vuelta de commits entre las dos máquinas.

**[1/8/2026]** — Auditoría de los docs y corrección de inconsistencias. Lo importante:
la regla de autoridad de red pasó a **autoridad dividida** (ver "Decisiones tomadas"),
se fijó **primera persona**, y se definió el **idioma del código** (inglés para
identificadores, español para comentarios y docs). Además: se resolvió un conflicto de
merge que había quedado commiteado en `docs/design.md`, se crearon `scripts/player/`,
`scripts/enemies/` y `scripts/ui/`, se amplió el scope de `.claude/rules/netcode.md` a
`scenes/**` y a esas carpetas, se agregaron `export_presets.cfg` y `*.tmp` al `.gitignore`,
y se arreglaron los comandos de `CLAUDE.md` (Godot no está en el PATH: el ejecutable está
en `C:\Godot\Godot_v4.7.1-stable_win64.exe`).

**[1/8/2026]** — Tres decisiones más, todas para desbloquear v0.1: **character controller
propio** (ver arriba), **escala y números base** del jugador y el mundo (en
`docs/design.md`), y **`project.godot` pasa a tener un solo dueño, Mathi** (en el reparto
de trabajo de `docs/design.md`). Con esto v0.1 no tiene ninguna decisión pendiente.

**[2/8/2026]** — Sesión de proceso, sin código. Entraron `docs/proceso.md` (commits,
documentación, diagnóstico de errores) y `docs/investigacion-claude-code.md` (modos de
falla medidos de la IA en gamedev), y el resto de los docs se alineó con ellos.

**El reparto de trabajo por carpetas queda sin efecto** y revierte lo decidido el
1/8/2026: los dos trabajamos en todo, **`project.godot` incluido**, y ya no tiene dueño.
Lo reemplaza avisarse antes de arrancar diciendo sobre qué archivos, nunca dos personas
sobre el mismo archivo a la vez, y `git pull` siempre antes de empezar. `plan.md` §5 quedó
con la nota de revisión encima del párrafo viejo, igual que §2 con la regla de autoridad.

Se escribieron las **seis primeras ADRs** en `docs/decisions/`, reconstruidas desde esta
bitácora y desde `plan.md`: engine, lenguaje, autoridad de red, plan de transporte,
character controller y MCP. Donde el porqué no estaba registrado, quedó escrito que no lo
está, en vez de inventarlo.

En `CLAUDE.md`: el formato de las respuestas pasó a ser explícito (qué cambié / probá vos
/ decidí vos, y qué no escribir nunca), y la versión de Godot quedó fijada arriba de todo.
Para no pasar las 200 líneas se movieron tres secciones a `.claude/rules/limites.md`.
Rules nuevas: `commits.md` y `limites.md`, las dos con scope a todo el repo.
`.claude/rules/gdscript.md` sumó el checklist de los 10 pitfalls, y `docs/netcode.md` la
advertencia de que el `MultiplayerSynchronizer` **no** sincroniza el inventario solo
(v0.3: hay que serializar a `PackedByteArray` a mano).

**Un dato que se verificó corriendo Godot 4.7.1**, porque circula mal en todos lados: la
firma vieja `connect("pressed", self, "_on_x")` no "compila y no hace nada". Con tipado
estático es error de parseo y el script no carga; solo sobre un `Variant` llega a runtime
y deja la señal muerta en silencio. El static typing obligatorio previene el caso malo.

**[2/8/2026]** — Auditoría del plan y decisiones de scope del mapa. Sin código.

**v0.1 es una caja con piso y paredes**, no "una manzana": `plan.md` §3 decía una cosa y
`design.md`, `netcode.md` y el propio `plan.md` §6 decían otra. Gana la caja porque v0.1 es
el filtro y un filtro tiene que costar horas — un mapa hecho a mano arrastra ambientación,
packs y familia visual, y entonces deja de medir el esqueleto de red.

**El mapa pasa a tener progresión propia** (`plan.md` §3 → "Progresión del mapa"): greybox
primero, arte al final. Caja en v0.1, greybox mínimo en v0.2 para que el NavMesh tenga qué
navegar, el greybox crece en v0.3-v0.5, y la pasada de arte recién en v1.0. **Consecuencia:
la familia visual no bloquea nada hasta v1.0.** Tamaño del mapa de v1.0: **250 × 250 m**,
valor de arranque a tunear, en `design.md`.

**"Qué pasa al morir" se partió en dos decisiones:** respawn y revivir bloquean v0.2; qué
pasa con el inventario al morir bloquea v0.3, porque hasta v0.3 no hay inventario que
perder. Antes era un solo `[DECIDIR]` atado a v0.2 y no se podía cerrar.

**El addon de inventario de expressobits queda registrado como pregunta abierta**, no como
decisión tomada: `plan.md` afirmaba que es multiplayer-friendly y `netcode.md` advierte que
el `MultiplayerSynchronizer` no replica estructuras anidadas. Se decide en v0.3 verificando
si el addon replica solo o si hay que serializar a `PackedByteArray` igual.

Además se arreglaron cuatro desalineaciones entre docs: el encabezado de `plan.md` §2 y el
ejemplo de rule de §5 seguían diciendo "autoridad total del host"; la estructura de carpetas
estaba escrita tres veces y ninguna coincidía —ahora la única versión está en `CLAUDE.md` y
`plan.md` apunta ahí—; `plan.md` §5 describía el loop de verificación como cerrado cuando
gdUnit4 no está instalado; y las referencias de tono de `plan.md` no incluían DayZ ni Road
to Vostok.

**[2/8/2026]** — **Se cerraron todos los huecos de diseño menos uno.** Está todo en
`docs/design.md`; acá va solo lo que tiene consecuencia sobre el plan.

**Nombre: SurGameZombie**, provisorio. **Ambientación: un complejo industrial** —fábrica,
depósitos, oficinas, playa de camiones—, elegida contra el tamaño del mapa: 250 × 250 m
son unas 2 × 2 manzanas y un pueblo no entra. **No hay condición de victoria:**
supervivencia infinita.

**Muerte, en dos etapas.** En v0.2 quedás **caído**, no muerto: un compañero puede
levantarte y si nadie llega en 60 segundos morís de verdad y respawneás cerca. En v0.3 la
muerte real deja el inventario en una **bolsa** que solo saquean jugadores, que no
despawnea por tiempo y desaparece al quedar vacía.

**El mundo persiste** —los contenedores vaciados siguen vacíos, el mapa no se resetea—, y
eso **convierte el guardado de v0.5 en obligatorio**: sin guardado, la persistencia dura
lo que dura la sesión del host.

**Inventario limitado por peso**, no por slots ni por grid. Se descartó el grid tipo
Tarkov: duplica el trabajo de UI y empeora la serialización de red, porque cada item pasa
a guardar posición y rotación además de cantidad. Migrar después es reescribir la UI de
inventario entera.

**Los primeros 10 items:** bate, pistola 9mm, munición 9mm, botella de agua, lata de
comida, barra de cereal, vendas, linterna, mochila, palanca. Un solo melee y una sola arma
de fuego, consistente con v0.5. **Escopeta y fusil quedan para v0.6 en adelante**, porque
con tres armas de fuego en diez items el combate deja de ser escaso.

**Queda un solo hueco:** si el inventario de v0.3 usa el addon de expressobits o se
escribe. **v0.2 no tiene ninguna decisión de diseño pendiente.**

**[2/8/2026]** — Consecuencias de las decisiones de diseño de arriba, resueltas una por
una. Sin código. Lo que tiene efecto de acá en adelante:

**El estado caído no reasigna autoridad de red.** El cuerpo del jugador sigue siendo del
peer dueño incluso caído: el host decide que caíste, el cliente lee el flag y deja de leer
input. Le confiamos al cliente que respete su propio flag. *Rejected: pasarle la autoridad
del cuerpo al host mientras dura el caído | toca el `MultiplayerSynchronizer` en caliente,
que da bugs difíciles, y del otro lado no hay PvP que defender.* En `docs/netcode.md` y en
`.claude/rules/netcode.md`. **Regla general que sale de acá: la autoridad no se reasigna en
runtime, nunca.**

**El patrón del modificador, con nombre porque se va a repetir:** el host calcula el
modificador de velocidad y lo replica, el cliente lo multiplica al moverse, el cliente
nunca lo calcula. Ya aplica a la stamina (v0.4); el sobrepeso (v0.3) es el segundo caso y
heridas y temperatura entrarían igual.

**El save vive en la máquina de quien hostea: si hostea el otro, es otro mundo.** Aceptado
por simple. Si molesta, la solución es que hostee siempre el mismo, no sincronizar saves.
Consecuencia que hay que aplicar dos milestones antes de que se note: **los contenedores
llevan un ID persistente propio (`@export var container_id: String`), no `NodePath`**,
porque el save de v0.5 los busca por ese ID y mover o renombrar un nodo cambia su ruta.
Anotado en v0.3 y en v0.5.

**Slots de equipo: mochila y arma en mano, solo esos dos.** No contradice el inventario
por peso: el peso limita qué cargás, los slots definen qué tenés puesto. **Capacidad: 25 kg
sin mochila, 40 con.** Al pasarte caminás más lento y no podés correr — sin bloqueo duro.
Valores de arranque.

**Tabla item → mecánica → milestone** en `docs/design.md`. Lo que deja claro: **en v0.3 los
diez items entran, pero solo la mochila hace algo.** Vendas, linterna y palanca son items
inertes ahí y es a propósito — v0.3 prueba el inventario, no las mecánicas. Aparecieron dos
huecos de diseño nuevos, los dos sin bloquear nada: cuándo curan las vendas (depende de si
la vida se regenera sola, que no está decidido) y qué abre la palanca (no hay mecánica de
acceso trabado en el plan).

**v1.0 se partió en dos.** Tenía arte, sonido, lobby, menús y mapa final juntos: más
trabajo que v0.1 a v0.5 sumadas, y un milestone que no se puede terminar no ordena nada.
Queda **v0.6 "Se ve"** (pasada de arte, familia visual, iluminación, post-processing, SFX)
y **v1.0 "Se juega con amigos"** (noray, lobby, menús, nombre definitivo, balance final).
La pasada de arte va sola porque es el único bloque que no toca sistemas: mezclada con
netcode, es lo primero que se recorta cuando aparece un bug. **La familia visual y los SFX
se pueden ir haciendo en paralelo desde v0.3**, aunque no bloqueen hasta v0.6.

Efecto colateral de partir v1.0: la entrada anterior decía "escopeta y fusil quedan para
v0.6 en adelante", escrito cuando v0.6 no era un milestone definido. Ahora v0.6 es la
pasada de arte, así que en `docs/design.md` quedó como **"fuera de la v1"**, que era la
intención. `docs/decisions/0004-plan-de-transporte.md` dice "Ahora → v0.5" por el mismo
motivo; **no se toca, las ADRs son inmutables** (`docs/proceso.md` §2). Se lee bien igual:
ENet sigue hasta que entre noray en v1.0.

**[2/8/2026]** — Cierre de la misma sesión: **v0.2 queda planificada de punta a punta** y
se escribió **ADR-0007**. Sin código.

**ADR-0007: la autoridad de red no se reasigna en runtime, nunca.** Generaliza lo del
estado caído: `set_multiplayer_authority()` se llama en un solo lugar del proyecto —el
host, al instanciar al jugador— y en ninguno más. Aplica de antemano a los estados que
todavía no existen (vehículos, que un zombie te agarre): flag en el nodo de stats del host,
replicado, y el cliente lo respeta saliendo temprano de `_physics_process`. Es un molde, no
una decisión nueva cada vez. Queda atada a ADR-0003: las dos apoyan en que no hay nada que
defender, y si algún día lo hay, se revisan juntas.

**`docs/netcode.md` → "Cómo se resuelve v0.2"**, con el mismo formato que la de v0.1 y las
dependencias marcadas. Lo que sale de ahí y no era evidente:

- **v0.2 tiene dos RPCs del patrón 2, no uno.** El daño y `request_revive`. La validación
  de distancia para levantar a alguien la hace el host contra las posiciones ya replicadas,
  nunca contra una distancia que mande el cliente. El timer de 60 s también corre en el
  host: en cada cliente, dos latencias distintas llegan a cero en momentos distintos.
- **El NavMesh va antes que el zombie, no con el zombie.** Parece cosa de la IA, pero el
  respawn "cerca de donde caíste" necesita validar que el punto sea navegable, así que
  bloquea también el último paso del milestone. Dejarlo para cuando toque la IA traba el
  final de v0.2 por algo que se podía hacer primero.
- **El segundo `MultiplayerSynchronizer` es donde muerde la trampa de
  `set_multiplayer_authority(id, recursive = true)`.** En v0.1 no se nota porque no hay
  stats; en v0.2 la vida termina siendo del cliente y el host no puede aplicar daño.

**Verificado por MCP contra el editor 4.7.1-stable**, porque estaba escrito de memoria y es
justo el tipo de API que se alucina: `NavigationServer3D.map_get_closest_point(map: RID,
to_point: Vector3) -> Vector3` existe con esa firma exacta, igual que
`World3D.get_navigation_map() -> RID`, `map_get_random_point()` y `map_force_update()`.
**Lo importante es lo que la firma implica:** devuelve `Vector3`, no `bool`, así que **no
falla nunca** — siempre da el punto más cercano del NavMesh, esté a 10 cm o a 40 m.
Validar "es navegable" es comparar la distancia contra el punto pedido. Sin eso, morir
arriba de un techo te respawnea del otro lado del mapa. Eso último es inferencia de la
firma, **no verificado corriendo**: cuando se implemente, probarlo muriendo a propósito en
un lugar sin NavMesh.

**La bolsa de muerte es una entidad de red, no un item, y es la pieza más cara de v0.3.**
En el diseño ocupa dos renglones y arrastra: `MultiplayerSpawner`, un inventario entero
serializado (el mismo problema del `PackedByteArray`), RPC del patrón 2 para sacar cosas,
chequeo de vacío en el host cada vez que alguien saca algo, e ID persistente porque **entra
al save de v0.5**: una bolsa que nadie vació tiene que seguir ahí después de cerrar el
juego. Si en v0.3 se hace como algo que vive solo en memoria, v0.5 la reescribe entera.

**`docs/netcode.md` estrena "Qué entra al save"**, lista viva: contenedores, bolsas de
muerte y hora del día. Quedaron tres cosas **sin registrar** que hay que decidir antes de
escribir el save, no después: si los items tirados en el piso sobreviven al cierre, si el
inventario y las stats de cada jugador persisten entre sesiones —y qué pasa con el de
alguien que no está conectado cuando el host guarda—, y si los zombies entran o no.
