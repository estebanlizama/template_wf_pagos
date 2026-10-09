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

## Resumen — decisiones tomadas y estado

Decisiones del cliente del 08-10-2026, ya aplicadas salvo lo indicado.

| # | Anotación | Decisión | Estado |
| :--- | :--- | :--- | :--- |
| 1 | Cuotas en la resolución | Línea propia en el bloque de datos del decreto, no columna de la tabla | **Implementado** (pantalla y PDF) |
| 2 | Pago de la última cuota | Solo la última: se paga **desde** el mes de término de la ejecución. Sin techo y sin piso para las anteriores | **Implementado** (formulario + 2 PA, pendiente desplegar) |
| 3 | Editar el monto por mes | Editable también en fijo, acotado a lo propuesto (C-10) y al tope de la cuota | **Implementado** (formulario + PA, pendiente desplegar) |
| 3b | Auditoría del cambio | Valor nuevo en `sg_fume`, versión anterior en `sg_fum2` | **Implementado** (PA, pendiente desplegar) |
| 4.a | Horas comprometidas | Bloquea solo la última; en las anteriores advierte | **Implementado** (frontend; falta el PA) |
| 4.b | Saldo no acumulable | Se pierde: se informa, no se bloquea | **Implementado** |

### 1 · Cuotas en la resolución

Se agrega `Cuotas en que se distribuye el pago : 2 cuotas` después de
`Cantidad de horas contratadas`, en:

- `ResolutionDetail.completeDocumentCards` (pantalla), desde `tot_cuotas` del funcionario;
- `resolution.controller.formatDeclaredInstallments` + `prse-resolution.document.html` (PDF).

Con varios funcionarios de distinto número se enumeran por nombre en vez de
inventar un total único.

### 2 · Mes de pago mínimo

La regla alcanza **solo a la última cuota** (aclaración del 08-10-2026): se paga
desde el mes de término de la ejecución, nunca antes. Con dos cuotas es la
segunda la que queda sujeta.

Las cuotas anteriores **no tienen piso**: se pagan cuando corresponda. Y no hay
techo para ninguna — una cuota atrasada sigue siendo válida (C-08).

| Dónde | Condición |
| :--- | :--- |
| `Du288InstallmentFormSection.minimumPaymentPeriod` | `isLastAvailableQuota ? lastExecutionPeriod : 0` |
| `sg_epagiSecgen01` | `@cuotas_hoy + 1 = @tot_cuotas` |
| `sg_epaguSecgen01` | `@nro_cuota = @tot_cuotas` |

El mes de término sale de `max(sg_fume.ano_prop * 100 + mes_prop)` de la
prestación, no de los meses que la cuota toma: la última cuota podría no
incluir el mes final y la regla igual aplica (C-06).

### 3 · Monto por mes editable

El input deja de ser exclusivo de variable. En fijo el reparto por resto mayor
(**T-08**) pasa a ser **propuesta**, con `max` = monto propuesto del mes, porque
C-10 solo permite bajar. El total de la cuota sigue acotado por `capExceeded`
(tope) y `balanceExceeded` (saldo autorizado).

`sg_fumeuSecgen02` suma dos cosas:

1. **Tope de la cuota.** Si el mes pertenece a una cuota y la prestación no tiene
   extensión, `suma(otros meses) + monto nuevo <= mto_tope`.
2. **Versión en `sg_fum2`.** Antes de actualizar, y solo si el monto cambia,
   inserta la fila actual de `sg_fume` con `correlativ = max + 1`.

Todo dentro de una transacción: la versión y el nuevo valor entran juntos o no
entra ninguno.

#### Lo que `sg_fum2` no puede guardar

La tabla es espejo de `sg_fume` **menos tres columnas** y con el nombre viejo del
estado (§8.2 de `diagrama_pagos_actualizada.md`):

| | `sg_fume` | `sg_fum2` |
| :--- | :--- | :--- |
| estado | `cod_estfum` | `cod_estcuo` ← el PA escribe aquí `cod_estfum` |
| monto enviado | `mto_realpa` | **no está** |
| descuento licencia | `mto_deslic` | **no está** |
| descuento sin goce | `mto_dessg` | **no está** |

