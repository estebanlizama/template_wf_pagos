# SG-Solicitudes — Modernización Módulo PDS 2026
## Flujo de Solicitud de Pago — Perfil Dirección de Finanzas
### Estructura base de requerimientos por pantalla y funcionalidad

---

# 1. Propósito de esta sección

Este documento organiza la **Pantalla PP03: Revisión Presupuestaria y Ejecución de Pago — Perfil Dirección de Finanzas** como base formal de requerimientos de la **Fase 2 de Modernización del Workflow de Pagos PDS**.

La pantalla se documenta a partir de:
1. El rol estratégico de la **Dirección de Finanzas** como garante del uso correcto de los recursos financieros de la universidad.
2. Los requisitos de control de saldos y cuentas estipulados en el **Decreto N° 009/2026 (D9)**.
3. La integración con la Pantalla PP01 (Solicitante) y PP02 (DGDP), garantizando que Finanzas audite las labores pre-cargadas de la BDD, los documentos físicos de respaldo (evidencias) cargados, y el PDF de la resolución con sus antecedentes.

> [!IMPORTANT]
> **Hito de Cierre Financiero:** En este flujo de tres roles, la Dirección de Finanzas constituye la etapa final mensual. Su aprobación favorable valida la disponibilidad presupuestaria líquida del Centro de Costo de origen y gatilla el proceso de transferencia y registro en la liquidación de sueldo del prestador.

---

# 2. Identificación general de la pantalla

| Elemento | Descripción |
| :--- | :--- |
| **Código de pantalla** | PP03 |
| **Nombre** | Revisión Presupuestaria y Ejecución de Pago Finanzas |
| **Perfil principal** | Analista de Finanzas Central / Tesorería |
| **Etapa del flujo** | Etapa 03 — Control Presupuestario Final y Liquidación |
| **Estado de entrada esperado** | Solicitud aprobada por DGDP — `sg_soli.cod_estsol = 'EN_REVISION_FINANZAS'` |
| **Objetivo principal** | Validar el saldo disponible en el Centro de Costo, verificar financiamiento compatible, auditar las evidencias documentales cargadas, autorizar formalmente el desembolso e ingresar la transacción de pago por detalle (`sg_pade.nro_transac`) para cerrar la cuota. |
| **Resultado posible** | Solicitud `PAGADA` (todos los detalles liquidados); `PAGO_PARCIAL` (algunos detalles liquidados, otros `PENDIENTE_SALDO`); `PENDIENTE_SALDO` (ninguno liquidado por falta de fondos); `RECHAZADA` (causal financiera definitiva). |

---

# 3. Principio funcional de la Pantalla PP03

La Pantalla PP03 debe operar como una **consola de control financiero y egreso de fondos**.
* **Integración Presupuestaria**: Consulta el saldo disponible real en tiempo de ejecución de la cuenta del Centro de Costo.
* **Cero Sobregiros**: Inhabilita la aprobación si el Centro de Costo no cuenta con fondos líquidos suficientes.
* **No permite editar** labores, deudas ni los datos contractuales del beneficiario.
* Registra el número de transacción contable de egreso (`nro_transac`) antes de cerrar la solicitud.

## 3.1 Relación con Solicitud PDS Formalizada

- El pago nace desde una PDS formalizada y con resolución/documento firmado.
- `sg_prse` y `sg_fups` son la fuente de datos aprobados.
- `sg_fume` contiene los meses aprobados por funcionario.
- `sg_fucu` contiene las cuotas generadas desde esos meses aprobados.
- `sg_paso` crea la solicitud formal de pago asociada a la PDS.
- `sg_pade` registra qué cuotas se solicitan pagar.
- `sg_fuev` registra las evidencias/constancias por funcionario/mes/pago.
- El pago no modifica la PDS, funcionarios, meses ni topes aprobados.
- Un rechazo de pago no debe usar `sg_fups.ind_retfun`.

### Matriz de Validaciones de Pago

