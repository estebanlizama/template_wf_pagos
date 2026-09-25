# Impacto — qué estados de `sg_fume` usa hoy el sistema de resolución

Antes de cambiar el catálogo hay que saber qué estados toca realmente el código ya desarrollado.
La respuesta es corta y tiene una sorpresa.

---

## 1. Resolución escribe **un solo** estado

| Punto | Qué hace |
| :--- | :--- |
| [repository.ts:3561](../../../sg-solicitudes-backend/src/repositories/storedProcedures/service-provision-request-procedures.repository.ts:3561) | `cod_estcuo: 1` — literal, sin variable |
| [sg_fumeuSecgen01.txt:30](../../../sissolic-procedimientos/sg_fumeuSecgen01.txt:30) | `@cod_estcuo int = 1` — mismo valor por defecto |
| [sg_fumeuSecgen01.txt:258](../../../sissolic-procedimientos/sg_fumeuSecgen01.txt:258) | el `INSERT` usa ese parámetro |

**No existe ningún otro punto de escritura.** `updateInstallmentStatusesByRequest` es un stub
vacío (`void nroSolici; void codEstcuo;`), así que la única transición que el sistema actual
provoca sobre un mes es *"nace en 1"*.

## 2. El único otro código referenciado es el 3, y está muerto

[sg_fumeuSecgen01.txt:68](../../../sissolic-procedimientos/sg_fumeuSecgen01.txt:68):

```sql
and cod_estcuo not in (1, 3)
   -- 'No se pueden modificar las cuotas porque estan en proceso de visacion o pago'
```

La guarda permite editar meses en 1 *Propuesta* o 3 *Observada*. Pero **nada escribe 3**: no hay
código que lo ponga. Es una guarda preparada para un flujo que todavía no existe.

## 3. Nadie compara el código numéricamente

`installmentStatusCode` viaja del PA al frontend y **nunca se compara contra un número**:

| Archivo | Uso |
| :--- | :--- |
| `du288-staff-previous-provision-response.model.ts:57` | mapeo `cod_estcuo` → `installmentStatusCode` |
| `:349` | se copia a `statusCode` del installment |
| `:426` | se elimina del objeto padre |

En todo el frontend no hay una sola comparación contra 1, 6, 8, 9 ni nada. El código viaja como
dato muerto.

---

## 4. 🔴 Lo que sí decide el comportamiento es **la etiqueta**, por coincidencia de texto

En [du288-staff-previous-provision-response.model.ts:334-345](../../../sg-solicitudes-backend/src/models/response/service-provision/du288-staff-previous-provision-response.model.ts:334):

```ts
const normalizedStatus = status.toUpperCase();
const isPaid = Boolean(row.paidAt) || normalizedStatus.includes('PAGAD');
const isInPayment = !isPaid && (Boolean(row.sentToPayrollAt) ||
    normalizedStatus.includes('PAGO')   ||
    normalizedStatus.includes('TRAMIT') ||
    normalizedStatus.includes('PROCES') ||
    normalizedStatus.includes('REMUN'));
```

`isPaid` e `isInPayment` son **lo único** que el frontend consume: el cupo del numeral 6, los
badges del comparador, la advertencia de doble pago, el resumen "2 de 3 cuotas pagadas". Todo
sale de estas dos banderas, y estas dos banderas salen de buscar substrings en
`sg_ecuo.des_estcuo`.

### Cómo clasifica hoy cada etiqueta

| Etiqueta | Substring que engancha | Resultado |
| :--- | :--- | :--- |
| Propuesta | — | pendiente |
| En visación | — | pendiente |
| Observada | — | pendiente |
| Aprobada | — | pendiente |
| Disponible **pago** | `PAGO` | **en pago** |
| Solicitada **pago** | `PAGO` | **en pago** |
| Autorizada **pago** | `PAGO` | **en pago** |
| Enviada **remun**eraciones | `REMUN` | **en pago** |
| **Pagad**a | `PAGAD` | **pagada** |
| Rechazada | — | pendiente |
| Devuelta Finanzas | — | pendiente |
| Bloqueada | — | pendiente |

Ya hay dos errores en esta tabla, hoy, con el catálogo actual:

- **"Disponible pago" se cuenta como en pago.** Un mes que sólo está disponible consume cupo
  como si estuviera comprometido.
