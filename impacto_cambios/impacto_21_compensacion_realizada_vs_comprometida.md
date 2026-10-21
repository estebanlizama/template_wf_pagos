# Impacto 21 — Compensación Realizada vs Comprometida: Cierre por Totales, Días Hábiles y Validación DGDP

**Fecha:** 21-10-2026  
**Módulo:** Pagos DU288 / Fase 2 — Compensación Horaria (`sg_fuco` vs `sg_fuc2`)  
**Archivos impactados:**
- Procedimientos Almacenados / Base de Datos:
  - `nuevo_workflow_fase_2/template_wf_pagos/cambios_pa/sg_fuc2/sg_fuc2iSecgen01.sql`
  - `nuevo_workflow_fase_2/template_wf_pagos/cambios_pa/sg_fuc2/sg_fuc2iSecgen02.sql`
- Backend:
  - `src/controllers/service-provision/service-provision-payment.controller.ts`
  - `src/repositories/storedProcedures/service-provision-payment-procedures.repository.ts`
  - `src/db-assets/sybase-assets/queries/service-provision-payment/service-provision-payment.ts`
- Frontend:
  - `components/services-provision/payments/Du288ExecutedCompensationSection.vue`
  - `components/services-provision/payments/Du288PaymentMonthsReviewSection.vue`
  - `components/services-provision/payments/Du288CompensationDetailModal.vue`
  - `utils/services-provision/normative/compensationValidations.js`
  - `utils/services-provision/__tests__/weekendExecutionSchedule.test.cjs`
- Documento fuente original:
  - `nuevo_workflow_fase_2/template_wf_pagos/compensacion_revision.md`

---

## 1. Contexto y Diagnóstico del Problema

Durante la puesta en marcha del CRUD de compensaciones efectivas en la revisión y gestión de cuotas de pago, surgió una excepción HTTP 422:

```json
{ "statusCode": 422, "message": "Error: El tramo se superpone con una compensacion comprometida" }
```

### 1.1 Inversión del Propósito de las Tablas
El procedimiento `Analisis2.sg_fuc2iSecgen01` contenía una validación que rechazaba cualquier tramo realizado (`sg_fuc2`) que coincidiera con un tramo comprometido (`sg_fuco`). Esto invertía el modelo de datos:

| Tabla | Naturaleza | Propósito |
| :--- | :--- | :--- |
| `secgen_db.dbo.sg_fuco` | Planificada / Comprometida | Lo que el funcionario **se comprometió** a compensar en la resolución inicial. |
| `secgen_db.dbo.sg_fuc2` | Ejecutada / Realizada | Lo que el funcionario **efectivamente** compensó durante la ejecución de la cuota. |

Si el funcionario cumplió exactamente lo comprometido (mismo día y mismo horario), la validación errónea rechazaba precisamente el caso ideal. La prohibición de solapamiento solo es aplicable entre dos tramos **realizados** (nadie puede compensar dos veces al mismo tiempo), pero jamás contra su propio compromiso planificado.

---

## 2. Decisiones Técnicas y de Base de Datos

### 2.1 Eliminación de la Validación Errónea en `sg_fuc2iSecgen01`
Se retiró la comprobación que contrastaba contra `sg_fuco`, manteniendo intactas las validaciones legítimas de consistencia:

| # | Regla de Validación en `sg_fuc2iSecgen01` | Estado |
| :-- | :--- | :---: |
| 1 | Datos completos (fechas, horas, identificador) | Vigente |
| 2 | La prestación pertenece a la solicitud informada | Vigente |
| 3 | Modalidad DU288 (`cod_modprs = 2`) | Vigente |
| 4 | `dentro_jor IN ('S', 'D')` (requiere compensación horaria) | Vigente |
| 5 | El mes y cuota existen en `sg_fume` | Vigente |
| 6 | El mes admite cambios (estado 1 Propuesta, o cuota observada) | Vigente |
| 7 | Horas de inicio y término distintas | Vigente |
| 8 | Tramo dentro del período autorizado de la prestación | Vigente |
| 9 | No coincide con feriados nacionales | Vigente |
| 10 | **Fuera** de la jornada institucional (08:30 a 17:18 de lunes a viernes) | Vigente |
| 11 | Sin solapamiento con otro tramo **realizado** de la misma persona | Vigente |
| ~~12~~ | ~~Sin solapamiento con lo comprometido en `sg_fuco`~~ | **ELIMINADA** |

