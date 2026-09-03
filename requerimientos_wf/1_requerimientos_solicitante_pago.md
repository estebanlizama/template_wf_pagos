# PP01 — Requerimientos del Solicitante de Pago

**Estado:** levantamiento funcional  
**Actor principal:** responsable autorizado del centro de costo/proyecto o delegado vigente  
**Entrada:** PDS formalizada  
**Salida:** solicitud enviada a la etapa siguiente

## 1. Objetivo

Permitir que un usuario autorizado seleccione una PDS, revise su situación financiera y documental, elija uno o varios funcionarios/cuotas, registre el monto solicitado y sus respaldos, y envíe una solicitud trazable.

PP01 no modifica la PDS, la resolución, el monto aprobado ni los antecedentes contractuales.

## 2. Respuestas preliminares ya levantadas

| Tema | Respuesta preliminar que debe ratificarse |
| :--- | :--- |
| Búsqueda | El criterio principal es número/año de resolución exenta o externa; los demás filtros son complementarios. |
| Personas visibles | Mostrar todos los funcionarios de la PDS como contexto; solo los vigentes y con saldo/cuota habilitada son seleccionables. |
| Historia | Mostrar pagado, en trámite, disponible y saldo pendiente con tratamiento visual distinto. |
| Agrupación | Permitir varios funcionarios y varios meses/cuotas de una misma PDS. |
| Pagos atrasados | Pueden convivir con el mes actual si cumplen reglas y no están comprometidos. |
| Falta de saldo | El reintento es manual; no debe obligar a redigitar antecedentes permanentes. |
| Monto | El solicitante puede proponer pago total o parcial. Un parcial requiere motivo. |
| Ausencias | El sistema no ajusta automáticamente; el solicitante propone monto y justifica, sujeto a revisión DGDP. |
| Evidencia | Se asocia como mínimo a funcionario y periodo/cuota; si nace en el pago también a la solicitud/detalle. |
| Corrección | Solo permite cambiar datos del pago; no los antecedentes aprobados de la PDS. |

## 3. Precondiciones

- usuario autenticado y autorizado sobre el centro de costo/proyecto;
- delegación vigente cuando actúa por otra persona;
- PDS formalizada con documento final accesible;
- funcionario perteneciente a la PDS y no retirado;
- monto total aprobado mayor que cero;
- cuota disponible o saldo que permita crearla según ADR-PP-001;
- catálogos de estados, evidencias y causales vigentes.

## 4. Funcionalidades

### PP01-F01 — Buscar PDS

Filtros mínimos:

- número/año de resolución;
- número de solicitud PDS;
- centro de costo/proyecto;
- funcionario;
- actividad;
- periodo;
- estado de habilitación para pago.

Resultado mínimo:

- PDS y resolución;
- actividad y periodo;
- centro de costo y responsable;
- total aprobado, pagado, comprometido y pendiente;
- cantidad de funcionarios;
- documento final;
- motivo cuando no esté habilitada.

**Regla:** seleccionar una PDS no crea automáticamente una solicitud ni reserva saldo.

### PP01-F02 — Cargar contexto de la PDS

Mostrar como solo lectura:

- datos de `sg_soli` y `sg_prse`;
- centro de costo o proyecto global;
- resolución/documentos;
- rango aprobado;
- responsable titular y delegación utilizada;
- resumen por ítem presupuestario;
- advertencias generales.

### PP01-F03 — Mostrar saldo

Por cada combinación `cod_unifin + cod_ccto + cod_sitm` debe mostrar:

- saldo inicial informado;
- monto de esta solicitud;
- compromisos activos del workflow;
- saldo remanente;
- fecha/hora de cálculo;
- fuente y resultado.

La pantalla puede mostrar una vista previa. El envío debe recalcular sin caché.

### PP01-F04 — Mostrar funcionarios y cuotas

Por funcionario:

- RUT, nombre, estamento/cargo y actividad;
- rango particular y monto total aprobado;
- monto pagado, comprometido y saldo pendiente;
- cuota, periodo/hito cubierto y estado;
- mes propuesto de pago;
- validaciones conocidas y evidencias;
- elegibilidad y motivo de bloqueo.

Estados no seleccionables: pagada, en trámite activo, bloqueada o cerrada definitivamente. `Pendiente saldo` será seleccionable solo después de liberar el intento anterior.

### PP01-F05 — Seleccionar y editar detalles

Cada selección crea o actualiza un detalle lógico con:

- cuota `(id_funprse, nro_cuota)`;
- monto solicitado;
- mes/año solicitado de pago;
- motivo de ajuste si el monto es parcial;
- periodo(s) o hito cubierto;
- evidencias asociadas;
- estado inicial del detalle.

