# Plan: dinamismo de la selección de cuotas y su reflejo en la financiación

Problema a resolver, en palabras del requerimiento: **seleccionar una cuota para
editar y seleccionar una cuota para guardar/enviar deben reflejarse en la
financiación, sin confundir lo que está en edición con lo que ya está guardado o
lo que está por guardar.**

Fecha: 22-10-2026. Alcance: solo la vista de detalle de pago del solicitante
(`pages/services-provision/payments/_nroSolici/index.vue` y sus secciones). **No
toca los PA ni la creación de cuotas**, ni nada del WF de resolución.

---

## 1. Cómo está hoy

### 1.1 Hay tres nociones distintas de "la cuota de la que estamos hablando"

| Noción | Dónde vive | Quién la mueve |
| :--- | :--- | :--- |
| `activeInstallmentNumber` | estado de la página | el botón de abrir de cada fila de la lista |
| `installmentToSend` → `selectedToSend` | estado de la página | un `b-form-select` aparte, en la barra de envío |
| `activeOrSendableInstallment` | computada | **`selectedToSend` primero**, y solo si no hay, la abierta |

Las tres conviven. El usuario elige dos veces —una en la lista para editar y otra
en la barra para enviar— y la pantalla no dice que son la misma decisión.

### 1.2 Hay tres fuentes de plata, y solo una ve el borrador

| Fuente | Qué es | ¿Ve el borrador en pantalla? |
| :--- | :--- | :---: |
| `paymentBalance` (getter del store) | suma de las cuotas **guardadas**, por estado | no |
| `costCenterBalance` | snapshot de la última llamada a `revalidateNormative` | no |
| las computadas del formulario | lo que se está armando | **sí** |

`revalidateNormative` corre en cuatro momentos: carga de la vista, cambio de
funcionario, después de guardar y antes de enviar. **No corre al seleccionar otra
cuota ni al cambiar un monto.**

### 1.3 Los estados de cuota y cómo los agrupa el cálculo

`cod_estcuo`: 1 Propuesta · 2 En visación · 3 Devuelta · 4 Aprobada ·
8 Enviada a remuneraciones · 10 Rechazada · 11 Devuelta de Finanzas.

`resolvePaymentAmountBalance` los reparte así:

- `consumed` ← 8 (por `amountSent`) y 2, 3, 4, 11 (por `requestedAmount`)
- `proposed` ← 1
- `remaining` = `authorized − consumed`

Y el backend marca `isEditable` para **1 y 3**.

---

## 2. Hallazgos

### H1 — El respaldo PDF se puede adjuntar a la cuota equivocada (funcional, grave)

`Du288InstallmentEvidenceSection` recibe `activeOrSendableInstallment`, que da
prioridad a `selectedToSend`. Con la cuota 1 enviable y la cuota 2 abierta en el
compositor, `uploadInstallmentEvidence` sube el PDF con
`installment.installmentNumber` = **1**, y acto seguido
`this.$refs.installmentEditor?.setEvidenceUploaded(...)` marca como adjuntado el
borrador de la **2**. El archivo queda en una cuota y el "listo" en otra.

Lo mismo arrastra `hasInstallmentEvidence` y `evidenceValidationTag`: el chip
"Falta respaldo justificativo" puede estar hablando de una cuota que no es la que
se está mirando.

### H2 — La financiación no ve el borrador

La tira de montos del contexto muestra `Pagado`, `Comprometido` y `Saldo`, donde
`Saldo = authorized − consumed`. Una cuota en estado 1 —guardada, sin enviar— no
aparece en ninguna de las tres: no está pagada, no está comprometida y no
descuenta del saldo. Está en `proposed`, que la tira no muestra. Lo que se está
escribiendo en el formulario en este momento, menos todavía.

La única resta que sí la considera es `unreservedAuthorizedBalance`
(`remaining − proposed`), que la página calcula y pasa **solo a la lista de
cuotas**, para decidir si se puede crear otra.

### H3 — "Consumido" mezcla la cuota devuelta con la aprobada y la enviada

Una cuota devuelta (3) es editable y su monto va a cambiar. Hoy pesa igual que
una enviada a remuneraciones (8), que es plata que ya salió. Son cosas distintas:
una es **plata que salió**, la otra es **plata reservada por algo que hay que
corregir**.

### H4 — La validación presupuestaria se consulta con un monto que no es el de la cuota

