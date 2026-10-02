# Propuesta de vistas y componentes — pantallas del jefe de proyecto

**Fecha:** 02-10-2026
**Alcance:** frontend. Los 16 endpoints del backend están implementados.
**Complementa:** [`plan_implementacion_frontend.md`](plan_implementacion_frontend.md), que da el orden
y las jornadas. Esto da el detalle de archivos, props y eventos.

---

## 1. Inventario

### Archivos nuevos

| Tipo | Archivo | Qué es |
| :--- | :--- | :--- |
| Página | `pages/services-provision/payments/_nroSolici/index.vue` | contenedor con las dos pestañas |
| Store | `store/service-provision-payment-detail.js` | agregado por resolución |
| Scheme | `schemes/tables/services-provision-payment-months-table-scheme.js` | tabla de meses |
| Scheme | `schemes/tables/services-provision-installments-table-scheme.js` | tabla de cuotas |
| Componente | `Du288PaymentStaffSection.vue` | marco autorizado del funcionario |
| Componente | `Du288PaymentMonthsSection.vue` | tabla de meses |
| Componente | `Du288InstallmentsSection.vue` | tabla de cuotas |
| Componente | `Du288InstallmentFormModal.vue` | crear y editar cuota |
| Componente | `Du288ExecutedCompensationModal.vue` | compensación realizada |
| Componente | `Du288PaymentAntecedentsTab.vue` | pestaña de antecedentes |

**Diez archivos nuevos.** Todos los componentes con prefijo `Du288` y dentro de
`components/services-provision/`, como exige §3.2 del estándar visual.

### Lo que se reutiliza sin tocar

| Componente | Para qué |
| :--- | :--- |
| `BaseTable` · `EmptyAlert` | tablas de meses y cuotas |
| `RequestStatusBadge` | estado de la cuota — ya tiene la variante `primary` |
| `Du288ValidationSummary` | panel de incidencias |
| `Du288StaffPreviousProvisionsModal` | comparador de PDS previas |
| `ExecutionMonthsTags` | meses que abarca una cuota, en la fila |

### Lo que se reutiliza con cambios

| Componente | Cambio | Riesgo |
| :--- | :--- | :--- |
| `StaffCompensationSection` | acotar a **un** mes en vez de navegar entre varios | **alto** — 1005 líneas, lo usa resolución |

Es el único punto delicado del plan. Ver §5.

---

## 2. La página contenedora

### `_nroSolici/index.vue`

```
meta.module                  service-provision-payments
meta.guardian.privilege      provision-payment-manage
ruta                         /prestacion-de-servicios/pagos/:nroSolici
query                        ?funcionario=:idFunprse   ancla al entrar desde la bandeja
```

**Estructura**

```
<section class="container-bl-md pds-du288-scope">
  pds-ui-page-header        título · resolución · centro de costo
  Du288ValidationSummary    solo si hay incidencias
  pestañas
    │
    ├── Gestión de pago
    │     Du288PaymentStaffSection      selector + marco, solo lectura
    │     Du288PaymentMonthsSection     tabla de meses
    │     Du288InstallmentsSection      tabla de cuotas + acciones
    │
    └── Du288PaymentAntecedentsTab      sub-pestañas, solo lectura
  modales
    Du288InstallmentFormModal
    Du288ExecutedCompensationModal
</section>
```

La página **orquesta y no calcula**: mantiene qué funcionario está activo, qué modal está abierto, y
despacha al store. Los componentes reciben datos ya filtrados.

---

## 3. El store

### `store/service-provision-payment-detail.js`

Separado del de la bandeja a propósito: aquel es una lista plana, éste un agregado por resolución
con cuatro colecciones que se refrescan por separado.

