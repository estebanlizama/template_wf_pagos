# PA de compensación realizada — `sg_fuc2`

Compensación que el funcionario **efectivamente hizo**, por mes de ejecución. Es el espejo de la
comprometida (`sg_fuco`) con una dimensión más: el `corr_fume`.

| PA | Qué hace |
| :--- | :--- |
| `sg_fuc2sSecgen01` | Lista las realizadas de una solicitud, opcionalmente por funcionario y mes |
| `sg_fuc2iSecgen01` | Registra un tramo |
| `sg_fuc2dSecgen01` | Elimina los tramos de un mes, o uno puntual por fecha |

`sg_fucosSecgen01` se reutiliza **sin modificarlo** para traer lo comprometido. Lista por solicitud
sin filtrar por mes, porque `sg_fuco` no tiene esa dimensión.

---

## La fecha lleva la hora incrustada

Igual que `sg_fuco`. El PA guarda en `fec_comrea` el día **más los minutos de la hora de inicio**, y
el de lectura la trunca de vuelta:

```sql
@inicio_dt = dateadd(minute, minutos(@hora_ini), dia(@fec_comrea))
insert into sg_fuc2 (..., fec_comrea, ...) values (..., @inicio_dt, ...)
```

Sin eso la PK `(id_funprse, corr_fume, fec_comrea)` solo admitiría **un tramo por día**, y compensar
dos horas en la mañana y dos en la tarde es un caso normal.

---

## Qué valida la inserción

Heredado de `sg_fucoiSecgen01`:

1. Datos completos
2. Modalidad DU288
3. `dentro_jor in ('S', 'D')` — quien ejecuta fuera de jornada no compensa
4. Horas de inicio y término distintas
5. El tramo cae dentro de `f_inicio`–`f_termino`
6. No es feriado nacional (`es_cfer`, `cod_tipfer = 1`)
7. No se superpone con otro tramo **realizado** de la persona, de cualquier mes

Propio del pago:

8. **El rut es responsable vigente del centro de costo.** `sg_fucoiSecgen01` no lo comprueba porque
   la autorización de resolución vive en el backend. El módulo de pagos la resuelve en el PA, igual
   que `sg_fupssSecgen18`, para que la escritura no dependa de que quien llame se acuerde.
9. **El mes admite cambios** — `cod_estfum = 1`, o `2` con su cuota en `3 Observada`.
10. **No se superpone con lo comprometido** en `sg_fuco`.
11. **No cae en jornada institucional** — lunes a viernes 08:30–17:18 (RES-JO-07).

> **8, 9, 10 y 11 son más estrictas que el PA de resolución.** Las cuatro son correctas y la
> asimetría favorece al pago, pero conviene saberla: un tramo que resolución habría aceptado puede
> ser rechazado acá.
>
> La 11 estaba solo en el frontend (`compensationOverlapsInstitutionalWorkday`). Bajarla al PA la
> vuelve inevitable. La función evalúa el **solapamiento** con la jornada, y solapar es el error:
> la compensación va **fuera** de 08:30–17:18.

El día de la semana se obtiene con `datediff(day, '19000101', fecha) % 7` — 1900-01-01 fue lunes —
para no depender de `@@datefirst`, que es configuración de sesión.

---

## Qué valida el borrado

Las mismas 8 y 9. Y el `delete` va acotado a `(id_funprse, corr_fume)`:

```sql
delete from sg_fuc2 where id_funprse = @id_funprse and corr_fume = @corr_fume
```

`sg_fucodSecgen01` borra **todos** los tramos del funcionario de un viaje, porque el guardado de
resolución es borrar-todo-y-reinsertar. Acá eso arrasaría meses ya comprometidos en una cuota
enviada.

Con `@fec_comrea` borra solo los tramos de ese día, para quitar uno sin rehacer el mes.

---

## Contrato de retorno

Los PA de mutación siguen §6 del estándar:

```sql
-- exito
select 1 as status, 'OK' as code, '<texto>' as msg

-- error
select '<texto>' as msg
```

El backend distingue por **`status = 1`**, no por el texto. Los mensajes de error vienen ya
redactados para el usuario final y **sin nombres de tabla**, así que se propagan tal cual en un 422.

Los PA de lectura no devuelven `msg` en el camino normal: solo al abortar, y en ese caso la fila
no trae las columnas de datos.

---

## Lo que estos PA no resuelven

**La comparación con lo comprometido.** Un tramo válido se acepta aunque las horas del mes no
sumen lo comprometido. Esa es una validación de **envío de la cuota**, no de registro de un tramo,
y el envío todavía no existe. Queda como PAG-38, pendiente de definir si bloquea o solo advierte.

**Si el tramo debe caer dentro del mes de su `corr_fume`.** Hoy no se exige: trabajó el 30 de
septiembre y compensa el 2 de octubre, y el PA lo acepta en el `corr_fume` de septiembre. Se eligió
la opción permisiva porque la restrictiva deja sin registrar una compensación a caballo entre dos
meses. Si se decide lo contrario es un `if` más, antes de la verificación de feriado.

---

## Despliegue

```
1. sg_fuc2sSecgen01
2. sg_fuc2iSecgen01
3. sg_fuc2dSecgen01
4. Backend
```

Los tres son independientes entre sí y no tocan nada existente: `sg_fuc2` está vacía y ningún
flujo la consulta hoy.
