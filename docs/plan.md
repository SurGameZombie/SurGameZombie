# Plan de proyecto — Zombie survival co-op

**Contexto:** dos personas, saben programar, cero experiencia en gamedev. Co-op 2-4 jugadores, uno hostea. Hobby sin plazo. Referencia visual/tonal: SurrounDead. Herramienta principal: Claude Code.

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

### Modelo: listen server con autoridad total del host

Un jugador corre el juego **y** la lógica de servidor en el mismo proceso. Los otros 1-3 se conectan como clientes.

**La regla que define todo el proyecto, desde el commit 1:**

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
| **ENetMultiplayerPeer** (built-in) | $0, cero deps | Conexión directa por IP. Anda en LAN sin configurar nada. Por internet el host tiene que abrir puerto en el router | v0.1 → v0.5. Para testear entre ustedes dos |
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
Un mapa chico hecho a mano (una manzana, no un mundo abierto). Character controller en primera persona. Host + 1 cliente conectados por IP en LAN, viéndose moverse en tiempo real. Sin zombies, sin items, sin nada.
*Por qué primero:* prueba el esqueleto de red. Si esto no funciona limpio, nada de lo demás importa. Y si sale mal, descubrirlo acá cuesta un día, no tres meses.

**v0.2 — "Mata"**
Un tipo de zombie. NavMesh para que persiga. Ataque cuerpo a cuerpo. Vida del jugador, muerte, respawn. Todo el daño resuelto en el host.

**v0.3 — "Se lootea"**
Inventario replicado. ~10 items. Contenedores registrables (armarios, autos). Pickup y drop sincronizados.
*Acá entra el addon de inventario de expressobits* — está hecho en C++ (GDExtension), es modular, separa la lógica de la UI, y ya es multiplayer-friendly. Ahorra semanas.

**v0.4 — "Duele"**
Hambre y sed drenando con el tiempo. Comida y agua como items consumibles. Muerte por inanición. Stamina que se consume corriendo.

**v0.5 — "Es un juego"**
Un arma melee + un arma de fuego con munición escasa. Sistema de spawn/densidad de zombies. Ciclo día/noche. Guardado del estado del mundo en el host.

**v1.0 — "Se juega con amigos"**
Conectividad sin port forwarding (noray). Flujo de lobby: crear partida / unirse. Menús básicos. Sonido. Un mapa lo suficientemente grande para una sesión de 30-60 minutos.

Cada milestone se juega de punta a punta antes de pasar al siguiente. Si en v0.3 el inventario no es divertido de usar, no sigas a v0.4.

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

---

## 5. Organización del proyecto para Claude Code

Esta es la parte que más rendimiento te va a dar y la que más gente se saltea.

### Estructura de carpetas

Organizada **por sistema, no por tipo de archivo**. Claude Code trabaja mucho mejor cuando todo lo de "inventario" está en una carpeta.

```
proyecto/
├── CLAUDE.md                  # contexto siempre cargado (< 200 líneas)
├── .claude/
│   ├── rules/                 # constraints path-scoped
│   ├── skills/                # procedimientos repetibles
│   └── settings.json          # hooks
├── docs/
│   ├── design.md              # el GDD corto, una página
│   ├── netcode.md             # reglas de autoridad y replicación
│   └── decisions/             # ADRs: por qué se eligió cada cosa
├── project.godot
├── addons/                    # plugins de terceros — no tocar
├── scenes/
│   ├── main/                  # menú, lobby, mundo
│   ├── player/
│   ├── enemies/
│   └── items/
├── scripts/
│   ├── net/                   # NetworkManager, autoridad, RPCs
│   ├── survival/              # hambre, sed, stamina
│   ├── inventory/
│   ├── combat/
│   └── world/                 # spawns, día/noche, loot
├── resources/                 # .tres: definiciones de items, loot tables
├── assets/                    # .glb, texturas, audio
└── tests/                     # GUT o gdUnit4
```

### Datos como Resources (`.tres`), no hardcodeados

Items, tipos de zombie, loot tables: todo como archivos `.tres`. Son texto plano. Esto significa que le podés pedir a Claude Code "generá 30 items de comida balanceados según esta tabla" y te crea 30 archivos que vos revisás en un diff de git.

