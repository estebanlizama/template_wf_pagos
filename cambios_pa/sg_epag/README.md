# PA del encabezado de cuota — `sg_epag` / `sg_dpag`

Gestión de cuotas del **jefe de proyecto** y revisión de **DGDP**. Los PA existentes del jefe de
proyecto autorizan contra `fin21_db..es_ecct`; los PA DGDP
`sg_epagsSecgen03/04/05` y `sg_epaguSecgen03/04/05` verifican contrato activo más `sp_orde.cod_organi = 696`, RUT autenticado
coincidente y `vigente = 'S'`. El RUT llega del token.

| PA | Qué hace | Estados que admite |
| :--- | :--- | :--- |
| `sg_epagsSecgen01` | Lista las cuotas de una resolución con su total y período, usando columnas de `sg_epag` definidas en la BDD | — lectura |
| `sg_epagiSecgen01` | Crea el encabezado en **1 Propuesta** y le asocia meses | — |
| `sg_epaguSecgen01` | Edita mes de pago, respaldo y el conjunto de meses | 1, 3 |
| `sg_epagdSecgen01` | Elimina el borrador y libera sus meses | 1 |
| `sg_epaguSecgen02` | **Envía** a visación: `→ 2` y compromete los meses | 1, 3 |
| `sg_epagsSecgen03` | Bandeja DGDP: cuotas por estado | 2, 3, 4, 8, 10, 11 |
| `sg_epagsSecgen04` | Detalle DGDP: meses de una cuota | 2, 3, 4, 8, 10, 11 |
| `sg_epagsSecgen05` | Datos SISPER por mes/asignación y centro de costo para el Excel de Finanzas | 4, 8 |
| `sg_epaguSecgen03` | Aprobar, observar o rechazar y actualizar el estado de la cuota | 2 |
| `sg_epaguSecgen04` | **Registrar el envío a Finanzas**: cierra la cuota en 8 y sus meses en 3 | 4 |
| `sg_epaguSecgen05` | Devuelve una cuota aprobada a visación DGDP, con motivo auditado | 4 → 2 |

---

## Qué mueve cada estado

```
      sg_epag.cod_estcuo              sg_fume.cod_estfum
 ──────────────────────────────────────────────────────────
  crear      →  1 Propuesta            sin cambio (sigue 1)
  enviar     →  2 En visación          1 → 2 Comprometida
  observar   →  3 Observada            sin cambio (sigue 2)
  reenviar   →  2 En visación          sin cambio (ya está 2)
  rechazar   → 10 Rechazada            2 → 4 Rechazada (bloqueados)
  aprobar    →  4 Aprobada             sin cambio
  devolver aprobada → 2 En visación     sin cambio (meses siguen en 2)
  enviar rem →  8 Enviada remun.       2 → 3 Enviada a pago
```

`sg_epaguSecgen03` cubre aprobar, observar y rechazar desde el estado 2. `sg_epaguSecgen04`
registra el envío a remuneraciones y cierra la cuota: deja `sg_epag.mto_realpa` con la suma de los
meses enviados.

`sg_epaguSecgen05` permite que DGDP devuelva una cuota aprobada (4) a visación (2) para ajustar
montos y antecedentes antes de enviarla a Finanzas. Exige un motivo, confirma que todos sus meses
sigan comprometidos en estado 2, conserva la asociación y registra el motivo en `sg_com1` con
acción 34 dentro de la misma transacción. Una cuota ya enviada a Finanzas (8) no se puede reabrir.

Antes de desplegarlo, cargar `datos_base/05_sg_tacc_acciones_pago.sql` (ruta relativa al paquete
`template_wf_pagos`). La carga agrega solo las acciones faltantes 32, 33 y 34. El PA valida la
existencia de la acción 34 antes de modificar la cuota; si falta, devuelve un mensaje de
configuración en lugar de intentar insertar un comentario que viola la FK hacia `sg_tacc`.

