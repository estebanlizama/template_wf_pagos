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
