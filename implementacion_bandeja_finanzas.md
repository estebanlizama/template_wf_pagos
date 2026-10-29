# Implementación end-to-end: bandeja de cuotas aprobadas y envío a Finanzas

**Fecha:** 27-10-2026, actualizado el 28-10-2026
**Estado:** orden de construcción. El qué y el por qué están en
`plan_bandeja_aprobadas_finanzas.md`; acá va el cómo, capa por capa, en el orden
en que se puede ejecutar y verificar.

**Avance al 28-10-2026.** F1, F2 y F3 están implementadas de punta a punta.
Para F4 ya están confirmadas las fuentes de Código Haber, Ítem y Porcentaje CC,
y la salida será una fila por asignación mensual SISPER y por cada centro de
costo asociado. Se aplica el prorrateo del neto de la cuota por porcentaje CC,
con el residuo de redondeo en la última línea para conservar el total; falta
validar la regla con Finanzas.

| Capa | Estado |
| :--- | :--- |
| `sg_epaguSecgen04` + par de certificación | **hecho**, sin ejecutar contra Sybase |
| Consulta `markInstallmentSentToPayroll` | **hecho** |
| Modelos de petición y resultado | **hecho** |
| Repositorio `markInstallmentsSentToPayroll` | **hecho** |
| Endpoint `POST …/installments/sent-to-payroll` | **hecho** |
| Store `markInstallmentsSentToPayroll` | **hecho** |
| Pruebas unitarias del lote | **hecho**, 8 casos |
| Filtro por fecha de envío (`sentFrom`/`sentTo`) | **hecho**, con 3 pruebas |
| Opción `showStatus` del esquema DGDP | **hecho** |
| Texto `payments.finance` | **hecho**, 52 claves, 0 sin referencia |
| Página `payments/finance/index.vue` | **hecho**, en la lista del validador visual |
| Ruta, menú y tarjeta de inicio | **hecho** |
| Pantalla de la acción (F3.6) | **hecho**, en la bandeja |
| F2: volver a la bandeja de origen | **hecho**, por `query.origen` |
| F4 · el Excel | implementada en código; regla de prorrateo pendiente de validación funcional y PA sin ejecutar en Sybase |

**Lo que no es como lo describía el plan.** Cinco cosas se decidieron al
construir, y valen para quien lea el plan después:

1. **El estado no es fijo en 4: son dos conjuntos.** La bandeja ofrece «Por
   enviar a Finanzas» (4) y «Ya enviadas a Finanzas» (8) en un solo selector,
   porque el 8 lo escribe ahora `sg_epaguSecgen04` y consultar lo ya enviado es
   el mismo PA con otro `cod_estcuo`. La acción de registrar el envío solo
   aparece en el primero.
2. **El mes a pagar es un mes, no un rango.** Lo que se entrega a Finanzas es la
   nómina de un período, así que un `type="month"` obligatorio alimenta
   `paymentFrom` y `paymentTo` con el mismo valor. Sin mes elegido la tabla
   queda vacía a propósito, con su propio mensaje.
3. **El lote son las cuotas a la vista.** No hay selección por fila: se
   registran las filas filtradas, y el modal lo dice. Acotar el lote es acotar
   los filtros, que es lo mismo que hace la descarga. Agregar casillas por fila
   habría dejado dos definiciones del lote —lo marcado y lo filtrado— para el
   archivo y para el registro, que tienen que ser el mismo conjunto.
4. **El filtro de alertas no está en esta bandeja.** Las alertas son del momento
   de visar; sobre una cuota ya aprobada sugerirían que todavía bloquean algo.
5. **La bandeja se reconstruye desde la URL** (`estado` y `periodo`), para que
   volver del detalle no devuelva la vista en blanco.

## Decisiones de entrada

1. **La bandeja es de DGDP**, con el mismo permiso, rol y condición que la
   bandeja de revisión: `provision-payment-read-waiting` más la pertenencia a la
   unidad 696 que ya validan las PA. No se crea permiso ni se toca ninguna PA
   por autorización.
2. **El envío a Finanzas se marca con una acción explícita**, separada de la
   descarga: la cuota pasa de 4 a 8 y sus meses de 2 a 3, con `fec_envrem`.
3. **El detalle no se duplica.** La ruta de revisión ya es de solo lectura para
   una cuota aprobada.
4. **El Excel va al final** y sigue bloqueado por tres columnas sin fuente y por
   el mes de proceso del ejemplo.

## Mapa end-to-end

| # | Capa | Archivo | Qué cambia |
| :--- | :--- | :--- | :--- |
| **F1** | texto | `lang/es/pds.js` | nodo nuevo de la vista |
| | filtro | `utils/servicesProvisionDgdpReviewFilter.js` | filtro por fecha de envío |
| | esquema | `schemes/tables/services-provision-dgdp-installments-table-scheme.js` | columnas parametrizables |
| | página | `pages/services-provision/payments/finance/index.vue` | nueva |
| | navegación | `config/menuChildren/servicesProvisionPayments.js`, `pages/index.vue` | entrada y atajo |
| | gate | `utils/validateDu288Ui.js` | agregar la página a la lista |
| **F2** | página | `payments/review/_staffProvisionId/_installmentNumber.vue` | `backRoute` según origen |
| **F3** | PA | `cambios_pa/sg_epag/sg_epaguSecgen04.sql` + `.txt` | nueva |
| | PA doc | `cambios_pa/sg_epag/README.md` | tabla y diagrama de estados |
| | consulta | `db-assets/.../service-provision-payment.ts` | `markInstallmentsSentToPayroll` |
| | repositorio | `service-provision-payment-procedures.repository.ts` | método nuevo |
| | controlador | `service-provision-payment.controller.ts` | endpoint nuevo |
| | store | `store/service-provision-payments.js` | acción nueva |
| | página | `payments/finance/index.vue` | acción de lote y confirmación |
| **F4** | — | — | Excel, bloqueado |

---

## F1 · La bandeja

Frontend puro: ninguna capa de backend cambia. `fetchDgdpInstallments({ statusCode: 4 })`
ya existe y el PA ya acepta el 4.

### F1.1 Texto

Nodo `payments.finance` en `lang/es/pds.js`, con el mismo reparto que
`payments.review`: `title`, `subtitle`, `filters.*`, `totals.*`, `empty.*`,
`actions.*`. **Nada de texto en la plantilla**: §15 del estándar visual.

Reutilizar `payments.review.columns` para los encabezados en vez de copiarlos —
son las mismas columnas y una copia significaría dos rótulos para la misma
columna, que es lo que el §19.2 del informe de redundancia vino a sacar.

### F1.2 Filtro por fecha de envío

