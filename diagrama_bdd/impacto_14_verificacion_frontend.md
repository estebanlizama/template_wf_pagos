# Verificación del contrato backend → frontend

Comprobación de que el frontend toma los datos nuevos y que nada quedó huérfano.

---

## 1. Qué emite el backend por cada mes

23 campos en cada elemento de `installments`:

```
number · proposedYear · proposedMonth · statusCode · status
executionYear · executionMonth
amountToPay · amountPaid · medicalLeaveDeduction · unpaidLeaveDeduction
evidenceId
hasMedicalLeave · hasDisablement · hasUnpaidLeave · hasAttendanceClosure
validatedAt · authorizedBy · authorizedAt · sentToPayrollAt
isCommitted · isSentToPayment · isRejected
```

---

## 2. Qué consume el frontend

**16 de 23.** Los tres flags nuevos están conectados:

| Campo | Consumido | Dónde |
| :--- | :---: | :--- |
| `number` | ✅ | filas del comparador, citaciones |
| `proposedYear` · `proposedMonth` | ✅ | cupo del numeral 6, tabla de meses |
| `executionYear` · `executionMonth` | ✅ | cupo, columna de ejecución |
| `statusCode` | ✅ | se transporta a la fila |
| `status` | ✅ | etiqueta del badge |
| `amountToPay` | ✅ | columna Monto, citaciones |
| `hasMedicalLeave` …`hasAttendanceClosure` | ✅ | badges de validación |
| `sentToPayrollAt` | ✅ | columna de envío, citaciones |
| **`isCommitted`** | ✅ | bucket del cupo, `hasRealProgress`, colisión de doble pago |
| **`isSentToPayment`** | ✅ | bucket del cupo, badges, citaciones, traslape de compensación |
| **`isRejected`** | ✅ | bucket del cupo (descarta el mes), color del badge |

---

## 3. Los 7 que no se consumen

### 3.1 Cuatro ya no se consumían antes — sin cambio

`evidenceId`, `validatedAt`, `authorizedBy`, `authorizedAt`

Verificado contra `HEAD`: **ninguno se consumía antes del cambio**. Viajan en la respuesta desde
el commit original y nunca se usaron. No es una regresión introducida ahora.

### 3.2 Tres son los campos nuevos, y **todavía no tienen dato**

`amountPaid` (`mto_realpa`), `medicalLeaveDeduction` (`mto_deslic`),
`unpaidLeaveDeduction` (`mto_dessg`)

Sólo los escribe el WF de pagos, que no existe. Conectarlos ahora mostraría columnas vacías en
todas las filas.

**Pero hay una decisión que conviene dejar anotada:** la columna *Monto* del modal muestra
`amountToPay` — lo **solicitado**. Cuando existan los pagos, lo correcto para un mes ya enviado
es mostrar `amountPaid`, que es lo que efectivamente se informó a Finanzas con los descuentos
aplicados. Hoy ambos coinciden porque el segundo es nulo; el día que no, la columna estará
mostrando un monto que no se pagó.

Lo mismo con los dos descuentos: DGDP querrá verlos desglosados en el comparador, no sólo el
monto final.

---

## 4. Lo que se quitó, y por qué no dejó huecos

| Campo | Antes | Ahora |
| :--- | :--- | :--- |
| `isPaid` | **sí se consumía** — 11 puntos | reemplazado por `isSentToPayment` en los 11 |
| `paidAt` | **sí se consumía** — 4 puntos | 3 pasaron a `sentToPayrollAt`; el cuarto era la columna *Pago efectivo*, eliminada |

La columna se eliminó porque su dato ya no existe en el mes: la fecha de pago efectivo vive en el
encabezado de pago y el sistema nunca recibe acuse de Finanzas. Se quitó también su etiqueta
`paidAtColumnLabel` del archivo de textos, para no dejar una clave huérfana.

---

## 5. Cambios en el frontend, archivo por archivo

| Archivo | Qué cambió |
| :--- | :--- |
| `utils/textSimilarityUtil.js` | `compensationRowsFor` → `isSentToPayment`; `evaluatePdsConflict` → los dos flags; **`installmentStatusBucket` de 3 a 4 estados**, con el rechazado devolviendo `null`; mensaje de bloqueo reescrito |
| `du288PreviousProvisionsFormatting.js` | `installmentVariant` con 4 ramas, `danger` para rechazado |
| `Du288StaffPreviousProvisionsModal.vue` | badge de estado, `hasRealProgress`, `defaultStatus` con dos valores nuevos, colisión de doble pago, `paymentRiskDetail`, 2 citaciones, filas del comparador, **columna eliminada** |
| `PdsDu288RequestForm.vue` | 1 línea: el flag en el armado de compensaciones |
| `lang/es/pds.js` | −`paidAtColumnLabel`, +`monthSentToPayment`, +`monthRejected` |
| 2 archivos de test | fixtures con los flags nuevos |

7 archivos modificados. **9 archivos de prueba OK, linter DU288 OK.**

---

## 6. El punto que más importa

`installmentStatusBucket` es lo que alimenta el cupo del numeral 6. Quedó así:

```js
const installmentStatusBucket = (installment) => {
  if (installment?.isRejected) return null
  if (installment?.isSentToPayment) return 'paid'
  if (installment?.isCommitted) return 'inPayment'
  return 'pending'
}
```

Y el llamador descarta el `null`:

```js
const bucket = installmentStatusBucket(installment)
if (!bucket) return
```

Sin ese `return null`, un mes que DGDP excluyó caería en `pending` y volvería a contarse como
disponible. Es el único lugar donde el estado del mes decide una regla normativa.

---

## 7. Resumen

| Pregunta | Respuesta |
| :--- | :--- |
| ¿El frontend toma los datos nuevos? | **Sí** — los 3 flags están conectados en los 7 archivos |
| ¿Quedó algo huérfano? | No. Los 11 usos de `isPaid` y los 4 de `paidAt` están resueltos |
| ¿Se perdió funcionalidad? | Sólo la columna *Pago efectivo*, cuyo dato ya no existe en este grano |
| ¿Falta conectar algo? | Los 3 montos nuevos, pero **no tienen dato hasta que exista el WF de pagos** |

### Pendiente anotado

Cuando el WF de pagos escriba montos reales, la columna *Monto* del modal debe pasar a
`amountPaid` para los meses ya enviados, y conviene agregar el desglose de descuentos al
comparador de DGDP.
