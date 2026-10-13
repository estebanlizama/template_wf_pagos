# Plan — saldo del centro de costo, días de ejecución y cuotas de pago

**Fecha:** 06-10-2026
**Ruta:** `/prestacion-de-servicios/pagos/:nroSolici`
**Estado:** **aplicado por completo** el 09-10-2026. Ver §7 para la auditoría y §7.1 para la decisión de §1.3.
**Alcance:** frontend. Un punto necesita decisión de negocio (§1.3) y ninguno requiere PA nuevo.

---

## 0. Lo que ya existe y no hay que construir

Antes de planificar conviene saber qué está hecho: tres de los cuatro bloques son
**reutilización**, no obra nueva.

| Lo que se necesita | Qué existe hoy | Qué falta |
| :--- | :--- | :--- |
| Saldo del centro de costo | el store **ya consulta** `cost-center-balance-validation` y recibe `saldo`, `saldoInicial`, `montoSolicitado`, `saldoRemanente`, `estatus`, `isValid`, `mensaje` | **se descarta todo salvo la etiqueta**: solo hay que guardarlo y pintarlo |
| Tabla presupuestaria | `Du288RequestHeaderSection.vue` la tiene en resolución, con Ítem · Solicitado · Saldo inicial · Remanente · Estado · Mensaje | una versión de solo lectura para pagos |
| Horario de ejecución | `schedules` **ya está en el estado** de pagos y llega a la tarjeta del funcionario | hoy se colapsa a `"Lun 08:30–09:30 +2"`; falta la semana completa |
| Grilla semanal | `StaffExecutionWeeklyGrid.vue` y `StaffExecutionScheduleSummary.vue` | adaptar la forma de los datos; el *Summary* es solo lectura y encaja mejor |
| Pendiente por pagar | `Du288PaymentStaffSection.balance()` ya resta lo consumido por estado de cuota | está encerrado en el componente; el compositor también lo necesita |
| Tope de la cuota | el compositor ya bloquea con `capExceeded` contra `monthlyCap` | falta el reparto y el cupo de cuotas |

---

## 1. Saldo del centro de costo

### 1.1 Tabla de solo lectura

Una sección nueva en la pestaña de gestión, **sobre** la tarjeta del funcionario, con la misma
anatomía que resolución y sin ninguna acción.

```
Validación presupuestaria
Saldo efectivo del centro de costo frente al monto de esta solicitud de pago.

Ítem                  Solicitado   Saldo inicial   Remanente    Estado
306 - No Académicos     $141.111        $500.000    $358.889    Disponible
```

| | |
| :--- | :--- |
| Componente | `Du288PaymentBudgetSection.vue` |
| Datos | la respuesta que el store ya recibe; hay que persistirla en `state.costCenterBalance` |
| Monto consultado | el mismo `validationAmount` que ya se envía: la cuota en borrador más alta, o el tope |
| Sin acciones | ni recargar ni editar; se actualiza con el resto de validaciones |

**El cambio real es de una línea en el store:** hoy `balance.data` se usa para armar la etiqueta y
se pierde. Basta un `SET_COST_CENTER_BALANCE` junto a los tags.

### 1.2 La etiqueta deja de ser un TODO

Hoy dice **«Centro de costo sin saldo · TODO»** porque no había dónde consultar el detalle. Con la
tabla, el sufijo sobra y el texto queda como sus vecinos:

| Condición | Etiqueta |
| :--- | :--- |
| `isValid` o `estatus = 1` | Centro de costo con saldo |
| sin fondos | Centro de costo sin saldo |
| no se pudo consultar | Saldo no disponible |

### 1.3 Decisión pendiente: ¿bloquea el envío?

El store tiene la constante `BALANCE_VALIDATION_BLOCKS_SUBMISSION`, hoy en falso, y por eso la
etiqueta es `warning` y no `error`. Esto **no es un detalle visual**: define si se puede pedir el
pago de una prestación cuyo centro de costo no tiene fondos.

| Opción | Consecuencia |
| :--- | :--- |
| Sigue informando | se envía igual y Finanzas lo rechaza más tarde |
| Bloquea | el jefe de proyecto no puede enviar hasta que haya saldo |