Para esta anotación alcanza: lo que se versiona es `mto_apagar`, que sí está.
**No alcanza** para el otro camino de escritura, el de DGDP
(`sg_fumeuSecgen03`, que escribe `mto_deslic`/`mto_dessg`): si esos cambios
también deben quedar versionados, `sg_fum2` necesita las tres columnas.

Tampoco queda **cuándo ni quién** hizo el cambio. `rut_autori`/`fec_autori` de
`sg_fume` son de la autorización DGDP y escribirlos desde aquí falsearía ese
dato, así que el PA no los toca. Si se quiere la marca del editor hace falta
una columna nueva.

### 4.b · El saldo se pierde

`resolveRemainingInstallmentCapacity` ya calculaba el remanente que no cabe en
las cuotas que quedan. Deja de bloquear: ahora el formulario informa
*"Con este reparto, $X del total autorizado no podrá pagarse: el tope no se
acumula entre cuotas"* y permite guardar. Es T-03 aplicado tal cual.

### 4.a · Resuelto: bloquea solo la última, advierte en las anteriores

Decisión del 09-10-2026:

| Cuota | Compensación incompleta |
| :--- | :--- |
| Anterior a la última | **no bloquea** — se envía (C-07, pago parcial), con advertencia visible |
| Última | **bloquea** — no se envía hasta completar las horas |

La advertencia de las anteriores dice a qué lleva la deuda: *"Quedan horas
comprometidas sin compensar. Esta cuota se puede enviar, pero si la
compensación no se completa en horas, la última cuota no se podrá pagar."*

"Última" se decide con la misma condición que el PA —`nro_cuota = tot_cuotas`—
para que pantalla y base no discrepen (`isSendingLastInstallment`).

**Sigue pendiente:** el bloqueo vive solo en el frontend. `sg_epaguSecgen02` no
valida compensaciones, así que una llamada directa a la API enviaría la última
cuota sin ellas. Llevar la regla al PA es trabajo aparte, con su despliegue.

### 5 · Editar una cuota con meses ya comprometidos

Decisión del 08-10-2026: una cuota devuelta tiene que poder cambiar también
**qué meses abarca**, no solo montos y mes de pago.

Antes, `sg_epaguSecgen01` rechazaba con *"Una cuota observada no puede cambiar
los meses que abarca"*. El motivo era real: sacar un mes lo dejaba en
`cod_estfum = 2` sin cuota y fuera de `disponible`. La guarda se levanta y el
PA se hace cargo del estado, dentro de la misma transacción que rehace
`sg_dpag`:

| Al guardar una cuota en estado 3 | `cod_estfum` |
| :--- | :--- |
| mes que sale de la cuota (queda sin fila en `sg_dpag`) | vuelve a **1 Propuesta** |
| mes que entra a la cuota | pasa a **2 Comprometida** |

La liberación se escribe como *"mes en 2 sin fila en `sg_dpag`"*, no como
*"mes que estaba en esta cuota"*: así además corrige cualquier mes que hubiera
quedado huérfano antes.

Montos y compensaciones ya eran editables en estado 3 — los PA usan
`cod_estfum = 1 or cod_estcuo = 3`.

### 6 · Editar / Cancelar edición / Guardar edición

El formulario de cuota abre **en consulta**. Las tres acciones:

| Acción | Qué hace |
| :--- | :--- |
| **Editar cuota** | habilita mes de pago, selección de meses y montos; guarda una copia del estado actual |
| **Cancelar edición** | restaura esa copia y vuelve a consulta; nada se persiste |
| **Guardar edición** | persiste montos (`sg_fumeuSecgen02`) y encabezado + meses (`sg_epaguSecgen01`) |

Una cuota nueva abre directamente en edición, porque no hay nada que consultar.

El estado que el formulario emite al contenedor
(`{ open, editing, valid, dirty }`) suma `editing`; `dirty` solo puede ser
verdadero dentro del modo edición, así que el aviso de cambios sin guardar deja
de dispararse por abrir una cuota a mirar.

### PA que quedan por desplegar

| PA | Qué cambió |
| :--- | :--- |
| `sg_epagiSecgen01` | mes de pago mínimo al crear la cuota |
| `sg_epaguSecgen01` | mes de pago mínimo al editar la cuota + cambio de meses en estado 3 con `cod_estfum` coherente |
| `sg_fumeuSecgen02` | tope de la cuota + versión en `sg_fum2` |
