# WF pagos · texto duplicado e información que sobra

**Fecha:** 27-10-2026 · **Aplicado en las dos vistas.**

Revisión buscando únicamente dos cosas: texto que dice lo mismo dos veces y
datos que la pantalla repite sin necesidad. No es una auditoría de cálculo ni de
estándares; para eso están `auditoria_vistas_solicitud_dgdp.md`,
`auditoria_vista_solicitud_pagos.md` y los §16 a §18 de
`rechazo_devolucion_y_estados.md`, ya aplicados.

Las secciones A a D son la vista del solicitante, que es la que se revisó
primero; «Lo mismo en la vista DGDP», al final, es el mismo barrido sobre
`payments.review`. El barrido se hizo contra el catálogo completo
(`lang/es/pds.js`: 542 claves bajo `payments.detail` y 559 bajo
`payments.review`) y contra los 390 archivos de código del frontend.

---

## A · Lo que la pantalla dice dos veces

Esto es lo que más pesa, porque el usuario lo ve.

### A1 · El período de ejecución aparece dos veces en la misma pestaña

`Du288PaymentContextSection` muestra el campo «Período de ejecución»
(`:127`, valor en `periodLabel()` `:189`). Tres líneas más abajo en la misma
pestaña, `Du288ExecutionWeekSection` cierra su resumen con otro «Período de
ejecución» (`:171`), calculado por un `periodLabel()` propio (`:132`).

Las dos funciones son **idénticas carácter por carácter**: mismas claves de
origen (`executionStartDate || f_inicio`, `executionEndDate || f_termino`), mismo
separador, mismo rótulo de dato ausente. Es la misma fecha escrita dos veces en
la misma pantalla, desde dos copias del mismo código.

Lo que sobra es la del resumen de carga: ahí el dato no explica nada —el resumen
habla de horas— y la ficha de contexto es el lugar donde el usuario ya lo busca.

### A2 · El régimen de cuotas aparece dos veces

| Dónde | Qué dice |
| :--- | :--- |
| `Du288PaymentContextSection:158` | «Cuota máx. que puede pedir: Máximo 2 cuotas (normativa general DU288)» |
| `Du288InstallmentsSection:153` (`capacityNote`) | «… · Tope: 2 cuotas normativa general» |

Las dos secciones se renderizan juntas en la pestaña «Gestión de pago»
(`_nroSolici/index.vue:27-45`). El tope normativo es un dato que no cambia
nunca; decirlo dos veces a quince centímetros de distancia no agrega
información.

### A3 · El avance de cuotas aparece tres veces, y una de ellas no dice nada nuevo

Con una resolución de dos cuotas decretadas y una ya enviada, la pestaña muestra:

1. `Du288PaymentContextSection:144` → «Cuota actual: **Cuota 1 de 2**»
2. `Du288PaymentContextSection:152` → «Cuotas autorizadas: **2 cuotas decretadas**»
3. `Du288InstallmentsSection:153` → «**Cuota 1 de 2** · Tope: 2 cuotas …»
4. `Du288InstallmentsSection:145` (`creationHeadline`) → «Puede crear **1 cuota** más»

El punto 2 es el caso más claro de información que sobra: el «2» ya está dicho
en el punto 1, dentro de la misma lista de campos y dos filas más arriba. Un
campo entero de la ficha para repetir un número que está justo encima.

El punto 3 repite el punto 1 completo, y el punto 4 es la misma cuenta expresada
al revés (`autorizadas − solicitadas`). Entre los cuatro hay **un solo dato**:
cuántas cuotas se decretaron y cuántas se usaron.

### A4 · El monto de la cuota activa aparece dos veces, lado a lado

`Du288PaymentWorkspace` pone la lista y el panel uno al lado del otro. En la
lista, la fila activa muestra «Solicitado $X» (`Du288InstallmentsSection:37`);
en el panel, el titular del formulario muestra «Total de la cuota $X»
(`Du288InstallmentFormSection:86`). Misma cifra, dos rótulos distintos, visibles
al mismo tiempo.

No es un error —el titular del formulario tiene sentido cuando la cuota se está
editando— pero con la fila seleccionada a la izquierda el titular es redundante,
y los dos rótulos distintos para la misma cifra invitan a pensar que son
magnitudes diferentes.

### A5 · «A pagar» rotula dos cosas distintas en el mismo panel