Este es probablemente el mayor multiplicador de productividad del proyecto entero. Si hardcodeás los items en GDScript, perdés esto.

### Cómo repartir las instrucciones (según la guía oficial de Anthropic)

Hay siete formas de instruir a Claude Code y cada una tiene un costo de contexto y una autoridad distinta. Las cuatro que importan acá:

**`CLAUDE.md` en la raíz** — se carga al inicio de sesión y se queda toda la sesión. Va lo que Claude tiene que saber *siempre*: comandos de build y run, layout de directorios, convenciones de código, la regla de static typing, qué addons se usan y dónde está su documentación. Anthropic recomienda mantenerlo **bajo 200 líneas** y tratarlo como un índice que apunta a otros archivos, no como un volcado. Cada línea cuesta tokens en cada sesión, sea relevante o no.

**Rules path-scoped en `.claude/rules/`** — constraints que solo aplican a ciertas carpetas. Ejemplo concreto para este proyecto:

```yaml
---
paths:
  - "scripts/net/**"
  - "scripts/combat/**"
---
Todo cambio de estado se resuelve en el host. Los clientes solo mandan input
vía @rpc("any_peer", "call_local", "reliable"). Nunca modificar salud,
inventario o posición de otro peer desde un cliente.
```

Una regla scopeada a `scripts/net/**` no ocupa contexto cuando estás trabajando en la UI.

**Skills en `.claude/skills/`** — procedimientos repetibles. Solo se carga el nombre y la descripción al inicio; el cuerpo se carga cuando se invoca. Candidatos obvios: "agregar un item nuevo", "agregar un tipo de zombie", "correr el test de dos instancias". Anthropic es explícito: un procedimiento de 30 líneas va en un skill, no en `CLAUDE.md`.

**Hooks en `settings.json`** — para lo que tiene que pasar **determinísticamente**. Correr el linter después de cada edición, correr los tests antes de un commit. La diferencia clave: que el modelo *decida* correr el formatter no es lo mismo que el formatter *corriendo automáticamente*. Un `PreToolUse` hook puede inspeccionar cualquier llamada y bloquearla con exit code 2.

Regla mental: si escribís "siempre que X, hacé Y" en `CLAUDE.md`, probablemente debería ser un hook. Si escribís "nunca hagas X", debería ser un hook o un permiso, porque una instrucción en prosa falla bajo presión en sesiones largas.

### Cerrar el loop de verificación

Este es el punto crítico. Por default, **Claude Code edita archivos pero no puede apretar play y leer el error de runtime** — te entrega código y vos encontrás el bug. Dos cosas cierran ese loop:

**a) Tests headless con GUT o gdUnit4.** Los dos corren desde línea de comandos con `godot --headless`, y gdUnit4 genera reportes JUnit XML/HTML e integra con GitHub Actions (soporta hasta 4.7.x). Claude Code corre los tests y lee pass/fail estructurado.

Qué testear: **la lógica pura**, no el rendering. Matemática de inventario (stacking, capacidad, split), decay de hambre, cálculo de daño, loot tables, serialización del save. Eso es donde viven los bugs sutiles y es donde los tests pagan.

**b) Un MCP server de Godot** para que Claude Code vea el scene tree en vivo, lea el output del debugger, corra el proyecto y saque screenshots, en vez de adivinar node paths. Opciones activas: [GDAI MCP Plugin](https://github.com/3ddelano/gdai-mcp-plugin-godot), [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp), [alexmeckes/godot-mcp](https://github.com/alexmeckes/godot-mcp). Ver el scene tree real es, según la gente que lo usa, el salto de calidad más grande.

### Git

- **`.gitignore` de Godot:** ignorar `.godot/` (caché de import — se regenera), `*.tmp`, y los export presets con credenciales.
- **Git LFS:** *no* desde el día 1. Con assets low poly y dos personas, el repo tarda en crecer. Metelo cuando pase ~200 MB. Ojo con el límite gratis de GitHub: 1 GB de storage y 1 GB de bandwidth mensual.
- **Commits chicos, uno por feature.** No porque sea buena práctica en abstracto, sino porque cuando Claude Code rompe algo querés poder revertir 20 líneas y no un día de trabajo.

### Trabajar de a dos

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
