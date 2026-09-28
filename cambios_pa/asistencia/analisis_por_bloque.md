# Script de asistencia — análisis bloque por bloque

Recorrido secuencial: qué intenta hacer cada bloque, qué hace realmente, y veredicto.

---

## Bloque 1 · Declaración y parámetros globales

```sql
declare @n_dias_jus int
declare @fecha_hoy datetime
select @n_dias_jus = n_dias_jus from sp_pasi
select @fecha_hoy = getdate()
```

**Intención.** Cargar un parámetro de configuración —`n_dias_jus`, probablemente *días de plazo
para justificar*— y la fecha actual, para usarlos más adelante.

**Qué hace.** Los carga y no los usa nunca. Además `sp_pasi` va sin prefijo de base: se resuelve
en el contexto de sesión, que puede no ser `sisper_db`. Y el `select` no tiene `where`, así que
si la tabla tuviera más de una fila toma una arbitraria.

**Veredicto.** Código muerto. Sugiere que el script se recortó de algo más grande que sí
calculaba plazos de justificación.

---

## Bloque 2 · Validaciones de entrada

```sql
if @rut is null or @cod_periodo is null → error
if not exists (... sisper_db..sp_pers ...) → error
if not exists (... sisper_db..sp_prdo ...) → error
```

**Intención.** No consultar con parámetros vacíos, ni con un funcionario o un periodo que no
existen.

**Qué hace.** Lo correcto, con una grieta: valida la persona contra `sisper_db..sp_pers`, pero
el `SELECT` principal filtra por `ufro_db..sp_pers`. Si alguien está en una y no en la otra,
**pasa la validación y devuelve cero filas sin mensaje**.

**Veredicto.** Bien planteado, mal alineado con la consulta que viene después.

---

## Bloque 3 · Resolución del rango de fechas

```sql
select @inicio = f_inicio, @termino = f_termino from sp_prdo where cod_periodo = @cod_periodo

if (ambas null) or (ambas = 1900/01/01) → ventana de hoy-8 a hoy+7
if @inicio  is null → @termino - 14
if @termino is null → @inicio + 14
```

**Intención.** Traducir un código de periodo a un rango de fechas, con respaldos por si el
periodo está mal cargado.

**Qué hace.** Los tres respaldos son **código muerto**: ninguna fila de `sp_prdo` tiene fechas
nulas ni en 1900. Y el literal `"1900/01/01"` depende del `dateformat` de la sesión.

Hay un problema de fondo mayor: `sp_prdo` es el maestro de **periodos de calificación de
desempeño**, no de asistencia. Sus rangos duran de 5 a 12 meses, se solapan entre sí, y la tabla
no se carga desde 2017.

**Veredicto.** Funciona para lo que fue escrito —una pantalla del módulo de calificaciones— y no
sirve para acotar un mes de ejecución.

---

## Bloque 4 · Tablas temporales

```sql
create table #Ausencias (cod_asist int, res_ausen varchar(60))
create table #asist (13 columnas)
```

**Intención.** `#Ausencias` junta los motivos de ausencia de cada día en un solo texto.
`#asist` es el resultado que se irá completando por pasos.

**Qué hace.** Declara tamaños incompatibles entre sí y con el origen:

| Columna | Tamaño | Origen |
| :--- | :---: | :--- |
| `@res_ausen` (variable) | `varchar(15)` | `sp_eaus.res_ausen` |
| `#Ausencias.res_ausen` | `varchar(60)` | varios motivos concatenados |
| `#asist.res_ausen` | `varchar(30)` | viene del `varchar(60)` |

Y dos columnas quedan `not null` (`hora_e`, `hora_s`) cuando su origen sí admite nulos.

**Veredicto.** El diseño de la temporal es la raíz de dos fallas posteriores: el truncamiento en
cadena y la caída del `INSERT`.

---

## Bloque 5 · Cursor de ausencias

```sql
declare Ausencia cursor for
    select a.cod_asist, f.res_ausen from sp_as01, sp_as21, sp_eaus ...

while ...
   while mismo cod_asist ...
      @tot_ausen = @tot_ausen + "<br>" + @res_ausen
   insert #Ausencias values (@cod_asist2, @tot_ausen)
```

