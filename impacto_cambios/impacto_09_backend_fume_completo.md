# `sg_fume` en el backend — inventario completo

Barrido de todo lo que toca `sg_fume`, sus estados y sus cuotas en
`sg-solicitudes-backend`. 20 archivos, 266 ocurrencias.

Alcance: **`sg_epag`, `sg_dpag` y `ext_cuotas` quedan fuera.**

---

## 1. Mapa por responsabilidad

| Grupo | Archivos | Estado |
| :--- | :--- | :--- |
| **A. Escritura** | repository, query template, workflow.service | 3 cambios mecánicos |
| **B. Lectura** | PA → repository → modelo de respuesta → controller | el grueso del trabajo |
| **C. Cálculo** | repository (espejo del cupo) | sin cambios |
| **D. Código muerto** | 7 llamadas a un stub + su constante | **eliminar** |
| **E. Catálogo** | `installment-status.controller`, `sg-ecuo.model` | decidir |
| **F. Lado pago** | `du288-payable-provision`, `payment-access-summary` | fuera de alcance, pero queda inconsistente |

---

## 2. Grupo A — escritura

```
workflow.service.ts:216 / :409     if (isSubmitted)
  └─ repository.syncNormativeRequestStaffMonths()      :3957
      └─ repository.syncStaffMonths()                  :3539
          ├─ deriveExecutionMonths()                   :353
          └─ query 'updateStaffMonths'                 :162
```

| # | Archivo | Cambio |
| :-- | :--- | :--- |
| A1 | `repository.ts:3561` | `cod_estcuo: 1` → `cod_estfum: 1` — el **valor no cambia** |
| A2 | `service-provision-request.ts:162` | `@cod_estcuo` → `@cod_estfum` |
| A3 | `workflow.service.ts` | ninguno |

`deriveExecutionMonths` y `countExecutionMonths` no se tocan: derivan meses de fechas y no
saben nada de estados ni cuotas.

---

## 3. Grupo B — lectura

### B1 · `du288-staff-previous-provision-response.model.ts` — el archivo más afectado (52 hits)

**Mapeo de columnas** (líneas 54-70):

| Hoy | Después |
| :--- | :--- |
| `nro_cuota: 'installmentNumber'` | `corr_fume: 'monthSequence'` |
| `cod_estcuo: 'installmentStatusCode'` | `cod_estfum: 'monthStatusCode'` |
| `des_estcuo: 'installmentStatus'` | `des_estfum: 'monthStatus'` |
| `fec_pago: 'paidAt'` | **eliminar** — la columna no existe |
| `ano_pago: 'paymentYear'` | **eliminar** |
| `mes_pago: 'paymentMonth'` | **eliminar** |
| — | **agregar** `mto_realpa`, `mto_deslic`, `mto_dessg` |

**Agrupador** (:327-378): agrupa por `installmentNumber`. `corr_fume` sigue siendo único por
mes, así que **en esta fase no se rompe**. Pero el nombre miente: agrupa meses, no cuotas.

**Clasificación** (:334-345) — 🔴 se rompe:

```ts
const isPaid = Boolean(row.paidAt) || normalizedStatus.includes('PAGAD');
```

`paidAt` desaparece y ninguna etiqueta de `sg_efum` contiene `PAGAD`. Debe pasar a comparar
`cod_estfum` contra los códigos del catálogo.

**Agregados** (:454-505): `paidInstallments`, `pendingInstallments`, `inPaymentInstallments`,
`paidAmount`, `pendingAmount`, `paymentStatus`, `hasPaidInstallments`, `hasPaymentInProgress`.
Todos derivan de `isPaid`/`isInPayment`. En esta fase quedan en cero — que es lo correcto, porque
ninguna fila llega a un estado distinto de 1.

### B2 · `service-provision-request.controller.ts`

Dos endpoints (`:1665` DGDP, `:1689` solicitante) que llaman a `buildStaffPreviousProvisionsHistory`.
Solo cambian si se renombra el contrato de la API.

