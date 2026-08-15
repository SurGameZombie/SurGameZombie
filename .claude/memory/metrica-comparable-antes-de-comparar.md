---
name: metrica-comparable-antes-de-comparar
description: Dar el comando no alcanza si la métrica no es comparable entre los archivos que se comparan
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e183d100-74e9-41b1-945e-eb35547deeb9
  modified: 2026-08-14T22:49:34.524Z
---

Cuando un número se usa para **comparar** dos cosas, el comando al lado no alcanza: hay que
chequear que la métrica muerda igual en los dos lados. Pasó el 14/8/2026 con la densidad de
línea de `docs/estado.md`: reporté 87 caracteres contra 76 de `proceso.md` usando un `awk`
filtrado a líneas de más de 40 caracteres. El filtro descartaba el 55% de `proceso.md` y el
31% de `bitacora.md`, así que la comparación no medía densidad sino cuántas líneas cortas
tenía cada archivo. Midiendo líneas no vacías, `estado.md` y `bitacora.md` dan 76 los dos:
la conclusión se daba vuelta.

**Por qué:** `CLAUDE.md` pide el comando al lado de cada cifra, y eso ya se cumplía. El
agujero que queda es el de arriba — un comando correcto puede producir un número que no
significa lo que la frase dice que significa, y Joaco lo agarró remidiendo por su cuenta.

**Cómo aplicarlo:** si el número va con un "contra" o un "más que", medirlo de dos formas
antes de escribirlo y usar la que no dependa de la forma de cada archivo. Si las dos formas
no coinciden, decir cuál se usó y qué descarta. Un número descriptivo de una sola cosa no
necesita esto; uno comparativo sí. Relacionado: [[atribuir-inferencias-vs-decisiones]].
