# Impacto 23 — Estados de cuota, observación, devolución de aprobadas y rechazo

**Fecha de contraste con código:** 30-10-2026. Implementado en fuentes; despliegue por confirmar.
**Módulo:** Pagos DU288 / Fase 2 — Ciclo de Vida de Cuotas y Revisión DGDP  
**Fuentes originales:**  
- `nuevo_workflow_fase_2/template_wf_pagos/rechazo_devolucion_y_estados.md`  
- `nuevo_workflow_fase_2/template_wf_pagos/comentario_devolucion_dgdp.md`  
- `nuevo_workflow_fase_2/template_wf_pagos/comentario_devolucion_dgdp_tabla.md`  
- `nuevo_workflow_fase_2/template_wf_pagos/decisiones_flujo_pago.md`  

**Archivos impactados:**
- **Procedimientos Almacenados / Base de Datos:**
  - `nuevo_workflow_fase_2/template_wf_pagos/cambios_pa/sg_epag/sg_epaguSecgen02.sql` (Transición a visación)
  - `nuevo_workflow_fase_2/template_wf_pagos/cambios_pa/sg_epag/sg_epaguSecgen03.sql` (Decisión DGDP: aprobar, devolver o rechazar)
  - `secgen_db.dbo.sg_epag` (Cabecera de cuota)
  - `secgen_db.dbo.sg_dpag` (Detalle de meses vinculados a la cuota)
  - `secgen_db.dbo.sg_fume` (Meses de ejecución del funcionario)
  - `secgen_db.dbo.sg_com1` (Comentarios y motivos de auditoría)
- **Backend:**
  - `src/controllers/service-provision/service-provision-payment.controller.ts`
  - `src/repositories/storedProcedures/service-provision-payment-procedures.repository.ts`
- **Frontend:**
  - `components/services-provision/payments/Du288PaymentDecisionModal.vue`
  - `pages/services-provision/payments/review/_staffProvisionId/_installmentNumber.vue`
  - `components/services-provision/payments/Du288InstallmentSummarySection.vue`

---

## 1. Máquina de Estados y Transiciones de la Cuota

La cuota transita a través de `sg_epag.cod_estcuo` siguiendo una máquina de estados controlada estrictamente por procedimientos almacenados con control de concurrencia (`holdlock`):

```
                     ┌──────────────────┐
                     │   1 PROPUESTA    │
                     └────────┬─────────┘
                              │ sg_epaguSecgen02
                              ▼
                     ┌──────────────────┐
         ┌──────────>│   2 EN VISACIÓN  │<──────────┐
         │           └────────┬─────────┘           │
         │                    │ sg_epaguSecgen03    │
         │                    ▼                     │
         │           ┌──────────────────┐           │
         │           │ 3 OBSERVADA /    │           │
         │           │   DEVUELTA       │───────────┘ (Reenvío tras corrección)
         │           └──────────────────┘
         │
         │ sg_epaguSecgen03
         ├───────────────────> 4 APROBADA DGDP ──(sg_epaguSecgen04)──> 8 ENVIADA A FINANZAS
         │
         └───────────────────> 10 RECHAZADA (Terminal / Meses bloqueados)
```

---

## 2. Acciones Resolutivas de DGDP (`sg_epaguSecgen03`)

### 2.1 Aprobación (`cod_estcuo = 4`)
- Requiere rol revisor DGDP asignado en `sp_orde` con `cod_organi = 696` y contrato vigente en `sp_cont`.
- Los meses asociados conservan `sg_fume.cod_estfum = 2` (Comprometida). El código `4` del mes significa Rechazada, no aprobación.
- La cuota queda lista para su remesa a Finanzas.

### 2.2 Observación / Devolución a Corrección (`cod_estcuo = 3`)
- **Motivo obligatorio:** El procedimiento rechaza si `@observacion` viene vacía (*«Indique el motivo de la devolucion o del rechazo.»*).
- **Conserva la cuota:** Los meses en `sg_dpag` se mantienen asignados a la cuota.
- **Trazabilidad en `sg_com1`:** Se registra un comentario con `id_tipacc = 32` (*Devolución a corrección*), guardando el RUT del revisor y la fecha.
- El solicitante / jefe de proyecto puede editar las compensaciones o montos y re-enviar la cuota (`sg_epaguSecgen02` transita de 3 a 2).

### 2.3 Rechazo Definitivo (`cod_estcuo = 10`)
- **Motivo obligatorio:** Exige texto explicativo formal en `@observacion`.
- **Bloqueo de meses:** `sg_epaguSecgen03` cambia los meses comprometidos de `2` a `4` (Rechazada), después de guardar su versión previa en `sg_fum2`.
- **Conserva la relación:** No elimina `sg_dpag`; mantiene el vínculo para consultar el intento rechazado.
- **Trazabilidad en `sg_com1`:** Se registra un comentario con `id_tipacc = 33` (*Rechazo definitivo*).
- **Estado terminal:** El rechazo no habilita automáticamente esos meses para un nuevo pago. Mostrar relaciones múltiples en el resumen tampoco autoriza repartir o pagar dos veces el mes.

---

## 3. Impacto en el Cálculo de Saldos y Montos Acumulados

### 3.1 Descuento de Cuotas Rechazadas
Al evaluar el saldo comprometido del funcionario (`amountCommitted` / `totalPresupuestado`):
- Anteriormente se evaluaba el total comprometido de la resolución sin descontar las cuotas rechazadas.
- **Decisión aplicada:** Las cuotas en estado `10` restan su valor del saldo ocupado del funcionario. El monto total comprometido vigente es:
  El saldo que presenta el detalle se calcula con `resolveProvisionRemainingAmount`: total autorizado menos enviado a pago, en trámite y rechazado. No se debe interpretar el rechazo como una liberación de saldo o de meses para otro ingreso.
- Esta lógica se implementó tanto en la consulta agregada de backend como en el visor de resumen del modal DGDP y la tarjeta de cuotas del funcionario.

## 4. Devolver una aprobada a DGDP (4 → 2)

- Endpoint `POST .../dgdp/provisions/{staffProvisionId}/installments/{installmentNumber}/reopen` y PA `sg_epaguSecgen05`.
- Exige motivo, cuota aprobada y todos sus meses comprometidos. No admite cuota ya enviada (8).
- Conserva `sg_dpag` y los meses en 2; guarda motivo, actor y fecha en `sg_com1`, acción 34 de `sg_tacc`.
- La carga `datos_base/05_sg_tacc_acciones_pago.sql` inserta solo las acciones faltantes 32, 33 y 34. El PA comprueba la 34 antes de modificar la cuota.
- En la sesión se observó una violación de FK por acción 34 ausente; el usuario informó haber agregado el catálogo. Falta evidencia del reintento satisfactorio en ambiente.
- La misma página de detalle sirve a revisión y a Finanzas; el botón de devolución se presenta al entrar desde Finanzas con estado 4.

## 5. Límites de este contraste

La transición 8 → 11 está descrita en catálogos, pero no se identificó aquí un escritor completo. La transición 4 → 8 existe en `sg_epaguSecgen04`, invocado por una API de lote con resultado individual; el PA recibe una sola cuota por llamada. Ninguna de ellas confirma el pago efectivo de remuneraciones.
