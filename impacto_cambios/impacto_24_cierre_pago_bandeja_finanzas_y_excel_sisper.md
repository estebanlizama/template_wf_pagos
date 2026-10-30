# Impacto 24 — Cierre del Pago y Bandeja de Finanzas: Transición a Nómina (4 → 8), Conciliación y Excel SISPER

**Fecha de contraste con código:** 30-10-2026. Fuentes locales; no acredita instalación ni pago efectivo.
**Módulo:** Pagos DU288 / Fase 2 — Envío a Finanzas y Remesa a Nómina  
**Fuentes originales:**  
- `nuevo_workflow_fase_2/template_wf_pagos/implementacion_bandeja_finanzas.md`  
- `nuevo_workflow_fase_2/template_wf_pagos/plan_bandeja_aprobadas_finanzas.md`  
- `nuevo_workflow_fase_2/template_wf_pagos/plan_ingreso_sisper.md`  

**Archivos impactados:**
- **Procedimientos Almacenados / Base de Datos:**
  - `nuevo_workflow_fase_2/template_wf_pagos/cambios_pa/sg_epag/sg_epaguSecgen04.sql` (Marca masiva de envío a nómina: 4 → 8)
  - `nuevo_workflow_fase_2/template_wf_pagos/cambios_pa/sg_epag/sg_epagsSecgen03.sql` (Consulta de cuotas visadas y filtros de Finanzas)
  - `secgen_db.dbo.sg_epag` (`cod_estcuo = 8`, `mto_realpa`)
  - `secgen_db.dbo.sg_fume` (`cod_estfum = 3`, `fec_envrem`, `mto_realpa`) y `sg_fum2` (versión previa)
- **Backend:**
  - `src/controllers/service-provision/service-provision-payment.controller.ts` (`POST .../installments/sent-to-payroll`)
  - `src/repositories/storedProcedures/service-provision-payment-procedures.repository.ts` (`markInstallmentsSentToPayroll`)
  - `src/models/requests/du288-payment-sent-to-payroll-request.model.ts` (entrada del lote y resultado por cuota)
- **Frontend:**
  - `pages/services-provision/payments/finance/index.vue` (Bandeja integral de Finanzas)
  - `store/service-provision-payments.js` (Acción `markInstallmentsSentToPayroll`)
  - `utils/services-provision/normative/financeExcelProjection.js`
  - `utils/services-provision/normative/financeExcelConflicts.js`

---

## 1. El Nuevo Estado 8: «Ya enviadas a Finanzas»

Para cerrar la brecha donde las cuotas aprobadas (`cod_estcuo = 4`) quedaban en un estado terminal ciego sin acuse de recibo de Finanzas, se introdujo el estado `8`:

1. **Procedimiento `sg_epaguSecgen04`:**
   - Recibe una cuota aprobada (`id_funprse`, `nro_cuota`). La API organiza el lote y entrega resultado por cuota.
   - Transita `cod_estcuo = 4` a `cod_estcuo = 8`.
   - Versiona los meses en `sg_fum2`, cambia meses 2 → 3, escribe `sg_fume.fec_envrem`, completa su neto si es nulo y persiste la suma enviada en `sg_epag.mto_realpa`. No escribe `fec_envepa` ni `rut_envepa`: esos campos no corresponden al esquema revisado.
   - Valida pertenencia a la unidad DGDP y existencia de la cuota en estado 4.

2. **Bandeja de Finanzas (`finance/index.vue`):**
   - Selector de estado unificado:
     - **Por enviar a Finanzas (`cod_estcuo = 4`):** Revisión del detalle y descarga del archivo preparado desde SG.
     - **Ya enviadas a Finanzas (`cod_estcuo = 8`):** Consulta del conjunto marcado como enviado. No acredita pago efectivo.
   - En la página revisada el único botón de lote visible es descargar Excel. La API de cierre existe, pero no hay un botón de registro directo a SISPER ni de cierre masivo conectado en esa plantilla.

---

## 2. Generación del Archivo Excel SISPER (13 Columnas)

El archivo exportado contiene exactamente los campos requeridos por el sistema de remuneraciones (SISPER):

| N° | Columna SISPER | Significado en el Flujo SG |
| :-: | :--- | :--- |
| 1 | `Corr` | Consecutivo de exportación |
| 2 | `Nombre` | Nombre del funcionario |
| 3 | `RUT` | Sin puntos ni guion |
| 4 | `Código Haber` | Proyección actual: constante 2417 |
| 5 | `Monto` | `netAmount` de la cuota |
| 6 | `Fec_inicio` | Primer día del mes de pago de la cuota |
| 7 | `Fec_Termino` | Último día del mismo mes |
| 8 | `CC` | Unidad financiera y centro, separados por punto |
| 9 | `Item` | Equivalencia de subítem de cinco dígitos |
| 10 | `Porcentaje CC` | Proyección aprobada para este alcance: 100 |
| 11 | `Nº Resol` | Número externo de la resolución |
| 12 | `Cod_Unidad Res` | 05000000 |
| 13 | `Año Resol` | Año de resolución, independiente del año de pago |

### Regla de Prorrateo por Centro de Costo
El archivo actual se genera desde `projectFinanceExcelRows`: una fila por cuota, un CC y porcentaje 100. La lectura conciliadora `sg_epagsSecgen05` conserva una fila por asignación/CC existente y prorratea el neto; es otro contrato y no es la fuente de la descarga actual. No se debe describir ese prorrateo como comportamiento del archivo que hoy descarga la página.

---

## 3. Descarga actual y conciliación pendiente

La plantilla revisada expone una descarga: `Cuotas_Finanzas_AAAAMM.xlsx`, hoja `Finanzas`, con las cuotas seleccionadas. El mes del nombre sale del filtro «Pago hasta»; las fechas de cada fila mantienen el mes programado de esa cuota. Cambiar el filtro no reprograma automáticamente un atraso.

La API `finance-excel-rows` y `sg_epagsSecgen05` siguen disponibles para consultar SISPER. La corrección del error 146 localiza dentro de la subconsulta las columnas utilizadas por `SUM`, usando `#montos_cuota_finanzas`; falta evidencia de recompilación y ejecución exitosa en ASE.

La proyección traduce 300→30000, 303→30300 y 306→30600. Otros códigos de tres dígitos quedan sin equivalencia. La descarga actual no impide por sí sola exportar un ítem vacío o un conflicto de cuotas con el mismo mes: existe aviso de conflicto, pero no una validación integral previa al archivo.

Quedan pendientes el ingreso directo con los tres PA, la relación persistida cuota↔asignación SISPER, la conciliación del Excel externo y la confirmación de pago efectivo. La cuenta 2417 está fija en el código; contrasta con la instrucción previa de que el haber depende de la prestación y requiere ratificación funcional.
