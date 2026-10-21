# Revisión: compensación duplicada, extensión y cuotas

Caso real: prestación de SERGIO DELGADO (`06706447K`), resolución 205/2026,
centro de costo 9010-5. Tipo de monto **Variable**, 12 cuotas decretadas,
modalidad **Dentro de jornada**, período 01/01/2016 – 31/12/2016.

Fecha: 20-10-2026. Solo análisis, sin cambios de código.

---

## 1. El error de compensación duplicada — es de la vista, no del PA

**Síntoma.** En *Compensación horaria · Abril 2016*, día 13/04: el panel muestra
el tramo ya informado (`17:18 – 23:59`, 6 h 41 min) **y además** ofrece
*"Confirmar como realizado"* sobre el tramo comprometido idéntico. Al pulsarlo:
*"Error: El tramo de compensacion esta duplicado o superpuesto"*.

**El PA tiene razón.** `sg_fuc2iSecgen01` (y su gemelo DGDP `sg_fuc2iSecgen02`)
rechazan cualquier tramo que se solape con uno ya registrado ese día. Confirmar
ese comprometido insertaría un duplicado exacto del que ya existe.

**La vista es la que está mal.** El botón se ofrece con esta condición
(`Du288ExecutedCompensationSection.vue:206`):

```
v-if="!readOnly && duration(item) <= remainingMinutes"
```

`remainingMinutes` es un saldo **del mes** — comprometido menos informado. En
abril: 26 h 44 min − 13 h 22 min = 13 h 22 min. El tramo mide 6 h 41 min, cabe en
el saldo del mes, y el botón aparece. Pero el saldo del mes no dice nada sobre
**ese día**, que ya está cubierto.

**Y el componente ya sabe la respuesta.** La lista *Comprometida en la
resolución* marca con ✓ los días 06/04 y 13/04 usando `item.exactMatch`
(`línea 67`). Ese dato existe y el botón no lo consulta. De ahí que el ✓ y el
botón se contradigan en la misma pantalla.

**Dónde está el arreglo.** Agregar a la condición del botón la comprobación de
que ese tramo no esté ya informado ese día — el componente tiene
`selectedExecutedRanges` (`línea 378`) con los tramos informados de la fecha
seleccionada, así que no hay que traer nada nuevo. La regla es de día y de
tramo, no de mes.

> Esto es independiente de los montos y de la cuota: es solo la UI de
> compensación, y aplica igual en la vista del solicitante y en la de DGDP.

---

## 2. "Extensión de cuotas autorizada" aparece Sí y No en la misma pantalla

En los datos del caso:

| Bloque | Valor |
| :--- | :--- |
| *Prestación autorizada* | **Sí** |
| *Centro de costo* | **No** |

Es el mismo rótulo con dos valores, porque son **dos computed distintos leyendo
fuentes distintas**:

| Componente | Computed | De dónde lee |
| :--- | :--- | :--- |
| `Du288PaymentContextSection` (`línea 190`) | `hasExtension()` | `activeStaff`: `hasInstallmentExtension`, `hasExtension`, `installmentExtensionIndicator`, `extCuotas` |
| `Du288PaymentBudgetSection` (`línea 223`) | `isExtensionAuthorized()` | `installment`: `installmentExtension`, `conTopdu9`, `con_topdu9`; y `context.request` |

