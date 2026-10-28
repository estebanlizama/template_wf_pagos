# Implementación end-to-end: bandeja de cuotas aprobadas y envío a Finanzas

**Fecha:** 27-10-2026
**Estado:** orden de construcción. El qué y el por qué están en
`plan_bandeja_aprobadas_finanzas.md`; acá va el cómo, capa por capa, en el orden
en que se puede ejecutar y verificar.

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
  `{ staffProvisionId, installmentNumber, ok, message? }`. Un `msg` de una cuota
  no cancela las demás.
- `this.assertMutationResult` por ítem, capturando su error para el informe en
  vez de propagarlo.
- Normalizar el RUT con `this.normalizeRut`, y nunca registrarlo en los logs.

Por qué el lote va acá y no en el frontend: marcar 80 cuotas con 80 llamadas HTTP
abriría 80 conexiones y revalidaría la unidad 80 veces. Una llamada, una
conexión, 80 ejecuciones del PA.

### F3.4 Controlador

```
POST /requests/service-provision/payments/dgdp/installments/sent-to-payroll
```

- Cuerpo: lista de `{ staffProvisionId, installmentNumber }`, con un modelo de
  request propio (`Du288PaymentSentToPayrollRequest`) y tope de ítems por
  llamada.
- **`assertCanResolveDgdpPayment`**, no `assertIsDgdpPaymentReviewer`: es una
  escritura, y el permiso de lectura no debe cambiar estados. Es la separación
  que ya tienen las otras seis escrituras del controlador.
- Respuesta: el informe por cuota, para que la pantalla diga qué se marcó y qué
  no. No un booleano: en un lote el «éxito» parcial es el caso normal.

### F3.5 Store

`markInstallmentsSentToPayroll({ items })` en
`store/service-provision-payments.js`, y al volver, recargar la bandeja con
`fetchDgdpInstallments({ statusCode: 4 })` para que las marcadas desaparezcan.

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

Pruebas unitarias del lote, sin Sybase: todas ok, una con `msg`, lista vacía,
ítem repetido, y que el RUT no aparezca en los mensajes.

**Contra Sybase no se puede verificar en este entorno** —no hay cliente ni
contenedor—. Lo que hay que probar en certificación:

1. Cuota en 4 → queda en 8 y sus meses en 3 con `fec_envrem` y `mto_realpa`.
2. La misma cuota otra vez → `msg`, sin segundo cambio.
3. Cuota en 2 o en 10 → `msg`, sin cambios.
4. Usuario fuera de la unidad 696 → `msg` de asignación.
5. Un mes ya en 3 dentro de una cuota en 4 → no se vuelve a escribir.
6. Que la cuota en 8 siga visible filtrando por ese estado.

---

## F4 · El Excel

Bloqueada. Lo que la desbloquea, en este orden:

1. `Código Haber`, `Item` y `Porcentaje CC`: constantes de DU288 o datos por
   solicitud.
2. El mes de proceso del ejemplo frente a `01-09`–`31-12`.
3. Plantilla oficial, si existe.

Cuando se abra, el diseño ya decidido: lectura dedicada que devuelva para un
período de pago las cuotas aprobadas **con sus meses** en una consulta —los
meses de hoy se piden de a una cuota, y 80 cuotas serían 80 viajes—, y el libro
armado en backend si el formato es contractual. `Nº Resol` es el **Exento**
(`num_resolu_ext`) con su `Año Resol`, nunca el consecutivo interno.

---

## Orden de entrega

F1 y F2 son frontend y se pueden entregar juntas: dejan la bandeja y el detalle
utilizables, sin tocar base de datos. F3 es la que necesita certificación del PA,
así que va en su propia entrega. F4 queda esperando decisiones.

Si hay que elegir una sola, **F3 antes que F1**: es la que evita que la misma
cuota se exporte y se pague dos veces. Pero sin F1 no hay dónde ponerle el
botón, así que entregar F1+F2 primero y F3 enseguida es el orden que menos
trabajo repite.
