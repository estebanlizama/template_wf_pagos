# CRUD de `sg_fume` end to end — análisis previo a la implementación

Alcance de esta fase: aplicar el cambio de `sg_fume` en PA, backend y frontend.
**Fuera de alcance:** `sg_epag`, `sg_dpag` y `ext_cuotas`.

---

## 1. El cambio de fondo: `installments` deja de ser cuotas

Toda la cadena actual asume **una cuota = un mes**. El nombre lo delata: la API llama
`installments` a lo que transporta meses.

| Capa | Hoy | Después |
| :--- | :--- | :--- |
| BDD | `sg_fume.nro_cuota` | `sg_fume.corr_fume` — correlativo del mes |
| PA | `fume.nro_cuota` | `fume.corr_fume` |
| Modelo | `installmentNumber` | número de mes, no de cuota |
| API | `installments: [...]` | meses |
| Frontend | `installments.length` = cuotas | = meses |

**Esta fase no agrega cuotas — las quita.** Después de aplicar el cambio, `sg_fume` no sabe nada
de cuotas; las conocerá `sg_epag` cuando exista.

---

## 2. Cadena de ESCRITURA

```
PdsDu288RequestForm.vue                 periodo del funcionario
  └─ POST/PUT /requests/service-provision
      └─ service-provision-workflow.service.ts:216 / :409     if (isSubmitted)
          └─ repository.syncNormativeRequestStaffMonths()
              └─ repository.syncStaffMonths()                  :3539
                  ├─ deriveExecutionMonths(f_inicio, f_termino) → "2026:3;2026:4;2026:5"
                  └─ query 'updateStaffMonths'                  :162
                      └─ PA sg_fumeuSecgen01
                          └─ DELETE + INSERT en sg_fume
```

| # | Punto | Cambio | Riesgo |
| :-- | :--- | :--- | :--- |
| E1 | `PdsDu288RequestForm.vue` | **ninguno** — solo manda fechas | — |
| E2 | `workflow.service.ts` | **ninguno** | — |
| E3 | `repository.syncStaffMonths:3561` | `cod_estcuo: 1` → `cod_estfum: 1` | bajo |
| E4 | `service-provision-request.ts:162` | `@cod_estcuo` → `@cod_estfum` | **debe ir junto con E5** |
| E5 | `sg_fumeuSecgen01` | 7 renombres + guarda + `sg_fuc2`/`sg_fum2` | medio |

La escritura es la parte fácil: el cliente nunca manda estados ni números de cuota, solo fechas.

---

## 3. Cadena de LECTURA — aquí está el trabajo

```
sg_fume
  └─ PA sg_fupssSecgen17          JOIN sg_ecuo, sg_fuc2, sg_fuho, sg_fuco
      └─ repository.selectStaffPreviousProvisions
          └─ Du288StaffPreviousProvisionResponse.fromProcedureRows()
              ├─ agrupa por installmentNumber            ← L3
              └─ deriva isPaid / isInPayment por texto   ← L4
          └─ GET /staff-previous-provisions/{rut}
              └─ textSimilarityUtil.js
                  ├─ installmentMonthsForYear
                  ├─ installmentMonthsByStatusForYear
                  ├─ monthDistributionCheck
                  └─ evaluatePdsConflictSeverity
              ├─ PdsDu288RequestForm.vue            cupo y tope
              └─ Du288StaffPreviousProvisionsModal.vue   comparador DGDP
```

### L1 · `sg_fupssSecgen17`

| Línea | Hoy | Después |
| :--- | :--- | :--- |
| 79 | `fume.nro_cuota` | `fume.corr_fume` |
| 82 | `fume.cod_estcuo` | `fume.cod_estfum` |
| 96-98 | `fume.fec_pago`, `ano_pago`, `mes_pago` | **eliminar** — se fueron a `sg_epag` |
| 137 | `join sg_ecuo on ecuo.cod_estcuo = fume.cod_estcuo` | `join sg_efum on efum.cod_estfum = fume.cod_estfum` |
| 140 | `fuc2.nro_cuota = fume.nro_cuota` | depende de dónde quede `sg_fuc2` |
| 166 | `order by ... fume.nro_cuota` | `fume.ano_prop, fume.mes_prop` |