Único cambio al módulo de filtros. En `servicesProvisionDgdpReviewFilter.js`:

- `emptyDgdpReviewFilter()` gana `sentFrom` y `sentTo`.
- `matchesSentRange(row, from, to)` compara contra `requestedAt` (`fec_solici`,
  la fecha de envío a DGDP), con el mismo patrón que `matchesPaymentRange`.
- `filterDgdpInstallments` agrega el término; `hasActiveDgdpFilters` lo cuenta.
- Pruebas en `utils/__tests__/servicesProvisionDgdpReviewFilter.test.cjs`: rango
  cerrado, solo desde, solo hasta, fila sin fecha.

Lo que **no** hay que hacer: un módulo de filtros propio para Finanzas. La
bandeja filtra las mismas filas con los mismos criterios.

### F1.3 Columnas

`createServicesProvisionDgdpInstallmentsTableScheme(pdsText, options)` con un
segundo argumento. La única diferencia real es que con el estado fijo en 4 la
columna «Estado de la cuota» no distingue nada:

```js
createServicesProvisionDgdpInstallmentsTableScheme(pdsText, { showStatus: false })
```

Parametrizar, no copiar: la columna de resolución que se agregó esta semana
tendría que agregarse dos veces.

### F1.4 Página

`pages/services-provision/payments/finance/index.vue`, partiendo de
`review/index.vue`:

- **Sin** selector de estado; `statusCode` fijo en `DGDP_STATUS.APPROVED`.
- **Período de pago obligatorio**: el filtro `paymentFrom`/`paymentTo` ya existe;
  acá además valida y, sin él, la tabla no se carga y el vacío explica por qué.
- Tres totalizadores sobre las filas filtradas: cuotas, funcionarios distintos
  (por `staffRut`) y suma del neto. El neto por fila sale del módulo de montos
  (`utils/services-provision/normative/paymentValidations.js`), no de una resta
  escrita en la página.
- Estados de carga, error y sin resultados, con el texto del catálogo.
- `resolutionCell(item)` igual que las otras dos bandejas, con
  `resolveResolutionIdentity` — el Exento, no el interno.
- El botón de Excel se deja **deshabilitado con su razón** hasta la F4, en lugar
  de omitirlo: la bandeja se entrega completa y se ve que falta el archivo.

### F1.5 Ruta y navegación

```vue
<router>
  { path: '/prestacion-de-servicios/pagos/finanzas', name: 'services-provision-payments-finance' }
</router>
```

- `config/menuChildren/servicesProvisionPayments.js`: tercera entrada con
  `guardian: ['provision-payment-read-waiting']`, igual que la de revisión.
- `config/menu.js` no cambia: el permiso ya está en la lista del módulo.
- `pages/index.vue`: tarjeta de atajo bajo `canReviewPayments`, que ya evalúa el
  mismo permiso. Su texto va al nodo `dashboard` del catálogo.

### F1.6 Verificación de la fase

```bash
node utils/validateDu288Ui.js && npm test && npx eslint --ext .js,.vue pages/services-provision/payments/finance utils/servicesProvisionDgdpReviewFilter.js && npx nuxt build
```

La página nueva **debe agregarse a la lista de `utils/validateDu288Ui.js`**: el
gate recorre una lista explícita, así que un archivo que no esté ahí no se
valida. Es exactamente como la vista de revisión quedó fuera cuando se creó.

---

## F2 · El detalle

No se crea ninguna vista. La ruta
`payments/review/_staffProvisionId/_installmentNumber.vue` ya muestra lo pedido y
ya es de solo lectura con estado 4, porque `RESOLVABLE_STATUS = [2]`.

### F2.1 Volver a donde se entró

Hoy `backRoute` apunta siempre a la bandeja de revisión:

```js
backRoute() {
  return { name: 'services-provision-payments-review', query: { estado: String(this.listedStatus) } }
}
```

Pasa a resolverse por el origen, con `query.origen` en el enlace de la bandeja
nueva y la revisión como valor por omisión. El rótulo del botón sale del mismo
origen. Es un cambio de dos computados; el contenido de la vista no se toca.

### F2.2 Lo que hay que comprobar, no construir

- Que la pestaña de respaldo no ofrezca cargar ni borrar documentos con estado 4.
  La sección de meses ya se cuida con `editable`; el respaldo hay que mirarlo.
- Que los tres tableros de la pestaña `Cuota` carguen con estado 4. Las dos PA de
  meses aceptan `(2, 3, 4, 8, 10, 11)`, así que deberían; es verificación.

---

## F3 · «Marcar como enviada a Finanzas»

Es la única fase que atraviesa todas las capas. Se puede implementar antes del
Excel porque no depende de ninguna decisión abierta.

### F3.1 PA nueva: `sg_epaguSecgen04`

Por qué nueva y no ampliar `sg_epaguSecgen03`: esa PA registra la **decisión**
de visación —destinos 3, 4 o 10, solo desde el estado 2—. Una cuota aprobada no
entra, y ampliarla mezclaría dos actos en un PA cuyo nombre y validaciones
hablan de otra cosa. Es además la regla del paquete: crear uno nuevo.

Contrato:

```
@rut_person  char(9)  obligatorio   RUT del revisor, del token
@id_funprse  int      obligatorio
@nro_cuota   tinyint  obligatorio
```

Cuerpo, en este orden:

1. Validar parámetros; sin ellos, `select '…' as msg` y `return`.
2. Normalizar el RUT a 9 con ceros, como las PA hermanas.
3. **La misma validación de asignación DGDP** que llevan las otras 13 PA:
   contrato vigente en `sisper_db..sp_cont` y `sp_orde.cod_organi = 696` con
   `vigente = 'S'`. Copiar el bloque tal cual: que la autorización no dependa
   solo del backend es parte del estándar del paquete.
4. Exigir `cod_estcuo = 4`. Desde cualquier otro estado, `msg` y `return`. Esto
   es lo que hace la acción **idempotente**: una segunda petición sobre una
   cuota ya enviada no la vuelve a enviar.
5. `begin tran`:
   - `sg_epag.cod_estcuo = 8` donde `id_funprse`/`nro_cuota` y `cod_estcuo = 4`.
   - `sg_fume`: los meses de esa cuota —los que `sg_dpag` asocia— que estén en
     `cod_estfum = 2` pasan a `3`, con `fec_envrem = getdate()` y `mto_realpa`
     igual al neto del mes (`mto_apagar − mto_deslic − mto_dessg`).
   - Chequeo de `@@transtate` entre pasos, como `sg_epaguSecgen03`.
6. Devolver el contrato de mutación del §6: `select 1 as status` en el éxito,
   solo `msg` en el error. El repositorio lo valida con `assertMutationResult`.