Técnicamente es cambiar la constante a `true` y el estado a `error`. **La decisión es tuya**, y
conviene tomarla junto con la tabla: mostrar el saldo y a la vez dejar enviar sin él es una
contradicción que el usuario va a notar.

---

## 2. Días de ejecución de la prestación

Hoy el horario comprometido se resume en una línea de la tarjeta. Se separa en su propia sección,
**antes** de la compensación, porque responde otra pregunta: *cuándo se trabaja*, no *cuándo se
compensa*.

```
Días de ejecución
Horario semanal comprometido en la resolución. Se repite cada semana del período.

  Lun      Mar      Mié      Jue      Vie      Sáb      Dom
08:30                                                   
09:30      —        —        —        —        —        —
  1 h                                                   

Total semanal: 1 h · Período 01/01/2016 – 30/06/2016
```

| | |
| :--- | :--- |
| Componente | `Du288PaymentScheduleSection.vue`, envolviendo `StaffExecutionScheduleSummary` |
| Datos | `schedules` del estado, filtrado por `id_funprse` — ya llega |
| Solo lectura | el horario pertenece a resolución; pagos no lo edita |
| Semana completa | los siete días, con los no asignados en gris, para que se vea qué **no** se trabaja |

**Por qué importa, en palabras del caso real:** la compensación debe ocurrir fuera de la jornada
institucional y en días hábiles. Ver que la prestación se ejecuta solo los lunes explica por qué
hay horas que compensar y en qué días tiene sentido hacerlo.

> Verificar al implementar si `StaffExecutionScheduleSummary` sirve tal cual o si su forma de datos
> es la del editor. Si no calza, `StaffExecutionWeeklyGrid` con `isDisabled` es la alternativa.

---

## 3. Cuotas de pago — orden visual

Aplicar lo mismo que se corrigió en meses, que quedó sin hacer.

| | Hoy | Propuesto |
| :--- | :--- | :--- |
| Lista | columna vertical al lado del compositor | rejilla que envuelve, compositor **debajo** a ancho completo |
| Badges | se repite el estado aunque no discrimine | solo las excepciones |
| Estado vacío | columna derecha reservada | una línea, lista a ancho completo |
| Al abrir | el compositor aparece lejos del botón | panel debajo, con encabezado fijo y **Cerrar** |
| Etiquetas | revisar contra §8.1 | ninguna sobre 25 caracteres |

Es el mismo cambio ya probado: `stacked` en el workspace, rejilla `auto-fill minmax(230px, 1fr)` en
la lista, y el encabezado del compositor con `position: sticky`.

---

## 4. Cuotas de pago — topes, reparto y pendiente

### 4.1 Lo que falta validar

El compositor hoy solo compara contra el tope mensual. Las reglas que faltan:

| Regla | Dónde vive hoy | Qué hacer |
| :--- | :--- | :--- |
| Suma ≤ tope del período | `capExceeded`, contra `monthlyCap` | distinguir tope **mensual** de tope del **período** según cuotas declaradas |
| Suma ≤ **pendiente por pagar** | en ningún lado | **nueva**: impide comprometer más de lo que queda |
| Cupo de cuotas | `canCreateInstallment` lo controla al crear | avisar también en el compositor |
| Reparto en Fija | el sistema lo calcula | mostrar que no es editable y por qué |
| Monto mayor que cero | sí | sin cambios |

### 4.2 El pendiente por pagar

Es el dato que falta a la vista y ya está calculado — encerrado en la tarjeta del funcionario:

```js
consumido = cuotas en estado 8        → amountSent
          + cuotas en estados 2,3,4,11 → requestedAmount
pendiente = total autorizado − consumido
```

**Hay que levantarlo a un getter del store** para que lo usen la tarjeta y el compositor sin
duplicar la regla. Y mostrarlo en el titular de la cuota:

```
Esta cuota solicita   $141.111
1 mes · Septiembre 2026 · se paga en Octubre 2026  Pago corriente
Quedan $358.889 por solicitar de $500.000 autorizados
```

### 4.3 Avisar o bloquear

Siguiendo lo que ya se decidió para compensación —avisar en el formulario, bloquear antes de
llamar al PA—:

| Situación | Comportamiento |
| :--- | :--- |
| Suma sobre el tope | **bloquea** Guardar, con el monto del tope en el mensaje |
| Suma sobre el pendiente | **bloquea** Guardar, diciendo cuánto queda |
| Última cuota disponible | **avisa**, no bloquea |
| Reparto fijo no editable | nota explicativa, sin error |

> **Ojo con un desfase conocido:** ninguna de estas reglas existe en `sg_epagiSecgen01` ni en
> `sg_epaguSecgen02`, salvo «suma ≤ monto autorizado» que sí se verifica al enviar. Si solo se
> implementan en la pantalla, una llamada directa a la API las salta. Está anotado en
> `diagrama_contraste_implementado.md` §2.

---

## 5. Orden propuesto

| | Bloque | Por qué primero | Esfuerzo |
| :-- | :--- | :--- | :--- |
| 1 | Saldo: persistir y tabla (§1.1, §1.2) | el dato ya se consulta y se tira; es la mejor relación resultado/esfuerzo | bajo |
| 2 | Pendiente por pagar al store (§4.2) | desbloquea las validaciones de §4.1 y quita una regla duplicada | bajo |
| 3 | Cuotas: orden visual (§3) | repite un cambio ya probado en meses | medio |
| 4 | Cuotas: topes y reparto (§4.1, §4.3) | depende del 2 | medio |
| 5 | Días de ejecución (§2) | aporta contexto, no desbloquea nada | medio |

La decisión de §1.3 conviene tomarla antes del paso 1; el resto no la necesita.

---

## 6. Lo que este plan no resuelve

- **Las validaciones siguen siendo de pantalla.** Llevarlas a los PA es otro trabajo, con su
  despliegue.
- **El saldo se consulta con un monto estimado** —la cuota en borrador más alta, o el tope—, no con
  el monto real de la cuota que se enviará. Con varias cuotas en borrador la cifra puede no ser la
  que corresponde. Conviene revisarlo al hacer §1.1.
- **No se toca resolución.** La tabla presupuestaria de pagos es una vista aparte que reutiliza el
  patrón, no el componente, porque aquel está acoplado al formulario de solicitud.

---

## 7. Auditoría contra el código — 09-10-2026

El plan quedaba marcado como "no implementado", pero sus cinco bloques se
fueron aplicando entre el 05 y el 09 de octubre, varios dentro de la
reestructura de la solicitud de pago. Estado real, verificado en el código:

| § | Bloque | Estado | Dónde |
| :--- | :--- | :--- | :--- |
| 1.1 | Persistir el saldo y mostrar la tabla | **aplicado** | `SET_COST_CENTER_BALANCE` en el store; `Du288PaymentBudgetSection.vue` |
| 1.2 | La etiqueta deja de ser un TODO | **aplicado** | las tres etiquetas son "Centro de costo con saldo", "Centro de costo sin saldo" y "Saldo no disponible", sin sufijo |
| 1.3 | ¿El saldo bloquea el envío? | **pendiente — decisión de negocio** | `BALANCE_VALIDATION_BLOCKS_SUBMISSION = false` |
| 2 | Días de ejecución en su propia sección | **aplicado, con variante** | `Du288PaymentScheduleSection.vue`; desde la reestructura vive en un modal del bloque de contexto, no como sección apilada |
| 3 | Cuotas: orden visual | **aplicado** | `stacked` en el workspace y rejilla `auto-fill`; la lista ya es el primer bloque accionable |
| 4.1 | Tope del período distinto del mensual | **aplicado** | `resolvePaymentPeriodCap` + `periodCapExceeded` |
| 4.1 | Suma ≤ pendiente por pagar | **aplicado** | `balanceExceeded` contra `availableAuthorizedAmount` |
| 4.1 | Cupo de cuotas avisado en el compositor | **aplicado** | `isLastAvailableQuota` |
| 4.1 | Reparto fijo no editable | **revertido por decisión posterior** | el 08-10-2026 se decidió que en fijo el reparto es **propuesta** y se puede bajar (C-10); ver `revision_anotaciones_2026-10-08.md` §3 |
| 4.2 | Pendiente por pagar al store | **aplicado** | getter `paymentBalance` (`resolvePaymentAmountBalance`) |
| 4.3 | Bloquear sobre tope y sobre pendiente | **aplicado** | ambos cortan `isValid` del compositor |

