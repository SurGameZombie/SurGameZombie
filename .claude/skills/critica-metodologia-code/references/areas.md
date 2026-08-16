# Áreas del lado Code: qué mirar y cómo falla cada una

Guía de dónde suele estar el problema, no una checklist para completar. Si en un área no hay
nada, el resultado correcto es "está bien". Donde diga *verificable*, se corre: dejarlo como
inferencia es un error del auditor.

Las rutas están nombradas a propósito, para que el auditor tenga anclas y no salga a
adivinar cuál archivo es. Si una ruta no aparece donde dice, **eso es un hallazgo**: el
archivo se renombró o se movió y algo quedó apuntando al vacío. No la busques en silencio.

## 1. `CLAUDE.md` y las reglas

Los archivos van separados en dos grupos, porque no cargan igual y eso cambia qué se le puede
pedir a cada uno:

- **Residentes** — sin frontmatter `paths:`. Entran en cada arranque y se re-inyectan al
  compactar: `CLAUDE.md`, `.claude/rules/commits.md`, `.claude/rules/herramientas.md`,
  `.claude/rules/limites.md`.
- **Path-scoped** — con `paths:` declarado. Entran solo al tocar un archivo que machee, y se
  pierden al compactar hasta que algo vuelva a machear: `.claude/rules/gdscript.md`
  (`**/*.gd`) y `.claude/rules/netcode.md` (`scripts/<sistema>/**` y `scenes/**`).

Qué mirar: si cada regla sigue describiendo cómo se trabaja hoy; contradicciones entre reglas
o con las ADRs de `docs/decisions/`; reglas marcadas como sin probar que ya se ejercitaron y
nadie destildó; el tamaño total, medido con `wc -l`; y si los globs de las dos path-scoped
todavía cubren dónde vive hoy el código que pretenden gobernar.

Modos de falla: una regla sobreajustada al caso puntual que la originó; ejemplos que crecen
mientras la regla queda igual; una regla que solo se cumple si alguien se acuerda, donde
podría haber un chequeo mecánico; una regla path-scoped que gobierna algo crítico y no está
cargada durante la conversación donde se decide, que es lo que la separación de arriba busca
hacer visible.

## 2. Hooks y suite de consistencia

Archivos: `.claude/hooks/consistencia.sh` (PostToolUse sobre Edit|Write, corre la suite),
`.claude/hooks/navmesh-recordatorio.sh` (avisa, no hornea, y es deliberado),
`.claude/hooks/commit-confirmacion.sh`, `tests/consistencia_test.gd`,
`docs/reestructuracion/inventario-pares.md`, y el bloque de hooks en `.claude/settings.json`.

*Verificable.* Editar un archivo de cada tipo cubierto y confirmar que el hook dispara.
Romper cada par a mano y confirmar que el chequeo falla nombrando los dos lados. Revertir.

Qué mirar: rutas y patrones del `case` que ya no matchean lo que existe; chequeos que nunca
se vieron fallar; pares del inventario que siguen sin comparador pese a haber causado un bug.

Modos de falla: un chequeo en verde permanente porque compara mal y nadie lo probó en rojo;
un hook que dejó de matchear después de renombrar un archivo.

## 3. Permisos y settings

Archivos: `.claude/settings.json` (viaja), `.claude/settings.local.json` (no viaja, está
gitignoreado).

Qué mirar: qué quedó en el archivo local que debería viajar y al revés; reglas sueltas de
pruebas viejas; tools de MCP preaprobadas que mezclen lectura y escritura; si lo que dicen
las reglas coincide con lo que realmente pide confirmación en pantalla.

Modos de falla: una regla en el archivo local que solo protege una máquina; un `allow` puesto
para desbloquear algo puntual que quedó para siempre.

## 4. MCP y herramientas

Archivos: `.mcp.json` (viaja, solo config sin rutas absolutas), el bloque de proyecto de
`~/.claude.json` (no viaja), `docs/estado.md` §8.

Qué mirar: si la config con rutas absolutas está fuera del repo y la portable adentro; si las
tools declaradas se usan; si alguna se sumó sin pasar por el catálogo que pide
`.claude/rules/herramientas.md`.

Modos de falla: rutas de una máquina versionadas que no existen en la otra; herramientas
declaradas que nadie llamó nunca.

## 5. Convenciones de commit y trailers

*Verificable* sobre el historial de git. Ver `docs/estado.md` §6, que trae los comandos de
regeneración.

Qué mirar: commits que debían llevar trailer y no lo llevan; deuda de `Not-tested:` ya pagada
que nadie cerró con `Tested-later:`; trailers que afirman más de lo que se comprobó; el
conteo real de deuda abierta, medido con el `^` en el grep — sin él, el número sale inflado
porque machea commits que nombran el trailer en la prosa sin llevarlo.

Modos de falla: un trailer que afirma un alcance mayor que lo visto en pantalla, que deja
deuda marcada como cerrada y es peor que dejarla abierta; fechas imposibles contra la fecha
del commit que el trailer dice cerrar.

## 6. Los documentos como contenedores

Archivos: `docs/estado.md` (y su tabla de ruteo), `docs/proceso.md`, `docs/design.md`,
`docs/plan.md`, `docs/netcode.md`, `docs/bitacora.md`, `docs/investigacion-claude-code.md`,
`docs/retrospectiva-v0.2.md` (congelado: se cita, no se actualiza), `docs/decisions/`, los dos
archivos que escribe esta skill —`docs/auditoria-metodologia.md` y `docs/auditoria-deuda.md`—,
y todo `docs/reestructuracion/`, que la tabla de ruteo marca como temporal.

Qué mirar: si cada hecho vive en un solo lugar y los demás apuntan; archivos que mezclan
decisiones de método con decisiones de juego; documentos de trabajo temporales que quedaron
sin destino o que en los hechos ya son permanentes; si hay un lugar obvio donde va una
decisión nueva de cada tipo.

Modos de falla: dos copias del mismo dato que ya divergieron; un documento en una carpeta
temporal que en realidad es permanente; una decisión sin lugar obvio, que termina donde caiga.

## 7. Skills y comandos del repo

Archivos: `.claude/skills/`, incluido `barrido-navmesh/SKILL.md`.

Qué mirar: si el disparo describe lo que se pide realmente; dos que reclamen lo mismo; que el
frontmatter parsee; reglas duplicadas entre una skill y `CLAUDE.md` que van a divergir; que
lo instalado sea una carpeta con `SKILL.md` adentro y no un `.skill` sin extraer.

Modos de falla: una skill que nunca se activa por formato y falla en silencio, sin error
visible; una skill que repite una regla residente y queda vieja cuando la otra se edita.

## 8. La memoria de Code

Archivos: `.claude/memory/`, incluido su `MEMORY.md` índice.

Qué mirar: si lo que dice sigue siendo cierto; si contradice al repo; si un memo quedó viejo
respecto de algo ya corregido; si el índice concuerda con los memos que indexa; si hay algo
ahí que debería vivir en un doc.

Modos de falla: un índice desactualizado respecto de sus propios memos; un hecho que solo
vive en memoria y no viaja.