**Por qué el envío es un PA aparte.** `sg_epaguSecgen03` está acotado al estado 2 y a los destinos
3, 4 y 10: una cuota aprobada no entra, y ampliarlo a 4 → 8 mezclaría dos actos en un PA cuyo
nombre y validaciones hablan de visación. Vale acá la regla del paquete: pagos no modifica un PA
para sus propias necesidades, crea uno nuevo.

**Qué escribe y qué no, `sg_epaguSecgen04`.** Es la transición que los catálogos ya describían
—`sg_ecuo = 8` «se registró en Finanzas, los meses pasan a `sg_efum = 3`»— y hasta ahora nadie la
escribía, así que `fec_envrem`, `mto_realpa` y los estados 8 y 11 estaban muertos.

- Exige `cod_estcuo = 4`: una segunda ejecución sobre la misma cuota responde `msg` y no cambia
  nada. Es lo que evita pagar dos veces la misma cuota.
- No recalcula `sg_fume.mto_realpa` donde ya existe: `sg_fumeuSecgen03` lo dejó al registrar los
  descuentos, y ese es el neto que DGDP revisó. Solo lo completa donde nunca se ajustó, para que
  ningún mes llegue al estado 3 sin su monto enviado.
- Los meses que DGDP descartó uno a uno quedan en `sg_efum = 4` y no se tocan: solo pasan a 3 los
  que están comprometidos.
- Cierra la cuota dejando `sg_epag.mto_realpa = sum(sg_fume.mto_realpa)` de los meses enviados, que
  es la consistencia que este README ya exigía al PA de cierre y que ningún PA mantenía.

**Crear no compromete.** El borrador deja los meses en `cod_estfum = 1`. Si crear ya los
comprometiera, un borrador abandonado bloquearía meses y consumiría cupo sin que nadie haya pedido
nada — mismo criterio que usa resolución para no escribir `sg_fume` desde un borrador.

**Observar no libera.** Por eso `sg_epaguSecgen01` no deja cambiar los meses de una cuota en 3:
siguen comprometidos, y cambiar el conjunto exigiría liberar unos y tomar otros en el mismo acto.
Cambiar los meses de una cuota ya enviada es rechazarla y rehacerla.

`sg_epagsSecgen05` es una lectura masiva para construir el Excel de Finanzas. Recibe el RUT
DGDP, el estado (4 o 8) y una lista numérica de prestaciones; vuelve a validar la asignación
DGDP y devuelve los meses de las cuotas de esas prestaciones junto con sus asignaciones SISPER.
El resultado tiene una fila por asignación mensual y por cada `ss_ccas` asociado, para conservar
cada centro de costo y su porcentaje. Las fechas se cruzan con el mes de pago de `sg_epag`, y el
monto neto de la cuota se prorratea entre sus centros; cualquier residuo del redondeo queda en la
última asignación para que el total siga cuadrando. El backend limita luego la respuesta a los
números de cuota seleccionados por el usuario.

Las columnas de nómina salen de estas fuentes: `ss_asds.num_cuenta` para Código Haber;
`sg_fups.cod_sitm` para Item, contrastado con `ss_ccas.cod_item`; y
`ss_ccas.valor_asig / ss_asds.valor * 100` para Porcentaje CC. El monto base es el neto total de
la cuota (`sum(sg_fume.mto_apagar - mto_deslic - mto_dessg)`), y las fechas son las de la
asignación del mes de pago. La resolución es el número Exento de `sg_rslc`.

Corrección del 29-10-2026 en `sg_epagsSecgen05`: los netos de las cuotas seleccionadas se
calculan en `#montos_cuota_finanzas`. El agregado que ajusta el redondeo consulta ese neto y el
valor de la asignación mediante alias locales, para evitar el error 146 de ASE por columnas
externas dentro de `sum`. Conserva parámetros, columnas de salida y distribución del monto.
Desplegar el par SQL/TXT actualizado; la compilación y ejecución en ASE quedan pendientes.

