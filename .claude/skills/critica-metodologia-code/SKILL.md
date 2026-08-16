---
name: critica-metodologia-code
description: "Audita y critica la metodología de trabajo del lado Claude Code en SurGameZombie: CLAUDE.md y las reglas residentes, hooks y suite de consistencia, permisos y settings, MCP, convenciones de commit, los docs como contenedores, skills y memoria. Corre en dos fases, mapa y zoom, con ángulos de revisión separados y umbral de confianza. Actualiza el mapa en docs/estado.md y deja reporte y hallazgos abiertos. Usala solo cuando Joaco la pida explícitamente. No audita el código del juego."
---

# Crítica de metodología — lado Code

Autocrítica: Code auditando el sistema dentro del que Code trabaja. Es la configuración más
débil que existe para encontrar errores — un modelo detecta un error cuando le llega como
material externo y no lo detecta cuando salió de él mismo.

La defensa principal es que acá **se puede ejecutar**. Un hallazgo que se convierte en un
comando deja de ser opinión. Regla dura: **si se puede verificar corriendo algo, se corre.**
Inferir algo que era verificable es un error del auditor, no una limitación del entorno.

Las otras tres:

- **Leer, no recordar.** Todo lo que se audita se abre y se cita por archivo y línea.
- **Umbral de confianza.** Cada hallazgo se puntúa 0-100; por debajo de 80 se descarta en
  silencio. El umbral aplica **a hallazgos**, no a la incertidumbre sobre una API, sobre lo
  que no se pudo verificar o sobre el entorno: eso se dice siempre, como pide `limites.md`.
- **Permiso de no encontrar nada.** "Esta área está bien" es un resultado válido y frecuente.
  A un revisor al que se le pide encontrar huecos, encuentra huecos aunque no los haya.

## Lectura obligatoria antes de producir un solo hallazgo

Dos archivos, y ninguno es opcional:

- **`docs/reestructuracion/critica-metodologia.md`** — crítica manual previa, con hallazgos ya
  argumentados y una sección **"Lo que NO haría"** que registra decisiones tomadas de no hacer
  ciertas cosas. Esta no es la primera auditoría. Re-proponer algo que ahí ya se descartó, o
  presentar esta corrida como la primera, es el error más caro que puede cometer esta skill.
- **`docs/investigacion-claude-code.md`** — `CLAUDE.md` lo exige textualmente *antes de
  proponer cambios de proceso o de herramientas*, y esta skill no produce otra cosa. Trae los
  modos de falla medidos de la IA en gamedev y las reglas operativas que salen de ahí. Un
  hallazgo que los contradice sin nombrarlos está discutiendo contra evidencia que no leyó.

## Alcance

**Adentro:** todo lo que determina cómo se trabaja — `CLAUDE.md` y `.claude/rules/`, hooks,
la suite de consistencia y el inventario de pares, permisos y settings, configuración de MCP,
convenciones de commit y trailers, los documentos en su rol de contenedores, las skills y
comandos del repo, y la memoria de Code.

**Afuera:** el código del juego, los números de balance y los assets. La metodología del lado
app se audita por separado y fuera de este repo; no la mires.

**El borde:** de un archivo, el contenido de juego queda afuera pero su rol queda adentro. Si
el número de vida del zombie está bien no es asunto de esta skill; si vive en el lugar
correcto y hay algo que lo compare, sí lo es.

**La separación método/juego es materia de auditoría, no un supuesto.** Un archivo que mezcla
las dos cosas es un hallazgo por sí mismo: obliga a leer las dos para encontrar una, y hace
que una decisión nueva no tenga lugar obvio donde ir.

Si aparece una tarea que no requiere programar (diseño, balance, worldbuilding, mockups),
marcala como delegable a Mathi en el momento en que aparece. En esta skill casi nunca va a
pasar, pero `CLAUDE.md` lo pide igual.

## Los tres archivos

Vidas distintas, no los mezcles:

1. **El mapa** — `docs/estado.md`, §6 y §8. Permanente. Describe cómo funciona hoy la
   maquinaria: qué protege verificación automática y qué no, qué herramientas hay, qué viaja
   entre máquinas y qué no. Esta skill lo **pone al día** al correr, remidiendo cada cifra:
   §6 regenerándola con sus propios comandos y §8 a mano (ver Fase 1, que dice por qué no es
   lo mismo). Mantenerlo al día entre corridas es obligación permanente de Code, no de esta
   skill.
   `docs/reestructuracion/mapa-metodologia.md` es material de origen para leer, **no** el
   destino: esa carpeta está marcada como temporal y convertirla en permanente sería cometer
   el modo de falla que `references/areas.md` §6 describe.
