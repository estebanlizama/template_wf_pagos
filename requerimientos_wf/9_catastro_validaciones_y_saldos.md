# Catastro de validaciones y saldos — solicitud de resolución y solicitud de pago

**Versión:** 0.2
**Fecha:** 2026-09-02
**Naturaleza:** catastro de lo que **existe hoy** y de lo que la solicitud de pago **debe tener**
**Ámbito:** D.U. 009/2026, DU288/DU09
**Decisiones incorporadas:** respuestas registradas en la tarjeta ClickUp [S0-013](https://app.clickup.com/t/86e2zrkh4) — bloques A, B, C, D, E completos o casi completos, F parcial, G01. Las respuestas de los bloques G a Q siguen pendientes.

## 0. Cómo se relaciona con los demás documentos

| Documento | Responde |
| :--- | :--- |
| Este catastro | *Qué existe, dónde vive, con qué fuente y con qué severidad real hoy* |
| [8_matriz_validaciones_resolucion_a_pago.md](./8_matriz_validaciones_resolucion_a_pago.md) | *Qué hace el pago con cada regla*: hereda, revalida, adapta, descarta o crea |
| [0_requerimientos_cu_pa_bdd_segun_wf_pagos.md](./0_requerimientos_cu_pa_bdd_segun_wf_pagos.md) | Requerimiento maestro y decisiones bloqueantes |

Aquí no se clasifica ni se decide: se levanta el inventario verificado. Cada fila indica **estado real**, no estado deseado.

Convención de estado real:

| Marca | Significado |
| :--- | :--- |
| `ACTIVA` | Implementada y con efecto sobre el usuario |
| `BLOQUEA` | Implementada e impide guardar o enviar |
| `INFORMA` | Se calcula y se muestra, pero no impide avanzar |
| `APAGADA` | El código existe pero está deshabilitado por bandera o TODO |
| `SIN FUENTE` | La regla está declarada, pero el dato no está integrado |
| `POR CREAR` | No existe todavía; corresponde al flujo de pago |

## 0.1 Modelo de ejecución, cuotas y meses

Decidido en S0-013 (A03, A04, A06, A07, A12, B02, B05, B08, B09, C01–C06, C11, D03, D04). Es la base de las reglas de tope, saldo y periodo que siguen; toda la parte financiera del catastro depende de este modelo.

### Separación de ejes

```text
Ejecución   →  hasta 12 meses, sin cruzar el año calendario
Cuota       →  unidad de pago; máximo 2 por PDS + funcionario
Mes de pago →  libre; puede caer en el año siguiente y no consume cupo
```

Los "dos meses de pago" del D.U. 9 se expresan como **dos cuotas**. El rango de ejecución deja de tener relación con esa cuenta: una actividad de ocho meses y una de dos tienen el mismo cupo de cuotas.

### Reglas derivadas

| ID | Regla | Origen |
| :--- | :--- | :--- |
| MOD-01 | La ejecución puede abarcar hasta 12 meses y no cruza el año calendario | B09 |
| MOD-02 | Máximo **2 cuotas** por PDS + funcionario, ancladas al año de ejecución de la actividad | C01, C02 |
| MOD-03 | Una cuota puede cubrir uno o varios meses de ejecución; el solicitante distribuye manualmente | B05, B06, B08 |
| MOD-04 | **Una cuota consume un solo tope**, cubra los meses que cubra | C08 aclarada |
| MOD-05 | El tope **no se arrastra ni se descuenta** entre cuotas: cada una parte completa | A07, C02 |
| MOD-06 | El monto de una cuota solo puede **bajar** respecto del tope: licencia, permiso o ejecución parcial | B12 |
| MOD-07 | Un mes de ejecución queda bloqueado para otra cuota de la misma actividad | C06 |
| MOD-08 | Dos cuotas coinciden en el mismo mes de pago solo cuando hay atraso administrativo | C05 |
| MOD-09 | La **última cuota** se paga únicamente una vez terminada la ejecución | C06, E02 |
| MOD-10 | El mes de pago puede caer en el año calendario siguiente al de ejecución | C11 |
| MOD-11 | ANID libera el tope **y** el límite de 2 cuotas, de forma automática por centro de costo | D03, D04, D11 |
| MOD-12 | Las cuotas las crea el solicitante **al enviar**, no al guardar borrador, y son eliminables mientras la solicitud no haya sido enviada nunca | B01, B02, F10 |

### Coherencia con la solicitud de resolución

El modelo cierra con lo ya implementado: el mensaje `topExceededPaymentMonths` bloquea en resolución cuando el monto total requeriría más de 2 meses de pago, es decir, **la resolución ya impide autorizar más de dos topes**. El pago consume exactamente lo que la resolución autoriza y no puede quedar monto estructuralmente impagable, salvo en ANID, donde ambos límites se levantan a la vez.

### Registro en el modelo de datos

`sg_fume` ya separa los ejes necesarios: `ano_ejec`/`mes_ejec` para la ejecución y `ano_pago`/`mes_pago` para el pago efectivo. El conteo de MOD-02 se hace sobre el eje de ejecución; el eje de pago no participa del límite.

### Pendientes de este modelo

| # | Pendiente | Efecto |
| :---: | :--- | :--- |
| M1 | Plazo máximo para pagar hacia atrás una ejecución de un año anterior | Sin corte, una actividad de 2026 podría pagarse indefinidamente |
| M2 | Arrastre del compromiso presupuestario entre ejercicios | Ver §3, brecha B11 |
| M3 | Qué mes fija el tope: congelado en la resolución o recalculado al pago | C13 sin responder; con dos cuotas separadas por meses las opciones dan resultados distintos |
| M4 | Constancia formal de que dos cuotas pueden coincidir en un mes de pago por atraso no imputable al funcionario | Respaldo ante auditoría |

---

# PARTE I — CATASTRO DE SALDOS

## 1. Los cuatro saldos del negocio

Hablar de "el saldo" es la principal fuente de ambigüedad en este flujo. Existen **cuatro saldos distintos**, con fuente, dueño y momento diferentes. Ninguno reemplaza a otro.

| # | Saldo | Pregunta que responde | Fuente | Dueño |
| :---: | :--- | :--- | :--- | :--- |
| S1 | **Presupuestario** | ¿El centro de costo tiene fondos para pagar esto? | FIN21 (`valida_saldo_cc_cs`, `sg_cctosSecgen06`) | Dirección de Finanzas |
| S2 | **Contractual / autorizado** | ¿Queda monto sin pagar dentro de lo que autorizó la resolución? | `sg_fups.mto_total` menos pagado y comprometido | SecGen (workflow) |
| S3 | **De tope** | ¿Cabe este monto en el tope de **esta cuota**? | `sg_fups.mto_tope` o `sg_fupssSecgen13` | DGDP |
| S4 | **De cuota / periodo** | ¿Queda cupo de cuotas y ese periodo ya fue pagado o comprometido? | `sg_fume` + cobertura de periodo | SecGen (workflow) |

S3 se evalúa **por cuota, no por mes calendario** (MOD-04, MOD-05): cada cuota dispone del tope completo y una cuota que cubre varios meses sigue consumiendo un solo tope.

En la **solicitud de resolución** solo existen S1 (informativo) y S3. En la **solicitud de pago** deben existir los cuatro y el monto autorizable es el mínimo de todos.

## 2. Cadena de saldo presupuestario (S1) implementada hoy

Está construida de extremo a extremo en el flujo de resolución. Este es el recorrido verificado:

| Capa | Elemento | Ubicación |
| :--- | :--- | :--- |
| PA FIN21 | `Analisis.valida_saldo_cc_cs` | [PA base/valida_saldo_cc_cs.sql](../../template-du09/cambios_pa_solicitud_wf/solicitante/PA%20base/valida_saldo_cc_cs.sql) |
| PA SecGen | `Analisis2.sg_cctosSecgen06` — saldo consolidado por ítem | [sg_cctosSecgen06.sql](../../template-du09/cambios_pa_solicitud_wf/solicitante/sg_cctosSecgen06.sql) |
| Query backend | `validateNormativeCostCenterBalance` y `selectCostCenterBalance` | [service-provision-request.ts](../../../sg-solicitudes-backend/src/db-assets/sybase-assets/queries/service-provision-request/service-provision-request.ts:378) |
| Repositorio | `validateNormativeCostCenterBalance()` | [service-provision-request-procedures.repository.ts:2461](../../../sg-solicitudes-backend/src/repositories/storedProcedures/service-provision-request-procedures.repository.ts:2461) |
| Endpoint informativo | `GET /requests/service-provision/cost-center-balance/{codUnifin}/{codCcto}` | [controller:351](../../../sg-solicitudes-backend/src/controllers/service-provision/service-provision-request.controller.ts:351) |
| Endpoint de validación | `GET /requests/service-provision/normative/cost-center-balance-validation` | [controller:392](../../../sg-solicitudes-backend/src/controllers/service-provision/service-provision-request.controller.ts:392) |
| Agrupación en UI | `costCenterBalanceGroups` — agrupa por `cod_sitm` y suma montos | [PdsDu288RequestForm.vue:1194](../../../sg-solicitudes-frontend/components/services-provision/PdsDu288RequestForm.vue:1194) |
| Invocación en UI | `loadCostCenterBalance` con `codTipmov: 21`, `afecta: '1'` | [PdsDu288RequestForm.vue:2340](../../../sg-solicitudes-frontend/components/services-provision/PdsDu288RequestForm.vue:2340) |
| Presentación | tabla de saldo por ítem y mensaje de resultado | [Du288RequestHeaderSection.vue:94](../../../sg-solicitudes-frontend/components/services-provision/Du288RequestHeaderSection.vue:94) |

### 2.1 Contrato de entrada y salida de `valida_saldo_cc_cs`

| Parámetro | Tipo | Valor usado hoy en DU288 |
| :--- | :--- | :--- |
| `@cod_unifin` | `int` | unidad financiera del centro de costo |
| `@cod_ccto` | `int` | centro de costo |
| `@cod_sitm` | `varchar(5)` | ítem presupuestario de la fila; por defecto `'300'` |
| `@cod_tipmov` | `smallint` | **21**, fijo en la interfaz |
| `@valor` | `decimal(15,2)` | suma de montos de los funcionarios de ese ítem |
| `@Afecta` | `char(1)` | `'1'` |

Salida: `Mensaje`, `Estatus`, `Saldo`, `SaldoInicial`, `MontoSolicitado`, `SaldoRemanente`, `CodSitm`, `CodUnifin`, `CodCcto`. `Estatus = 1` es la única condición de aprobación; cualquier otro valor se trata como error.

### 2.2 Qué rechaza realmente el PA

| Causal verificada | Mensaje devuelto | Momento |
| :--- | :--- | :--- |
| Centro de costo cerrado (`f_cierre` pasada) | `El centro de costo esta Cerrado` | antes de calcular saldo |
| Centro de costo bloqueado (`bloqueo = '1'`) | `El centro de costo está bloqueado` | antes de calcular saldo |
| Ítem incoherente con el tipo de CC | `El item no corresponde para este tipo de centro de costo` | validación de coherencia |
| Tipo de movimiento incompatible con el ítem | `El tipo de movimiento no corresponde para el item ingresado` | validación de coherencia |
| Disponible negativo tras descontar compromisos | `El centro de costo no tiene fondos disponibles` | cálculo de saldo |
| Resultado favorable | `OK` o `NULL` con `Estatus = 1` | cálculo de saldo |

Detalles relevantes del cálculo, verificados en el PA:

- El saldo se acumula desde el **31/12 del año anterior** a la fecha de ejecución; el año se toma de `getdate()`, no de un parámetro.
- Distingue tipo de centro de costo (`cod_tfondo`): para tipo 1 usa `saldo_prsp − saldo_comp`; para tipos 2 y 4 usa `saldo_prsp + saldo_perc − saldo_comp`.
- Trata aparte los ítems `31200` y `31201`.
- Suma **sobregiro** (`mto_sobreg`, `mto_sobre2`) solo si su fecha de vencimiento sigue vigente.
- El parámetro `@Afecta` se declara y se recibe, pero **no se usa** en el cuerpo del procedimiento.

### 2.3 Qué entrega `sg_cctosSecgen06`

Devuelve filas con `tipo_registro` en `ITEM`, `GENERAL` o `ERROR`, con `saldo_presupuesto`, `saldo_percibido`, `saldo_compromiso` y `saldo_disponible` por ítem y consolidado. Acepta `@fecha_eval` opcional — **es el único de los dos PA que admite fecha de evaluación explícita**. Se usa solo como panel informativo.

### 2.4 Estado real del saldo en la solicitud de resolución

Este es el hallazgo central del catastro:

| Aspecto | Estado real |
| :--- | :--- |
| Cálculo y despliegue del saldo | `ACTIVA` — se calcula por ítem con *debounce* de 700 ms y caché por clave |
| Bloqueo al enviar por falta de saldo | `APAGADA` |
| Mecanismo del apagado | `enableCostCenterBalanceSubmitValidation: false` en [PdsDu288RequestForm.vue:744](../../../sg-solicitudes-frontend/components/services-provision/PdsDu288RequestForm.vue:744) |
| Motivo declarado en el código | Reactivar "cuando Finanzas confirme el PA `fin21_db.Analisis.valida_saldo_cc_cs` ajustado y sus casos de prueba" |
| Código de bloqueo | Ya escrito: `validateCostCenterBalanceBeforeSubmit()` en [:2392](../../../sg-solicitudes-frontend/components/services-provision/PdsDu288RequestForm.vue:2392), push del error en [:6400](../../../sg-solicitudes-frontend/components/services-provision/PdsDu288RequestForm.vue:6400) y `:disabled` del botón enviar en [:240](../../../sg-solicitudes-frontend/components/services-provision/PdsDu288RequestForm.vue:240) |
| Mensaje asociado | `costCenterNoAvailableBalance` en [messages.js](../../../sg-solicitudes-frontend/utils/services-provision/normative/messages.js), con un TODO adicional que menciona permisos sobre `wf_sol2` / `wf_tra1` |

> No falta implementar el control de saldo: falta **habilitarlo** y que Finanzas certifique el PA. Para el flujo de pagos esto es una dependencia, no un desarrollo desde cero.

## 3. Brechas del saldo presupuestario para el flujo de pago

| # | Brecha | Efecto si no se resuelve |
| :---: | :--- | :--- |
| B1 | El PA no descuenta compromisos vivos del workflow SG | Dos solicitudes de pago pueden aprobar contra el mismo saldo |
| B2 | `valida_saldo_cc_cs` no recibe fecha de evaluación; usa `getdate()` | No se puede validar un periodo ejecutado contra el saldo de ese periodo |
| B3 | `decimal(15,2)` en el PA frente a `decimal(19,2)` del modelo objetivo | Truncamiento y descuadres en montos altos |
| B4 | `@Afecta` declarado y no usado | La interfaz cree estar declarando afectación presupuestaria y no lo hace |
| B5 | `cod_tipmov = 21` está fijo en la interfaz, no configurado ni confirmado por Finanzas | Un cambio normativo obliga a tocar el frontend |
| B6 | Ítem por defecto `'300'` cuando la fila no informa uno | Se puede validar contra un ítem que no corresponde |
| B7 | Sin tratamiento de `itm_global`, `cc_global`, `pry_global` | Proyectos con imputación global quedan fuera del control |
| B8 | Sin moneda en la agrupación (`cod_moneda` existe en `sg_fups`) | Agregación incorrecta si hay más de una moneda |
| B9 | La caché de saldo vive en el cliente | Un envío podría apoyarse en un saldo obsoleto si no se fuerza el recálculo |
| B10 | El sobregiro se suma según su vencimiento, sin dejar traza del hecho | Finanzas no puede auditar por qué un pago pasó con saldo negativo |
| B11 | El saldo se acumula desde el 31/12 del año anterior **a la fecha de hoy**, no a la de ejecución | Una cuota ejecutada en diciembre y pagada en enero se valida contra el presupuesto del año nuevo. Si el compromiso del ejercicio anterior no se arrastra, puede quedar sin fondos pese a haber tenido saldo al ejecutarse. Afecta directamente a MOD-10 |

## 4. Catastro de saldos que la solicitud de pago debe tener

| ID | Control | Fórmula o fuente | Momento | Severidad propuesta | Estado |
| :--- | :--- | :--- | :--- | :--- | :--- |
| SAL-01 | Saldo contractual del funcionario (S2) | `sg_fups.mto_total − pagado − comprometido en solicitudes vivas` | seleccionar, enviar, autorizar | bloqueo | POR CREAR |
| SAL-02 | Tope de la cuota (S3) | `tope aplicable` completo, sin descuento por cuotas anteriores; una cuota multi-mes consume un solo tope | enviar, DGDP, autorizar | bloqueo | POR CREAR |
| SAL-03 | Saldo de cuota y periodo (S4) | cuota no pagada ni comprometida; mes de ejecución no cubierto por otra cuota de la misma actividad | seleccionar, enviar | bloqueo | POR CREAR |
| SAL-04 | Saldo presupuestario efectivo (S1) | `valida_saldo_cc_cs` menos compromisos vivos del workflow SG | vista previa y autorización | bloqueo o pendiente de saldo | Parcial: PA y endpoint existen; falta el descuento SG |
| SAL-05 | Saldo por ítem y unidad financiera | agrupar por `cod_unifin + cod_ccto + cod_sitm + cod_moneda` | vista previa y autorización | bloqueo | Parcial: la agrupación existe sin moneda |
| SAL-06 | Máximo de **2 cuotas** por PDS + funcionario, ancladas al año de ejecución | conteo de cuotas vivas y pagadas de la actividad (MOD-02) | seleccionar, enviar, autorizar | bloqueo; liberado en ANID | POR CREAR |
| SAL-06b | La última cuota solo se paga terminada la ejecución | comparar cobertura con `sg_fups.f_termino` (MOD-09) | enviar | bloqueo | POR CREAR |
| SAL-06c | El mes de ejecución no puede repetirse en otra cuota de la misma actividad | cobertura persistida (MOD-07) | seleccionar, enviar | bloqueo | POR CREAR |
| SAL-07 | Sobregiro o capital de trabajo autorizado | resultado del PA, registrado como causal explícita | autorización | informativa con traza obligatoria | POR CREAR |
| SAL-08 | Recálculo sin caché dentro de la transacción | repetir SAL-01 a SAL-05 en el PA transaccional | enviar y autorizar | bloqueo | POR CREAR |
| SAL-09 | Anticoncurrencia sobre cuota y saldo | ninguna cuota comprometida dos veces en simultáneo | enviar y autorizar | bloqueo | POR CREAR |
| SAL-10 | Registro del resultado financiero | `nro_transac`, fecha efectiva, monto autorizado, saldo remanente | cierre del detalle | bloqueo al cerrar | POR CREAR |

### 4.1 Monto autorizable

```text
monto pagable de la cuota =
  MIN(
    SAL-02  tope aplicable, completo para esta cuota,
    SAL-01  monto total autorizado − pagado − comprometido,
    SAL-03  monto ajustado por licencia, permiso o ejecución parcial,
    SAL-04  saldo presupuestario efectivo
  )

sujeto a:  cuotas del año de ejecución ≤ 2      (sin límite si ANID)
           última cuota solo con la ejecución terminada
```

La vista previa puede calcularlo en pantalla. **El valor que se persiste debe recalcularse dentro de la transacción**, sin caché, tanto al enviar como al autorizar.

El tope entra completo y no descontado: si la primera cuota usó una fracción del tope, la segunda no hereda el remanente ni queda mermada por lo ya pagado. El monto solo se reduce por causales de ejecución, nunca por consumo de tope previo.

---

# PARTE II — CATASTRO DE VALIDACIONES DE LA SOLICITUD DE RESOLUCIÓN

Fuente del catálogo: [issueMeta.js](../../../sg-solicitudes-frontend/utils/services-provision/normative/issueMeta.js) (28 códigos con severidad) y el bloque `validation` de [messages.js](../../../sg-solicitudes-frontend/utils/services-provision/normative/messages.js).

## 5. Centro de costo, responsable y financiamiento

| ID | Validación | Fuente de dato | Severidad real | Estado |
| :--- | :--- | :--- | :--- | :--- |
| RES-CC-01 | Centro de costo obligatorio y asociado al responsable | `sg_cctosSecgen05` | error | BLOQUEA |
| RES-CC-02 | Centro de costo vigente | ficha del CC | error | BLOQUEA |
| RES-CC-03 | Responsable del CC vigente (`responsibleValidity = 'S'`) | `sp_orcosSecgen01` | error | BLOQUEA al enviar |
| RES-CC-04 | Financiamiento compatible con DU288 (`compatibleFinancing = 'S'`) | ficha del CC | error | BLOQUEA al enviar |
| RES-CC-05 | Formación Continua excluida (`isContinuingEducation = 'S'`) | ficha del CC | error | BLOQUEA al enviar y deshabilita la selección |
| RES-CC-06 | Flujo DU288 configurado para el CC | `sg_flusSecgen01` | error | BLOQUEA |
| RES-CC-07 | Saldo disponible del CC | `valida_saldo_cc_cs` | error | **APAGADA** (ver §2.4) |
| RES-CC-08 | Saldo por ítem, panel informativo | `sg_cctosSecgen06` | informativa | INFORMA |

## 6. Funcionario, contrato y cargo

| ID | Validación | Fuente de dato | Severidad real | Estado |
| :--- | :--- | :--- | :--- | :--- |
| RES-FU-01 | Funcionario obligatorio | `sp_perssSecgen02` | error | BLOQUEA |
| RES-FU-02 | Exactamente un funcionario por solicitud DU288 | regla de negocio | error | BLOQUEA |
| RES-FU-03 | Sin funcionarios duplicados ni identificadores repetidos | regla de negocio | error | BLOQUEA |
| RES-FU-04 | Contrato seleccionado con información laboral válida | `sg_fupssSecgen16` | error | BLOQUEA |
| RES-FU-05 | Contrato vigente o en trámite | `sg_fupssSecgen16` | error | BLOQUEA |
| RES-FU-06 | Contrato con horas válidas informadas | `sg_fupssSecgen16` | error | BLOQUEA |
| RES-FU-07 | El contrato cubre el rango de ejecución (`CONTRATO_NO_CUBRE_RANGO`) | fechas del contrato | error | BLOQUEA |
| RES-FU-08 | El contrato cubre los meses de ejecución (`CONTRATO_NO_CUBRE_MESES`) | fechas del contrato | error | BLOQUEA |
| RES-FU-09 | El contrato persistido sigue disponible y vigente | comparación con la ficha vigente | error | BLOQUEA al editar |
| RES-FU-10 | El cargo persistido coincide con el vigente (`CARGO_CONTRATO_MODIFICADO`) | comparación con la ficha vigente | **advertencia** | INFORMA |

## 7. Inhabilidades

| ID | Validación | Fuente de dato | Severidad real | Estado |
| :--- | :--- | :--- | :--- | :--- |
| RES-IN-01 | Cargo o contrato habilitado (`habilitado_du288 = S/N`) | `sg_fupssSecgen14` | error | BLOQUEA |
| RES-IN-02 | Ningún contrato del funcionario inhabilitado | `sg_fupssSecgen14` | error | BLOQUEA |
| RES-IN-03 | Ninguna asignación o designación vigente inhabilitante | `sg_fupssSecgen15` | error | BLOQUEA |
| RES-IN-04 | Habilitación de cargo o asignación no confirmable | `sg_fupssSecgen14/15` | pendiente | BLOQUEA |
| RES-IN-05 | Asignación próxima a vencer (30 días) | `sg_fupssSecgen15` | advertencia | INFORMA |
| RES-IN-06 | Parentesco con incompatibilidad absoluta (`requiereConstancia = 'N'`) | `sg_fupssSecgen12` vía `GET /normative/check-relationship` | error | BLOQUEA |
| RES-IN-07 | Parentesco que requiere constancia (`requiereConstancia = 'S'`) | `sg_fupssSecgen12` | informativa | **DIFERIDA AL PAGO** |
| RES-IN-08 | Deuda institucional no regularizada | campo del perfil (`sg_fupssSecgen16`) | error si viene informada | SIN FUENTE — sin dato queda `pending` y no bloquea |

## 8. Tope, haberes y monto

| ID | Validación | Fuente de dato | Severidad real | Estado |
| :--- | :--- | :--- | :--- | :--- |
| RES-TO-01 | Tope mensual disponible y válido | `sg_fupssSecgen13`, `funps13` | error | BLOQUEA |
| RES-TO-02 | Tope especial por cargo o contrato | `sg_tocasSecgen01` vía `GET /normative/staff-position-cap` | error | BLOQUEA |
| RES-TO-03 | Monto mensual dentro del tope aplicado (`TOPE_EXCEDIDO`) | comparación en UI | error | BLOQUEA |
| RES-TO-04 | Haberes del mes anterior disponibles | `sg_fupssSecgen13` | error | BLOQUEA |
| RES-TO-05 | Excepción ANID: se ignora el tope del 50 % | marca del CC y certificación DIUFRO/DITT | informativa | ACTIVA |
| RES-TO-06 | Monto mayor que cero y no negativo | formulario | error | BLOQUEA |
| RES-TO-07 | Factibilidad: el monto requeriría más de 2 meses de pago | cálculo en UI | advertencia | INFORMA |
| RES-TO-08 | Prestaciones previas del funcionario | `sg_fupssSecgen17` vía `GET /normative/staff-previous-provisions` | informativa | INFORMA |

## 9. Jornada, compensación y carga horaria

| ID | Validación | Fuente de dato | Severidad real | Estado |
| :--- | :--- | :--- | :--- | :--- |
| RES-JO-01 | Modalidad de jornada obligatoria | formulario | error | BLOQUEA |
| RES-JO-02 | Compensación obligatoria según estamento, SEA y modalidad | `sg_fupssSecgen13` (`numHoras > 11`) | error | BLOQUEA |
| RES-JO-03 | Compensación total completa respecto de lo exigido | cálculo en UI | error | BLOQUEA |
| RES-JO-04 | Fecha y horas obligatorias por tramo | formulario | error | BLOQUEA |
| RES-JO-05 | Tramos sin solapamiento ni duplicados | `formatters.js` | error | BLOQUEA |
| RES-JO-06 | Fecha del tramo dentro del periodo habilitado | `formatters.js` | error | BLOQUEA |
| RES-JO-07 | Compensación fuera de la jornada institucional 08:30–17:18 | `compensationOverlapsInstitutionalWorkday` | error | BLOQUEA |
| RES-JO-08 | Límite de 12 horas diarias | `getCompensationWorkloadEvaluation` | error | BLOQUEA |
| RES-JO-09 | Límite de 56 horas semanales (`totHoras + hrsHonor + prestación`) | `sg_fupssSecgen13` + PDS activas | error | BLOQUEA |
| RES-JO-10 | Distribución horaria de ejecución obligatoria y consistente | `sg_fuhosSecgen01` | error | BLOQUEA |
| RES-JO-11 | La distribución no supera el cupo semanal disponible | cálculo en UI | error | BLOQUEA |

## 10. Periodo y actividad

| ID | Validación | Fuente de dato | Severidad real | Estado |
| :--- | :--- | :--- | :--- | :--- |
| RES-PE-01 | Fechas de inicio y término obligatorias y coherentes | formulario | error | BLOQUEA |
| RES-PE-02 | El periodo no cruza a otro año calendario | formulario | error | BLOQUEA |
| RES-PE-03 | El periodo no excede 12 meses | formulario | error | BLOQUEA |
| RES-PE-04 | El periodo del funcionario está contenido en el periodo general | formulario | error | BLOQUEA |
| RES-PE-05 | Actividad descrita con al menos 10 caracteres | formulario | error | BLOQUEA |
| RES-PE-06 | Similitud textual con prestaciones anteriores (umbral 0.6) | [textSimilarityUtil.js:218](../../../sg-solicitudes-frontend/utils/textSimilarityUtil.js:218) | informativa | INFORMA |

## 11. Flujo, permisos y trazabilidad

| ID | Validación | Fuente de dato | Severidad real | Estado |
| :--- | :--- | :--- | :--- | :--- |
| RES-FL-01 | Perfil y privilegio del usuario sobre PDS | `sg_usacsSecgen01` | error | BLOQUEA |
| RES-FL-02 | Responsable de etapa resoluble | `sg_etasSecgen01`, `sp_orcosSecgen01` | error | BLOQUEA |
| RES-FL-03 | Transición configurada y permitida | `sg_eta2sSecgen01`, `sg_prseuSecgen03` | error | BLOQUEA |
| RES-FL-04 | Tareas pendientes de la etapa cerradas correctamente | `sg_apsouSecgen02`, `sg_apsosSecgen05` | error | BLOQUEA |
| RES-FL-05 | Historial obligatorio de cada acción | `sg_histiSecgen03` | — | ACTIVA |

## 12. Controles declarados sin fuente integrada

Registrados explícitamente como pendientes en [reglas_restricciones_du288_d09.md](../../reglas/reglas_restricciones_du288_d09.md) §4.1. Fueron retirados de la interfaz para no generar ruido y **no bloquean** la solicitud:

| Control | Fuente esperada | Dónde debe vivir |
| :--- | :--- | :--- |
| Deudas institucionales (fondo crédito, fondos por rendir) | SISPER / Finanzas | Pago, con inhabilidad absoluta desde 2027-01-01 |
| Licencias médicas | SISPER | Pago, por periodo cubierto |
| Permisos sin goce de sueldo | SISPER | Pago, por periodo cubierto |
| Receso universitario | Calendario institucional | Pago, con acreditación de trabajo efectivo |
| Detalle de excepciones ANID certificadas | DIUFRO / DITT | Resolución, heredado por el pago |
| Saldo presupuestario por ítem y etapa | FIN21 | Ambos; en pago es obligatorio |
| Similitud de funciones con el contrato base | Manual / jefatura | Resolución |

---

# PARTE III — CATASTRO DE VALIDACIONES DE LA SOLICITUD DE PAGO

Todo lo de esta parte está en estado `POR CREAR`, salvo lo que se indique. La clasificación de origen (heredada, revalidada, adaptada o nueva) está en el [documento 8](./8_matriz_validaciones_resolucion_a_pago.md); aquí se lista **por momento del flujo**, que es como debe implementarse.

## 13. PP01 — Buscar PDS y armar el borrador

| ID | Control | Origen | Severidad propuesta |
| :--- | :--- | :--- | :--- |
| PAG-01 | La PDS está formalizada y con resolución vigente | nuevo | bloqueo |
| PAG-02 | El usuario tiene autorización sobre el centro de costo de la PDS | RES-CC-03 revalidado | bloqueo |
| PAG-03 | El centro de costo sigue vigente y no está cerrado ni bloqueado | RES-CC-02 + PA saldo | bloqueo |
| PAG-04 | Existe al menos un funcionario con saldo contractual pagable | SAL-01 | filtra la PDS |
| PAG-05 | La cuota está disponible: no pagada ni comprometida | SAL-03 | bloqueo de selección |
| PAG-06 | El periodo cubierto está dentro de `sg_fups.f_inicio`–`f_termino` | RES-PE-04 adaptado | bloqueo |
| PAG-07 | El contrato evaluado cubre el periodo que se paga | RES-FU-07/08 adaptados | bloqueo |
| PAG-08 | Monto solicitado mayor que cero | RES-TO-06 | bloqueo |
| PAG-09 | Monto dentro del saldo contractual | SAL-01 | bloqueo |
| PAG-10 | Monto dentro del tope de la cuota, tomado completo y sin descuento por cuotas anteriores | SAL-02, MOD-04, MOD-05 | bloqueo |
| PAG-11 | Evidencia obligatoria adjunta según catálogo | nuevo | bloqueo al enviar |
| PAG-12 | Vista previa de saldo presupuestario por ítem | SAL-04/05 — endpoint ya existe | informativa |
| PAG-13 | El periodo cubierto no fue pagado antes ni está cubierto por otra cuota de la actividad | SAL-03, SAL-06c | bloqueo |
| PAG-14 | Máximo de 2 cuotas por PDS + funcionario en el año de ejecución | SAL-06 | bloqueo; liberado en ANID |
| PAG-15 | La última cuota solo se envía con la ejecución terminada | SAL-06b | bloqueo |
| PAG-16 | Dos cuotas en el mismo mes de pago solo por atraso administrativo | MOD-08 | advertencia con causal registrada |
| PAG-17 | Una PDS por solicitud, un funcionario por solicitud, sin mezclar CC, proyecto, ítem ni moneda | A03, A05, A10 | bloqueo |
| PAG-18 | Recompromiso de compensación faltante cuando la comprometida en la PDS no se cumplió | C15, nota de cierre del bloque C | habilita la revalidación |

## 14. Control de ejecución — Jefatura

**Descartada.** E06 resuelve S0-008 en negativo: la Jefatura Directa no participa del flujo de pagos, a diferencia del flujo de solicitud de resolución. No existe etapa de certificación de ejecución previa a DGDP. La acreditación de la ejecución se resuelve por evidencia documental (PAG-11) y, en la compensación, por contraste con marcaje (PAG-38).

## 15. PP02 — DGDP, control normativo dinámico

| ID | Control | Origen | Severidad propuesta |
| :--- | :--- | :--- | :--- |
| PAG-30 | Cargo o contrato habilitado a la fecha de pago | RES-IN-01/02 revalidados | bloqueo |
| PAG-31 | Sin asignación inhabilitante vigente durante el periodo pagado | RES-IN-03 adaptado | bloqueo |
| PAG-32 | Constancia jurada de parentesco presentada | RES-IN-07, diferida desde la resolución | bloqueo |
| PAG-33 | Sin licencia médica en el periodo cubierto | nuevo, sin fuente integrada | bloqueo, según decisión de fuente |
| PAG-34 | Sin permiso sin goce de sueldo en el periodo cubierto | nuevo, sin fuente integrada | bloqueo |
| PAG-35 | Receso universitario no pagado salvo trabajo efectivo acreditado | nuevo | bloqueo con acreditación |
| PAG-36 | Proyecto vigente y no cerrado al momento de la ejecución | nuevo | bloqueo |
| PAG-37 | Sin deuda institucional no regularizada (desde 2027-01-01) | RES-IN-08 revalidado | bloqueo desde esa fecha |
| PAG-38 | La compensación comprometida se acreditó como ejecutada, contrastada contra **marcaje biométrico y registro de reloj** | RES-JO-03 adaptado (`sg_fuc2`) | bloqueo, con vía alternativa para quien no tiene marcaje obligatorio |
| PAG-38b | Si la compensación no se cumplió o está incompleta, se vuelven a comprometer **solo los tramos faltantes** y la solicitud se revalida | C15, nota de cierre del bloque C | habilita corrección sin rehacer la solicitud |
| PAG-38c | Las reglas horarias se reaplican sobre los tramos nuevos: solapamiento, duplicados, jornada institucional, 12 h diarias y 56 h semanales | RES-JO-04 a RES-JO-09 adaptados | bloqueo |
| PAG-39 | La actividad pagada no es formación continua | RES-CC-05 sobre el contenido de la evidencia | bloqueo |
| PAG-40 | Ajuste proporcional por ausencias en el periodo | nuevo | advertencia con ajuste de monto |
| PAG-41 | Cambio de cargo o contrato posterior a la resolución | RES-FU-09/10 revalidados | severidad por decidir |

## 16. PP03 — Finanzas

| ID | Control | Origen | Severidad propuesta |
| :--- | :--- | :--- | :--- |
| PAG-50 | Solo se evalúan detalles aprobados por DGDP y vigentes | nuevo | filtro |
| PAG-51 | Recálculo de saldo presupuestario sin caché, agrupado por `cod_unifin + cod_ccto + cod_sitm + cod_moneda` | SAL-04/05 | bloqueo o pendiente de saldo |
| PAG-52 | Descuento de compromisos vivos del workflow SG | SAL-04, brecha B1 | bloqueo |
| PAG-53 | Sobregiro o capital de trabajo registrado como causal explícita | SAL-07 | traza obligatoria |
| PAG-54 | Monto autorizado menor o igual al monto autorizable | §4.1 | bloqueo |
| PAG-55 | Autorización parcial con motivo obligatorio | nuevo | bloqueo del cierre sin motivo |
| PAG-56 | Falta de saldo tratada como estado temporal reintentable, **devuelta a DGDP y no al solicitante** | E05, E11 | pendiente de saldo |
| PAG-57 | Registro obligatorio de `nro_transac` y fecha efectiva al cerrar | SAL-10 | bloqueo del cierre |
| PAG-58 | Anticoncurrencia: la cuota no puede comprometerse dos veces | SAL-09 | bloqueo |
| PAG-59 | Cierre global derivado de los detalles, nunca digitado | nuevo | regla de sistema |

## 17. Transversales de todo el expediente

| ID | Control | Severidad propuesta |
| :--- | :--- | :--- |
| PAG-70 | Historial obligatorio: actor, perfil, acción, estado anterior y nuevo, fecha, observación | regla de sistema |
| PAG-71 | La evidencia se versiona lógicamente; reemplazar no borra el respaldo anterior | regla de sistema |
| PAG-72 | Los antecedentes de la PDS son de solo lectura en todo el flujo | bloqueo de edición |
| PAG-73 | Toda validación monetaria se repite en el PA transaccional | regla de sistema |
| PAG-74 | Ningún código sin entrada en el catálogo se muestra como etiqueta al usuario | regla de presentación |

---

# PARTE IV — RESUMEN POR MOMENTO

| Momento | Saldos que se evalúan | Bloque de validaciones |
| :--- | :--- | :--- |
| Buscar PDS | S2, S4 | PAG-01 a PAG-04, PAG-17 |
| Armar borrador | S2, S3, S4 y vista previa de S1 | PAG-05 a PAG-13 |
| Enviar | S1, S2, S3, S4 recalculados en transacción | PAG-08 a PAG-18, PAG-73 |
| DGDP | S3 | PAG-30 a PAG-41 |
| Finanzas | S1, S2, S3, S4 recalculados en transacción | PAG-50 a PAG-58 |
| Cierre | resultado registrado | PAG-57, PAG-59 |

Las cuotas se materializan en `sg_fume` en el paso **Enviar** (MOD-12): antes de ese momento el borrador no tiene cuotas creadas y por tanto no compromete cupo, tope ni presupuesto.

---

# PARTE V — DEPENDENCIAS Y DECISIONES

## 18. Dependencias externas

| # | Dependencia | Bloquea |
| :---: | :--- | :--- |
| D1 | Finanzas certifica `valida_saldo_cc_cs` y sus casos de prueba | SAL-04, y la reactivación de RES-CC-07 |
| D2 | Confirmación de `cod_tipmov = 21` | SAL-04, SAL-05 |
| D3 | Fuente maestra de licencias y permisos sin goce. G01 indica que el dato existe en alguna base, pero aún no está identificada | PAG-33, PAG-34 |
| D4 | Fuente de deuda institucional | RES-IN-08, PAG-37 |
| D5 | Calendario institucional de receso | PAG-35 |
| D6 | Catálogo documental aprobado | PAG-11 |
| D7 | Permisos sobre `wf_sol2` / `wf_tra1` | control de saldo con detalle de compromisos |
| D8 | **Sistema de control de asistencia: marcaje biométrico y reloj.** Fuente distinta de SISPER, no inventariada en ninguna integración actual | PAG-38 |
| D9 | Campo maestro del centro de costo que identifica ANID, DITT, VRIP y equivalentes. D02 lo deja pendiente de nombrar | MOD-11, RES-TO-05 |
| D10 | Criterio de arrastre del compromiso presupuestario entre ejercicios | MOD-10, brecha B11 |

## 18.1 Decisiones ya cerradas en S0-013

| Decisión | Respuesta | Efecto en este catastro |
| :--- | :--- | :--- |
| Unidad de pago | Una PDS + un funcionario + una o varias cuotas | PAG-17 |
| Momento de creación de la cuota | Al enviar, eliminable solo si nunca se envió | MOD-12 |
| Límite de pagos | 2 cuotas por PDS + funcionario, no 2 meses | MOD-02, SAL-06 |
| Aplicación del tope | Por cuota, completo, sin arrastre | MOD-04, MOD-05, SAL-02 |
| Cruce de año | El mes de pago puede caer en el año siguiente y no consume cupo | MOD-10 |
| Jefatura Directa | No participa | §14 descartada |
| Devolución de Finanzas | Va a DGDP, no al solicitante | PAG-56 |
| Evento habilitante | PDS con resolución archivada y vigente | PAG-01 |
| Compensación en pago | Se recompromete solo lo faltante y se verifica contra marcaje | PAG-38, PAG-38b, PAG-38c |
| ANID | Se identifica por centro de costo, sin certificado; libera tope y límite de cuotas | MOD-11 |
| Etapa de archivo | No existe; el expediente termina en pagado | — |

## 19. Decisiones que este catastro deja al descubierto

1. **El saldo presupuestario no bloquea hoy en resolución.** Debe decidirse si el pago se lanza con el control activo desde el inicio, o replicando el mismo apagado transitorio. Sin esa decisión, `SAL-04` no tiene severidad definible.
2. **`cod_tipmov = 21` está fijo en el frontend.** Debe confirmarse con Finanzas y moverse a configuración antes de replicarlo en pagos.
3. **El ítem por defecto `'300'`** no puede heredarse a pagos sin validar contra `sg_fups.cod_sitm` real.
4. **Falta la fecha de evaluación en `valida_saldo_cc_cs`.** `sg_cctosSecgen06` sí la acepta. Debe decidirse si se ajusta el PA de FIN21 o se valida siempre contra el saldo del día.
5. **Compromisos del workflow SG.** Mientras el PA no los descuente, el control anticoncurrencia (`SAL-09`) debe resolverse íntegramente en el PA transaccional de SecGen.
6. **Moneda.** `sg_fups.cod_moneda` existe pero no participa de la agrupación actual. Debe confirmarse si el flujo admite más de una moneda.
7. **Tope congelado o recalculado**, ya planteado en el documento 8 §6.1: define la fuente de `SAL-02`. Corresponde a C13, sin responder. Con dos cuotas separadas por varios meses, congelar o recalcular arroja montos distintos.
8. **Ratificación normativa del modelo de cuotas.** Expresar el límite del D.U. 9 como "2 cuotas" en vez de "2 meses de pago" es una interpretación. Es siempre igual o más restrictiva que la regla literal —dos cuotas nunca caen en más de dos meses—, pero debe quedar ratificada por escrito por DGDP o jurídica antes de implementarse.
9. **Acreditación de la excepción ANID.** El texto normativo admite superar los dos meses "salvo excepción normativa acreditada", mientras que D11 establece que no se cargará certificado. Debe quedar escrito que el campo del centro de costo **es** esa acreditación, y quién responde por mantenerlo (ver D9).
10. **Plazo máximo de pago retroactivo** (M1) y **arrastre presupuestario entre ejercicios** (M2/D10): sin ambos, MOD-10 no es implementable con seguridad.
11. **Acreditación de compensación para quien no marca reloj.** El contraste biométrico de PAG-38 no aplica al personal académico sin marcaje obligatorio; se requiere vía alternativa o una regla de alcance.
12. **Facultad de edición de DGDP.** B07 propone que DGDP pueda corregir la solicitud, mientras F07 y E09 dejan la edición en el solicitante. Si DGDP edita montos, cambia el modelo de segregación que E07 declara querer mantener.

## 20. Criterio de cierre

El catastro queda cerrado cuando cada fila `POR CREAR` tenga fuente de dato confirmada, severidad aprobada y capa de ejecución asignada; y cuando las dependencias D1 a D7 tengan responsable y fecha.
