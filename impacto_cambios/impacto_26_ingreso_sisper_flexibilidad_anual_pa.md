# Impacto 26 — Ingreso Directo a SISPER: Flexibilidad Temporal y Procedimientos de Asignación

**Fecha de contraste con código:** 30-10-2026. PA preparados; ingreso directo desde aplicación pendiente.
**Módulo:** Pagos DU288 / Sybase — Integración con Remuneraciones SISPER  
**Fuentes originales:**  
- `nuevo_workflow_fase_2/template_wf_pagos/plan_ingreso_sisper.md`  
- `nuevo_workflow_fase_2/template_wf_pagos/cambios_pa/pa_externos/sg_asdiSecgen01.sql`  
- `nuevo_workflow_fase_2/template_wf_pagos/cambios_pa/pa_externos/sg_ccaiSecgen01.sql`  

**Archivos impactados:**
- **Procedimientos Almacenados / Base de Datos:**
  - `sisper_db.Analisis2.sg_asdiSecgen01` (Registro de asignación mensual en `ss_asds`)
  - `sisper_db.Analisis2.sg_ccaiSecgen01` (Imputación presupuestaria a centro de costo en `ss_ccas`)
  - `sisper_db.dbo.ss_asds` (Tabla física de asignaciones mensuales de personal)
  - `sisper_db.dbo.ss_ccas` (Tabla física de centros de costo por asignación)

---

## 1. El Problema del Desfase Anual (Diciembre → Enero)

En el procedimiento original de asignación de remuneraciones (`sg_asdiSecgen01`), existía una validación que forzaba a que las fechas de inicio y término del período de pago coincidieran estrictamente con el año decretado en la resolución:

```sql
-- Validación restrictiva original:
if substring(@fec_inicio, 7, 4) <> @ano or substring(@fec_termino, 7, 4) <> @ano
begin
    select 'El periodo no corresponde al ano de la resolucion' as msg
    return
end
```

### 1.1 Inviabilidad Operativa
Esta condición bloqueaba el caso más habitual en la gestión de pagos institucionales:
- Una resolución decretada en **diciembre de 2026** cuya primera cuota o cuota devengada se paga en **enero de 2027**.
- Bajo la regla anterior, era imposible registrar la asignación en SISPER, forzando modificaciones manuales riesgosas en la base de datos o retrasos de nómina.

---

## 2. Decisión Aplicada en los Procedimientos de Cambio

Se actualizó `sg_asdiSecgen01.sql` eliminando la exigencia de que el año de ejecución del pago sea idéntico al año de la resolución:

1. **El período deja de exigirse dentro del año de la resolución:**  
   Se permite que `@fec_inicio` y `@fec_termino` pertenezcan al año de la cuota real, mientras que `@ano` mantiene el año en que la resolución fue decretada en `sp_resl`.
2. **Validación de consistencia del mes:**  
   Se mantiene la validación de que `@fec_inicio` sea el primer día de un mes calendario y `@fec_termino` el último día de ese **mismo mes**.
3. **Flujo de Asignación en Dos Pasos:**
   - **Paso 1 (`sg_asdiSecgen01`):** Inserta en `sisper_db..ss_asds` y retorna `@codigo_asignac`.
   - **Paso 2 (`sg_ccaiSecgen01`):** Toma ese `@codigo_asignac` e inserta la distribución en `sisper_db..ss_ccas` con el valor asignado al centro de costo (`cod_unifin`, `cod_ccto`, `cod_item`).

## 3. Resolución y límites de la integración

Antes de la asignación debe existir la resolución externa en `sp_resl`, mediante `sg_resliSecgen01` cuando no exista. El tipo es 2 y la unidad 05000000. El original `sppres1` no se modifica; los equivalentes con formato viven en `cambios_pa/pa_externos`, con `execute` para `UsuaVrac`.

Se verificó en fuentes que `sg_asdiSecgen01` permite que el mes de pago sea de otro año, pero sigue exigiendo exactamente un mes completo. El Excel de ejemplo con un rango septiembre–diciembre no está implementado como asignación recurrente en ese PA.

No se encontró en las rutas de pago ni en el repositorio una orquestación que invoque los tres PA para una cuota. El helper `projectSisperRecords` prepara datos, pero no los inserta. Por ello, «PA preparado» no implica «botón Agregar a SISPER implementado».

Cada PA confirma su propia transacción. Faltan control de reintentos, recuperación de asignación creada sin CC, relación persistida con `sg_epag` y conciliación de ingresos hechos externamente. La referencia debe conservar ficha y código de asignación, además de cuota/resolución/período; una coincidencia por RUT y fechas no basta para atribuir el registro.

## 4. Decisiones y diferencias por resolver

- Porcentaje 100 y unidad 05000000: última instrucción del usuario y proyección actual.
- Haber: el código actual fija 2417, mientras una instrucción anterior indica que depende de la prestación. Ratificar fuente antes de extender a otras prestaciones.
- Monto: la proyección usa el neto de la cuota. El contrato funcional de `ss_asds.valor` para cualquier registro recurrente debe confirmarse con SISPER.
- Atrasos: clasificar una cuota como atrasada no cambia sus fechas. Falta definir y conectar una reprogramación explícita si debe pagarse en el mes que Finanzas procesa.
- Registro recurrente y superposición del primer mes con atrasos: decisión abierta; no generar dos pagos solapados por deducción del Excel.