Entregables: `sg_epaguSecgen04.sql` y `sg_epaguSecgen04.txt` idénticos, en
`cambios_pa/sg_epag/`.

**Actualizar `cambios_pa/sg_epag/README.md`**: fila nueva en la tabla de PA y el
diagrama de estados con `marcar enviada → 8 Enviada remuneraciones` y
`2 → 3 Enviada a pago`. Al pasar, ese README tiene dos filas desactualizadas —
dice que `sg_epagsSecgen03/04` admiten solo el estado 2 cuando el cuerpo acepta
`(2, 3, 4, 8, 10, 11)`, y el diagrama todavía describe el rechazo liberando
meses, que cambió el 26-10-2026.

### F3.2 Consulta

En `db-assets/sybase-assets/queries/service-provision-payment/service-provision-payment.ts`:

```ts
markInstallmentSentToPayroll: `
  EXECUTE secgen_db.Analisis2.sg_epaguSecgen04
      @rut_person='{{ rut_person }}',
      @id_funprse={{ id_funprse }},
      @nro_cuota={{ nro_cuota }}
`,
```

### F3.3 Repositorio

`markInstallmentsSentToPayroll(rutRevisor, items)` en
`service-provision-payment-procedures.repository.ts`, con
`resolveDgdpInstallment` como molde:

- Una conexión para todo el lote, no una por cuota: `connect()` una vez, bucle,
  `disconnect()` en el `finally`.
- Una ejecución del PA por cuota, cada una atómica. El resultado es por cuota:
  `{ staffProvisionId, installmentNumber, sent, message? }`. Un `msg` de una
  cuota no cancela las demás.
- `this.assertMutationResult` por ítem. Su error se captura **solo cuando es
  422**, que es lo que el contrato de mutación produce con una fila `msg`:
  cualquier otro error —la conexión, por ejemplo— aborta el lote, porque no
  habla de esa cuota y convertirlo en ochenta «no enviada» ocultaría la falla.
- Normalizar el RUT con `this.normalizeRut`, y nunca registrarlo en los logs.
- Descartar las cuotas repetidas del cuerpo antes de ejecutar: la segunda
  pasada devolvería «ya se envió» y dejaría un resultado contradictorio para
  una cuota que sí se envió.
- Tope de 500 cuotas por llamada (`SENT_TO_PAYROLL_MAX_ITEMS`): un período
  completo cabe de sobra, y el límite evita que una petición mal armada
  mantenga la conexión abierta ejecutando el PA miles de veces.

Por qué el lote va acá y no en el frontend: marcar 80 cuotas con 80 llamadas HTTP
abriría 80 conexiones y revalidaría la unidad 80 veces. Una llamada, una
conexión, 80 ejecuciones del PA.

### F3.4 Controlador

```
POST /requests/service-provision/payments/dgdp/installments/sent-to-payroll
```

- Cuerpo: `{ installments: [{ staffProvisionId, installmentNumber }] }`, con
  modelo propio (`Du288PaymentSentToPayrollRequest`, con
  `Du288PaymentSentToPayrollItem`) y tope de ítems por llamada.
- **`assertCanResolveDgdpPayment`**, no `assertIsDgdpPaymentReviewer`: es una
  escritura, y el permiso de lectura no debe cambiar estados. Es la separación
  que ya tienen las otras seis escrituras del controlador.
- Respuesta: el informe por cuota, para que la pantalla diga qué se marcó y qué
  no. No un booleano: en un lote el «éxito» parcial es el caso normal.

### F3.5 Store

`markInstallmentsSentToPayroll({ installments })` en
`store/service-provision-payments.js`. Devuelve el informe por cuota tal cual;
recargar la bandeja con `fetchDgdpInstallments({ statusCode: 4 })` es trabajo de
la pantalla, no del store, para que la acción no fuerce una consulta cuando la
vista decide mostrar antes el resumen de lo marcado.

### F3.6 Pantalla

- La acción vive **en la bandeja**, junto a la descarga, no en el detalle: lo que
  se envía es el lote del período, y así el detalle sigue sin escrituras.
- Modal de confirmación —`pds-ui-modal`, centrado, §3.1 y §11— que diga cuántas
  cuotas, de qué período, por qué monto total, y que **desde el sistema no se
  deshace**: el camino de vuelta es el estado 11, que DGDP registra a mano
  cuando Finanzas devuelve.
- Al terminar, resumen de lo marcado y lo que falló, con el motivo que devolvió
  el PA.
- Filtro adicional para consultar las ya enviadas (estado 8). El PA de la
  bandeja ya acepta el 8, así que es una opción más, no una consulta nueva.

### F3.7 Verificación

Backend:

```bash
npm run build && npx lb-mocha -r ./test-setup.js "dist/__tests__/unit/**/*.js"
```

Pruebas unitarias del lote, sin Sybase, en
`src/__tests__/unit/service-provision-payment-sent-to-payroll.unit.ts`
(8 casos): una conexión para el lote y una ejecución por cuota, una cuota con
`msg` que no detiene el resto, cuota repetida, lista vacía, identificador
inválido, error de conexión que aborta y cierra, lote sobre el tope, y que el
RUT del revisor no aparezca en ningún resultado. Suite completa: 247 pruebas.

**Contra Sybase no se puede verificar en este entorno** —no hay cliente ni
contenedor—. Lo que hay que probar en certificación:

1. Cuota en 4 → queda en 8 y sus meses en 3 con `fec_envrem` y `mto_realpa`.
2. La misma cuota otra vez → `msg`, sin segundo cambio.
3. Cuota en 2 o en 10 → `msg`, sin cambios.
4. Usuario fuera de la unidad 696 → `msg` de asignación.
5. Un mes ya en 3 dentro de una cuota en 4 → no se vuelve a escribir.
6. Que la cuota en 8 siga visible filtrando por ese estado.

---

## F0 · El saldo ya no bloquea la aprobación DGDP

Corregido el 28-10-2026, y es **precondición de toda esta bandeja**: sin
aprobaciones no hay cuotas en estado 4 y la bandeja de Finanzas llega vacía.

El detalle DGDP revalidaba la batería normativa con `balanceBlocks: true` fijo
en el código, así que «Centro de costo sin saldo» y «Centro de costo fuera de
DU09» salían como `error` bloqueante y el botón Aprobar quedaba deshabilitado.
El resto del módulo no lo hace: el `INTERRUPTOR-DU09`
(`BALANCE_VALIDATION_BLOCKS_SUBMISSION` en el store, `BALANCE_BLOCKS_SUBMISSION`
en el controlador) está **apagado desde el 14-10-2026** mientras los centros de
costo de prueba no tengan cargadas sus marcas presupuestarias.

