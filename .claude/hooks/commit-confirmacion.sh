#!/usr/bin/env bash
# Hook PreToolUse: pide confirmación explícita antes de cada `git commit` y de cada
# `git push`, por Bash y por PowerShell.
#
# Existe porque las cuatro reglas `ask` de `.claude/settings.json` **no disparan**
# (docs/bitacora.md → Problemas, 14/8/2026). La doc oficial dice que deberían, así
# que es un gap del producto y no algo que este repo pueda arreglar cambiando
# config. Mientras el gap exista, sin este hook lo único que frena un commit por
# iniciativa propia es la prosa de `.claude/rules/commits.md`.
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
    "permissionDecisionReason": "Esto es $accion. Se pide confirmación porque las cuatro reglas \`ask\` de .claude/settings.json no disparan —gap del producto, medido el 14/8/2026 en Claude Code 2.1.232, ver docs/bitacora.md → Problemas— y este hook es la mitigación mientras exista. Recordá que el default de .claude/rules/commits.md es preparar el mensaje y parar ahí: terminar una tarea no habilita a commitearla, y la autorización de un pedido no se hereda al siguiente. Si esto no lo pediste explícitamente ahora, decí que no."
  }
}
JSON
