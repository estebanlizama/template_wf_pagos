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
| **Estado de entrada esperado** | Solicitud aprobada por DGDP / En revisión Finanzas (`cod_estpago = 3`) |
| **Objetivo principal** | Validar el saldo disponible en el Centro de Costo, verificar financiamiento compatible, auditar las evidencias documentales cargadas, autorizar formalmente el desembolso e ingresar la transacción de pago para archivar la cuota. |
| **Resultado posible** | Solicitud Aprobada y Pagada (`cod_estpago = 8`); o Rechazada por motivos presupuestarios (`cod_estpago = 4`). |

---

# 3. Principio funcional de la Pantalla PP03

La Pantalla PP03 debe operar como una **consola de control financiero y egreso de fondos**.
* **Integración Presupuestaria**: Consulta el saldo disponible real en tiempo de ejecución de la cuenta del Centro de Costo.
* **Cero Sobregiros**: Inhabilita la aprobación si el Centro de Costo no cuenta con fondos líquidos suficientes.
* **No permite editar** labores, deudas ni los datos contractuales del beneficiario.
* Registra el número de transacción contable de egreso (`nro_transac`) antes de cerrar la solicitud.

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
8. Registre la decisión financiera (Aprobar Pago / Rechazar Solicitud).
9. Ingrese el **Número de transacción bancaria / Código contable de egreso** (`nro_transac`) y registre la fecha del depósito bancario para archivar la solicitud mensual con estado **"Pagada" (8)**.

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
* Selección de la acción:
  * **APROBAR Y PAGAR**: Registra la aprobación y habilita la entrada contable.
  * **RECHAZAR PAGO**: Rechaza el cobro del mes debido a inconsistencias o falta de presupuesto.
* Comentarios del analista (Obligatorio en Rechazo).
* Número de transacción bancaria / Código contable de egreso (`nro_transac`) (Obligatorio en Aprobación).

### D. Datos o cambios que debe mostrar el sistema
* Al registrar y ejecutar:
  * El estado de la solicitud de pago cambia a **"Resolución Pagada" (8)**.
  * Se almacena el `nro_transac` y la fecha/hora efectiva del pago en `sg_pago_soli`.
  * Se descuenta físicamente el saldo en el Centro de Costo contable.
  * Se genera e imprime el comprobante de liquidación del pago PDS mensual.
* Notificación automática por correo electrónico al Solicitante/Beneficiario informando que el pago ha sido depositado exitosamente.

### F. Validaciones

| Código | Validación | Efecto esperado |
| :--- | :--- | :--- |
| **VAL-PP03-DEC-01** | Motivo obligatorio de rechazo. | Exige un comentario de mínimo 20 caracteres detallando el motivo financiero del rechazo. |
| **VAL-PP03-REG-01** | Código de transacción no vacío. | Impide archivar el expediente de pago mensual en aprobación si no se ha ingresado la referencia contable/bancaria. |