En `Du288InstallmentFormSection`, `text.totalNet` (`:113`) rotula el neto de
**toda la cuota** y `text.netPerMonth` (`:225`) el neto de **un mes**. Las dos
claves valen `'A pagar'`. En el mismo panel, con las tarjetas de mes debajo del
titular, el mismo rótulo aparece para una cifra total y para varias cifras
parciales.

Esto no es redundancia: es ambigüedad. Las dos claves existen precisamente
porque son cosas distintas; lo que falta es que el texto lo diga.

---

## B · Claves del catálogo con el mismo texto dentro del mismo nodo

Seis casos. No son duplicados entre vistas —eso es la estructura del catálogo y
está bien— sino dos o tres claves con el mismo valor dentro de un solo nodo.

| Nodo | Texto | Claves |
| :--- | :--- | :--- |
| `payments.detail.installments` | «Solicitado» | `requestedLabel`, `requested`, `rejectedRequestedLabel` |
| `payments.detail.installmentModal` | «Detalle de cuota» | `readTitle`, `rejectedTitle` |
| `payments.detail.installmentModal` | «Meses seleccionados» | `selectedMonths`, `selectedCount` |
| `payments.detail.installmentModal` | «meses» | `monthMany`, `monthsCounterSuffix` |
| `payments.detail.installmentModal` | «A pagar» | `netPerMonth`, `totalNet` |
| `payments.detail.installmentModal` | «Total de la cuota» | `total`, `installmentTotal` |

De estas trece claves, **tres no las lee nadie**: `rejectedRequestedLabel`,
`selectedMonths` y `selectedCount`. De las parejas restantes ninguna sobra del
todo, porque cada una se usa en un componente distinto —`total` en el modal de
envío, `installmentTotal` en el formulario—, que es exactamente el motivo por el
que convendría una sola.

El caso de `readTitle` / `rejectedTitle` tiene un síntoma visible en el código:

```js
return `${this.text.rejectedTitle || this.text.readTitle} (…)`
```

`Du288InstallmentFormSection:362`. Un `||` entre dos claves que valen lo mismo:
la segunda rama nunca se ejecuta y, si algún día alguien cambia una, el `||`
oculta cuál ganó.

---

## C · Claves que nadie lee

De las 542 claves bajo `payments.detail`, **54** no aparecen referenciadas en
ningún archivo del frontend. Revisando a mano los nodos cuyo nombre de clave
coincide con un identificador del código —y que el barrido por eso no puede
ver— aparecen **13 más**: **67 claves muertas**, uno de cada ocho rótulos del
catálogo de esta vista.

### C1 · Dos nodos prácticamente completos

**`payments.detail.summary` — 9 claves, 1 en uso.**
Solo se lee `noResolution` (`_nroSolici/index.vue:552`). Las otras ocho
—`title`, `staff`, `activity`, `resolution`, `amountType`, `fixed`, `variable`,
`total`— son el bloque «Resumen de la prestación» que `Du288PaymentContextSection`
reemplazó. El bloque se fue; sus rótulos se quedaron.

**`payments.detail.schedule` — 7 claves, 2 en uso.**
Solo se leen `summary` y `period`, y las lee
`Du288ExecutionWeekSection` (`:58` y `:172`), que es un componente de la vista
DGDP: su `text()` apunta a `payments.review.detail.executionWeek` y esas dos
claves no existen ahí, así que las toma de este nodo. Las otras cinco —`title`,
`subtitle`, `week`, `weeklyTotal`, `noDaySchedules`— no las lee nadie.

Ese cruce es, además, el otro hallazgo de este nodo: **una sección de la pantalla
lee sus rótulos de dos nodos distintos**, uno de la vista DGDP y otro de la del
solicitante, según cuál tenga la clave. Nada lo indica desde el código.

### C2 · El resto, por nodo

| Nodo | Claves muertas |
| :--- | ---: |
| `payments.detail.installmentModal` | 18 |
| `payments.detail.months` | 14 |
| `payments.detail.summary` | 8 |
| `payments.detail.installments` | 7 |
| `payments.detail.schedule` | 5 |
| `payments.detail.context` | 5 |
| `payments.detail.compensations` | 3 |
| `payments.detail.actions` | 3 |
| `payments.detail.staff` | 2 |
| `payments.detail.budget`, `payments.detail.messages` | 1 cada uno |

