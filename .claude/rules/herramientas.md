---
paths:
  - "**"
---

# Herramientas nuevas

Antes de sumar **cualquier** MCP, skill, plugin, connector o hook, se consulta primero el
catálogo en `C:\ClaudeMCPsPlugingsSkillsETC`. El scope es todo el repo porque la decisión
de sumar una herramienta no nace tocando un archivo en particular.

## El catálogo se consulta antes, no después

Es la decisión ya tomada sobre cada herramienta, con el porqué y con lo descartado.
Evaluar de nuevo algo que ya se evaluó es trabajo tirado, y peor: se llega a la conclusión
contraria sin enterarse de por qué se había descartado.

Orden de lectura: **`INDICE.md` → `VEREDICTOS.md` → la ficha puntual** en `mcp/`,
`skills/`, `plugins/`, `connectors/`, `hooks/`, `comandos/` u `otros/`. Si hay más de una
opción para el mismo lugar, `comparativas/` antes de recomendar ninguna — ahí está por qué
las opciones **no se acumulan**.

## Nada `peligroso` se instala sin avisar

Si la ficha dice `peligroso`, se avisa primero, con el riesgo concreto sobre la mesa. No
alcanza con nombrar el veredicto: hay que decir **qué hace** la herramienta que la vuelve
peligrosa.

## Verificar autor/repo exacto, nunca solo el nombre

Hay herramientas distintas con nombre idéntico y perfiles de riesgo opuestos, y hay repos
que cambiaron de dueño —`MikeSchulze/gdUnit4` es hoy `godot-gdunit-labs/gdUnit4`—. **El
nombre por el que conocés una herramienta puede no ser el nombre del repo hoy**, y el
nombre viejo queda libre para que lo registre cualquiera.

## Dónde va la decisión de este proyecto

En `proyectos/surgamezombie/README.md` del catálogo, y es lo único que se escribe ahí: el
resto lo mantiene su propio agente. Tres estados posibles, y nada más:

| Estado | Qué exige |
|---|---|
| **Adoptada** | Qué hace acá, en una línea |
| **Diferida** | Un **gatillo concreto** — "cuando haya `.glb` que normalizar", no "más adelante" |
| **Descartada** | Por qué, para no volver a entrar al mismo callejón |

Un diferido sin gatillo no se puede desmentir nunca, así que no se escribe.

Un veredicto del catálogo es un **antecedente, no una orden**. Si acá la respuesta correcta
es otra, decilo y explicá por qué.

## Un condicional también se vence

Pasó con gdUnit4: la ficha lo tuvo como diferido seis días después de que estaba instalado
y corriendo, porque la nota se transcribió de una fuente vieja sin contrastarla contra el
repo. **Cuando toques una ficha diferida, verificá el gatillo contra el estado real antes
de copiarla hacia adelante.**