La misma pantalla se contradecía: la sección de validaciones recibía
`balanceBlocksSubmission` —el interruptor, apagado— y mostraba el aviso de que
el saldo no bloquea, con el botón Aprobar deshabilitado al lado.

La corrección es una línea: la revalidación toma el interruptor en vez del
literal. El saldo sigue a la vista como advertencia amarilla, que es lo que el
interruptor dice que debe pasar.

**Lo que sigue bloqueando Aprobar**, y no se tocó porque son impedimentos
reales: contrato no vigente o pendiente, inhabilidad del cargo, asignación
inhábil, tope faltante o excedido, centro de costo cerrado y falta de respaldo
justificativo. Si alguno de estos también debe dejar de bloquear, es otra
decisión y hay que decirlo: no es el interruptor del saldo.

**El backend no participaba.** La compuerta de saldo
(`assertCostCenterBalanceCompliance`) solo corre en `submitInstallment`, el
envío del jefe de proyecto, y ya respetaba el interruptor. El endpoint de
resolución DGDP nunca validó saldo, así que no hubo cambio de backend.

**Esto es transitorio, no la regla definitiva.** El saldo deja de bloquear solo
mientras los centros de costo de prueba no tengan sus marcas presupuestarias: a
master se entra con **todas** las validaciones bloqueando. Al conmutar el punto 1
del `INTERRUPTOR-DU09` la aprobación DGDP vuelve a bloquear junto con el envío,
porque desde este cambio las dos leen el mismo interruptor. Lo que ese
interruptor **no** arregla es que el endpoint de la decisión DGDP no tiene
compuerta normativa: está anotado en `INTERRUPTOR-DU09.md` y como paso 8 del
checklist de certificación.

### F0.1 · El modal de confirmación, calcado del envío del solicitante

Consecuencia directa de lo anterior: si el saldo ya no impide aprobar, el
resumen tiene que decir lo que antes decía el botón deshabilitado. El modal
traía tres líneas —decisión, nombre y una cifra—, así que se aprobaba sin ver
el mes de pago ni la resolución, los dos datos con los que Finanzas cuadra el
pago.

Las dos pantallas confirman el mismo tipo de acto sobre la misma cuota, así que
ahora se leen igual. El modal DGDP pasó a ser
`components/services-provision/payments/Du288PaymentDecisionModal.vue`, con la
misma estructura de bloques que `Du288InstallmentSubmitModal`:

| Bloque | Qué muestra |
| :--- | :--- |
| Aviso de rechazo | solo al rechazar: que la decisión no tiene vuelta atrás |
| Antecedentes de la cuota | funcionario con RUT, solicitud, **Resolución Exenta con su año**, centro de costo con código, actividad |
| Cifra destacada | el neto en grande, con la cuota «2 de 3» como insignia y la cobertura debajo; luego las celdas de monto, límite y saldo que detalla §F0.3 |
| Meses de la cuota | una fila por mes con su neto, y sus descuentos cuando existen |
| Validaciones | la fila de chips con el estado de cada validación; el aviso ámbar solo al aprobar (§F0.3) |
| Observación | solo al observar o rechazar, con su contador de 255 |

Cuatro reglas que el modal conserva o incorpora:

- **Al rechazar la cifra cambia de rótulo, no de valor**: es el monto que queda
  bloqueado, no plata por pagar. Mismo criterio que corrigió el «A pagar
  fantasma» de la bandeja.
- **El descuento aparece solo cuando existe.** En cero repetiría la celda
  anterior y haría dudar de cuál es la cifra que manda.
- **El tope se marca cuando se supera**, sin acotar a cero: una cuota sobre el
  tope tiene que verse que lo supera, no leerse como que justo lo agota.
- **Las advertencias van solo al aprobar.** Es la decisión que deja la plata en
  camino; las bloqueantes no hacen falta ahí porque con una sola de ellas no se
  llega al modal.

**Por qué un componente y no estilos pegados en la página.** El modal estaba
inline en una página de 1.500 líneas y su CSS habría tenido que duplicar el del
modal del solicitante, que es `scoped`. Como componente, la página queda 127
líneas más corta, el modal es reutilizable desde la bandeja de Finanzas si
alguna vez confirma algo equivalente, y los estilos propios usan los tokens
`--pds-du288-*` que ya existen.

**Qué se quitó después de la primera versión.** El bloque «Qué efecto tiene»
repetía, con relleno de color, la misma frase que la página ya muestra al lado
de los botones (`decision.note`). Además pintaba de verde una acción que
todavía no ocurrió, y en el estándar el color Éxito significa «resultado válido
o confirmado» (§5.4), no «botón importante». Quedó un solo aviso, al rechazar:
es la única decisión sin vuelta atrás y eso hay que leerlo antes de confirmar.
Con eso salieron de `lang/es/pds.js` las claves `effectApprove` y
`effectObserve`, que ya no tenían lector; `effectReject` se mantiene.

### F0.2 · Colores: un solo origen para los dos flujos

El mismo recorrido —solicitante que envía, DGDP que aprueba— se veía con dos
paletas. El estándar es explícito: «Los colores DEBEN provenir de variables
`--pds-du288-*`. No se permiten colores hexadecimales nuevos en componentes si
el significado ya tiene token» (§5.4). Lo que había:

| Incongruencia | Dónde | Qué se hizo |
| :--- | :--- | :--- |
| Dos ámbar distintos para la misma advertencia (`#fffbeb`/`#fef3c7`/`#92400e` contra los tokens `warning-*`) | modal del solicitante, tarjetas de día de ejecución | todo pasa a `--pds-du288-warning-soft` / `-warning-dark`, con borde `rgba(249, 143, 21, 0.35)` |
| Dos verdes para «ejecutado» **en el mismo archivo** (`#f0fdf4` en la tarjeta, `--pds-du288-success-soft` en la celda de calendario) | `Du288PaymentExecutionSection` | los dos usan el token |
| Grises sueltos `#f8fafc`, `#f8f9fa`, `#f1f5f9`, que es el valor exacto de `--pds-du288-soft` | seis componentes | token |
| `var(--pds-du288-surface-alt, #f8f9fa)` y `var(--pds-du288-title, #1e293b)` / `#2c3e50` | tres componentes | **esos dos tokens no existen**: el fallback estaba vivo y pintaba un gris distinto en cada uso. Pasan a `--pds-du288-soft` y `--pds-du288-text` |
| 49 `var(--token, #hex)` cuyo respaldo no coincidía con el token (`warning-dark` respaldaba `#d97706` contra el real `#946200`) | módulo de pagos | se quitó el respaldo: la hoja se carga en `nuxt.config` y los tokens viven en `:root`, así que nunca se usaba y solo documentaba un color falso |
| Insignia de la cuota con `badge badge-primary` de Bootstrap, azul propio | modal del solicitante | `pds-ui-mini-chip`, la misma que usa el modal DGDP |
| Mayúsculas completas en rótulos y encabezados, y tamaños en `rem` fuera de la escala (`0.72rem`, `0.78rem`, `1.6rem`) | modal del solicitante | formato oración y tokens de tipografía (§5.1); el monto queda en 24 px y baja a 20 px bajo 576 px |
| Modal del solicitante sin `scrollable` | `Du288InstallmentSubmitModal` | se agregó: §11 pide scroll interno en contenido extenso |