### 7.1 §1.3 — resuelto: el saldo bloquea el envío

Decisión del 09-10-2026: **el saldo del centro de costo bloquea también el
envío del jefe de proyecto**, no solo la aprobación DGDP. Mostrar el saldo en
rojo y dejar enviar igual era una contradicción que se descubría una etapa más
tarde.

`BALANCE_VALIDATION_BLOCKS_SUBMISSION = true`. La etiqueta pasa de `warning` a
`error` y entra en `hasBlockingNormativeValidations`, que ya corta
`submitFromBar`.

**Consecuencia inmediata:** una prestación cuyo centro de costo no tenga fondos
deja de poder enviarse. En los datos de prueba el centro de costo 9050-2
devuelve saldo `$0`, así que esa solicitud queda bloqueada hasta que la
consulta financiera devuelva saldo real. Es el comportamiento pedido, no un
defecto.

### 7.2 Advertencias del §6 que siguen vigentes

- Las validaciones de topes y pendiente **siguen siendo de pantalla**. Ni
  `sg_epagiSecgen01` ni `sg_epaguSecgen02` las replican, salvo
  "suma ≤ monto autorizado" al enviar. Una llamada directa a la API las salta.
  Excepción: el tope **por cuota** sí quedó en el PA, en `sg_fumeuSecgen02`,
  al abrirse la edición del monto por mes.
- El saldo se sigue consultando con un **monto estimado**, no con el de la
  cuota que se enviará.

---

## 8. Auditoría del apartado 2 «Meses de ejecución» — 13-10-2026

Revisión de `Du288InstallmentFormSection.vue` contra
`reglas_pagos/01_reglas_montos_por_tipo_de_flujo.md`. Verificado en ejecución
sobre la prestación 8 (6 meses de $74.074, tope $256.250, 2 cuotas, fijo).

### 8.1 Lo que está correcto

| Regla | Cómo se cumple |
| :--- | :--- |
| T-01, T-02 | `effectiveCap` es el tope completo de la cuota y se mide sobre la suma de los meses marcados, una sola vez |
| T-04 | `balanceExceeded` y `periodCapExceeded` bloquean el guardado contra el saldo autorizado |
| T-08 | el reparto fijo viene de `getFixedMonthAmounts` (resto mayor), no de `Math.round` |
| C-03 | el reparto es manual: casillas, sin propuesta automática del sistema |
| C-09 | `availabilityOf` cierra el mes tomado por otra cuota y dice cuál |
| C-10 (fijo) | `maxAmount = proposed` y `overProposed` impiden subir el mes sobre lo decretado |
| K-07 | `month.isAvailable` cierra el mes cuya ejecución no terminó |
| orden | `sg_fumesSecgen02` ordena por `ano_prop, mes_prop`, así que un `corr_fume` no cronológico no desordena las tarjetas |

### 8.2 Defecto 1 — `unpayableMonths` cuenta una cuota de más

```js
const slots = Math.max(0, this.availableInstallmentSlots - 1)
let used = 0          // <- abre una cuota implícita que nunca descuenta slot
let openSlots = slots
```

`used = 0` abre un primer grupo gratis, así que el lazo reparte los meses
pendientes en `slots + 1` cuotas cuando solo hay `slots`. Ejecutado con el
algoritmo tal cual:

| Escenario | `availableInstallmentSlots` | Pendientes | Devuelve | Debería |
| :--- | :--: | :--- | :--- | :--- |
| se edita la **última** cuota | 1 | 3 × $74.074 | `[]` | los 3 |
| queda 1 cuota, 7 meses sueltos | 2 | 7 × $74.074 | 1 mes | 4 meses |
| sin cuotas disponibles | 0 | 2 × $74.074 | `[]` | los 2 |

El caso grave es el primero: **en la última cuota nunca marca nada como
perdido**, y como `unpayableMonths` está vacío el panel cae en la rama
contraria y afirma *«N meses quedan para la cuota siguiente. Con este reparto
se paga el total decretado»* — cuando no hay cuota siguiente y ese dinero se
pierde. Es justo el aviso que la regla T-03 existe para dar.