| Regla | Resuelta en PDS | Revalidar en Pago |
| :--- | :--- | :--- |
| Cargo inhabilitado | Sí | Solo mostrar antecedente |
| Asignación directiva | Sí | Solo mostrar antecedente |
| Formación continua | Sí | Solo mostrar antecedente |
| Tope mensual | Sí | Revalidar si cambia monto solicitado |
| Máximo 2 meses | Sí | Validar cuota generada coherente |
| SEA | Sí | Mostrar antecedente |
| Compensación | Sí | Mostrar y exigir si falta respaldo |
| Licencia médica | Puede haber sido evaluada | Sí, por mes ejecutado |
| Permiso sin goce | Puede haber sido evaluado | Sí, por mes ejecutado |
| Receso | No siempre | Sí, requiere constancia |
| Deudas 2027 | Puede haber sido evaluada | Sí, si fecha aplica |
| Ausencias | No estática | Sí, ajuste proporcional |
| Saldo CC | Informativo/aprobado PDS | Sí, final en Finanzas |
| Evidencia | Planificada | Carga real obligatoria |

---

# 4. Objetivo funcional de la Pantalla PP03

La pantalla debe permitir que la Dirección de Finanzas:
1. Identifique el ID de la solicitud de pago mensual y el mes calendario a liquidar.
2. Visualice la **Resolución base en formato PDF** a través de un visor integrado en pantalla, junto con todos sus antecedentes.
3. Revise la trazabilidad de aprobaciones anteriores (Solicitante y DGDP).
4. Consulte el saldo actual y los recursos disponibles del **Centro de Costo** asociado.
5. Ejecute validaciones presupuestarias críticas:
   * Verificar tipo de financiamiento compatible (Fondos propios 21, Terceros 44).
   * Confirmar que no se utilicen recursos estructurales de base.
   * Corroborar que el monto solicitado no exceda el saldo disponible.
6. Audite la **ficha de labores y funciones específicas pre-cargadas** de solo lectura.
7. Acceda a la **descarga e inspección visual de los documentos de respaldo** (archivos cargados por el solicitante en cada evidencia).
8. Registre la decisión financiera: Aprobar y Pagar / Marcar Pendiente por Saldo / Rechazar por causal definitiva.
9. Ingrese el **número de transacción bancaria / código contable de egreso** (`sg_pade.nro_transac`) por cada detalle pagado, junto a la fecha efectiva de pago (`sg_pade.f_pago`), para cerrar el ciclo de la cuota correspondiente (`sg_fucu.cod_estcuo = 'PAGADA'`).

---

# 5. Estructura funcional general de la pantalla

La Pantalla PP03 se organiza en los siguientes bloques funcionales:

| Código | Bloque de pantalla | Propósito |
| :--- | :--- | :--- |
| **PP03-B01** | Encabezado e Historial del Mes | Identificar la solicitud y mostrar la cadena completa de visaciones anteriores. |
| **PP03-B02** | Visor de Resolución Integrado | Desplegar el PDF oficial de la resolución firmada y sus antecedentes. |
| **PP03-B03** | Consulta Presupuestaria en Tiempo Real | Mostrar datos del Centro de Costo, tipo de fondo, saldo disponible y saldo proyectado. |
| **PP03-B04** | Auditoría de Labores y Evidencias | Visualizar labores/funciones de la BDD y descargar los archivos documentales de respaldo. |
| **PP03-B05** | Panel de Aprobación y Registro de Pago | Habilitar los controles de aprobación y registrar la transacción contable de egreso. |

---

# 6. Desglose detallado por bloque y funcionalidad

---

# 7. Especificaciones de Modelo Normalizado para PP03

## 7.1 Revision financiera por detalle de pago

Finanzas debe revisar la disponibilidad presupuestaria sobre los detalles incluidos en la solicitud de pago.

| Elemento | Regla |
| :--- | :--- |
| Solicitud de pago | Se identifica por `sg_paso.nro_solici`. |
| PDS origen | Se consulta mediante `sg_paso.nro_solpds`. |
| Detalle financiero | Cada cuota/persona a pagar se registra en `sg_pade`. |
| Cuota base | La cuota se obtiene desde `sg_fucu`. |
| Monto solicitado | Se lee desde `sg_pade.mto_solpag`. |
| Monto autorizado | Se registra en `sg_pade.mto_autpag` si Finanzas autoriza un monto distinto. |

## 7.2 Pago parcial dentro de una solicitud