Queda **un** color sin token a propósito: el violeta de «marca de reloj
control» (`#ede9fe`/`#5b21b6` en las marcas de mes, `#f5f3ff`/`#ddd6fe`/`#6366f1`
en las tarjetas de ejecución). No es una infracción —§5.4 prohíbe hexadecimales
nuevos cuando el significado *ya* tiene token, y este no lo tiene—, pero es una
cuarta categoría de la leyenda de días que conviene resolver: o se le define un
token con nombre propio en `pds-du288.css`, o se funde con Información y se
pierde la distinción contra «comprometido». Es decisión del dueño del estándar,
no del cambio de pagos, así que se dejó marcada.

El estilo del modal del solicitante sí se tocó, entonces, contra lo que decía
este documento: solo colores, radios, tamaños y el `scrollable`. Ni una regla de
negocio, ni un dato de los que muestra, ni nada del formulario de creación de
cuotas.

**Lo que queda abierto, y por qué no se hizo acá.** Fuera de los dos modales
siguen 21 `font-size` en `rem` fuera de la escala y una regla de mayúsculas
completas en `Du288PaymentExecutionSection`. Son infracciones del §5.1, pero
corregirlas cambia el aspecto de pantallas de creación de cuotas ya aprobadas,
y eso es una pasada de tipografía con su propia revisión visual, no parte de la
bandeja de Finanzas. Se deja listado para decidirlo aparte.

---

### F0.3 · Paridad de datos: los dos modales contra el Excel de Finanzas

Criterio acordado: **lo que se confirma en pantalla es lo que va a salir en el
archivo de traspaso**. No «el mismo modal», sino el mismo juego de datos, más
lo propio de cada etapa. El archivo tiene 13 columnas (§4 de
`plan_bandeja_aprobadas_finanzas.md`) y de ahí sale qué tiene que estar:

| Columna del Excel | Dato en los dos modales | Estado |
| :--- | :--- | :--- |
| `Nombre`, `RUT` | funcionario con RUT | ya estaba en los dos |
| `Monto` | **monto neto aprobado** | **era la incongruencia principal** |
| `CC` | centro de costo con código | ya estaba |
| `Nº Resol`, `Año Resol` | Resolución Exenta con año | se agregó al modal de envío |
| `Fec_inicio`, `Fec_Termino` | períodos incluidos (mes–mes) | se muestra el rango de períodos, no las fechas |
| `Corr` | correlativo de fila del archivo | no corresponde a la cuota |
| `Cod_Unidad Res` | constante `05000000` | no se muestra: es constante |
| `Código Haber` | — | `ss_asds.num_cuenta` (confirmado por el usuario) |
| `Item` | — | `sg_fups.cod_sitm`, contrastado con `ss_ccas.cod_item` (confirmado) |
| `Porcentaje CC` | — | `ss_ccas.valor_asig / ss_asds.valor × 100` (confirmado) |

**La incongruencia principal: el solicitante confirmaba el bruto.** El modal de
envío destacaba la suma de `amountToPay`; el de DGDP destaca el neto. Para la
misma cuota, las dos pantallas mostraban dos cifras distintas como «la» cifra.
Y el propio formulario de creación ya calcula `selectedDeductions` y
`selectedNet` y se los muestra al solicitante: el modal volvía al bruto
después. Ahora los dos destacan el **monto neto aprobado**, con el mismo
rótulo, y el bruto baja a la celda «total solicitado». Es el monto que el plan
fija para el archivo: «el monto a exportar es el neto aprobado, descontando
licencias y ausencias».

**Licencias y ausencias van separadas.** Los dos modales sumaban los descuentos
en una sola cifra, pero el neto del archivo sale de las dos y los campos
siempre estuvieron separados (`medicalLeaveDeduction`, `unpaidLeaveDeduction`).
Ahora se muestran como celdas distintas en el total y bajo el neto de cada mes,
cada una solo cuando existe.

**Datos de cuota que faltaban en DGDP.** El modal de envío mostraba tope por
cuota, espacio en la cuota, bloqueado por rechazo, saldo disponible y saldo
después; el de DGDP, ninguno. Desde que el saldo dejó de bloquear la aprobación
(§F0) el revisor puede aprobar sin saldo, así que son justo las celdas que
necesita. Se calculan con el mismo helper que usa el envío,
`resolveDraftInstallmentBalance`: la cuota ya enviada está dentro de lo
consumido, y el helper la devuelve para mostrar el saldo sin ella y, en
`after`, el saldo con ella. No hay un cálculo nuevo ni un segundo criterio de
saldo.

**Validaciones como etiquetas, en los dos.** Antes el envío las dejaba fuera
del modal —estaban al lado, en la página— y DGDP mostraba solo las **no**
bloqueantes, como lista de texto. Ahora los dos llevan la fila completa de
chips con su estado: verde lo cumplido, ámbar lo revisable, rojo lo que
bloquea, con el mismo par de clases `payment-chip-*` que usa el formulario de
la cuota, para que una etiqueta no cambie de color al pasar de una pantalla a
otra. El aviso ámbar quedó reducido a su frase, bajo los chips y solo al
aprobar.

**Lo que no se igualó, a propósito**, porque es propio de cada acto: «se envía a
DGDP» y el aviso de que la cuota deja de ser editable (envío); el aviso de
rechazo, la observación con su contador de 255 y el botón por decisión
(revisión). El respaldo con botón «ver PDF» queda solo en el envío: en la
revisión el PDF tiene su propia pestaña y el estado del respaldo ya viaja como
chip de validación.

#### Lo que apareció al mirar las dos pantallas lado a lado

Ocho diferencias que no eran de datos sino de cómo se escribía el mismo dato.
Seis corregidas:

| Qué pasaba | Dónde | Qué se hizo |
| :--- | :--- | :--- |
| **El RUT se mostraba en crudo**, `087962717`, con el relleno de ceros del PA | los dos modales | `runFormatToRequest` → `8.796.271-7` |
| **El formateador de las bandejas borraba el dígito verificador**: `replace(/\D/g, '')` se come la K, así que `06706447K` se mostraba como `6.706.447` —otro RUT— | las tres bandejas de pagos, con tres copias locales idénticas | una sola implementación en `utils/formatters`, con pruebas |
| Licencia y permiso **se leían pegados** bajo el neto del mes | revisión DGDP | `display: block` (el modal de envío ya lo tenía) |
| **«Total solicitado» repetía el neto** cuando no había descuentos | los dos | se muestra solo si hay descuentos, mismo criterio que ya tenían las celdas de licencia y permiso |
| El mes de pago se llamaba **«Se paga en»** en una pantalla y **«Mes de pago»** en la otra | envío | «Mes de pago» en las dos |
| La solicitud era **«Prestación: Solicitud N° 208»** contra **«Solicitud: N° 211»** | revisión DGDP | rótulo «Solicitud», valor «N° 208» |
| El centro de costo era **`NOMBRE (9010.5)`** contra **`NOMBRE · 9010.36`** | revisión DGDP | el formato con punto medio, el de la vista del solicitante |
| Los títulos de tarjeta salían en **MAYÚSCULAS** | los dos | `app.css` pone en mayúsculas todos los `h1`–`h6` de la aplicación; se anula en los dos modales, que es lo que pide el §5.1 |

Y el tope por cuota no aparecía en la revisión: tomaba `installment.monthlyCap`
sin el respaldo de la ficha del funcionario que la propia página ya resuelve en
`modalStaff.topValidation.appliedCap`. Ahora usa ese.

**Dos que no se tocaron, porque exceden estas pantallas:**

1. **Nombres con `Ñ` llegan rotos** desde el backend: la captura muestra
   «SERGIO HERIBERTO DELGADO ZU?IGA». No es del modal —el dato llega así— y hay
   que resolverlo en la codificación de la respuesta de Sybase, no maquillarlo
   en la vista.
2. **Las etiquetas de campo van en mayúsculas completas en toda la aplicación**
   (`.pds-ui-read-label` y compañía, seis reglas de `pds-du288.css`, más
   `h1`–`h6` en `app.css`). El §5.1 del estándar pide formato oración. Cambiarlo
   restyliza todas las pantallas DU288, así que es decisión del dueño del
   estándar y no de este cambio.

**Pendiente que esto deja a la vista:** `Fec_inicio`/`Fec_Termino` no se
muestran como fechas porque la regla para derivarlas sigue abierta —decisión
pendiente 1 del plan, la reconciliación del mes de proceso con el tramo
`01-09` a `31-12` del ejemplo—. Mostrar fechas calculadas con una regla no
cerrada sería inventar el dato. Cuando se cierre, las dos pantallas deberían
mostrar el mismo par de fechas que va al archivo.

---

### F0.4 · El máximo de cuotas, siempre a la vista

Regla: **en toda pantalla donde aparezca el número de una cuota debe aparecer
el máximo decretado para la prestación.** Siete lugares lo escribían por su
cuenta y cinco lo omitían:

| Dónde | Decía | Ahora |
| :--- | :--- | :--- |
| Listado de cuotas de la solicitud | «Cuota 1», sin máximo | «Cuota 1 de 3» |
| Modal de envío | «Cuota 1» si el total no venía | siempre con el total |
| Resumen de la cuota (solicitud) | «Cuota única (1 de 1)» con una sola cuota | «Cuota 1 de 1» |
| Pestaña de meses | igual que el anterior | igual que el anterior |
| Título de la cuota en revisión DGDP | «Cuota 2» si el decretado era 1 | siempre con el total |
| Ficha de antecedentes DGDP | dos ramas escritas a mano | una sola |
| Bandejas de revisión y Finanzas | «de Sin información» | «total de cuotas no informado» |

El punto que importa: **sin el dato y «prestación de una sola cuota» se leían
igual.** Las dos terminaban en «Cuota 1», y quien leía suponía lo segundo.
Ahora el total ausente se declara ausente.

Queda un solo origen: `formatInstallmentOfTotal` en
`utils/services-provision/normative/formatters.js`, con el vocabulario en
`payments.installmentLabel`, y cinco pruebas que fijan la regla —incluida la
que exige que dato ausente y cuota única **no** se lean igual—.

`authorized` es lo que decretó la resolución (`authorizedInstallments`), no
cuántas se enviaron ni cuántas se pueden declarar: eso último es
`getMaxDeclarableInstallments`, que es la regla del formulario y responde otra
pregunta.

### F0.5 · Lo que faltaba para decidir

- **Las marcas del mes**, en los dos modales. `monthRows` ya traía las cuatro
  que entrega el PA —licencia médica, sin goce, inhabilidad, centro de costo
  cerrado— y ninguno de los dos modales las mostraba: se veía el descuento sin
  su causa, y una inhabilidad o un centro de costo cerrado **no** se deducen
  mirando el monto. Van como chips bajo el período del mes. El vocabulario
  quedó en `payments.monthFlags`, que ahora leen la pestaña de meses y los dos
  modales.
- **La observación anterior**, en el modal de DGDP. La cuota puede ir y volver
  varias veces; el motivo con que se devolvió ya estaba en la pestaña, pero no
  en el modal donde se confirma. Aprobar sin comprobar si eso se subsanó es
  exactamente el error que la devolución quería evitar. Se muestra con su fecha
  y autor, en tono de información y no de advertencia: que la cuota ya volvió
  una vez es contexto, no un problema de esta decisión.
- **El anclaje del saldo**, en los dos. «Saldo disponible $12.024.252» no dice
  si es mucho o nada. Ahora va en su propia tarjeta —«Saldo de la resolución»—
  con el monto autorizado, lo pagado, lo en trámite, lo bloqueado por rechazo y
  el saldo antes y después de esta cuota. Separarlo de la grilla de la cuota no
  es cosmética: son dos niveles distintos —la cuota y la prestación— y
  mezclados en una sola grilla de hasta doce celdas se leían como uno solo.
- **Tipo de monto**, en los dos. Fijo o variable cambia qué se está aprobando:
  en monto variable la cifra del mes se define al pagar, así que el neto del
  resumen no es una cifra cerrada.
- **Modalidad de jornada**, en los dos. Define si la prestación exigía
  compensación —fuera de jornada no se compensa—, y hasta ahora eso solo se
  infería del chip de compensación, que no dice por qué.

No se agregó la antigüedad de la cuota (fecha de envío y días en espera):
sirve para priorizar en la bandeja, que es donde está, y no para decidir con el
modal abierto.

---

## F4 · El Excel

Fuentes confirmadas por el usuario el 28-10-2026:

- `Código Haber`: `ss_asds.num_cuenta`.
- `Item`: `sg_fups.cod_sitm`, contrastado con `ss_ccas.cod_item`.
- `Porcentaje CC`: `ss_ccas.valor_asig / ss_asds.valor × 100`.
- Grano: una fila por mes/asignación SISPER.
- `Nº Resol` es el Exento (`num_resolu_ext`) con su `Año Resol`, nunca el
  consecutivo interno.

La consulta dedicada debe devolver los meses/asignados de las cuotas
seleccionadas en una lectura, con estos campos SISPER y neto aprobado por mes.
El archivo conserva las 13 columnas indicadas en el plan y el RUT como texto.
Cuando `ss_ccas` tiene varias filas para una asignación SISPER, se genera una
fila por cada centro de costo. El monto exportado se prorratea por el porcentaje
de esa línea; el residuo de redondeo se asigna a la última línea, de modo que la
suma coincida con el neto aprobado de la cuota. Las fechas SISPER corresponden
al mes de pago de `sg_epag`, y el neto es la suma neta de todos los meses de la
cuota.

---

## Orden de entrega

F1 y F2 son frontend y se pueden entregar juntas: dejan la bandeja y el detalle
utilizables, sin tocar base de datos. F3 es la que necesita certificación del PA,
así que va en su propia entrega. F4 queda esperando decisiones.

Si hay que elegir una sola, **F3 antes que F1**: es la que evita que la misma
cuota se exporte y se pague dos veces. Pero sin F1 no hay dónde ponerle el
botón, así que entregar F1+F2 primero y F3 enseguida es el orden que menos
trabajo repite.

**Lo que se hizo el 28-10-2026** fue F3, F1 y F2, en ese orden, por lo que pedía
el encargo: antes de la bandeja, que DGDP pueda cambiar el estado de una cuota
aprobada. Aprobar ya existía (`sg_epaguSecgen03`, destino 4 desde el 2); lo que
no existía era ninguna salida del 4. Con `sg_epaguSecgen04` el estado 4 deja de
ser terminal, y sobre eso la bandeja tiene de dónde partir y a dónde llegar.

Verificación ejecutada: backend `npm run build` y 247 pruebas unitarias;
frontend `node utils/validateDu288Ui.js` (52 archivos), `npm test`
(15 archivos), `npx eslint` sin hallazgos nuevos y `npx nuxt build` con la ruta
`/prestacion-de-servicios/pagos/finanzas` generada. **Nada se ejecutó contra
Sybase**: la PA nueva está sin probar en base de datos y su lista de
comprobaciones de certificación está en F3.7.

F2.2 queda comprobado y no construido, como decía el plan:
`Du288PaymentDocumentTab` no tiene props ni eventos de carga ni de borrado —solo
ver, abrir en pestaña nueva y descargar—, así que la pestaña de respaldo no
ofrece escrituras en ningún estado, no solo en el 4.

De F2 queda sin hacer una sola cosa, a propósito: **el encabezado del detalle no
cambia según el origen**. «Antecedentes enviados a visación DGDP» es cierto en
los dos caminos —la cuota se envió a visación, y por eso está aprobada—, y el
estado de la cuota ya está a la vista en la propia pantalla. Un subtítulo
distinto por camino habría hecho que la misma cuota se leyera distinto según
desde dónde se abrió, sin agregar un dato. Lo que sí distingue el origen es el
botón de volver, que es lo que el usuario necesita que cambie.

---

## F5 · Ingreso a SISPER: contraste contra el alcance del 29-10-2026

El alcance acordado el 29-10 agrega el paso que faltaba: Finanzas no solo
descarga un archivo, también puede ingresar los registros a SISPER desde el
sistema, y los dos caminos deben partir de los mismos datos. Esta sección
contrasta ese alcance con lo que hay escrito hoy. No autoriza ningún cambio.

### F5.1 Lo que ya está escrito

| Pieza | Estado |
| :--- | :--- |
| Estados de la cuota y sus transiciones | `sg_epaguSecgen03` (2 → 3/4/10), `sg_epaguSecgen04` (4 → 8), `sg_epaguSecgen05` (4 → 2 con motivo). Nada ejecutado en ASE. |
| Bandeja de Finanzas | Página, filtros, selección múltiple, totales, detalle de solo lectura y «Registrar envío a Finanzas». |
| Excel de 13 columnas | `sg_epagsSecgen05`, endpoint `finance-excel-rows` y descarga con guardas de ítem, porcentajes y período. |
| Los tres PA de SISPER | `sg_resliSecgen01`, `sg_asdiSecgen01`, `sg_ccaiSecgen01` escritos en `cambios_pa/pa_externos`. |
| Montos y descuentos de la visación | `sg_fume.mto_deslic` / `mto_dessg` por mes; el cierre deja `sg_epag.mto_realpa`. |

Lo que el paso 2 del plan pedía —guardar el pago aprobado en DGDP— ya ocurre.

### F5.2 El Excel apunta en la dirección contraria

`sg_epagsSecgen05` resuelve las columnas SISPER con
`inner join sisper_db..ss_asds`, exigiendo además que la asignación cubra desde
el primer hasta el último día del mes de pago de `sg_epag`. Es decir: **hoy el
archivo exporta asignaciones que ya existen en SISPER**. Una cuota aprobada sin
asignación no produce ninguna fila, y el caso del pago vigente de varios meses
(01/09 a 31/12) no calza con la condición de mes exacto.

El alcance nuevo pide lo inverso: preparar desde SG los registros que **deben**
ingresarse. La consulta actual sirve para conciliar lo ya ingresado, no para
generarlo. Hay que decidir si se reescribe contra SG o si convive una segunda
lectura, y en ese caso cuál alimenta la bandeja.

### F5.3 Lo que no existe todavía

1. **Preparación compartida de registros** (paso 3). No hay ninguna lista de
   registros preparados: ni atraso ni pago vigente. El Excel se arma de lo que
   SISPER ya tiene y el botón no existe, así que hoy no hay un origen común que
   las dos salidas puedan compartir.
2. **Botón «Agregar a SISPER» e integración** (paso 5). Los tres wrapper no se
   invocan desde ningún TypeScript: falta consulta, repositorio, servicio,
   controlador, store y pantalla. Atención al límite que su README ya declara:
   cada PA confirma su propia inserción y **no hay transacción común**, así que
   un fallo en `sg_ccaiSecgen01` deja una asignación sin centro de costo. La
   recuperación de ese parcial es responsabilidad del orquestador, que debe
   reusar el `cod_asign` ya creado en lugar de insertar otra asignación.
3. **Dónde guardar la trazabilidad** (paso 6). `sg_epag` tiene diez columnas y
   ninguna para `cod_asign`; no existe tabla puente cuota → asignación SISPER →
   centros de costo. Sin ella no se puede responder «¿esta cuota ya tiene
   asignación vinculada?», y la detección de duplicados queda reducida al cruce
   por funcionario, resolución y mes, que el propio análisis descarta como
   identificador seguro. **Requiere tabla nueva**: es cambio de esquema, no solo
   un PA.