Además, ese mensaje informativo no consulta `isLastAvailableQuota`, así que la
frase «quedan para la cuota siguiente» se emite aunque no quede ninguna.

### 8.3 Defecto 2 — el mes que no cabe no se puede ajustar

`capAvailabilityOf` deshabilita la casilla del mes que excede el espacio de la
cuota, y el monto solo es editable con la casilla marcada:

```html
<b-form-checkbox :disabled="locked || !month.selectable">
<b-form-input v-if="month.checked && !locked" ...>
```

Con $34.028 de espacio y un mes de $74.074 el usuario queda sin salida: no
puede marcarlo porque no cabe, y no puede bajarlo a $34.028 para que quepa
porque el campo no existe mientras no esté marcado. C-07 (pago parcial del
período ya ejecutado) y C-10 (el monto baja) permiten exactamente ese ajuste, y
el subtítulo del apartado lo promete: *«puede ajustar cada mes a la baja»*.

Salidas posibles:

1. **Habilitar el monto en el mes bloqueado por tope** — se edita, y al quedar
   bajo el espacio disponible la casilla se libera sola. Mantiene la casilla
   como la decisión y el monto como el ajuste.
2. **Dejar marcar el mes y mostrar el exceso como error** — más cercano a lo
   pedido en su momento (*«no se puede bloquear la selección»*), pero permite
   guardar un borrador inválido hasta corregirlo.

### 8.4 Observaciones menores

- **Dos límites, dos interacciones.** El tope de la cuota cierra la casilla; el
  saldo autorizado deja marcar y después bloquea el guardado. Son el mismo tipo
  de límite (T-01 y T-04) resueltos de forma distinta.
- **C-10 en variable.** `maxAmount` y `overProposed` solo aplican con
  `amountType === 1`. Es correcto —en variable la resolución no declara monto
  por mes, solo el techo, y ese techo lo cuida `balanceExceeded`— pero conviene
  que quede dicho, porque §5 de las reglas afirma C-10 «en ambos».
- **T-05 sin implementar.** Dos cuotas en el mismo mes de pago solo se permiten
  por deuda o atraso. No hay validación en el apartado 1 ni aquí.
- **Tope vigente vs tope congelado.** `monthlyCap` viene del tope de la
  prestación; el panel normativo bloquea con el tope del cargo vigente. Sigue
  abierto desde el plan anterior.

---

## 9. Plan de implementación del apartado 2 — 13-10-2026

Cierra los dos defectos de §8. Todo ocurre en
`Du288InstallmentFormSection.vue` y `lang/es/pds.js`; **no toca PA ni backend**,
salvo el paso 4, que es opcional y sí los toca.

### Paso 1 · Corregir `unpayableMonths`

`Du288InstallmentFormSection.vue:492`. El lazo abre un grupo con `used = 0` que
nunca descuenta cupo; hay que cobrarlo.

```js
unpayableMonths() {
    const cap = this.effectiveCap
    if (cap === Infinity) return []
    const pending = this.monthRows
        .filter(row => !row.checked && row.selectable)
        .sort((a, b) => a.period - b.period)
    /* Cuotas que quedan DESPUES de esta. Si no queda ninguna, todo lo que no
       se marque aqui ya no se paga (T-03). */
    const slots = Math.max(0, this.availableInstallmentSlots - 1)
    if (!slots) return pending

    const left = []
    let used = 0
    let openSlots = slots - 1          // la primera de esas cuotas ya esta abierta
    for (const row of pending) {
        if (used + row.requested <= cap) { used += row.requested; continue }
        if (openSlots > 0) { openSlots -= 1; used = row.requested; continue }
        left.push(row)
    }
    return left
}
```

Comprobación contra los tres escenarios de §8.2 y el caso real:

| `availableInstallmentSlots` | Pendientes | Antes | Después |
| :--: | :--- | :--- | :--- |
| 1 (última cuota) | 3 × $74.074 | `[]` | los 3 |
| 2 | 7 × $74.074 | 1 mes | 4 meses |
| 0 | 2 × $74.074 | `[]` | los 2 |
| 2 (caso real de hoy) | 3 × $74.074 | `[]` | `[]` — no cambia |

