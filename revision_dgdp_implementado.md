# Revisión DGDP de cuotas: qué está implementado hoy

**Fecha:** 06-10-2026
**Alcance:** bandeja de revisión y gestión de la aprobación. Contraste contra `requerimientos_wf/2_requerimientos_dgdp_pago.md` (PP02) y `plan_bandeja_gestion_dgdp.md`.

Corrección a un diagnóstico anterior: el lado DGDP **sí existe** de punta a punta (PA, backend y frontend). La búsqueda previa falló porque las rutas del frontend están en inglés (`pages/services-provision/payments/review/`), no bajo `*pago*`.

---

## 1. Cadena completa

| Capa | Bandeja | Detalle de meses | Decisión |
|---|---|---|---|
| Página | `payments/review/index.vue` | misma página de detalle | `review/_staffProvisionId/_installmentNumber.vue` |
| Ruta pública | `/prestacion-de-servicios/pagos/revision` | — | `/prestacion-de-servicios/pagos/revision/:id/:nro` |
| Store | `fetchDgdpInstallments` | `fetchDgdpInstallmentMonths` | `resolveDgdpInstallment` |
| Endpoint | `GET /requests/service-provision/payments/dgdp/installments` | `GET .../provisions/{id}/installments/{nro}/months` | `POST .../decision` |
| Guardia | `assertIsDgdpPaymentReviewer` → `provision-payment-read-waiting` | igual | `assertCanResolveDgdpPayment` → `provision-payment-approve` |
| PA | `sg_epagsSecgen03` | `sg_epagsSecgen04` | `sg_epaguSecgen03` |
| Menú | `servicesProvisionPayments.js` → "Revisión de cuotas DGDP" | — | — |

El criterio de acceso se revalida dentro de Sybase en los tres PA: contrato vigente en `sp_cont` (`vigen_cont` en 0 o 2, `cod_calida` distinto de 01, fechas vigentes) **y** fila vigente en `sp_orde` con `cod_organi = 696` para el RUT autenticado. El permiso se deriva en `sg_usacsSecgen01` y se cataloga en `datos_base/04_roles_privilegios_pagos.sql` (privilegio 94).

---

## 2. Bandeja

### 2.1 Datos que entrega `sg_epagsSecgen03`

Un registro por cuota, agrupado sobre `sg_epag` + `sg_dpag` + `sg_fume`:

| Grupo | Columnas | Expuesto en el modelo |
|---|---|---|
| Identidad de la cuota | `id_funprse`, `nro_cuota`, `cod_estcuo`, `des_estcuo` | `staffProvisionId`, `installmentNumber`, `statusCode`, `status` |
| Envío | `rut_solici`, `fec_solici` | `requestedByRut`, `requestedAt` |
| Respaldo | `id_evidenc` | `evidenceId` |
| Funcionario | `rut`, `nom_nombre`/`nom_appate`/`nom_apmate` | `staffRut`, `staffFullName` (compuesto en el modelo) |
| Prestación | `nro_solici`, `actividad` | `requestId`, `activity` |
| Centro de costo | `cod_unifin`, `cod_ccto`, `nom_ab_cct` | `costCenterUnitCode`, `costCenterCode`, `costCenterName` |
| Resolución | `nro_resolu`, `ano_resolu`, `rslc.num_resolu` | `resolutionNumber`, `resolutionYear`, `resolutionExternalNumber` |
| Topes de la resolución | `mto_total`, `mto_tope`, `cod_tpps` | `totalAmount`, `monthlyCap`, `amountType` |
| Período de pago | `ano_pago`, `mes_pago` | `paymentYear`, `paymentMonth` |
| Cobertura | `cant_meses`, `mes_prop_min`, `mes_prop_max` | `monthCount`, `firstCoveredPeriod`, `lastCoveredPeriod` |
| Monto | `sum(fume.mto_apagar)` | `requestedAmount` |

### 2.2 Datos que la tabla realmente muestra

Siete columnas: Funcionario (+RUT), Prestación (+actividad), Centro de costo (+`unifin-ccto`), Cuota, Monto solicitado (+cantidad de meses), Enviada, acción.

**Quedan en el payload sin usarse en la bandeja:** `mto_tope`, `mto_total`, `cod_tpps`, `ano_pago`/`mes_pago`, `firstCoveredPeriod`/`lastCoveredPeriod`, `evidenceId`, `status`/`statusCode`, `resolution*`. Varios de esos son justamente los que permiten priorizar sin abrir el detalle.

### 2.3 Filtros

**No existe ninguno.** `sg_epagsSecgen03` recibe un solo parámetro (`@rut_person`); la cláusula `where` está fija en `cod_estcuo = 2`, modalidad 2, `cod_estsol = 11` y resolución no nula. La página no tiene controles de filtro, ni orden por columna, ni paginación; el orden lo impone el PA (`fec_solici, nro_solici, id_funprse, nro_cuota`).

