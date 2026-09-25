# Qué guarda y actualiza resolución en `sg_fume`

Premisa confirmada: **`sg_epag` y `sg_dpag` no existen hasta el WF de pagos.** En resolución sólo
se generan filas de `sg_fume`, con datos propuestos. Ni la cantidad de cuotas ni el tipo de cuota
se materializan todavía — eso lo declara `sg_fups` (`tot_cuotas`, `cod_tpps`) como intención, no
como hecho.

---

## 1. Las 20 columnas, y quién escribe cada una

| Columna | Resolución | Pagos | Por qué |
| :--- | :---: | :---: | :--- |
| `id_funprse` | **escribe** | — | PK |
| `corr_fume` | **escribe** | — | PK, correlativo del mes |
| `ano_prop` | **escribe** | — | derivado de `f_inicio`/`f_termino` |
| `mes_prop` | **escribe** | — | idem |
| `cod_estfum` | **escribe** (=1) | escribe | único estado que resolución conoce |
| `ano_ejec` | — | escribe | el mes en que se ejecutó de verdad |
| `mes_ejec` | — | escribe | idem |
| `mto_apagar` | — | escribe | monto de ese mes dentro de la cuota |
| `id_evidenc` | — | escribe | PDF de la cuota |
| `val_licmed` | — | escribe | validación de DGDP |
| `val_inabili` | — | escribe | idem |
| `val_singoce` | — | escribe | idem |
| `val_ciecc` | — | escribe | idem |
| `fec_valida` | — | escribe | cuándo revisó DGDP |
| `rut_autori` | — | escribe | quién autorizó |
| `fec_autori` | — | escribe | cuándo |
| `fec_envrem` | — | escribe | al subir a Finanzas |
| `mto_realpa` | — | escribe | monto realmente pagado |
| `mto_deslic` | — | escribe | descuento por licencia |
| `mto_dessg` | — | escribe | descuento por sin goce |

**Resolución escribe 5 de 20 y deja las otras 15 en `NULL`.** Eso es correcto y no hay que
cambiarlo.

---

## 2. Lo que resolución **no** debe guardar, aunque podría

### 2.1 `mto_apagar` en prestaciones Fijas

Es tentador: en Fija (`cod_tpps = 1`) el monto de cada mes se conoce desde la resolución —
`ExecutionMonthsTags` ya lo muestra mes a mes.

**Pero no debe persistirse**, porque sería un dato derivado duplicado:

```
monto del mes = sg_fups.mto_total / meses de ejecución
```

Y `sg_fups.monto_mes` ya guarda exactamente ese promedio, recalculado siempre por el PA
(ADR-011). Si `mto_total` o el periodo cambian, los `mto_apagar` que resolución hubiera escrito
quedarían obsoletos sin que nada los actualice.

`mto_apagar` es lo que la **cuota** asigna a ese mes, que puede diferir de la promesa: DGDP
descuenta por licencia, el solicitante ajusta en Variable. Es dato de pago.

### 2.2 Los `val_*`

Resolución sí valida inhabilidades, cargo, parentesco y calendario. Pero esas validaciones son
dinámicas y se recalculan en cada transición — persistirlas en el mes sería cachear un resultado
que caduca, que es justo lo que descartamos al sacar el estado *Validada*.

### 2.3 `ano_ejec` / `mes_ejec`

En resolución sólo existe lo **propuesto**. `ano_ejec`/`mes_ejec` registran en qué mes se ejecutó
realmente, y eso se sabe al pagar. Dejarlos iguales a `ano_prop`/`mes_prop` desde el inicio
borraría la distinción entre lo planificado y lo ocurrido.

---

## 3. Resolución nunca hace `UPDATE`

`sg_fumeuSecgen01` es una **sincronización diferencial**, no un update:

1. `DELETE` de los meses que salieron de la propuesta
2. `INSERT` de los meses que entraron
3. Los que siguen, **no se tocan** — conservan su correlativo

No hay un solo `UPDATE` sobre `sg_fume` en todo el flujo de resolución. Un mes o existe en 1, o
no existe.

Eso simplifica el impacto del cambio de catálogo: no hay transiciones que migrar, sólo filas que
cambian de columna.

---

## 4. Dos cosas que conviene revisar de `corr_fume`

### 4.1 No es cronológico después de una edición

```sql
select @max_cuota = isnull(max(nro_cuota), 0) from sg_fume where id_funprse = @id_funprse
...
select @id_funprse, @max_cuota + correlativ, anio, nro_mes, @cod_estcuo from #meses_nuevos
```

Los correlativos nuevos arrancan sobre el máximo existente. Si la prestación se guardó con
marzo–mayo (1, 2, 3) y luego se **agrega enero**, enero queda con correlativo **4**.

Hoy no molesta, pero `sg_fupssSecgen17` ordena por ese campo:

```sql
order by soli.f_solicit desc, fu.id_funprse, fume.nro_cuota, fuc2.fec_comrea
```

→ el modal de prestaciones previas mostraría enero **después** de mayo. Debe ordenar por
`ano_prop, mes_prop`.

### 4.2 Quedan huecos

Al borrar meses, los correlativos dejan gaps (1, 2, 5, 6). Es inofensivo mientras `corr_fume` se
trate como **identificador**, no como posición. `sg_dpag` lo referencia por valor, así que no
importa — pero conviene que nadie asuma que van de 1 a N.

---

## 5. Consecuencia para la guarda del PA

Como en resolución **no existen cuotas todavía**, todos los meses están en `cod_estfum = 1` y la
guarda nunca bloquea:

```sql
if exists (select 1 from sg_fume
            where id_funprse = @id_funprse
              and cod_estfum not in (1, 4))
```

Sólo empieza a bloquear cuando el WF de pagos comprometió meses (estado 2) o los subió (3). Es
decir: **la resolución es libremente editable hasta que alguien pide el primer pago**, que es
exactamente el comportamiento esperado.

La guarda nueva contra `sg_dpag` es el refuerzo de lo mismo, y sólo puede dispararse cuando esa
tabla ya tiene filas — o sea, nunca durante resolución.

---

## 6. Resumen

| Pregunta | Respuesta |
| :--- | :--- |
| ¿Qué guarda resolución en `sg_fume`? | `id_funprse`, `corr_fume`, `ano_prop`, `mes_prop`, `cod_estfum = 1` |
| ¿Qué actualiza? | Nada. Es `DELETE` + `INSERT` diferencial |
| ¿Debería guardar el monto en Fija? | No — es derivable de `sg_fups.mto_total` y ya está en `monto_mes` |
| ¿Debería guardar validaciones? | No — se recalculan en cada transición |
| ¿Se crean cuotas? | No. `sg_epag` y `sg_dpag` nacen en el WF de pagos |
| ¿`tot_cuotas` y `cod_tpps`? | Viven en `sg_fups` como declaración; no se materializan hasta el pago |

**Pendiente de corregir:** el `order by` de `sg_fupssSecgen17` debe ser `ano_prop, mes_prop` y no
el correlativo, porque después de una edición el correlativo deja de ser cronológico.
