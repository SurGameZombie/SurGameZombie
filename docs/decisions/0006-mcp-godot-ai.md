# ADR-0006: Usamos `hi-godot/godot-ai` como MCP server de Godot

**Fecha:** 2026-08-01
**Estado:** aceptada
**Fuente:** `docs/bitacora.md` → "Tooling: MCP server `hi-godot/godot-ai`"; `docs/plan.md`
§5 → "Cerrar el loop de verificación"

## Contexto

Por default, Claude Code edita archivos pero **no puede apretar play y leer el error de
runtime**. Entrega código y los bugs los encontramos nosotros. En Godot, donde casi todos
los bugs aparecen en runtime, eso es un techo estructural.

Un MCP server cierra parte de ese loop: deja ver el scene tree en vivo, leer el output del
debugger, correr el proyecto y sacar screenshots, en vez de adivinar node paths. Según la
gente que lo usa, ver el scene tree real es el salto de calidad más grande.

`docs/plan.md` §5 listaba tres opciones activas —GDAI MCP Plugin, `Coding-Solo/godot-mcp`
y `alexmeckes/godot-mcp`— pero esa lista quedó vieja: **el plan se escribió antes de
compararlos de verdad.**

## Decisión

Usamos **`hi-godot/godot-ai`**, instalado y configurado en el commit `37fc970`. El plugin
vive en `addons/godot_ai/` y está commiteado en el repo, así que las dos máquinas corren
la misma versión.

Las razones registradas:

- Se autoconfigura con Claude Code desde el propio editor, sin editar configs a mano.
- Licencia MIT.
- Mantenimiento activo.
- Expone 43 tools contra el editor en vivo.

## Alternativas descartadas

**GDAI MCP Plugin**, **`Coding-Solo/godot-mcp`** y **`alexmeckes/godot-mcp`**: eran las
tres opciones que listaba `docs/plan.md` §5.

**Los tres MCPs de `plan.md` nunca se evaluaron individualmente. Ese plan se escribió
antes de compararlos.** No hubo un descarte razonado de cada uno: la lista quedó vieja
antes de usarse, y la comparación real se hizo después, contra `hi-godot/godot-ai`.

## Consecuencias

- El plugin registra un autoload `_mcp_game_helper` en `project.godot`. **Es esperado, no
  un accidente.**
- `addons/godot_ai/` está commiteado y **no se edita** (`CLAUDE.md` → `addons/`). Cualquier
  cambio ahí se pierde al actualizar el plugin.
- Como `project.godot` ahora lo toca también el plugin, aplica la regla de "Reload from
  disk" cuando git modifica ese archivo con el editor abierto (`docs/bitacora.md` →
  "Problemas que ya nos pasaron").
- Queda **un solo** servidor de Godot. Sumar otros solapados es contexto desperdiciado y
  descripciones que compiten entre sí (`docs/investigacion-claude-code.md` → regla
  operativa 6).
- Cierra parte del loop de verificación, no todo: sigue sin poder decidir si el juego se
  siente bien.
