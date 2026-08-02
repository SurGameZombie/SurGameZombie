# Investigación: trabajar con Claude Code en Godot

Hallazgos verificados de estudios, postmortems y devs que shippearon. Está acá para que
las reglas del proyecto tengan una razón detrás y no se relajen por conveniencia.

---

## Los modos de falla documentados

**Version drift.** Los modelos vieron mucho código de Godot 3. El error obvio
(`KinematicBody`) lo marca el editor. El peligroso es el que compila y no hace nada:
`button.connect("pressed", self, "_on_pressed")` es sintaxis válida que en Godot 4 no
conecta nada porque cambió la firma. Poner la versión explícita en el prompt corta esta
contaminación aproximadamente a la mitad — es la única medida con efecto cuantificado.

**Ceguera de runtime.** Claude Code edita archivos pero no puede apretar play. En Godot
casi todos los bugs aparecen en runtime, así que este es el techo estructural. Un dev
que armó un pipeline entero lo resumió: el código compila bien, pero los assets flotan,
los caminos no llevan a ningún lado y los layouts son basura.

**"Los tests pasan y el juego es injugable."** Caso documentado: el agente cambiaba
algo, corría los tests, veía verde, commiteaba y seguía. El juego hacía cero daño en 60
segundos, con subidas de nivel cada 3,9 segundos donde el rango divertido es 10-30. Los
tests miden corrección, no diversión.

**Sobreingeniería incremental.** Una dev que hizo un match-3 en Godot: *"cada vez que
pedía un ajuste menor, el resultado era sobrecomplicado."*

**Diseño de niveles.** Es la frontera no resuelta. Un dev intentando un RPG reportó que
Claude lo admitió solo: podía hacer el área funcional y fea, o copiar una demo existente
sin tener idea de qué era cada cosa. Layout espacial y composición visual los hacemos
nosotros.

**Colapso de contexto.** Los refactors largos se degradan a los ~40 minutos: pierde el
track de qué archivos ya editó. Los repos de juegos cruzan un punto de quiebre alrededor
de las 30.000 líneas donde grep devuelve miles de falsos positivos.

**Pérdida de contacto con el código.** Un dev abandonó su RTS en Godot con un prototipo
funcionando a las ocho horas, porque no podía arreglar nada por su cuenta. Este es el
riesgo principal de este proyecto.

---

## Los 10 pitfalls de GDScript a revisar en cada diff

De un analizador estático escrito específicamente para GDScript generado por IA:

1. API de Godot 3 usada en Godot 4
2. Scripts gigantes
3. `:=` sobre un `Variant`
4. Acoplamiento fuerte entre nodos
5. Re-entrancia de señales
6. Mal uso de autoloads
7. Señales que no se desconectan
8. Timing de `_init()`
9. Python-ismos que no compilan
10. `static func` en un autoload

Dos misses recurrentes de Claude en particular: meter generación procedural en `_ready()`
sin `await` (conoce `WorkerThreadPool`, pero en prompts cortos lo saltea), y mezclar
nombres de clases de C# con sintaxis de GDScript en proyectos mixtos.

---

## Los números

| Estudio | Resultado |
|---|---|
| **CMU**, 807 repos con IA vs 1.380 de control | Velocidad: +281% líneas el mes 1, +48% el mes 2, **~0% el mes 3**. Complejidad: **+41% permanente.** Warnings de análisis estático: +30%, también permanentes |
| **METR**, 16 devs experimentados, 246 tareas | **19% más lentos** con IA. Se percibieron **24% más rápidos** |
| **Faros AI**, +10.000 devs | +9% bugs, +91% tiempo de code review |
| **Qodo** | Los juniors: menor mejora de calidad (51,9%), **mayor confianza para shippear sin revisar** (60,2%). Los seniors: mayor beneficio (68,2%), menos propensos a saltear revisión |
| **GitClear**, 211M líneas | En 2024 el código copy-pasteado superó por primera vez al refactorizado |

El dato de Qodo describe el perfil de riesgo de este equipo. Por eso la revisión del
diff no es opcional acá: es lo que compensa el déficit.

El dato de CMU implica algo operativo: **si al tercer mes sentimos que avanzamos menos
que al principio, no es impresión, es el patrón medido.** La contramedida es
refactorizar a propósito, no acelerar.

---

## Lo que funciona

**El acceso importa más que el modelo.** Un modelo más flojo cableado al editor, capaz
de correr el juego y leer errores reales, le gana a un modelo top hablando a ciegas.

**Scaffolding a mano primero.** El dev que reporta mejores resultados con Claude Code en
Godot arrancó desde un proyecto jugable con bastante estructura escrita a mano, y usa
solo `CLAUDE.md` + plan mode antes de cada cambio.

**Plan mode siempre.** El flujo reportado: digo qué quiero lograr → Claude arma un plan
y una explicación → **cuestiono cualquier suposición que no entienda** → investigo por mi
cuenta las partes nuevas → recién ahí le pido que implemente, o le pido el concepto y lo
implemento yo.

**El testigo independiente.** Un pipeline open source resolvió el sesgo de
autoevaluación con un modelo de visión separado que hace QA viendo *solo* screenshots,
sin acceso al código. Nuestra versión barata: nosotros jugamos, sin mirar el código.

**Prototipar con IA, arquitecturar nosotros.** El muro de complejidad aparece cuando la
IA decide *cómo se conectan los sistemas*, no cuando implementa uno solo.

---

## Godot multiplayer: lo que falta y cuándo va a doler

La recomendación estándar es usar el multiplayer de Godot si el juego tiene sesiones de
2 a 8 jugadores y puede vivir sin client-side prediction. Co-op encaja bien. Estamos del
lado correcto de esa línea.

| Falta | Cuándo duele |
|---|---|
| **Sincronización de datos complejos** | **v0.3.** El `MultiplayerSynchronizer` maneja primitivas y tipos built-in. Para sincronizar un **inventario** hay que encodear y decodear `PackedByteArray` a mano. Unity trae `SyncList`/`SyncDictionary`; Godot no. **No asumir que el Synchronizer lo resuelve solo** |
| NAT traversal | v1.0. Ya está en el plan: noray o Steam |
| Lobby y matchmaking | v1.0. Todo lo que esté encima del transporte es nuestro |
| Client-side prediction | Nunca, si se respeta el modelo de autoridad |
| Escalabilidad (~40 CCU máx) | Nunca. Apuntamos a 4 |

Precedente de producción: *Dome Keeper* (Godot, 6,1M USD en Steam) shippeó multiplayer
online en abril de 2026 sobre decenas de miles de líneas de GDScript existentes.

---

## Reglas operativas que salen de todo esto

1. **Versión de Godot explícita y prominente** en el `CLAUDE.md`, no al pasar.
2. **Los 10 pitfalls** como checklist al revisar cualquier diff de `.gd`.
3. **Cortar la sesión a los 40 minutos** y `/clear` entre features.
4. **Claude Code nunca commitea solo.**
5. **Playtest sin código a la vista**, quince minutos por milestone.
6. **Un solo skill de Godot**, si instalamos alguno. Cinco librerías solapadas es
   contexto desperdiciado y descripciones que compiten entre sí.
7. **Vigilar el mes 3.**
