---
name: atribuir-inferencias-vs-decisiones
description: "Al documentar decisiones de diseño, distinguir explícitamente lo inferido de la arquitectura de lo que decidieron ellos"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 61713aea-06ea-4336-88bb-541e4f5bfbf0
  modified: 2026-08-06T19:09:02.740Z
---

Cuando escribo una decisión de diseño en `docs/`, cada afirmación tiene que decir de dónde
sale: **inferencia de la arquitectura que ya existe** o **decisión que tomaron ellos**. No
alcanza con que la afirmación sea correcta.

Ejemplo del 6/8/2026: al cerrar el hueco del límite de revivires en `design.md`, escribí que
la ventana se cuenta por jugador. Era cierto y salía de que cada jugador ya tiene su propio
estado de caído en su nodo de stats — pero quedaba redactado como si Joaco lo hubiera
decidido aparte. Corrección: dejarlo escrito como inferencia.

**Por qué:** `docs/design.md` es donde ellos registran sus propias decisiones. Una inferencia
mía redactada con el mismo tono se lee después como doctrina del equipo, y nadie puede
distinguirla. Es el mismo modo de falla que la retrospectiva de v0.2 documenta en §1.E, donde
números de gameplay que inventé yo terminaron en la tabla de números base.

**Cómo aplicarlo:** al cerrar un hueco o escribir en `design.md`/`plan.md`, marcar cada
afirmación como decidida por ellos, inferida de la arquitectura, o pendiente. Si es
inferencia, decirlo en la misma frase: "no es una decisión nueva: sale de que X". Es la misma
distinción de `.claude/rules/limites.md` (dato verificado / inferencia / suposición) aplicada
a diseño y no a APIs.
