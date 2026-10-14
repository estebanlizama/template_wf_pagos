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

---

## 10. Aplicado — 13-10-2026

Los pasos 1, 2 y 3 de §9 están aplicados con la salida (a). El paso 4 (T-05)
sigue fuera: necesita definir qué cuenta como deuda o atraso.

### 10.1 Paso 1 — el reparto ya no inventa una cuota

`unpayableMonths` abre el primer grupo con `used = 0` y ahora **cobra ese
cupo**: si no queda ninguna cuota después de esta, devuelve todos los
pendientes sin entrar al lazo. El conteo se extrajo a
`remainingInstallmentSlots`, que es el dato que el mensaje también necesita.

Comprobado ejecutando la función real del componente con un `this` simulado:

| Escenario | Pendientes | Antes | Ahora |
| :--- | :--- | :--: | :--: |
| se edita la **última** cuota | 3 × $74.074 | 0 | **3** |
| queda 1 cuota, 7 meses sueltos | 7 × $74.074 | 1 | **4** |
| sin cuotas disponibles | 2 × $74.074 | 0 | **2** |
| caso real de hoy (queda 1 cuota, 3 meses) | 3 × $74.074 | 0 | 0 |

La última fila es la que importa tanto como las otras tres: el arreglo **no
cambia** el caso que ya estaba bien.

### 10.2 Paso 2 — tres mensajes

La rama informativa afirmaba *«quedan para la cuota siguiente»* sin mirar si
quedaba alguna. Ahora el primer caso tiene texto propio:

> *N meses ($X) no se pagarán: esta es la última cuota y no quedan cuotas donde
> incluirlos.*

Es **advertencia, no bloqueo**, según lo ya decidido en §4.b: el saldo se
pierde y el envío sigue permitido.

### 10.3 Paso 3 — el mes que no cabe se puede ajustar

`capAvailabilityOf` marca `blockedByCap`, que distingue el cierre por tope
—que el usuario puede levantar— de los que no dependen de él. Con esa marca:

- el campo de monto aparece también en el mes cerrado por tope;
- la condición incorpora `month.acceptsChanges`, que es lo que
  `sg_fumeuSecgen02` exige al guardar y la plantilla no comprobaba;
- debajo del campo se dice **qué hacer, con la cifra exacta**: *«Para incluirlo
  en esta cuota, baje el monto a $34.028 o menos.»*

Comprobado en pantalla sobre abril de 2016:

| | monto | casilla | motivo |
| :--- | ---: | :--- | :--- |
| antes | $74.074 | cerrada | No cabe bajo el tope. Espacio: $34.028 |
| al bajarlo | $34.028 | **abierta** | Disponible para incluir |

La casilla se libera sola al caer bajo el espacio disponible: no hay botón
extra ni paso intermedio.

**`isDirty`** ahora también mira los meses sin marcar, comparándolos contra el
snapshot de la edición. Antes un mes bajado y no marcado no ensuciaba el
formulario, así que «Cancelar edición» no lo devolvía a su valor y el usuario
podía creer que el ajuste había quedado guardado. Verificado: ensucia al bajar
el monto y se limpia al restaurarlo.

**Lo que no cambia:** solo se persisten los montos de los meses marcados. Bajar
un mes y no marcarlo no escribe nada — el monto solo importa cuando el mes
entra en una cuota. Cuando sí se marca y se guarda, `sg_fumeuSecgen02` versiona
el cambio en `sg_fum2` como cualquier otro, y queda visible en *Cambios de
monto*.

### 10.4 Verificación

`eslint` limpio. En pantalla, sobre la prestación 8: los tres escenarios del
reparto, el ajuste de abril y su restauración, y a 375 px sin scroll horizontal
de página ni desbordes en las tarjetas de mes.

---

## 11. Edición, asignación y topes en el apartado 2 — mapa completo (13-10-2026)

Auditoría de las tres capas: plantilla, `isValid` del formulario y los PA.
Todo verificado leyendo el código, no el diseño.

### 11.1 Quién puede tocar qué, por estado

Hay **dos candados distintos** y conviene no confundirlos: uno es de la cuota,
el otro del mes.