```js
state
  request           cabecera de la solicitud
  staff             funcionarios con su marco
  months            meses de todos los funcionarios
  installments      cuotas de todos los funcionarios
  statuses          catálogo de estados de cuota
  activeStaffId     funcionario seleccionado
  isLoading / error

getters
  activeStaff           el funcionario activo
  monthsOfActiveStaff   sus meses, ordenados por periodo
  availableMonths       los que tienen isAvailable
  installmentsOfActive  sus cuotas
  usedQuota             cuotas vivas vs tot_cuotas
  canCreateInstallment  queda cupo, o hasExtension

actions
  fetchDetail           cinco llamadas en paralelo al montar
  refreshMonths         tras guardar monto o compensación
  refreshInstallments   tras crear, editar, eliminar o enviar
  saveInstallment       POST o PUT según haya nroCuota
  removeInstallment
  submitInstallment
  saveMonthAmount
```

**Dos refrescos y no uno.** Guardar una cuota cambia la asignación de los meses, y guardar un monto
cambia el total de la cuota: cada acción refresca las dos colecciones que toca, no todo.

---

## 4. Componentes, uno por uno

### `Du288PaymentStaffSection`

Marco autorizado del funcionario. Solo lectura.

| | |
| :--- | :--- |
| **props** | `staff: Array` · `activeStaffId: Number` · `isLoading: Boolean` |
| **events** | `@select="idFunprse"` |
| **muestra** | nombre · RUT · tipo de pago · total · tope · cuotas usadas de autorizadas · saldo · jornada · extensión |

Si hay un solo funcionario, el selector no se dibuja.

Usa `pds-ui-read-field` para cada dato — §6.2 del estándar: fondo blanco, agrupación por borde y
grilla.

---

### `Du288PaymentMonthsSection`

| | |
| :--- | :--- |
| **props** | `months: Array` · `amountType: Number` · `requiresCompensation: Boolean` · `isLoading` |
| **events** | `@edit-compensation="monthSequence"` · `@change-amount="{ monthSequence, amount }"` |

Columnas: mes · estado · monto · compensación · cuota · acción.

**No recalcular nada.** `isAvailable`, `isProposed`, `isAssigned` y `period` vienen del backend. En
particular `isAvailable` lo deriva el PA con la fecha del servidor; rehacerlo en el cliente abre
diferencias por zona horaria.

La columna **monto** es editable solo si `amountType === 2`. En Fija muestra el reparto comprometido,
sin control.

La columna **compensación** solo aparece si `requiresCompensation` — que sale de `dentro_jor`.

---

### `Du288InstallmentsSection`

| | |
| :--- | :--- |
| **props** | `installments: Array` · `canCreate: Boolean` · `isLoading` |
| **events** | `@create` · `@edit="nroCuota"` · `@remove="nroCuota"` · `@submit="nroCuota"` |

Columnas: cuota · estado · meses que abarca · monto · mes de pago · acciones.

`isEditable` del backend decide qué botones se muestran. **No replicar la regla de estados.**

`canCreate` sale del getter `canCreateInstallment`: queda cupo, o la prestación tiene extensión.

El botón **Enviar** pide confirmación: es la transición que compromete cupo y saldo, y no se
deshace sin pasar por DGDP.

---

### `Du288InstallmentFormModal` — el núcleo

| | |
| :--- | :--- |
| **props** | `visible` · `staffProvisionId` · `installment: Object\|null` · `availableMonths: Array` · `amountType` |
| **events** | `@save="payload"` · `@close` |

**Al abrir en modo edición** carga sus meses:

```
GET /payments/provisions/{id}/installments/{nro}/months
```

Ese endpoint es lo que hace posible editar — sin él no se sabe qué meses tiene marcados.

**Campos**

| Campo | Control | Regla |
| :--- | :--- | :--- |
| Meses | checkboxes sobre `availableMonths` + los propios | un mes en una sola cuota |
| Mes de pago | dos selects, año y mes | deriva *corriente* o *atrasada* en vivo |
| Monto por mes | input por mes | solo si `amountType === 2` |
| Respaldo | — | **oculto**: la subida está parqueada |

**Resumen en vivo**, arriba del pie: meses seleccionados, suma, y si queda corriente o atrasada.
Que el usuario vea el total antes de guardar, no después.