**Intención.** Una asistencia puede tener varias ausencias asociadas. El cursor recorre las
filas, agrupa por `cod_asist` y concatena los motivos en una sola cadena separada por `<br>`.

**Qué hace.** Dos fallas encadenadas:

1. En la primera vuelta `@tot_ausen` es `NULL`, y `NULL + cadena = NULL` en ASE. La variable
   **nunca sale de nula**, así que todas las filas se insertan con `res_ausen = NULL`.
2. El cursor **no tiene `ORDER BY`**. El bucle interno asume que las filas del mismo `cod_asist`
   llegan consecutivas; si el optimizador las entremezcla, el mismo `cod_asist` se inserta
   varias veces y el join posterior duplica días.

**Veredicto.** El bloque completo es inútil hoy: produce una tabla de nulos. Y aunque se
arreglara la concatenación, seguiría siendo frágil por el orden.

---

## Bloque 6 · `INSERT` principal a `#asist`

```sql
insert #asist (...)
select a.cod_asist, datepart(cdw, a.f_ent_o), convert(varchar(10), a.f_ent_o, 103),
       CASE f.ver_hora WHEN "S" THEN hora_ent_o ELSE "T.S.H." END, ...
from sp_as01 a, sp_easi b, ufro_db..sp_pers d, #Ausencias e, sp_turn f, sp_as31 g
where a.cod_estasi = b.cod_estasi
  and g.cod_asist =* a.cod_asist
  and a.rut = @rut and d.rut = a.rut
  and a.f_ent_o between @inicio and @termino
  and f.cod_turno = a.cod_turno
  and e.cod_asist =* a.cod_asist
```

**Intención.** El corazón del script. Por cada día del rango trae la marca real, el horario del
turno, el estado de asistencia y el motivo de ausencia. El `CASE` oculta la hora cuando el turno
no expone marcaje (`ver_hora <> 'S'`).

**Qué hace.** Aquí se concentran cinco problemas:

- **`sp_as31 g`** se une y **no se usa**. Con 3 justificaciones en un día, ese día sale 3 veces.
- **`ufro_db..sp_pers d`** se une y tampoco se usa. Siendo join interno, filtra de más.
- **`sp_turn f` es join interno.** Un día con `cod_turno` nulo o huérfano **desaparece**.
- **`"T.S.H."` son 6 caracteres** en un `char(5)`: queda `"T.S.H"`.
- **`hora_ent_o` nula** hace que el `convert` devuelva `NULL` contra una columna `not null`:
  falla el `INSERT` entero, no la fila.

El `CASE` sobre `ver_hora` además mete una decisión de negocio en la capa de datos: reemplaza el
dato por un literal en vez de devolver la bandera y dejar que el consumidor decida.

**Veredicto.** La consulta es correcta en intención y tiene dos joins de sobra que la vuelven
no determinista.

---

## Bloque 7 · `UPDATE` de justificaciones

```sql
update #asist set excusa = des_tipjus + "/" + des_catjus
from #asist a, sp_as31 b, sp_cjus y, sp_tjus x
where b.cod_asist = a.cod_asist and ...
```

**Intención.** Agregar a cada día el tipo y la categoría de su justificación.

**Qué hace.** Si hay varias justificaciones para el mismo día, `UPDATE...FROM` con múltiples
coincidencias en ASE aplica **una cualquiera**, sin criterio y sin garantía de repetibilidad.
Las demás se pierden.

Nótese que `sp_as31` ya venía unida en el bloque 6 —ahí sin usarse— y aquí se vuelve a unir.

**Veredicto.** Debió resolverse igual que las ausencias: agrupando todas, no quedándose con una.

---

## Bloque 8 · Nombres de día de la semana

```sql
update #asist set diasem = "Lunes"   where ndia = 1
update #asist set diasem = "Martes"  where ndia = 2
... siete sentencias
```

**Intención.** Traducir el número de día a su nombre.