Cambio del 30-10-2026 en `sg_epagsSecgen03`: devuelve `fu.cod_sitm`, agregado al `select` y al
`group by`. El ítem presupuestario va en la columna Item del archivo de Finanzas y en la
distribución de la asignación SISPER, y la bandeja ya tenía unido `sg_fups` sin devolverlo. Al
certificar basta comprobar que la columna llega y que el conteo de filas no cambia: `cod_sitm` es
de `sg_fups`, que está unido por `id_funprse`, así que no multiplica el agregado.

> El par estaba desincronizado al tomarlo: al `.txt` le faltaba la ampliación de `mto_rechazado`
> —la que descuenta lo que un rechazo dejó bloqueado, que es lo que declara el objetivo del PA—.
> Se tomó el `.sql` como contenido correcto y se reescribieron los dos. Es el segundo par
> desincronizado en dos días y el otro se resolvió al contrario, así que conviene comparar los dos
> archivos antes de cada entrega.

Cambio del 30-10-2026 en `sg_epagsSecgen03`: devuelve `cod_sitm` más dos columnas,
`cant_subitm` y `cod_subitm`. Lo que `sg_fups.cod_sitm` guarda es el **ítem antiguo** de tres
(`306`), y `pt_sitm` lo conserva en su columna `item_antig smallint`; el archivo y
`ss_ccas.cod_item` esperan el **subítem vigente** de cinco (`30600`), que es el `cod_sitm` de esa
misma fila. Las dos columnas cuentan los subítems vigentes con ese ítem antiguo y devuelven el
menor: con uno solo la resolución es inequívoca, y el contador es lo que distingue «no existe» de
«hay varios».

> Unir por `pt_sitm.cod_item` no sirve: también tiene cinco caracteres, es la clave foránea a
> `pt_item`, y contra un `306` no encuentra nada. La primera versión de este cambio, del mismo
> día, unía por ahí y habría devuelto cero candidatos siempre.

**El mismo día se podaron dos columnas más.** La primera versión traía también `cant_subitm_cc` y
`cod_subitm_cc`, que repetían las dos subconsultas restringidas a los subítems con presupuesto en
el centro de costo (`fin21_db..pt_depr`), para desempatar cuando un ítem antiguo apuntara a
varios. Se retiraron por tres razones: la relación es **uno a uno** en los códigos cargados, así
que el desempate no se ejecutaba nunca; desempatar por presupuesto era una **regla inventada aquí**
y no una de Finanzas; y costaban dos subconsultas correlacionadas por fila, con su correlación a
`prse.cod_unifin`/`prse.cod_ccto`, para nada. Si algún día un ítem antiguo apunta a varios, la
bandeja lo informa como ambiguo en vez de elegir, que es lo correcto. El bloque bajó de 31 líneas
a 9.

Se resuelve por subconsulta escalar y **no por `join`**, y esto no es estilo: el `select` de este
PA agrega (`sum(fume.mto_apagar)`, `count(dpag.corr_fume)` y cuatro más), así que un `join` a
`pt_sitm` que multiplicara filas **duplicaría los montos de la cuota**, no solo las filas. La
comparación va sobre texto a propósito: convirtiendo `item_antig` a `varchar` es ASE quien no
tiene que convertir `fu.cod_sitm`, y un valor sucio devuelve cero candidatos en vez de abortar la
consulta.

La regla de decisión vive en `Du288PaymentReviewInstallmentResponse.resolveSubitem`, con pruebas
unitarias, y no en el PA.

Al certificar:

1. El conteo de filas no cambia respecto de la versión anterior: las dos son subconsultas
   escalares, no uniones, y los montos agregados dan lo mismo.
2. Una prestación con un ítem de un solo subítem devuelve `cant_subitm = 1` y ese subítem,
   **tenga o no presupuesto el centro de costo**.
3. Una con un ítem de varios subítems vigentes devuelve `cant_subitm > 1`, y la bandeja lo marca
   ambiguo sin elegir.
4. Una con `cod_sitm` nulo o con un código que no existe como `item_antig` devuelve `0` y `null`,
   sin error de conversión.
5. Los tres códigos conocidos resuelven: 300 → 30000, 303 → 30300 y 306 → 30600, que es lo que
   `pt_sitm` tiene cargado con `vigencia = '1'`.

