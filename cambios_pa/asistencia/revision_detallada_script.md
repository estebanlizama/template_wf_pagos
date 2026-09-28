# Revisión detallada del script de asistencia

Repaso línea por línea del script recibido. Ordenado por severidad.

---

## 🔴 Rompe la ejecución

### R1 · Un día sin hora marcada aborta todo el `INSERT`

```sql
create table #asist (
    ...
    hora_e  char(5) not null,
    hora_s  char(5) not null,
```

`hora_e` se llena con `convert(varchar(5), a.hora_ent_o, 108)`. Si `hora_ent_o` es `NULL` —
una inasistencia, una licencia, un día sin marca— el `convert` devuelve `NULL` y el `insert`
falla con *"does not allow null values"*.

**No falla esa fila: falla el `INSERT` completo.** Un solo día sin marca en el rango deja la
consulta sin resultado.

Es probablemente el motivo por el que alguien cubrió el caso con el literal `"T.S.H."`, pero esa
rama sólo cubre `ver_hora <> 'S'`, no la hora nula.

---

## 🔴 Devuelve datos incorrectos

### R2 · El cursor de ausencias nunca acumula

```sql
if @tot_ausen is not null
   select @tot_ausen = @tot_ausen + "<br>" + @res_ausen
else
   select @tot_ausen = @tot_ausen + @res_ausen
```

En la rama `else`, `@tot_ausen` vale `NULL`. En ASE, `NULL + cadena = NULL`. La variable
**nunca deja de ser nula**, así que `#Ausencias.res_ausen` queda vacío en todas las filas y la
columna `res_ausen` del resultado final siempre viene `NULL`.

La línea correcta es `select @tot_ausen = @res_ausen`.

### R3 · El cursor no tiene `ORDER BY`

```sql
declare Ausencia cursor for
    select a.cod_asist, f.res_ausen
    from ... where ...
    -- sin order by
```

El bucle interno asume que las filas del mismo `cod_asist` llegan **consecutivas**. Sin
`order by a.cod_asist`, el optimizador puede devolverlas entremezcladas, y entonces el mismo
`cod_asist` se inserta varias veces en `#Ausencias` con fragmentos distintos.

Eso además rompe el `left join` posterior: `#Ausencias` deja de tener una fila por asistencia y
**duplica** el resultado final.

### R4 · Dos tablas unidas que multiplican filas

```sql
from sisper_db..sp_as01 a, sisper_db..sp_easi b, ufro_db..sp_pers d,
     #Ausencias e, sisper_db..sp_turn f, sisper_db..sp_as31 g
```

`sp_as31 g` está en el `FROM`, se une con `g.cod_asist =* a.cod_asist`, y **no se usa ninguna
columna suya**. Si una asistencia tiene 3 justificaciones, ese día aparece **3 veces** en el
resultado.

La justificación se vuelve a unir después en un `update`, así que el join es puramente
accidental.

### R5 · `datepart(cdw, ...)` depende de la configuración de sesión

```sql
datepart(cdw, a.f_ent_o) "dia"
...
update #asist set diasem = "Lunes" where ndia = 1
```

`cdw` devuelve el día relativo al primer día de la semana del servidor (`@@datefirst`). Si esa
configuración tiene **domingo como día 1** —que es el valor por defecto en muchas instalaciones—
entonces `ndia = 1` es domingo y **los siete nombres quedan corridos**.

Hay que verificarlo con `select @@datefirst`, o usar `datename(dw, ...)` que no depende de eso.

### R6 · El feriado nunca coincide si hay hora

```sql
where a.cod_tipfer = b.cod_tipfer
and f_ent_o = f_feriado
```

`f_ent_o` es `datetime` y trae hora de entrada. `f_feriado` es una fecha a medianoche. La
igualdad sólo se cumple si la marca fue exactamente a las 00:00:00.

En la práctica **la columna `feriado` sale siempre nula**.

### R7 · La validación mira una tabla y la consulta filtra por otra

```sql
-- Valida contra:
if not exists (select 1 from sisper_db..sp_pers where rut_person = @rut)

-- Pero filtra por:
from ... ufro_db..sp_pers d ... and d.rut = a.rut
```

Son dos tablas de personas distintas, en bases distintas. Un funcionario que existe en
`sisper_db` pero no en `ufro_db` **pasa la validación y devuelve cero filas**, sin ningún
mensaje que explique por qué.

Además `d` es un join interno y no se usa ninguna de sus columnas.

---

## 🟡 Pérdida silenciosa de datos

### R8 · `sp_turn` como join interno descarta días

```sql
and f.cod_turno = a.cod_turno
```

Es un `INNER JOIN`. Un día cuyo `cod_turno` sea nulo, o que apunte a un turno que ya no existe
en `sp_turn`, **desaparece del resultado** sin aviso. Justo los días atípicos son los que más
importan al validar cumplimiento.

### R9 · Cinco truncamientos por tamaño de columna

