# Impacto 27 — Checklist Maestro de Certificación, Interruptores DU09 y Catastro de PAs

> Contraste 30-10-2026: checklist pendiente de evidencia por ambiente. Las cifras del catastro que siguen corresponden al informe fuente, no se recalcularon en esta revisión. Front/store y controller de pago mantienen sus constantes de bloqueo presupuestario en `false`; el detalle DGDP consume el mismo interruptor del store. `ATTENDANCE_TEST_RUT` está vacío en la fuente revisada. Comprobar el valor desplegado antes de certificar. Incluir `sg_epaguSecgen05`, acciones de catálogo 32/33/34, `sg_fumesSecgen03`, versionado completo y la corrección ASE 146 de `sg_epagsSecgen05` en la evidencia de pase (impacto 30).

**Fecha:** 27-10-2026 (Actualizado)  
**Módulo:** Pagos DU288 / Transversal — Despliegue, Configuración e Integridad de Procedimientos  
**Fuentes originales:**  
- `nuevo_workflow_fase_2/template_wf_pagos/checklist_validaciones_y_paso_a_certificacion.md`  
- `nuevo_workflow_fase_2/template_wf_pagos/INTERRUPTOR-DU09.md`  
- `nuevo_workflow_fase_2/template_wf_pagos/catastro_pa_vs_repo_procedimientos.md`  

---

## 1. El Interruptor Maestro: `INTERRUPTOR-DU09` (6 Puntos Críticos)

Durante la fase de desarrollo, la validación presupuestaria DU09 se relajó intencionalmente para permitir la prueba integral del flujo de cuotas mientras la base de datos de pruebas no tenía poblada la columna `ccto.afec_du9 = 'S'` en `fin21_db..es_ccto`.

Para el paso a **Certificación y Producción**, deben conmutarse estrictamente los siguientes 6 puntos:

| N° | Capa | Archivo / Ubicación | Cambio Requerido para Producción |
| :-: | :--- | :--- | :--- |
| **1** | Frontend | `store/service-provision-payment-detail.js` | `BALANCE_VALIDATION_BLOCKS_SUBMISSION = true` |
| **2** | Backend | `controllers/.../service-provision-payment.controller.ts` | `BALANCE_BLOCKS_SUBMISSION = true` |
| **3** | Base de Datos (PA Inserción) | `cambios_pa/sg_epag/sg_epagiSecgen01.sql` | Descomentar guarda `if @afec_du9 <> 'S'` |
| **4** | Base de Datos (PA Edición) | `cambios_pa/sg_epag/sg_epaguSecgen01.sql` | Descomentar guarda `if @afec_du9 <> 'S'` |
| **5** | Base de Datos (PA Envío) | `cambios_pa/sg_epag/sg_epaguSecgen02.sql` | Descomentar guarda `if @afec_du9 <> 'S'` |
| **6** | Base de Datos (Criterio CC) | `cambios_pa/sg_ccto/sg_cctosSecgen05.sql` | Invertir criterio DU288: usar `ccto.afec_du9 = 'S'` |

> [!WARNING]
> Los puntos 1 (Frontend) y 2 (Backend) deben desplegarse en sincronía para evitar errores de validación HTTP 422 o formularios bloqueados de forma inconsistente.

---

## 2. Catastro de Procedimientos: Desalineamiento con el Repo de Procedimientos

La auditoría de catastro identificó que el backend invoca 100 procedimientos almacenados en el módulo de pagos y prestaciones:
- **45 procedimientos invocados no están en `sissolic-procedimientos/` (el repositorio de release).**
- **32 de ellos viven únicamente en `nuevo_workflow_fase_2/cambios_pa/`.**
- Si el equipo de infraestructura despliega tomando como base el repositorio `sissolic-procedimientos/`, estos 32 procedimientos críticos no se instalarán.

### El caso crítico de `sg_usacsSecgen01`:
- La versión de `sissolic-procedimientos/` tiene 137 líneas y **no incluye** el rol revisor DGDP de pagos.
- La versión de `template_wf_pagos/cambios_pa/sg_usacs/` tiene 168 líneas e incluye `es_revisor_pago` mediante `sp_orde.cod_organi = 696`.
- **Impacto:** Si se despliega la versión antigua, el login funciona normalmente pero la bandeja de revisión DGDP aparece completamente vacía sin arrojar error.

---

## 3. Variables de Entorno e Higiene de Desarrollo

1. **Reloj Control Simulado (`ATTENDANCE_TEST_RUT`):**  
   En `service-provision-payment-procedures.repository.ts`, debe permanecer como cadena vacía (`''`). En ningún caso debe contener un RUT en producción.
2. **Interruptor de Autenticación (`DISABLE_AUTH`):**  
   En `nuxt.config.js`, no debe estar activo en producción. `NODE_ENV=production` debe forzarse en el despliegue.
3. **Validación de Revisor en `sg_epagsSecgen03`:**  
   Se incorporó la verificación en `sp_cont` para asegurar que el revisor DGDP posea contrato activo y no pertenezca a calidad honorario (`cod_calida <> '01'`).
