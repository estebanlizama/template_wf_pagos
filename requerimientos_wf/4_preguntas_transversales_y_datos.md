# Preguntas transversales y datos por levantar

Este documento operacionaliza Sprint 0 de ClickUp. Las preguntas se formulan para obtener una decisión implementable, no solo una respuesta sí/no.

## 1. Método de entrevista

Por cada tema se debe preguntar en este orden:

1. describir el caso real y quién lo ejecuta hoy;
2. identificar evento de entrada y resultado esperado;
3. enumerar datos consultados, ingresados y generados;
4. separar camino normal, excepción, devolución y contingencia;
5. identificar quién decide y quién solo consulta;
6. definir cuándo la respuesta cambia;
7. obtener un ejemplo real anonimizado;
8. convertir la respuesta en regla, estado y criterio de aceptación.

## 2. S0-001 — Actores y responsabilidades

Preguntas:

- ¿Quién inicia, certifica, revisa, autoriza, ejecuta, confirma y corrige?
- ¿Quién reemplaza a cada actor por ausencia?
- ¿Cómo nace, vence y se revoca una delegación?
- ¿Una persona puede solicitar y aprobar el mismo detalle?
- ¿El responsable se determina por PDS, centro, proyecto, unidad o funcionario?
- ¿Qué acciones administrativas puede realizar soporte?

Datos a capturar: actor, perfil, unidad, alcance, titular, sustituto, fuente de asignación, vigencia, acciones permitidas/prohibidas, segregación y SLA.

## 3. S0-002 — Inicio, término y frontera

Preguntas:

- ¿Qué estado/documento exacto habilita la primera solicitud?
- ¿Debe haberse cumplido el mes o hito antes de crear borrador?
- ¿SecGen termina al autorizar, enviar, pagar, conciliar o archivar?
- ¿Qué sistemas participan y cuál es maestro de cada dato?
- ¿Qué ocurre cuando una integración no responde?
- ¿Quién reabre o revierte un proceso cerrado erróneamente?

Datos: evento, estado origen/destino, sistema emisor/receptor, timestamp, identificador externo, confirmación, timeout, reintento y responsable de contingencia.

## 4. S0-003 — Agregado y cardinalidad

Preguntas:

- ¿Una solicitud contiene exactamente una PDS?
- ¿Puede mezclar funcionarios, meses, cuotas, ítems o monedas?
- ¿Qué representa una cuota y cuándo se crea?
- ¿Una cuota puede tener varios intentos y pagos parciales?
- ¿Cuál es la unidad mínima que DGDP y Finanzas pueden resolver?
- ¿Qué identifica un reintento?

Datos: claves de cabecera, detalle, cuota, cobertura, intento y movimiento; cardinalidades; unicidades; reglas de vigencia.

## 5. S0-004/S0-005 — Estados

Para cada estado preguntar:

- ¿Qué significa funcionalmente?
- ¿Quién y qué evento permite entrar?
- ¿Qué campos son editables?
- ¿Reserva cuota o saldo?
- ¿Qué tareas quedan pendientes y para quién?
- ¿Cuáles son sus salidas válidas?
- ¿Qué ocurre al cancelar, caducar o fallar técnicamente?
- ¿Es terminal, reversible o histórico?

Datos: código, nombre, nivel, actor, entrada, precondiciones, efectos, editabilidad, SLA, transiciones y reversión.

## 6. S0-006/S0-007 — Validaciones y severidad

Preguntas por cada regla:

- ¿Se hereda de PDS o se recalcula en cada pago?
- ¿Cuál es la fuente maestra y fecha efectiva?
- ¿Aplica a PDS, funcionario, periodo, cuota o detalle?
- ¿Cuál es resultado favorable/desfavorable/no disponible?
- ¿Informa, advierte, observa, bloquea o admite excepción?
- ¿Quién puede autorizar la excepción y por cuánto tiempo?
- ¿Qué evidencia debe adjuntarse?
- ¿Qué pasa si la fuente externa falla?

Datos: código, norma, descripción, fuente, endpoint/PA, entrada, fecha, periodicidad, severidad, etapa, actor, excepción, mensaje y prueba.

Reglas mínimas: formalización, vigencia del funcionario, licencia, inhabilidad, sin goce, cierre de CC, jornada, compensación, tope, saldo contractual, saldo presupuestario, duplicidad y evidencia.

## 7. S0-008 — Jefatura Directa

Preguntas:

- ¿Debe certificar ejecución antes de DGDP?
- ¿Certifica solicitud completa, funcionario, cuota, periodo o evidencia?
- ¿Puede observar/rechazar y a quién devuelve?
- ¿Puede ser la misma persona que solicita?
- ¿Se requiere firma, declaración o documento?
- ¿Qué ocurre si no existe jefatura vigente?

Datos: actor/fuente, nivel de decisión, campos, declaración, firma/evidencia, estado, causal, SLA y sustitución.

## 8. S0-009 — Finanzas y Tesorería

Preguntas:

- ¿SecGen consulta, reserva, compromete, ordena o solo registra?
- ¿Quién determina ítem y puede corregir imputación?
- ¿Qué significa exactamente “sin fondos disponibles” en cada etapa?
- ¿Falta de saldo es temporal, rechazo o devolución?
- ¿Cuándo se libera una reserva?
- ¿Se permiten varias transacciones o abonos?
- ¿Cuál es la confirmación definitiva y cómo se reversa?

Datos: sistema, operación, parámetros, respuesta, reserva, expiración, transacción, conciliación, reversa, errores y responsable.

## 9. S0-010 — Evidencias

Preguntas:

- ¿Qué tipos existen por prestación/modalidad?
- ¿Cuál es obligatorio y en qué etapa?
- ¿A qué entidad se asocia?
- ¿Quién emite, carga, revisa y reemplaza?
- ¿Formato, tamaño, firma, vigencia y retención?
- ¿Puede reutilizarse y cómo se versiona?
- ¿Quién puede verla y descargarla?

Datos: código/tipo, descripción, aplicabilidad, obligatoriedad, formato, tamaño, firma, emisor, vigencia, retención, confidencialidad y relación.

## 10. S0-011 — Escenarios

Solicitar ejemplos reales de:

- camino feliz individual y agrupado;
- observación corregible;
- rechazo de un detalle y de toda la solicitud;
- licencia total y parcial;
- producto cumplido pese a ausencia;
- compensación horaria;
- pago parcial;
- falta de saldo y posterior reintento;
- dos usuarios seleccionando la misma cuota;
- proyecto o ítem global;
- falla de integración;
- pago registrado erróneamente y reversa.

Por escenario capturar: datos iniciales, acciones, estados, reglas ejecutadas, resultado, mensajes, auditoría y datos externos.

## 11. Inventario de datos

| Dominio | Datos mínimos | Fuente candidata | Dueño que debe confirmar |
| :--- | :--- | :--- | :--- |
| PDS | solicitud, resolución, actividad, periodo, modalidad, estado | `sg_soli`, `sg_prse`, documental | DGDP |
| Financiamiento | UF, CC, ítem, globales, tipo fondo, vigencia | `sg_prse`, `sg_fups`, FIN21 | Finanzas |
| Funcionario | RUT, cargo, estamento, contrato, rango, monto, estado | `sg_fups`, SISPER | DGDP |
| Cuota | número, cobertura, base, estado, pagado, saldo | `sg_fume` + detalle | PO/Finanzas |
| Solicitud pago | PDS origen, solicitante, etapa, total, fechas | `sg_soli`, `sg_paso` | PO |
| Detalle | cuota, monto solicitado/autorizado/pagado, estado, motivo | `sg_pade` | PO/DGDP/Finanzas |
| Validación | regla, fuente, fecha, resultado, severidad, excepción | nueva relación/historial | DGDP |
| Evidencia | tipo, documento, relación, versión, vigencia, autor | `sg_fuev` propuesta | DGDP/Documental |
| Ejecución | fecha, horas, periodo/hito, certificador | `sg_fuc2` y/o nueva cobertura | Jefatura |
| Pago | transacción, fecha, monto, conciliación, reversa | `sg_pade`/movimiento | Finanzas/Tesorería |
| Seguridad | perfil, tarea, delegación, alcance | `sg_apso`, perfiles, delegaciones | Seguridad/PO |
| Auditoría | actor, perfil, acción, anterior/nuevo, fecha, observación | `sg_hist` + detalle | Auditoría |

## 12. Criterio de pregunta cerrada

Una pregunta se considera cerrada solo si la respuesta permite:

- escribir una regla inequívoca;
- identificar fuente y propietario del dato;
- dibujar transición y responsable;
- definir mensaje/severidad;
- crear caso positivo, negativo y excepción;
- determinar impacto en BDD, PA, backend, frontend y operación.
