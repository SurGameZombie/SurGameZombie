# ADR-0005: Escribimos nuestro propio character controller

**Fecha:** 2026-08-01
**Estado:** aceptada
**Fuente:** `docs/bitacora.md` → "Character controller: propio, no
`expressobits/character-controller`"

## Contexto

Existe `expressobits/character-controller` (MIT, GDScript), un addon modular ya hecho, del
mismo equipo que liberó las otras piezas que este proyecto podría usar.

Contra eso pesa el riesgo declarado número uno del proyecto, registrado en
`docs/bitacora.md` → "Riesgos identificados":

> **El riesgo mayor para nosotros: descargar todo el trabajo cognitivo en la IA.** Hay
> casos documentados de gente que abandonó su proyecto porque perdió el contacto con su
> propio código y no lo podía arreglar.

Y el controller del jugador es justamente el archivo que no nos podemos permitir tratar
como caja negra: `CharacterBody3D`, `_physics_process`, `move_and_slide()` y el manejo de
input son la base de todo lo que viene después.

## Decisión

Lo escribimos nosotros.

**Es una decisión de aprendizaje, no técnica.** Escribirlo a mano es la mejor forma de
entender Godot, y este es el primer videojuego de los dos.

## Alternativas descartadas

**`expressobits/character-controller`.** Nos ahorra una tarde a cambio de no entender lo
más básico del juego. Queda registrado explícitamente que **el addon seguramente sea mejor
código que el que escribamos la primera vez**: no se descartó por calidad.

No hay registrada ninguna otra alternativa evaluada.

## Consecuencias

- La primera versión del controller va a ser peor código que el addon. Se acepta a
  conciencia.
- v0.1 tarda más de lo que tardaría con el addon.
- A cambio, el archivo más importante del juego es legible y arreglable por nosotros, que
  es la contramedida directa al riesgo de arriba.
- Esta decisión no se generaliza sola a otros addons. El de inventario de expressobits
  sigue en el plan para v0.3 (`docs/plan.md` §3): la regla no es "no usamos addons", es
  "el controller del jugador no es una caja negra".