**Qué hace.** Siete pasadas completas sobre la temporal donde bastaría un `CASE` en el `SELECT`
original.

Y hay un supuesto sin verificar: `ndia` viene de `datepart(cdw, ...)`, que devuelve el día
**relativo al primer día de la semana del servidor** (`@@datefirst`). Si esa configuración tiene
domingo como día 1 —el valor por defecto en muchas instalaciones— entonces `ndia = 1` es domingo
y **los siete nombres quedan corridos**.

**Veredicto.** Ineficiente y posiblemente incorrecto. Se verifica con `select @@datefirst`.

---

## Bloque 9 · `UPDATE` de feriados

```sql
update #asist set feriado = des_tipfer
from #asist z, ufro_db..es_cfer a, ufro_db..es_tfer b
where a.cod_tipfer = b.cod_tipfer
  and f_ent_o = f_feriado
```

**Intención.** Marcar los días que caen en feriado o receso institucional. Es el dato que el WF
de pagos necesita para acreditar trabajo durante receso.

**Qué hace.** `f_ent_o` es `datetime` con la hora de entrada; `f_feriado` es una fecha a
medianoche. La igualdad sólo se cumple si alguien marcó exactamente a las 00:00:00.

**En la práctica la columna sale siempre nula.**

Además el `update` no filtra `es_cfer` por nada más que la fecha: si el calendario tiene entradas
por sede o unidad, todas coinciden.

**Veredicto.** No funciona. Y es justo la columna que más importa para pagos.

---

## Bloque 10 · `SELECT` final

```sql
select diasem, feriado, fecha, hora_e, hora_s, m_ent, m_sal,
       res_ausen, excusa, cod_estasi, des_estasi
from #asist order by f_ent_o
```

**Intención.** Devolver el detalle diario listo para pintar en pantalla.

**Qué hace.** Devuelve once columnas de las cuales **tres vienen siempre vacías**: `res_ausen`
(bloque 5), `feriado` (bloque 9) y potencialmente `diasem` (bloque 8).

No incluye `cod_asist`, así que el consumidor no puede correlacionar una fila con nada. Y `fecha`
va en formato `dd/mm/yyyy`, que no es ordenable ni parseable sin ambigüedad.

**Veredicto.** La forma del resultado es la adecuada; el contenido está a medias.

---

## Bloque 11 · Limpieza

```sql
drop table #asist
drop table #Ausencias
```

**Qué hace.** Innecesario dentro de un procedimiento: ASE descarta las temporales al salir. Y si
algo falla antes, no se ejecuta.

---

## Panorama

| Bloque | Intención | Estado |
| :--- | :--- | :--- |
| 1 · Parámetros globales | cargar configuración | ⚫ código muerto |
| 2 · Validaciones | proteger la entrada | 🟡 valida otra tabla |
| 3 · Rango de fechas | traducir periodo a rango | 🟡 fuente de otro dominio |
| 4 · Temporales | estructura de trabajo | 🔴 tamaños y `not null` mal |
| 5 · Cursor de ausencias | agrupar motivos | 🔴 produce sólo nulos |
| 6 · `INSERT` principal | traer el detalle diario | 🔴 duplica y puede fallar |
| 7 · Justificaciones | agregar la excusa | 🟡 se queda con una |
| 8 · Día de la semana | traducir el número | 🟡 posible corrimiento |
| 9 · Feriados | marcar receso | 🔴 nunca coincide |
| 10 · `SELECT` final | devolver el detalle | 🟡 tres columnas vacías |
| 11 · Limpieza | liberar temporales | ⚫ innecesario |

**La estructura del script es la correcta**: trae el detalle diario, lo enriquece por pasos y lo
devuelve. Lo que falla es la implementación de tres de esos pasos —ausencias, feriados y días de
la semana— más dos joins de sobra en la consulta central.

De los once bloques, sólo el 6 hace trabajo real; los bloques 5, 7, 8 y 9 son enriquecimientos
que se resuelven mejor dentro del mismo `SELECT`, que es lo que hace el PA reescrito.