### Paso 2 · Separar los tres mensajes

`installmentStatusMessages:643`. Hoy hay dos ramas y la segunda miente cuando
no queda cuota siguiente. Pasan a ser tres, con el orden del §5.4 intacto:

| Condición | Tipo | Texto |
| :--- | :--- | :--- |
| `slots === 0` y hay pendientes | advertencia | *N meses ($X) no se pagarán: esta es la última cuota y no quedan cuotas donde incluirlos.* |
| `unpayableMonths.length` | advertencia | el actual: *…no se podrán pagar: no quedan cuotas donde incluirlos y superan el tope.* |
| hay pendientes y `slots > 0` | información | el actual: *…quedan para la cuota siguiente. Con este reparto se paga el total decretado: $X.* |

La primera es **advertencia, no bloqueo**: ya se decidió que el saldo se pierde
sin impedir el envío (§4.b). Texto nuevo en `pds.js`, junto a `movesToNext` y
`unpayableSuffix` (≈ línea 2186).

### Paso 3 · Permitir ajustar el mes que no cabe

1. `capAvailabilityOf:747` agrega una marca al objeto que devuelve:

   ```js
   return { selectable: false, blockedByCap: true, reason: ... }
   ```

2. La plantilla abre el campo también para ese caso, y de paso respeta lo que
   el PA exige (`sg_fumeuSecgen02` rechaza el mes que ya no admite cambios):

   ```html
   <b-form-input
     v-if="(month.checked || month.blockedByCap) && !locked && month.acceptsChanges"
   ```

3. Nota corta bajo el campo cuando está bloqueado por tope, con la cifra exacta
   a la que hay que bajarlo: *«Bájelo a $34.028 o menos para incluirlo en esta
   cuota.»* Al bajarlo, `requested` cambia, `capAvailabilityOf` deja de
   bloquear y la casilla se libera sola — sin botón extra.

4. `isDirty:452` pasa a comparar **todos** los meses con monto editado, no solo
   los marcados, para que «Cancelar edición» los devuelva al valor original.
   Hoy un mes no marcado y editado no ensucia el formulario, así que el usuario
   podría creer que el ajuste quedó guardado.

**Lo que no cambia:** solo se persisten los montos de los meses marcados
(`submit:821`). Bajar un mes y no marcarlo no escribe nada, que es lo correcto:
el monto solo importa cuando el mes entra en una cuota. Cuando sí se marca y se
guarda, `sg_fumeuSecgen02` versiona el cambio en `sg_fum2` como cualquier otro.

### Paso 4 · T-05, opcional y con decisión pendiente

Dos cuotas en el mismo mes de pago solo se permiten por deuda o atraso (C-05,
T-05). Hoy no lo valida **ni el frontend ni el PA** (`sg_epagiSecgen01` solo
comprueba el rango de `@ano_pago` / `@mes_pago`).

Requiere, en este orden:

1. Decidir qué cuenta como «deuda o atraso» — no está definido en las reglas.
2. Pasar al formulario los meses de pago de las otras cuotas (el dato existe en
   `Du288InstallmentsSection`, pero el formulario no recibe la lista).
3. Validación equivalente en `sg_epagiSecgen01` y `sg_epaguSecgen01`, porque el
   frontend no es la frontera de integridad.

Queda fuera de este plan mientras el punto 1 no se responda.

### Orden y verificación

Pasos 1 y 2 juntos (el mensaje depende del cálculo), paso 3 aparte. Para probar
sin tocar datos, la prestación 8 sirve: tiene 6 meses de $74.074 con tope
$256.250 y 2 cuotas.

| Qué | Cómo se comprueba |
| :--- | :--- |
| paso 1 | con la cuota 2 abierta y meses sin marcar, los pendientes salen como *no se pagarán* |
| paso 2 | con la cuota 1 abierta, sigue diciendo *quedan para la cuota siguiente* y el total $444.444 |
| paso 3 | abril ($74.074) con $34.028 de espacio: el campo aparece, se baja, la casilla se libera |
| regresión | `paymentMonthsValidation.test.cjs` sigue verde (T-08) |
