# PP03 — Requerimientos de Dirección de Finanzas

**Estado:** levantamiento funcional  
**Actor principal:** analista/autorizador de Finanzas  
**Entrada:** uno o más detalles aprobados por DGDP  
**Salida:** detalle pagado, pendiente de saldo, observado o rechazado

## 1. Objetivo

Revalidar disponibilidad presupuestaria, autorizar el monto financiero y registrar la referencia contable y fecha efectiva de cada detalle, manteniendo trazabilidad de pagos parciales y falta temporal de fondos.

## 2. Frontera pendiente

ClickUp S0-009 debe confirmar si SecGen:

1. solo consulta saldo;
2. consulta y reserva;
3. genera un compromiso en FIN21;
4. solicita ejecución a Tesorería/Remuneraciones;
5. o únicamente registra `nro_transac` y `f_pago` informados externamente.

Hasta esa decisión, ninguna maqueta se considera autorización para ejecutar transferencias.

## 3. Principios

- Finanzas resuelve por detalle.
- El saldo se calcula con información vigente, no con la vista previa de PP01.
- La autorización debe considerar compromisos activos de SecGen aún no reflejados en FIN21.
- Falta temporal de saldo no modifica la PDS.
- `nro_transac` y `f_pago` pertenecen al detalle pagado.
- La cuota `sg_fume` pasa a pagada solo cuando su saldo queda cerrado según la regla de pago parcial.
- La cabecera se deriva de sus detalles: pagada, pago parcial, pendiente o cerrada.

## 4. Funcionalidades

### PP03-F01 — Bandeja financiera

Mostrar solicitudes recibidas con antigüedad, centro de costo, ítems, monto aprobado DGDP, cantidad de detalles y alertas presupuestarias.

### PP03-F02 — Consultar antecedentes

Mostrar:

- PDS, resolución y documento final;
- solicitante y responsable del centro;
- detalle aprobado DGDP;
- cuota y saldo contractual;
- evidencias y excepciones;
- historial de DGDP;
- financiamiento: UF, CC, ítem o códigos globales.

### PP03-F03 — Revalidar saldo

Agrupar detalles vigentes por:

```text
cod_unifin + cod_ccto + cod_sitm + moneda
```

Ejecutar `valida_saldo_cc_cs` o el contrato que lo reemplace con la suma de la agrupación. Luego descontar compromisos activos del nuevo workflow si no están incorporados en el saldo externo.

Mostrar saldo inicial, comprometido SG, monto evaluado, sobregiro/excepción, saldo remanente, fuente y fecha.

### PP03-F04 — Resolver falta de saldo

Por detalle se debe poder:

- autorizar si existe saldo;
- autorizar un monto menor, si negocio lo permite;
- dejar pendiente de saldo;
- observar por imputación incorrecta;
- rechazar por causal financiera definitiva.

Debe quedar definido cuándo se libera la cuota y si el reintento ocurre en la misma solicitud o en una nueva.

### PP03-F05 — Autorizar

Registrar `mto_autpag`, actor, perfil y fecha. La operación debe bloquear o reservar de forma transaccional la cuota/detalle para evitar doble compromiso.

Si el monto autorizado difiere del solicitado, debe exigirse causal y determinar quién acepta la modificación.

### PP03-F06 — Registrar pago

Para cerrar un detalle son obligatorios:

- monto efectivamente pagado;
- número de transacción o referencia contable;
- fecha/hora efectiva;
- mes/año real de pago si se conserva en `sg_fume`;
- usuario que registra;
- resultado de integración o fuente manual;
- conciliación/confirmación cuando aplique.

Varias transferencias para un mismo detalle requieren una tabla de movimientos o varios intentos; un único `nro_transac` no es suficiente.

### PP03-F07 — Cerrar expediente

Derivar estado global:

| Resultado de detalles | Estado global sugerido |
| :--- | :--- |
| Todos pagados | Pagada |
| Pagados y pendientes/rechazados | Pago parcial |
| Ningún pagado y falta saldo temporal | Pendiente saldo |
| Ningún pagado y cierre definitivo | Rechazada/cerrada |
| Todos resueltos y documentados | Archivada, si existe etapa documental |

## 5. Uso actual de `valida_saldo_cc_cs`

| Parámetro | Fuente propuesta |
| :--- | :--- |
| `@cod_unifin` | `sg_prse.cod_unifin` |
| `@cod_ccto` | `sg_prse.cod_ccto` |
| `@cod_sitm` | `sg_fups.cod_sitm` |
| `@cod_tipmov` | 21, sujeto a confirmación de Finanzas |
| `@valor` | suma de `sg_pade.mto_solpag` o `mto_autpag` del grupo |
| `@Afecta` | `'1'`, aunque hoy no se usa internamente |

Resultados útiles: `Estatus`, `Mensaje`, `Saldo`, `SaldoInicial`, `MontoSolicitado` y `SaldoRemanente`.

Brechas:

- tipos monetarios `decimal(15,2)` versus `decimal(19,2)`;
- `@Afecta` sin uso;
- ausencia de fecha explícita de evaluación;
- manejo de `itm_global`, `cc_global`, `pry_global`;
- ausencia de compromisos del workflow de pagos;
- excepciones históricas incluidas dentro del PA.

## 6. Estados financieros de detalle propuestos

| Estado | Significado | Efecto sobre cuota |
| :--- | :--- | :--- |
| En revisión Finanzas | Esperando análisis | Comprometida |
| Observado Finanzas | Requiere corrección | Depende de política |
| Pendiente saldo | Falta temporal | Liberar o reservar, pendiente |
| Autorizado | Aprobado para ejecutar | Comprometida |
| Enviado a remuneraciones | Entregado al ejecutor | Comprometida |
| Pagado parcial | Existe abono y saldo | Disponible por saldo o nueva cuota, pendiente |
| Pagado | Cierre completo | `sg_fume` pagada |
| Rechazado financiero | No procede | Liberar salvo bloqueo definitivo |

## 7. Datos mínimos por resultado financiero

```text
id_pagdet
mto_solicitado
mto_autorizado
mto_pagado
saldo_inicial
compromiso_sg
saldo_remanente
cod_unifin
cod_ccto
cod_sitm o imputacion global
nro_transac
f_pago
fuente_resultado
rut_actor
fecha_hora
causal y comentario
```

## 8. Preguntas bloqueantes Finanzas/Tesorería

1. ¿Quién consulta, quién autoriza y quién registra el pago?
2. ¿Existe doble firma o segregación entre autorización y registro?
3. ¿El PA de saldo es informativo o vinculante?
4. ¿Cuándo se reserva saldo y cómo se libera?
5. ¿Qué ocurre si dos solicitudes compiten por el mismo saldo?
6. ¿Se permite autorización menor al monto solicitado?
7. ¿Puede haber varias transacciones por detalle?
8. ¿Cuál es la confirmación definitiva del pago?
9. ¿Cómo se revierte una transacción errónea o anulada?
10. ¿Cómo se procesan proyectos/ítems globales?
11. ¿Quién reintenta un detalle pendiente de saldo?
12. ¿SecGen envía información a Remuneraciones/Tesorería o solo registra su respuesta?

## 9. Criterios de aceptación

- Dos detalles de una misma solicitud pueden terminar pagado y pendiente de saldo.
- El saldo final se recalcula inmediatamente antes de autorizar.
- Una falla transaccional no deja cuota pagada sin detalle/transacción.
- Un detalle pendiente puede reintentarse sin alterar la PDS.
- Cada pago permite rastrear monto, imputación, actor, fecha y referencia.
- El sistema impide pagar dos veces la misma cuota o superar el total aprobado.