4. **Separar exportado, registrado y pagado** (paso 7). `sg_ecuo` tiene
   1, 2, 3, 4, 8, 10 y 11. El 8 «Enviada remuneraciones» es un solo valor para
   los tres hechos. Descargar el Excel no deja marca alguna y
   `sg_epaguSecgen04` marca 8 directamente.
5. **El cálculo del atraso.** Los datos están —`sg_fume.ano_ejec` / `mes_ejec`
   y `sg_epag.ano_pago` / `mes_pago`—, pero la regla no está escrita en ninguna
   capa, la bandeja no tiene columna que distinga atraso de pago vigente, y el
   período que Finanzas procesa no es una entrada explícita: el filtro «Pago
   desde / hasta» es un rango de búsqueda, no el mes de proceso contra el cual
   se compara.
6. **El período de varios meses en `sg_asdiSecgen01`.** El PA exige que el
   período abarque desde el primer hasta el último día del **mismo mes**, y
   rechaza repetir período para la misma persona y resolución. Si se confirma el
   registro recurrente hay que ampliarlo. Es un PA propio de este paquete, así
   que se puede ampliar sin crear otro; lo que cambia con el rango largo es la
   validación de duplicado, que dejaría de ser comparable mes a mes.

### F5.4 Detalles del archivo que ya se pueden corregir

- Las fechas se exportan como texto `dd-mm-yyyy` (`excelDate` en la página de
  Finanzas). El acuerdo pide fechas reales de Excel para evitar la ambigüedad
  mes/día del ejemplo.
- `Nº Resol` sale solo como número. El ejemplo entregado muestra `2379/2026`,
  con el año incluido en la misma celda además de la columna `Año Resol`.

### F5.5 Lo único que impide cerrar la regla de fechas

¿La segunda fila del ejemplo —$995.554 desde 01/09 hasta 31/12— deja programado
ese monto en cada mes, septiembre incluido? De esa respuesta dependen tres
cosas: el cálculo del atraso sin duplicar el primer mes, la ampliación de
`sg_asdiSecgen01` y el grano de las filas del archivo. Mientras no esté
respondida, los puntos 1, 5 y 6 de F5.3 no se pueden programar sin adivinar.

### F5.6 Decisión del 29-10-2026: los PA generan el registro y la resolución se lee

Acuerdo: el ingreso a SISPER se hace con los PA, el mismo origen alimenta el
Excel, y **la resolución es la que ya está en la base de datos** — no se crea
desde pagos. Esto es lo que se verificó contra el código con esa regla puesta.

**El flujo queda en dos PA, no tres.** El Exento vive en
`sg_rslc.num_resolu` + `ano_resolu`, y la unidad es la constante `05000000` con
`cod_ders = '2'`. Con la resolución leída, `sg_resliSecgen01` sale del camino y
quedan `sg_asdiSecgen01` (asignación) y `sg_ccaiSecgen01` (centro de costo).

**Pero leerla no basta: tiene que existir en SISPER.**
`sg_asdiSecgen01` valida contra `sisper_db.dbo.sp_resl` por
`num_resol` + `cod_ders` + `cod_unidad` y, si no la encuentra, responde
«La resolucion no existe para los antecedentes indicados» y no inserta nada.
Ningún procedimiento del repositorio escribe `sp_resl`. Hay que confirmar que
Decretación registra ahí la resolución del Exento; si no lo hace, el ingreso se
detiene y la única salida sería volver a `sg_resliSecgen01`, que es justo lo que
esta decisión descarta.

**El número de resolución no es comparable como entero.**
`sg_rslc.num_resolu` es `int`. `sp_resl.num_resol` es `varchar(10)` y los datos
reales de la tabla traen sufijos: `5284 RA`. Un Exento con letras no cabe en la
columna de SG, y tampoco calza con la comparación rellenada a diez posiciones
que ya usa `sg_epagsSecgen05`. Antes de ingresar hay que decidir qué ocurre con
esos casos: hoy fallarían sin diagnóstico claro.

**El código de haber no tiene origen en SG.** Es el único dato que
`sg_asdiSecgen01` exige (`@numero_cuenta`) y que SG no guarda en ninguna parte:
`sg_fups` tiene `cod_sitm` e `itm_global`, no `num_cuenta`. Hoy el Excel lo
resuelve leyendo `ss_asds.num_cuenta`, es decir desde la asignación que todavía
no existe — circular en cuanto SG pasa a crearla. Los códigos 2011, 2013, 2319
y 2320 que aparecen en `sg_fupssSecgen13` pertenecen al cálculo del tope, no a
esto. Falta decidir dónde vive el valor del ejemplo (2417): columna nueva en
`sg_fups`, catálogo por `cod_tpps`, o parámetro de la operación.

**Al Excel hay que darle vuelta el origen de cuatro columnas.** Hoy
`codigo_haber`, `centro_costo`, `item_sisper` y `porcentaje_cc` salen de
`ss_asds` y `ss_ccas`. Si SG genera los registros, los cuatro deben salir de SG:
centro de costo con `cod_unifin` + `cod_ccto` —que sí están—, ítem con
`sg_fups.cod_sitm` —que sí está—, porcentaje fijo en 100, y el haber según el
punto anterior. Las dos guardas de la descarga cambian de sentido: `item_coincide`
y `porcentajes_suman_100` hoy comparan contra SISPER, y pasarían a describir el
valor que se va a escribir.

**Hallazgo sobre el pago recurrente.** `ss_asds` tiene `permanente`, `cuotas` y
`unidad_med`, y `sg_asdiSecgen01` ya acepta los tres como parámetros opcionales.
Es posible que el «pago vigente» no se exprese con un rango 01/09 a 31/12 sino
con `permanente` y una cantidad de cuotas, en cuyo caso la validación de mes
único no estorba y no habría que ampliarla. Conviene verificarlo contra cómo
SISPER liquida antes de tocar el PA: cambiaría la respuesta a la pregunta
abierta de F5.5.

Lo demás de F5.3 sigue pendiente igual: la preparación compartida de registros,
el botón con su orquestación —los dos PA no comparten transacción, así que un
fallo en el centro de costo deja la asignación suelta y hay que reusar su
`cod_asign`—, la tabla de trazabilidad para guardar ese `cod_asign`, y la
separación entre exportado, registrado y pagado.

El plan de implementación de este alcance, con sus fases y los estándares de
desarrollo que debe cumplir, está en
[plan_ingreso_sisper.md](plan_ingreso_sisper.md).