Las de `installmentModal` y `months` son el rastro de dos rediseños: el
formulario pasó de un asistente por pasos (`stepWhen: '1. ¿Cuándo se paga?'`,
`whenPaid`, `whenPaidHelp`, `selectMonths`, `willRequest`, `totalRequested`,
`capAvailable`, `capRoom`, `periodCapAvailable`, `fixedAmountHelp`,
`variableAmountHelp`, `fixedDistribution`, `timeliness`, `lateHint`) al titular
y panel de límites actuales; y las tarjetas de mes dejaron atrás sus botones y
avisos propios (`manage`, `registerCompensation`, `editCompensation`,
`registerCompensationFor`, `continueCompensationFor`, `viewCompensationFor`,
`selectMonthIdle`, `systemProposal`, `lockedForChanges`, `monthsSummary`,
`monthsSummaryOne`, `registeredOne`, `registeredMany`, `monthState.inInstallment`).

Ninguna de las 67 hace daño en pantalla —no se muestran— pero sí al leer el
catálogo: al buscar el rótulo de un campo aparecen tres candidatos y dos son de
una versión que ya no existe.

---

## D · Fallbacks en duro que la auditoría anterior no listó

El §18.4 quitó seis `|| 'Texto'` de claves que ya existían. Quedaron cuatro más
del mismo tipo, que el barrido anterior no alcanzó porque están fuera de los
archivos que la auditoría enumeró:

| Archivo | Línea | Texto |
| :--- | ---: | :--- |
| `Du288ExecutionWeekSection` | 58 | `\|\| 'Resumen de carga'` |
| `Du288ExecutionWeekSection` | 172 | `\|\| 'Período de ejecución'` |
| `Du288PaymentDocumentTab` | 17 | `text.openNewTab \|\| 'Abrir en pestaña nueva'` |
| `Du288PaymentDocumentTab` | 21 | `text.openNewTab \|\| 'Abrir'` |

Las dos del `DocumentTab` merecen nombrarse aparte: es **la misma clave con dos
fallbacks distintos**, uno para el `title` y otro para la etiqueta del botón.
Mientras la clave falte se leen dos textos; el día que exista, los dos lugares
dirán lo mismo y uno de los dos quedará mal.

Y un texto en duro que no es fallback de nada:

```js
return number ? `Resolución N° ${number}${year ? ` / ${year}` : ''}` : …
```

`_nroSolici/index.vue:552`. El prefijo «Resolución N°» y el separador están en la
plantilla, no en el catálogo, aunque `payments.detail.context.resolution` ya
existe para rotular ese mismo dato.

---

## E · Lo que se repite y no sobra

Para no confundir repetición con redundancia:

- **El saldo** aparece en la ficha de contexto, en el panel de límites del
  formulario y en el modal de envío. Son tres momentos distintos —consulta,
  edición y confirmación— y en el último es el dato que sostiene la decisión.
  Desde el §18.1 las tres cifras salen de la misma función, así que no pueden
  contradecirse.
- **La pestaña «Antecedentes»** repite funcionario, actividad, resolución y
  montos a través de `ResolutionDetail`. Es el documento de origen, en una
  pestaña aparte, y eso es lo que el usuario va a buscar ahí.
- **Los rótulos repetidos entre `payments.detail` y `payments.review.detail`**
  («Funcionario» nueve veces, «Centro de costo» nueve veces, «Actividad» seis)
  son la estructura del catálogo: un nodo por vista. Cambiar eso es un refactor
  del catálogo completo, no una limpieza de esta vista.

---

## Resumen

| | Hallazgo | Clase | Dónde | Aplicado |
| :--- | :--- | :--- | :--- | :--- |
| A1 | el período de ejecución se muestra dos veces, desde dos copias del mismo `periodLabel()` | dato repetido | `…ContextSection:127/189`, `…ExecutionWeekSection:132/171` | sí |
| A2 | el régimen de cuotas se muestra dos veces en la misma pestaña | dato repetido | `…ContextSection:158`, `…InstallmentsSection:153` | sí |
| A3 | el avance de cuotas se dice cuatro veces; «Cuotas autorizadas» repite un número que está dos filas arriba | dato repetido | `…ContextSection:144/152`, `…InstallmentsSection:145/153` | sí |
| A4 | el monto de la cuota activa aparece en la lista y en el titular del panel, lado a lado y con rótulos distintos | dato repetido | `…InstallmentsSection:37`, `…FormSection:86` | sí |
| A5 | «A pagar» rotula el neto de la cuota y el neto del mes en el mismo panel | ambigüedad | `…FormSection:113/225` | sí |
| B | 6 grupos de claves con el mismo texto dentro de un solo nodo (13 claves) | catálogo | `installments`, `installmentModal` | sí |
| B' | `rejectedTitle \|\| readTitle`: un `\|\|` entre dos claves que valen lo mismo | catálogo | `…FormSection:362` | sí |
| C1 | `payments.detail.summary`: 9 claves, 1 en uso | catálogo muerto | `lang/es/pds.js` | sí |
| C2 | `payments.detail.schedule`: 7 claves, 2 en uso, y las lee un componente de la vista DGDP | catálogo muerto | `…ExecutionWeekSection:58/172` | sí |
| C3 | 67 claves de `payments.detail` sin ninguna referencia (de 542) | catálogo muerto | `lang/es/pds.js` | sí |
| D1 | 4 fallbacks en duro de claves existentes, dos de ellos sobre la misma clave con textos distintos | §15 | `…ExecutionWeekSection:58/172`, `…DocumentTab:17/21` | sí |
| D2 | «Resolución N°» escrito en la plantilla | §15 | `_nroSolici:552` | sí |

