# Auditoría — vistas de solicitud y DGDP del WF de pagos

**Fecha:** 27-10-2026
**Normas aplicadas:** `estandar_visual/estandar_visual_obligatorio_du288.md` v1.3 ·
`estandar_visual/GUIDELINES_DEVELOPMENT.md` ·
skill `ufro-typescript-fullstack` (`references/du288-workflow.md`)

**Alcance.** Las dos vistas y sus componentes montados:

| Vista | Archivo | Líneas |
| :--- | :--- | ---: |
| Solicitud (jefe de proyecto) | `payments/_nroSolici/index.vue` | 1.014 |
| DGDP — bandeja | `payments/review/index.vue` | 447 |
| DGDP — detalle de cuota | `payments/review/_staffProvisionId/_installmentNumber.vue` | 1.390 |
| Componentes de pagos | `components/services-provision/payments/*.vue` | 8.631 |

15 hallazgos. El orden es por consecuencia, no por esfuerzo.

---

## A. Cálculos críticos

### A1 · El saldo que ve DGDP no descuenta lo rechazado — y el dato no le llega

`review/_staffProvisionId/_installmentNumber.vue:617`

```js
remainingAmount() {
  const total = Number(item.totalAmount || 0)
  const paid = Number(item.paidAmount || 0)
  const inProgress = Number(item.inProgressAmount || 0)
  return Math.max(0, total - paid - inProgress)
}
```

Es el mismo defecto que se corrigió el 26-10 en `sg_fupssSecgen18.mto_saldo`, vivo
en la ruta DGDP. Y aquí no se arregla en el frontend, porque **el dato no existe
en el payload**: `sg_epagsSecgen03` (líneas 113-120) sólo trae dos sumas.

```sql
(select isnull(sum(f4.mto_realpa), 0) ... and f4.cod_estfum = 3) as mto_pagado,
(select isnull(sum(f5.mto_apagar), 0) ... and f5.cod_estfum = 2) as mto_gestion,
```

No hay suma del estado 4. El modelo
(`du288-payment-review-installment-response.model.ts:25-27`) mapea `mto_total`,
`mto_pagado` y `mto_gestion`, y nada más.

El revisor DGDP rechaza una cuota, vuelve a entrar y lee un saldo que todavía
cuenta esa plata. Es quien decide, leyendo el número equivocado.

**Agravante:** `Math.max(0, …)` esconde el sobregiro. Si lo comprometido supera
lo decretado, muestra `$0` — una fila sana sobre un dato que no lo es. En la
bandeja del solicitante se tomó la decisión opuesta a propósito (§15.2 de
`rechazo_devolucion_y_estados.md`), así que las dos vistas además discrepan en
criterio.

**Corrección:** agregar `mto_rechazado` (estado 4) a `sg_epagsSecgen03`,
mapearlo en el modelo, restarlo en `remainingAmount` y quitar el `Math.max`.

---

### A2 · La vista DGDP recalcula a mano lo que el módulo probado ya resuelve

Ninguna de las dos vistas importa `paymentValidations.js` directamente. La de
solicitud lo recibe por los getters del store
(`store/service-provision-payment-detail.js`), que sí lo importan. La de DGDP no:
rehace el saldo con aritmética local.

`resolvePaymentAmountBalance` existe, tiene pruebas y ya conoce la regla del
26-10. Infringe §3.2 del estándar visual —«un patrón repetido dos o más veces
DEBE extraerse a un componente o helper compartido»— y la precedencia de fuentes
de la skill: el mismo número calculado por dos caminos distintos no es un
detalle de estilo, es la causa de A1.

---

### A3 · El tratamiento del rechazo no llegó a la vista DGDP

La vista DGDP **conoce** el estado 10: `DGDP_STATUS.REJECTED = 10` en
`utils/servicesProvisionDgdpReviewFilter.js:7`, y `statusFilter[10]` dice
«Rechazadas». Puede listarla y rotularla.

Lo que no tiene es **ninguna consecuencia visual del rechazo**. Un `grep` de
`=== 10`, `rejected` o `Rechaz` en las dos pantallas DGDP devuelve cero
coincidencias.

En la bandeja DGDP (`review/index.vue:174-182`) la cuota rechazada muestra su
monto y su neto en estilo normal:

```html
<span class="text-nowrap">{{ formatPrice(item.requestedAmount) }}</span>
<div class="font-weight-bold text-nowrap">{{ formatPrice(item.netAmount) }}</div>
```

