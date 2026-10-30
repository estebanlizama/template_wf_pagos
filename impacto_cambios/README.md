# Índice Maestro de Impactos, Decisiones y Cambios — WF Pagos DU288

Este directorio consolida el registro histórico y la evolución técnica de todas las decisiones, cambios de base de datos, procedimientos almacenados, backend y componentes de interfaz aplicados en el ecosistema de **SG-Solicitudes / Pagos DU288**.

**Revisión vigente: 30-10-2026.** Comenzar por [impacto 30 — consolidado de vistas, datos, acciones y ClickUp](impacto_30_consolidado_vistas_datos_acciones_y_clickup.md). Distingue implementado en fuentes, script preparado, decisión pendiente y evidencia de ambiente. Las marcas «Aplicado» de los documentos históricos no certifican despliegue ni aprobación de todas sus propuestas.

Cambios recientes: [impacto 29 — resumen por cuota y meses compartidos](impacto_29_resumen_cuotas_dgdp_y_meses_compartidos.md), estados corregidos en 23, archivo real y frontera SISPER en 24/26, filtros actuales en 25. La lectura de ClickUp incluye los sprints PP01, PP02, PP03, certificación y las tareas de despliegue/saldo.

Las seis descripciones de ClickUp fueron actualizadas y releídas el 30-10-2026, conservando sus estados y antecedentes. Texto publicado: [actualización ClickUp](clickup_actualizacion_2026_10_30.md).

---

## Catálogo Consolidado de Documentos de Impacto

| Documento | Título / Tema Principal | Capas Afectadas | Estado |
| :--- | :--- | :--- | :---: |
| [`impacto_04`](impacto_04_estados_en_uso_hoy.md) | Catálogo de estados en uso hoy | Base de Datos, Catálogos | ✅ Aplicado |
| [`impacto_05`](impacto_05_que_guarda_resolucion_en_fume.md) | Qué guarda la resolución en `sg_fume` | Sybase, Resoluciones | ✅ Aplicado |
| [`impacto_06`](impacto_06_montos_fups_vs_fume.md) | Cuadratura de montos `sg_fups` vs `sg_fume` | Base de Datos, Backend | ✅ Aplicado |
| [`impacto_07`](impacto_07_pa_resolucion_cambios.md) | Cambios requeridos en PA de resolución | Sybase, Procedimientos | ✅ Aplicado |
| [`impacto_08`](impacto_08_end_to_end_fume.md) | Flujo end-to-end de meses en `sg_fume` | Backend, Frontend, PAs | ✅ Aplicado |
| [`impacto_09`](impacto_09_backend_fume_completo.md) | Backend completo para meses `sg_fume` | Controladores, Repositorios | ✅ Aplicado |
| [`impacto_10`](impacto_10_limpieza_y_transiciones.md) | Limpieza de modelos y transiciones | Arquitectura Backend | ✅ Aplicado |
| [`impacto_11`](impacto_11_frontend.md) | Componentes de interfaz de meses | Frontend (Vue/Nuxt) | ✅ Aplicado |
| [`impacto_11_bis`](impacto_11_visador_y_borrador_sin_ddl.md) | Visador y borrador sin DDL | Sybase, Workflows | ✅ Aplicado |
| [`impacto_12`](impacto_12_bandeja_dgdp_sin_apso.md) | Bandeja DGDP sin depender de `sg_apso` | Backend, Repositorios | ✅ Aplicado |
| [`impacto_13`](impacto_13_apso_aislado_por_modulo.md) | Aislamiento de tareas de workflow por módulo | Workflow, Seguridad | ✅ Aplicado |
| [`impacto_14`](impacto_14_etapa_nueva_vs_flujo_nuevo.md) | Etapa nueva vs flujo nuevo en Sybase | Arquitectura Workflow | ✅ Aplicado |
| [`impacto_15`](impacto_15_frontend_ext_cuotas.md) | Extensión de cuotas en interfaz | Frontend, Componentes | ✅ Aplicado |
| [`impacto_16`](impacto_16_plan_implementacion_extension.md) | Plan de implementación de extensión | Planificación, Roadmap | ✅ Aplicado |
| [`impacto_17`](impacto_17_plan_front_extension.md) | Plan detallado de frontend de extensión | UI/UX, Componentes | ✅ Aplicado |
| [`impacto_18`](impacto_18_auditoria_anid_frontend.md) | Auditoría de componentes anidados en Vue | Frontend, Clean Code | ✅ Aplicado |
| [`impacto_19`](impacto_19_estado_validaciones_pago.md) | Estado de validaciones de pago | Reglas de Negocio | ✅ Aplicado |
| [`impacto_20`](impacto_20_revision_dgdp_edicion_monto_y_licencias.md) | Edición de montos y descuentos de licencias | Backend, Frontend DGDP | ✅ Aplicado |
| [`impacto_21`](impacto_21_compensacion_realizada_vs_comprometida.md) | Compensación realizada vs comprometida (`sg_fuc2`) | Base de Datos, Frontend | ✅ Aplicado |
| [`impacto_22`](impacto_22_atributos_faltantes_por_tabla.md) | Auditoría de atributos y propuestas de extensión | Sybase, DDL | Propuesta/histórico; verificar por atributo |
| [`impacto_23`](impacto_23_maquina_estados_cuota_rechazo_y_devolucion.md) | Máquina de estados, rechazo y reapertura 4→2 | Sybase (`sg_epag`), Backend | Contrastado en fuentes; ambiente pendiente |
| [`impacto_24`](impacto_24_cierre_pago_bandeja_finanzas_y_excel_sisper.md) | Cierre 4→8 y Excel proyectado desde SG | Sybase, Backend, Frontend | Código/API existentes; conexión y verificación parciales |
| [`impacto_25`](impacto_25_filtros_y_ux_bandeja_finanzas.md) | Filtros, selección y columnas reales de Finanzas | Frontend (`finance/index.vue`) | Contrastado al corte 30-10 |
| [`impacto_26`](impacto_26_ingreso_sisper_flexibilidad_anual_pa.md) | PA preparados y orquestación SISPER pendiente | Sybase (`sg_resli`, `sg_asdi`, `sg_ccai`) | Preparado; ingreso directo pendiente |
| [`impacto_27`](impacto_27_checklist_certificacion_e_interruptores.md) | Checklist de certificación, INTERRUPTOR-DU09 y catastro | Despliegue, Configuración | ⚠️ Checklist Activo |
| [`impacto_28`](impacto_28_resolucion_autoridades_y_ambiguedad_organigrama.md) | Resolución de autoridades y ambigüedad en `sp_orco` | Sybase, Workflow, UI | ℹ️ Documentado |
| [`impacto_29`](impacto_29_resumen_cuotas_dgdp_y_meses_compartidos.md) | Pestaña compartida DGDP/Finanzas, tarjetas por cuota y relaciones múltiples | Frontend, lectura existente | Implementado en fuentes |
| [`impacto_30`](impacto_30_consolidado_vistas_datos_acciones_y_clickup.md) | Inventario de pantallas/datos/acciones y matriz de actualización ClickUp | Documentación y trazabilidad | Revisión vigente 30-10-2026 |
