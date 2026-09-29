# Modelo de datos de asistencia — según el script recibido

Inventario de las 14 tablas que el script toca, qué hace cada una y cómo se relacionan.
Todo lo que sigue está inferido del uso en el script; lo que es suposición va marcado.

---

## Convención de nombres

El propio nombrado revela la organización:

| Patrón | Significa | Ejemplos |
| :--- | :--- | :--- |
| `sp_asNN` | Familia de **asistencia**, numerada maestro→detalle | `sp_as01`, `sp_as21`, `sp_as31` |
| `sp_e…` | Catálogo de **estados** | `sp_easi`, `sp_eaus` |
| `sp_t…` | Catálogo de **tipos** | `sp_tjus`, `sp_turn` |
| `sp_c…` | Catálogo de **categorías** | `sp_cjus` |
| `es_…` | Tablas **institucionales** en `ufro_db` | `es_cfer`, `es_tfer` |

`sp_as01` es el maestro; `21` y `31` son sus detalles. Que existan los números 21 y 31 y no 11
sugiere que hay **más tablas de la familia que el script no toca**.

---

## 1. `sisper_db..sp_as01` — el registro diario

**La tabla central.** Una fila por funcionario y día con actividad registrada.

| Columna | Rol |
| :--- | :--- |
| `cod_asist` | PK. Es la llave que usan todos los detalles |
| `rut` | funcionario |
| `f_ent_o` | fecha del registro, con hora. Es por lo que se filtra el rango y se ordena |
| `hora_ent_o` / `hora_sal_o` | **marca real** del reloj |
| `f_entrada` / `f_salida` | horario de referencia *(supuesto: el del turno)* |
| `cod_estasi` | cómo se clasificó el día |
| `cod_turno` | turno asignado ese día |

> ⚠️ El supuesto sobre `f_entrada`/`f_salida` no está confirmado. El script las etiqueta
> `"mentrada"`/`"msalida"` —¿*marca* entrada?— pero las que pasan por el filtro de `ver_hora`
> son `hora_ent_o`/`hora_sal_o`, lo que sugiere que **esas** son las sensibles, o sea la marca.
> Hay que verificarlo con datos.

---

## 2. `sisper_db..sp_easi` — estados de asistencia

Catálogo. `cod_estasi` → `des_estasi`.

Clasifica **cómo terminó el día**: normal, atraso, inasistencia, permiso… El script lo une
siempre (`INNER JOIN`), lo que implica que `cod_estasi` nunca es nulo en `sp_as01`.

Es el campo que responde *"¿ese día contó como trabajado?"* sin tener que interpretar horas.

---

## 3. `sisper_db..sp_turn` — turnos

Catálogo de jornadas. El script usa **una sola columna**:

```sql
CASE f.ver_hora WHEN "S" THEN <la hora> ELSE "T.S.H." END
```

`ver_hora` decide si la hora marcada se muestra o se oculta. `'N'` identifica a quien **no tiene
marcaje horario exigible** — académicos, jornadas sin control de reloj.

Es el dato más valioso que el script trae y no devuelve: permite separar *"no marcó porque
faltó"* de *"no marca nunca porque no le corresponde"*.

> El join es `INNER`, así que un día sin turno asignado desaparece del resultado.

---

## 4. `sisper_db..sp_as21` — ausencias del registro

**Detalle de `sp_as01`, relación 1:N.** Un mismo día puede tener varias ausencias.

| Columna | Rol |
| :--- | :--- |
| `cod_asist` | FK al registro del día |
| `tip_agraus` | tipo de agrupación de ausencia |
| `cod_agraus` | código de agrupación |

La clave hacia el catálogo es **compuesta**: `(tip_agraus, cod_agraus)`. Eso significa que las
ausencias están **clasificadas en grupos**, no en una lista plana.

Que el script monte un cursor completo para agruparlas confirma que la relación 1:N es real y
conocida.

---

## 5. `sisper_db..sp_eaus` — motivos de ausencia

Catálogo de `sp_as21`. Clave compuesta `(tip_agraus, cod_agraus)` → `res_ausen`.

`res_ausen` es el texto del motivo. El script lo lee en una variable `varchar(15)`, lo acumula
en `varchar(60)` y lo guarda en `varchar(30)` — tres tamaños distintos para el mismo dato.

---

## 6. `sisper_db..sp_as31` — justificaciones del registro

**El otro detalle de `sp_as01`.**

| Columna | Rol |
| :--- | :--- |
| `cod_asist` | FK al registro del día |
| `cod_tipjus` | tipo de justificación |
| `cod_catjus` | categoría de justificación |

Aquí está la inconsistencia más reveladora del script: para `sp_as21` armó un cursor que agrupa,
y para `sp_as31` usó un `UPDATE...FROM` que **se queda con una sola fila**.

Si `sp_as31` también es 1:N —y nada indica que no lo sea— el script pierde justificaciones sin
avisar. Es la cardinalidad que hay que confirmar primero.

---

## 7. `sisper_db..sp_tjus` — tipos de justificación