**Errores.** El backend devuelve 422 con el mensaje del PA, ya redactado y sin nombres de tabla.
Mostrarlo tal cual en el modal, sin mapear códigos ni traducir.

---

### `Du288ExecutedCompensationModal`

| | |
| :--- | :--- |
| **props** | `visible` · `staffProvisionId` · `monthSequence` · `period` · `isReadOnly` |
| **events** | `@close` · `@saved` |

Dos columnas lado a lado: comprometido y realizado. Lo que se audita es la **diferencia**; una sola
lista precargada invita a confirmar sin mirar.

Las dos listas llegan con la **misma forma** — el backend renombra `fec_compro` a `fec_comrea` —, así
que la comparación no traduce nada.

Dentro va `StaffCompensationSection` acotado al mes. Ver §5.

---

### `Du288PaymentAntecedentsTab`

Dos sub-pestañas, ambas solo lectura **por norma**: el flujo de pagos no escribe nada de resolución.

| Sub-pestaña | Fuente |
| :--- | :--- |
| Detalle de la resolución | `GET /requests/service-provision/resolution-details/{id}` |
| Documento | `<iframe>` a `GET /resolution/file/{año}/{nroResolu}/{correlativo}` — el **2** es el firmado |

Sin botones de firmar, aprobar ni archivar.

---

## 5. El punto delicado: `StaffCompensationSection`

Hoy navega libremente entre los meses del período, con selector y flechas. En pago tiene que
quedarse en **uno**.

**Tres caminos, de menor a mayor riesgo:**

| | Cómo | Riesgo |
| :--- | :--- | :--- |
| **A** | Prop `lockedMonth` que oculta la navegación y fija el mes activo | bajo — aditivo, el default no cambia nada |
| **B** | Extraer el calendario a `Du288CompensationCalendar` y que ambos lo usen | medio — refactor de un componente en producción |
| **C** | Componente nuevo para pago, duplicando el calendario | nulo al inicio, alto después: dos calendarios que divergen |

**Propongo A.** Una prop opcional, un `v-if` sobre el bloque de navegación, y el mes activo forzado.
Resolución no se entera.

Si al implementarlo aparece que el componente asume el arreglo completo de meses en más lugares de
los previstos, **B** es la salida — pero eso se decide con el código a la vista, no antes.

---

## 6. Textos

Todo a `lang/es/pds.js`, bajo `payments.detail`:

```
titles        detail · months · installments · compensation · antecedents
columns       month · status · amount · compensation · installment · actions
fields        paymentYear · paymentMonth · monthAmount · coveredMonths
actions       newInstallment · edit · remove · submit · saveDraft
confirm       submitTitle · submitBody
empty         noMonths · noInstallments · noCompensation
hints         currentPayment · latePayment · fixedAmountNotEditable
```

§15 del estándar: ningún texto visible en el template.

---

## 7. Orden de construcción

| | Qué | Deja funcionando |
| :-- | :--- | :--- |
| 1 | Store + página + `Du288PaymentStaffSection` | entrar y ver el marco |
| 2 | Navegación desde la bandeja | llegar |
| 3 | `Du288PaymentMonthsSection` | ver qué se puede pagar |
| 4 | `Du288InstallmentsSection` | ver las cuotas |
| 5 | `Du288InstallmentFormModal` | **crear, editar y enviar** |
| 6 | `Du288ExecutedCompensationModal` | informar lo realizado |
| 7 | `Du288PaymentAntecedentsTab` | contexto |
| 8 | Textos · responsive · lint DU288 | cierre |

Tras el paso **5** la pantalla ya cumple su propósito. Lo demás agrega.

---

## 8. Lo que la pantalla no podrá hacer

| | Por qué |
| :--- | :--- |
| Adjuntar respaldo | parqueado hasta decidir dónde se guarda el PDF |
| Ver el panel normativo revalidado | el servicio que orquesta los ocho PA no está |
| Seguir la cuota tras enviarla | el lado DGDP no existe |

