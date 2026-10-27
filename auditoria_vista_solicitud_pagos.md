# Auditoría de la vista de solicitud de pagos — paridad con DGDP

27-10-2026 · Contra `estandar_visual_obligatorio_du288.md` v1.3 y contra lo
aplicado en la vista DGDP (§16 y §17 de `rechazo_devolucion_y_estados.md`).

La pregunta de esta auditoría no es «¿la vista está bien?» sino **«¿lo que se
arregló en DGDP está arreglado también acá?»**. Varios de los defectos que la
auditoría de DGDP encontró viven en código espejo: la misma propiedad calculada,
la misma cadena en duro, el mismo `Math.max` escrito dos veces. Eso es lo que se
revisó.

## Alcance

| Archivo | Líneas |
| :--- | ---: |
| `payments/index.vue` (bandeja) | 566 |
| `payments/_nroSolici/index.vue` (detalle) | 1.015 |
| `Du288InstallmentFormSection.vue` | 1.391 |
| `Du288ExecutedCompensationSection.vue` | 913 |
| `Du288InstallmentSubmitModal.vue` | 359 |
| `Du288InstallmentsSection.vue` | 329 |
| `Du288PaymentContextSection.vue` | 284 |
| `Du288ExecutionWeekSection.vue` | 242 |
| `Du288InstallmentEvidenceSection.vue` | 240 |
| `Du288MonthVersionsModal.vue` | 196 |
| `Du288PaymentValidationsSection.vue` | 113 |
| `Du288PaymentWorkspace.vue` | 99 |

Total: 5.747 líneas. **Nada de esto se modificó.**

---

## A · Cálculo

### A1 · El saldo del módulo de dinero se acota a cero en su origen

`resolvePaymentAmountBalance` devuelve:

```js
remaining: Math.max(0, authorized - consumed)
```

El §16.1 dejó escrito lo contrario para la vista DGDP —«un saldo negativo
significa más comprometido que decretado, y eso hay que verlo»— y
`resolveProvisionRemainingAmount` se escribió sin acotar, con una prueba que lo
fija. **Las dos funciones del mismo módulo responden hoy distinto a la misma
pregunta**: la de DGDP muestra el sobregiro, la del solicitante lo deja en cero.

La consecuencia alcanza al arreglo de ayer: `resolveDraftInstallmentBalance`
—que el modal de envío ya usa (§17.1)— parte de `remaining`, así que su «Saldo
disponible» tampoco puede mostrar un sobregiro originado en cuotas **ya
enviadas**. Solo lo muestra si el exceso viene de otros borradores.

Qué hay que mirar antes de tocarlo: `remaining` lo consumen
`canCreateInstallment` (store:111), `unreservedAuthorizedBalance`
(`_nroSolici:489`), `availableAuthorizedAmount`
(`Du288InstallmentFormSection:609`) y la línea «Saldo» del contexto. Los tres
primeros comparan contra cero o restan, así que quitar el `Math.max` no les
cambia el veredicto; ninguna prueba fija el caso `consumed > authorized`. No es
un cambio de una línea, pero tampoco es un cambio de régimen.

### A2 · «Saldo por gestionar» y «Espacio en la cuota» acotados donde se escribe el monto

`Du288InstallmentFormSection` —el formulario donde el solicitante escribe el
monto— tiene el mismo patrón que el modal de envío tenía antes del §17.1:

| Línea | Propiedad | Problema |
| :--- | :--- | :--- |
| 473 | `remainingCapAmount` | `Math.max(0, effectiveCap - selectedRequested)` |
| 614 | `remainingAfterDraft` | `Math.max(0, availableAuthorizedAmount - selectedRequested)` |
| 156 (contexto) | línea «Saldo» | `Math.max(0, remaining)`, redundante sobre un valor ya acotado |

Importa menos de lo que parece, y hay que decirlo: `balanceExceeded` (:615) y
`capExceeded` (:630) **sí** detectan el exceso, bloquean el guardado y muestran
«La cuota supera el saldo autorizado disponible de …». Así que no se escapa
dinero. Lo que queda es una incoherencia de lectura: el panel de límites dice
«Saldo por gestionar: $0» mientras el mensaje de error dice que se superó el
saldo, y el usuario tiene que decidir a cuál de los dos creerle.

### A3 · `otherProposedAmount` duplica el helper que se creó ayer

`Du288InstallmentFormSection:600-612` ya hacía, a mano, lo que ayer se extrajo
al módulo como `resolveDraftInstallmentBalance`:

```js
otherProposedAmount() {
  return Math.max(0, Number(this.paymentBalance.proposed || 0)
    - paymentInstallmentProposedAmount(this.installment || {}))
}
```

