# Crítica del sistema de trabajo

> **Documento de trabajo de la reestructuración. No es documentación final del proyecto.**
> Segunda mitad de `mapa-metodologia.md`: aquel describe, este juzga. Se absorbe en
> `ESTADO.md` / `PLAN.md` cuando lleguen esas partes, o se borra si deja de hacer falta.

Escrita el **13/8/2026**, contra dos cosas: la documentación oficial de Anthropic, y la
evidencia medible del propio repo. Todo número de acá está medido hoy; los que no pude
medir están marcados.

**No inventé hallazgos para parecer crítico.** La sección 1 es lo que está bien y no hay
que tocar, y va primera a propósito: varias de esas cosas son exactamente lo que la doc
oficial recomienda y son fáciles de romper "mejorando".

---

## 0. Criterios y de dónde salen

### Fuentes oficiales de Anthropic

| # | Fuente | Qué aporta |
|---|---|---|
| **A1** | [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) | El contexto como recurso finito; *context rot*; "encontrá el conjunto más chico de tokens de alta señal"; memoria externa estructurada; subagentes que devuelven resumen |
| **A2** | [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices) | "Dale a Claude una forma de verificar su trabajo"; **"que muestre evidencia en vez de afirmar éxito"**; los cinco patrones de falla, incluido *the over-specified CLAUDE.md*; revisión adversarial en subagente fresco |
| **A3** | [How Claude remembers your project](https://code.claude.com/docs/en/memory) | "target under 200 lines per CLAUDE.md"; reglas sin `paths` cargan al arranque con la misma prioridad que CLAUDE.md; consistencia entre reglas; auto memory **machine-local**; `autoMemoryDirectory`; hook `InstructionsLoaded` |
| **A4** | [Explore the context window](https://code.claude.com/docs/en/context-window) | **Qué sobrevive a la compactación**: reglas sin scope se re-inyectan, reglas con `paths:` se pierden; skills re-inyectados con tope de 5.000 tokens y truncados desde el final |
| **A5** | [Extend Claude Code](https://code.claude.com/docs/en/features-overview) | La tabla CLAUDE.md vs rules vs skills vs hooks; "usá rules para mantener CLAUDE.md enfocado… **ahorrando contexto**"; **"Put guardrails in hooks"** |
| **A6** | [Hooks reference](https://code.claude.com/docs/en/hooks) | Los ~30 eventos, cuáles bloquean, semántica de exit 2, el campo `if` con sintaxis de reglas de permiso |
| **A7** | [Configure permissions](https://code.claude.com/docs/en/permissions) | **"deny, then ask, then allow… rule specificity doesn't change the order"**; "una regla `ask` prompta aunque una `allow` más específica machee"; "las reglas las hace cumplir Claude Code, **no el modelo**" |
| **A8** | [Steering Claude Code](https://claude.com/blog/steering-claude-code-skills-hooks-rules-subagents-and-more) | Ya citado en `plan.md` §8. **"Unscoped: load at session start like CLAUDE.md; re-inject on compaction"**; errores comunes: instrucciones repetidas, procedimientos en CLAUDE.md, y **"cuando algo absolutamente no debe pasar, una instrucción es la herramienta equivocada"** |

### Terceros

| # | Fuente | Qué aporta |
|---|---|---|
| **T1** | [Context Rot: Why Claude Code Sessions Decay](https://towardsdatascience.com/governed-context-managing-context-rot-in-claude-code/) · [How to Prevent CLAUDE.md Bloat](https://docs.bswen.com/blog/2026-04-23-prevent-claudemd-bloat/) | El benchmark de Chroma 2025: los 18 modelos frontier probados pierden exactitud a medida que crece el input, algunos de 95% a 60%; efecto *lost in the middle* con caídas de más del 30% |
| **T2** | [I gave Claude Code a 200-line CLAUDE.md, and it was the worst decision I made](https://www.xda-developers.com/gave-claude-code-200-line-claudemd-worst-decision-made/) · [CLAUDE.md Best Practices 2026](https://dev.to/nishilbhave/claudemd-best-practices-the-complete-2026-guide-435j) | Postura más dura que la oficial: 40–60 líneas en la raíz y todo lo demás a skills |
| **T3** | [Claude Code Hooks: 6 Production Patterns](https://www.pixelmojo.io/blogs/claude-code-hooks-production-quality-ci-cd-patterns) · [Production Playbook](https://www.totalum.app/blog/claude-code-hooks-totalum) | "Un hook es una garantía: una instrucción el modelo la puede olvidar en el turno siguiente"; `PostToolUse` **no puede deshacer** lo que ya corrió; el `Stop` hook necesita guarda anti-loop |
| **T4** | [Preventing Agents from Declaring Victory Too Early](https://walkinglabs.github.io/learn-harness-engineering/en/lectures/lecture-09-why-agents-declare-victory-too-early/) · [Fresh-context verifier](https://yowox.com/posts/claude-code-fresh-context-verifier/) | Un modelo que evalúa su propia salida es indulgente: ya racionalizó sus decisiones. **El verificador no debe recibir un resumen halagüeño, debe recibir evidencia** |
| **T5** | [Process documentation trends 2026](https://gethaiku.ai/blog/process-documentation-trends-2026) | El *workflow drift* como falla clásica: "el equipo que actualizó staging el lunes rara vez actualizó el runbook el martes" |
| **T6** | [Claude Code Reddit: What Developers Actually Say](https://www.morphllm.com/claude-code-reddit) | Tool Search bajó el costo de contexto de MCP un 46,9% (51K → 8,5K tokens) al diferir los esquemas |

**Nota de honestidad sobre el método.** Intenté medir empíricamente el hallazgo H1
—instalar un hook `InstructionsLoaded` en un settings temporal y arrancar una sesión
headless para ver con qué motivo cargan las tres rules— y **el clasificador de permisos
bloqueó la escritura del script**. Así que H1 se apoya en A4 y A8, que son explícitos, más
lo que sí pude observar en esta sesión. Queda marcado como no verificado en el repo, con
el método escrito para que alguien lo corra.

---

## 1. Lo que está bien y no hay que tocar

Esto no es cortesía. Son seis cosas que coinciden con la recomendación oficial y que un
refactor apurado rompe sin darse cuenta.

**1.1 Los dos hooks existen y hacen exactamente lo que la doc dice que hagan.** A5 es
categórico: *"Put guardrails in hooks. An instruction like 'never edit .env' in CLAUDE.md
or a skill is a request, not a guarantee."* `consistencia.sh` convirtió una regla en prosa
en una ejecución, que es el consejo titular de A2 ("dale a Claude una forma de verificar su
trabajo"). **La mayoría de los proyectos hobby no llegan nunca a esto.**

**1.2 `navmesh-recordatorio.sh` recuerda en vez de hornear, y está bien decidido.** T3
advierte que `PostToolUse` no puede deshacer lo que ya corrió; hornear ahí reescribiría un
archivo versionado como efecto colateral. El script explica esa decisión en su propio
encabezado. **No convertirlo en un hook que hornee.**

**1.3 El control negativo obligatorio de `barrido-navmesh`.** Es la aplicación literal de
T4 —el que hace el trabajo no puede ser el que lo califica— a un banco de medición, y el
skill registra que agarró errores las tres veces que se corrió. Y hay un detalle que sale
bien por accidente feliz: A4 dice que al re-inyectar un skill tras compactar, **el truncado
conserva el principio del archivo**. La regla 2 ("control negativo obligatorio, siempre")
está en la línea 32 de 191. Si alguien reordena el SKILL.md y la manda al final, se pierde
justo esa. **No reordenarlo.**

**1.4 `consistencia_test.gd` trata el ancla perdida como falla, no como salto.** Es la
contramedida directa al falso verde, y T5 describe el *workflow drift* como la falla
clásica de las bibliotecas de documentación de proceso. Este repo construyó un detector de
drift, que es más de lo que hace casi nadie.

**1.5 Las 15 reglas `deny` del catálogo están bien escritas, y es fácil "arreglarlas" mal.**
Dos cosas que A7 confirma y que conviene dejar anotadas:

- *"`Edit` rules apply to all built-in tools that edit files"*, y **"si escribís una regla
  de path para `Write`… Claude Code la acepta pero nunca la consulta"**. O sea que
  `Edit(...)` es la forma correcta y `Write(...)` la rompería en silencio.
- En Windows los paths se normalizan a POSIX antes de matchear, así que
  `//c/ClaudeMCPsPlugingsSkillsETC/**` es la forma correcta de un absoluto.

Además, A7 dice que *"una regla deny no puede llevar excepciones de allowlist"*. O sea que
**enumerar las doce carpetas prohibidas es la única forma de dejar `proyectos/surgamezombie/`
escribible.** El diseño actual no es torpe: es el único que existe.

**1.6 `.mcp.json` en git y `godot-ai` afuera, con el porqué escrito.** La razón registrada
—rutas absolutas del home— es correcta y la simetría entre máquinas se resuelve por otro
lado (el plugin commiteado). Es la decisión que A5 respalda.

Y una que no es de la doc sino del propio proyecto: **marcar cada afirmación como
verificado / inferido / suposición.** T4 dice que el verificador tiene que recibir
evidencia y no un resumen halagüeño; ese hábito es la versión escrita de eso. Está en
`limites.md`, en la retrospectiva y en el mapa. Vale mantenerlo.

---

## 2. Hallazgos

Ordenados por consecuencia × qué tan barato es arreglarlos.

---

### H1. Las tres rules "de scope global" tienen `paths:`, y por eso probablemente no sobrevivan a un `/compact`

**Severidad: alta. Costo de arreglo: borrar 4 líneas × 3 archivos.**

`commits.md`, `limites.md` y `herramientas.md` declaran `paths: ["**"]`. A4 tiene una tabla
explícita de qué sobrevive a la compactación:

| | |
|---|---|
| Project-root CLAUDE.md **y reglas sin scope** | Re-inyectadas desde disco |
| **Reglas con frontmatter `paths:`** | **Perdidas hasta que se vuelva a leer un archivo que machee** |

Y la recomendación textual: *"If a rule must persist across compaction, **drop the `paths:`
frontmatter**"*. A8 dice lo mismo desde el otro lado: *"Unscoped: load at session start like
CLAUDE.md; **re-inject on compaction**"*.

**Por qué importa acá y no en abstracto:** la regla que se pierde es la que dice *"Claude
Code no commitea por iniciativa propia"*. Y el momento en que se compacta es, por
definición, **la sesión larga** — exactamente la que `investigacion-claude-code.md` describe
como aquella donde se pierde el hilo. La regla de mayor consecuencia del repo está en el
archivo con más chances de evaporarse justo cuando más hace falta.

**Además, `paths: ["**"]` no compra nada.** A5 explica para qué existe el scope: *"Rules
with `paths` frontmatter only load when Claude works with matching files, **saving
context**"*. Un glob que machea todo no ahorra un solo token; solo cambia el bucket de
compactación.

**Medido en esta sesión:** las tres cargan al arranque, antes de cualquier lectura de
archivo — o sea que a la carga se comportan como si no tuvieran scope. **No verificado:**
qué pasa después de compactar, porque en esta sesión no hubo compactación y el probe quedó
bloqueado. Como el arreglo cuesta 12 líneas y no tiene contrapartida —a la carga son
equivalentes—, no hace falta esperar la verificación para hacerlo.

**Cómo verificarlo si igual se quiere:** A3 documenta el hook `InstructionsLoaded`, cuyo
matcher acepta el motivo de carga (`session_start`, `path_glob_match`, `compact`). Un hook
de dos líneas que loguee el motivo contesta la pregunta en una sesión.

> **Aplicado el 13/8/2026.** El frontmatter se sacó de los tres archivos. La prosa
> residente baja de 444 a **429 líneas** medidas, así que todas las cifras de 444 que
> aparecen más abajo —H10 y la sección 3— son de antes del arreglo y quedan como estaban:
> el argumento no cambia, el número sí. **Sigue sin verificarse** el comportamiento después
> de un `/compact`, que es la premisa de todo esto.

---

### H2. "Claude Code no commitea por iniciativa propia" es prosa, y el permiso dice que sí puede

**Severidad: alta. Costo: 2 líneas de JSON.**

Es la decisión abierta n.º 2 de `permisos-curados.md`, y el doc de la curación ya la
describe bien: *"no contradice `.claude/rules/commits.md` —esa regla es de comportamiento y
la sigo igual—, pero el permiso saca el prompt del sistema, que era la última red si la
regla fallara."*

Lo que agrega la doc oficial es que **la solución es de una línea y ya existe**, y que el
diagnóstico es más duro de lo que el doc de la curación asume:

- A7: *"Rules are evaluated in order: deny, then ask, then allow. The first match in that
  order determines the outcome, and **rule specificity doesn't change the order**… The same
  precedence applies between ask and allow: **a matching ask rule prompts even when a more
  specific allow rule also matches the same call**."*
- A7, más directo: *"**Permission rules are enforced by Claude Code, not by the model.**
  Instructions in your prompt or `CLAUDE.md` shape what Claude tries to do, but they don't
  change what Claude Code allows."*
- A8 lo pone como error común: *"When there's something that absolutely must not happen, an
  instruction is the wrong tool."*

O sea: **agregar `ask` no obliga a sacar los `allow`.** `PowerShell(git *)` puede quedarse
tal cual; una regla `ask` sobre `git commit` y `git push` gana igual.

**El agravante que el chat de criterio ya vio, y que confirmo:** si en la laptop eso ya se
cerró con una regla `ask` y en esta máquina no, **las dos máquinas tienen hoy dos
comportamientos de seguridad distintos**, y el archivo donde se arregló —
`settings.local.json`— es justamente el que **no viaja** (`.gitignore:28`). El mecanismo que
haría simétrico el arreglo existe y no se está usando: `.claude/settings.json`, que sí
viaja y que ya define los hooks "para los dos".

---

### H3. El formato de respuesta de tres partes no exige evidencia, y CLAUDE.md además la prohíbe

**Severidad: alta. Costo: 3 líneas en CLAUDE.md, más resolver una contradicción.**

A2 lo dice casi con las palabras del pedido: *"**Have Claude show evidence rather than
asserting success: the test output, the command it ran and what it returned**, or a
screenshot of the result. Reviewing evidence is faster than re-running the verification
yourself."* T4 agrega el porqué: un modelo que evalúa su propia salida es indulgente porque
ya racionalizó sus decisiones, y el verificador tiene que recibir evidencia, no un resumen.

Coincido con que corresponde ajustarlo. Pero hay algo más grande que un ajuste, y es lo que
hace que este hallazgo no sea cosmético:

**CLAUDE.md hoy contiene una regla que prohíbe exactamente lo que la evidencia requiere.**
En "Qué no escribir nunca":

> *"Lo que verificaste y salió bien. Si compila y los tests pasan, no lo menciones."*

Y en "La regla que resume todo":

> *"Si algo lo podés resolver o verificar vos, resolvelo y no lo cuentes."*

Las dos son buenas reglas contra el relleno. Pero conviven mal con "todo número va con el
comando que lo produjo", y A3 advierte justo sobre eso: *"**Consistency**: if two rules
contradict each other, Claude may pick one arbitrarily."* Un error de conteo que pasa el
filtro del formato no es sorprendente: **el formato está optimizado para no reportar
verificaciones exitosas, que es donde viven los conteos.**

La salida no es borrar la regla de brevedad. Es partir el caso: *no contar el proceso*
sigue valiendo; *toda afirmación numérica lleva el comando* es una excepción explícita.
Dicho de otro modo: la brevedad se aplica a la narración, no a la evidencia.

---

### H4. La duplicación `commits.md` ↔ `proceso.md` no está fichada, y ya divergió

**Severidad: media-alta. Costo: borrar ~12 líneas y agregar una ficha.**

Coincido con el chat de criterio, y puedo agregar el dato que convierte el par latente en
un par roto. **Medido hoy:** los dos archivos traen el mismo bloque de código con el formato
del mensaje, y **la copia de `docs/proceso.md` no tiene la línea de `Tested-later:`**:

| | `.claude/rules/commits.md` | `docs/proceso.md` §1 |
|---|---|---|
| `Rejected:` en el bloque de formato | ✔ | ✔ |
| `Directive:` | ✔ | ✔ |
| `Tested:` | ✔ | ✔ |
| `Not-tested:` | ✔ | ✔ |
| **`Tested-later:`** | ✔ | **✘** |
| Lista de tipos | ✔ | ✔ (con glosa) |
| Lista de scopes | ✔ | ✔ (idéntica) |

El trailer más nuevo del proyecto existe en una copia y no en la otra, **dos días después de
haberse creado.** `proceso.md` lo menciona dos veces en prosa, pero el bloque canónico —el
que alguien copia cuando escribe un commit— quedó viejo. Es el par E de manual: A8 lista
*"Repeated instructions: avoid duplicating content across CLAUDE.md, rules, and skills"*
entre los errores comunes.

Que no esté en `inventario-pares.md` es coherente con cómo se armó ese inventario —salió de
barrer los 109 archivos versionados buscando *datos* duplicados, no bloques de prosa
idénticos— pero la familia E existe justamente para esto y tiene cuatro entradas. Esta sería
la quinta, y es la única de la familia con divergencia **ya materializada**, o sea 💥.

**El molde para arreglarlo ya está definido en el propio repo** y funcionó una vez:
`b1a6ec5` dejó la regla del "no commitea solo" entera en un lugar y punteros en los otros
dos. Es el mismo movimiento.

---

### H5. `Tested-later:` no escala como está, y el problema no es la disciplina del trailer

**Severidad: media-alta. Costo: un script de 10 líneas + una pasada de reconciliación.**

Coincido con el diagnóstico. Los números, medidos hoy:

| Dato | Valor |
|---|---|
| Commits con `Not-tested:` | **50** |
| Commits con `Tested-later:` | **2** (uno de ellos es el que inventó el trailer) |
| Hashes distintos citados | **1** (`2d417f5`), y el propio trailer aclara que paga **parte** |
| `Not-tested:` escritos **antes** de que el trailer existiera (11/8) | **40** |
| `Not-tested:` que abren con la forma "no hay nada que testear" | **5** |

Tres cosas que salen de ahí y que cambian el diagnóstico:

**a) El trailer nació sin retroactividad, y eso es estructural.** 40 de los 50 son
anteriores a su invención. La regla dice —con razón— que *"el commit viejo no se toca…
reescribir el historial invalida los hashes que lo citan"*. Así que esos 40 **solo se pueden
saldar hacia adelante**, con un commit nuevo que los cite. Nada los va a citar solo.

**b) El ejemplo más claro del problema es el cierre de v0.2.** El commit `b3964c3` —el que
registra el playtest de quince minutos, o sea el evento que más deuda cerró en la vida del
proyecto— lleva:

```
Not-tested: nada que testear, es prosa
```

Es literalmente la forma que la regla prohibió después, textual: *"Nada de `Not-tested: nada
que testear, es prosa` ni sus variantes: eso mete ruido en la única señal mecánica de deuda
que tiene el proyecto, y ya se coló varias veces."* O sea que el commit que pagó deuda **la
sumó** en el contador. La regla se escribió por casos como este y no puede corregirlos.

**c) Por lo tanto, `git log --grep="Not-tested" | wc -l` = 50 no es la deuda.** Sobreestima
por al menos 5 (ruido) más todo lo que el playtest del 6/8 cerró sin citarse. Y subestima
nada. Es un número que nadie puede usar para decidir.

**Lo que falta no es más disciplina, es que la consulta sea un comando.** La retrospectiva
§5.4 ya propuso el destino ("la deuda se muda a `bitacora.md` como lista viva") y no se
hizo — y hoy `inventario-pares.md` F2 registra que **hay tres listas parciales de lo mismo**.
Un skill que compute `Not-tested` menos `Tested-later` es un pipeline de shell y hace la
pregunta contestable en un tecleo. A5 pone justo ese gatillo: *"You keep typing the same
prompt to start a task → save it as a user-invocable skill."*

---

### H6. La memoria no viaja entre máquinas, y hoy es el único artefacto de aprendizaje que no viaja

**Severidad: media. Costo: 1 línea de settings por máquina.**

A3 lo confirma textual: *"Auto memory is machine-local. All worktrees and subdirectories
within the same git repository share one auto memory directory. **Files are not shared
across machines or cloud environments.**"*

**Qué se pierde, medido:** 4 memos de 27 a 30 líneas cada uno, más el índice. Los cuatro son
correcciones de método —cómo atribuir inferencias vs. decisiones, parar ante avisos del
sistema, qué se pagó de la deuda de red, el cierre de la Parte 1—. Ninguno es específico de
la PC. En la laptop no existe ninguno: **la misma corrección hay que darla dos veces**, y
`JoaquinLaptop` tiene 16 de los 73 commits, así que no es un caso raro.

Es además la excepción a un patrón que el resto del setup cumple bien: CLAUDE.md, rules,
skill, hooks, tests y docs viajan todos. A1 llama a esto *structured note-taking* y lo pone
como la técnica que permite coherencia a través de los pasos de resumen; tenerla partida por
máquina anula la mitad del beneficio.

**Hay una palanca directa.** A3 documenta `autoMemoryDirectory`, leíble desde cualquier
scope de settings, con dos condiciones: valor absoluto o `~/`, y —si se define en settings
de proyecto— *"honored only after you accept the workspace trust dialog"*, que este proyecto
ya aceptó (`hasTrustDialogAccepted: true`, medido).

Dos formas, con distinta contrapartida:

| Forma | Ventaja | Contrapartida |
|---|---|---|
| `autoMemoryDirectory` en **`.claude/settings.json`** (viaja) | Una sola edición, las dos máquinas quedan iguales | Hardcodea `C:\Proyectos\SurGameZombie` en un archivo compartido — **es exactamente el par D4** del inventario, que ya está roto por diseño para Mathi |
| `autoMemoryDirectory` en **`settings.local.json`** de cada máquina (no viaja) | No agrega una copia más de la ruta absoluta al repo | Hay que hacerlo dos veces, y una máquina nueva arranca sin él |

Recomiendo la segunda, y que apunte a una carpeta **dentro del repo** (`.claude/memory/`):
la config no viaja pero **el contenido sí**, que es lo que interesa. Con un efecto
secundario que a este proyecto le viene bien: la memoria pasa a verse en el diff, que es
donde este equipo revisa todo.

**La contrapartida honesta:** hoy yo escribo esos archivos en medio de la sesión, sin pasar
por el gate del commit. Moverlos al repo significa que voy a modificar archivos versionados
sin que nadie lo pida. Aparecen en `git status`, así que no se cuelan; pero es un cambio de
régimen y lo decide Joaco, no yo.

---

### H7. Los hooks no cubren el lado "doc" de los pares que el test compara

**Severidad: media. Costo: dos patrones más en un `case`, o un campo `if`.**

Ya está descrito en el mapa §2.3, pero como crítica es más filoso de lo que parece:

`consistencia_test.gd` compara `docs/design.md` ↔ código y `SKILL.md` ↔ `yard.tscn`. El hook
que corre ese test se dispara con `*/scripts/*.gd`, `*/resources/*.tres`, `*/scenes/*.tscn` y
`*/project.godot`. **Ninguno de los dos lados "doc" de esos pares dispara nada.** O sea que
el comparador cubre la dirección código→doc y no la dirección doc→código, y el commit
`aaefd2a` existe justamente porque un comentario contradecía a `design.md`.

Es asimetría, no rotura, y hay una razón obvia para el recorte —correr Godot en cada edición
de un `.md` es caro—. Pero el costo real está medido: **3.134 ms**. Sobre una edición de doc,
eso es ruido.

**Y hay una forma más limpia que ampliar el `case`.** A6 documenta el campo `if` en la
config del hook, que usa sintaxis de reglas de permiso y machea nombre de tool y argumentos
juntos: `"if": "Edit(docs/design.md)"`. Eso deja el filtrado en la config —donde se lee— en
vez de en un `case` de shell que hay que abrir para entender.

---

### H8. Reglas que existen y no se cumplen

**Severidad: baja cada una, media como conjunto. Son la evidencia de que la prosa se
erosiona sin mecanismo.**

Medido sobre los 73 commits y sobre el repo:

| Regla | Dónde | Cumplimiento medido |
|---|---|---|
| `tipo(scope): …` en la primera línea | `commits.md`, `proceso.md` | **70 de 73 (96%)**. Las tres excepciones: `fdddeac` (commit inicial, de la web), `b4d09ce` "agregado archivos de iformacion" (2/8), y **`a134c5e` "Conecta el proyecto al catalogo de herramientas Claude" (12/8, el anteúltimo commit del repo)** |
| Scopes permitidos: `net·player·enemy·inventory·survival·world·ui` | ídem | **4 scopes en uso que no están declarados**: `deps` (×2), `tooling`, `design`, `chore`. Y **`survival` nunca se usó** |
| Playtest de 15 min por milestone | `investigacion-claude-code.md` regla 5, `bitacora.md` | Se cumplió una vez (v0.2, 6/8). v0.3 pendiente |
| Cortar la sesión a los 40 min | `investigacion-claude-code.md` regla 3 | Nada lo dispara; la retrospectiva §2.10 ya lo registró y sigue igual |
| Sacar los andamios de debug | retrospectiva §3.4 | **`debug_enabled = true` sigue en `zombie.tscn:55`** ocho días después de ficharse. Y `project.godot` tiene **4** acciones `debug_*` contra las 2 que lista la retrospectiva — es el par F1, ya divergido |

**Lo que dice el conjunto:** el formato del subject se cumple 96%, o sea que la regla
funciona. Las dos excepciones recientes son las dos veces que el commit **no era de código**
— cuando el trabajo sale del carril, la convención sale con él. Los scopes, en cambio,
derivaron sin que nadie lo notara porque **nadie los mira**: cuatro valores nuevos entraron
por uso.

Esto es exactamente T5 —*el que actualizó staging el lunes rara vez actualizó el runbook el
martes*— y A5 lo prevé: *"You want something to happen every time without asking → write a
hook."* Un `PreToolUse` sobre `Bash(git commit *)` que valide el subject contra la lista de
tipos y scopes es determinístico y cuesta unas 15 líneas. **No lo propongo como prioritario**
—96% no es una crisis— pero es el candidato natural si esto vuelve a resbalar.

---

### H9. Mecanismos que nunca se ejercieron

**Severidad: media. Es el riesgo de creer que algo protege cuando no se sabe.**

| Mecanismo | Estado |
|---|---|
| `consistencia.sh` saliendo con **exit 2** (suite roja) | **Nunca ejercido.** Es el único camino en que el hook hace algo distinto de nada |
| La rama "no encuentro Godot" del mismo hook | Nunca ejercida |
| Las 3 ramas de `return 1` de `bake_navmesh.gd` | Nunca ejercidas (ya en retrospectiva §3.1) |
| `Tested-later:` | 2 usos en 2 días (H5) |
| El inspector de tests de gdUnit4 en el editor | **No está prendido**: `project.godot` `[editor_plugins] enabled` lista solo `godot_ai` (medido). Es el único paso manual que quedó de la instalación del 6/8 |

El primero es el que más importa. **Todo el valor del hook está en el camino rojo**, y ese
camino nunca corrió: si el filtro de `grep -E "FAILED\|ancla perdida\|…"` no machea la
salida real de una corrida roja, el hook bloquea con un mensaje vacío. Es barato de probar:
romper un par a propósito en una copia, correr, mirar, revertir. **El propio proyecto tiene
el hábito** —es el control negativo de `barrido-navmesh`— pero no se lo aplicó al hook.

---

### H10. CLAUDE.md está en 225, pero el número que importa es 444

**Severidad: baja-media. Costo: depende de cuánto se quiera mover.**

`inventario-pares.md` E7 vigila `CLAUDE.md` contra las ~200 líneas. La cifra oficial existe
y es dura: A3 dice *"**Size**: target under 200 lines per CLAUDE.md file. Longer files
consume more context and reduce adherence"*, y A2 lo pone como patrón de falla con nombre
propio —*the over-specified CLAUDE.md*— y remate: *"**Bloated CLAUDE.md files cause Claude to
ignore your actual instructions!**"*. T1 respalda el mecanismo con el benchmark de Chroma
2025: los 18 modelos frontier probados pierden exactitud a medida que crece el input.

**Pero E7 mide el archivo equivocado, o mejor dicho: mide uno de cuatro.** A3 dice que las
reglas sin scope *"are loaded at launch with the same priority as `.claude/CLAUDE.md`"*, y
las tres de scope `**` cargan al arranque igual (medido). Entonces el presupuesto residente
real es:

| | Líneas |
|---|---:|
| `CLAUDE.md` | 225 |
| `.claude/rules/commits.md` | 116 |
| `.claude/rules/herramientas.md` | 57 |
| `.claude/rules/limites.md` | 43 |
| `~/.claude/CLAUDE.md` | 3 |
| **Total residente** | **444** |

225 contra 200 es un 12,5% de exceso: real, menor. **444 de prosa residente es otra
conversación**, y explica por qué mover secciones de `CLAUDE.md` a `.claude/rules/` con
scope `**` bajó el número vigilado sin bajar el costo — que es literalmente lo que dice
`limites.md` en su propio encabezado que se hizo ("se movieron acá para bajarlo de 200
líneas").

**Sobre el control simétrico con el chat de criterio: coincido, con dos correcciones.**

1. **No puedo verificar las 401 líneas.** Ese archivo no está en este repo ni en ninguna
   ruta a la que tenga acceso. Lo tomo como dato del pedido.
2. **Si el control se hace, que mida prosa residente total, no un archivo.** Vigilar
   `CLAUDE.md` solo premia mudar texto a una rule de scope `**`, que no ahorra nada. Del
   lado del chat de criterio la métrica equivalente es todo lo que entra a cada turno.

Y una nota de alcance: `consistencia_test.gd` no puede vigilar el lado del chat de criterio
—lee por `res://`, y ese archivo está fuera del repo—. **Cada lado tiene que vigilar el
suyo**, y por eso la simetría acá es de política, no de mecanismo.

Sobre T2 —la postura de 40–60 líneas en la raíz— **no la suscribo para este proyecto.**
Buena parte de las 225 son el porqué de reglas contraintuitivas (por qué la versión de Godot
va arriba, por qué el input map se parte en dos), y este equipo está aprendiendo: A1 avisa
que *"minimal does not necessarily mean short; you still need to give the agent sufficient
information up front"*. Recortar a 60 acá compraría contexto y pagaría con comprensión, que
es justo el riesgo declarado n.º 1 del proyecto.

---

### H11. La sección de decisiones duplicada del chat de criterio: sí al puntero, no a reordenar las Partes

**Severidad: media. Costo: 35 líneas → 1, si se cumple una condición.**

No puedo leer esa sección, así que juzgo el principio y no el texto.

**El principio está mal, y la doc oficial lo dice sin matices.** A8 lista *"Repeated
instructions: avoid duplicating content across CLAUDE.md, rules, and skills"* entre los
errores comunes, y A3 agrega la consecuencia: *"if two rules contradict each other, Claude
may pick one arbitrarily."*

**Y hay un agravante específico de este caso que lo pone peor que los 53 pares del
inventario.** De esos, **31 están marcados 🔒 —comparables con el molde de
`consistencia_test.gd`—** (medido). Un par cuyo segundo lado vive fuera del repo **no puede
ser 🔒 nunca**: la suite lee con `FileAccess` sobre `res://`. Es un par estructuralmente
incomparable, y por lo tanto peor que los que sí se pueden automatizar.

**Sobre adelantar la Parte 4 por encima de terminar la Parte 3: no coincido, y creo que la
disyuntiva es falsa.** Reemplazar 35 líneas por un puntero **no necesita que `estado.md`
exista**. Hoy puede apuntar a `docs/design.md` → "Escala y números base" y a
`docs/decisions/`, que son la fuente de verdad actual, y re-apuntarse a `estado.md` §7 el
día que exista. Eso convierte la pregunta "¿qué parte va primero?" en "hagamos la mitad
barata ahora", sin tocar el orden.

**La condición que decide todo, y que hay que chequear antes de mover un dedo:** ¿el chat de
criterio **puede leer este repo**? Si corre en otra máquina o sin acceso al filesystem, un
puntero apunta a algo inalcanzable y **es peor que la copia** — la copia al menos es
consultable. En ese caso lo correcto no es un puntero sino un *extracto generado*, con fecha
y con el commit del que salió, para que al menos se pueda fechar la divergencia. No sé cuál
de los dos casos es; es la primera pregunta a contestar.

> **Contestado el 14/8/2026: sí puede.** Clona el repo público con `git clone` en un sandbox
> propio y lee con `grep`, `wc` y `git log` — así verificó esta semana, incluidos los
> reportes de acá. O sea que **el puntero es alcanzable y el extracto fechado no hace
> falta.** La acción queda como estaba en la tabla de la tanda C: ~35 líneas → 1, apuntando
> hoy a `docs/design.md` y `docs/decisions/`, y del lado del chat de criterio. Lo que sigue
> sin cambiar es que yo no puedo leer esa sección: juzgo el principio, no el texto.

---

### H12. La regla de push: coincido en que falta acá, y va en dos registros

**Severidad: media. Costo: 2 líneas de prosa + 1 de JSON.**

Escribí en el mapa §9.3 que no encontré ninguna regla que fije cuándo se pushea, y sigo
sosteniendo la observación: **no está en este repo.** Que exista del otro lado lo confirma
el punto del pedido; yo no la puedo ver, y ese es exactamente el problema.

**Dónde debería vivir**, según la lógica que el propio repo ya usa:

- **La regla, en `.claude/rules/commits.md`.** Es la versión que gobierna el comportamiento
  de commit —así lo declaran `proceso.md` §1 y el propio archivo— y "después de aprobar un
  commit se pregunta si se pushea" es la continuación natural de "el commit es el punto donde
  ellos revisan el diff". Ponerla en `CLAUDE.md` la separaría de su familia.
- **Y como regla `ask`, en `.claude/settings.json`.** Por lo mismo que H2: A7 dice que las
  reglas las hace cumplir Claude Code y no el modelo, y A8 que una instrucción es la
  herramienta equivocada para algo que no debe pasar. Hoy `PowerShell(git *)` cubre
  `git push` sin prompt.

Las dos, no una. La prosa explica; el permiso obliga. Es la misma división que
`proceso.md` §2 ya define entre ADRs y rules, aplicada un piso más abajo.

---

### H13. Dos observaciones menores, sin acción urgente

**a) El `deny` del catálogo es enumerativo.** Cubre las 12 carpetas que existían el 12/8. Si
el agente del catálogo crea una decimotercera, queda escribible desde acá. No es un
descuido: A7 dice que un `deny` no puede llevar excepciones, así que enumerar es la única
forma. Pero **acopla este repo al árbol de carpetas de otro repo**, y eso conviene que esté
escrito donde alguien lo lea. Hoy no lo está.

**b) `docs/` pesa 3.570 líneas sin `decisions/` ni `reestructuracion/`.** No es contexto
—no se carga solo— así que no cuesta tokens. Pero A1 razona sobre *just-in-time retrieval*:
la carga se paga cuando se busca. Con `retrospectiva-v0.2.md` en 1.063 líneas y `bitacora.md`
en 778, "leer `bitacora.md` antes de proponer cambios estructurales" (CLAUDE.md) es una
instrucción cuyo costo crece solo. No propongo recortar: propongo que **la Parte 3 sepa que
ese es el número que está manejando**.

---

## 3. Los ocho puntos del chat de criterio: dónde coincido y dónde no

| # | Punto | Veredicto |
|---|---|---|
| 1 | CLAUDE.md 225 vs 200; control simétrico con las 401 del chat | **Coincido con matiz importante.** El número residente real acá es **444**, no 225: las tres rules de scope `**` cargan al arranque con la misma prioridad (A3). Un control que mire solo `CLAUDE.md` premia mudar texto a una rule que no ahorra nada. Simetría sí, pero midiendo prosa residente total, y **cada lado vigilando la suya** — la suite de acá no puede leer un archivo fuera del repo. Las 401 no las pude verificar |
| 2 | Los 14 ítems duplicados → ¿adelantar la Parte 4? | **Coincido en el problema, no en la conclusión.** La duplicación está mal y es **peor que los pares del inventario**, porque un par con un lado fuera del repo no puede ser 🔒 nunca (31 de los 53 sí lo son). Pero el puntero no necesita `estado.md`: puede apuntar hoy a `design.md` + `decisions/` y re-apuntarse después. **No reordenaría las Partes por esto.** Antes hay que contestar si el chat de criterio puede leer el repo; si no puede, un puntero es peor que la copia |
| 3 | La duplicación `commits.md` ↔ `proceso.md` no está fichada | **Coincido, y es peor de lo dicho: ya divergió.** Medido: el bloque de formato de `proceso.md` **no tiene `Tested-later:`**, dos días después de que el trailer se creara. Es par de familia E con 💥, y el molde para arreglarlo ya lo usó `b1a6ec5` |
| 4 | `git commit` preaprobado; en la laptop ya se cerró con `ask` | **Coincido, sin reservas.** A7: `ask` gana sobre `allow` sin importar especificidad, así que no hay que sacar nada. Y agrego: **las dos máquinas tienen hoy comportamientos de seguridad distintos**, y el arreglo está en el archivo que no viaja. Debería ir a `.claude/settings.json` |
| 5 | La regla de push solo existe del otro lado | **Coincido.** Va en **dos** lugares: la prosa en `.claude/rules/commits.md` (es la versión que gobierna el commit) y un `ask` en `.claude/settings.json`. Hoy `PowerShell(git *)` cubre `push` sin prompt |
| 6 | El formato de tres partes no exige el comando | **Coincido, y hay más.** A2 lo pide casi textual ("show evidence… the command it ran and what it returned"). Pero **CLAUDE.md hoy prohíbe activamente reportar verificaciones exitosas**, que es donde viven los conteos. No alcanza con agregar la regla: hay que resolver la contradicción, o A3 dice que voy a elegir una arbitrariamente |
| 7 | La memoria no sincroniza entre máquinas | **Coincido.** A3 lo confirma textual. Se pierden 4 memos de método, ninguno específico de máquina, y `JoaquinLaptop` tiene 16 de 73 commits. Hay palanca directa: `autoMemoryDirectory` apuntando adentro del repo, mejor desde `settings.local.json` de cada máquina para no sumar otra copia de la ruta absoluta (par D4) |
| 8 | `Tested-later:` cerró 1 de 50 en dos días | **Coincido en que no escala, discrepo en la causa.** No es falta de disciplina: **40 de los 50 son anteriores al trailer** y solo se pueden saldar hacia adelante, y **5 son ruido conocido** — incluido `b3964c3`, el commit que cierra v0.2 con `Not-tested: nada que testear, es prosa`, la forma exacta que la regla prohibió después. Lo que falta es que la consulta sea un comando, no más trailers |

---

## 4. Plan de mejora, priorizado

Orden por consecuencia ÷ costo. Los costos son líneas medidas o estimadas sobre archivos que
leí.

### Tanda A — barato y de consecuencia alta (una sesión corta)

| # | Qué | Costo | Dueño |
|---|---|---|---|
| **A1** | Borrar el frontmatter `paths: ["**"]` de `commits.md`, `limites.md` y `herramientas.md` | 4 líneas × 3 archivos | **Mío**, Joaco aprueba el diff |
| **A2** | Agregar `ask` para `git commit` y `git push` en **`.claude/settings.json`** (el que viaja), dejando los `allow` como están | 4 líneas de JSON | **Joaco decide**, yo escribo |
| **A3** | Escribir la regla de push en `.claude/rules/commits.md`, en la sección que ya trata la autorización de commit | ~4 líneas | **Del chat de criterio** dictarla, **mía** escribirla |
| **A4** | Agregar a `CLAUDE.md` → "Formato de las respuestas": toda afirmación numérica va con el comando que la produjo. **Y ajustar "Qué no escribir nunca"** para que no la contradiga | ~4 líneas netas | **Mío** proponer, **Joaco** aprobar |
| **A5** | Colapsar el bloque duplicado de formato de commit: queda entero en `commits.md`, `proceso.md` §1 pasa a puntero | −12 líneas en `proceso.md` | **Mío** |
| **A6** | Fichar ese par como **E8 💥** en `inventario-pares.md` | 1 fila | **Mío** |

**Por qué esta tanda primero:** las seis son ediciones de texto o de config, ninguna toca
código de juego, ninguna necesita que se juegue nada, y A1+A2 juntas cierran el agujero más
grande — que la regla de commits se puede evaporar al compactar *y* que el permiso no la
respalda.

### Tanda B — barato, consecuencia media (una sesión)

| # | Qué | Costo | Dueño |
|---|---|---|---|
| **B1** | Ejercer el camino rojo de `consistencia.sh`: romper un par a propósito, confirmar que el `grep` machea y que sale con 2, revertir | ~15 min | **Mío**, con Joaco mirando la salida |
| **B2** | `autoMemoryDirectory` → `.claude/memory/` en el `settings.local.json` de cada máquina, más una línea en `.gitignore` si se decide que la memoria **no** se versione | 1 línea × 2 máquinas | **Joaco decide el régimen**, yo lo aplico acá |
| **B3** | Skill `/deuda`: computa `Not-tested:` menos los hashes citados en `Tested-later:` y lista lo abierto | ~30 líneas de SKILL.md | **Mío** |
| **B4** | Pasada de reconciliación: revisar los 50 `Not-tested:` con `/deuda` en la mano y saldar con un `Tested-later:` los que el playtest del 6/8 cerró | 1–2 h, y **requiere que Joaco recuerde qué se jugó** | **Compartido.** Yo no puedo afirmar que algo se ejerció |
| **B5** | Ampliar el disparo de `consistencia.sh` a `docs/design.md` y `.claude/skills/**`, preferentemente con el campo `if` de la config en vez del `case` | 2 líneas | **Mío** |
| **B6** | Prender gdUnit4 en Project → Plugins, y tachar el pendiente de `bitacora.md` | 2 min en el editor | **Joaco** (yo no abro el editor) |

### Tanda C — más caro, o bloqueado por una decisión

| # | Qué | Costo | Dueño |
|---|---|---|---|
| **C1** | Contestar si el chat de criterio puede leer este repo, y según eso: puntero o extracto fechado para los 14 ítems | La respuesta es gratis; la acción, ~35 líneas | **Del chat de criterio** |
| **C2** | Decidir la métrica del control simétrico —prosa residente total, no un archivo— y dónde se mide de cada lado | Decisión | **Joaco + chat de criterio** |
| **C3** | La tanda 2 de comparadores que `inventario-pares.md` ya priorizó: **31 pares están marcados 🔒 y solo 4 están cableados** | Varias sesiones | **Mío**, en el orden que el inventario ya fijó |
| **C4** | Alinear los scopes declarados con los usados: o se agregan `deps`, `tooling`, `design` a la lista, o se dejan de usar. Y decidir qué pasa con `survival`, declarado y nunca usado | 1 línea + criterio | **Joaco decide**, yo aplico |
| **C5** | Sacar `debug_enabled = true` de `zombie.tscn:55` cuando entre el HUD, y alinear la lista de andamios (par F1, ya divergido) | Chico, pero atado a v0.3/v0.4 | **Mío**, cuando toque |

### Lo que NO haría

- **No recortar `CLAUDE.md` a 40–60 líneas** (T2). El exceso real es 12,5% sobre un archivo,
  y buena parte de lo que se recortaría es el porqué de reglas contraintuitivas, que es lo
  que este equipo necesita conservar. A1: *"minimal does not necessarily mean short."*
- **No convertir `navmesh-recordatorio.sh` en un hook que hornee.** El motivo está escrito en
  el propio script y sigue siendo correcto.
- **No reescribir el historial para limpiar los 5 `Not-tested:` de ruido.** La regla ya dice
  por qué, y tiene razón: invalida los hashes que los citan.
- **No agregar un `PreToolUse` que valide el subject de los commits todavía.** 96% de
  cumplimiento no justifica el mecanismo; queda anotado como el arreglo si vuelve a resbalar.
- **No tocar las reglas `deny` del catálogo** para convertirlas en `Write(...)`: A7 dice que
  Claude Code acepta esa regla y **nunca la consulta**.
- **No reordenar `barrido-navmesh/SKILL.md`.** Su regla más importante está cerca del
  principio, que es lo que sobrevive al truncado tras compactar (A4).

---

## 5. Lo que esta crítica no cubre

- **Las 401 líneas y los 14 ítems del chat de criterio no los pude leer.** Todo lo que digo
  sobre ellos juzga el principio, no el texto.
- **El comportamiento tras `/compact` no está verificado** (H1). El método para verificarlo
  está escrito y cuesta un hook de dos líneas.
- **No corrí el juego.** Nada de acá dice si el juego se siente bien; eso sigue siendo el
  playtest, y v0.3 lo tiene pendiente.
- **La escribió el mismo que trabaja con este sistema todos los días**, igual que la
  retrospectiva de v0.2 — que ya se puso esa advertencia a sí misma. T4 dice que un modelo
  que evalúa su propia salida es indulgente. Las secciones con números medidos son las más
  confiables; la sección 1 —"lo que está bien"— es la que más conviene que alguien discuta.
