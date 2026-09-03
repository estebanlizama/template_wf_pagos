# Catálogo y transiciones del workflow de pagos

**Estado:** propuesta para talleres S0-004 y S0-005. Los códigos nuevos no están aprobados.

## 1. Principio

Una acción puede afectar hasta tres niveles, pero cada efecto se registra explícitamente:

```text
cabecera = etapa/resultado global del expediente
detalle  = resultado de una cuota en esta solicitud
cuota    = disponibilidad o pago acumulado de sg_fume
```

## 2. Cabecera de solicitud

| Estado propuesto | Actor/tarea activa | Editable | Salidas |
| :--- | :--- | :---: | :--- |
| Borrador | Solicitante | Sí | Enviada, anulada |
| En control ejecución | Jefatura, si se aprueba S0-008 | No salvo devolución | DGDP, devuelta, rechazada |
| En revisión DGDP | DGDP | No | Devuelta, Finanzas, rechazada |
| Devuelta a corrección | Solicitante | Solo pago | Reenviada, anulada |
| En revisión Finanzas | Finanzas | No | Autorizada, pendiente saldo, devuelta, pago parcial |
| Pendiente saldo | Finanzas/Solicitante, por definir | No o reintento | Revisión Finanzas, cerrada |
| Aprobada para pago | Finanzas/Tesorería | No | Enviada, pagada, reversada |
| Pago parcial | Finanzas | No | Pagada, cerrada con pendientes |
| Pagada | Sin tarea | No | Archivada/reversa administrativa |
| Rechazada | Sin tarea | No | Nuevo expediente si procede |
| Anulada | Sin tarea | No | Ninguna |
| Archivada | Sin tarea | No | Reapertura administrativa excepcional |

Pendiente: decidir si `Pendiente saldo` y `Pago parcial` son estados de cabecera o vistas derivadas.

## 3. Detalle/intento

| Estado propuesto | Significado | Reserva cuota |
| :--- | :--- | :---: |
| Ingresado | Seleccionado en borrador | Pendiente de decisión |
| Enviado | Superó controles PP01 | Sí |
| En control ejecución | Esperando certificación | Sí |
| En revisión DGDP | Revisión normativa | Sí |
| Observado DGDP | Requiere corrección | Depende de política |
| Aprobado DGDP | Habilitado para Finanzas | Sí |
| Rechazado DGDP | Este intento no procede | No |
| En revisión Finanzas | Evaluación presupuestaria | Sí |
| Observado Finanzas | Corrección de pago/imputación | Depende |
| Pendiente saldo | Falta temporal | Pendiente |
| Autorizado | Monto autorizado | Sí |
| Enviado remuneraciones | Entregado a ejecutor | Sí |
| Pagado parcial | Abono registrado | Sí/No por saldo |
| Pagado | Resultado cerrado | No; cuota cerrada |
| No vigente | Retirado/anulado | No |

## 4. Estados reales de `sg_ecuo`

| Código | Descripción actual | Uso nuevo propuesto |
| :---: | :--- | :--- |
| 1 | Propuesta | Histórico; no usar sin redefinir creación de cuota |
| 2 | En visación | Histórico |
| 3 | Observada | Histórico |
| 4 | Aprobada | Histórico |
| 5 | Disponible pago | Cuota seleccionable |
| 6 | Solicitada pago | Cuota comprometida en solicitud enviada |
| 7 | Autorizada pago | Cuota autorizada |
| 8 | Enviada remuneraciones | Cuota entregada al ejecutor |
| 9 | Pagada | Cuota cerrada |
| 10 | Rechazada | Definir si es intento o cuota definitiva |
| 11 | Devuelta Finanzas | Definir retorno y liberación |
| 12 | Bloqueada | Condición persistente con responsable |

Los estados 10 y 11 no deben reemplazar el estado detallado de cada intento. Una cuota puede conservarse disponible después de un intento rechazado corregible.

## 5. Transiciones críticas

| Evento | Cabecera | Detalle | Cuota | Condición |
| :--- | :--- | :--- | :--- | :--- |
| Guardar borrador | Borrador | Ingresado | Sin cambio o creada | política de creación/reserva |
| Enviar PP01 | Etapa siguiente | Enviado | Solicitada pago | validaciones y transacción OK |
| Observar detalle | Devuelta o permanece, pendiente | Observado | Solicitada o disponible, pendiente | definir atomicidad |
| Aprobar DGDP | En revisión DGDP/Finanzas | Aprobado DGDP | Solicitada pago | detalle válido |
| Rechazar intento | Mixto/rechazada | Rechazado DGDP | Disponible o rechazada | según causal |
| Sin saldo | Pendiente/pago parcial | Pendiente saldo | Disponible o solicitada | definir reserva |
| Autorizar | Aprobada/mixta | Autorizado | Autorizada pago | saldo bloqueado |
| Enviar ejecutor | Aprobada | Enviado remuneraciones | Enviada remuneraciones | contrato integración OK |
| Confirmar pago total | Pagada/mixta | Pagado | Pagada | transacción y fecha |
| Confirmar pago parcial | Pago parcial | Pagado parcial | Disponible/estado parcial pendiente | saldo persistido |
| Anular borrador | Anulada | No vigente | Disponible/sin cambio | liberar compromisos |

## 6. Reglas de transición

- Ningún estado cambia por actualización masiva basada solo en `nro_solici` sin validar detalle.
- Cada cambio registra actor, perfil, fecha, anterior, nuevo, causal y comentario.
- Las transiciones financieras se ejecutan bajo transacción.
- Un error técnico revierte todos los cambios de la operación.
- Una cuota pagada solo puede cambiar mediante reversa administrativa formal.
- Una cuota bloqueada debe tener causal, responsable y acción de desbloqueo.
- Caducar un borrador nunca borra registros; los marca no vigentes.

## 7. Preguntas para aprobación

1. ¿El borrador reserva cuota?
2. ¿Observación de un detalle devuelve toda la cabecera?
3. ¿Pendiente saldo libera inmediatamente la cuota?
4. ¿Pago parcial mantiene la misma cuota o crea otra por saldo?
5. ¿Rechazada en `sg_ecuo` es definitiva?
6. ¿Quién desbloquea y con qué evidencia?
7. ¿Existe estado de conciliación posterior al pago?
8. ¿Cómo se representa una reversa?
9. ¿Cuándo se archiva y quién puede reabrir?
10. ¿Qué estados se calculan y cuáles se persisten?
