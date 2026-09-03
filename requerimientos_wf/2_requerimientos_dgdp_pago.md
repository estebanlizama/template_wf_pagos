# PP02 — Requerimientos de revisión DGDP

**Estado:** levantamiento funcional  
**Actor principal:** analista/revisor DGDP autorizado  
**Entrada:** solicitud enviada con detalles vigentes  
**Salida:** detalles aprobados para Finanzas, observados o rechazados

## 1. Objetivo

Resolver la procedencia normativa y documental de cada funcionario/cuota sin alterar la PDS formalizada. La decisión global se deriva de los resultados individuales.

## 2. Principios

- DGDP decide por `sg_pade`, no modificando `sg_fups.cod_estfun`.
- Un mismo expediente puede terminar con resultados mixtos.
- Toda observación o rechazo exige causal y comentario según catálogo.
- Una excepción debe identificar norma, autorizador, vigencia y evidencia.
- Las validaciones dinámicas se recalculan con fecha/hora y fuente.
- El monto que avanza a Finanzas es la suma de detalles aprobados.

## 3. Precondiciones

- solicitud en estado de revisión DGDP;
- tarea asignada a usuario/perfil vigente;
- al menos un detalle enviado;
- PDS y documento final visibles;
- evidencias accesibles;
- fuentes normativas disponibles o contingencia declarada.

## 4. Funcionalidades

### PP02-F01 — Bandeja

Mostrar solicitudes asignadas con antigüedad, prioridad, centro de costo, solicitante, cantidad de detalles, monto y alertas. Los filtros mínimos son número, resolución, funcionario, centro, estado y fecha.

### PP02-F02 — Encabezado e historial

Mostrar la cabecera de pago, PDS origen, resolución, solicitante/delegación, etapa, tiempo pendiente e historial completo. Los datos de origen son solo lectura.

### PP02-F03 — Revisar detalle

Por cada detalle mostrar:

- funcionario, cargo/estamento, actividad y modalidad;
- cuota y cobertura;
- monto aprobado PDS, solicitado, pagado y pendiente;
- licencias, inhabilidades, permisos, sin goce y otras restricciones;
- jornada/horario y compensación cuando aplique;
- evidencias, constancias y versiones;
- resultados de cada regla con fuente, fecha y severidad;
- decisiones anteriores sobre el mismo detalle/cuota.

### PP02-F04 — Gestionar observación

Observar un detalle requiere causal, comentario accionable y responsable de corrección. Debe definirse si:

- se devuelve inmediatamente toda la solicitud;
- se permite resolver los demás detalles primero;
- el retorno va a solicitante o Jefatura;
- existe plazo y número máximo de devoluciones.

### PP02-F05 — Aprobar o rechazar detalle

Acciones mínimas:

- aprobar;
- aprobar con excepción formal;
- observar;
- rechazar este intento;
- bloquear cuota por condición persistente, solo con autorización definida.

Rechazar un intento no cierra necesariamente la cuota. Debe indicarse expresamente si la causal es temporal, corregible o definitiva.

### PP02-F06 — Resolver solicitud

La solicitud solo avanza cuando todos sus detalles vigentes tienen una resolución DGDP. Si existe al menos un aprobado, esos detalles avanzan a Finanzas. Si no existe ninguno, la cabecera se cierra o devuelve según los resultados.

## 5. Matriz preliminar de validaciones

| Código | Regla | Fuente esperada | Severidad pendiente |
| :--- | :--- | :--- | :--- |
| VAL-DGDP-001 | PDS y resolución formalizadas | SecGen/documental | Bloqueo |
| VAL-DGDP-002 | Funcionario vigente en la PDS | `sg_fups` | Bloqueo |
| VAL-DGDP-003 | Licencia médica en periodo cubierto | SISPER/constancia | Por definir |
| VAL-DGDP-004 | Inhabilidad o incompatibilidad | fuente institucional | Bloqueo/excepción |
| VAL-DGDP-005 | Permiso sin goce | SISPER | Por definir |
| VAL-DGDP-006 | Cierre o incompatibilidad de centro de costo | FIN21/SecGen | Bloqueo |
| VAL-DGDP-007 | Jornada y compensación | contrato, `sg_fuco`, `sg_fuc2` | Por definir |
| VAL-DGDP-008 | Tope normativo | `sg_fups` + regla vigente | Bloqueo/excepción |
| VAL-DGDP-009 | Evidencia obligatoria y vigente | documental | Bloqueo al aprobar |
| VAL-DGDP-010 | Actividad/producto cumplido | evidencia/Jefatura | Por definir |

Cada resultado debe persistir como dato auditable o quedar registrado en historial estructurado; los cuatro flags de `sg_fume` no bastan para explicar varias evaluaciones.

## 6. Estados de detalle propuestos

| Estado | Responsable | Salida permitida |
| :--- | :--- | :--- |
| En revisión DGDP | DGDP | Aprobado, observado, rechazado |
| Observado DGDP | Solicitante/Jefatura | Reenviado o retirado |
| Aprobado DGDP | Sistema | En revisión Finanzas |
| Rechazado DGDP | DGDP | Cerrado o nuevo intento, según causal |
| Bloqueado normativo | DGDP autorizado | Desbloqueo excepcional o cierre |

Los códigos definitivos dependen de S0-005/S0-007.

## 7. Datos mínimos a registrar por decisión

```text
id_pagdet
cod_regla o cod_causal
resultado
severidad
comentario
rut_revisor
perfil
fecha_hora
estado_anterior
estado_nuevo
excepcion
id_documento_autorizacion
vigencia_excepcion
```

## 8. Preguntas bloqueantes DGDP

1. ¿Quién revisa y quién puede autorizar excepciones?
2. ¿Jefatura certifica antes de DGDP, en paralelo o fuera del sistema?
3. ¿Una observación individual devuelve toda la solicitud?
4. ¿Qué causales permiten corregir y cuáles cierran el intento?
5. ¿Cuáles reglas se heredan de la PDS y cuáles se recalculan por periodo?
6. ¿Qué ocurre si una fuente externa no responde?
7. ¿Licencia total bloquea siempre? ¿Qué cambia si el producto fue cumplido?
8. ¿Quién decide pago proporcional por ausencia?
9. ¿DGDP puede modificar el monto o solo aprobar/rechazar lo solicitado?
10. ¿Existe segunda firma, revisión o segregación de funciones?

## 9. Criterios de aceptación

- DGDP puede resolver dos detalles de una solicitud con resultados diferentes.
- Toda decisión muestra regla, fuente, fecha, actor y evidencia.
- Una observación indica exactamente quién corrige y qué puede modificar.
- Un rechazo DGDP no retira al funcionario de la PDS.
- Solo la suma aprobada DGDP avanza a Finanzas.
- Una excepción no puede autorizarse sin responsable y vigencia.