Es la misma resta —sacar el borrador propio de `proposed` para no descontarlo
dos veces— con un término más: `availableAuthorizedAmount` suma de vuelta
`paymentInstallmentConsumedAmount(installment)` para el caso de editar una cuota
ya enviada. **La versión del formulario es la más completa de las dos.** El
helper nuevo debería absorber ese término y el formulario pasar a usarlo; si no,
el módulo de dinero y el formulario van a volver a separarse.

Es un hallazgo sobre el cambio de ayer, no sobre código viejo.

### A4 · El fallback de «Comprometido» cuenta lo rechazado dos veces

`Du288PaymentContextSection:188-192`:

```js
inProgressAmount() {
  const fromSummary = Number(this.provisionSummary?.inProgressAmount)
  if (Number.isFinite(fromSummary)) return Math.max(0, fromSummary)
  return Math.max(0, Number(this.paymentBalance.consumed || 0) - this.paidAmount)
}
```

`consumed` suma los estados 2, 3, 4, 8, 10 y 11 —el **10 incluido**—, así que el
fallback mete lo rechazado dentro de «Comprometido», y cuatro líneas más abajo
la ficha vuelve a mostrarlo como «Bloqueado por rechazo». Sumando lo que el
usuario lee, el monto rechazado aparece dos veces.

No se dispara mientras `sg_fupssSecgen18` entregue `mto_gestion` —que sí es solo
el estado 2—, por eso es un defecto latente y no un número equivocado hoy. El
arreglo es restar también lo rechazado en el fallback, o eliminarlo: si el
agregado del PA no llega, es mejor «No informado» que una suma inventada.

### A5 · `sg_fupssSecgen18` no devuelve `mto_rechazado`

El PA de la bandeja del solicitante calcula `mto_saldo` descontando los meses en
estado 4 (línea 110), pero no expone el monto rechazado como columna. El PA de
DGDP sí lo hace desde el §16.1 (`mto_rechazado` en `sg_epagsSecgen03`).

Resultado: la bandeja del solicitante **descuenta** el rechazo del saldo pero no
puede **nombrarlo**. El desglose de la celda de monto dice «Saldo $X» y el
usuario no tiene cómo saber que la diferencia contra el total es un rechazo y no
un pago. El detalle sí lo muestra, porque ahí la cifra sale de la lista de
cuotas y no del agregado.

Es el mismo agregado, la misma forma de resolverlo: una columna más en el
`select`, con el `isnull(sum(case when fume.cod_estfum = 4 …))` que ya está
escrito tres líneas más arriba.

---

## B · Cobertura del gate

### B1 · La vista del solicitante está completa, salvo un componente prestado

Los 14 archivos de la vista están en `vueTargets`, y el gate pasa sin
incumplimientos: **ninguna violación de tipografía** (§5.1) ni estilo inline
estático (§16) en toda la vista. Esto es lo contrario de lo que pasaba en DGDP,
y la razón es histórica: esta vista nació con el gate y DGDP se agregó después.

La única pieza fuera es `components/services-provision/resolution-format/ResolutionDetail.vue`,
que la pestaña de antecedentes monta prestada del flujo de resolución. No es un
archivo de pagos, así que puede ser una decisión deliberada; vale confirmarlo en
lugar de asumirlo.

---

## C · Visual

### C1 · §6.2 — las dos convenciones conviven, y una vez en el mismo archivo

| Archivo | `'—'` | `noInformation` |
| :--- | ---: | ---: |
| `Du288PaymentContextSection.vue` | 5 | 10 |
| `Du288ExecutedCompensationSection.vue` | 3 | 0 |
| `Du288MonthVersionsModal.vue` | 3 | 1 |
| `Du288ExecutionWeekSection.vue` | 3 | 0 |
| `payments/index.vue` | 2 | 2 |
| `payments/_nroSolici/index.vue` | 2 | 0 |
| `Du288InstallmentFormSection.vue` | 2 | 0 |
| `Du288InstallmentsSection.vue` | 1 | 0 |
| **Total** | **21** | **13** |

`Du288PaymentContextSection` es el caso que mejor lo muestra: diez campos dicen
«No informado» y cinco, en la misma ficha, dicen «—». Es exactamente el C1 de la
auditoría de DGDP, con los papeles repartidos dentro de un solo archivo.

### C2 · Lo que no aparece

Se buscó y **no** hay: fechas en `DD-MM-YYYY` (§9.1), modales sin
`pds-ui-modal` / `centered` / footer real (§3.1, §11), ni filtros con estados
inalcanzables (§8) —la bandeja del solicitante no filtra por estado—.