La pantalla soporta que la Dirección de Finanzas autorice y pague de manera parcial e individual a nivel de detalle (`sg_pade`).

| Caso | Comportamiento esperado |
| :--- | :--- |
| Hay saldo para todos los detalles | Se autorizan todos los detalles (`sg_pade.cod_estdet = 'PAGADO'`), se registran las transacciones y la solicitud pasa a `PAGADA` globalmente. Las cuotas base pasan a `PAGADA` (`sg_fucu.cod_estcuo`). |
| Hay saldo solo para algunos detalles | Se autorizan y pagan solo los detalles seleccionados con fondos. La solicitud pasa globalmente al estado mixto `PAGO_PARCIAL`. Los detalles no pagados por falta temporal de saldo quedan como `PENDIENTE_SALDO`. |
| No hay saldo para un funcionario/cuota | Se marca el detalle en `sg_pade.cod_estdet = 'PENDIENTE_SALDO'`. Esto no cierra la cuota de forma definitiva: la cuota base en `sg_fucu.cod_estcuo` vuelve a quedar `DISPONIBLE` o `PENDIENTE_SALDO` para ser reintentada en una posterior solicitud cuando se inyecte presupuesto. |
| No hay saldo para ningun detalle | La solicitud pasa a estado global `PENDIENTE_SALDO` o `RECHAZADA` si aplica otra causal, liberando las cuotas asociadas para nuevos intentos. |

Regla: un rechazo o retraso presupuestario temporal en Finanzas nunca modifica la PDS ni retira permanentemente al personal.

## 7.3 Estados de cuota y detalle

| Nivel | Campo | Uso |
| :--- | :--- | :--- |
| Cuota base | `sg_fucu.cod_estcuo` | Controla el ciclo de vida de la cuota: `DISPONIBLE`, `EN_TRAMITE`, `PAGADA`, `PENDIENTE_SALDO`. |
| Detalle de solicitud | `sg_pade.cod_estdet` | Controla el resultado del detalle en esta solicitud: `EN_PROCESO`, `APROBADO_DGDP`, `PAGADO`, `PENDIENTE_SALDO`, `RECHAZADO`. |

Recomendación de reintento:
1. Si un detalle queda `PAGADO`, la cuota en `sg_fucu` pasa a `PAGADA` permanentemente.
2. Si un detalle queda `PENDIENTE_SALDO` (falta temporal de fondos), la cuota se libera a `DISPONIBLE` para posterior reenvío.

## 7.4 Registro contable por Detalle (`sg_pade.nro_transac`)

Para permitir múltiples transferencias bancarias y egresos independientes en una misma solicitud de pago, el número de transacción bancaria / referencia contable (`nro_transac`) y la fecha de pago (`f_pago`) **deben quedar almacenados directamente en cada registro de detalle (`sg_pade`)**, no en la cabecera `sg_paso`.

Esto independiza la contabilidad de cada funcionario, permitiendo que algunos detalles sean pagados en momentos distintos cuando existe disponibilidad presupuestaria parcial.

## 7.5 Alertas por rol Finanzas

La bandeja de Finanzas debe calcular el tiempo pendiente desde que la solicitud quedo asignada a este rol.

| Caso | Regla |
| :--- | :--- |
| Solicitud entra a Finanzas | Inicia contador para rol Finanzas. |
| Pasa mas de 3 dias sin revision | Marcar en rojo para Finanzas. |
| Finanzas aprueba o rechaza | Se cierra el tramo de Finanzas. |
| Finanzas deja detalles pendientes | Debe quedar trazabilidad del detalle y del motivo financiero. |

El contador se debe calcular dinamicamente desde historial o desde una tabla de tramos/asignacion, segun lo que finalmente permita `sg_hist`.

---

# PP03-B01 — Encabezado e Historial del Mes

## Funcionalidad PP03-F01 — Visualizar trazabilidad global de la solicitud

### A. Descripción funcional
El sistema debe mostrar los metadatos básicos de identificación de la solicitud y desplegar la bitácora completa de acciones previas para auditoría de Finanzas.

### B. Actor principal
Dirección de Finanzas.