Los tres campos de pago pasan a devolverse **siempre nulos** en esta fase. Es correcto y honesto:
hoy tampoco tienen dato, porque nada los escribe.

### L2 · `sg_fuc2` — decisión bloqueante

Su FK apunta a `sg_fume(id_funprse, nro_cuota)`, llave que **deja de existir**. Sin resolver
esto, el PA no compila. Dos salidas:

| Opción | Consecuencia |
| :--- | :--- |
| FK a `sg_fume(id_funprse, corr_fume)` | la compensación efectiva queda **por mes** |
| FK a `sg_epag(id_funprse, nro_cuota)` | queda **por cuota** — es lo acordado en el WF (Q-G04), pero `sg_epag` no existe todavía |

Como esta fase no crea `sg_epag`, la salida pragmática es **repuntar a `corr_fume` ahora** y
migrar a `sg_epag` cuando llegue el WF de pagos. `sg_fuc2` hoy está vacía, así que la migración
posterior no arrastra datos.

### L3 · 🔴 El agrupador pierde filas

[du288-staff-previous-provision-response.model.ts:327](../../../sg-solicitudes-backend/src/models/response/service-provision/du288-staff-previous-provision-response.model.ts:327):

```ts
let installment = provision.installments.find(item => item.number === installmentNumber);
if (!installment) { ...crea con proposedYear/proposedMonth de ESTA fila... }
// si ya existe, la fila se descarta
```

Hoy funciona porque `nro_cuota` es único por mes. Con `corr_fume` **sigue siendo único por mes**,
así que en esta fase **no se rompe**. El problema aparece cuando `sg_dpag` agrupe varios meses
bajo una cuota.

> **Recomendación:** renombrar ahora `installments` → `months` y `installmentNumber` →
> `monthSequence`. Es el momento barato: el grano ya es el mes, y evita que la próxima fase tenga
> que desarmar una estructura que ya se llamaba distinto de lo que era.

### L4 · 🔴 La clasificación por texto

[model.ts:334-345](../../../sg-solicitudes-backend/src/models/response/service-provision/du288-staff-previous-provision-response.model.ts:334):

```ts
const isPaid = Boolean(row.paidAt) || normalizedStatus.includes('PAGAD');
const isInPayment = !isPaid && (Boolean(row.sentToPayrollAt) ||
    normalizedStatus.includes('PAGO') || ... );
```

Después del cambio:
- `paidAt` viene de `fec_pago`, que **ya no existe** → siempre `false`
- ninguna etiqueta de `sg_efum` contiene `PAGAD` → `isPaid` queda muerto
- `sentToPayrollAt` viene de `fec_envrem`, que **sí sigue** en `sg_fume`

Hay que reemplazarlo por el código:

```ts
const MES_PROPUESTO    = 1;
const MES_COMPROMETIDO = 2;
const MES_ENVIADO      = 3;
const MES_RECHAZADO    = 4;
```

**Dato tranquilizador:** hoy ninguna fila llega a otro estado que no sea 1 — el sistema solo
escribe `cod_estcuo = 1` y no existe transición. `isPaid`/`isInPayment` ya son `false` en toda
la data real; lo que se ve distinto en desarrollo viene de inserts manuales.

### L5 · Frontend — `textSimilarityUtil.js`

| Función | Hoy | Después |
| :--- | :--- | :--- |
| `installmentMonthsForYear:396` | un mes por installment | igual — el grano no cambia |
| `installmentMonthsByStatusForYear:422` | clasifica por `isPaid`/`isInPayment` | debe clasificar por `cod_estfum` |
| `installmentsSummaryLabel:766` | `installments.length` como total de cuotas | debe usar solo `tot_cuotas` de `sg_fups` |
| `monthDistributionCheck` | cuenta meses | igual |
| `evaluatePdsConflictSeverity` | usa los anteriores | se arrastra |

`installmentsSummaryLabel` es el que engaña: hoy cae a contar el arreglo cuando falta
`totalInstallments`, y ese fallback pasa a contar meses en vez de cuotas.

### L6 · `Du288StaffPreviousProvisionsModal.vue`

