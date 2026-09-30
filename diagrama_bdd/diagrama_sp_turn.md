# `sisper_db..sp_turn` — turnos

Catálogo de jornadas. Define **cómo se controla** la asistencia de un funcionario, no sus horas.

---

## Estructura

| Columna | Qué es |
| :--- | :--- |
| `cod_turno` | PK |
| `cod_jorper` | jornada de la persona |
| `cod_hora` | referencia al esquema horario |
| `duracion` | días que dura el ciclo |
| `inicio` | día en que arranca el ciclo |
| `descanso` | días de descanso del ciclo |
| `ver_hora` | **`S` = el marcaje es exigible · `N` = no lo es** |

---

## Contenido

| cod_turno | cod_jorper | cod_hora | duracion | inicio | descanso | ver_hora |
| ---: | ---: | ---: | ---: | ---: | ---: | :---: |
| 1 | 1 | 1 | 5 | 1 | 2 | S |
| 2 | 2 | 2 | 5 | 1 | 2 | S |
| **3** | 1 | 1 | 6 | 3 | 1 | **N** |
| 4 | 3 | 4 | 4 | 2 | 4 | S |
| 5 | 4 | 5 | 4 | 0 | 4 | S |
| 6 | 6 | 6 | 5 | 1 | 2 | S |
| 10 | 9 | 10 | 5 | 1 | 2 | S |
| 11 | 7 | 9 | 5 | 1 | 0 | S |
| 12 | 10 | 2 | 1 | 6 | 1 | S |
| 13 | 8 | 7 | 5 | 1 | 2 | S |
| 14 | 11 | 7 | 5 | 1 | 2 | S |
| **15** | 2 | 4 | 5 | 1 | 2 | **N** |
| **16** | 12 | 4 | 5 | 1 | 2 | **N** |
| 17 | 13 | 12 | 5 | 1 | 2 | S |
| 18 | 14 | 13 | 5 | 1 | 2 | S |

**15 turnos. Tres sin marcaje exigible: 3, 15 y 16.**

---

## El turno no guarda horas

`cod_hora` apunta a un esquema horario que vive en otra tabla. Las horas que el WF necesita
—`hora_ent_o` y `hora_sal_o`— **están en cada fila de `sp_as01`**, copiadas al registro del día.

Se comprobó con datos: un mismo `cod_turno = 1` aparece con 17:20 en registros de 2016 y con
17:18 en los posteriores. Si las horas vinieran del catálogo, serían idénticas.

---

## `ver_hora` — la columna que importa

Separa dos situaciones que se ven iguales en los datos:

| | |
| :--- | :--- |
| `ver_hora = 'S'` + sin marca | **faltó** |
| `ver_hora = 'N'` + sin marca | **no marca porque no le corresponde** |

Es la respuesta a la pregunta que quedó abierta en S0-013: *"cómo acredita su compensación quien
no tiene marcaje obligatorio"*. Los turnos **3, 15 y 16** son ese universo.

El script original la usaba sólo para reemplazar la hora por el literal `"T.S.H."`, perdiendo la
distinción. El PA la devuelve como bandera.

---

## Pendiente

Los códigos `cod_jorper`, `cod_hora`, `duracion`, `inicio` y `descanso` apuntan a catálogos que
todavía no se revisaron. `cod_hora` es el que llevaría al esquema horario real — útil si alguna
vez hace falta saber el horario teórico sin pasar por `sp_as01`.

---

## Relación

```
sp_as01 ──── cod_turno ────► sp_turn
```