Es exactamente el «A pagar fantasma» que se corrigió en la vista del solicitante
el 26-10. Allá la cuota rechazada tiene tachado (`is-void`), etiqueta
«Rechazado», se le suprimen los requisitos pendientes y el texto de confirmación
advierte que es definitivo. Acá nada de eso existe.

El trabajo del 26-10 aterrizó **sólo del lado del solicitante**. El lado que
toma la decisión quedó sin actualizar.

---

## B. El gate obligatorio no cubre la vista DGDP

### B1 · 12 archivos y ~8.000 líneas fuera de `validateDu288Ui.js`

`npm run lint:du288-ui` es paso obligatorio (§17 del estándar, y corre dentro de
`build:prod`). Su lista de objetivos —`utils/validateDu288Ui.js:6-37`— incluye la
vista de solicitud y sus componentes, y **omite toda la vista DGDP**:

| Archivo no cubierto | Líneas |
| :--- | ---: |
| `Du288PaymentMonthsReviewSection.vue` | 1.492 |
| `review/_staffProvisionId/_installmentNumber.vue` | 1.390 |
| `Du288PaymentExecutionSection.vue` | 1.368 |
| `Du288ExecutedCompensationSection.vue` | 913 |
| `review/index.vue` | 447 |
| `Du288NormativeDetailSection.vue` | 352 |
| `Du288InstallmentSummarySection.vue` | 340 |
| `Du288PaymentBudgetSection.vue` | 334 |
| `Du288PaymentAttendanceSection.vue` | 313 |
| `Du288ExecutionWeekSection.vue` | 242 |
| `Du288InstallmentEvidenceSection.vue` | 240 |
| `Du288MonthVersionsModal.vue` | 196 |
| `Du288PaymentAbsencesSection.vue` | 147 |

«Estándar visual DU288 validado en 39 archivos» tranquiliza, pero ninguno de
esos 39 es la vista DGDP.

### B2 · Aplicando sus propias reglas aparecen 4 incumplimientos

| Archivo:línea | Regla | Valor |
| :--- | :--- | :--- |
| `Du288PaymentMonthsReviewSection.vue:1288` | §5.1 / §16 peso prohibido | `font-weight: 800` |
| `Du288PaymentExecutionSection.vue:1123` | §5.1 / §16 mínimo 11 px | `font-size: 10px` |
| `Du288PaymentExecutionSection.vue:1167` | §5.1 / §16 mínimo 11 px | `font-size: 10px` |
| `Du288PaymentExecutionSection.vue:1357` | §5.1 / §16 mínimo 11 px | `font-size: 8px` |

Los tres tamaños son además un problema de accesibilidad (§14, contraste y
legibilidad); 8 px no es texto legible.

**Corrección:** agregar los 13 archivos a `vueTargets` y resolver los 4. Ojo con
el orden: agregarlos primero hace fallar `build:prod` hasta que se corrijan.

---

## C. Estándar visual

### C1 · §6.2 — dos convenciones de valor ausente en la misma pantalla

«Valores ausentes DEBEN usar el texto único *Sin información* o *No aplica*».

| Archivo | `'—'` | `noInformation` |
| :--- | ---: | ---: |
| `review/index.vue` | 7 | 0 |
| `review/…/_installmentNumber.vue` | 7 | 5 |
| `Du288NormativeDetailSection.vue` | 7 | 1 |
| `Du288PaymentExecutionSection.vue` | 3 | 3 |
| `Du288PaymentMonthsReviewSection.vue` | 1 | 2 |
| `Du288PaymentBudgetSection.vue` | 0 | 12 |
| **Total** | **26** | **23** |

`Du288PaymentBudgetSection` cumple al 100 % y `review/index.vue` incumple al
100 %, y se ven en la misma pantalla: la sección de montos dice «Sin
información» y la de al lado dice «—».

### C2 · §9.1 — dos formatos de fecha en la misma página

El helper compartido `formatDateOnly` devuelve `DD/MM/YYYY` con barras, como
manda §9.1. Pero `_installmentNumber.vue:379-386` define su propio
`formatDateTime` que devuelve **guiones**:

```js
return `${pad(date.getDate())}-${pad(date.getMonth() + 1)}-${date.getFullYear()} …`
```

La misma pantalla muestra el período como `01/09/2026 – 30/09/2026` y la fecha
de la observación como `27-10-2026 14:30`.

### C3 · §3.1 y §11 — dos modales fuera de norma, y son los del dinero

§3.1: «Todo modal DU288 DEBE utilizar `modal-class="pds-ui-modal"` y
`body-class="pds-ui-modal-body"`».