PP02-F01 pide como mínimo **número, resolución, funcionario, centro, estado y fecha**:

| Filtro exigido | Estado | Dato disponible para implementarlo |
|---|---|---|
| Número | ausente | `nro_solici` + `nro_cuota` ya vienen |
| Resolución | ausente | `nro_resolu` / `num_resolu` ya vienen |
| Funcionario | ausente | `rut` y nombre ya vienen |
| Centro de costo | ausente | `cod_unifin`/`cod_ccto`/`nom_ab_cct` ya vienen |
| Estado | no aplicable | la bandeja es monoestado por diseño (`= 2`) |
| Fecha | ausente | `fec_solici` ya viene |

Cinco de los seis filtros son implementables **solo en el cliente**, sin tocar el PA. "Estado" exige decidir primero si la bandeja debe incluir también 3/4/10 como historial.

### 2.4 Otras brechas de PP02-F01

- **Antigüedad**: hay `fec_solici` pero no se calcula días pendientes.
- **Prioridad**: no existe el concepto en el modelo.
- **Cantidad de detalles**: `cant_meses` existe; "detalles" en PP02 son funcionarios, y aquí la unidad ya es la cuota de un funcionario.
- **Alertas**: no hay ninguna. Ni tope excedido, ni compensación incompleta, ni saldo de centro de costo, ni licencias.
- **Asignación**: PP02 habla de "solicitudes asignadas". No hay modelo de asignación: toda persona con el permiso ve **todas** las cuotas en estado 2.
- **Monto bruto**: `requestedAmount` suma `mto_apagar` sin descontar `mto_deslic`/`mto_dessg`. El detalle sí muestra "Descuentos informados" por mes, así que el total de la bandeja no es lo que pagaría Finanzas.

---

## 3. Gestión de la aprobación

### 3.1 Detalle

No hay endpoint de detalle de cuota: la página vuelve a pedir **toda la bandeja** y busca la fila en cliente (`items.find(...)`). Consecuencias:

- si la cuota dejó el estado 2 (o alguien ya la resolvió), el detalle muestra "La cuota ya no está disponible en la bandeja DGDP";
- no hay forma de abrir una cuota ya aprobada, observada o rechazada: la revisión no es consultable después de decidir.

`sg_epagsSecgen04` entrega por mes: período propuesto, `cod_estfum`/`des_estfum`, `ano_ejec`/`mes_ejec`, `mto_apagar`, `mto_realpa`, `mto_deslic`, `mto_dessg`, los cuatro indicadores (`val_licmed`, `val_inabili`, `val_singoce`, `val_ciecc`), fechas de validación/autorización/envío a remuneraciones, y `cant_compens` (conteo de filas `sg_fuc2`).

La tabla muestra cinco columnas: Mes, Estado del mes, Monto solicitado, Descuentos informados, Compensaciones realizadas. **Se descarta** `mto_realpa`, los cuatro indicadores normativos y las tres fechas, que ya llegan en el payload.

### 3.2 Decisión

`sg_epaguSecgen03` acepta `@cod_estcuo` en 3, 4 o 10, exige observación para 3 y 10, revalida el permiso, y dentro de una transacción con `holdlock`:

- verifica que la cuota siga en estado 2 (si no, `rollback` + mensaje);
- si es **rechazo (10)**: devuelve los meses de `cod_estfum = 2` a `1` y **borra las filas de `sg_dpag`**, liberando los meses para otra cuota. El encabezado queda en 10 con cero meses;
- actualiza `sg_epag.cod_estcuo`, exige `@@rowcount = 1`, y hace `commit`.

Coherencia verificada con el lado solicitante:

- `sg_epagiSecgen01` cuenta cupo con `cod_estcuo <> 10`, así que un rechazo libera cupo de cuota;
- `sg_epaguSecgen01` (editar) admite estados 1 y 3, así que una cuota observada se puede corregir;
- `sg_fuc2iSecgen01` permite registrar compensación cuando el mes está comprometido pero la cuota está observada. El camino de la observación cierra bien.

### 3.3 Lo que falta en la decisión

