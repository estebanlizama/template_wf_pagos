# Vista de solicitud de pago — análisis y propuesta

Fecha: 2026-09-07
Fuente autoritativa: ClickUp S0-013 (`86e2zrkh4`). Ver `01_reglas_montos_por_tipo_de_flujo.md`.

## 1. Alcance

Tres pantallas nuevas, un solo modelo de datos. El flujo es
Solicitante/Jefe de Proyecto → DGDP → Finanzas (Q-E05), y Finanzas puede
devolver a DGDP por falta de fondos, no rechazar de plano (Q-E05, Q-E11).

| Pantalla | Actor | Qué hace |
|---|---|---|
| Crear/editar solicitud de pago | Jefe de proyecto (Q-E03) | Selecciona resolución, arma la cuota, adjunta evidencia |
| Bandeja de pagos | Los tres | Listado por estado, con filtros |
| Detalle / visación | DGDP y Finanzas | Revisa, edita con registro, aprueba, devuelve o rechaza |

## 2. Mapa de páginas

Siguiendo la convención existente (`new-request-du288.vue`,
`my-requests.vue`, `requests-waiting.vue`, `_id/index.vue`):

```
pages/services-provision/payments/
├── new-payment-du288.vue      crear solicitud de pago
├── my-payments.vue            bandeja del solicitante
├── payments-waiting.vue       bandeja DGDP / Finanzas
└── _id/index.vue              detalle y visación
```

## 3. Componentes: qué se reutiliza

### Tal cual, sin tocar

| Componente | Uso en pago |
|---|---|
| `RequestStatusBadge.vue` | Estado de la solicitud |
| `Comments.vue` | Observaciones entre etapas |
| `NormativeApprovalTimeline.vue` | Línea de tiempo de aprobación |
| `HistoryItem.vue` | Historial de cambios |
| `ExecutionMonthsTags.vue` | Meses de la cuota (ya soporta monto por mes) |
| `InputRoot`, `InputNumber`, `SelectList`, `DatePickup`, `InputTextarea` | Formularios |
| `AppLoadingState`, `SectionLoadingState` | Cargas |
| `Du288StaffPreviousProvisionsModal.vue` | Ver qué más tiene comprometido el funcionario |

### Se adapta

| Componente | Adaptación |
|---|---|
| `PdsWorkflowRequestSummary.vue` | Resumen previo al envío. Ya arma resumen por funcionario con montos; hay que cambiar el eje de "funcionarios de la solicitud" a "meses de la cuota" (Q-F11) |
| `ChangeStateRequestModal.vue` | Modal de visación DGDP/Finanzas. Mismas acciones (aprobar, devolver, rechazar) sobre otro objeto |
| `Du288ContractDetailsSection.vue` | Antecedentes contractuales heredados, en modo lectura |
| `StaffCompensationSection.vue` | Solo si la modalidad exige compensación (Q-F06), mostrando lo aprobado en la resolución, no editable |

### Nuevo

| Componente | Por qué no existe equivalente |
|---|---|
| `PaymentResolutionPicker` | Buscar la resolución pagable con los filtros de Q-F01, restringido a archivadas y vigentes (Q-F02) |
| `PaymentBalanceCard` | Autorizado / pagado / comprometido / disponible. No hay nada equivalente hoy |
| `PaymentInstallmentBuilder` | El corazón: selector de cuota + tabla de meses con estado y monto |
| `PaymentEvidenceUpload` | Un solo PDF (Q-G01) |

## 4. Anatomía de la vista principal

Orden de arriba abajo, con el criterio de Q-F07: **lo heredado de la
resolución arriba y bloqueado; lo editable abajo**.

1. **Selección de resolución** — filtros por resolución, solicitud, RUT,
   proyecto, centro de costo, actividad y periodo (Q-F01). Solo aparecen
   funcionarios con resolución archivada y vigente (Q-F02).
2. **Antecedentes heredados (solo lectura)** — funcionario, actividad,
   período de ejecución, modalidad (heredada, Q-F05), tipo de monto
   (fijo/variable), monto total autorizado, tope aplicable.
3. **Saldo de la prestación** — autorizado, pagado, comprometido en otras
   solicitudes activas, disponible.
4. **Armado de la cuota** — número de cuota, meses que cubre, monto.
5. **Evidencia** — un PDF (Q-G01), no obligatorio para guardar borrador
   (Q-F09).