> Queda pendiente, y no se tocó: `item_coincide` de `sg_epagsSecgen05` compara `fu.cod_sitm` de
> tres contra `ss_ccas.cod_item` de cinco, así que da 0 siempre. No estorba hoy porque la bandeja
> ya no usa ese archivo, pero cuando vuelva hay que comparar contra el subítem resuelto.

---

## Los tres montos de una cuota

| | Dónde vive | Quién lo escribe |
| :--- | :--- | :--- |
| **Solicitado** | derivado: `sum(sg_fume.mto_apagar)` | el solicitante, mes a mes |
| **Descuentos** | `sg_fume.mto_deslic` + `sg_fume.mto_dessg` | DGDP en la visación |
| **Monto de la cuota** | `sg_epag.mto_realpa` | el **cierre**, tras aplicar los descuentos |

`mto_realpa` es el monto de la cuota: lo que se registra para Finanzas. Es el único que se
persiste en el encabezado, y viene nulo mientras la cuota está en trámite — hasta entonces lo que
vale es lo solicitado.

El per-mes `sg_fume.mto_realpa` guarda la misma cifra desglosada, de modo que
`sg_epag.mto_realpa = sum(sg_fume.mto_realpa)` de los meses de la cuota. Está denormalizado a
propósito, para no tener que recorrer los meses en cada reporte; el PA de cierre tiene que
mantener las dos consistentes.

Lo solicitado no se persiste en el encabezado porque **`sg_dpag` no tiene columna de monto**: un
mes aporta su `mto_apagar` completo a una sola cuota y no puede repartirse entre dos. Lo calcula
`sg_epagsSecgen01` y lo revalida `sg_epaguSecgen02`.

Quien escribe `mto_apagar` es **`sg_fumeuSecgen02`**, no estos PA. Y no toca `cod_estfum`: el estado
lo mueve el procedimiento que mueve el encabezado, nunca una edición de datos.

---

## Qué valida el envío y qué no

`sg_epaguSecgen02` valida lo **estructural**:

- la cuota existe y está en 1 o 3;
- tiene al menos un mes;
- cada mes tiene `mto_apagar > 0`;
- desde el estado 1, cada mes sigue propuesto y con ejecución terminada;
- la suma no excede `sg_fups.mto_total` descontando lo ya comprometido y lo ya enviado.

El **panel normativo** —tope, inhabilidad, parentesco, saldo del centro de costo— lo revalida la
aplicación con los PA de resolución (`sg_fupssSecgen12` a `15`, `sg_cctosSecgen06`) antes de
llamar a este procedimiento. Duplicar esas reglas en SQL crearía una segunda versión que se
desincroniza de la que ya usa resolución.

---

## La guarda de `afec_du9` está comentada en los archivos, no en la base

Tres de estos PA rechazaban con *«El centro de costo no pertenece al flujo
DU09»* cuando `fin21_db..es_ccto.afec_du9` no vale `S`. Hoy la columna está
nula en todos los centros vigentes, así que la guarda bloqueaba cualquier
cuota. El 14-10-2026 se envolvió en un comentario `INTERRUPTOR-DU09` en
`sg_epagiSecgen01`, `sg_epaguSecgen01` y `sg_epaguSecgen02`.

> [!WARNING]
> Comentarlo en el `.sql` no cambia nada hasta **redesplegar los tres PA**.
> Mientras no se redespliegan, crear o enviar una cuota sigue devolviendo 422
> con ese mensaje, aunque el chip del panel aparezca como advertencia y el
> front no lo cuente entre los bloqueantes.

Para saber qué hay realmente instalado:

```sql
exec sp_helptext 'Analisis2.sg_epagiSecgen01'
```

Si la guarda aparece fuera del bloque `/* INTERRUPTOR-DU09 ... */`, lo
instalado es anterior al interruptor.

El estado esperado del archivo, que vale para los tres:

```sql
/* INTERRUPTOR-DU09 : deshabilitada el 2026/10/14 mientras los centros de
   costo de prueba no tienen cargada la marca afec_du9. Para habilitarla,
   borrar esta linea de apertura y la de cierre. ...

if @afec_du9 <> 'S'
begin
    select 'Error: El centro de costo no pertenece al flujo DU09' as msg
    return
end
*/
```

Para volver a encenderla hay que poblar la marca primero —
`datos_base/06_marcas_du09_centro_costo.sql` lista los centros con
prestaciones DU288 archivadas y cuenta cuántos quedarían sin poder pagar —
y seguir los cinco puntos de `INTERRUPTOR-DU09.md`. Encenderla con la
columna vacía reproduce exactamente el bloqueo que el interruptor vino a
esquivar.

Es la misma columna que deja sin menú al jefe de proyecto cuando
`sg_cctosSecgen05` filtra por ella: ver `sg_ccto/sg_cctosSecgen05.sql` y la
sección del PA en el README de `cambios_pa`.

---

## Cómo se evita que un mes caiga en dos cuotas

La PK de `sg_dpag` es `(id_funprse, nro_cuota, corr_fume)`, así que admite `(3,1,1)` y `(3,2,1)`:
el mismo mes en dos cuotas. No se agrega índice único; la aprobación/rechazo usa las PAs
transaccionales del módulo. El motivo de observación/rechazo no queda persistido: la definición
vigente de `sg_epag` no incluye una columna para guardarlo.

La guarda vive entonces en los procedimientos, en dos capas:

1. **Antes de la transacción**, `sg_epagiSecgen01` y `sg_epaguSecgen01` verifican que ninguno de
   los meses pedidos esté ya en `sg_dpag`. Esto atrapa el caso normal y devuelve un mensaje claro.
2. **Dentro de la transacción**, la misma verificación se repite con `holdlock` justo después del
   `begin tran`. El bloqueo compartido se mantiene hasta el commit, de modo que dos llamadas
   simultáneas se serializan: la segunda espera, encuentra el mes tomado y aborta con rollback.

Sin la segunda capa, dos envíos concurrentes pasarían ambos la verificación previa y ambos
insertarían.

**Lo que queda sin cubrir** es una corrección hecha directamente por SQL, que ningún procedimiento
puede impedir. Es un riesgo asumido al no agregar el índice.

Conviene confirmar también que la FK compuesta hacia `sg_fume` está en el catálogo:

```sql
sp_helpconstraint 'secgen_db.dbo.sg_dpag'
```

---

## Orden de despliegue

```
1. sg_ecuo/sg_ecuosSecgen01 · sg_ecuosSecgen02   catálogo, solo lectura
2. sg_fume/sg_fumesSecgen01   lectura de meses
3. sg_fume/sg_fumeuSecgen02   monto y ejecución real del mes
4. sg_fuc2/los tres              compensación realizada
5. sg_epag/sg_epagsSecgen01 · sg_epagsSecgen02   lectura de cuotas
6. sg_epag/sg_epagiSecgen01 · sg_epaguSecgen01 · sg_epagdSecgen01
7. sg_epag/sg_epaguSecgen02   envío
8. Backend y frontend
9. `datos_base/04_roles_privilegios_pagos.sql`
10. `sg_usacs/sg_usacsSecgen01` y actualizar `sg_epagsSecgen01`
11. `sg_epagsSecgen03/04` y `sg_epaguSecgen03`
12. Backend y frontend DGDP
13. `sg_epag/sg_epaguSecgen04`   envío a Finanzas (cierre de la cuota)
14. Backend y frontend de la bandeja de cuotas aprobadas
15. `datos_base/05_sg_tacc_acciones_pago.sql` (acción 34) y `sg_epag/sg_epaguSecgen05`
```

Todos los PA usan las columnas declaradas para `sg_epag` en el diagrama vigente. La decisión
actualiza el estado y el rechazo libera los meses; el motivo, RUT revisor y fecha no se persisten
porque esa tabla no contiene campos para auditoría. El SQL `datos_base/05_auditoria_revision_dgdp`
queda como propuesta opcional de extensión y no forma parte de este orden de despliegue.
