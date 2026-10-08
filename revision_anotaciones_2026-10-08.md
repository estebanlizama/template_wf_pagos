# Revisión de anotaciones — 08-10-2026

Cuatro anotaciones funcionales contrastadas contra lo implementado. Para cada
una: qué dice la regla vigente, qué hace hoy el sistema y qué falta.

Fuente de reglas: `reglas_pagos/01_reglas_montos_por_tipo_de_flujo.md`
(ClickUp S0-013 es la fuente autoritativa).

---

## 1. Indicar en la resolución en cuántas cuotas se distribuye

**Estado: no implementado.** El dato existe y se captura, pero no llega al
documento decretado.

| Dónde | Hoy |
| :--- | :--- |
| Formulario de solicitud | campo **Cuotas esperadas** (`worker.nroCuotas`), acotado por `getMaxDeclarableInstallments` |
| Persistencia | `sg_fups.tot_cuotas`, expuesto como `totalInstallments` en `RequestStaff` |
| Resumen interno | visible en `Du288StaffSummarySection.vue:185` |
| **Tabla del decreto** | **no aparece**: `createDu288ResolutionWorkersTableScheme` (`ResolutionDetail.vue:107`) tiene Nombre, RUT, Jerarquía, Funciones, Monto bruto total, Período a pagar, Horario, Total final |
| **PDF de la resolución** | **no aparece**: `buildStaffPdfRows` (`resolution.controller.ts:618`) no emite `tot_cuotas` |
| Tarjetas de encabezado | centro de costo, unidad ejecutora, jefe, ítem, período, modalidad, horas. Sin cuotas |

**Qué falta**

1. Agregar `totalInstallments` a la fila del PDF en `buildStaffPdfRows` y una
   columna o línea en `createDu288ResolutionWorkersTableScheme`, para que el
   decreto diga el número de cuotas.
2. Decidir la redacción: columna por funcionario ("2 cuotas") o una frase en el
   cuerpo del decreto. Son distintos: la columna soporta varios funcionarios con
   cuotas distintas; la frase, no.
3. Texto nuevo en `lang/es/pds.js` (§15 del estándar visual).

**A confirmar:** si el número decretado es **vinculante** (el pago no puede
usar más cuotas que las decretadas) o **indicativo**. Hoy el PA
`sg_epagiSecgen01` ya bloquea con *"La resolución no autoriza más cuotas para
este funcionario"*, es decir, se comporta como vinculante — pero el decreto no
lo declara, así que el funcionario no tiene cómo saberlo antes de pagar.
Esta anotación cierra justamente ese hueco.

---

## 2. El pago de la última cuota debe ser dentro del último mes

**Estado: no implementado. Y la anotación admite dos lecturas.**

Lo único que hoy valida el mes de pago:

| Capa | Validación |
| :--- | :--- |
| `Du288InstallmentFormSection.isValid` | año entre 2000 y 2100, mes entre 1 y 12 |
| `sg_epagiSecgen01` (líneas 55-63) | mismo rango, nada más |
| `paymentTimingState` | solo **etiqueta** "Atrasado" / "Al día" comparando contra el mes actual. No bloquea |

No hay ninguna relación entre el mes de pago y el período de ejecución.

**Las dos lecturas**

- **(a) Techo:** la última cuota no puede pagarse después del último mes del
  período autorizado (`sg_fups.f_termino`). Acota el diferimiento del pago.
- **(b) Piso:** la última cuota no puede pagarse antes de que termine la
  ejecución completa. Esto ya es la regla **C-06** y hoy se cubre
  *indirectamente*: `availabilityOf` solo deja seleccionar meses cuyo
  `isAvailable` es verdadero (ejecución terminada), y el PA rechaza con
  *"su ejecución no ha terminado"*. Pero se valida sobre los **meses incluidos**,
  no sobre el **mes de pago** declarado.

(b) ya está resuelto en sustancia. **Si la anotación es (a), es regla nueva** y
hay que implementarla en los dos lados (formulario y `sg_epagiSecgen01`), porque
el mes de pago lo escribe el PA y el frontend no es el único camino.

**Necesita confirmación del cliente antes de tocar código.** Interpretar mal
esto bloquea pagos legítimos atrasados, que C-08 permite explícitamente
("se pueden mezclar meses atrasados y el mes actual").

---

## 3. En monto fijo se debe poder editar lo propuesto por mes

**Estado: no implementado — hoy es explícitamente de solo lectura.**

En `Du288InstallmentFormSection.vue:90` el input de monto por mes está
condicionado a `amountType === 2` (variable). En fijo se pinta el valor
calculado y una leyenda *"Calculado por el sistema"* (línea 115).

El valor viene de `getFixedMonthAmounts` (reparto por resto mayor, **T-08**),
que garantiza `Σ meses = mto_total` exacto.

**Qué implica abrir la edición**