[línea 1721](../../../sg-solicitudes-frontend/components/services-provision/Du288StaffPreviousProvisionsModal.vue:1721) mapea `installments` 1:1 a filas de la tabla comparativa. En esta fase
el grano no cambia (sigue siendo un mes por fila), así que **funciona igual** — pero el
encabezado de la columna debe decir *mes*, no *cuota*.

Los badges `isPaid`/`isInPayment` quedan siempre apagados. Conviene reemplazarlos por el estado
del mes (`des_estfum`), que sí trae información.

---

## 4. Las validaciones que dependen de esto

| Validación | Depende de | ¿Se rompe? |
| :--- | :--- | :---: |
| Cupo del numeral 6 (`getMaxDeclarableInstallments`) | meses ocupados por año y CC | **No** — cuenta meses, y el grano no cambia |
| `monthDistributionCheck` | idem | **No** |
| Tope por cuota (`capNoteForRelated`) | `sg_fups.tot_cuotas` y `mto_total` | **No** — no toca `sg_fume` |
| Traslape de periodo / horario | `sg_fuho`, fechas | **No** |
| Duplicidad por centro de costo | `sg_prse` | **No** |
| Resumen "N cuotas pagadas" | `isPaid` | **Sí** — queda en blanco |
| Advertencia de doble pago | `isPaid` + compensaciones | **Sí** — deja de dispararse |

Las validaciones **normativas** no se rompen. Lo que se apaga son los indicadores de pago, que
hoy ya no tienen dato real.

---

## 5. Lo que se puede hacer ahora y lo que no

| Se puede ahora | Queda para el WF de pagos |
| :--- | :--- |
| Renombrar `nro_cuota` → `corr_fume` en toda la cadena | Crear `sg_epag` y `sg_dpag` |
| Renombrar `cod_estcuo` → `cod_estfum` + catálogo `sg_efum` | Escribir estados 2, 3 y 4 |
| Quitar `fec_pago`/`ano_pago`/`mes_pago` del PA y del modelo | Leer el mes de pago desde `sg_epag` |
| Agregar `mto_realpa`/`mto_deslic`/`mto_dessg` (columnas, sin uso) | Llenarlos |
| Reemplazar el matching por texto por el código | Agrupar meses bajo una cuota |
| Renombrar `installments` → `months` en la API | La guarda contra `sg_dpag` |
| Corregir el `order by` de `sg_fupssSecgen17` | Repuntar `sg_fuc2` a `sg_epag` |
| Eliminar el stub `updateInstallmentStatusesByRequest` | |

**El criterio:** esta fase deja `sg_fume` correcto como *tabla de meses propuestos*, sin
inventar la mitad del WF de pagos para que compile.

---

## 6. Orden de implementación sugerido

1. **BDD** — `sg_efum` + `ALTER` de `sg_fume` y `sg_fum2`, migración, FK, `DROP`.
2. **`sg_fuc2`** — repuntar a `corr_fume` (decisión de §L2).
3. **PA** — `sg_fumeuSecgen01` y `sg_fupssSecgen17`, en el mismo despliegue que el backend.
4. **Backend** — repository, query template, y el modelo de respuesta (renombre de grano +
   clasificación por código).
5. **Frontend** — `textSimilarityUtil.js`, el modal y las etiquetas.
6. **Tests** — los tres archivos de test que tocan esto:
   `du288-staff-previous-provision-response.unit.ts`, `textSimilarityUtil.test.cjs`,
   `du288PreviousProvisionsFormatting.test.cjs`.

---

## 7. Decisiones que hay que cerrar antes de escribir código

1. **`sg_fuc2`** — ¿FK a `corr_fume` ahora, o se congela la tabla hasta que exista `sg_epag`?
2. **¿Se renombra el contrato de la API** (`installments` → `months`) en esta fase, o se deja el
   nombre viejo con el grano nuevo? Renombrar ahora es más barato, pero toca el frontend entero.
3. **`sg_fum2`** — confirmar que replica `corr_fume`, `cod_estfum` y los tres montos nuevos.
4. **Tipos** — los cuatro montos de `sg_fume` son `int` y deberían ser `decimal(19,2)`
   (ver `impacto_06`). Conviene resolverlo en el mismo `ALTER`, no en otro despliegue.