### C. Datos que debe mostrar el sistema
* ID de Solicitud de Pago.
* RUT y Nombre del prestador beneficiario.
* Mes cobrado y monto mensual solicitado.
* Resolución asociada (`nro_resolu`).
* Historial con fechas, horas, nombres de usuarios y comentarios de:
  * Solicitante (Carga de evidencias).
  * DGDP (Control de deudas, licencias médicas y excepciones aprobadas).

---

# PP03-B02 — Visor de Resolución e Información PDS A4

## Funcionalidad PP03-F02 — Visualizar resolución y anexo de personal en formato A4

### A. Descripción funcional
El sistema debe proveer una consola visual de auditoría contable integrada que exponga la resolución decretada y su anexo mediante pestañas interactivas, permitiendo a la Dirección de Finanzas corroborar el origen formal de la obligación de pago y el sueldo bruto exacto autorizado.

### B. Actor principal
Dirección de Finanzas.

### C. Estructura visual del componente (Tabs A4)
La pantalla debe organizar la visualización del documento en los siguientes bloques:
1. **Pestaña "Formato de resolución"**:
   * Despliega una hoja de simulación física A4 con fondo blanco, sombra y tipografía formal *Times New Roman*.
   * Estructura del contenido:
     * Encabezado de la Universidad de La Frontera (Secretaría General).
     * Identificación correlativa: `RESOLUCIÓN EXENTA N° 102/2026`.
     * Fecha formal: `TEMUCO, 15 de Mayo de 2026`.
     * Bloques oficiales: `VISTOS`, `CONSIDERANDOS` y cláusulas del `RESUELVO` (decretando la imputación de gastos en el CC del mes).
     * Firmas digitalizadas de Rectoría y Secretaría General.
2. **Pestaña "Anexo"**:
   * Muestra la tabla formal anexa del PDS con el desglose exacto de las asignaciones de personal.
   * Campos y columnas obligatorias:
     * RUT y Nombre Completo del funcionario.
     * Función o cargo específico pactado.
     * Período mensual.
     * Centro de Costo de imputación (`cod_cenco` - ej. 4050.21) y financiamiento compatible.
     * Monto bruto mensual a pagar.

### D. Datos de Contexto de Prestación (PDS) expuestos
El panel debe consolidar de solo lectura los siguientes metadatos clave:
* **Identificación del Centro de Costo**: Código, nombre, y tipo de financiamiento.
* **Responsable Técnico**: Nombre y RUT del Jefe de Proyecto.
* **Control de Meses y Saldos PDS**:
  * Monto bruto mensual pactado en el contrato original.
  * Monto bruto total acumulado de la PDS.
  * Balance de meses: Meses pagados, meses en proceso actual, y meses pendientes de pago totales.
* **Labores pre-cargadas**: Detalle de actividades específicas.

---

# PP03-B03 — Consulta Presupuestaria en Tiempo Real

## Funcionalidad PP03-F03 — Verificar saldo y compatibilidad de fondos

### A. Descripción funcional
El sistema ejecuta una consulta automática contra el módulo de presupuestos para validar la disponibilidad y compatibilidad de la cuenta contable asociada.

### B. Actor principal
Sistema, expuesto para la Dirección de Finanzas.

### C. Datos que debe mostrar el sistema
* Código del Centro de Costo (`cod_cenco`).
* Tipo de financiamiento (Código y Nombre).
* Saldo presupuestario disponible antes del pago.
* Saldo proyectado después del pago (Saldo actual - Monto solicitado).
* Decreto afecto registrado.

### D. Reglas de negocio
* El financiamiento del Centro de Costo debe corresponder exclusivamente a **21 - Fondos Propios** o **44 - Terceros**. Queda prohibido autorizar pagos con fondos de origen estructural.
* Si el saldo disponible es menor que el monto solicitado, el sistema debe activar un indicador de alerta roja y bloquear el botón "Aprobar Pago".

### F. Validaciones

| Código | Validación | Efecto esperado |
| :--- | :--- | :--- |
| **VAL-PP03-PRE-01** | Fondos compatibles (21 o 44). | Inhabilita aprobación si el centro de costo tiene otro tipo de financiamiento contable. |
| **VAL-PP03-PRE-02** | Saldo Suficiente. | Bloquea la acción de aprobar si el saldo proyectado es menor a cero. |