| Candado | Dónde | Regla |
| :--- | :--- | :--- |
| de la **cuota** | `isEditable` del modelo · `cod_estcuo not in (1,3)` en `sg_epaguSecgen01:119` | solo **1 Borrador** y **3 Devuelta** |
| del **mes** | `acceptsChanges` en el formulario · `@cod_estfum <> 1 and @cod_estcuo <> 3` en `sg_fumeuSecgen02:116` | el mes está **Propuesto**, o pertenece a una cuota **devuelta** |

Y encima de los dos, el modo de edición de la pantalla: `locked = readOnly ||
!editing`. Al crear, `editing` nace en `true`; al abrir una cuota existente
nace en `false` y hay que pulsar **Editar cuota**.

| Estado de la cuota | ¿abre? | ¿edita meses? | ¿edita montos? | ¿elimina? |
| :--- | :--: | :--: | :--: | :--: |
| 1 Borrador | sí | sí | sí | sí (`sg_epagdSecgen01` solo acepta el 1) |
| 2 En visación | sí, lectura | no | no | no |
| 3 Devuelta | sí | sí | sí | no |
| 4 · 8 · 10 · 11 | sí, lectura | no | no | no |

### 11.2 Crear una cuota — qué valida cada capa

| # | Qué | Plantilla | `isValid` | PA |
| :-: | :--- | :--: | :--: | :--- |
| 1 | al menos un mes | — | sí | `sg_epagiSecgen01:49` |
| 2 | mes ya ejecutado | casilla cerrada | — | `:181` |
| 3 | mes tomado por otra cuota | casilla cerrada, dice cuál | — | `:191` · `:240` relee dentro de la transacción |
| 4 | mes repetido | imposible | — | `:152` |
| 5 | quedan cuotas autorizadas | — | — | `:116` y `:214`, dos veces |
| 6 | la última cuota no se paga antes del fin de ejecución | aviso | sí | `:201` |
| 7 | el mes no excede lo decretado (C-10) | `max` del campo | `overProposed` | **no** |
| 8 | la cuota cabe en el tope (T-01) | casilla cerrada | `capExceeded` | **no** — ver §11.5 |
| 9 | la cuota cabe en el saldo autorizado (T-04) | — | `balanceExceeded` | `sg_epaguSecgen02:179`, recién **al enviar** |

El monto del mes se guarda **antes** que la cuota: `submit()` recorre los meses
con `changed: true` y llama a `sg_fumeuSecgen02` uno por uno, y después crea o
actualiza el encabezado. Es ahí, y solo ahí, donde un PA mira el tope.

### 11.3 Editar una cuota devuelta — qué cambia

Lo mismo de §11.2, más tres cosas propias:

1. **Los meses entran y salen con su estado.** `sg_epaguSecgen01:272` libera a
   `cod_estfum = 1` todo mes en 2 que quedó sin fila en `sg_dpag`, y
   comprometea 2 los que entraron. Lo hace **por ausencia de puente**, no por
   lista, así que de paso repara meses huérfanos de otras ediciones.
2. **El mes devuelto sí admite cambios** aunque esté en `cod_estfum = 2`: la
   excepción `@cod_estcuo = 3` de `sg_fumeuSecgen02` existe justo para esto.
3. **Los descuentos de DGDP ya están escritos** y la pantalla los muestra como
   información no editable. Pero el **monto sí** se puede bajar, y de ahí salen
   dos de las aristas.

### 11.4 Dónde vive cada tope

| Límite | Regla | Frontend | PA |
| :--- | :--- | :--- | :--- |
| tope por cuota | T-01, T-02 | `capExceeded` bloquea guardar · `capAvailabilityOf` cierra la casilla | **solo** `sg_fumeuSecgen02:126`, y solo cuando cambia un monto |
| tope no acumulable | T-03 | `unpayableMonths` | — (no hace falta: no hay traspaso que impedir) |
| saldo autorizado | T-04 | `balanceExceeded` | `sg_epaguSecgen02:179` al enviar |
| monto del mes solo baja | C-10 | `maxAmount` y `overProposed` | — |
| exención por extensión | A-02 / `ext_cuotas` | `effectiveCap = Infinity` | `sg_fumeuSecgen02:126` la respeta |

### 11.5 Las aristas

