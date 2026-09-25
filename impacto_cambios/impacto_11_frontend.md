# Impacto en el frontend del cambio a `sg_efum`

Estado previo: el backend de la ruta de resolución ya está migrado. Este documento mapea lo que
falta en el frontend.

---

## 1. Qué cambió en el contrato de la API

| Antes | Ahora | Nota |
| :--- | :--- | :--- |
| `installmentNumber` | `monthSequence` | correlativo del mes, no de la cuota |
| `installmentStatusCode` | `monthStatusCode` | catálogo `sg_efum` |
| `installmentStatus` | `monthStatus` | etiqueta |
| `isPaid` | `isSentToPayment` | *"pagado"* era una afirmación que el sistema no puede hacer |
| `isInPayment` | `isCommitted` | |
| — | `isRejected` | **nuevo** — el mes que DGDP excluyó |
| `paidAt` | *eliminado* | la columna se fue al encabezado de pago |
| `paymentYear` / `paymentMonth` | *eliminado* | idem |
| — | `amountPaid` | **nuevo** — monto real, con descuentos |
| — | `medicalLeaveDeduction` | **nuevo** |
| — | `unpaidLeaveDeduction` | **nuevo** |

El arreglo sigue llamándose `installments` en la respuesta; sólo cambió el contenido de cada
elemento. Renombrarlo a `months` es un paso aparte.

---

## 2. Dónde impacta — 41 referencias en 4 archivos

### 2.1 `utils/textSimilarityUtil.js` — el más crítico

| Línea | Qué hace | Cambio |
| :--- | :--- | :--- |
| 89-91, 105-107 | arma el ítem de comparación con `installmentNumber`, `installmentStatus`, `isPaid` | renombre directo |
| 224-226 | `hasPaidInstallments` / `hasPaymentInProgress` de la PDS previa | `isSentToPayment` / `isCommitted` |
| 230 | traslape de compensación con una cuota ya pagada | `isSentToPayment` |
| 412-415 | `installmentStatusRank` y `installmentStatusBucket` — jerarquía pagado > en pago > pendiente | **rehacer con los 4 estados** |
| 427-435 | `installmentMonthsByStatusForYear` — clasifica los meses del año por estado | usa el bucket anterior |
| 927 | aviso de doble pago sobre compensación pagada | `isSentToPayment` |

**El punto delicado es `installmentStatusBucket`.** Hoy tiene 3 buckets y ninguno para
*rechazado*:

```js
const installmentStatusRank = { paid: 2, inPayment: 1, pending: 0 }
```

Con `sg_efum` hay 4 estados, y el rechazado **no consume cupo** — si cae en `pending` por
defecto, un mes que DGDP excluyó volvería a contarse como disponible, que es correcto para
*disponible* pero incorrecto para *volver a ofrecerlo*. Hay que decidirlo explícitamente.

### 2.2 `Du288StaffPreviousProvisionsModal.vue` — el más extenso

| Línea | Qué | Cambio |
| :--- | :--- | :--- |
| 454-456, 1026 | columna *Estado* de la tabla de compensaciones | `monthStatus` |
| 1368 | `hasRealProgress` — decide si la cuota tiene avance | los 3 flags nuevos |
| 1381-1383 | badges de estado en el resumen de pago | idem |
| 1396, 1417 | columna *Pagado el* con `paidAt` | **se queda sin dato** |
| 1430-1434 | aviso de doble pago | `isSentToPayment` + `sentToPayrollAt` |
| 1735-1737, 1748-1750 | filas del comparador | renombre |
| 2222-2226, 2249 | citación de traslape con cuota pagada | `isSentToPayment` |

**`paidAt` es el único que pierde información de verdad.** La columna *"Pagado el"* ya no tiene
fuente: esa fecha vive ahora en el encabezado de pago. Opciones: mostrar `sentToPayrollAt`
(*"Enviado a pago el"*, que es lo que el sistema realmente sabe) o quitar la columna hasta que
exista el encabezado.

### 2.3 `du288PreviousProvisionsFormatting.js` — 2 líneas

```js
export const installmentVariant = (item) => {
  if (item?.isPaid) return 'success'
  if (item?.isInPayment) return 'warning'
  return 'secondary'
}
```

Pasa a 4 ramas, con el rechazado en `danger`.

### 2.4 `PdsDu288RequestForm.vue` — 1 línea

Línea 1645, `isPaid: comp.isPaid` dentro del armado de compensaciones. Renombre directo.

---

## 3. Lo que NO se rompe

| Validación | Por qué |
| :--- | :--- |
| Cupo del numeral 6 (`getMaxDeclarableInstallments`) | cuenta claves `año-mes`, y el grano del mes no cambia |
| `monthDistributionCheck` | idem |
| Tope por cuota (`capNoteForRelated`, `monthlyContributionOf`) | lee `mto_total`, `cod_tpps` y `tot_cuotas` de la prestación, no los meses |
| Traslape de periodo y de horario | fechas y horarios, no estados |
| Duplicidad por centro de costo | identificadores, no estados |
| `ExecutionMonthsTags` | calcula desde el periodo |

Las validaciones normativas están intactas. Lo que cambia es **cómo se clasifica y se muestra**
el estado de pago.

---

## 4. Lo que se apaga, y por qué está bien

Después del cambio, ninguna prestación tendrá meses en estado distinto de 1, porque el WF de
pagos todavía no existe. Entonces:

- todos los badges de pago quedan en *pendiente*,
- `hasPaidInstallments` y `hasPaymentInProgress` quedan en `false`,
- el aviso de doble pago deja de dispararse.

**Eso no es una regresión: es el estado real.** Hoy esos indicadores se ven activos sólo con
datos insertados a mano; por el sistema nunca se producen, porque resolución escribe siempre
*Propuesta* y no hay transición.

---

## 5. Decisión pendiente

**¿Se renombra `installments` → `months` en el frontend?**

| | A favor de renombrar | En contra |
| :--- | :--- | :--- |
| Claridad | el arreglo transporta meses; el nombre miente desde el origen | — |
| Costo | — | toca los 4 archivos completos, no sólo las 41 líneas |
| Futuro | cuando exista la cuota real habrá **dos** colecciones: meses y cuotas. Si `installments` ya está ocupado por los meses, habrá que renombrar igual | — |

Recomendación: **renombrar ahora**. El trabajo es el mismo que hacer sólo los flags, y evita que
la próxima fase tenga que desarmar una estructura mal nombrada.

---

## 6. Orden sugerido

1. `du288PreviousProvisionsFormatting.js` — 2 líneas, sin dependencias
2. `textSimilarityUtil.js` — el bucket y los consumidores de los flags
3. `Du288StaffPreviousProvisionsModal.vue` — columnas, badges y citaciones
4. `PdsDu288RequestForm.vue` — 1 línea
5. Tests: `textSimilarityUtil.test.cjs` y `du288PreviousProvisionsFormatting.test.cjs`
6. Textos de `lang/es/pds.js` — *"Pagado el"* → *"Enviado a pago el"*

El paso 2 es el que tiene riesgo: de ahí sale el cupo del numeral 6.