6. **Resumen de confirmación** — *"para qué cuota y cuánto abarca esa
   cuota"* (Q-F11).

## 5. Validaciones por momento

### Al listar resoluciones pagables
- Solo resolución **archivada y vigente** (Q-F02).
- Solo actividades con **trabajo ya realizado**: la fecha de la prestación
  debe haber pasado (Q-A02).
- Excluir las que ya agotaron el monto autorizado (Q-A06).

### Al seleccionar la resolución
- Heredar modalidad sin permitir cambiarla (Q-F05).
- Mostrar tabla de compensación solo si modalidad y cargo lo exigen (Q-F06).
- Cargar el tipo de monto (`cod_tpps`) para decidir el comportamiento de la
  columna monto.

### Al seleccionar meses de la cuota
- Solo meses **ya ejecutados** (Q-A02, Q-C09).
- Mes ya pagado queda **bloqueado para la misma actividad** — se muestra
  deshabilitado con su motivo, no oculto (Q-C06).
- No cruzar el año calendario de ejecución (Q-B09).
- Se pueden mezclar meses atrasados con el mes actual (Q-C10).

### Al definir el monto
- Cada cuota dispone del **tope completo**; se reinicia para la siguiente
  (Q-C01, Q-C02).
- El tope **no se arrastra**: lo no usado en la cuota anterior no se suma
  (Q-A07).
- Techo real = mínimo entre tope de la cuota y saldo autorizado disponible
  (Q-A07).
- Solo puede **bajar** respecto del techo, por licencia o permiso (Q-B12).
- Si dos cuotas caen en el mismo mes (solo por deudas, Q-C05), validar
  además la suma mensual del funcionario (Q-C08).
- ANID: sin tope y sin límite de cuotas, automático por centro de costo
  (Q-D03, Q-D04, Q-D11).

### Al guardar borrador
- Se permite sin evidencia (Q-F09).
- No se crean cuotas todavía (Q-B02).
- Eliminable solo si nunca se envió (Q-F10).

### Al enviar
- Se **crean las cuotas** en este momento (Q-B02).
- Máximo 2 cuotas por PDS + funcionario, salvo ANID (Q-C01).
- La **última cuota** exige ejecución terminada (Q-C06, Q-E02).
- Evidencia PDF obligatoria (Q-G01, pendiente de confirmar en Q-G06).
- El folio se genera al enviar (Q-A11).

### En visación
- DGDP puede editar, pero **queda registrado** (Q-A08).
- Rechazo u observación devuelve **la solicitud completa**, no un detalle
  (Q-A09).
- Finanzas puede devolver a DGDP por falta de fondos; DGDP puede reabrir
  (Q-E05, Q-E11).
- Nadie solicita y aprueba la misma solicitud (Q-E07).

## 6. Restricción heredada de la base de datos

`sg_fumeuSecgen01` (versión 2026-09-07) ya no borra meses que tengan
compensaciones en `sg_fuc2` o historial en `sg_fum2`: son antecedentes de
trabajo realizado. La vista de pago debe reflejar lo mismo — un mes con
compensaciones registradas no puede quedar fuera de la cuota sin una
acción explícita, porque la base lo va a rechazar.

## 7. Bloqueantes

No se puede construir la columna de monto sin resolver:

| Pregunta | Qué bloquea |
|---|---|
| **Q-J07** | ¿El monto lo propone el sistema desde saldo/tope, o lo ingresa el usuario? Define la interacción principal en el caso variable |
| **Q-B13** | Significado de `ano_prop/mes_prop`, `ano_ejec/mes_ejec`, `ano_pago/mes_pago`. Define dónde se guarda lo que el usuario selecciona |
| **Q-F08** | ¿Puede ajustar el monto por ausencia, o solo proponerlo a DGDP? |
| **Sección H completa** | Licencia, permiso, vigencia y receso son las causales que justifican bajar el monto; ninguna tiene fuente ni tratamiento definido |
| **Q-F04, Q-F12** | Qué ocultar al solicitante y qué mensajes mostrar por cuota no seleccionable |
| **Q-C13, Q-C14** | Qué fecha determina el tope y si se recalcula al cambiar el mes efectivo |

Las dos primeras son las que impiden empezar: una define **cómo se
interactúa**, la otra **dónde se persiste**.
