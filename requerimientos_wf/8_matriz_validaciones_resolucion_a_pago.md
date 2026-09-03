# Matriz de validaciones — de la solicitud de resolución al flujo de pagos

**Versión:** 0.2 de levantamiento
**Fecha:** 2026-09-02
**Estado:** actualizada con las respuestas registradas en la tarjeta ClickUp [S0-013](https://app.clickup.com/t/86e2zrkh4). Las clasificaciones que no dependen de esas respuestas siguen sin aprobar.
**Ámbito:** D.U. 009/2026, DU288/DU09

## 1. Propósito

El flujo de pagos debe aplicar "las mismas reglas" de la solicitud de resolución, pero *aplicar* no significa *repetir*. Una parte de esas reglas ya quedó resuelta y congelada al formalizar la PDS; otra parte debe volver a ejecutarse con la fecha del pago; y otra no existe todavía porque solo tiene sentido cuando hay dinero, periodo ejecutado y transacción.

Este documento inventaria **las validaciones efectivamente implementadas hoy** en el flujo de resolución, con su fuente verificable, y declara qué hace el flujo de pagos con cada una. Reemplaza cualquier lista informal previa de "reglas heredadas".

No es un documento de diseño técnico: no define el DDL ni el PA. Alimenta a [0_requerimientos_cu_pa_bdd_segun_wf_pagos.md](./0_requerimientos_cu_pa_bdd_segun_wf_pagos.md) §11 y a las preguntas H, I, J, K y L de [S0-013](./cuestionario_maestro_clickup_s0_013.md).

## 2. Clasificación usada

| Marca | Significado | Consecuencia en pago |
| :---: | :--- | :--- |
| **H** | Heredada como antecedente inmutable | Se muestra como dato PDS, no se re-evalúa ni se puede editar |
| **R** | Revalidada | Misma regla, ejecutada de nuevo con la fecha del pago y el periodo cubierto |
| **A** | Adaptada | Misma intención normativa, distinto objeto: ya no el rango autorizado sino el periodo o la cuota que se paga |
| **X** | No aplica | Propia del acto de crear la PDS; repetirla convertiría el pago en una segunda resolución |
| **N** | Nueva | Exclusiva del pago; no existe en el flujo de resolución |

Capa de ejecución:

| Capa | Rol | Autoridad |
| :--- | :--- | :--- |
| `UI` | Previsualización y guía al usuario | No autoritativa; nunca es la última palabra |
| `API` | Consulta a PA normativos y armado del resultado | Intermedia; puede usar caché controlada |
| `PA-TX` | Procedimiento transaccional al enviar, aprobar y autorizar | **Autoritativa**; sin caché, dentro de la transacción |

Regla general del flujo de pagos: **toda validación monetaria o de disponibilidad debe repetirse en `PA-TX`**, aunque ya se haya mostrado en `UI`.

## 3. Fuentes verificadas

Catálogo de reglas y severidades ya implementado en resolución:

- Códigos y severidad: [issueMeta.js](../../../sg-solicitudes-frontend/utils/services-provision/normative/issueMeta.js:1) — 28 códigos con `severity` `error` / `warning` / `pending`.
- Textos y reglas: [messages.js](../../../sg-solicitudes-frontend/utils/services-provision/normative/messages.js:19) — bloques `validation` y `normative`.
- Evaluación de carga horaria y compensación: [formatters.js](../../../sg-solicitudes-frontend/utils/services-provision/normative/formatters.js:527).
- Puntos de aplicación en el formulario: [56 horas semanales](../../../sg-solicitudes-frontend/components/services-provision/PdsDu288RequestForm.vue:5358), [formación continua](../../../sg-solicitudes-frontend/components/services-provision/PdsDu288RequestForm.vue:5385), [cargo inhabilitado](../../../sg-solicitudes-frontend/components/services-provision/PdsDu288RequestForm.vue:5397), [bloqueo al enviar](../../../sg-solicitudes-frontend/components/services-provision/PdsDu288RequestForm.vue:6398).

Procedimientos normativos vigentes:

| PA | Objetivo verificado | Uso en pago |
| :--- | :--- | :--- |
| `sg_fupssSecgen12` | Parentesco activo con el jefe de proyecto | Revalidar y exigir constancia |
| `sg_fupssSecgen13` | Contrato principal, haberes y tope DU288 | Decisión abierta: tope congelado o recalculado |
| `sg_fupssSecgen14` | Habilitación del contrato/cargo (`habilitado_du288 = S/N`) | Revalidar a la fecha de pago |
| `sg_fupssSecgen15` | Asignaciones o designaciones vigentes inhabilitantes | Revalidar sobre el periodo cubierto |
| `sg_fupssSecgen17` | Prestaciones de servicio previas del funcionario | Base de acumulado y duplicidad |
| `sg_tocasSecgen01` | Tope especial por contrato | Igual que `sg_fupssSecgen13` |
| `sg_cctosSecgen06` | Saldo consolidado por ítem y centro de costo | Vista previa de saldo |
| `valida_saldo_cc_cs` | Saldo o sobregiro en FIN21 | Control presupuestario obligatorio |

Normativa: [reglas_restricciones_du288_d09.md](../../reglas/reglas_restricciones_du288_d09.md), D.U. 009/2026, Res. Ex. 1194/2026 y Res. Ex. 1265/2026.

## 4. Matriz A — validaciones existentes en resolución

### 4.1 Centro de costo, financiamiento y flujo

| Código actual | Regla implementada hoy | Clase | Qué hace el pago | Capa |
| :--- | :--- | :---: | :--- | :--- |
| `requiredCostCenter` | Debe seleccionarse un CC asociado al responsable | **X** | El CC llega desde `sg_prse`; no se elige | — |
| `costCenterNotCurrent` | El CC debe estar vigente | **R** | El CC de la PDS debe seguir vigente al pagar | PA-TX |
| `responsibleNotCurrent` | El responsable del CC debe estar vigente | **R** | Quien solicita el pago debe estar vigente y habilitado sobre ese CC | API + PA-TX |
| `incompatibleFinancing` | Financiamiento incompatible con DU288 | **R** | Prohibición estructural del D.U. 9: no pagar con presupuesto de base | PA-TX |
| `continuingEducation` | CC de Formación Continua bloquea la solicitud | **H** + **N** | Heredado a nivel de CC; nuevo control sobre el *contenido* de la evidencia (no pagar clases de diplomado por esta vía) | UI + DGDP |
| `requiredWorkflow` | El CC debe tener flujo DU288 configurado | **A** | El CC debe tener **flujo de pago** configurado | API |
| `costCenterNoAvailableBalance` | Implementado de extremo a extremo pero **apagado** por bandera `enableCostCenterBalanceSubmitValidation: false` | **A** | En pago es **obligatorio y bloqueante**; ver §5 | PA-TX |

> El control de saldo existe completo en resolución —PA, endpoint, agrupación por ítem, mensaje y botón deshabilitado— pero hoy solo informa: la bandera de bloqueo está en `false` a la espera de que Finanzas certifique el PA `valida_saldo_cc_cs`. Para pagos esto es una **dependencia por habilitar**, no un desarrollo desde cero. El detalle de la cadena completa está en [9_catastro_validaciones_y_saldos.md](./9_catastro_validaciones_y_saldos.md) §2.

### 4.2 Funcionario, contrato y vigencia contractual

| Código actual | Regla implementada hoy | Clase | Qué hace el pago | Capa |
| :--- | :--- | :---: | :--- | :--- |
| `selectContract`, `invalidContractInfo`, `invalidContractStatus`, `invalidContractHours` | Selección y validez del contrato evaluado | **X** | El contrato evaluado quedó congelado en `sg_fups.cod_contra`; el pago no vuelve a elegir contrato | — |
| `CONTRATO_NO_CUBRE_RANGO` | El contrato debe cubrir el rango de ejecución | **A** | Debe cubrir el **periodo ejecutado que se paga**, no el rango completo | PA-TX |
| `CONTRATO_NO_CUBRE_MESES` | El contrato debe cubrir los meses de ejecución | **A** | Se evalúa contra los periodos declarados en la cuota | PA-TX |
| `persistedContractUnavailable`, `persistedContractNotCurrent` | El contrato guardado dejó de estar disponible o vigente | **R** | **Pregunta abierta:** ¿bloquea el pago de trabajo ya ejecutado, o solo advierte? | PA-TX |
| `CARGO_CONTRATO_MODIFICADO` / `persistedPositionChanged` | El cargo vigente difiere del guardado (hoy `warning`) | **R** | Debe decidirse la severidad en pago: un cambio de cargo puede activar una inhabilidad | DGDP |
| `duplicatedWorker`, `singleStaffOnly`, `duplicatePersistedIds` | Unicidad de funcionarios en la solicitud | **X** | La nómina viene de la PDS. Se reemplaza por la unicidad de **detalle**: una cuota no puede estar viva en dos solicitudes de pago | PA-TX |
| `corruptSummary`, `incompleteSummaryStaff` | Integridad del resumen antes de guardar | **A** | Integridad del detalle de pago antes de enviar | UI + API |

### 4.3 Inhabilidades por cargo, asignación, parentesco y deuda

| Código actual | Regla implementada hoy | Clase | Qué hace el pago | Capa |
| :--- | :--- | :---: | :--- | :--- |
| `CARGO_INHABILITADO_DU288` / `disabledPosition` / `anyContractDisabled` | `sg_fupssSecgen14` inhabilita el contrato o cargo | **R** | **Obligatorio revalidar:** entre la resolución y el pago la persona pudo asumir un cargo inhabilitante (Decano, Contraloría, directivo) | PA-TX |
| `ASIGNACION_DU288_INHABILITADA` / `anyAssignmentDisabled` | `sg_fupssSecgen15` detecta designación vigente inhabilitante | **A** | Se evalúa la vigencia de la asignación **durante el periodo ejecutado**, no solo a la fecha de hoy | PA-TX |
| `VALIDACION_CARGO_PENDIENTE`, `anyAssignmentPending` | La habilitación no pudo confirmarse; hoy bloquea | **R** | Mantener el bloqueo: no se paga sobre una habilitación no confirmada | PA-TX |
| `ASIGNACION_PROXIMA_VENCER` | Advertencia a 30 días del vencimiento | **A** | En pago no interesa el vencimiento futuro sino la cobertura del periodo pagado | UI |
| Parentesco (`sg_fupssSecgen12`) | Bloquea solo `requiereConstancia = 'N'`. Los casos `'S'` quedaron **explícitamente diferidos a la etapa de pago** | **N** | El pago debe exigir la constancia jurada firmada como evidencia obligatoria antes de autorizar | DGDP + PA-TX |
| `DEUDA_INSTITUCIONAL` / `debtDetected` | Deuda institucional no regularizada | **R** | Inhabilidad absoluta desde **2027-01-01**; antes de esa fecha, advertencia | PA-TX |
| `DEUDA_VALIDACION_PENDIENTE` | Fuente de deuda no disponible | **R** | Decidir si "pendiente" bloquea el pago o solo lo observa | DGDP |

> El caso de parentesco es el único donde la resolución **delegó formalmente** una validación al flujo de pagos. Si el pago no la implementa, la regla queda sin ejecutar en todo el sistema.

### 4.4 Tope, haberes y monto

| Código actual | Regla implementada hoy | Clase | Qué hace el pago | Capa |
| :--- | :--- | :---: | :--- | :--- |
| `TOPE_EXCEDIDO` | Monto mensual mayor al tope aplicable | **A** | Se evalúa **por cuota**: cada cuota dispone del tope completo, no se arrastra ni se descuenta entre cuotas, y una cuota que cubre varios meses consume un solo tope | PA-TX |
| `TOPE_FALTANTE` / `TOPE_NO_CONFIGURADO` / `missingTop` | Sin tope válido disponible | **R** | Bloquea igual que hoy | PA-TX |
| `REMUNERACION_FALTANTE`, `REMUNERACION_MES_NO_DISPONIBLE` | Haberes del mes anterior no disponibles | **R** | Depende de la decisión de §6.1 | API |
| `capExemptAnid` | Excepción ANID: se ignora el tope del 50 % | **H** | La certificación DIUFRO/DITT quedó acreditada en la PDS; el pago la hereda y solo revalida vigencia del proyecto | UI |
| `topExceededPaymentMonths` | Simulación: el monto requeriría más de 2 meses de pago | **A** | En resolución ya opera como techo: impide autorizar un monto que exceda dos topes. En pago se expresa como **máximo 2 cuotas** por PDS y funcionario, ancladas al año de ejecución y liberadas en ANID | PA-TX |
| `amountGreaterThanZero`, `negativeAmount` | Monto mayor que cero | **R** | Sobre el monto solicitado del detalle | UI + PA-TX |

### 4.5 Jornada, compensación y carga horaria

| Código actual | Regla implementada hoy | Clase | Qué hace el pago | Capa |
| :--- | :--- | :---: | :--- | :--- |
| `COMPENSACION_JORNADA` / `requiredCompensation` | Exigencia de compensación según estamento, SEA y modalidad | **H** | El compromiso quedó fijado en la PDS | UI |
| `COMPENSACION_TOTAL_INCOMPLETA` / `totalCompensationMismatch` | La compensación registrada debe cubrir lo exigido | **H** + **N** | Heredado como compromiso; **nuevo**: acreditar que la compensación se *ejecutó* en el periodo pagado (`sg_fuc2`) | DGDP |
| `compensationTimeOverlap`, `compensationTimeDuplicate`, `compensationDateOutOfPeriod`, `compensationOverlapWorkday` | Consistencia de tramos y jornada institucional 08:30–17:18 | **A** | Se reaplican sobre los tramos recomprometidos en el pago | UI + PA-TX |
| `LIMITE_DIARIO_EXCEDIDO` | Límite de 12 horas diarias | **A** | Igual que el anterior | UI + PA-TX |
| `LIMITE_SEMANAL_EXCEDIDO` | `totHoras + hrsHonor + prestación ≤ 56` | **A** | Se revalida sobre los tramos nuevos; el compromiso original no se recalcula | UI + PA-TX |
| `HORARIO_EJECUCION_JORNADA`, `executionSchedule*` | Distribución horaria de ejecución | **H** | Antecedente | — |

> **Decisión tomada (S0-013, cierre del bloque C):** el pago **sí** registra compensación. Cuando la comprometida en la PDS no se cumplió o quedó incompleta, se vuelven a comprometer **solo los tramos faltantes** y con eso la solicitud se revalida. Por lo tanto todas las reglas horarias pasan a **A** y deben reimplementarse en el flujo de pago, no solo mostrarse.
>
> Se agrega además una verificación que no existe en resolución: la compensación se contrasta contra **marcaje biométrico y registro de reloj**. Eso convierte un compromiso declarado en un compromiso verificado e incorpora una integración nueva, distinta de SISPER. Queda pendiente la vía alternativa para el personal sin marcaje obligatorio.

### 4.6 Periodo de ejecución

| Código actual | Regla implementada hoy | Clase | Qué hace el pago | Capa |
| :--- | :--- | :---: | :--- | :--- |
| `periodFromRequired`, `periodToRequired`, `periodEndBeforeStart` | Coherencia del rango general | **A** | Aplica al **periodo cubierto** declarado en la cuota | UI + PA-TX |
| `periodCrossoverCalendarYear` | El periodo no cruza a otro año calendario | **R** | Se revalida sobre el periodo cubierto y sobre el conteo anual de meses de pago | PA-TX |
| `periodExceeds12Months` | El periodo no excede 12 meses | **H** | Ya acotado por la PDS | — |
| `workerExecutionStartOutOfPeriod`, `workerExecutionEndOutOfPeriod` | Fechas del funcionario dentro del periodo general | **A** | El periodo cubierto debe estar contenido en `sg_fups.f_inicio`–`f_termino` | PA-TX |

### 4.7 Lo que el pago no debe repetir

| Elemento de resolución | Motivo |
| :--- | :--- |
| Decretación, firmas y visaciones de la resolución | Acto administrativo ya perfeccionado |
| Selección de contrato y cálculo inicial de elegibilidad | Congelado en `sg_fups` |
| Cálculo del tope base como acto constitutivo | Se conserva `mto_tope` y `f_cal_tope` como antecedente |
| Asociación por similitud textual de actividades ([textSimilarityUtil.js:218](../../../sg-solicitudes-frontend/utils/textSimilarityUtil.js:218), umbral 0.6) | En pago existe una PDS origen identificada. Un umbral textual **no puede ser llave financiera**: duplicidad y acumulados se resuelven por identificadores y periodos persistidos |
| Elección de funcionarios y montos totales | Los define la resolución |

## 5. Matriz B — validaciones nuevas del flujo de pagos

| Código propuesto | Regla | Fuente normativa | Severidad propuesta | Capa |
| :--- | :--- | :--- | :--- | :--- |
| `LICENCIA_PERIODO_CUBIERTO` | No se paga un periodo cubierto por licencia médica | D.U. 9 | error | PA-TX |
| `SIN_GOCE_PERIODO` | No se paga un periodo con permiso sin goce de sueldo | D.U. 9 | error | PA-TX |
| `RECESO_NO_ACREDITADO` | No se paga receso universitario salvo trabajo efectivo acreditado y asumido por el proyecto | D.U. 9 | error | DGDP |
| `PROYECTO_CERRADO` | No se paga ejecución posterior al cierre o fuera de la vigencia del proyecto | D.U. 9 | error | PA-TX |
| `CONSTANCIA_PARENTESCO_FALTANTE` | Falta la constancia jurada diferida desde la resolución | Protocolo D.U. 9 | error | DGDP |
| `EVIDENCIA_FALTANTE` | Falta evidencia obligatoria del periodo o hito | Catálogo S0-010 | error | UI + PA-TX |
| `COMPENSACION_NO_ACREDITADA` | La compensación comprometida no se acreditó como ejecutada | D.U. 9 | por definir | DGDP |
| `SALDO_INSUFICIENTE` | Sin saldo, sobregiro ni capital de trabajo autorizado en el CC | D.U. 9 | error temporal, admite reintento | PA-TX |
| `SALDO_AUTORIZADO_EXCEDIDO` | El monto solicitado supera el saldo del monto total autorizado | Resolución origen | error | PA-TX |
| `CUOTA_COMPROMETIDA` | La cuota ya está viva en otra solicitud de pago | Integridad | error | PA-TX |
| `MAX_CUOTAS_EXCEDIDO` | Más de 2 cuotas por PDS y funcionario en el año de ejecución | D.U. 9, interpretado en S0-013 | error; liberado en ANID | PA-TX |
| `CUOTA_FINAL_ANTICIPADA` | La última cuota se envía sin que la ejecución haya terminado | S0-013 C06, E02 | error | PA-TX |
| `MES_EJECUCION_YA_CUBIERTO` | El mes de ejecución ya está cubierto por otra cuota de la misma actividad | S0-013 C06 | error | PA-TX |
| `PERIODO_DUPLICADO` | El periodo cubierto ya fue pagado o está comprometido | Integridad | error | PA-TX |
| `PRORRATEO_POR_AUSENCIA` | Ajuste proporcional al tiempo efectivamente trabajado | D.U. 9 | advertencia con ajuste de monto | DGDP |
| `TRANSACCION_FALTANTE` | No se cierra un detalle pagado sin `nro_transac` ni fecha efectiva | Control interno | error | PA-TX |

### 5.1 Cálculo monetario autoritativo

Dentro de una sola transacción, al **enviar** y otra vez al **autorizar**:

```text
monto pagable de la cuota =
  MIN(
    tope aplicable, completo para esta cuota,
    monto total autorizado − pagado − comprometido en solicitudes activas,
    monto ajustado por licencia, permiso o ejecución parcial,
    saldo presupuestario efectivo = saldo FIN21 − compromisos activos del workflow SG
  )

sujeto a:  cuotas del año de ejecución ≤ 2   (sin límite si ANID)
           última cuota solo con la ejecución terminada
```

Ningún término puede provenir de caché ni de un cálculo hecho en `UI`. El tope entra completo: no se descuenta por cuotas anteriores ni hereda su remanente.

## 6. Decisiones que esta matriz obliga a cerrar

1. **Tope congelado o recalculado.** El D.U. 9 define el tope sobre los haberes del *mes anterior a la solicitud*. Si el pago ocurre meses después hay dos lecturas legítimas: usar `sg_fups.mto_tope` congelado, o recalcular con `sg_fupssSecgen13` al mes de pago. Afecta a `TOPE_EXCEDIDO`, al tope de cada cuota y al máximo pagable. → S0-013 §J.
2. **Severidad de los cambios contractuales sobrevenidos.** Contrato terminado o cargo modificado después de la resolución, sobre trabajo ya ejecutado: ¿bloqueo o advertencia? → S0-013 §H5.
3. ~~**Compensación en pago.**~~ **Resuelta:** el pago recompromete los tramos faltantes y los verifica contra marcaje. §4.5 queda como **A**. Nuevo pendiente derivado: cómo acredita su compensación quien no tiene marcaje obligatorio.
4. **Proporcionalidad por ausencias.** El D.U. 9 prohíbe pagar periodos con licencia; el documento de preguntas admite proporcionalidad. La lectura que permitiría pago completo por objetivos cumplidos en pocos días requiere validación jurídica explícita. → S0-013 §H1.
5. **Fuente de licencia, sin goce y receso.** Sin integración SISPER confirmada, estas reglas quedarían como control manual de DGDP. Debe decidirse la fuente antes de comprometer severidad `error`. → S0-013 §H.
6. **Deuda institucional.** Confirmar la fuente y el comportamiento antes y después de 2027-01-01. → S0-013 §H5.
7. **Reserva en borrador.** Resuelta en parte: las cuotas se crean al enviar (B02), así que el borrador no reserva nada. Queda por definir el mensaje y el efecto cuando dos envíos concurrentes compiten por el mismo cupo o saldo. → S0-013 §L.
8. **Ratificación normativa del modelo de cuotas.** Expresar el límite del decreto como "2 cuotas" en vez de "2 meses de pago" es una interpretación, siempre igual o más restrictiva que la regla literal. Requiere ratificación escrita de DGDP o jurídica.
9. **Acreditación de la excepción ANID.** El decreto admite superar el límite "salvo excepción normativa acreditada"; D11 descarta cargar certificado. Debe quedar escrito que el campo del centro de costo es esa acreditación, y quién lo mantiene.

El estado completo de estas decisiones y su efecto sobre cada control está en [9_catastro_validaciones_y_saldos.md](./9_catastro_validaciones_y_saldos.md) §0.1, §18.1 y §19.

## 7. Contrato de resultado de validación

Toda regla, heredada o nueva, debe devolver la misma estructura, extendiendo la convención ya usada por `normalizeDu288Issue`:

```text
codigo        identificador estable, presente en el catálogo
etiqueta      texto corto para interfaz
severidad     error | advertencia | pendiente | informativo
mensaje       explicación accionable para el usuario
fuente        PDS | PA normativo | FIN21 | SISPER | documental | manual
fecha_eval    momento de la evaluación
alcance       solicitud | detalle | cuota | periodo
excepcion     si admite excepción, quién la autoriza y con qué respaldo
vigencia      hasta cuándo el resultado es reutilizable
```

Un código sin entrada en el catálogo **nunca** se imprime como etiqueta al usuario: se muestra como "Observación" y el código viaja solo para diagnóstico. Este criterio ya está implementado en resolución y debe conservarse.

## 8. Criterio de cierre

Esta matriz queda cerrada cuando cada fila tiene clase confirmada en taller, severidad aprobada por DGDP, fuente de dato identificada y responsable de excepción definido. Hasta entonces, ninguna fila marcada **R** o **N** puede implementarse como bloqueo definitivo.
