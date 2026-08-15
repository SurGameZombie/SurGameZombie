#!/usr/bin/env bash
# Hook PreToolUse: pide confirmación explícita antes de cada `git commit` y de cada
# `git push`, por Bash y por PowerShell.
#
# No reemplaza a las cuatro reglas `ask` de `.claude/settings.json`: las complementa.
# Las reglas sí disparan —verificado el 14/8/2026, ver docs/bitacora.md → Problemas—,
# pero su patrón es un **prefijo literal**: `Bash(git commit *)` no matchea un
# `git -c user.name=X commit`. El regex de acá abajo sí, porque tolera tokens
# intermedios. Ese hueco es lo único que cubre este hook, y es real: está probado con
# `git -c … commit`, y cualquier otra forma con flags entre `git` y el subcomando cae
# igual.
#
# Cuando las dos capas matchean la misma llamada el prompt sale por la regla, no por
# acá: *"a matching ask rule still prompts even when the hook returned `allow` or
# `ask`"* (doc de permissions). Así que para probar que este hook aporta algo hay que
# testearlo con una variante que la regla no agarre.
#
# **Por eso el `permissionDecisionReason` de abajo NO dice cuál de las dos capas está
# pidiendo la confirmación.** Cuál es depende de la forma del comando, y este script no
# lo puede saber sin reimplementar el matcheo de `.claude/settings.json` —un dato que
# vive en otro archivo, o sea un par duplicado más, de los que nadie compara—. Decirlo
# igual fue el bug: el texto afirmaba *"las reglas `ask` no matchean esto"* también en
# los cuadros que salían justo por la regla, que son todos los de un `git commit` o un
# `git push` pelados. Es el mismo error que `ce5f439` corrigió del lado commit, en este
# mismo texto: nombrar una causa que no es.
#
# **No reemplaza al `ask` conceptualmente:** pide confirmación, no bloquea. El
# mecanismo es `permissionDecision: "ask"` con código de salida 0, NO un `exit 2`.
# Un `ask` emitido por un hook fuerza el prompt real incluso en modo auto y el
# clasificador no lo puede aprobar en silencio, mientras que un `exit 2` cortaría
# la llamada devolviéndole el mensaje al modelo —sin prompt para Joaco—, que es una
# pared y no una confirmación.
set -u

payload=$(cat)

# Sin jq: no está instalado en estas máquinas (ver consistencia.sh).
#
# Los `\"` del JSON pasan a un placeholder ANTES de buscar. Después de eso, todo
# `"` que queda es un delimitador de campo del JSON y nunca una comilla que el
# comando llevaba adentro. Sin este paso, `git -c user.name="X" commit` se escapa.
probe=$(printf '%s' "$payload" | sed 's/\\"/\x01/g')

# Que los tokens intermedios NO puedan contener `"` es lo que impide que el match
# cruce del campo `command` al campo `description`: entre los dos siempre hay un
# `","` crudo. Sin eso, `git show <hash> --stat` con la descripción "Show the
# commit contents" pediría confirmación, y este repo corre `git log` y `git show`
# todo el tiempo.
re='git[[:space:]]+([^[:space:]"]+[[:space:]]+)*(commit|push)([^[:alnum:]_-]|$)'

printf '%s' "$probe" | grep -Eq "$re" || exit 0

# Cuál de los dos, para que el mensaje diga algo concreto. Ante la duda —machea el
# patrón pero no se puede decidir cuál—, se nombran los dos: falla cerrada, que es
# la dirección barata. Pedir confirmación de más cuesta un prompt; pedirla de menos
# es el guardarraíl ausente.
if printf '%s' "$probe" | grep -Eq 'git[[:space:]]+([^[:space:]"]+[[:space:]]+)*commit([^[:alnum:]_-]|$)'; then
	accion="un \`git commit\`"
elif printf '%s' "$probe" | grep -Eq 'git[[:space:]]+([^[:space:]"]+[[:space:]]+)*push([^[:alnum:]_-]|$)'; then
	accion="un \`git push\`"
else
	accion="un \`git commit\` o un \`git push\`"
fi

# El JSON se arma con un heredoc SIN expansión salvo la línea de $accion, que se
# interpola aparte para no tener que escapar el resto.
cat <<JSON
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "Esto es $accion. El default de .claude/rules/commits.md es preparar el mensaje y parar ahí: terminar una tarea no habilita a commitearla ni a pushearla, y la autorización de un pedido no se hereda al siguiente. Si esto no lo pediste explícitamente ahora, decí que no."
  }
}
JSON