2. **El reporte de la corrida** — `docs/auditoria-metodologia.md`, en `docs/` y no en
   `reestructuracion/`, porque esta skill sigue corriendo después de que la reestructuración
   cierre. Se sobrescribe siempre; el historial lo guarda git. No se acumulan archivos
   fechados.
3. **La lista de hallazgos abiertos** — `docs/auditoria-deuda.md`. Persiste entre corridas. Un
   hallazgo sale de ahí cuando se arregla y hay evidencia de qué lo cerró, no cuando alguien lo
   da por hecho. Mismo patrón que `Not-tested:` / `Tested-later:`: el evento es efímero, la
   deuda persiste hasta que se paga.

**Los dos archivos nuevos van también a la tabla de ruteo de `docs/estado.md`** —la de "Dónde
va cada cosa"—, la primera vez que se los escriba. Una fila cada uno, en el formato de las que
ya están: destino y qué tipo de hecho va ahí. Un doc permanente en `docs/` que el índice de
ruteo no nombra es la "decisión sin lugar obvio" que `references/areas.md` §6 lista como modo
de falla, y sería autoinfligida.

**En la primera corrida**, la lista arranca migrando las tandas A/B/C de
`critica-metodologia.md`, que ya tienen dueño asignado, a su nuevo hogar: no dejes la lista
apuntando a un archivo marcado para desaparecer.

**No copies las tandas tal cual: varias ya están cerradas y entrarían como deuda falsa.** Antes
de migrar un ítem, buscá su evidencia de cierre, y migralo cerrado —con el comando o el hash
que lo cierra— o no lo migres. Cómo se verifica el cierre, en orden de fuerza:

1. **Corriendo el chequeo que el ítem pedía.** Es la evidencia más fuerte y la única que esta
   skill produce sola. B5 pedía ampliar el disparo de `consistencia.sh` a `docs/design.md` y al
   `SKILL.md` de `barrido-navmesh`; `sed -n '45,49p' .claude/hooks/consistencia.sh` muestra las
   dos rutas ya adentro del `case`, así que B5 está hecho.
2. **Leyendo el estado actual del archivo que el ítem quería cambiar.** H1 decía que las tres
   rules de scope global declaraban `paths:` y por eso no sobrevivían a un `/compact`; hoy
   `head -1` sobre `commits.md`, `herramientas.md` y `limites.md` no devuelve frontmatter en
   ninguna, así que H1 está cerrado.
3. **Encontrando el commit que lo cerró**, que es lo que permite citarlo:
   `git log --oneline --all -S'<el texto que cambió>'` o `git log --oneline -- <el archivo>`.
   A H1 lo cierra `a2b806b`.

Un ítem que no se puede cerrar por ninguna de las tres migra **abierto**. La duda no lo cierra:
es el mismo criterio que `Tested-later:`, que no puede dar por verificado algo que no se
ejerció.

**Todo número se remide en cada corrida.** Ninguno se hereda del mapa ni del reporte
anterior. Ya pasó más de una vez que un número viejo sobreviviera copiándose solo.

## Fase 1: mapa

Pasada sobre **todas** las áreas del alcance, sin profundizar. Para cada una: qué es, qué se
leyó o midió, veredicto grueso, si necesita zoom.

**Regenerá `docs/estado.md` §6 con sus propios comandos** en vez de editarla a mano: la sección
declara en su primera línea que se genera, y trae los dos `git log` que la producen. §8 sí se
actualiza a mano, con lo que encuentres. Ninguna cifra de las dos se hereda: se remide.

Prioridad para el zoom:

1. Áreas con un error real registrado — en la bitácora, en un commit, en la lista de
   abiertos. Entran sin discusión: misma regla que el proyecto ya usa para los pares.
2. Áreas que nunca se auditaron.
3. Áreas auditadas hace más tiempo.

**Si ninguna necesita zoom, la corrida termina acá** y el reporte lo dice. No agregues un
área para tener trabajo.

## Fase 2: zoom

Cargá `references/areas.md` al empezar: trae qué mirar en cada área, con rutas concretas, y
los modos de falla conocidos.

Cuatro ángulos, y **el orden importa porque comparten el árbol de trabajo**:

**Primero, tres en paralelo, todos de solo lectura** (agentes tipo `Explore`):