---

# PP03-B04 — Auditoría de Labores y Evidencias

## Funcionalidad PP03-F04 — Auditar justificación de labores y descargar respaldos

### A. Descripción funcional
El analista de finanzas debe tener acceso visual y de descarga a la descripción de labores del mes y los entregables subidos por el beneficiario, con el fin de resguardar la legalidad del desembolso.

### B. Actor principal
Dirección de Finanzas.

### C. Datos que debe mostrar el sistema
* Campo descriptivo de las labores/funciones de la prestación (Solo lectura, cargado desde la BDD de la resolución).
* Tabla de Medios de Verificación:
  * Tipo de evidencia pactada.
  * Enlace de descarga del archivo digital real subido por el solicitante.
  * Tamaño y formato de archivo.
* Botón "Descargar Todo" para auditoría offline.

---

# PP03-B05 — Panel de Aprobación y Registro de Pago

## Funcionalidad PP03-F05 — Ejecutar pago en el sistema contable y cerrar flujo

### A. Descripción funcional
Habilita los controles finales para que el analista apruebe presupuestariamente, ingrese el código contable de egreso y proceda a archivar y pagar la cuota del mes.

### B. Actor principal
Analista de Finanzas Central / Tesorería.

### C. Datos de entrada
* Selección de la acción por detalle de pago (`sg_pade`):
  * **PAGAR DETALLE**: Registra la aprobación del detalle y habilita la entrada del código contable.
  * **PENDIENTE POR SALDO**: Marca el detalle sin fondos para reintento posterior; la cuota base (`sg_fucu`) vuelve a `DISPONIBLE`.
  * **RECHAZAR PAGO**: Rechaza el detalle por causal financiera definitiva.
* Comentarios del analista (Obligatorio en Rechazo y en Pendiente por Saldo).
* Número de transacción bancaria / Código contable de egreso (`sg_pade.nro_transac`) — Obligatorio al pagar.
* Fecha efectiva de pago (`sg_pade.f_pago`) — Obligatorio al pagar.

### D. Datos o cambios que debe registrar el sistema
* Al pagar un detalle:
  * `sg_pade.cod_estdet = 'PAGADO'`.
  * Se almacena `sg_pade.nro_transac` y `sg_pade.f_pago`.
  * La cuota base pasa a `sg_fucu.cod_estcuo = 'PAGADA'`.
  * Se descuenta el saldo en el Centro de Costo contable.
* Al marcar detalle como pendiente por saldo:
  * `sg_pade.cod_estdet = 'PENDIENTE_SALDO'`.
  * La cuota base vuelve a `sg_fucu.cod_estcuo = 'DISPONIBLE'` para reintento posterior.
* Al rechazar un detalle:
  * `sg_pade.cod_estdet = 'RECHAZADO'` con causal registrada.
  * La cuota base puede quedar `PENDIENTE_SALDO` o `RECHAZADA` según regla de negocio.
* El estado global de la solicitud (`sg_soli`) se deriva automáticamente:

| Estado global derivado | Condición |
| :--- | :--- |
| `PAGADA` | Todos los detalles quedan `PAGADO`. |
| `PAGO_PARCIAL` | Al menos un detalle `PAGADO` y al menos uno `PENDIENTE_SALDO` o `RECHAZADO`. |
| `PENDIENTE_SALDO` | Ningún detalle pagado, quedan pendientes por fondos. |
| `RECHAZADA` | Ningún detalle pagado y existe causal definitiva de rechazo. |

* Se genera comprobante de liquidación por detalle pagado.
* Notificación automática al Solicitante/Beneficiario informando resultado del pago.

### F. Validaciones

| Código | Validación | Efecto esperado |
| :--- | :--- | :--- |
| **VAL-PP03-DEC-01** | Motivo obligatorio de rechazo o de pendiente por saldo. | Exige comentario de mínimo 20 caracteres. |
| **VAL-PP03-REG-01** | `sg_pade.nro_transac` no vacío al pagar. | Impide cerrar el detalle sin referencia contable/bancaria. |
| **VAL-PP03-REG-02** | `sg_pade.f_pago` no vacía al pagar. | Impide cerrar el detalle sin fecha efectiva de pago. |