El segundo se apoya en la **cuota**, y en este caso no hay ninguna ("Sin cuotas
enviadas"), así que cae a falso aunque la prestación sí tenga la extensión.

Hay además una conflación que conviene mirar aparte: `isExtensionAuthorized`
acepta `conTopdu9` / `con_topdu9` como si fueran la extensión. *Con tope DU09* y
*extensión de cuotas autorizada* no son lo mismo; que uno implique al otro habría
que confirmarlo con la norma antes de dejarlo así.

**Qué conviene decidir:** cuál es la fuente de verdad —la prestación
(`sg_fups.ext_cuotas`) o la cuota— y que los dos bloques lean esa. Hoy el usuario
ve una contradicción en una misma pantalla.

---

## 3. Por qué no deja avanzar con los tres primeros meses

Los tres meses **sí** están seleccionados (Enero, Febrero y Marzo marcados
*Incluido en esta cuota*, "Ejecución: 3 de 12 meses"). Lo que bloquea es otra
cosa, y hay dos candidatos independientes:

### a) La validación presupuestaria da "No disponible"

```
Ítem 306 - No Académicos
Monto solicitado   $12.024.252
Saldo disponible   $0
Saldo remanente   -$12.024.252
Estado             No disponible
Mensaje            El centro de costo no tiene fondos disponibles
```

El centro de costo 9010-5 tiene saldo **$0**. Mientras eso siga así, ninguna
cuota de esta prestación va a poder validarse, con independencia de los meses que
se elijan. Es dato del ambiente (`fin21_db..es_ecct`), no del flujo.

### b) La regla de pérdida evitable

El panel dice:

> Quedan sin pagar $10.024.252: las cuotas de esta prestación pagan $2.000.000 de
> los $12.024.252 decretados.
> Puede evitarlo: devuelva cada mes a su monto decretado y deje el que no entra
> para una cuota nueva.

Esa es la regla que exige redistribuir cuando el dinero es recuperable, y con 12
cuotas autorizadas y 9 meses libres **lo es**, así que bloquea el guardado. Es el
comportamiento buscado.

Pero el texto se contradice consigo mismo dos líneas más abajo: dice *"quedan sin
pagar $10.024.252"* y acto seguido *"9 meses quedan para la cuota siguiente"*. Si
quedan para la cuota siguiente, no están sin pagar. El mensaje debería distinguir
**lo que se pospone** de **lo que se pierde**; hoy nombra todo como pérdida y eso
es justo lo que confunde al usuario que intenta avanzar.

### Y un dato que no cuadra con el tipo de monto

*Tipo de monto: **Variable*** con *Tope mensual: **$0***. Con tope 0, cualquier
validación que compare el monto del mes contra el tope va a fallar. Hay que
confirmar si en variable el tope simplemente no aplica (y entonces no debería
mostrarse como $0) o si falta el dato.

---

## 4. Lo que hay que confirmar antes de tocar nada

1. **Compensación:** ¿confirmar un tramo comprometido debe estar prohibido cuando
   el día ya tiene ese mismo tramo informado, o debe reemplazarlo? Lo primero es
   lo que hace el PA hoy.
2. **Extensión:** ¿la fuente de verdad es la prestación o la cuota? ¿Y `con_topdu9`
   implica extensión?
3. **Tope mensual en monto variable:** ¿no aplica, o falta el dato?
4. **Saldo del centro de costo 9010-5 en $0:** ¿es el estado real del ambiente de
   pruebas o es un problema de datos? Define si el caso sirve para probar el
   flujo completo.

---

## 5. Compensación registrada dos veces — las dos vías

### a) Dentro de la misma prestación: el botón queda clicable

Tras un *Confirmar como realizado* exitoso, el botón **no desaparece**: su
condición sigue siendo solo `duration(item) <= remainingMinutes`, y el saldo del
mes todavía da. Así que un segundo clic reenvía exactamente el mismo payload.

Y `confirmCommittedRange` (`línea 502`) no se protege por su cuenta: arma el
payload y hace `$emit('save', ...)` sin mirar si ese tramo ya está informado. El
`:disabled="saving"` solo cubre la ventana del request en curso, no el estado
posterior.

Es la misma raíz del §1: la condición del botón mira un saldo mensual donde
debería mirar el día y el tramo.

### b) Entre prestaciones distintas: el PA no lo controla

Este es el hueco de fondo. El control de solapamiento de `sg_fuc2iSecgen01`
está acotado a la prestación:

```sql
if exists (
    select 1
    from secgen_db.dbo.sg_fuc2 fc
    where fc.id_funprse = @id_funprse      /* <-- solo esta prestacion */
      and @inicio_dt < ...                 /* solapamiento horario */
```

**Consecuencia:** un mismo funcionario con dos prestaciones vigentes —en centros
de costo distintos— puede registrar **las mismas horas de compensación en las
dos**. Cada PA mira su propio `id_funprse` y ninguno ve al otro. Nadie compensa
la misma hora dos veces en la realidad, pero el sistema hoy lo acepta.

El dato para cerrarlo ya está: `sg_fuc2` cuelga de `id_funprse`, y
`sg_fups.rut` identifica a la persona. El control tendría que subir de la
prestación al RUT:

```sql
from secgen_db.dbo.sg_fuc2 fc
inner join secgen_db.dbo.sg_fups fu on fu.id_funprse = fc.id_funprse
where fu.rut = (select rut from secgen_db.dbo.sg_fups where id_funprse = @id_funprse)
  and ...  /* mismo solapamiento horario */
```

Y del lado de la vista, el modal debería **mostrar los tramos compensados ese mes
en las otras prestaciones**, en solo lectura. Si no, el usuario recibe un bloqueo
sin explicación: ve su día vacío y el sistema le dice que está ocupado.

### Lo que hay que decidir antes

1. **¿Bloquea o advierte?** Subir el control al RUT es correcto en lo normativo,
   pero endurece el flujo: una compensación de otra prestación va a impedir
   registrar en esta. Hay que confirmar que es lo que se quiere, y no una alerta.
2. **¿Qué alcance tiene "las otras prestaciones"?** ¿Todas las vigentes del RUT,
   o solo las del mismo período? Lo segundo es más barato de consultar y
   probablemente suficiente.
3. **¿Y lo ya cargado?** Si el control sube al RUT, conviene contar primero
   cuántos solapamientos existen hoy entre prestaciones, porque pasarían a ser
   datos inconsistentes:

```sql
select fu1.rut, fc1.id_funprse, fc2.id_funprse, fc1.fec_comrea,
       fc1.hora_ini, fc1.hora_ter, fc2.hora_ini, fc2.hora_ter
  from secgen_db.dbo.sg_fuc2 fc1
 inner join secgen_db.dbo.sg_fups fu1 on fu1.id_funprse = fc1.id_funprse
 inner join secgen_db.dbo.sg_fups fu2 on fu2.rut = fu1.rut
                                     and fu2.id_funprse <> fu1.id_funprse
 inner join secgen_db.dbo.sg_fuc2 fc2 on fc2.id_funprse = fu2.id_funprse
                                     and fc2.fec_comrea = fc1.fec_comrea
 where fc1.hora_ini < fc2.hora_ter
   and fc2.hora_ini < fc1.hora_ter
 order by fu1.rut, fc1.fec_comrea
```

*(Sin el ajuste de tramos que cruzan medianoche, que el PA sí hace: sirve para
dimensionar, no como control definitivo.)*

---

## 6. Recomendación por caso

| # | Caso | Recomendación | Dónde | Bloqueado por |
| :-- | :--- | :--- | :--- | :--- |
| 1 | Botón ofrece confirmar un tramo ya informado | Arreglar ahora | Vista | — |
| 2 | Compensación duplicada entre prestaciones | Arreglar, después de contar lo existente | PA | Decisión: ¿bloquea o advierte? |
| 3 | "Extensión autorizada" Sí y No a la vez | Arreglar ahora | Vista | — |
| 4 | Texto que llama "perdido" a lo pospuesto | Arreglar después de 1 y 3 | Vista | — |
| 5 | Tope mensual $0 en monto variable | **No tocar** hasta confirmar la norma | — | Decisión normativa |
| 6 | Saldo $0 del centro de costo 9010-5 | Dato de ambiente, no código | Datos | — |

### 1 · Espejar la regla del PA, no inventar una nueva

El PA no rechaza solo el duplicado exacto: rechaza **cualquier solapamiento** en
el día. La condición del botón tiene que decir lo mismo, o va a seguir ofreciendo
acciones que el backend rechaza — por ejemplo un comprometido de 17:18–23:59
cuando ya hay informado 17:18–20:00, que no es duplicado pero sí se solapa.

Entonces: ocultar el botón cuando el tramo comprometido **se solapa** con alguno
de `selectedExecutedRanges`, no cuando es idéntico. Y agregar la misma guarda
dentro de `confirmCommittedRange`, para que el doble clic no dependa del render.

No hay decisión funcional pendiente: el PA ya decidió, la vista solo tiene que
dejar de contradecirlo.

### 2 · Subir el control al RUT, y que bloquee

**Que bloquee, no que advierta.** Compensar la misma hora dos veces es
físicamente imposible; no es una preferencia de flujo. Y una advertencia en la
vista no protege el dato: el PA es el único punto por el que pasan todas las
escrituras.

**Primero el PA, después la vista.** El control por RUT cierra el agujero; el
listado de las otras prestaciones en el modal lo hace entendible. Lo segundo
necesita PA de lectura y endpoint nuevos — no conviene retrasar lo primero
esperándolo, pero sí hay que hacerlo, porque un bloqueo sin explicación es peor
que el bug para quien lo sufre.

**Alcance: todas las prestaciones del RUT.** No hace falta acotar por período: el
control ya compara por fecha y hora, así que la fecha hace el filtro sola.

**Antes de desplegar, contar.** La consulta del §5 dimensiona cuántos
solapamientos hay hoy. El riesgo de migración es bajo —el control es de
inserción, las filas existentes no se tocan— pero si el número es alto conviene
saber por qué antes de cerrar la puerta.

### 3 · Fuente de verdad: la prestación

La extensión la autoriza la **resolución para el funcionario**, no la cuota. Así
que `Du288PaymentBudgetSection.isExtensionAuthorized()` debe leer lo mismo que
`Du288PaymentContextSection.hasExtension()`, que ya va a `activeStaff`. Hoy el
primero depende de que exista una cuota, y por eso dice "No" cuando todavía no
hay ninguna.

Y **sacar `con_topdu9` de esa condición**. Es otro concepto; si la norma dice que
el tope DU09 implica extensión, que se documente y se agregue explícitamente, no
por arrastre.

### 4 · Separar lo pospuesto de lo perdido

El mensaje debe distinguir dos situaciones que hoy nombra igual:

- **hay cuotas y cupo por delante** → "queda para cuotas siguientes"; no es
  pérdida, y el usuario no tiene que corregir nada todavía;
- **no quedan cuotas, o el monto excede el tope** → "se pierde"; ahí sí la regla
  debe exigir redistribuir.

La lógica ya está (`resolvePaymentDroppedAmount` / `isPaymentLossAvoidable`): lo
que falla es que el texto trata los dos casos como pérdida. Va después de 1 y 3
porque es el más fácil de malinterpretar al redactarlo y conviene hacerlo con la
pantalla ya limpia.

### 5 · No tocar sin respuesta

Si en monto variable el tope no aplica, mostrar "$0" es engañoso y cualquier
validación contra ese 0 bloquea pagos legítimos. Si sí aplica, el dato falta y el
problema es de carga. **Adivinar en cualquiera de los dos sentidos tiene costo
real**, así que corresponde preguntar antes de escribir código.

### 6 · Confirmar si es del ambiente

El centro de costo 9010-5 con saldo $0 impide validar cualquier cuota de esta
prestación. Si es del ambiente de pruebas, hay que cargarle saldo o elegir otro
centro para probar. Si también está así en producción, no es un problema de
pruebas y hay que escalarlo.