**A · El tope por cuota no se valida en la base.** Ni `sg_epagiSecgen01`, ni
`sg_epaguSecgen01`, ni `sg_epaguSecgen02` comparan el total de la cuota contra
`mto_tope`; el envío solo revisa `mto_total`. `sg_fumeuSecgen02` sí lo hace,
pero **únicamente cuando se escribe un monto**, y el formulario solo manda los
meses con `changed: true`. Consecuencia concreta: **agregar meses a una cuota
sin tocar sus montos no pasa por ninguna validación de tope en la base.** Hoy
lo detiene la pantalla; un `POST` directo, no.

**B · Un mes que sale de la cuota se lleva los descuentos de DGDP.**
`sg_epaguSecgen01:272` devuelve el mes a `cod_estfum = 1` pero no limpia
`mto_deslic`, `mto_dessg`, `mto_realpa`, `val_licmed` ni `val_singoce`. Si el
solicitante lo saca de la cuota devuelta y lo mete en otra, llega con un
descuento que DGDP aplicó a una visación que ya no existe.

**C · Bajar el monto deja `mto_realpa` obsoleto.** `sg_fumeuSecgen02` escribe
`mto_apagar` y no recalcula `mto_realpa`, que DGDP había dejado como
`mto_apagar − deslic − dessg`. Después de bajar el mes, el neto guardado ya no
corresponde al bruto.

**D · Nada impide bajar el monto por debajo de los descuentos.**
`sg_fumeuSecgen03` valida `@mto_deslic + @mto_dessg > @mto_apagar` cuando
escribe DGDP, pero `sg_fumeuSecgen02` no tiene la validación simétrica, y el
`isValid` del formulario solo exige `requested > 0`. Con enero de 2016
—$74.074 con $46.643 de descuento— se puede guardar $20.000 y dejar un neto
negativo; la pantalla lo esconde con `Math.max(0, …)`.

**E · Dos topes distintos conviven.** El reparto usa `monthlyCap`, que es el
`mto_tope` congelado en la resolución; el panel normativo bloquea con el tope
del cargo vigente (`resolveCurrentMonthlyCap`). Si el tope del cargo bajó desde
que se decretó, el formulario deja armar una cuota que el panel rechaza.
Señalado desde el plan anterior, sin resolver.

**F · `ext_cuotas` exime del tope, y la regla dice que es ANID.** A-02 atribuye
la exención a ANID; el código la ata a la extensión de cuotas
(`effectiveCap`, y `messages.js:215` «el tope mensual no aplica»). Viene
heredado del flujo de resolución, que ya resuelve `isAnid: hasExtension`. No es
un defecto del apartado 2, pero cambia a quién se le aplica el tope.

### 11.6 Prioridad sugerida

| | Arista | Por qué |
| :-- | :--- | :--- |
| 1 | **A** | es la única que deja entrar datos inválidos a la base |
| 2 | **D** | produce un neto negativo con dos clics |
| 3 | **C** y **B** | ensucian lo que DGDP escribió; se arreglan juntas, en `sg_epaguSecgen01` y `sg_fumeuSecgen02` |
| 4 | **E** | necesita decidir cuál tope manda |
| 5 | **F** | necesita confirmación funcional, no código |

Las tres primeras son PA; ninguna necesita DDL.

---

## 12. El campo desaparecía al escribir — 14-10-2026

**El defecto.** El campo de monto se mostraba con
`v-if="(month.checked || month.blockedByCap) && ..."`, o sea su visibilidad
dependía del valor que el propio campo cambia. Con $34.028 de espacio y abril
en $74.074: al teclear el primer dígito de «34028» el monto pasaba a **7**, que
sí cabe, `blockedByCap` se apagaba y **el input se desmontaba a media
escritura**. No se podía terminar de escribir la cifra.

**La corrección.** La decisión se toma por el mes, no por cuánto vale ahora:

```js
display.amountEditable = !this.locked && row.acceptsChanges &&
  (display.checked || display.selectable || Boolean(display.blockedByCap))
```

Está en la cuota, o podría estar: en los dos casos el campo sigue ahí. Bajarlo
lo hace caber y subirlo lo vuelve a sacar, y la caja no se mueve.

Comprobado ejecutando `displayMonthRows` y `capAvailabilityOf` reales con un
`this` simulado:

| monto | marcado | editable | bloqueado por tope | seleccionable |
| ---: | :--: | :--: | :--: | :--: |
| 74.074 | no | **sí** | sí | no |
| 7 | no | **sí** | no | sí |
| 34 | no | **sí** | no | sí |
| 34.028 | no | **sí** | no | sí |
| 34.028 | sí | **sí** | no | sí |
| 74.074 | sí | **sí** | no | sí |

