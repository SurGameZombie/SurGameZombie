#!/usr/bin/env bash
# Hook PostToolUse: avisa que hay que rehornear el NavMesh y correr el barrido de
# conectividad después de tocar la geometría del greybox o la herramienta que lo
# hornea.
#
# **Recuerda, no hornea, y eso es a propósito.** Hornear solo tiene dos problemas:
# reescribe scenes/main/yard_navmesh.tres —un archivo versionado— como efecto
# colateral de una edición que pedía otra cosa, y sobre todo deja la sensación de
# que el asunto está cubierto cuando no lo está. Que exista NavMesh no es que el
# mapa conecte: eso lo dice el barrido, y el barrido necesita leer un mapa de
# 59 × 59 caracteres y decidir. Hornear sin barrer es exactamente el estado en que
# el proyecto vivió tres semanas con la oficina tapiada (ADR-0008).
#
# El recordatorio sale por additionalContext y no solo por systemMessage: tiene que
# llegarle al modelo, que es quien puede correr el skill, no solo a la pantalla.
set -u

payload=$(cat)

# Desescapar y después normalizar. El porqué del orden está en consistencia.sh.
file=$(
	printf '%s' "$payload" \
		| sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
		| sed 's/\\\\/\\/g' \
		| tr '\\' '/'
)
[ -n "$file" ] || exit 0

case "$file" in
	*/scenes/main/yard.tscn | */tools/bake_navmesh.gd) ;;
	*) exit 0 ;;
esac

cat <<'JSON'
{
  "systemMessage": "[hook] tocaste la geometría del greybox o el horneado: falta rehornear el NavMesh y correr barrido-navmesh con su control negativo.",
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Se editó scenes/main/yard.tscn o tools/bake_navmesh.gd. Antes de dar la tarea por terminada: (1) rehornear con `godot --headless --path . -s res://tools/bake_navmesh.gd`, que sale con código 1 si algo falló; (2) correr el skill barrido-navmesh ENTERO, incluido su control negativo. El control tiene que sellar las DOS puertas del galpón, no una: con una sola el galpón sigue conectado por la otra y el barrido da verde sin haber controlado nada, que es el bug del commit 2519ff7. Si moviste una puerta, las coordenadas que el SKILL usa para sellarlas dejaron de apuntar al mapa real y tests/consistencia_test.gd ya te lo dijo en la misma edición."
  }
}
JSON