1. **Se rompe el invariante de T-08.** Si el usuario edita un mes, la suma deja
   de cuadrar con `mto_total`. Hay que decidir qué pasa: ¿se reparte la
   diferencia entre los meses no tocados? ¿se permite que la cuota sume menos y
   el saldo quede disponible? ¿se bloquea si suma más?
2. **C-10 sigue mandando:** el monto de un mes solo puede **bajar** respecto de
   lo propuesto, nunca subir. La validación de borde es `≤ propuesto`, no un
   `min="1"` abierto como el de variable.
3. **T-04 sigue mandando:** la suma de todas las cuotas no puede superar el
   total autorizado. Ya está cubierto por `balanceExceeded`.
4. Si baja el monto, hay que distinguir si el saldo liberado **vuelve al
   disponible** o **se pierde** — que es exactamente la anotación 4.
5. La diferencia fijo/variable deja de ser "editable o no". Habría que redefinir
   qué separa los dos tipos: probablemente *fijo propone y permite bajar*,
   *variable parte vacío*.

**Recomendación:** implementarlo reutilizando el input que ya existe para
variable, con `max` = monto propuesto del mes (C-10) en lugar de abierto, y
dejando `getFixedMonthAmounts` como **propuesta inicial**, no como valor final.
Es el cambio más chico que satisface la anotación sin romper T-08: el reparto
sigue generando la propuesta exacta y el usuario solo descuenta.

---

## 4. Última cuota: horas comprometidas y saldo no acumulable

Dos reglas en una anotación.

### 4.a — Restrictivo que no tenga todas las horas comprometidas realizadas

**Estado: implementado, pero más estricto que la regla.**

`monthsMissingCompensation` (`_nroSolici/index.vue:415`) bloquea el envío cuando
`committedMinutes > executedMinutes`, y `sendBlockReason` devuelve
`blockedByCompensation`.

El problema: **se aplica a todas las cuotas, no solo a la última.** Eso
contradice **C-07** (*"se permite pago parcial de un periodo ya ejecutado, con
monto ajustado"*). Hoy una cuota intermedia con compensación pendiente no se
puede enviar, aunque la regla la permita.

**Qué falta:** acotar el bloqueo a la última cuota. "Última" hay que definirla —
`isLastAvailableQuota` ya existe en el formulario y la calcula como
`quotaSummary.remaining + (editando ? 1 : 0) === 1`, pero hoy solo pinta un
aviso informativo (*"Es la última cuota autorizada"*). Para las cuotas
anteriores, la compensación incompleta debería ser **advertencia**, no bloqueo.

Nota: el bloqueo vive **solo en el frontend**. `sg_epaguSecgen02` (envío a
visación) valida estado, PDF adjunto, meses con monto y total autorizado — no
valida compensaciones. Si la regla es dura, tiene que estar también en el PA.

### 4.b — El saldo de la cuota no es acumulable; se pierde según el tope

**Estado: implementado en el cálculo, no en el mensaje.**

Es la regla **T-03** (*"el tope no es acumulativo: lo no usado en la primera
cuota no se traspasa a la segunda"*).

`resolveRemainingInstallmentCapacity` (`paymentValidations.js:91`) ya lo modela:
calcula `futureCapacity = tope × cuotas restantes` y, si el disponible supera
esa capacidad, exige un `minimumCurrentAmount` en la cuota actual. Cuando no se
alcanza, `underfunded` es verdadero y `isValid` **bloquea el guardado**.

La diferencia con la anotación es de enfoque, no de aritmética:

| Hoy | La anotación |
| :--- | :--- |
| **Impide** guardar una cuota que deje un remanente impagable | Deja pasar y el remanente **se pierde** |

El cálculo es el mismo; cambia si el sistema obliga o informa. Hay que decidir
cuál de las dos es la conducta querida. El mensaje actual
(`distributionMinimum` / `distributionAdd`) dice *"agregue $X"* — si la decisión
es que se pierde, el texto tiene que decirlo: *"$X del total autorizado no podrá
pagarse"*.

---

## Resumen

| # | Anotación | Estado | Bloqueante para avanzar |
| :--- | :--- | :--- | :--- |
| 1 | Cuotas en la resolución | No implementado | Decidir columna vs. frase |
| 2 | Pago de la última dentro del último mes | No implementado | **Sí** — dos lecturas posibles |
| 3 | Editar lo propuesto por mes en fijo | No implementado | Decidir qué pasa con el remanente (ver 4.b) |
| 4.a | Horas comprometidas en la última cuota | Implementado, pero para todas | Confirmar que las intermedias sí admiten pago parcial |
| 4.b | Saldo no acumulable | Calculado; hoy bloquea | Decidir: bloquear o dejar perder |

Las anotaciones 3 y 4.b son la misma decisión vista desde dos lados: si el
monto de un mes puede bajar, hay que decir qué ocurre con la diferencia.