El tercero conviene decirlo **en la pantalla**. Una cuota enviada se queda en *En visación* y ahí se
detiene; mejor que el usuario lo lea a que lo descubra esperando.

---

## 9. Validaciones — qué se reutiliza y qué es nuevo

El panel normativo de resolución tiene **25 códigos** con severidad declarada en
`utils/services-provision/normative/issueMeta.js`. Pagos los reutiliza completos: mismos códigos,
mismos textos, mismo componente `Du288ValidationSummary`.

### 9.1 Los 25 códigos ya implementados

| Severidad | Cuántos | Códigos |
| :--- | :-- | :--- |
| **error** · bloquea | 19 | `CARGO_INHABILITADO_DU288` · `TOPE_EXCEDIDO` · `CONTRATO_NO_REGISTRADO` · `CONTRATO_NO_DISPONIBLE` · `CONTRATO_FUERA_PERIODO` · `CONTRATO_NO_VIGENTE` · `CONTRATO_NO_CUBRE_RANGO` · `CONTRATO_NO_CUBRE_MESES` · `COMPENSACION_JORNADA` · `COMPENSACION_TOTAL_INCOMPLETA` · `HORARIO_EJECUCION_JORNADA` · `REMUNERACION_MES_NO_DISPONIBLE` · `REMUNERACION_FALTANTE` · `TOPE_FALTANTE` · `TOPE_NO_CONFIGURADO` · `REQUEST_VALIDATION_ERROR` · `LIMITE_SEMANAL_EXCEDIDO` · `ASIGNACION_DU288_INHABILITADA` · `DEUDA_INSTITUCIONAL` |
| **pending** · falta dato | 4 | `CARGO_VALIDACION_PENDIENTE` · `VALIDACION_CARGO_PENDIENTE` · `PERFIL_DINAMICO_NO_DISPONIBLE` · `DEUDA_VALIDACION_PENDIENTE` |
| **warning** · deja continuar | 2 | `CARGO_CONTRATO_MODIFICADO` · `ASIGNACION_PROXIMA_VENCER` |

**Ninguno se reescribe.** La pantalla de pago los recibe, los agrupa por severidad y los pinta con
el mismo componente. `pending` es importante: significa *no se pudo evaluar*, que no es lo mismo que
*pasó* — y hoy resolución ya lo distingue.

### 9.2 Los nueve endpoints que los producen

Todos existen y los invoca el formulario de resolución. **Pagos los consume tal cual.**

| Endpoint | Qué entrega |
| :--- | :--- |
| `/normative/staff-profile/{rut}` | perfil institucional, carga horaria, contrato |
| `/normative/calculated-cap/{rut}` | tope calculado y haberes |
| `/normative/staff-assignments/{rut}` | asignaciones inhabilitantes |
| `/normative/staff-position-cap` | tope por cargo |
| `/normative/disablement-staff` | inhabilidad del funcionario |
| `/normative/check-relationship` | parentesco con la jefatura |
| `/normative/staff-previous-provisions/{rut}` | PDS previas — alimenta tope mensual y cupo |
| `/normative/cost-center-balance-validation` | validación de saldo del centro de costo |
| `/normative/institutional-calendar` | feriados y fechas institucionales |

> **Advertencia de alcance.** El servicio que los orquesta **antes del envío** no está construido.
> Hoy la pantalla puede llamarlos para *mostrar* el panel, pero `sg_epaguSecgen02` no los consulta:
> una cuota se envía sin que se revalide el contrato. Está anotado en
> [`backend_lo_que_falta.md`](backend_lo_que_falta.md) §2.1.

### 9.3 Validaciones propias de pago

Estas no existen en resolución. Viven en los PA del flujo de pago, no en el frontend.