---

## D · Textos y duplicación

### D1 · El tag de respaldo: el mismo defecto, línea por línea

`_nroSolici/index.vue:474-487` es una copia del bloque que el §16.5 (D5)
corrigió en DGDP, con los tres problemas intactos:

- cinco cadenas visibles en duro, fuera de `lang/es/pds.js` (§15);
- `detail` y `message` con **la misma cadena** en las dos ramas, cuando el
  componente que las consume hace `tag.detail || tag.message`;
- `blocking: true` incondicional, también cuando el respaldo está presente.

Las claves de catálogo ya existen: se agregaron en
`payments.review.detail.validations` para DGDP (`evidenceOk`, `evidenceMissing`,
`evidenceOkDetail`, `evidenceMissingDetail`). Si se van a compartir, conviene
subirlas a un lugar común en vez de duplicar el bloque de textos.

### D2 · «Máx.» y «DU 288», otra vez

`Du288PaymentContextSection:134-135`:

```js
? 'Hasta 12 cuotas (con extensión autorizada)'
: 'Máx. 2 cuotas (normativa general DU 288)'
```

Son las dos cadenas exactas del D3 de DGDP, ya corregidas allá a «Máximo 2
cuotas (normativa general DU288)» y catalogadas como
`maxInstallmentsExtended` / `maxInstallmentsGeneral`. Acá siguen en duro, con la
abreviatura y con el espacio en «DU 288».

### D3 · «cuota decretada» / «cuotas decretadas»

`Du288PaymentContextSection:148`. Misma cadena que el D1 de DGDP, ya catalogada
como `installmentsDecreedOne` / `installmentsDecreedMany`.

### D4 · «Rechazada» escrita a mano como estado

`Du288InstallmentFormSection:91` y `:363` usan `'Rechazada'` como respaldo del
estado que viene del servidor. El §8 pide que los estados visibles salgan del
catálogo real: un literal acá es el camino para que la pantalla diga «Rechazada»
cuando el estado sea otro.

### D5 · Otros textos en duro

| Archivo | Línea | Texto |
| :--- | ---: | :--- |
| `Du288PaymentContextSection` | 144 | `Sin cuotas enviadas (1 de N disponible)` y `Sin cuotas` |
| `Du288InstallmentFormSection` | 68 | `Período de pago (DGDP)` |
| `Du288InstallmentFormSection` | 73 | `Período de pago de referencia` |
| `Du288InstallmentFormSection` | 79 | `Fijado por DGDP al momento de visar y aprobar la cuota.` |
| `Du288PaymentValidationsSection` | 49-51 | ocho etiquetas `… pendiente` |
| `Du288ExecutionWeekSection` | 77, 140, 178-180 | `|| 'Miércoles'`, `|| 'Total semanal'`, `|| 'Semana de ejecución'`, `|| 'Sin horario'` |

Los de `Du288ExecutionWeekSection` son fallbacks de claves que **sí existen** en
el catálogo (`executionWeek.weekdayNames`, `weekTotal`, `title`, `emptyDay`): el
`||` nunca se ejecuta, y mientras esté ahí hay dos lugares donde cambiar un
texto y uno solo que se nota.

### D6 · `MONTHS` a mano, dos copias más

El §16.5 (D4) dejó los nombres de los meses exportados una vez desde
`formatters.js` y eliminó seis copias; el §17.3, una séptima. Quedan dos, que no
aparecían porque la constante se llama `MONTHS` y no `MONTH_NAMES`:

- `Du288InstallmentFormSection:326` — nombres completos, idénticos al export.
- `Du288InstallmentsSection:113` — abreviados, segunda copia de los `MONTH_SHORT`
  que viven en `payments/review/index.vue`.

Los dos archivos tienen a mano mejores herramientas: `Du288InstallmentFormSection`
ya importa `getMonthYearLabel`, que hace exactamente lo que su
`paymentPeriodLabel` arma a mano.

---

## Lo que ya está bien

Conviene dejarlo escrito, porque es la mitad de la respuesta a la pregunta de
esta auditoría:

- **El tratamiento del rechazo está completo.** `Du288InstallmentsSection` y
  `Du288InstallmentFormSection` tachan el monto con `is-void`, rotulan el total
  como `rejectedTotalLabel`, muestran el chip de estado y ocultan el neto de una
  cuota rechazada (`netLabel: !rejected && …`). Es lo que el §16.2 tuvo que
  llevar a DGDP; acá ya estaba.
