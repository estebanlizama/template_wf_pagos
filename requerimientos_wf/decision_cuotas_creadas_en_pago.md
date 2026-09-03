# ADR-PP-001 — Cuota financiera y momento de creación

**Fecha de revisión:** 2026-08-26  
**Estado:** decisión técnica parcial; momento de creación pendiente de ratificación funcional  
**Relacionado con ClickUp:** [S0-003 — Definir agregado de pago mensual](https://app.clickup.com/t/86e2kw6f6)

## 1. Problema

Los documentos anteriores mezclaban tres conceptos:

1. mes o rango de ejecución aprobado en la PDS;
2. cuota financiera;
3. intento de pagar esa cuota dentro de una solicitud.

También proponían una tabla nueva `sg_fucu` porque se asumía que `sg_fume` solo almacenaba meses. El DDL real demuestra que `sg_fume` ya contiene número y estado de cuota, monto, validaciones, autorización, envío a remuneraciones y pago.

## 2. Decisiones técnicas vigentes

- `sg_fups` mantiene el funcionario de la PDS, su rango y el monto total aprobado.
- `sg_fume` será la cuota financiera canónica; no se creará `sg_fucu` mientras no exista una brecha funcional que lo justifique.
- La PK de cuota es `(id_funprse, nro_cuota)`.
- Una cuota no equivale necesariamente a un mes. Puede cubrir uno o varios periodos o un hito.
- `sg_pade` representará la inclusión o intento de una cuota en una solicitud de pago.
- El monto solicitado, el autorizado, el resultado individual y la transacción pertenecen a `sg_pade`, no se deben sobrescribir como único intento en `sg_fume`.
- `sg_fume` conserva el estado y resultado acumulado/final de la cuota.

## 3. Decisión funcional pendiente

Negocio debe escoger y ratificar una alternativa:

| Alternativa | Descripción | Ventaja | Riesgo |
| :--- | :--- | :--- | :--- |
| A — Plan previo | Las cuotas se crean al formalizar la resolución, pero no se derivan automáticamente de cada mes. | La cuota existe antes de PP01. | Exige definir plan y montos antes del pago. |
| B — Creación en pago | PP01 crea las cuotas al guardar/enviar la primera solicitud de pago. | Máxima flexibilidad. | Requiere control transaccional de correlativo y concurrencia. |
| C — Mixta | Resolución registra un plan modificable y PP01 materializa la cuota utilizada. | Conserva planificación y flexibilidad. | Mayor complejidad y riesgo de doble fuente. |

**Recomendación técnica:** alternativa B, porque evita igualar meses con cuotas y se alinea con pagos parciales o por hitos. Esta recomendación no se considera aprobada hasta cerrar S0-003.

## 4. Preguntas de cierre

1. ¿Quién define la cantidad de cuotas y en qué pantalla?
2. ¿La resolución firmada debe imprimir cantidad y monto de cada cuota?
3. ¿Una cuota puede cubrir varios meses o un hito sin mes específico?
4. ¿Se permite crear una nueva cuota cuando queda saldo después de un pago parcial?
5. ¿El número de cuota se conserva entre reintentos?
6. ¿Existe un máximo de cuotas por PDS, funcionario o año?
7. ¿`sg_fups.tot_cuotas` es plan aprobado, total definitivo o dato derivado?
8. ¿Qué significan exactamente `ano_prop/mes_prop`, `ano_ejec/mes_ejec` y `ano_pago/mes_pago`?

## 5. Modelo mínimo

`sg_paso` identifica la solicitud de pago y la PDS origen:

```text
nro_solici       PK/FK -> sg_soli
nro_solpds       FK -> sg_prse
f_creacion
vigente
```

`sg_pade` vincula la solicitud con la cuota:

```text
id_pagdet        PK
nro_solici       FK -> sg_paso
id_funprse       } FK compuesto -> sg_fume
nro_cuota        }
mto_solpag       decimal(19,2)
mto_autpag       decimal(19,2) null
ano_pag_sol      smallint
mes_pag_sol      tinyint
cod_estdet
motivo_ajuste
motivo_estado
nro_transac
f_pago
vigente
auditoría
```

Si una cuota cubre más de un periodo, se requiere una tabla hija de cobertura o una relación equivalente; `ano_ejec/mes_ejec` no alcanza para representar varios meses.

## 6. Invariantes

- Una PDS formalizada puede no tener cuotas todavía, según la alternativa aprobada.
- Una cuota pagada no puede volver a comprometerse.
- Una cuota no puede pertenecer a dos solicitudes activas al mismo tiempo.
- Un borrador no reserva saldo salvo decisión funcional expresa.
- Al enviar, el sistema debe validar en transacción el saldo contractual, presupuestario y la duplicidad.
- La suma pagada más comprometida más nueva no puede superar `sg_fups.mto_total`.
- Rechazar un intento no modifica la PDS ni retira al funcionario.
- Los importes nuevos usan `decimal(19,2)`.

## 7. Compatibilidad

- Los estados históricos 1–4 de `sg_ecuo` se conservan para datos anteriores.
- El PA `sg_fumeuSecgen01`, que elimina y reconstruye cuotas desde meses, no debe invocarse para el nuevo flujo mientras se mantenga esta separación conceptual.
- No se elimina ni renumera información histórica de `sg_fume`.

## 8. Criterios de aceptación de la decisión

- Existe una respuesta firmada para las ocho preguntas de cierre.
- La maqueta y los requerimientos dejan de referirse a `sg_fucu` como tabla confirmada.
- Los casos de pago parcial y reintento conservan la misma cuota y crean detalles distintos.
- Queda definido quién crea una cuota, cuándo y bajo qué estado inicial.
- La decisión actualiza BDD, PA, backend, frontend, pruebas y tarjetas de ClickUp afectadas.