### 2.2 Asimetría Estructural entre `sg_fuco` y `sg_fuc2`
* `sg_fuco` pertenece a la resolución completa y **carece de dimensión de mes** (no tiene `ano_prop`, `mes_prop` ni `corr_fume`).
* `sg_fuc2` pertenece a la cuota mensual específica (`corr_fume`, `nro_cuota`).
* **Derivación en Frontend:** Para cruzar lo comprometido en un mes específico, el mes se deriva en el cliente desde `fec_compro`. Si un tramo cruza la medianoche a fin de mes, se imputa al **mes de inicio**.
* **Normalización en Backend:** El backend (`service-provision-payment-procedures.repository.ts`) proyecta `fec_compro` bajo el alias `compensationDate` para homogenizar la interfaz DTO en frontend.

### 2.3 Restricción Estricta a Días Hábiles en Base de Datos
El frontend ya exigía que toda compensación se realizara de lunes a viernes (`weekendExecutionSchedule.test.cjs`), prohibiendo sábados y domingos. Sin embargo, `sg_fuc2iSecgen01` solo evaluaba no cruzarse con la jornada institucional de 08:30 a 17:18, permitiendo involuntariamente compensar en fin de semana.

**Alineación en Sybase:** Se incorporó en el SP la restricción explícita de días hábiles:
```sql
if @dia_ini >= 5 or (@hora_ter < @hora_ini and @dia_ter >= 5)
begin
    select 'Error: La compensacion solo puede realizarse de lunes a viernes' as msg
    return
end
```

---

## 3. Reglas de Negocio en Frontend y Cierre por Totales

### 3.1 Cierre por Suma de Horas y no por Pareo Individual
Un tramo informado no está obligado a coincidir fecha a fecha con el comprometido; lo determinante es el **saldo total de horas del mes**:
$$\sum \text{Horas Informadas} \le \sum \text{Horas Comprometidas}$$
* Cuando la diferencia llega a $0\text{ h}$, el mes está saldado y no se admiten tramos adicionales.
* Se eliminó el botón de atajo que forzaba pareo exacto, vinculando las acciones al saldo restante.

### 3.2 Consistencia en el Modal de Revisión DGDP (`Du288CompensationDetailModal.vue`)
* **Defecto corregido:** El modal de revisión evaluaba cada día individualmente contra sí mismo (`execMins >= commMins`). Con 25 horas requeridas y 25 horas ejecutadas, si un día se compensaba 1 hora y otro día 7 horas, marcaba falsamente el día como *«Pendiente»*.
* **Regla unificada:** Lo que se audita son las horas del mes. Con `coverageComplete` cumplido:
  * El día con menos horas pasa a **Cumplida**.
  * Los días con horas extras pasan a rotularse como **Compensa otro día** (en verde), reflejando que cubren el déficit del día corto.

### 3.3 Higiene Visual y Corrección de Tokens CSS
1. **Tokens no definidos:** Se reemplazaron variables inexistentes (`--pds-du288-surface`, `--pds-du288-primary-soft`) por los tokens estándar institucionales (`--pds-du288-card-bg`, `--pds-du288-info-soft`, `--pds-du288-radius`).
2. **Desambiguación de saldos:** Se distinguió el *«Saldo por gestionar de la prestación»* del aviso *«Centro de costo sin saldo»*.
3. **Eliminación de tarjetas anidadas:** En la revisión de cuotas DGDP se retiró la tarjeta externa duplicada de ejecución, consolidando el título y los totales en el encabezado del calendario.

---

## 4. Estado de Implementación y Trazabilidad

| Hito / Requerimiento | Estado | Verificación |
| :--- | :---: | :--- |
| Retiro de validación contra `sg_fuco` en SP | Aplicado | Script en `cambios_pa/sg_fuc2/sg_fuc2iSecgen01.sql` |
| Restricción de compensación a lunes-viernes en SP | Aplicado | Validado en `weekendExecutionSchedule.test.cjs` |
| Derivación de mes comprometido en cliente | Aplicado | `Du288ExecutedCompensationSection.vue` |
| Calificación por cobertura mensual en DGDP | Aplicado | `Du288CompensationDetailModal.vue` |
| Corrección de tokens CSS y limpieza de tarjetas | Aplicado | `Du288PaymentMonthsReviewSection.vue` |
