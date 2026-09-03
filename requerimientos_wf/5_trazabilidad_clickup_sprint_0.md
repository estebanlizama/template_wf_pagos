# Trazabilidad — Sprint 0 ClickUp y entregables locales

**Lista ClickUp:** [WF de Pago](https://app.clickup.com/90175529655/v/l/901713479167)  
**Tarea padre:** [Sprint 0 — Descubrimiento y decisiones](https://app.clickup.com/t/86e2kw64n)  
**Lectura realizada:** 2026-08-26, sin modificar tarjetas

## Matriz

| ClickUp | Objetivo | Entregable local | Condición de cierre |
| :--- | :--- | :--- | :--- |
| [S0-001](https://app.clickup.com/t/86e2kw6ew) | Actores y responsables | RACI completada desde plantilla de taller | titular, sustituto y límite por etapa |
| [S0-002](https://app.clickup.com/t/86e2kw6ey) | Inicio y término | Secciones 4–7 del documento maestro + ADR de frontera | eventos y sistemas externos explícitos |
| [S0-003](https://app.clickup.com/t/86e2kw6f6) | Agregado mensual | ADR-PP-001 y modelo conceptual | cardinalidad aprobada |
| [S0-004](https://app.clickup.com/t/86e2kw6fd) | Estados de cabecera | `6_estados_y_transiciones.md` | entrada, salida, actor y condición |
| [S0-005](https://app.clickup.com/t/86e2kw6fe) | Estados detalle/cuota | `6_estados_y_transiciones.md` | no deja cuota bloqueada sin dueño |
| [S0-006](https://app.clickup.com/t/86e2kw6fq) | Validaciones estáticas/dinámicas | Matriz de validaciones maestro/PP02 | fuente, fecha, severidad y actor |
| [S0-007](https://app.clickup.com/t/86e2kw6fv) | Severidad | Catálogo en documento maestro y PP02 | tratamiento inequívoco |
| [S0-008](https://app.clickup.com/t/86e2kw6fx) | Jefatura Directa | decisión de etapa/RACI | actor, evidencia, acción y retorno |
| [S0-009](https://app.clickup.com/t/86e2kw6g6) | Finanzas/Tesorería | PP03 + ADR de integración | responsabilidad ante fallos/reintentos |
| [S0-010](https://app.clickup.com/t/86e2kw6gb) | Evidencias | catálogo a completar con plantilla | obligatoriedad, formato, tamaño y vigencia |
| [S0-011](https://app.clickup.com/t/86e2kw6gj) | Escenarios | `7_escenarios_aceptacion.md` | cada regla crítica tiene positivo/negativo |
| [S0-012](https://app.clickup.com/t/86e2kw6gk) | Review y cierre | acta de taller + backlog refinado | sin bloqueante sin dueño/fecha |

## Hallazgos al contrastar ClickUp y documentos

1. ClickUp mantiene correctamente el Sprint 0 como requisito previo, pero las versiones antiguas de los documentos presentaban decisiones pendientes como si ya estuvieran aprobadas.
2. Existía contradicción sobre crear cuotas en resolución o en pago.
3. Los documentos proponían `sg_fucu` sin considerar que el DDL real de `sg_fume` ya representa una cuota.
4. Faltaba separar estado global, estado del detalle e historial acumulado de la cuota.
5. La participación de Jefatura y la frontera con Tesorería continúan abiertas.
6. Las respuestas preliminares de talleres anteriores son valiosas, pero necesitan responsable y ratificación.

## Regla de sincronización

Cuando una decisión se apruebe:

1. completar la plantilla de decisión;
2. actualizar documento maestro y etapa afectada;
3. actualizar estados y escenarios;
4. registrar enlace o resumen en la tarjeta ClickUp correspondiente;
5. crear/ajustar tareas técnicas solo después del Definition of Ready;
6. conservar la decisión reemplazada como antecedente, no borrarla.

## Definition of Ready sugerido para futuras tarjetas

- enlace al requerimiento fuente;
- decisión funcional aprobada;
- actor y alcance;
- datos de entrada/salida y fuente;
- estados y transiciones;
- reglas, severidad y mensajes;
- permisos y auditoría;
- criterios de aceptación y escenarios;
- dependencias e integraciones;
- evidencia esperada para cerrar.