### B3 · `request-staff.model.ts:300`

```ts
installments?: Array<{ nroCuota; anoProp; mesProp; codEstcuo; desEstcuo }>;
```

Tipo anidado con los nombres viejos. **No tiene ningún consumidor** — nada lo lee ni lo escribe.
Es un contrato declarado y abandonado: o se actualiza, o se elimina.

### B4 · `request-service.model.ts:103`

`installmentStatusId?: number` — mismo caso, declarado y sin uso.

---

## 4. Grupo C — cálculo del cupo

`repository.ts:437` `getInstallmentYearMonthKeys` y `:459` `getCommittedInstallmentMonthsForYear`
son el espejo backend de `installmentMonthsForYear` del frontend.

**No cambian.** Cuentan claves `año-mes` de `proposedYear/Month` y `executionYear/Month`, y el
grano del mes no se altera. Solo conviene renombrarlos si se renombra el contrato.

Lo mismo con `monthlyContributionOf` (:400): usa `sg_fups.mto_total`, `cod_tpps` y `tot_cuotas`
— nada de `sg_fume`.

---

## 5. Grupo D — 🔴 código muerto: 7 llamadas a un stub

`updateInstallmentStatusesByRequest` ([repository.ts:3898](../../../sg-solicitudes-backend/src/repositories/storedProcedures/service-provision-request-procedures.repository.ts:3898))
es un método vacío:

```ts
void nroSolici; void codEstcuo; void connect; void disconnect;
```

Y lo llaman **siete veces**:

| Archivo | Líneas | Con qué código |
| :--- | :--- | :--- |
| `workflow.service.ts` | 1081 | `REJECTED` / `RETURNED_TO_CORRECTION` |
| `service-provision-request-approval.controller.ts` | 592, 666 | idem |
| `service-provision-request-approval.repository.ts` | 239, 255 | `ENABLED` / `RETURNED_TO_CORRECTION` |
| `resolution-approval.repository.ts` | 509, 527 | idem |

Los códigos vienen de `ServiceProvisionInstallmentStatusCode`
([constant.ts:37](../../../sg-solicitudes-backend/src/constants/service-provision.constant.ts:37)):

```ts
CREATED: 1, IN_REVIEW: 2, RETURNED_TO_CORRECTION: 3, ENABLED: 5, REJECTED: 10
```

Son los códigos **viejos de `sg_ecuo`**, y tres de ellos (2, 5, 10) ni siquiera existen en
`sg_efum`.

**Por qué no rompe nada hoy:** `sg_fupssSecgen17` filtra `soli.cod_estsol not in (4)`, así que las
solicitudes rechazadas no entran al comparador. La exclusión ya está resuelta por el estado de la
**cabecera**.

> **Acción: eliminar el método, las 7 llamadas, la query
> `updateInstallmentStatusesByRequest` y la constante.** Dejarlo es peor que borrarlo — invita a
> que alguien lo implemente y genere una doble exclusión, ahora con códigos inválidos.

---

## 6. Grupo E — el catálogo tiene CRUD propio

| Archivo | Qué es |
| :--- | :--- |
| `installment-status.controller.ts` | CRUD completo de `sg_ecuo` (GET, GET/{id}, POST, PATCH) — 27 hits |
| `sg-ecuo.model.ts` | el modelo |
| `service-provision-request.ts:369-385` | 4 queries: `sg_ecuossSecgen01/02`, `sg_ecuosiSecgen01`, `sg_ecuouSecgen01` |

Sigue siendo válido: `sg_ecuo` no desaparece, pasa a ser el catálogo del encabezado de pago.

**Decisión:** ¿hace falta el equivalente para `sg_efum`? Solo si el catálogo va a administrarse
por pantalla. Si es fijo — 4 filas que cambian cuando cambia el diseño — basta con el `INSERT` y
no hace falta controlador, modelo ni 4 PA nuevos.