`Du288PaymentMonthsReviewSection.vue:270` (descuentos) y `:399` (compensación):

```html
<b-modal v-model="deductionsModalOpen" size="xl" hide-footer no-stacking
         body-class="p-0" :title="deductionsModalTitle" @hidden="cancelEditing">
```

- sin `modal-class="pds-ui-modal"` → §3.1
- `body-class="p-0"` en vez de `pds-ui-modal-body` → §3.1; el padding se
  recupera con un `p-3` de Bootstrap adentro, o sea con un selector global en
  vez del token DU288 (§2, §3.1)
- sin `centered` → §11 «estar centrado»
- `hide-footer` con la acción de guardar dentro del cuerpo → §11 «tener footer
  real para acciones» y «no se permiten botones simulados dentro del cuerpo»

Los otros 6 modales DGDP (`_installmentNumber.vue:204`,
`Du288PaymentExecutionSection.vue:196/240/294`, `Du288MonthVersionsModal.vue:2`)
cumplen los cuatro puntos. Estos dos son la excepción, y son justamente los dos
donde el revisor ingresa montos.

### C4 · §8 — el filtro DGDP ofrece dos estados que nada escribe

`lang/es/pds.js:1575-1583` y el filtro ofrecen:

- `8: 'Enviadas a remuneraciones'`
- `11: 'Devueltas de Finanzas'`

Ningún PA de `cambios_pa` escribe 8 ni 11 (auditado en §6.2 de
`rechazo_devolucion_y_estados.md`: sólo `sg_epaguSecgen02` y `sg_epaguSecgen03`
escriben `cod_estcuo`, y no producen esos valores). Son dos opciones de filtro
que no pueden devolver filas nunca.

§8: «Los badges DEBEN representar un estado real». El mismo criterio aplica a un
filtro: ofrecer un estado inalcanzable manda al revisor a una lista vacía sin
explicación.

---

## D. Textos

### D1 · §15 — texto visible en duro en la vista DGDP

«Todo texto visible DEBE provenir de `lang/es/pds.js` o del catálogo normativo».

| Ubicación | Texto |
| :--- | :--- |
| `Du288PaymentMonthsReviewSection.vue:56` | `<label …>Año</label>` |
| `Du288PaymentMonthsReviewSection.vue:74` | `title="El mes de pago ya pasó. La cuota se paga igual…"` |
| `Du288PaymentMonthsReviewSection.vue:231` | `title="Descuentos y ausencias"` |
| `Du288PaymentExecutionSection.vue:206` | `Detalle de Compensación Horaria` |
| `_installmentNumber.vue:479-487` | las 4 cadenas del respaldo justificativo |
| `_installmentNumber.vue:604` | `'cuota decretada'` / `'cuotas decretadas'` |
| `_installmentNumber.vue:609-610` | `'Hasta 12 cuotas (con extensión autorizada)'` / `'Máx. 2 cuotas (normativa general DU 288)'` |
| `_installmentNumber.vue:781/784` | los dos toasts del período de pago |
| `_installmentNumber.vue:897` | `'No fue posible revalidar el panel normativo.'` |

### D2 · §5.1 — un título en Title Case

`Detalle de Compensación Horaria` capitaliza cada palabra. §5.1: «Títulos y
etiquetas DEBEN usar formato oración». Debe ser `Detalle de compensación
horaria`.

### D3 · §15 — terminología y abreviaturas

- `'Máx. 2 cuotas (normativa general DU 288)'`: §15 pide terminología oficial y
  prohíbe abreviaturas distintas para el mismo concepto. «Máx.» abreviado, y
  **`DU 288` con espacio** donde el resto del sistema escribe `DU288`.

### D4 · §3.2 y §15 — `MONTH_NAMES` duplicado byte a byte en 6 archivos

`payments/index.vue`, `review/index.vue`, `_installmentNumber.vue`,
`Du288InstallmentSummarySection.vue`, `Du288PaymentExecutionSection.vue`,
`Du288PaymentMonthsReviewSection.vue` — las seis copias tienen el mismo hash.

Y ya existe `getMonthYearLabel` en
`utils/services-provision/normative/formatters.js:699`. Hay un helper compartido
y seis copias que lo ignoran.

### D5 · Dos cadenas iguales donde debería haber dos distintas

`_installmentNumber.vue:481-487`: el tag de evidencia asigna el **mismo texto** a
`detail` y a `message`, en las dos ramas. Es copia-pega, no una distinción.