**El paso siguiente, dicho.** Bajar el monto hace que quepa, pero el mes sigue
fuera de la cuota hasta marcarlo, y antes nada lo decía. Cuando el monto quedó
ajustado y el mes todavía no está marcado aparece:

> *Ya cabe en la cuota. Marque el mes para incluirlo.*

Se apoya en `amountAdjusted`, que compara contra el monto con el que se abrió
la edición, así que el aviso solo sale después de que el usuario tocó algo: en
un formulario recién abierto no aparece en ningún mes.

### 12.1 «Queda fuera del pago», siempre visible

El monto que el reparto deja sin pagar vivía solo dentro de un mensaje, y solo
cuando era mayor que cero. Pasa a ser una cifra fija del encabezado, en cero
también: saber que **no** se pierde nada es tan informativo como saber cuánto
se pierde, y si la línea apareciera solo al fallar habría que adivinar el resto
del tiempo.

De paso se ordenaron los límites, **de la cuota hacia la prestación**:

| | A · 3 + 3, nada bajado | B · abril bajado a $30.000 |
| :--- | ---: | ---: |
| Tope por cuota | $256.250 | $256.250 |
| Espacio en esta cuota | $34.028 | $4.028 |
| Saldo autorizado disponible | $444.444 | $444.444 |
| Saldo después de esta cuota | $222.222 | $192.222 |
| **Queda fuera del pago** | **$0** | **$44.074** |

Dos cambios de nombre y uno de contenido:

- **«Espacio en esta cuota»** es nuevo en el encabezado. Estaba solo en el
  contador del apartado 2, lejos del tope con el que se compara.
- **«Disponible para esta cuota» → «Saldo autorizado disponible».** El nombre
  viejo competía con el espacio bajo el tope: los dos sonaban a *lo que cabe*,
  siendo cosas distintas —uno es el saldo de la prestación, el otro el hueco
  bajo el tope de esta cuota—.
- La cifra que queda fuera se marca cuando es mayor que cero, pero **la
  etiqueta ya lo dice**: el color solo subraya (§14).

Verificado ejecutando `installmentLimits` con un `this` simulado en los dos
escenarios de la tabla.

### 12.2 Por qué se pierde, y el camino que no pierde

**El motivo depende del tipo de monto**, y antes no se decía ninguno.

| Tipo | Qué pasa con lo recortado |
| :--- | :--- |
| **Fijo** (`cod_tpps = 1`) | Cada mes tiene su propia cifra decretada y **no puede subir** (C-10), así que lo que se recorta de un mes **no se puede pasar a otro**. Y el tope no se acumula (T-03), así que tampoco se recupera en una cuota posterior. |
| **Variable** (`cod_tpps = 2`) | La resolución fija solo el techo total, así que **sí se reparte** en otros meses, mientras ninguna cuota supere su tope ni el total pase lo autorizado. |

El texto de «Queda fuera del pago» ahora dice el que corresponde. En variable el
formulario **ya permitía** subir un mes —`maxAmount` solo acota en fijo, y el
reparto queda acotado por `capExceeded` y `balanceExceeded`—; lo que faltaba era
decirlo.

**El camino que no pierde nada.** Bajar el mes para que quepa es la peor salida
cuando ese mes **cabe entero en una cuota posterior**: se paga menos por el
mismo trabajo, sin necesidad. La tarjeta ahora lo dice primero:

> **Cabe completo en la cuota siguiente.** Si lo incluye en esta, hay que
> bajarlo a $34.028 y se pierden $40.046.

Y solo cuando de verdad no queda dónde ponerlo, ofrece el recorte como lo que
es —el mal menor—:

> Para incluirlo en esta cuota, baje el monto a $34.028 o menos. No quedan
> cuotas donde incluirlo entero, así que pagar una parte es mejor que no pagar
> nada.

Se decide con `fitsInNextInstallment`, que es «está cerrado por tope **y** no
está en `unpayableMonths` **y** queda alguna cuota». Comprobado con las
funciones reales:

| Escenario | ¿Cabe en la siguiente? | Pérdida si lo baja |
| :--- | :--: | ---: |
| queda una cuota y abril cabe entero | **sí** | $40.046 |
| última cuota, ya no cabe en ninguna | no | $40.046 |

