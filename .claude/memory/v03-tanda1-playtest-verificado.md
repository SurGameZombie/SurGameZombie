---
name: v03-tanda1-playtest-verificado
description: De la deuda de red de la tanda 1 de v0.3 solo se pagó la mentira 3 de F4; el alcance y la fecha que tenía anotados eran más grandes que lo real
metadata: 
  node_type: memory
  type: project
  originSessionId: f051af95-bfb4-4106-9933-a1bbd8f1e57b
  modified: 2026-08-11T22:57:59.130Z
---

El playtest de dos instancias del inventario de v0.3 confirmó **una sola cosa**: la mentira
3 de F4 —un cliente escribiéndole un delta al `InventorySync` de otro jugador por el path
directo— la rechazó el host, y las 99 palancas no aparecieron del otro lado. Joaco no
recuerda haber visto el snapshot al conectarse, el stream de deltas ni el descarte por
desincronización con dos instancias reales. Fecha exacta no anotada: **entre el 7 y el
10/8/2026**, sin commit asociado.

**Why:** esta memoria decía antes "los siete commits de la tanda (`a3a1dc5`..`fae9d15`)
llevan `Not-tested: NINGÚN RPC cruzó el cable`" y con fecha 7/8. Las dos cosas eran de más:
`git log --grep` muestra que ese `Not-tested:` lo llevan **solo `50d33d0` y `2d417f5`**, y
la fecha no está registrada en ningún lado. Sobreestimar lo que se pagó es peor que
subestimarlo: deja deuda de red marcada como cerrada.

**How to apply:** quedó registrado en `docs/bitacora.md` § Registro y cerrado con el trailer
`Tested-later:` sobre `2d417f5` únicamente. El `Not-tested:` de `50d33d0` sigue **abierto
entero**. Antes de afirmar que algo de esa tanda se verificó, preguntar qué vieron en
pantalla — ver [[atribuir-inferencias-vs-decisiones]].