`validationAmount` sale de `normativeValidationAmount`: el **máximo** de los
montos de las cuotas editables guardadas, y si no hay ninguna,
`min(total, tope)`. Es un monto representativo para preguntar "¿alcanza el
saldo?", no el de una cuota concreta. La tabla, sin embargo, lo rotula
"Monto solicitado" junto a "Saldo remanente", como si fuera el de la cuota en
pantalla.

`costCenterPayload` (lo que la sección recibe como `installment` en el detalle)
no trae `requestedAmount`, así que el fallback tampoco corrige nada.

### H5 — El borrador no publica su monto

`onDraftState` guarda `installmentDraft`, y nadie lo lee: la propiedad se asigna
y muere ahí. El payload es `{open, editing, valid, dirty}` — sin monto, sin
meses, sin número de cuota. Aunque la financiación quisiera reaccionar al
borrador, hoy no tiene de dónde.

### H6 — Seleccionar una cuota mueve el panel y nada más

`activeInstallmentNumber` pinta `is-active` en la fila y elige qué muestra el
compositor. El resumen de montos, la validación presupuestaria y los chips siguen
hablando de otra cuota.

---

## 3. Propuesta

### 3.1 Vocabulario único de seis capas

Toda la pantalla pasa a nombrar la plata con los mismos seis rótulos, en este
orden:

| Capa | De dónde sale | Estado |
| :--- | :--- | :--- |
| **Pagado** | `provisionSummary.paidAmount` | cuotas en 8 |
| **En trámite** | cuotas en 2, 4, 11 | guardado, fuera de alcance del solicitante |
| **Por corregir** | cuotas en 3 | guardado y editable |
| **En borrador** | cuotas en 1 | guardado y editable |
| **En edición** | el formulario abierto con cambios sin guardar | **no guardado** |
| **Disponible** | `authorized` menos las cinco anteriores | — |

Las tres primeras son lo que el solicitante ya no puede mover. Las dos del medio
son lo que tiene en la mano. "En edición" se muestra **solo mientras el
formulario está abierto y sucio**, y con un rótulo que dice que todavía no está
guardado: así queda explícito lo que el requerimiento pide no confundir.

### 3.2 Paso 1 — Una sola "cuota en foco"

- `activeInstallmentNumber` pasa a ser la única selección: abrir una cuota en la
  lista es seleccionarla, punto.
- El `b-form-select` de la barra de envío **desaparece**. En su lugar, la barra
  dice qué cuota se enviaría —la que está en foco— y, si la que está en foco no
  es enviable, lo dice y ofrece el salto a la que sí.
- `activeOrSendableInstallment` se elimina. Se reemplaza por `focusedInstallment`
  = la cuota en foco, y donde hoy se usaba el fallback "la primera enviable", se
  usa un foco inicial: al cargar, la vista enfoca la primera enviable (el mismo
  resultado de hoy, pero una sola vez y de forma explícita).

**Esto cierra H1 y H6.** El respaldo se adjunta a la cuota en foco, que es la que
el usuario está mirando.

### 3.3 Paso 2 — El borrador publica su monto

`Du288InstallmentFormSection.emitState` pasa a emitir, además de lo que ya emite:

```js
{ open, editing, valid, dirty,
  installmentNumber,          // la cuota que se está armando (null si es nueva)
  grossAmount, deductions, netAmount,
  monthSequences }            // los meses marcados
```

Son cifras que el componente ya calcula para su propio resumen; acá solo se
exponen. La página las guarda en `installmentDraft` —que por fin se usa— y las
pasa hacia abajo.

### 3.4 Paso 3 — `resolvePaymentAmountBalance` separa las capas

En `utils/services-provision/normative/paymentValidations.js`, la función ya
existente devuelve hoy `{authorized, consumed, proposed, remaining}`. Pasa a
devolver además:

```js
{ paid, inProgress, returned, drafted, available }
```

- `paid` ← estado 8
- `inProgress` ← 2, 4, 11
- `returned` ← 3  (hoy está dentro de `consumed`)
- `drafted` ← 1  (es el `proposed` de hoy, renombrado al vocabulario)
- `available` = `authorized − paid − inProgress − returned − drafted`

`consumed`, `proposed` y `remaining` se mantienen con el mismo significado para
no romper a los nueve consumidores que ya los leen; las capas nuevas se suman.
La aritmética queda en un solo lugar y con pruebas, como el resto del módulo.

**Esto cierra H3**, y le da a la vista de dónde sacar las capas de 3.1.

### 3.5 Paso 4 — La tira de montos muestra las capas

