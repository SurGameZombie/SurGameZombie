# ADR-0002: Escribimos el juego en GDScript con static typing obligatorio

**Fecha:** 2026-08-01
**Estado:** aceptada
**Fuente:** `docs/bitacora.md` → "Lenguaje: GDScript, no C#"; `docs/plan.md` §1

## Contexto

Godot deja elegir entre GDScript y C#. Los dos venimos de otros lenguajes, así que la
tentación era usar el que ya conocemos.

Dos cosas pesaban en contra de esa intuición:

1. **El loop de feedback es lo que hace productivo a Claude Code.** Cuanto más corto el
   ciclo editar → correr → ver el error, más rápido se corrige lo que el agente escribe mal.
2. **GDScript es dinámico por default**, y eso es veneno para un agente: sin tipos, ni el
   editor ni Claude Code detectan errores hasta runtime.

## Decisión

Usamos **GDScript**, con **static typing obligatorio** en todas las variables, parámetros
y retornos, sin excepciones.

```gdscript
var health: float = 100.0
func take_damage(amount: int, source: Node3D) -> void:
```

Es el lenguaje de primera clase de Godot: toda la documentación, todos los tutoriales y
casi todos los addons están en GDScript. No tiene paso de compilación. Y es Python-like,
así que sabiendo programar se agarra en dos días.

## Alternativas descartadas

**C#.** Tiene paso de compilación, lo que alarga el loop de feedback. La documentación,
los tutoriales y los addons están en GDScript, así que trabajar en C# significa traducir
todo lo que se lee. No hay registrada ninguna otra razón de descarte.

**GDScript sin tipar (el default del lenguaje).** Descartado porque sin tipos los errores
no aparecen hasta runtime, ni para el editor ni para Claude Code. Con tipos, la mitad de
los bugs se agarran antes de correr el juego.

## Consecuencias

- La versión instalada en las dos máquinas es la **standard, no la .NET**. Meter C# más
  adelante implicaría cambiar la instalación en las dos.
- El static typing pasa a ser una regla dura de `CLAUDE.md` y de
  `.claude/rules/gdscript.md`, no una preferencia de estilo: es parte del sistema de
  detección de errores del proyecto.
- Conviene revisar `:=` con cuidado. Si el lado derecho devuelve `Variant`, la variable
  queda `Variant` y se pierde el tipado sin que nada avise (ver
  `.claude/rules/gdscript.md`, checklist punto 3).
- No existe nada de C# en este proyecto: mezclar nombres de clases de C# con sintaxis de
  GDScript es un error conocido de los agentes y acá no tiene ninguna excusa.