> Recomendación: **no crear CRUD para `sg_efum`.** Y de paso revisar si el de `sg_ecuo` se usa,
> porque un catálogo de estados editable en caliente es una fuente de incidentes.

---

## 7. Grupo F — el lado de pago queda inconsistente

`du288-payable-provision-response.model.ts` mapea la salida de `sg_fupssSecgen18`:

```
cant_cuotas       → installmentCount
cant_cuotas_pend  → pendingInstallments
cant_cuotas_gest  → inProgressInstallments
cant_cuotas_paga  → paidInstallments
cant_cuotas_rech  → rejectedInstallments
cant_cuotas_disp  → payableInstallments
cod_estpag        → paymentStatusCode
```

Ese PA cuenta **filas de `sg_fume`** y las reporta como cuotas, agrupando por `cod_estcuo` en
`(1)`, `(6,7,8)`, `(9)`, `(10)` — códigos que dejan de existir.

**Queda fuera de alcance**, pero hay que decidir qué hacer mientras tanto:

| Opción | Consecuencia |
| :--- | :--- |
| Dejarlo roto | el PA falla al leer `cod_estcuo`; la bandeja de pagos deja de funcionar |
| Adaptarlo mínimamente a `cod_estfum` | sigue contando meses como cuotas, pero no revienta |
| Reescribirlo contra `sg_epag` | correcto, pero es el WF de pagos |

> Recomendación: **adaptación mínima** — cambiar `cod_estcuo` por `cod_estfum` con los códigos
> nuevos y renombrar las salidas de `cuotas` a `meses`. Es honesto con lo que realmente cuenta, y
> no bloquea esta fase.

---

## 8. Tests que hay que actualizar

| Archivo | Hits | Qué cubre |
| :--- | :--: | :--- |
| `du288-staff-previous-provision-response.unit.ts` | 23 | agrupación y agregados |
| `service-provision-authorized-amount.unit.ts` | 22 | cupo y monto autorizado |
| `service-provision-workflow.service.unit.ts` | 7 | que el sync corra fuera de la transacción |
| `du288-payment-access-summary.unit.ts` | 5 | `cod_estpag` |
| `du288-payable-provision-response.unit.ts` | 2 | mapeo |

El de `authorized-amount` es el que más importa: valida el cupo del numeral 6, que es la
validación normativa con más riesgo.

---

## 9. Resumen ejecutivo

| | Archivos | Esfuerzo |
| :--- | :--: | :--- |
| Renombres mecánicos | 3 | bajo |
| Modelo de respuesta (mapeo + clasificación) | 1 | **medio-alto** |
| Eliminar código muerto | 5 | bajo, pero toca 7 puntos |
| Tipos declarados sin uso (`request-staff`, `request-service`) | 2 | trivial |
| Catálogo `sg_efum` | 0 si no se crea CRUD | — |
| Lado pago (adaptación mínima) | 2 + 1 PA | medio |
| Tests | 5 | medio |

**Lo que NO se rompe:** el cálculo del cupo (grupo C), `deriveExecutionMonths`,
`monthlyContributionOf`, y todas las validaciones normativas que no leen `sg_fume`.

**Lo único con riesgo real** es el modelo de respuesta: ahí viven la agrupación y la
clasificación, y de ahí sale todo lo que el frontend usa para el cupo y el comparador.

---

## 10. Decisiones antes de codificar

1. **¿Se renombra el contrato de la API** (`installments` → `months`)? Barato ahora, y evita que
   la próxima fase tenga que desarmar una estructura mal nombrada.
2. **`request-staff.model.ts:300` y `request-service.model.ts:103`** — ¿se actualizan o se
   eliminan? No tienen consumidores.
3. **`sg_fupssSecgen18`** — ¿adaptación mínima o se deja caer hasta el WF de pagos?
4. **CRUD de `sg_efum`** — confirmar que no se crea.
