---
name: reestructuracion-docs-parte1
description: Parte 1 de la reestructuración de docs cerrada el 10/8/2026; el inventario de los pares duplicados que quedan vive en docs/reestructuracion/inventario-pares.md
metadata: 
  node_type: memory
  type: project
  originSessionId: 5b1e2dda-61fd-40c0-af3c-9c871104b746
  modified: 2026-08-11T00:49:33.552Z
---

La reestructuración de la documentación se hace por partes, siguiendo una metodología
traída de otro proyecto (una landing web) cuyo hallazgo central es buscar **pares de datos
duplicados que nada compara**. La Parte 1 quedó cerrada el 10/8/2026 en los commits
`f1725bb`..`117d858`.

La Parte 1 cerró 8 pares (4 con comparador automático en `tests/consistencia_test.gd`, 4
en prosa o borrando la copia muerta). **Quedan 53 abiertos, y viven en
`docs/reestructuracion/inventario-pares.md`** — documento de trabajo, no documentación
final: se absorbe en `ESTADO.md` y `PLAN.md` cuando lleguen esas partes.

**Why:** el inventario costó una pasada de lectura completa sobre los 109 archivos
versionados fuera de `addons/`. Antes existía solo en una conversación, que es la forma
más fácil de tener que volver a producirlo entero.

**How to apply:** al planificar cualquier parte siguiente, abrir ese archivo primero — trae
la sección "Candidatos a la tanda 2 del script" ya priorizada y una sección "Lo que NO hay
que arreglar" con dos divergencias deliberadas que no se tocan. Ver también
[[atribuir-inferencias-vs-decisiones]].