- **La ficha de montos nombra el rechazo.** `Du288PaymentContextSection:161-167`
  agrega «Bloqueado por rechazo» con su monto, su conteo de cuotas y su `hint`,
  y solo cuando hay rechazos. Es el equivalente del campo que el §16.1 agregó al
  detalle DGDP.
- **El cupo y el saldo de la bandeja ya salen corregidos del PA.**
  `cuotas_creadas` sin filtro de estado y `mto_saldo` con el término del estado 4
  son del §15.1 y §15.2, y esta bandeja es justamente la que los consume.
- **Los modales cumplen.** El de compensación (`_nroSolici:56-83`) tiene
  `centered`, `modal-class`, `body-class`, `ok-only` y footer real; los
  `msgBoxConfirm` pasan por `confirmOptions()`, que fija `modalClass` y
  `centered`.
- **El gate la cubre entera** y no encuentra nada.
- **Las fechas y los montos** usan `formatDateOnly` y `formatPriceCLP`; no hay
  aritmética de fechas a mano ni `toFixed` visible.

---

## Resumen

| | Hallazgo | Norma | Dónde | Paridad | Aplicado |
| :--- | :--- | :--- | :--- | :--- | :--- |
| A1 | `remaining` acotado a cero en el módulo de dinero; contradice `resolveProvisionRemainingAmount` | cálculo | `paymentValidations.js:156` | diverge de §16.1 | sí |
| A2 | «Saldo» y «Espacio» acotados en el formulario; el mensaje de error dice otra cosa | cálculo | `…FormSection:473/614`, `…ContextSection:156` | mismo patrón del §17.1 | sí |
| A3 | `otherProposedAmount` duplica `resolveDraftInstallmentBalance`, con un término más | §3.2 | `…FormSection:600-612` | sobre el cambio de ayer | sí |
| A4 | el fallback de «Comprometido» incluye lo rechazado, que además se muestra aparte | cálculo | `…ContextSection:188-192` | latente | sí |
| A5 | `sg_fupssSecgen18` no devuelve `mto_rechazado` | cálculo | `sg_fupssSecgen18:105-110` | falta vs. §16.1 | sí |
| B1 | `ResolutionDetail.vue` fuera del gate | §17 | `validateDu288Ui.js` | por confirmar | sí |
| C1 | 21 `'—'` contra 13 `noInformation`, cinco y diez en el mismo archivo | §6.2 | 8 archivos | mismo C1 de DGDP | sí |
| D1 | tag de respaldo: textos en duro, `detail`/`message` iguales, `blocking` incondicional | §15 | `_nroSolici:474-487` | copia del D5 | sí |
| D2 | «Máx. 2 cuotas (normativa general DU 288)» | §15 | `…ContextSection:134-135` | copia del D3 | sí |
| D3 | «cuota decretada» / «cuotas decretadas» | §15 | `…ContextSection:148` | copia del D1 | sí |
| D4 | `'Rechazada'` en duro como estado | §8 §15 | `…FormSection:91/363` | nuevo | sí |
| D5 | 13 textos visibles en duro, seis de ellos fallbacks de claves existentes | §15 | 4 archivos | nuevo | sí |
| D6 | `MONTHS` a mano en dos archivos más | §3.2 | `…FormSection:326`, `…InstallmentsSection:113` | D4 incompleto | sí |

Los trece quedaron aplicados el 27-10-2026. El detalle de qué cambió en cada uno
está en el §18 de `rechazo_devolucion_y_estados.md`, porque esta auditoría
describe el problema y no la solución.

A5 y A1 son los dos que cambiaron números en pantalla; A3 dejó el módulo de
dinero con una sola definición de «saldo del borrador», que antes estaba escrita
a mano en tres lugares.

## Lo que quedó fuera

- **El guión suelto en dos archivos que la auditoría no contó.**
  `Du288PaymentAttendanceSection` tenía dos más, uno de ellos dentro de una
  función de módulo que no lee el catálogo. Se arreglaron igual, pasando el
  rótulo como parámetro (`timeLabel(from, to, missingLabel)`), el mismo patrón
  que ya usaba `formatCompensationRange`.
- **`Du288InstallmentSummarySection.vue`**: 340 líneas que no se montan en
  ninguna parte. Sigue sin decidirse si se borra o se monta, así que no entró al
  gate.
- **Los `hint` de la vista DGDP** siguen siendo `title=` y el teclado no los
  alcanza. Es accesibilidad, no paridad con esta vista.
- **Verificación en navegador**: nada se revisó a 1366, 1024, 768 ni 375 px.
- **Verificación contra Sybase**: en esta máquina no hay cliente ni Docker, así
  que `sg_fupssSecgen18` está escrito y revisado, no compilado.