| Destino | Tamaño | Origen | Riesgo |
| :--- | :---: | :--- | :--- |
| `@res_ausen` | `varchar(15)` | `sp_eaus.res_ausen` | alto |
| `#Ausencias.res_ausen` | `varchar(60)` | acumulado de varias ausencias | alto |
| `#asist.res_ausen` | `varchar(30)` | viene de `varchar(60)` | **seguro** |
| `#asist.excusa` | `varchar(40)` | `des_tipjus + '/' + des_catjus` | medio |
| `#asist.hora_e` | `char(5)` | el literal `"T.S.H."` son 6 caracteres | **seguro** |

El tercero es el peor: `#Ausencias` guarda hasta 60 caracteres y `#asist` los recorta a 30, sin
error. Y el último convierte `"T.S.H."` en `"T.S.H"`.

### R10 · La justificación se queda con una arbitraria

```sql
update #asist set excusa = des_tipjus + "/" + des_catjus
from #asist a, sisper_db..sp_as31 b, ...
where b.cod_asist = a.cod_asist
```

Si una asistencia tiene varias justificaciones, un `UPDATE...FROM` con múltiples coincidencias
en ASE aplica **una cualquiera**, de forma no determinista. Las demás se pierden y el resultado
no es reproducible entre ejecuciones.

### R11 · `es_cfer` sin filtro de alcance

El `update` de feriados no filtra `es_cfer` por nada más que la fecha. Si el calendario tiene
entradas por sede, campus o unidad, **todas coinciden** y el `update` aplica una arbitraria.

---

## 🔵 Higiene y compatibilidad

### R12 · No es un procedimiento

El archivo empieza con las variables comentadas como *"Variables de entrada"*. No hay
`create procedure`, ni bloque `if exists ... drop`, ni `grant execute`. Es un script suelto.

### R13 · Falta `set nocount on`

Sin eso, cada `insert`, `update` y `create table` intermedio emite un mensaje de conteo. Los
drivers que consumen un solo result set —el bridge de Node incluido— reciben resultados
adicionales antes del que interesa.

Para consumirlo desde el backend, esto no es opcional.

### R14 · Dos variables muertas

```sql
declare @n_dias_jus int
declare @fecha_hoy datetime
select @n_dias_jus = n_dias_jus from sp_pasi
select @fecha_hoy = getdate()
```

Ninguna se usa después. Además `sp_pasi` va **sin prefijo de base**: se resuelve en el contexto
actual, que puede no ser `sisper_db`. Y el `select` no tiene `where`, así que si la tabla tiene
más de una fila toma una arbitraria.

### R15 · Respaldos que nunca se ejecutan

```sql
if (@inicio is null and @termino is null) or (@inicio = "1900/01/01" ...)
```

Ninguna fila de `sp_prdo` tiene fechas nulas ni en 1900. Es código muerto. Y el literal
`"1900/01/01"` depende del `dateformat` de la sesión; lo seguro es `'19000101'`.

### R16 · Formato de fecha de presentación

```sql
convert(varchar(10), a.f_ent_o, 103) "fecha"
```

Formato 103 es `dd/mm/yyyy`: no es ordenable ni parseable sin ambigüedad. Para una API conviene
ISO (`112` → `yyyymmdd`) y que el formato lo aplique la capa de presentación.

### R17 · `<br>` dentro del dato

El separador HTML no pertenece a la base. Las reglas de estandarización del proyecto prohíben
devolver presentación desde un PA.

### R18 · Sintaxis `=*` mezclada con joins internos

Mezclar el outer join antiguo `=*` con predicados internos en el mismo `WHERE` produce
resultados que dependen del orden de evaluación. Sybase la marcó obsoleta justamente por eso;
en ASE 12.5 ya está disponible `LEFT JOIN`.

### R19 · El resultado no trae `cod_asist`

El `select` final devuelve once columnas, ninguna de las cuales identifica el registro de
asistencia. El consumidor no puede correlacionar una fila con nada.

---

## Resumen

| Severidad | Cantidad | Efecto |
| :--- | :---: | :--- |
| 🔴 Rompe o falsea | 7 | `res_ausen` y `feriado` siempre nulos · días duplicados · días de semana posiblemente corridos · cero filas si falta en `ufro_db..sp_pers` · falla total si hay una hora nula |
| 🟡 Pérdida silenciosa | 4 | días descartados · textos truncados · justificación arbitraria |
| 🔵 Higiene | 8 | no es PA · sin `set nocount` · código muerto · presentación en el dato |

**Tres columnas del resultado están efectivamente inservibles hoy:** `res_ausen` (R2), `feriado`
(R6) y potencialmente `diasem` (R5). Son justamente las que el WF de pagos necesita para
acreditar trabajo en receso y ausencias justificadas.

El PA reescrito en `sp_as01sSecgen01.sql` corrige R1–R19, salvo los puntos que requieren
confirmar datos del ambiente: `@@datefirst` (R5), el alcance de `es_cfer` (R11) y la
cardinalidad de `sp_as31` (R4, R10).