| Momento | Regla | Dónde |
| :--- | :--- | :--- |
| Elegir meses | mes propuesto · no tomado por otra cuota · ejecución terminada · mismo año | `sg_epagiSecgen01` · `sg_epaguSecgen01` |
| Compensación | fuera de jornada 08:30–17:18 · no feriado · sin solape con comprometido ni realizado | `sg_fuc2iSecgen01` |
| Montos | tope completo · saldo contractual · mayor que cero | `sg_epaguSecgen02` |
| Cupo | máximo 2 cuotas al año, salvo `ext_cuotas` | `sg_epagiSecgen01` |
| Envío | compensación completa · exclusividad de meses · última cuota con ejecución terminada | `sg_epaguSecgen02` |
| Concurrencia | `holdlock` sobre `sg_dpag` dentro de la transacción | `sg_epagiSecgen01` · `sg_epaguSecgen01` |

**El frontend no las replica.** Llama, recibe el 422 con el mensaje del PA —ya redactado y sin
nombres de tabla— y lo muestra. Duplicarlas en el cliente crearía una segunda versión que se
desincroniza.

### 9.4 Lo que está decidido pero no implementado

| | Estado |
| :--- | :--- |
| Compensación incompleta bloquea el **envío**, no el registro | decidido · falta la verificación en `sg_epaguSecgen02` |
| Respaldo obligatorio al enviar (PAG-11) | decidido · parqueado con la evidencia |
| Asistencia como antecedente, nunca bloqueante | decidido 30-09 · se muestra en la visación |
| Receso universitario | **fuera de alcance** |
| Recompromiso de tramos faltantes (PAG-38b) | **no implementable**: falta columna que distinga realizado de recomprometido |

---

## 10. Consultas de solo lectura que se reutilizan

Para mostrar información **no se escribe ningún PA nuevo**. Todo sale de lo que ya existe.

| Qué mostrar | Endpoint | Observación |
| :--- | :--- | :--- |
| Cabecera de la solicitud | `GET /requests/service-provision/{id}` | — |
| Detalle completo | `GET /requests/service-provision/{id}/detail-information` | pestaña de antecedentes |
| Funcionarios y marco | `GET /requests/service-provision/{id}/staff` | — |
| Detalle de la resolución | `GET /requests/service-provision/resolution-details/{id}` | — |
| Horario comprometido FUHO | `GET /requests/service-provision/{id}/staff-schedules` | — |
| Compensación comprometida FUCO | `GET /payments/{requestId}/committed-compensations` | reutiliza `sg_fucosSecgen01` sin tocarlo |
| Historial de la solicitud | `GET /requests/service-provision/{id}/comments` | — |
| PDS previas del funcionario | `GET /normative/staff-previous-provisions/{rut}` | alimenta el comparador |

### El documento de la resolución archivada

```
GET /resolution/file/{resolutionYear}/{resolutionNumber}/{correlative}
```

| | |
| :--- | :--- |
| Correlativo **1** | el generado por el sistema |
| Correlativo **2** | el **cargado y firmado** — es el que corresponde mostrar en una resolución archivada |
| Devuelve | el binario con su `Content-Type`; con `?action=download` fuerza la descarga |
| Autenticación | `@authenticate('jwt')` |

El binario no está en Sybase: sale de `MyArchivo` vía `selectResolutionSignaturesFile`. Por eso la
ruta recibe año y número y no el `nro_solici`.

**Cómo armar la URL en la pantalla.** `resolutionYear` y `resolutionNumber` vienen en la cabecera de
la solicitud (`ano_resolu`, `num_resolu_ext`). La bandeja ya los expone como `resolutionYear` y
`resolutionExternalNumber`.

```js
const url = `${this.$axios.defaults.baseURL}/resolution/file/${anoResolu}/${nroResolu}/2`
```

Se embebe en un `<iframe>`. **Sin acciones**: ni firmar, ni aprobar, ni archivar — esas pertenecen al
flujo de resolución y a su permiso.

> Si el correlativo 2 devuelve 404, la resolución no tiene documento firmado cargado. La pantalla
> debe mostrar un estado vacío explicativo, no un visor roto.