### 12.3 Avisar cuando la pérdida era evitable

Explicar por qué se pierde no alcanza si además **no hacía falta perderlo**. El
aviso del encabezado ahora distingue los dos casos.

`lossIsAvoidable` simula el reparto con **cada mes en su monto decretado** sobre
las cuotas disponibles —ésta incluida—, con el mismo criterio de T-07 que ya usa
`unpayableMonths`. Si todos caben, lo que se está perdiendo es por cómo quedó
armada la cuota, no por falta de cupo, y el mensaje lo dice con el remedio al
lado:

> 2 meses quedan para la cuota siguiente. Con este reparto se pagan $400.370 de
> los $444.444 decretados: se pierden $44.074. **No hace falta perderlos:
> devolviendo cada mes a su monto decretado, todos caben en las cuotas
> autorizadas. Deje el mes que no entra para la cuota siguiente, entero.**

Cuando la pérdida **sí** es estructural —no quedan cuotas, los meses no alcanzan
a repartirse, o un mes por sí solo excede el tope— la frase no aparece y queda
solo la explicación de §12.2, que es la correcta para ese caso.

Comprobado con la función real:

| Escenario | Resultado |
| :--- | :--- |
| 6 meses de $74.074, tope $256.250, **2 cuotas** (el caso real) | **evitable** |
| sin pérdida (`droppedAmount = 0`) | no aplica |
| queda solo esta cuota | no evitable |
| 7 meses: no alcanzan 2 cuotas | no evitable |
| un mes que por sí solo excede el tope | no evitable |
| prestación exenta de tope | no aplica |

**Por qué «deje el mes entero» y no «reparta el dinero»:** en fijo el monto de
un mes no puede subir (C-10), así que lo único que se mueve es el mes completo.
La redistribución de dinero solo existe en variable, y ahí no hay pérdida que
avisar porque el formulario ya deja subir los otros meses.

### 12.4 Los textos, reescritos

El aviso había crecido a cuatro frases encadenadas en una sola línea —la
pérdida, la aritmética, el remedio y los meses pendientes— y así no se lee
ninguna. Se separó en **una idea por mensaje**, con el orden del §5.4.

| Antes | Ahora |
| :--- | :--- |
| *2 meses quedan para la cuota siguiente. Con este reparto se pagan $400.370 de los $444.444 decretados: se pierden $44.074. No hace falta perderlos: devolviendo cada mes a su monto decretado, todos caben en las cuotas autorizadas. Deje el mes que no entra para la cuota siguiente, entero.* | **aviso** · Se pierden $44.074: este reparto paga $400.370 de los $444.444 decretados.<br>**aviso** · Puede evitarlo: devuelva cada mes a su monto decretado y deje el que no entra para la cuota siguiente.<br>**info** · 2 meses quedan para la cuota siguiente. |

La cifra perdida va **primero y sola**, que es el dato que decide. El remedio es
su propio mensaje, y solo aparece cuando la pérdida era evitable. Lo pendiente
baja a información, que es lo que es.

Cuando no hay pérdida quedan dos líneas de información y ninguna advertencia:

> 3 meses quedan para la cuota siguiente.
> Con este reparto se paga el total decretado: $444.444.

**Las tarjetas de mes**, con el consejo en negrita y el detalle detrás:

| Situación | Texto |
| :--- | :--- |
| cabe en la siguiente | **Cabe completo en la cuota siguiente.** Incluirlo aquí obliga a bajarlo a $34.028 y perder $40.046. |
| ya no cabe en ninguna | **No quedan cuotas donde incluirlo entero.** Baje el monto a $34.028 o menos para pagar al menos esa parte. |
| ya cabe, falta marcar | Ya cabe en la cuota. Marque el mes para incluirlo. |

Y los tooltips de «Queda fuera del pago» pasaron de tres líneas a una:

- **fijo** — En monto fijo cada mes tiene su cifra decretada y no puede subir, así que lo recortado de un mes no pasa a otro. El tope tampoco se acumula entre cuotas.
- **variable** — En monto variable puede repartir lo recortado en otros meses, mientras ninguna cuota supere su tope ni el total pase lo autorizado.
- **sin pérdida** — Este reparto paga todo lo decretado.
