---
name: que-hice-desde-el-estado-real
description: "Antes de cerrar un turno, armar Qué hice mirando git y no reconstruyéndolo de memoria — pero git no ve todo"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 931cbc9e-bdf0-4fbe-b8f6-5304e3f9fc2c
  modified: 2026-08-16T23:00:00.237Z
---

El ítem 2 del checklist de `docs/proceso.md` §4 —**"Leí el diff completo"**— aplica también
**antes de cerrar cualquier turno**, no solo antes de commitear. En concreto: correr
`git status --short` y `git diff --stat` y armar "Qué hice" con eso, en vez de reconstruirlo
de lo que me acuerdo de la sesión.

**Tarea = turno**, por la regla de un prompt por turno. Así que "el cierre de una tarea" de
`CLAUDE.md` → "Formato de las respuestas" es el cierre de cada turno, y "Qué hice" cubre ese
turno, no el arco entero de la sesión. Decidido con Joaco el 16/8/2026.

**Correr los comandos siempre, incluso cuando estoy seguro de que no cambié nada.** Si solo
los corro cuando dudo, el disparador vuelve a ser la autodetección.

**Por qué:** en una sesión larga el resumen final se arma de memoria de lo que fui haciendo,
y la memoria pierde cosas. No es hipótesis: `docs/investigacion-claude-code.md:47-48` lo tiene
medido —"los refactors largos se degradan a los ~40 minutos: pierde el track de qué archivos
ya editó"—. La regla que ya existía, `CLAUDE.md` → "Tareas chicas", tiene como disparador
*"notás que estás perdiendo el hilo"*, y una pérdida que no noté no dispara nada.

**El límite, y hay que decirlo si esto alguna vez se escribe en el repo:** "estado real" no
puede ser solo git. El scratchpad, los archivos que le mando a Joaco y cualquier cosa que
produzca fuera de un repo no aparecen en ningún `git status`. El caso que lo destapó fue justo
ese: el borrador de 34 líneas del formato de cuatro partes vivió en el scratchpad todo el
tiempo, con los dos repos limpios. Git captura el *efecto* —esas 34 líneas son hoy
`CLAUDE.md:138-171`— pero no el *artefacto*. Una regla escrita como "mirá git" deja ese punto
ciego con sensación de cobertura.

**Cómo aplicarlo:** correr los dos comandos antes de redactar "Qué hice", y sumar a mano lo
que produje fuera del repo. Esto **no está escrito en `CLAUDE.md` ni en las rules a propósito**:
la prosa residente está en 947 líneas contra un umbral de 750 y esa decisión sigue abierta
(E7 de `docs/reestructuracion/inventario-pares.md`). Si el umbral se resuelve y se decide
escribirlo, va con el límite del scratchpad incluido. Relacionado:
[[metrica-comparable-antes-de-comparar]].