Catálogo. `cod_tipjus` → `des_tipjus`.

Es el **qué**: licencia, permiso administrativo, cometido, comisión de servicio.

---

## 8. `sisper_db..sp_cjus` — categorías de justificación

Catálogo. `cod_catjus` → `des_catjus`.

Es el **matiz** dentro del tipo. El script las concatena: `des_tipjus + "/" + des_catjus`, de
donde sale algo como `"Permiso/Con goce"`.

Dos catálogos separados implican que la combinación es libre: cualquier tipo puede tener
cualquier categoría.

---

## 9. `sisper_db..sp_pers` — personas del sistema de personal

Se usa **sólo para validar** que el RUT existe:

```sql
if not exists (select 1 from sisper_db..sp_pers where rut_person = @rut)
```

Nótese la columna: `rut_person`, distinta del `rut` que usa `sp_as01`.

---

## 10. `ufro_db..sp_pers` — personas institucionales

**Otra tabla de personas, en otra base.** Se une en la consulta principal:

```sql
and d.rut = a.rut
```

Y **no se usa ninguna de sus columnas**. Siendo join interno, actúa como un filtro invisible:
quien esté en `sisper_db..sp_pers` pero no aquí, desaparece del resultado.

Que existan dos tablas de personas con columnas distintas (`rut_person` vs `rut`) indica que son
dominios separados: una es del módulo de personal, la otra es el maestro institucional.

---

## 11. `sisper_db..sp_prdo` — periodos de calificación

Ya analizada aparte. Aporta `f_inicio` y `f_termino` a partir de `cod_periodo`.

No pertenece al dominio de asistencia: es el maestro del **proceso calificatorio de desempeño**
(tiene puntajes, ventana de calificación, año del proceso). El script la usa sólo como selector
de rango, porque la pantalla de origen vive en ese módulo.

---

## 12. `sisper_db..sp_pasi` — parámetros del módulo de asistencia

```sql
select @n_dias_jus = n_dias_jus from sp_pasi
```

Tabla de configuración de una sola fila *(supuesto: el `select` no tiene `where`)*.
`n_dias_jus` = días de plazo para justificar una ausencia.

El script la carga y **no la usa**. En el PA completo del que salió, seguramente servía para
marcar ausencias fuera de plazo.

> Es la única tabla que va **sin prefijo de base** — huella de que el procedimiento original vive
> dentro de `sisper_db`.

---

## 13. `ufro_db..es_cfer` — calendario de feriados

| Columna | Rol |
| :--- | :--- |
| `f_feriado` | la fecha |
| `cod_tipfer` | qué tipo de día no laboral es |

Es el calendario institucional. El script lo une por fecha para marcar los días que no eran
laborales.

> No filtra por nada más que la fecha. Si el calendario tuviera entradas por sede o campus,
> todas coincidirían.

---

## 14. `ufro_db..es_tfer` — tipos de feriado

Catálogo. `cod_tipfer` → `des_tipfer`.

Según S0-013 los valores serían: **1 feriado nacional, 2 feriado universitario, 3 suspensión de
actividades lectivas**. El 2 y el 3 son los que importan para acreditar trabajo en receso.

> ⚠️ El script la llama `es_tfer`; en S0-013 quedó anotada como `es_tipfer`. Son nombres
> distintos y hay que confirmar cuál existe.

---

## Resumen por rol

| Rol | Tablas |
| :--- | :--- |
| **Hecho** — el registro diario | `sp_as01` |
| **Detalles 1:N** del registro | `sp_as21` ausencias · `sp_as31` justificaciones |
| **Catálogos** que dan significado | `sp_easi` · `sp_eaus` · `sp_tjus` · `sp_cjus` · `sp_turn` |
| **Calendario** institucional | `es_cfer` + `es_tfer` |
| **Personas** | `sisper_db..sp_pers` (valida) · `ufro_db..sp_pers` (filtra) |
| **Configuración** | `sp_pasi` |
| **Ajeno al dominio** | `sp_prdo` — es de calificaciones |

De las 14, **9 son el dominio real de asistencia**. Las otras 5 son personas, configuración y
una tabla prestada de otro módulo.

---

## Lo que hay que verificar contra la base

| # | Duda | Cómo se resuelve |
| :-- | :--- | :--- |
| 1 | ¿`f_entrada`/`f_salida` es el turno o la marca? | comparar contra `hora_ent_o` en días normales |
| 2 | ¿`sp_as31` es 1:N como `sp_as21`? | `group by cod_asist having count(*) > 1` |
| 3 | ¿`es_tfer` o `es_tipfer`? | buscar en `ufro_db..sysobjects` |
| 4 | ¿`es_cfer` tiene alcance por sede? | revisar sus columnas |
| 5 | ¿`sp_pasi` tiene una sola fila? | `count(*)` |
| 6 | ¿Qué tablas más hay en la familia `sp_asNN`? | `sysobjects like 'sp_as%'` |

La 6 es la más interesante: el salto de numeración 01 → 21 → 31 sugiere que hay detalles del
registro de asistencia que este script no consulta.