- **Arqueólogo** — busca si lo que parece un error ya está argumentado: en
  `docs/reestructuracion/critica-metodologia.md` (sobre todo su "Lo que NO haría"), en
  `docs/retrospectiva-v0.2.md` —congelado, se cita y no se actualiza, y es el autoanálisis
  donde varias de estas decisiones se tomaron por primera vez—, en las ADRs de
  `docs/decisions/`, en `docs/bitacora.md` y en los mensajes de commit. Su trabajo es
  **descartar** hallazgos, no producirlos.
- **Duplicación** — el mismo hecho escrito en dos lugares sin nada que los compare, y si
  alguno ya divergió. Cruzalo contra `docs/reestructuracion/inventario-pares.md`.
- **Cobertura** — qué no vigila ninguna regla ni chequeo, empezando por lo que ya falló una
  vez.

**La prohibición de escribir va en el prompt de cada uno de los tres, no se da por supuesta del
tipo de agente.** `Explore` no trae `Edit`, `Write` ni `NotebookEdit`, pero **sí trae `Bash` y
`PowerShell`**, así que puede escribir por shell igual. El tipo de agente acota la superficie;
no la cierra.

**Después, y solo, el verificador.** Toma cada afirmación que quedó en pie y la convierte en
un comando: corre la suite, rompe un par a mano para confirmar que el chequeo falla nombrando
los dos lados, edita un archivo de prueba para ver si el hook dispara, mide sobre el
historial de git.

Va solo por tres razones concretas, no por prudencia genérica:

- Si corre en paralelo con los de lectura, el ángulo de duplicación ve la rotura deliberada y
  reporta una divergencia **que el verificador acaba de crear**: un hallazgo fabricado, justo
  el error contra el que existe esta skill.
- El hook de consistencia es `PostToolUse` sobre `Edit|Write` y es bloqueante. Cada rotura
  deliberada lo pone en rojo. **Eso es lo esperado: no intentes arreglarlo.** La rotura es el
  experimento; el rojo es el resultado que se buscaba.
- El chequeo de cierre con `git status` solo sirve si hay un único agente escribiendo.

Cada rotura va con guion escrito antes de ejecutarla: qué se rompe, qué se espera ver, cómo
se revierte. Nada improvisado.

Si hiciera falta paralelismo real en el verificador, existe `isolation: "worktree"`, con dos
costos que hay que declarar: el worktree no lleva `.claude/settings.local.json` (está
gitignoreado) ni el cache de importación, así que Godot reimporta todo.

Cada ángulo devuelve hallazgos con confianza 0-100. Consolidá descartando lo que quede bajo
80 y lo que el arqueólogo haya justificado como deliberado.

Si el contexto no alcanza para todas las áreas, hacé las que entren y anotá el resto como
pendiente. Cortar y retomar es correcto; apurar los últimos zooms no.

## Formato de cada hallazgo

**[Título en una línea]** — [área] — confianza: [0-100] — evidencia: leído | medido |
ejecutado | inferido | no verificable desde acá
- Ubicación: [archivo:línea]
- Qué pasa: [qué dice o hace hoy]
- Cómo se comprobó: [el comando corrido y su salida, o qué se leyó]
- Por qué importa: [qué se rompe o qué costó ya]
- Hacia dónde: [dirección del arreglo]

La quinta etiqueta no es relleno: lo que depende de la otra máquina, del editor abierto o de
algo que Joaco tiene que mirar en pantalla se marca así y no se disfraza de inferencia.

**No escribas el texto de reemplazo ni apliques arreglos.** Esta skill audita; Joaco decide
qué hallazgos acepta y recién ahí se redacta. La única escritura permitida son los tres
archivos.

## Cierre

- ¿Algún hallazgo verificable que quedó como inferencia? Verificalo.
- ¿Alguno sin ubicación, sin confianza, o por debajo de 80? Sacalo.
- ¿Alguno que el arqueólogo mostró que es deliberado, o que ya está en "Lo que NO haría"?
  Sacalo.
- ¿Alguno sobre el código del juego o sobre el lado app? Fuera de alcance.
- ¿Quedó algo roto de lo que el verificador rompió a propósito? Revertilo y confirmá con
  `git status` que el árbol está limpio salvo los tres archivos.
- ¿Algún número copiado en vez de remedido? Remedilo.
- ¿Hallazgos de la lista de abiertos que se arreglaron desde la corrida anterior? Sacalos,
  con la evidencia de qué los cerró.

El mapa, el reporte y la lista van en el mismo commit: son la misma corrida.
