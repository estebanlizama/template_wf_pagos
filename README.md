# Workflow de pagos PDS — levantamiento funcional

Esta carpeta concentra el levantamiento, las decisiones y las maquetas del flujo de pagos asociado a prestaciones de servicios D.U. 009/2026 (DU288/DU09).

> Estado: **levantamiento funcional con integración parcial implementada**. La bandeja de solicitante ya existe; esta rama agrega acceso, cola y detalle de revisión DGDP con aprobar/observar/rechazar. Los SQL se entregan para certificación y no se consideran desplegados hasta ejecutarlos en Sybase.

## Fuente canónica

1. [Documento maestro](./requerimientos_wf/0_requerimientos_cu_pa_bdd_segun_wf_pagos.md): alcance, flujo, modelo conceptual y reglas transversales.
2. [PP01 — Solicitante](./requerimientos_wf/1_requerimientos_solicitante_pago.md).
3. [PP02 — DGDP](./requerimientos_wf/2_requerimientos_dgdp_pago.md).
4. [PP03 — Finanzas](./requerimientos_wf/3_requerimientos_direccion_finanzas_pago.md).
5. [Decisión sobre cuotas](./requerimientos_wf/decision_cuotas_creadas_en_pago.md).
6. [Banco de preguntas PP01](./requerimientos_wf/preguntas_pp01_solicitante_pago.md).
7. [Preguntas transversales y datos por levantar](./requerimientos_wf/4_preguntas_transversales_y_datos.md).
8. [Trazabilidad con Sprint 0 de ClickUp](./requerimientos_wf/5_trazabilidad_clickup_sprint_0.md).
9. [Estados y transiciones](./requerimientos_wf/6_estados_y_transiciones.md).
10. [Escenarios y criterios de aceptación](./requerimientos_wf/7_escenarios_aceptacion.md).
11. [Matriz de validaciones: de resolución a pago](./requerimientos_wf/8_matriz_validaciones_resolucion_a_pago.md).
12. [Catastro de validaciones y saldos](./requerimientos_wf/9_catastro_validaciones_y_saldos.md).

## Maquetas funcionales

- `01_vista_solicitante_pago.html`: vista completa del solicitante. Bandeja de pendientes, búsqueda por funcionario o por resolución, y expediente con dos pestañas: generación de la solicitud de pago y archivo de la resolución. Usa el sistema visual real del proyecto (`sg-solicitudes-frontend/assets/css/pds-du288.css`) y los datos de `mock_data_pago_du288.js`.
- `02_vista_dgdp_pago.html`: control normativo y resolución por detalle.
- `03_vista_direccion_finanzas_pago.html`: saldo, autorización, transacción y cierre financiero.
- `mock_data_pago_du288.js`: datos con la forma real de los payloads del backend, usados por la vista del solicitante.
- `mock_data_pagos.js`: datos ficticios usados por las vistas de DGDP y Finanzas.
- `style.css`: identidad visual usada por las vistas 02 y 03, pendientes de migrar al sistema visual del proyecto.
- [Guía visual y de contenido](./GUIA_VISUAL_Y_CONTENIDO.md): colores, vocabulario, estados y componentes esperados.

La vista del solicitante no define paleta propia: hereda los tokens `--pds-du288-*` del proyecto y cumple el [estándar visual obligatorio](../../estandar_visual/estandar_visual_obligatorio_du288.md). Los estados no deben distinguirse únicamente por color: siempre deben incluir texto e icono.

## Plantillas reutilizables

La carpeta `plantillas/` contiene formatos para taller, pregunta/decisión, requerimiento funcional, escenario de aceptación y tarjeta de ClickUp.

## Reglas de mantenimiento

- La autorización DGDP para pagos es `sp_orde.cod_organi = 696`, `rut_person` coincidente con el RUT autenticado y `vigente = 'S'`, además de contrato activo. No usar `cod_design = 696`, `sp_desg` ni el rol Director DGDP.
- La bandeja revisora lista estado 2. El detalle permite estado 2 → 3/4/10 y el rechazo devuelve los meses a propuesta y los desvincula de la cuota rechazada. La BDD actual solo persiste el estado de cuota; no guarda motivo, RUT ni fecha de revisión.
- Las rutas CRUD existentes del jefe de proyecto siguen sujetas a la autorización del centro de costo además del perfil/privilegios.
- Los artefactos de esta integración están en `cambios_pa/sg_usacs/`, `cambios_pa/sg_epag/sg_epagsSecgen03-04` y `cambios_pa/sg_epag/sg_epaguSecgen03`, con pares `.sql`/`.txt` alineados al esquema vigente. `datos_base/05_auditoria_revision_dgdp` es una propuesta opcional que amplía el esquema y no se requiere para estos PA.

- Distinguir siempre entre **confirmado**, **respuesta preliminar** y **pendiente**.
- Toda decisión debe indicar responsable, fecha, evidencia y documentos afectados.
- No usar la maqueta ni los nombres de sus objetos JavaScript como definición física de BDD.
- La PDS formalizada es el antecedente; el flujo de pagos no modifica sus datos aprobados.
- Mantener separados el estado global de la solicitud, el estado del detalle y el estado acumulado de la cuota.
- Un cambio funcional debe actualizar el documento maestro, la etapa afectada, la matriz de estados y sus escenarios.

## Ejecución local

Abrir cualquiera de las vistas HTML en un navegador. Si el navegador restringe recursos locales, servir la carpeta mediante un servidor HTTP local.

## Orden de aplicación de la integración DGDP

Los procedimientos todavía no están aplicados al servidor. Preparar y ejecutar en Sybase, con revisión de los códigos disponibles del sistema:

1. `datos_base/04_roles_privilegios_pagos.sql` crea el perfil 33 y sus permisos.
2. `cambios_pa/sg_usacs/sg_usacsSecgen01.sql` incorpora la derivación dinámica por organización 696 y contrato.
3. `cambios_pa/sg_epag/sg_epagsSecgen01.sql` instala el listado de cuotas compatible con la BDD.
4. `cambios_pa/sg_epag/sg_epagsSecgen03.sql` y `sg_epagsSecgen04.sql` instalan la bandeja y el detalle.
5. `cambios_pa/sg_epag/sg_epaguSecgen03.sql` instala aprobar/observar/rechazar por estado.

Cada artefacto tiene un `.txt` idéntico para certificación. Validar en el ambiente Sybase las consultas de contrato y los nombres/tipos de columnas locales antes de publicar el backend y frontend que las consumen.
