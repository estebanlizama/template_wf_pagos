# Escenarios y criterios de aceptación

**Estado:** mapa inicial para S0-011. Cada escenario debe completarse con datos reales anonimizados.

## Convención

Cada escenario debe incluir: precondiciones, datos, actor, pasos, reglas, estados esperados, auditoría, mensajes y resultado externo.

## ESC-PP-001 — Camino feliz individual

**Dado** una PDS formalizada, un funcionario habilitado, cuota disponible, evidencia vigente y saldo suficiente,  
**cuando** el solicitante envía, DGDP aprueba y Finanzas registra transacción y fecha,  
**entonces** detalle y cuota quedan pagados, la cabecera pagada y existe historial completo.

## ESC-PP-002 — Varios funcionarios, resultado mixto DGDP

Una solicitud contiene dos detalles. DGDP aprueba uno y observa otro. Debe quedar explícito si la cabecera permanece en DGDP o vuelve a corrección, sin perder la decisión aprobada.

## ESC-PP-003 — Rechazo individual

DGDP rechaza un detalle por causal definitiva y aprueba los demás. El funcionario no se retira de la PDS. Solo los aprobados avanzan a Finanzas.

## ESC-PP-004 — Observación corregible

Falta una evidencia. El sistema identifica documento, responsable y plazo; el solicitante reemplaza/carga sin modificar la PDS y reenvía conservando versiones.

## ESC-PP-005 — Licencia parcial con pago proporcional

Existe licencia dentro del periodo. El solicitante ingresa monto menor y motivo. DGDP visualiza fuente, periodo y justificación y decide sin cálculo automático oculto.

## ESC-PP-006 — Licencia parcial con producto cumplido

El solicitante pide pago total y adjunta constancia de cumplimiento. El resultado depende de la regla/excepción aprobada, registrando autorizador y evidencia.

## ESC-PP-007 — Pago de meses atrasados y actual

El mismo funcionario tiene coberturas de distintos meses disponibles. Se incluyen en una solicitud sin duplicar cuotas y mostrando claramente ejecución versus mes solicitado de pago.

## ESC-PP-008 — Pago parcial con saldo remanente

Una cuota base permite solicitar menos que su saldo. El detalle exige motivo, el pago no cierra el saldo total y el sistema permite un reintento posterior según decisión de cuota.

## ESC-PP-009 — Saldo insuficiente para un detalle

Finanzas paga un detalle y marca otro pendiente de saldo. La cabecera queda pago parcial; la PDS no cambia y el detalle pendiente conserva causal y posibilidad de reintento.

## ESC-PP-010 — Saldo insuficiente para todos

Ningún detalle puede pagarse. Debe definirse si la cabecera queda pendiente o cerrada y si las cuotas se liberan inmediatamente.

## ESC-PP-011 — Concurrencia sobre la misma cuota

Dos usuarios guardan borradores con la misma cuota. Solo uno puede enviarla; el segundo recibe conflicto actualizado y no queda saldo comprometido parcialmente.

## ESC-PP-012 — Concurrencia presupuestaria

Dos solicitudes distintas consumen el mismo saldo. La autorización transaccional permite únicamente montos compatibles con el saldo final y recalcula antes de confirmar.

## ESC-PP-013 — Anulación de borrador

El solicitante anula con motivo. Cabecera y detalles quedan no vigentes, se liberan compromisos y el historial se conserva.

## ESC-PP-014 — Devolución desde Finanzas

Finanzas detecta imputación o antecedente corregible. Debe identificarse quién corrige, qué campos quedan editables y cómo se conserva la aprobación DGDP.

## ESC-PP-015 — Falla de fuente externa

SISPER, documental o FIN21 no responde. El sistema no interpreta ausencia de respuesta como resultado favorable; registra contingencia, mensaje y posibilidad de reintento.

## ESC-PP-016 — Proyecto o ítem global

La PDS usa `cc_global/pry_global/itm_global`. Se aplica la ruta financiera aprobada y no se llama al PA estándar con códigos incompletos.

## ESC-PP-017 — Varias transacciones

Un detalle se paga mediante dos abonos. El modelo conserva cada movimiento y concilia la suma sin sobrescribir la primera referencia.

## ESC-PP-018 — Reversa

Finanzas informa que una transacción pagada fue anulada. Solo un actor autorizado ejecuta la reversa; se conserva el pago original y se recalculan cuota, detalle y cabecera.

## ESC-PP-019 — Delegación vencida

Un usuario guardó borrador con delegación vigente, pero esta vence antes del envío. El sistema revalida y bloquea el envío hasta nueva autorización.

## ESC-PP-020 — PDS histórica

Se intenta pagar una PDS anterior al nuevo workflow. Debe existir regla de compatibilidad que identifique cuotas, saldos y evidencias sin inventar datos.

## Matriz mínima de cobertura

| Regla crítica | Positivo | Negativo/excepción |
| :--- | :--- | :--- |
| autorización usuario | ESC-001 | ESC-019 |
| evidencia | ESC-001 | ESC-004/006 |
| validación normativa | ESC-001 | ESC-003/005/006 |
| pago parcial | ESC-001 | ESC-008 |
| saldo | ESC-001 | ESC-009/010/012 |
| duplicidad | ESC-001 | ESC-011 |
| integración | ESC-001 | ESC-015/016 |
| transacción | ESC-001 | ESC-017/018 |
| compatibilidad | ESC-001 | ESC-020 |

## Criterio de cierre S0-011

- cada regla bloqueante tiene al menos un escenario favorable y uno desfavorable;
- cada escenario identifica nivel de estado afectado;
- existen datos de prueba y resultado observable;
- se definen mensajes y auditoría;
- las decisiones pendientes tienen dueño y fecha;
- QA puede transformar el escenario en prueba sin inferir reglas.