- **"Aprobada" se cuenta como pendiente.** Un mes ya aprobado por DGDP no consume cupo.

---

## 5. 🔴 Con los catálogos nuevos, dos cosas se rompen en silencio

### 5.1 Nada volverá a ser `isPaid`

`isPaid` depende de `row.paidAt` o de la etiqueta *Pagada*. En el modelo nuevo:

- `fec_pago` **sale de `sg_fume`** y sube a `sg_epag` → `paidAt` llega vacío.
- *Pagada* **se elimina del catálogo** → ninguna etiqueta contiene `PAGAD`.

Resultado: `isPaid` queda permanentemente en `false`. Se apagan los badges "Pagada", el resumen
`2 de 3 cuotas pagadas`, `hasPaidInstallments` y la advertencia de doble pago sobre una
compensación ya pagada ([textSimilarityUtil.js:927](../../../sg-solicitudes-frontend/utils/textSimilarityUtil.js:927)).

### 5.2 Tres estados comprometidos se contarán como libres

| Estado nuevo | Cómo lo clasificaría el matching | Cómo debería ser |
| :--- | :--- | :--- |
| 2 En visación | pendiente | comprometido |
| 3 Observada | pendiente | comprometido — devolver **no libera** |
| 4 Aprobada | pendiente | comprometido |

Los tres describen meses **tomados**, y el cupo del numeral 6 los vería como disponibles. Un
solicitante podría pasarse del límite de 2 cuotas por año mientras DGDP revisa.

> Ojo: con `sg_efum` de 4 estados el mes nunca está en 2, 3 ni 4 — se queda en 6 *Solicitada
> pago*, que sí engancha con `PAGO`. **El bug no aparece en el mes**, pero sí en cuanto el
> comparador lea el estado del **encabezado** desde `sg_ecuo`, que es lo que hay que hacer para
> mostrar cuotas en vez de meses.

---

## 6. Qué hay que cambiar

### 6.1 Reemplazar el matching de texto por el código

Ahora que el catálogo está cerrado y es corto, la clasificación debe salir del número:

```ts
// sg_efum
const MES_LIBRE       = [1];         // Propuesta
const MES_COMPROMETIDO = [6];        // Solicitada pago
const MES_ENVIADO     = [8];         // Enviada remuneraciones
const MES_BLOQUEADO   = [12];        // Bloqueada  -> NO libera cupo

// sg_ecuo (encabezado)
const CUOTA_BORRADOR     = [1];
const CUOTA_COMPROMETIDA = [6, 2, 3, 4];
const CUOTA_ENVIADA      = [8];
const CUOTA_LIBERADA     = [10];
```

Es más corto que el matching actual, y deja de depender de cómo se redacte una etiqueta.

### 6.2 Renombrar el concepto en la API

`isPaid` deja de tener sentido: el sistema nunca sabe si se pagó. Lo más fuerte que conoce es
*enviada a pago*. Conviene renombrar a algo honesto —`isSentToPayment`— y no dejar una bandera
que siempre vale `false`.

### 6.3 `sg_fumeuSecgen01`

```sql
-- antes
@cod_estcuo int = 1
and cod_estcuo not in (1, 3)

-- después
@cod_estfum int = 1
and cod_estfum not in (1, 12)   -- editable si está libre o bloqueado
```

El 3 desaparece de la guarda: era *Observada*, estado del encabezado, que en el mes nunca
existió.

---

## 7. Resumen

| Pregunta | Respuesta |
| :--- | :--- |
| ¿Cuántos estados escribe resolución en `sg_fume`? | **Uno: el 1** |
| ¿Cuántos lee? | Todos, pero sólo para mostrarlos |
| ¿Alguien compara el código numérico? | **No, en ninguna capa** |
| ¿Qué decide el comportamiento? | La **etiqueta**, por coincidencia de substring |
| ¿Qué se rompe al cambiar el catálogo? | `isPaid` queda siempre `false`, y los estados de trámite se contarían como libres |

**Lo bueno:** como resolución escribe un solo estado y nadie compara códigos, el cambio de
catálogo casi no toca el flujo de resolución.

**Lo que hay que arreglar sí o sí:** la clasificación por texto. Es frágil hoy —ya produce dos
errores con el catálogo actual— y con los catálogos nuevos produce tres más.