`Du288PaymentContextSection.amountFields` reemplaza las tres filas de plata
(`Pagado`, `Comprometido`, `Saldo`) por las seis de 3.1. "En edición" se agrega
solo cuando el borrador está abierto y sucio, en el color de aviso y con el
rótulo "sin guardar"; "Disponible" muestra dos cifras cuando hay edición en
curso: la de ahora y la que quedaría si se guarda.

### 3.6 Paso 5 — La validación presupuestaria sigue a la cuota en foco

Dos cambios, que resuelven H4 sin golpear el endpoint en cada tecla:

1. **Al cambiar el foco** (no al teclear), la página revalida con
   `validationAmount` = el monto de la cuota enfocada. Es el mismo disparo que
   hoy ocurre al guardar, con un gatillo más.
2. **Mientras se teclea**, la tabla no se vuelve a consultar: el "Saldo
   remanente" se recalcula en el front como `saldoInicial − monto en edición` y
   la fila se marca como **proyección** (rótulo y estilo distintos), con la
   fecha/hora de la última consulta real al lado. Así la cifra acompaña al
   usuario sin fingir que el servidor la confirmó.

`Du288PaymentBudgetSection` recibe dos props nuevas, `projectedAmount` y
`projected`, y el `installment` que recibe en el detalle incluye el
`requestedAmount` de la cuota en foco (hoy `costCenterPayload` no lo trae).

### 3.7 Paso 6 — Señal de edición en toda la pantalla

- La fila de la lista de la cuota en foco, cuando hay cambios sin guardar, suma
  un chip "sin guardar" junto al estado.
- El encabezado del compositor dice de qué cuota se trata y en qué estado está
  (`Cuota 2 · Propuesta · sin guardar`), en vez de dejarlo implícito.
- El resto de las secciones que hablan de "la cuota" (respaldo, validaciones,
  envío) muestran el número en el título, para que no quede duda de a qué cuota
  se refieren.

### 3.8 Paso 7 — Pruebas

Al módulo `paymentValidations` (ya tiene corredor propio y 13 pruebas):

- las cinco capas suman exactamente `authorized` en cada combinación de estados;
- una cuota en 3 sale de `returned` y no de `inProgress`;
- `consumed`, `proposed` y `remaining` conservan los valores de hoy (prueba de
  no-regresión para los consumidores existentes);
- `available` nunca es negativo y no se confunde con `remaining`.

El resto (foco único, señal de edición, proyección del saldo) es de vista y se
verifica en navegador.

---

## 4. Orden de aplicación y riesgo

| # | Paso | Archivos | Riesgo |
| :-- | :--- | :--- | :--- |
| 1 | Capas en `resolvePaymentAmountBalance` + pruebas | `paymentValidations.js`, su test | bajo: solo agrega campos |
| 2 | Cuota en foco única | `index.vue`, `Du288InstallmentsSection.vue` | medio: elimina el selector de envío |
| 3 | El borrador publica su monto | `Du288InstallmentFormSection.vue`, `index.vue` | bajo |
| 4 | Tira de montos con capas | `Du288PaymentContextSection.vue`, `pds.js` | bajo |
| 5 | Saldo proyectado y revalidación al cambiar foco | `index.vue`, `Du288PaymentBudgetSection.vue` | medio: toca la tabla oficial |
| 6 | Señales de edición | lista, compositor, títulos | bajo |

El paso 1 habilita el 4 y el 5; el 2 habilita el 6. **El paso 2 es el que arregla
H1**, así que si hay que partir el trabajo, el 1 y el 2 van primero.

---

## 5. Lo que este plan no hace

- **No toca los PA.** Toda la aritmética nueva es de presentación: el PA sigue
  siendo el que revalida al guardar y al enviar.
- **No cambia la creación de cuotas** ni las reglas de monto, tope, extensión o
  pérdida: `canCreateInstallment`, `resolvePaymentPeriodCap` y
  `isPaymentLossAvoidable` quedan como están.
- **No cambia el WF de resolución.** La rejilla de 9 campos del centro de costo
  se mantiene idéntica; lo único que se suma es la fila de proyección dentro de
  la validación presupuestaria, que es propia de pagos.

---

## 6. Decisiones que necesito antes de aplicar

1. **El selector de envío**: ¿se elimina de verdad y el envío pasa a ser siempre
   "la cuota en foco"? Es lo que hace la pantalla consistente, pero cambia un
   gesto que ya está aprendido.
2. **La cuota devuelta (estado 3)**: ¿su monto reserva plata mientras se corrige
   (queda en `returned`, descontando de `Disponible`), o se libera y se vuelve a
   reservar al guardar? El plan asume lo primero, que es lo conservador.