En el mismo objeto, `blocking: true` es **incondicional**, incluso cuando
`hasEvidence` es verdadero y `status` queda en `'ok'`. Funciona sólo porque
`blockingTags` filtra después por `status`. Un requisito satisfecho marcado como
bloqueante es frágil: cualquiera que use `tag.blocking` sin ese segundo filtro
obtiene lo contrario de lo que el dato dice.

### D6 · Dos helpers compartidos devuelven texto no catalogado

- `utils/formatPriceCLP.js`: devuelve `"Invalid input"` ante un valor no
  numérico. Es **inglés técnico apuntando a la UI** (§15, §16 «mostrar datos
  crudos del backend»). Hoy todas las llamadas de estas dos vistas lo protegen
  con `Number(x) || 0`, así que no se ve — pero el helper es compartido y la
  próxima llamada sin guarda lo imprime.
- `formatters.js:645` `formatCompensationRange` devuelve `'Incompleto'` en duro.

---

## Qué se verificó y está bien

- **Montos (§9.3).** Todo pasa por `formatPriceCLP` → `toLocaleString('es-CL', {style:'currency', currency:'CLP'})`. Sin decimales, separador local. Sin un solo formateo manual en las dos vistas.
- **Duraciones (§9.2).** `formatDuration` convierte a minutos enteros y emite `N h`, `N h M min` o `N min`. Ninguna hora decimal visible.
- **Fechas civiles (§9.1).** Los parseos usan `new Date(\`${x}T00:00:00\`)`, que es local y no corre el día. El único `new Date(text)` suelto (`_installmentNumber.vue:382`) recibe un *timestamp*, no una fecha civil, y usa getters locales: correcto.
- **Alcance de estilos (§3.1).** Las tres páginas tienen `.pds-du288-scope`.
- **Estilos inline (§16).** Ninguno estático en los 12 archivos no cubiertos. El único del paquete estaba en `Du288InstallmentFormSection.vue:90` y se corrigió el 26-10.
- **Alertas (§14).** Todos los errores y avisos van por `b-alert`, que aporta `role="alert"`. La vista de solicitud además marca explícitamente un `<p role="alert">`.
- **Guarda de descuentos.** `sg_fumeuSecgen03` rechaza descuentos negativos y descuentos mayores al monto del mes, así que el neto no puede quedar negativo desde la base.
- **`amountSent`.** `net: Number(row.amountSent ?? (amount - deductions))` es correcto: el PA devuelve `mto_realpa` crudo —sin `isnull(…,0)`— así que llega `null` mientras la cuota está abierta y el `??` cae a la resta. Con un `isnull(…,0)` en el PA, todos los netos se mostrarían en cero.

---

## Resumen

| | Hallazgo | Norma | Dónde |
| :--- | :--- | :--- | :--- |
| A1 | saldo DGDP sin descontar lo rechazado; dato ausente en el PA | cálculo | `_installmentNumber.vue:617`, `sg_epagsSecgen03` |
| A2 | la vista DGDP recalcula el saldo a mano | §3.2 | `_installmentNumber.vue` |
| A3 | el rechazo no tiene tratamiento visual en DGDP | §8 | bandeja y detalle DGDP |
| B1 | 13 archivos DGDP fuera del gate obligatorio | §17 | `validateDu288Ui.js:6-37` |
| B2 | `font-weight: 800`, `10px` ×2, `8px` | §5.1 §16 | 2 componentes |
| C1 | 26 `'—'` contra 23 `noInformation` | §6.2 | 6 archivos |
| C2 | `DD/MM/YYYY` y `DD-MM-YYYY` en la misma página | §9.1 | `_installmentNumber.vue:379` |
| C3 | los 2 modales de dinero sin `pds-ui-modal`, sin `centered`, sin footer | §3.1 §11 | `…MonthsReviewSection.vue:270/399` |
| C4 | filtro con 2 estados inalcanzables | §8 | `pds.js:1575`, filtro DGDP |
| D1 | 9 textos visibles en duro | §15 | 3 archivos |
| D2 | título en Title Case | §5.1 | `…ExecutionSection.vue:206` |
| D3 | «Máx.» y «DU 288» | §15 | `_installmentNumber.vue:610` |
| D4 | `MONTH_NAMES` duplicado en 6 archivos | §3.2 §15 | 6 archivos |
| D5 | `detail` y `message` iguales; `blocking` incondicional | — | `_installmentNumber.vue:481` |
| D6 | `"Invalid input"` y `'Incompleto'` sin catalogar | §15 | 2 helpers |

**Nada de esto se modificó.** A1 es el que cambia una decisión: es el número que
el revisor DGDP lee para aprobar o rechazar.