- **La observación no se persiste.** `@observacion` se valida (obligatoria, hasta 255) y se descarta: `sg_epag` no tiene columnas `observacion`, `rut_visa` ni `fec_visa`. La página lo declara explícitamente al pie. Pero `Du288InstallmentsSection.vue:39` renderiza `row.source.reviewObservation`, campo que **ningún** modelo ni PA del backend produce: el solicitante nunca verá por qué le observaron la cuota. Es código muerto que simula una funcionalidad inexistente. `datos_base/05_auditoria_revision_dgdp.sql` existe como propuesta de extensión, fuera del despliegue.
- **Observar (3) no libera los meses.** Quedan en `cod_estfum = 2`. Es consistente con permitir corregir, pero significa que el saldo del funcionario sigue comprometido mientras la cuota esté observada.
- **Aprobar (4) no mueve nada más.** Los meses siguen en `cod_estfum = 2`. Nada escribe `cod_estcuo = 8` (Enviada remuneraciones), `11` (Devuelta Finanzas) ni `cod_estfum = 3` (Enviada a pago): **la etapa de Finanzas no existe**. Por eso las agregaciones de `sg_fupssSecgen18` sobre `cod_estfum = 3` (`mto_pagado`, `cant_cuotas_paga`) nunca se activan hoy.
- **Cero validación normativa en la decisión.** El PA no comprueba tope mensual, monto total de la resolución, saldo del centro de costo, ni completitud de la compensación. PP02-F03 pide "resultados de cada regla con fuente, fecha y severidad" y PP02-F05 pide "aprobar con excepción formal" y "bloquear cuota": nada de eso está. DGDP aprueba sin contraste automático.
- **Sin historial.** PP02-F02 pide historial completo y PP02-F03 "decisiones anteriores sobre el mismo detalle/cuota". No hay tabla de bitácora.
- **PP02-F06 no aplica todavía.** La unidad de decisión es la cuota de un funcionario; no hay resolución agregada de la solicitud.

### 3.4 Desvíos de permisos y de estándar visual

- **Permiso:** la página de detalle guarda con `provision-payment-read-waiting`, igual que la bandeja. Quien pueda leer ve los botones Aprobar/Observar/Rechazar y recibe un 403 recién al enviar. Deberían deshabilitarse con `provision-payment-approve`.
- **Sin confirmación:** las tres decisiones son irreversibles y se ejecutan en un clic directo, sin el modal de resumen que exige el §11 del estándar y que ya se aplicó al envío de cuota del solicitante.
- **Error de campo:** la obligación de observación se comunica solo con el botón deshabilitado; el §6.3 pide el mensaje junto al campo.
- **Patrón de tabla:** bandeja y detalle usan `b-table` cruda con `b-alert`/`b-form-textarea`, no los bloques `pds-ui-*` y el patrón de tarjetas que se normalizó en el detalle de pago y en resolución.
- **Textos:** "Monto solicitado" repetido en bandeja y detalle para dos sumas distintas (bruta vs. por mes); conviene distinguir bruto y neto.

---

## 4. Resumen de brechas priorizadas

**Sin tocar la BDD (solo frontend, el dato ya llega):**

1. Filtros de bandeja: número, resolución, funcionario, centro, fecha.
2. Orden por columna y paginación.
3. Columna de antigüedad (días desde `fec_solici`).
4. Mostrar en bandeja `mto_tope`, período de pago y cobertura `mes_prop_min`–`mes_prop_max`.
5. En el detalle, exponer los cuatro indicadores normativos y `mto_realpa` que ya vienen.
6. Modal de confirmación por decisión; error junto al textarea; deshabilitar acciones por `provision-payment-approve`.
7. Quitar o alimentar `reviewObservation` en `Du288InstallmentsSection.vue`.

**Requieren PA nuevo o modificado:**

8. Endpoint/PA de detalle de cuota por clave, independiente de la bandeja, para consultar cuotas ya resueltas.
9. Alertas calculadas en el PA de bandeja (tope excedido, compensación incompleta, saldo del centro de costo).
10. Monto neto en la bandeja (restar `mto_deslic` + `mto_dessg`).
11. Filtro de estado y modo historial (3/4/10).

**Requieren cambio de esquema (decisión pendiente):**

12. Persistir observación, RUT revisor y fecha (`05_auditoria_revision_dgdp.sql`).
13. Bitácora de decisiones para el historial de PP02-F02/F03.
14. Etapa Finanzas: estados 8 y 11, y `cod_estfum = 3`.

**Decisiones funcionales pendientes:**

15. ¿La bandeja se asigna por persona o sigue siendo global para el perfil?
16. ¿Aprobar exige que la compensación esté completa, o es criterio del revisor?
17. ¿Existe "aprobar con excepción" y "bloquear cuota" de PP02-F05?

---

## 5. Inconsistencia documental detectada

- `plan_bandeja_gestion_dgdp.md` punto 4 afirma "Se guarda la última observación, RUT revisor y fecha", pero su propia sección "Límites de la primera entrega" dice lo contrario y el PA confirma que no se guarda. El punto 4 debe corregirse.
- `requerimientos_wf/2_requerimientos_dgdp_pago.md` §2 dice "DGDP decide por `sg_pade`". `sg_pade` no existe en el esquema de pagos; lo implementado decide por `sg_epag.cod_estcuo` contra el catálogo `sg_ecuo`. Hay que actualizar el requerimiento o declarar el cambio de modelo.

