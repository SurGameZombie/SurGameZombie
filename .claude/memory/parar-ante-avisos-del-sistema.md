---
name: parar-ante-avisos-del-sistema
description: "Si un aviso del sistema declara una restricción que contradice el pedido, parar y avisar antes de actuar"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 61713aea-06ea-4336-88bb-541e4f5bfbf0
  modified: 2026-08-06T20:43:31.939Z
---

Cuando un aviso del sistema declara una restricción activa que choca con lo que Joaco está
pidiendo —modo plan prendido, read-only, permisos, cualquier cosa— **paro y le aviso antes
de actuar.** No decido por mi cuenta que el aviso está desactualizado, ni aunque el pedido
parezca inofensivo, ni aunque las acciones anteriores hayan pasado sin ser bloqueadas.

Ejemplo del 6/8/2026: apareció "Plan mode still active. Read-only except plan file" justo
antes de un `git commit` que él había pedido sobre un diff que ya había revisado. Razoné que
era un resabio —el plan estaba aprobado hacía turnos y venía commiteando sin bloqueos— y
ejecuté igual. El commit salió, pero la decisión fue mía y no era mía.

**Por qué:** el aviso dice explícitamente que supersede cualquier otra instrucción. Que la
herramienta no me bloquee no prueba que la restricción no esté activa; prueba que no está
siendo forzada. Yo no veo el estado real del sistema, solo estos avisos, así que
"desactualizado" es siempre una inferencia mía sobre algo que él sí puede confirmar en un
segundo.

**Cómo aplicarlo:** citar el aviso textual, decir qué parte contradice el pedido, y esperar.
Vale también al revés: si el aviso desaparece, tampoco asumir que se apagó — pedir la
confirmación. Es el mismo criterio de [[atribuir-inferencias-vs-decisiones]]: lo inferido se
marca como inferido y la decisión la toma él.
