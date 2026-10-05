# Catastro — vista de detalle de pago y antecedentes

**Fecha de corte:** 05-10-2026  
**Rama revisada:** `bandeja_pagos`  
**Clasificación:** implementado · agregado en curso · pendiente externo

## 1. Base implementada en la rama

- Módulo frontend y backend `service-provision-payments`.
- Bandeja «Prestaciones por pagar» y resumen de acceso del jefe de proyecto.
- Permiso derivado `provision-payment-manage`.
- Endpoints de meses, cuotas, estados de cuota, compensación realizada y envío a visación.
- Endpoints de antecedentes reutilizados desde el flujo de resolución.

## 2. Agregado en curso en el frontend

| Recurso | Responsabilidad |
| :--- | :--- |
| `pages/services-provision/payments/_nroSolici/index.vue` | Página de detalle por resolución; pestañas Gestión de pago y Antecedentes |
| `store/service-provision-payment-detail.js` | Carga coordinada de solicitud, funcionarios, horarios, antecedentes, meses, cuotas y validaciones vigentes |
| `Du288PaymentStaffSection.vue` | Funcionario y marco autorizado |
| `Du288PaymentMonthsSection.vue` | Meses de ejecución y disponibilidad |
| `Du288ExecutedCompensationSection.vue` | Contraste comprometido/realizado |
| `Du288InstallmentsSection.vue` | Cuotas registradas |
| `Du288InstallmentFormSection.vue` | Creación y edición de cuota |
| `Du288PaymentValidationsSection.vue` | Tags normativos consultados con datos vigentes |
| `Du288PaymentAntecedentsTab.vue` | Consulta unificada de datos decretados y resolución firmada |

## 3. Fuentes de la vista «Antecedentes»

| Contenido | Fuente existente | Uso |
| :--- | :--- | :--- |
| Datos generales decretados | `GET /requests/service-provision/detail/{requestId}/info` | Tarjetas de centro de costo, jefatura, ítem, período y modalidad |
| Funcionarios decretados | `GET /requests/service-provision/{requestId}/staff` | Tabla de funcionario, cargo, actividad, monto, período y horario |
| Información de resolución | `GET /requests/service-provision/{requestId}/info-gral` | Número y año necesarios para localizar el documento |
| Documento firmado | `GET /resolution/file/{year}/{resolutionNumber}/2` | PDF cargado y firmado del archivo universitario |

El correlativo `2` identifica el documento firmado/cargado. El correlativo `1` corresponde al
documento generado por el sistema y no se muestra como antecedente principal del pago.

## 4. Decisión visual aplicada

La pestaña principal **Antecedentes** se conserva porque separa consulta de resolución y gestión
de pago. Dentro de ella se elimina la segunda navegación por subtabs.

Orden único de lectura:

1. Información decretada de la prestación.
2. Tabla de funcionarios y condiciones autorizadas.
3. Resolución firmada embebida inmediatamente debajo.

Se elimina de esta vista la reconstrucción textual de `Vistos` y `Considerando` obtenida desde
`/resolution-details/{resolutionId}`. Esa información ya forma parte del documento firmado y
duplicarla podía mostrar una representación distinta del acto decretado.

## 5. Estados de interfaz cubiertos

- Datos disponibles con tabla y PDF firmado.
- Datos disponibles mientras el documento está cargando.
- Datos disponibles sin documento firmado encontrado.
- Documento no disponible por error de consulta.
- Antecedentes vacíos.
- Diseño adaptable: tabla con desplazamiento horizontal y visor reducido en pantalla móvil.

## 6. Capas no modificadas

Este ajuste es de composición y consumo frontend. No requiere cambios de procedimientos
almacenados, tablas, modelos ni contratos backend; reutiliza endpoints ya existentes y elimina
una consulta redundante desde el detalle de pago.

## 7. Ajuste del visor de resolución firmada

- El contenedor conserva la relación ancho/alto informada por `CropBox` o `MediaBox` de la primera página del PDF.
- El documento se abre inicialmente en la página 1 con ajuste de página completa.
- Si el archivo no expone esas dimensiones en el segmento legible, se utiliza la proporción A4 como respaldo.
- Se eliminan las alturas fijas de escritorio y móvil para evitar deformaciones y espacios arbitrarios.

## 8. Revalidaciones antes de enviar — agregado 05-10-2026

Las validaciones se muestran como tags `.pds-check`, reutilizando la semántica, los textos y los
estados visuales del flujo de resolución. Se consultan al abrir el detalle, al solicitar el envío y
nuevamente al confirmar el modal.

| Dato | Tratamiento en pago |
| :--- | :--- |
| Contrato | Se busca exclusivamente el contrato persistido en la resolución; no se reemplaza por el primer contrato vigente |
| Cargo e inhabilidades | Se vuelve a consultar con el contrato guardado |
| Asignaciones | Se vuelven a consultar las designaciones vigentes e inhabilitantes |
| Parentesco | Se vuelve a consultar contra el jefe de proyecto vigente |
| Tope | Se compara el tope autorizado en resolución con el tope vigente base/especial por cargo; el monto se valida contra el vigente |
| Carga semanal | Se recalculan contrato + honorarios + FUHO actual + FUHO de PDS previas concurrentes, con máximo de 56 horas |
| Saldo | TODO: la respuesta está falseada; se consulta y muestra como tag informativo, pero temporalmente no bloquea |
| Calendario | Se vuelve a consultar el período institucional |

Una fuente obligatoria pendiente o un resultado rojo bloquea «Enviar a visación», pero no impide
guardar el borrador. El motivo visible ya no es solo genérico: cita el primer tag bloqueante.

Excepción temporal: la validación «Centro de costo sin saldo» queda en **TODO PAG-SALDO**. Como la
fuente está falseada para probar el envío, cualquier resultado pendiente, no disponible o sin saldo
se presenta en amarillo y no participa en la compuerta de envío. Al conectar la fuente financiera
definitiva debe volver a estado rojo bloqueante.

Los datos históricos se mantienen separados de estas reconsultas. El marco autorizado muestra:

- cuotas solicitadas / autorizadas;
- cuotas que aún se pueden solicitar;
- tope autorizado en la resolución, incluso cuando el tag informa un tope vigente distinto.

## 9. Verificación automatizada

- Pruebas unitarias nuevas para contrato persistido, comparación de topes, tope especial, cuotas
  solicitadas/restantes y carga semanal con PDS concurrentes.
- Suite completa `npm test`: 11 archivos de prueba correctos.
- Estándar visual `npm run lint:du288-ui`: 38 archivos validados.
- Compilación de producción `npm run build`: correcta; se mantienen únicamente advertencias
  generales preexistentes de tamaño de bundles y `::v-deep`.
