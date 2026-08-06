# Plan de proyecto — Zombie survival co-op

**Contexto:** dos personas, saben programar, cero experiencia en gamedev. Co-op 2-4 jugadores, uno hostea. Hobby sin plazo. Referencias de tono: SurrounDead, DayZ y Road to Vostok (las mismas que `docs/design.md`, que es la fuente de verdad del diseño). Herramienta principal: Claude Code.

---

## 1. Decisión de stack

### Engine: Godot 4.7 (4.7.1-stable, julio 2026)

No es la respuesta obvia — SurrounDead está hecho en Unreal Engine 5 — pero para *este* proyecto con *estas* restricciones es la correcta. Las razones, en orden de peso:

**a) Compatibilidad real con Claude Code.** Este es el criterio que más pesa y el que más gente ignora.

| Engine | Formato de escenas/prefabs | Qué puede tocar un agente con acceso al filesystem |
|---|---|---|
| Godot | `.tscn` / `.tres` — texto plano tipo INI | Todo: código, escenas, materiales, datos |
| Unity | YAML (`Force Text` es default desde ~2020) | Casi todo, pero el YAML está lleno de GUIDs y `fileID`s; frágil de editar a mano |
| Unreal | `.uasset` binario (Blueprints, materiales, niveles, UI) | Solo el C++. El resto es ilegible |

En Unreal, Claude Code puede escribir C++ y nada más. Todo lo que hagas en Blueprints o en el editor es una caja negra que no puede leer, ni verificar, ni diffear. En Godot, el proyecto entero es texto: Claude Code puede crear una escena, definir 40 items, y vos ves el diff en git.

**b) El multiplayer que querés es exactamente el caso de uso del high-level multiplayer de Godot.** `MultiplayerSpawner`, `MultiplayerSynchronizer` y `@rpc` están diseñados para listen server (un jugador hostea y juega en el mismo proceso) con pocos peers. No necesitás librería de terceros para arrancar.

**c) Corre en cualquier máquina.** No me pasaste specs. Con Godot no importa: el editor arranca en segundos y no necesita GPU moderna. UE5 con Lumen/Nanite necesita una máquina decente solo para abrir el editor, y si alguno de los dos tiene un equipo flojo, se convierte en un cuello de botella permanente.

**d) MIT, gratis, sin royalties, sin tracking de revenue.** Unreal cobra 5% después del primer millón (irrelevante para ustedes, pero suma fricción legal). Unity tiene su historial.

**e) Prueba de existencia directa.** Expresso Bits — dos hermanos brasileños, Rafael (programador) y Gabriel (artista) — están haciendo *Nevoa*, un survival horror 3D multijugador para Steam, en Godot. Vinieron de Unity y se cambiaron. Y liberaron como open source justo las tres piezas que ustedes van a necesitar: el sistema de inventario multiplayer-ready, el character controller modular, y el plugin de red por Steam. Es literalmente el mismo proyecto, el mismo tamaño de equipo, y les dejaron las herramientas.

### El trade-off honesto de elegir Godot

No te lo vendo sin costo:

- **Godot 3D se ve peor out of the box.** No hay Lumen ni Nanite. Para llegar al look de SurrounDead vas a tener que trabajar iluminación, post-processing y foliage a mano. UE5 te regala un baseline visual que Godot no.
- **No hay terrain system oficial.** Necesitás [Terrain3D](https://github.com/TokisanGames/Terrain3D) (MIT, C++ GDExtension, soporta hasta 65.5×65.5 km, con LODs y clipmap geomorphing como The Witcher 3). Funciona bien pero es un addon más que mantener.
- **El ecosistema de tutoriales de survival 3D es mucho más chico** que el de Unity/Unreal. Vas a encontrar menos respuestas googleando, y más veces vas a tener que leer el código fuente del addon.
- **Godot 3D está menos probado en mundos grandes.** Vas a chocar con paredes de performance antes que en Unreal.

Si el objetivo fuera fidelidad visual, Unreal gana. Como el objetivo es *aprender, iterar rápido y apalancarse en Claude Code*, Godot gana por bastante.

### Lenguaje: GDScript (no C#)

Aunque vengan de otro lenguaje. Razones:

- Es el lenguaje de primera clase: toda la documentación, todos los tutoriales y casi todos los addons están en GDScript.
- **No tiene paso de compilación.** Editás y corrés. Eso acorta el loop de feedback, que es exactamente lo que hace productivo a Claude Code.
- Es Python-like. Sabiendo programar, lo tenés en dos días.

**Regla no negociable:** usar **static typing** siempre (`var health: float = 100.0`, `func take_damage(amount: int) -> void:`). GDScript es dinámico por default y eso es veneno para un agente: sin tipos, ni el editor ni Claude Code detectan errores hasta runtime. Con tipos, la mitad de los bugs los agarrás antes de correr. Esto va en `CLAUDE.md` como regla dura.

---

## 2. Arquitectura de red

### Modelo: listen server con autoridad dividida

Un jugador corre el juego **y** la lógica de servidor en el mismo proceso. Los otros 1-3 se conectan como clientes.

**La regla original, del commit 1. Quedó revisada — leer la nota de abajo antes de aplicarla:**

> El host es autoridad sobre todo el estado del juego. Los clientes mandan *input*. El host simula y replica *estado*.

> **[Revisado — ver `docs/netcode.md`, que es la fuente de verdad.]** Esta regla resultó
> demasiado absoluta en la práctica: aplicarla al movimiento del propio jugador exige
> client-side prediction, que es demasiado para empezar. El modelo final afloja *solo* el
> movimiento (autoridad del peer dueño) y mantiene el host como autoridad de todo el resto.
> El párrafo de abajo sigue explicando bien **por qué** hace falta una única fuente de
> verdad, que es el motivo por el que el resto del estado no se afloja.

Un cliente nunca decide que le pegó a un zombie, que agarró un item, o que su hambre bajó. Manda "quiero atacar" / "quiero agarrar esto" y el host resuelve. Esto no es paranoia anti-cheat (son 4 amigos), es que **sin una única fuente de verdad, el estado diverge entre máquinas y el juego se rompe de formas imposibles de debuggear**.

Retrofitear autoridad después es una reescritura completa. Por eso va en el commit 1 y por eso va como `path-scoped rule` en `.claude/rules/`.

### Conectividad: tres opciones, en este orden

No elijas una para siempre. Elegí una para *ahora* y aislá el cambio.

| Opción | Costo | Qué resuelve | Cuándo |
|---|---|---|---|
| **ENetMultiplayerPeer** (built-in) | $0, cero deps | Conexión directa por IP. Anda en LAN sin configurar nada. Por internet el host tiene que abrir puerto en el router | v0.1 → v0.6. Para testear entre ustedes dos |
| **netfox.noray** | $0, open source | NAT punchthrough + fallback a relay. Los amigos se conectan con un código, sin tocar el router. Hay instancia pública de prueba en `tomfol.io:8890` (sin garantía de uptime, no para producción) | Cuando quieran meter amigos que no van a hacer port forwarding |
| **SteamMultiplayerPeer** (expressobits) + GodotSteam | $100 por App ID, recuperable a los USD 1.000 de revenue | Steam maneja NAT, lobbies, invitaciones por el overlay. Para desarrollo se usa el App ID 480 (Spacewar) gratis | Solo si el juego alguna vez apunta a Steam |

**Consecuencia de diseño:** poné la creación del peer detrás de **un solo script** (`scripts/net/network_manager.gd`). El resto del código nunca sabe qué transporte se usa. Cambiar de ENet a noray a Steam tiene que ser un cambio de 10 líneas en un archivo, no un refactor. El plugin de expressobits está diseñado exactamente para eso: swappeás `ENetMultiplayerPeer` por `SteamMultiplayerPeer` y el código de alto nivel queda igual.

---

## 3. Scope de la v1

### El conflicto que hay que resolver primero

Dijiste "supervivencia realista" y también "primera versión simple". Están en tensión. Supervivencia realista significa hambre + sed + temperatura + fatiga + heridas + enfermedad interactuando entre sí — eso son seis sistemas que se afectan mutuamente, y cada uno multiplicado por "y además tiene que replicarse en red".

**La salida:** el realismo de un survival no viene de la *cantidad* de stats, viene de la *escasez y la consecuencia*. DayZ se siente brutal no por tener 15 barras, sino porque la comida es rara y morirte cuesta horas. Podés lograr eso con tres stats bien tuneadas.

**v1 = 3 stats (vida, hambre, sed) + stamina.** Temperatura, heridas y enfermedad quedan para v2, y las agregás cuando el loop base ya se siente bien.

### Milestones — cada uno tiene que ser jugable

**v0.1 — "Se mueve"** *(el milestone más importante de todos)*
Una caja con piso y paredes. Character controller en primera persona. Host + 1 cliente conectados por IP en LAN, viéndose moverse en tiempo real. Sin zombies, sin items, sin nada.
*Por qué primero:* prueba el esqueleto de red. Si esto no funciona limpio, nada de lo demás importa. Y si sale mal, descubrirlo acá cuesta un día, no tres meses.
*Por qué una caja y no un mapa:* v0.1 es el filtro, y un filtro tiene que costar horas. Un mapa hecho a mano —aunque sea una manzana— arrastra ambientación, packs de assets y familia visual, o sea que deja de medir si el esqueleto de red funciona y pasa a medir cuánto tardamos en decidir cómo se ve el juego. **v0.1 no depende de ninguna decisión de arte.**

**v0.2 — "Mata"**
Un tipo de zombie. NavMesh para que persiga. **Ataque cuerpo a cuerpo del zombie** —el melee del jugador es v0.5, y hasta entonces al zombie no se lo puede matar. Vida del jugador, caído, revivir, muerte y respawn. Todo el daño resuelto en el host.
*El orden interno del milestone está resuelto en `docs/netcode.md` → "Cómo se resuelve v0.2", con las dependencias marcadas.* La que no es obvia: **el NavMesh va antes que el zombie**, porque el respawn "cerca de donde caíste" también lo necesita para validar que el punto sea navegable.

**v0.3 — "Se lootea"**
Inventario replicado. ~10 items. Contenedores registrables (armarios, autos). Pickup y drop sincronizados. Capacidad por peso: 25 kg, 40 con la mochila equipada.
*El addon de inventario de expressobits es candidato, no decisión tomada* — está hecho en C++ (GDExtension), es modular y separa la lógica de la UI. Que sea "multiplayer-friendly" **no está verificado** y es justo lo que hay que verificar: ver el hueco abierto en `docs/design.md` y la advertencia de `docs/netcode.md` sobre serializar el inventario a mano.
**Los contenedores nacen con un ID persistente propio, no con `NodePath`** (`@export var container_id: String`). El save de v0.5 los va a buscar por ese ID, y renombrar o mover un nodo cambia su ruta en el árbol. Es dos milestones antes de que se note: si acá se usan node paths "porque todavía no hay save", en v0.5 hay que volver a tocar cada contenedor del mapa. Ver `docs/netcode.md` → "El mundo es del host".
De los 10 items, en v0.3 solo la mochila hace algo; el resto entra inerte, a propósito (tabla en `docs/design.md`).
**La bolsa de muerte entra acá y hay que presupuestarla aparte:** no es un item, es una entidad de red con spawner, inventario serializado y persistencia (ver `docs/netcode.md`). Es la pieza más cara del milestone.
**gdUnit4 se instala acá, no antes.** Se verificó que es GDScript puro (cero binarios, cero GDExtension) y que la versión 6.2.1 soporta 4.7.1, así que el pendiente que venía arrastrándose no era de compatibilidad sino del AssetLib: se baja el zip del tag de GitHub y se copia `addons/gdUnit4/`. **Las suites van como `*_test.gd`, nunca `test_*.gd`:** el runner que trae el MCP `godot-ai` —`McpTestSuite`, que existe y nadie está usando— descubre por el prefijo contrario y reportaría cada suite de gdUnit4 como error. Medido con los dos instalados. El argumento para instalarlo es v0.3 y no v0.2: hoy hay ~200 líneas que justifiquen un test unitario, y la matemática del inventario las multiplica.

**v0.4 — "Duele"**
Hambre y sed drenando con el tiempo. Comida y agua como items consumibles. Muerte por inanición. Stamina que se consume corriendo.
**Acá entra la curación** —vendas / item médico— **y con ella el límite de revivires.** Va acá y no en v0.3 para reusar el mismo sistema de "usar un item que restaura una stat" que este milestone construye igual para hambre y sed, en vez de escribir esa lógica dos veces, un milestone antes y con otro dueño.
**La regla del segundo caído, entera:** si un jugador cae, lo levantan, y **vuelve a caer sin haberse curado en el medio** dentro de los 10 minutos, la segunda caída no lo deja caído: **muere directo**, sin oportunidad de que lo levanten. En cualquier otro caso —si se curó, o si pasaron más de 10 minutos— vuelve a caer normal. Curarse es lo que corta la racha.
*Por qué no se implementa antes:* hoy no existe ninguna curación, así que "sin haberse curado" sería **siempre** verdadero y la regla mataría siempre en la segunda caída. Es una regla que necesita que exista la salida que ofrece.
*Consecuencia aceptada:* durante todo v0.3 nadie muere de verdad todavía. Un dúo se sigue reanimando indefinidamente el milestone entero.
*Qué sigue sin decidir:* si se avisa en pantalla que estás adentro de la ventana. Que la ventana se cuente por jugador y no para el grupo **no es una decisión aparte**: cada jugador ya tiene su propio estado de caído en su nodo de stats, así que sale de la arquitectura que ya existe.

**v0.5 — "Es un juego"**
Un arma melee + un arma de fuego con munición escasa. Sistema de spawn/densidad de zombies. Ciclo día/noche. Guardado del estado del mundo en el host.
**Acá el zombie pasa a tener vida y se lo puede matar.** Hasta este milestone es invulnerable **a propósito**: no existe ninguna fuente de daño del jugador —lo único que baja vida es `request_damage()` de `world.gd`, un andamio del overlay de debug que se borra cuando entre el HUD—, así que matarlo antes obliga a inventar un melee sin arma que no está presupuestado en ningún milestone. La vida del zombie llega con el bate y la pistola, no antes.
**El save es un archivo en la máquina de quien hostea:** si hostea el otro, es otro mundo. Aceptado — ver `docs/netcode.md` → "El mundo es del host". Lee los contenedores por el ID persistente que se les puso en v0.3, no por node path.
**Acá entra el número del cuerpo caído**, la mitad "dato" del trabajo de que el zombie pueda saltarle por encima (la mitad "arte" está en v0.6). Hoy el `NavigationObstacle3D` del caído tiene `height = 1.8`, o sea que estorba como una persona parada, y eso es lo que lo vuelve una pared. **Dato antropométrico real, ya investigado, para no inventarlo cuando toque.** La pose del caído es **arrastrándose boca abajo**, decidido, y todos los números de acá salen de ese ancla — no de gatear en cuatro patas, que es bastante más alto y no es la pose. Boca abajo, un adulto mide alrededor del **14% de su altura de pie**: profundidad de pecho ~0.25 m contra ~1.75 m de estatura, percentil 50 de adultos británicos y estadounidenses, más ~0.04 m si lleva ropa de exterior. Sobre el 1.8 m de este proyecto da **~0.30 m**. Es el mismo número que `DOWNED_CAMERA_HEIGHT` en `scripts/player/player.gd`, y los dos tienen que moverse juntos si la pose cambia. (De costado serían ~0.49 m por el ancho bideltoideo; queda anotado como contexto, no es la pose elegida.) Fuentes: [CityU, anthropometry cap. 2-20](https://personal.cityu.edu.hk/meachan/online%20anthropometry/chapter2/Ch2-20.htm) y [RoyMech](https://www.roymech.co.uk/Useful_Tables/Ergonomics/Human_sizes.html). El corolario es que un cuerpo tirado es un escalón, no un muro, y `agent_max_climb` está hoy en 0.2.

**v0.6 — "Se ve"**
Pasada de arte sobre el greybox. Familia visual definida y aplicada, iluminación, post-processing, SFX.
*Sacar acá:* la caja de referencia de escala de 1 m³ que está en `world.tscn` desde v0.1 para tener con qué comparar la altura del jugador.
*Entra acá:* la **pose tirado** del caído y la **animación del zombie saltando por encima** — la mitad "arte" del trabajo cuyo número está presupuestado en v0.5. Sin una pose de verdad, bajarle la altura al obstáculo del caído hace que el zombie atraviese visualmente una cápsula parada, que es peor que trabarse (`docs/decisions/0008-horneado-del-navmesh-y-cuerpo-caido.md`).
*Por qué es un milestone propio y no el final de v1.0:* es el único bloque de trabajo del proyecto que no toca sistemas. Mezclado con lobby y menús, lo primero que se recorta cuando aparece un bug de red es el arte, y el juego termina siendo un greybox con menú. Separado, se puede jugar v0.6 y decir "ya se ve como el juego que queríamos" antes de tocar nada de conectividad.

**v1.0 — "Se juega con amigos"**
Conectividad sin port forwarding (noray). Flujo de lobby: crear partida / unirse. Menús. Nombre definitivo. Balance final sobre todo lo que hasta acá tuvo valores de arranque.

Cada milestone se juega de punta a punta antes de pasar al siguiente. Si en v0.3 el inventario no es divertido de usar, no sigas a v0.4.

**Por qué v1.0 se partió:** en la versión anterior de este plan, v1.0 tenía arte, sonido, lobby, menús y mapa final juntos — más trabajo que v0.1 a v0.5 sumadas. Un milestone que no se puede terminar deja de ordenar nada.

### Progresión del mapa

Construimos geometría gris primero (greybox), arte después.

- **v0.1:** una caja. Piso, cuatro paredes, nada más.
- **v0.2:** greybox mínimo. Paredes y obstáculos para que el NavMesh tenga qué navegar. Sin assets, todo cubos grises.
- **v0.3-v0.5:** el greybox crece. Interiores donde poner contenedores, espacios que justifiquen la densidad de zombies.
- **v0.6:** pasada de arte. Recién acá entran los assets encima del greybox.

**Consecuencia:** la familia visual de assets no bloquea nada hasta v0.6, aunque se decida antes.

**Pero no hay que esperar a v0.6 para empezarla.** Elegir la familia visual, bajar los packs, probar cómo se ven juntos en Godot y juntar SFX es trabajo que se puede hacer en paralelo desde v0.3, en los ratos en que no se está tocando código. No bloquea ningún milestone y llegar a v0.6 con la familia ya elegida y los assets ya importados convierte esa pasada de arte en aplicar decisiones tomadas en vez de tomarlas.

---

## 4. Assets gratis

### Fuentes principales (todas CC0 o uso comercial libre)

| Fuente | Qué tiene | Licencia |
|---|---|---|
| **[Kenney](https://kenney.nl)** | Survival Kit (80 assets), Retro Urban Kit (120+), City Kit Roads/Suburban, Building Kit, Car Kit, Food Kit. También UI y audio | CC0 |
| **[Quaternius](https://quaternius.com)** | Universal Animation Library 1 y 2 (130+ animaciones cada una, rig humanoide universal, **incluye locomoción de zombie**), Universal Base Characters, Modular Character Outfits, packs de naturaleza | CC0 |
| **[KayKit](https://kaylousberg.itch.io)** (Kay Lousberg) | City Builder Bits, packs de personajes. Hizo también el pack modular de personajes de Kenney | CC0, sin atribución |
| **[Poly Pizza](https://poly.pizza)** | Agregador de modelos low poly CC0/CC-BY | Varía por modelo — verificar |
| **[ambientCG](https://ambientcg.com)** | Texturas PBR | CC0 |
| **[Freesound](https://freesound.org)** | SFX. Filtrar por CC0 | Varía por archivo — verificar |

### Animaciones: usar Quaternius, no Mixamo

Mixamo sigue online y sigue siendo gratis con cuenta de Adobe (verificado a julio 2026), pero está en modo mantenimiento: Adobe no le mete features desde la adquisición de 2015, discontinuó Fuse en 2020, y tuvo una caída inexplicada de varios días en junio 2025. No anunciaron cierre, pero es una dependencia que no controlás.

La **Universal Animation Library** de Quaternius es mejor opción para este proyecto: es CC0, usa **un solo rig humanoide universal** compatible con Godot/Unity/Unreal listo para retargeting, y la UAL 2 incluye combos de melee, parkour y locomoción de zombie específicamente. Un solo rig para jugador y zombies = la mitad del trabajo de animación.

En Godot el retargeting se hace con `BoneMap` + `AnimationTree`.

### El problema que nadie te avisa: coherencia visual

**Elegí una familia de assets y quedate ahí.** Mezclar Kenney + Quaternius + tres packs random de itch.io da escalas distintas, paletas distintas y densidades de polígonos distintas, y el juego termina pareciendo un asset flip. Esto se nota mucho más que la calidad individual de los modelos.

SurrounDead resolvió esto comprando Synty y usando dos packs de la misma familia (POLYGON Apocalypse y POLYGON Military). Ustedes no tienen Synty, así que la disciplina la tienen que poner ustedes.

Recomendación concreta: **Kenney + KayKit como base** (comparten estilo chunky con texture atlas de gradiente), **Quaternius solo para animaciones y personajes**, y ajustar los personajes de Quaternius a la paleta de Kenney en Blender.

### Formato y herramientas

- **Importar todo como glTF (`.glb`)**. Es el formato que Godot maneja mejor. Convertir FBX/OBJ a glb en Blender antes de meterlo al proyecto.
- **Blender** (gratis) es la única herramienta adicional obligatoria: cortar, unir, arreglar escalas, ajustar materiales.

### Blender MCP: para cuando haya assets, no antes

Pendiente anotado el 2026-08-05. **No instalar todavía.**

Cuando toque normalizar los packs en lote —escalas, pivotes, orígenes, unificar materiales y exportar `.glb` sobre los 80 assets del Survival Kit— eso es Python determinístico y repetitivo, tedioso sin ser difícil. `ahujasid/blender-mcp` (MIT, gratis, 25.5k stars, activo a agosto 2026) automatiza esa parte desde Claude Code. Es la única opción con tracción real: la segunda tiene 298 stars y está muerta desde marzo de 2025.

**El momento es cuando tengamos los packs bajados y toque normalizarlos**, no una versión concreta. Antes de eso no tiene qué hacer. Tres cosas verificadas para cuando llegue ese día:

- **Ejecuta Python sin sandbox dentro de Blender** (`execute_blender_code`). El propio README lo marca como riesgo: guardar antes de usarlo.
- **Manda telemetría** hasta que se le ponga `DISABLE_TELEMETRY=true` en la config del MCP. Desde julio 2026 la parte invasiva (prompts, código, screenshots) es opt-in, pero la mínima viene prendida.
- **Sus integraciones generativas —Hyper3D Rodin, Sketchfab, Hunyuan3D— no se usan.** Generar modelos uno por uno rompe justo la coherencia visual de la que habla la sección anterior. El MCP puede aplicar un cambio de paleta en lote; **cuál** es decisión de ustedes, no suya.

---

## 5. Organización del proyecto para Claude Code

Esta es la parte que más rendimiento te va a dar y la que más gente se saltea.

### Estructura de carpetas

Organizada **por sistema, no por tipo de archivo**. Claude Code trabaja mucho mejor cuando todo lo de "inventario" está en una carpeta.

**El árbol vive en `CLAUDE.md` → "Estructura", que es la única versión.** No se repite acá: estaba escrito en tres lugares distintos y los tres se habían desincronizado.

### Datos como Resources (`.tres`), no hardcodeados

Items, tipos de zombie, loot tables: todo como archivos `.tres`. Son texto plano. Esto significa que le podés pedir a Claude Code "generá 30 items de comida balanceados según esta tabla" y te crea 30 archivos que vos revisás en un diff de git.

Este es probablemente el mayor multiplicador de productividad del proyecto entero. Si hardcodeás los items en GDScript, perdés esto.

### Cómo repartir las instrucciones (según la guía oficial de Anthropic)

Hay siete formas de instruir a Claude Code y cada una tiene un costo de contexto y una autoridad distinta. Las cuatro que importan acá:

**`CLAUDE.md` en la raíz** — se carga al inicio de sesión y se queda toda la sesión. Va lo que Claude tiene que saber *siempre*: comandos de build y run, layout de directorios, convenciones de código, la regla de static typing, qué addons se usan y dónde está su documentación. Anthropic recomienda mantenerlo **bajo 200 líneas** y tratarlo como un índice que apunta a otros archivos, no como un volcado. Cada línea cuesta tokens en cada sesión, sea relevante o no.

**Rules path-scoped en `.claude/rules/`** — constraints que solo aplican a ciertas carpetas. La versión real y completa de esta regla está en `.claude/rules/netcode.md`; acá va recortada como ejemplo del formato:

```yaml
---
paths:
  - "scripts/net/**"
  - "scripts/combat/**"
---
El cuerpo del propio jugador es autoridad del peer dueño. Todo el resto del
estado es autoridad del host: los clientes mandan intención vía
@rpc("any_peer", "call_local", "reliable") y el host valida, aplica y replica.
Un cliente nunca modifica salud, inventario ni la posición de otro peer.
```

Una regla scopeada a `scripts/net/**` no ocupa contexto cuando estás trabajando en la UI.

**Skills en `.claude/skills/`** — procedimientos repetibles. Solo se carga el nombre y la descripción al inicio; el cuerpo se carga cuando se invoca. Candidatos obvios: "agregar un item nuevo", "agregar un tipo de zombie", "correr el test de dos instancias". Anthropic es explícito: un procedimiento de 30 líneas va en un skill, no en `CLAUDE.md`.

**Hooks en `settings.json`** — para lo que tiene que pasar **determinísticamente**. Correr el linter después de cada edición, correr los tests antes de un commit. La diferencia clave: que el modelo *decida* correr el formatter no es lo mismo que el formatter *corriendo automáticamente*. Un `PreToolUse` hook puede inspeccionar cualquier llamada y bloquearla con exit code 2.

Regla mental: si escribís "siempre que X, hacé Y" en `CLAUDE.md`, probablemente debería ser un hook. Si escribís "nunca hagas X", debería ser un hook o un permiso, porque una instrucción en prosa falla bajo presión en sesiones largas.

### Cerrar el loop de verificación

Este es el punto crítico. Por default, **Claude Code edita archivos pero no puede apretar play y leer el error de runtime** — te entrega código y vos encontrás el bug. Dos cosas cierran ese loop:

**a) Tests headless con GUT o gdUnit4.** Los dos corren desde línea de comandos con `godot --headless`, y gdUnit4 genera reportes JUnit XML/HTML e integra con GitHub Actions (soporta hasta 4.7.x). Claude Code corre los tests y lee pass/fail estructurado.

> **[Estado real: esta mitad del loop NO está cerrada.]** gdUnit4 todavía no se pudo
> instalar —el AssetLib falla, ver `docs/bitacora.md` → "Problemas que ya nos pasaron"—
> así que hoy no hay tests headless y el comando de tests de `CLAUDE.md` no corre. La
> única verificación real del proyecto es el MCP server más jugarlo nosotros. Mientras
> siga así, todo lo que se entregue queda sin cubrir por (a).

Qué testear: **la lógica pura**, no el rendering. Matemática de inventario (stacking, capacidad, split), decay de hambre, cálculo de daño, loot tables, serialización del save. Eso es donde viven los bugs sutiles y es donde los tests pagan.

**b) Un MCP server de Godot** para que Claude Code vea el scene tree en vivo, lea el output del debugger, corra el proyecto y saque screenshots, en vez de adivinar node paths. Opciones activas: [GDAI MCP Plugin](https://github.com/3ddelano/gdai-mcp-plugin-godot), [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp), [alexmeckes/godot-mcp](https://github.com/alexmeckes/godot-mcp). Ver el scene tree real es, según la gente que lo usa, el salto de calidad más grande.

### Git

- **`.gitignore` de Godot:** ignorar `.godot/` (caché de import — se regenera), `*.tmp`, y los export presets con credenciales.
- **Git LFS:** *no* desde el día 1. Con assets low poly y dos personas, el repo tarda en crecer. Metelo cuando pase ~200 MB. Ojo con el límite gratis de GitHub: 1 GB de storage y 1 GB de bandwidth mensual.
- **Commits chicos, uno por feature.** No porque sea buena práctica en abstracto, sino porque cuando Claude Code rompe algo querés poder revertir 20 líneas y no un día de trabajo.

### Trabajar de a dos

> **[Revisado el 2/8/2026 — ver `docs/design.md` → "Reparto de trabajo", que es la fuente
> de verdad.]** El reparto por carpetas quedó sin efecto: los dos trabajamos en todo el
> proyecto y no hay carpetas con dueño fijo, `project.godot` incluido. Lo reemplaza
> avisarse antes de arrancar diciendo sobre qué archivos o carpetas, nunca dos personas
> sobre el mismo archivo al mismo tiempo, y `git pull` antes de empezar siempre. El
> párrafo de abajo sigue explicando bien **por qué** hace falta alguna regla acá —mergear
> escenas a mano duele— que es el motivo por el que el reparto se reemplazó en vez de
> simplemente borrarse.

Los `.tscn` son texto y se pueden mergear, pero mergear escenas a mano es doloroso igual. Regla práctica:

- **Uno es dueño de netcode + sistemas** (`scripts/`), **el otro de mundo + contenido** (`scenes/`, `assets/`, `resources/`).
- Nunca editar la misma escena al mismo tiempo. Avisar antes de tocar `scenes/main/`.
- Cada uno con su propia sesión de Claude Code, ambas leyendo el mismo `CLAUDE.md`.

### Testear multiplayer en una sola máquina

Godot permite correr varias instancias del proyecto simultáneamente (**Debug → Customize Run Instances**). Podés levantar host + 2 clientes en tu PC solo. Sin esto testear multiplayer es insoportable.

---

## 6. Semana 1 concreta

En orden, sin saltear:

1. Instalar **Godot 4.7.1-stable** (versión .NET no; la standard). Los dos, misma versión exacta.
2. Crear repo en GitHub con el `.gitignore` de Godot. Los dos clonan.
3. Hacer el tutorial oficial 3D de Godot completo (unas 3-4 horas). Los dos. **No lo saltees porque sabés programar** — lo que se aprende no es sintaxis, es el modelo mental de nodos y escenas, y sin eso todo lo que te escriba Claude Code te va a parecer magia que no podés debuggear.
4. Escribir `docs/design.md`: una página, qué es el juego, cuál es el loop, qué NO es.
5. Escribir `CLAUDE.md` inicial (esto sí lo podés armar con Claude Code, pasándole este documento).
6. Instalar un MCP server de Godot y verificar que Claude Code ve el scene tree.
7. Arrancar v0.1: dos cápsulas moviéndose en una caja, sincronizadas por red.

---

## 7. Riesgos reales del proyecto

**El multiplayer duplica el costo de cada feature.** Cada sistema tiene que responder "¿quién es dueño de este estado y cómo se replica?". No es un feature que se agrega, es un impuesto sobre todos los features. Lo elegiste conscientemente, pero tenés que presupuestarlo.

**El modo de falla de un proyecto hobby de dos personas es el scope, no la habilidad.** SurrounDead son cuatro años de una persona full-time con assets pagos, y todavía está en Early Access con el multiplayer en un roadmap aparte. Ustedes van a tener menos horas. Un mapa chico terminado vale infinitamente más que un mundo abierto a medias.

**"Supervivencia realista" + "mundo abierto" + "multiplayer" son tres problemas difíciles.** Elegiste los tres. Mi recomendación es soltar "mundo abierto" para la v1: un mapa cerrado y denso (un pueblo, un complejo) es más divertido, más rápido de hacer y más barato en red que un mundo grande y vacío.

**La v0.1 es el filtro.** Si en dos semanas no tienen dos cápsulas sincronizadas moviéndose, el problema no es el scope: es que falta base. Ahí conviene parar y hacer un juego más chico primero (un shooter de arena co-op, dos semanas) antes de volver.

---

## 8. Referencias verificadas

- Godot 4.7.1-stable — julio 2026. Jolt Physics es el default desde 4.6
- [Terrain3D](https://github.com/TokisanGames/Terrain3D) — MIT, GDExtension C++
- [expressobits/inventory-system](https://github.com/expressobits/inventory-system) — MIT, GDExtension C++, multiplayer-friendly
- [expressobits/character-controller](https://github.com/expressobits/character-controller) — MIT, GDScript
- [expressobits/steam-multiplayer-peer](https://github.com/expressobits/steam-multiplayer-peer) — MIT, GDExtension
- [netfox / netfox.noray](https://github.com/foxssake/netfox) — NAT punchthrough + relay
- [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) — testing, CLI headless, JUnit XML
- Steam Direct: USD 100 por App ID, recuperable a los USD 1.000 de revenue bruto ajustado
- [Steering Claude Code](https://claude.com/blog/steering-claude-code-skills-hooks-rules-subagents-and-more) — guía oficial de Anthropic sobre CLAUDE.md, rules, skills, subagents y hooks