Debe soportar selección individual y múltiple. Una acción masiva no puede ocultar errores individuales.

### PP01-F06 — Gestionar evidencias

Permitir cargar, visualizar, descargar, reemplazar lógicamente y retirar del borrador. Cada tipo debe informar obligatoriedad, formato, tamaño, vigencia y responsable de emisión.

Una evidencia reemplazada queda no vigente, nunca borrada del historial. Falta confirmar si el mismo documento puede respaldar varios detalles.

### PP01-F07 — Guardar borrador

Guardar únicamente por acción explícita. Debe persistir cabecera, detalles, montos, evidencias y auditoría.

Pendientes de decisión:

- si se permite borrador sin detalles;
- si el borrador reserva cuota;
- duración del borrador;
- quién puede editarlo o asumirlo;
- comportamiento al quedar obsoleto por cambios externos.

### PP01-F08 — Validar y enviar

Antes de enviar:

1. comprobar autorización vigente;
2. comprobar PDS y funcionario habilitados;
3. comprobar cuota disponible y no duplicada;
4. validar monto positivo y saldo contractual;
5. validar tope normativo y presupuesto;
6. comprobar periodo/hito y evidencias;
7. ejecutar reglas dinámicas;
8. solicitar confirmación al usuario;
9. guardar todo y cambiar estados en una transacción;
10. crear la tarea de la etapa siguiente.

Si un detalle falla, debe identificarse cuál y por qué. Falta decidir si se bloquea toda la solicitud o se permite excluirlo antes de enviar.

### PP01-F09 — Corregir, anular y reintentar

Una devolución permite modificar únicamente montos, periodos solicitados, selección, motivos y evidencias del pago.

Anular marca cabecera y detalles como no vigentes/cerrados y libera compromisos según la política aprobada. Un reintento debe reutilizar la PDS, cuota y evidencias vigentes, creando un nuevo detalle trazable.

## 5. Reglas de monto

```text
saldo_contractual =
    sg_fups.mto_total
  - suma_pagada
  - suma_comprometida_en_solicitudes_enviadas

monto_nuevo <=
    MIN(saldo_contractual, saldo_presupuestario, saldo_tope, saldo_cuota)
```

- `mto_solpag` debe ser mayor que cero.
- Un pago parcial exige `motivo_ajuste`.
- El total de cabecera se deriva de detalles vigentes.
- El mes solicitado no es la fecha efectiva de pago.
- Las decisiones de excepción deben identificar actor, motivo, evidencia y vigencia.

## 6. Validaciones y severidad preliminar

| Validación | Severidad preliminar |
| :--- | :--- |
| PDS no formalizada | Bloqueo |
| Usuario sin autorización | Bloqueo |
| Cuota pagada o comprometida | Bloqueo |
| Monto sobre saldo aprobado | Bloqueo |
| Monto cero/negativo | Bloqueo |
| Evidencia obligatoria ausente | Bloqueo al enviar |
| Mes solicitado posterior al ejecutado | Informativa |
| Licencia, permiso, receso o ausencia | Alerta/observación; DGDP decide |
| Falta de saldo presupuestario | Bloqueo o pendiente de saldo, por confirmar |
| Excepción formal vigente | Advertencia y trazabilidad |

## 7. Datos de salida mínimos

```text
cabecera: nro_solici_pago, nro_solpds, estado, solicitante, titular/delegación, fechas
detalle: id_pagdet, cuota, funcionario, monto solicitado, periodo, estado, motivo
resumen: total solicitado, pagado previo, comprometido, pendiente y saldo presupuestario
documentos: tipo, id_docum, vigencia, autor y fecha
auditoría: actor, perfil, acción, estado anterior/nuevo, fecha y observación
```

## 8. Criterios de aceptación esenciales

- Una PDS con varios funcionarios muestra pagados y pendientes sin permitir seleccionar pagados.
- Dos usuarios no pueden enviar simultáneamente la misma cuota.
- Un detalle parcial exige motivo y conserva saldo pendiente.
- Una devolución no permite editar datos de la PDS.
- El envío fallido no deja cabecera, detalle y cuota en estados contradictorios.
- El usuario conoce qué dato proviene de PDS, qué dato ingresa y qué regla lo bloquea.

## 9. Preguntas específicas pendientes

El banco completo está en [preguntas_pp01_solicitante_pago.md](./preguntas_pp01_solicitante_pago.md). Las decisiones de cuota dependen de [ADR-PP-001](./decision_cuotas_creadas_en_pago.md).
