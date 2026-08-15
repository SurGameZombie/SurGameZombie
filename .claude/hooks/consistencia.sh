#!/usr/bin/env bash
# Hook PostToolUse: corre tests/consistencia_test.gd después de tocar un archivo
# que participa de alguno de los pares comparados.
#
# Existe porque la regla "corré la suite después de tocar esto" en prosa se cumple
# hasta que alguien tiene apuro. Un hook la ejecuta el harness, no el modelo
# (docs/plan.md §5: "si escribís 'siempre que X, hacé Y', probablemente debería ser
# un hook").
#
# **Va a ponerse rojo a mitad de un cambio legítimo de dos lados** —tocaste el
# código y todavía no el doc— y eso es correcto: vuelve a verde cuando los dos
# lados están hechos. No es un falso positivo, es el estado real del repo.
#
# Recibe por stdin el JSON del hook. Sale 0 si no aplica o si la suite pasa, y 2
# —error bloqueante, el detalle vuelve al modelo— si la suite se pone roja.
set -u

payload=$(cat)

# Sin jq: no está instalado en estas máquinas. El file_path no puede contener
# comillas en Windows, así que un sed alcanza.
#
# Los dos pasos de barras son necesarios y en este orden: el JSON trae las barras
# invertidas ESCAPADAS (`C:\\Proyectos`), así que primero se desescapan y recién
# después se pasan a barras normales. Haciendo solo lo segundo queda
# `C://Proyectos//...`, que igual machea de casualidad pero se imprime mal en el
# mensaje de error, que es lo único que alguien va a leer cuando esto se ponga rojo.
file=$(
	printf '%s' "$payload" \
		| sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
		| sed 's/\\\\/\\/g' \
		| tr '\\' '/'
)
[ -n "$file" ] || exit 0

# Los lugares donde vive algún lado de un par comparado. Los primeros cuatro van
# por directorio: cualquier .gd de scripts/ o .tscn de scenes/ puede ser un lado.
#
# Los dos de abajo van por ruta EXACTA, y no por `docs/*.md` ni
# `.claude/skills/**`, a propósito: son los dos únicos archivos de doc que la
# suite compara contra algo. Un glob haría que cada edición de cualquier doc del
# repo se coma la suite entera —3,1 s, y corre `-a res://tests`, no solo el
# archivo que importa— sin comparar nada que no se hubiera comparado igual. El
# día que un tercer doc entre a un par, se le agrega su renglón acá.
case "$file" in
	*/scripts/*.gd | */resources/*.tres | */scenes/*.tscn | */project.godot) ;;
	*/docs/design.md | */.claude/skills/barrido-navmesh/SKILL.md) ;;
	*) exit 0 ;;
esac

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)" || exit 0

# La ruta de Godot es distinta en cada máquina (CLAUDE.md → Comandos), así que
# NO se hardcodea una sola: primero el PATH —que es lo que CLAUDE.md recomienda—,
# después GODOT_BIN, y recién al final la ruta conocida de esta máquina.
godot=$(command -v godot 2>/dev/null || true)
[ -n "$godot" ] || godot="${GODOT_BIN:-/c/Godot/Godot_v4.7.1-stable_win64.exe}"
if [ ! -x "$godot" ]; then
	# No romper la sesión de quien no tenga Godot donde este script lo busca, pero
	# TAMPOCO callarse: un hook que no corre y no avisa es peor que no tener hook.
	printf '{"systemMessage":"[hook] no encuentro Godot, así que la suite de consistencia NO corrió. Poné Godot en el PATH o exportá GODOT_BIN."}\n'
	exit 0
fi

# La salida va a un archivo y NO a `out=$(...)`. Medido en Git Bash: capturarla en
# una variable hace que la misma corrida pase de 3,1 s a 14,6 s —Godot escribiendo
# por un pipe—, y eso es la diferencia entre un hook que no se siente y uno que
# convierte cada edición en una espera.
log=$(mktemp) || exit 0
"$godot" --headless --path . \
	-s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests \
	>"$log" 2>&1
code=$?
if [ "$code" -eq 0 ]; then
	rm -f "$log"
	exit 0
fi

# gdUnit4 sale 100 con tests en rojo; cualquier otro código no nulo es el runner
# roto, y también hay que avisarlo.
{
	echo "[hook] la suite de consistencia salió con código $code después de tocar:"
	echo "  $file"
	sed -e 's/\x1b\[[0-9;]*m//g' "$log" \
		| grep -E "FAILED|ancla perdida|preloadea|tiene radius|design.md dice|el skill usa" \
		| head -6
} >&2
rm -f "$log"
exit 2