---

## 6. Cambios aplicados el 06-10-2026 sobre la bandeja

Se atacó la brecha de la bandeja: filtros, tabla y definición de atributos. Las
decisiones de alcance fueron del usuario: la bandeja debe cubrir todos los
estados enviados (devueltas, rechazadas, pagadas y el resto), y el monto se
muestra como lo solicitado más un atributo aparte con los descuentos aplicados.

### 6.1 Base de datos

`sg_epagsSecgen03` — bandeja:

- nuevo `@cod_estcuo`. Omitido entrega las cuotas en visación, que es la
  bandeja de trabajo; `0` entrega todo lo enviado; un código concreto entrega
  ese estado. Se validan solo 0, 2, 3, 4, 8, 10 y 11: el estado 1 Propuesta es
  el borrador del jefe de proyecto y nunca aparece en DGDP;
- `dias_espera` con `datediff` contra la fecha del servidor, que es la que
  manda para medir antigüedad;
- `tot_cuotas` y `ext_cuotas`, para poder decir "Cuota 2 de 3" y marcar la
  extensión;
- `mto_deslic` y `mto_dessg` sumados, de donde salen el descuento y el neto;
- `cant_compens` y `cant_sincomp` por subconsulta sobre `sg_dpag`/`sg_fuc2`,
  que son la base de la alerta de compensación. Van como subconsulta y no como
  join porque un join con `sg_fuc2` multiplicaría las filas y rompería
  `sum(mto_apagar)`.

`sg_epagsSecgen04` — meses de la cuota: la condición pasa de `cod_estcuo = 2` a
los seis estados enviados, para que una cuota ya resuelta se pueda consultar.
El PA de decisión, `sg_epaguSecgen03`, sigue exigiendo estado 2: se puede mirar
el historial, no reabrirlo.

Ambos quedan como `.sql` y `.txt` idénticos, CRLF y ASCII 7-bit.

### 6.2 Backend

- `selectDgdpInstallments(rut, statusCode?)` con lista blanca
  `DGDP_REVIEW_STATUSES`; un valor fuera de ella cae al `NULL` del PA;
- `GET .../dgdp/installments` acepta `statusCode` como parámetro de consulta;
- el modelo de respuesta expone los campos nuevos y deriva `deductionsAmount` y
  `netAmount` una sola vez, en lugar de repetir la resta en cada vista.

### 6.3 Frontend

- bandeja rehecha con `BaseTable`, homologada con "Prestaciones por pagar":
  panel único de filtros, chip de resultados, orden por columna, paginación de
  10/25/50 y estado vacío con el componente común;
- diez atributos: funcionario con RUT, cuota con "de N" y chip de extensión,
  centro de costo con código, actividad truncada con tooltip, **mes a pagar**
  separado de **meses cubiertos**, solicitado, con descuentos, estado con
  antigüedad y alertas, y la acción;
- nueve filtros, que cubren los seis mínimos de PP02-F01: estado (al PA),
  número —busca en solicitud y en cuota—, funcionario, RUT, centro de costo,
  resolución, mes a pagar desde/hasta y alertas;
- alertas por fila: meses sin compensar, cuota sin respaldo y sobre el tope. El
  tope se compara contra el tope mensual por los meses que cubre la cuota,
  porque la bandeja entrega sumas; en qué mes se excede lo dice el detalle;
- el detalle abre en solo lectura cuando la cuota no está en visación, y vuelve
  a la bandeja conservando el estado desde el que se entró;
- `utils/servicesProvisionDgdpReviewFilter.js` con 14 pruebas en
  `utils/__tests__/servicesProvisionDgdpReviewFilter.test.cjs`.

### 6.4 Orden de despliegue

Primero los dos PA, después reiniciar el backend. Al revés, el backend manda
`@cod_estcuo` a un procedimiento que todavía no lo declara.

Mientras el PA no esté desplegado la bandeja funciona igual pero degradada: el
filtro de estado no acota, y antigüedad, "de N", extensión, descuentos y
alertas quedan vacíos porque esas columnas aún no llegan.

### 6.5 Lo que esta entrega no cubre

Siguen abiertos los puntos 8, 12, 13 y 14 del resumen anterior: endpoint de
detalle propio —el detalle aún refiltra la bandeja—, persistencia de la
observación con RUT revisor y fecha, bitácora de decisiones, y la etapa de
Finanzas con los estados 8 y 11. También sigue sin resolverse si la bandeja se
asigna por persona o permanece global para el perfil.