Los doce quedaron aplicados el 27-10-2026, **y lo mismo se revisó y aplicó en la
vista DGDP**, donde el barrido encontró su propia cosecha. El detalle de qué
cambió está en el §19 de `rechazo_devolucion_y_estados.md`.

## Lo mismo en la vista DGDP

El barrido se repitió sobre `payments.review` (559 claves) y sobre los
componentes de la revisión:

| | Hallazgo | Clase |
| :--- | :--- | :--- |
| R1 | **56 claves sin ninguna referencia**, 34 de ellas en `payments.review.detail.execution`: la familia `cross*` completa (18 claves) de una tabla «Ejecución mes a mes» que ya no existe, más los rótulos de una versión anterior del resumen semanal | catálogo muerto |
| R2 | la tarjeta del mes repetía el patrón del formulario del solicitante: «Total de la cuota» frente a «A pagar» para el total y «A pagar» otra vez para cada mes, y una tercera clave (`netTotal`) con el mismo texto para el modal de decisión | ambigüedad |
| R3 | `Du288PaymentBudgetSection` —compartido por las dos vistas— tenía **diez** `\|\| 'Texto'` sobre claves que ya existen, y cuatro textos en duro sin clave: los dos rótulos de «Decreto afecto», «Educación Continua», «Saldo suficiente» y «Fondos Propios» | §15 |
| R4 | los tres títulos de grupo de la ficha DGDP iban con fallback en duro, y uno de ellos —`groups.amounts`— **no existía**, así que el fallback era el texto real | §15 |
| R5 | `relationship.empty` decía «No fue posible consultar el parentesco.» en el lugar donde el dato significa «no registra parentesco»: el fallback en duro tenía la redacción correcta y la clave la equivocada | texto incorrecto |
| R6 | `executionWeek.summary` no existía, así que la sección leía ese rótulo del nodo del solicitante (`payments.detail.schedule`) y el otro del suyo: **una sección con los rótulos repartidos en dos nodos** | catálogo |
| R7 | `Du288PaymentAttendanceSection` (asistencia y reloj control) no se monta en ninguna parte | componente huérfano |

R5 es el único que cambia lo que el revisor lee de la base; el resto es rótulo y
catálogo.

## Lo que quedó fuera

- **Dos componentes huérfanos**: `Du288InstallmentSummarySection` (340 líneas) y
  `Du288PaymentAttendanceSection`. Ninguno se monta. Borrarlos o montarlos es una
  decisión funcional, no una limpieza, así que siguen donde estaban; sus
  referencias al catálogo se dejaron coherentes para que no apunten a claves
  borradas.
- **Nueve grupos de claves con el mismo texto que sí tienen razón de ser**, todos
  en `payments.review`: una palabra que sirve a dos o tres papeles distintos
  —título de sección, ítem de leyenda y tooltip del día («Ejecución
  comprometida», «Feriado», «Compensación comprometida», «Compensación
  informada»); título de modal, botón y columna («Descuentos»); chip y rótulo de
  fila («Licencia médica»); columna y fila de totales en la sección de
  asistencia—. Colapsarlas obligaría a que un cambio en la leyenda arrastre el
  título de la sección.
- **`statusVariant` 3 y 11 valen los dos `warning`**: son variantes de estilo por
  código de estado, no texto.
- **Verificación en navegador**: nada se revisó a 1366, 1024, 768 ni 375 px. Los
  cambios de esta tanda son rótulos y campos que desaparecen, así que lo que hay
  que mirar es que la ficha de contexto no quede con una fila impar al perder dos
  campos.
