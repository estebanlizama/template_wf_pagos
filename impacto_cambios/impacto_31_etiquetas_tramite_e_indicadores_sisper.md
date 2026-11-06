# Impacto 31 — Etiquetas de trámite e indicadores de registro SISPER

**Fecha:** 02-11-2026. Implementado en fuentes. Requiere publicar backend/frontend y recompilar el PA indicado; no acredita instalación ni pago efectivo.

## Alcance aprobado

Actualización posterior del 02-11-2026: las descripciones de cuotas se muestran directamente desde `sg_ecuo.des_estcuo`, expuestas por el backend como `status`/`installmentStatus`. Se retiró la prioridad de los diccionarios locales y el reemplazo especial del borrador. Los filtros DGDP/Finanzas consumen el endpoint existente `installment-statuses` con `codEstcuo`/`desEstcuo`; el catálogo se conserva en Vuex. Solo la opción «Todos los estados», los colores/íconos por código y los contextos como «Esta cuota» permanecen propios de la UI. Si falta una descripción de fila, se muestra No informado, no una interpretación del código.

La carga inicial `datos_base/01_sg_ecuo.sql` se alineó con los nombres acordados. Si la base ya tiene los códigos vigentes y solo necesita actualizar las etiquetas, se puede usar `soporte_certificacion/07_sg_ecuo_descripciones.sql`, que contiene solo el UPDATE y la lectura de verificación, sin insertar códigos faltantes. Ambos pares SQL/TXT están sincronizados; no se ejecutó SQL en el ambiente desde esta sesión.

Se conservan códigos y transiciones de `sg_epag`, estados de meses y decisiones DGDP. Se precisan nombres de pantalla y se agregan comprobaciones de lectura independientes. Ninguna consulta de registro modifica el estado de la cuota.

| Dato | Presentación |
| --- | --- |
| Cuota 4 | Aprobada por DGDP; Aprobadas por DGDP en filtros |
| Cuota 8 | Enviada a remuneraciones |
| Acumulado antes llamado Pagado | Enviado a pago |
| Resumen antes llamado Pago parcial | Envío parcial a pago |
| Resumen antes llamado Pagada | Envío a pago completo |

El encabezado del detalle usa la etiqueta singular de la cuota, no el rótulo plural del filtro. Las tarjetas del resumen también traducen el estado de cada cuota con el mismo catálogo visual.

## Indicadores separados

La bandeja de Finanzas y el detalle abierto desde ella usan `Du288SisperRegistrationIndicators.vue`:

- Resolución SISPER: Registrada / No encontrada / Sin consultar (o Sin número externo).
- Asignación SISPER: Identificada / Posible coincidencia / No encontrada / Sin consultar.
- Centro de costo SISPER: Completo / Faltante / Con diferencias / Sin consultar.
- Registro SISPER: completo, incompleto, posible coincidencia, sin asignación registrada o sin consultar.

El indicador no informa «Pagada». Una cuota puede estar aprobada por DGDP y tener un registro SISPER completo al mismo tiempo, conservando su estado de trámite.

## Qué acredita registro completo

`sg_epagsSecgen06` mantiene las columnas anteriores y agrega comprobaciones sobre la asignación marcada para la cuota, no sobre la suma de todas las asignaciones de la misma persona/resolución/período:

1. Existe la resolución en `sp_resl` con número externo, tipo 2, unidad 05000000 y año.
2. Hay exactamente una asignación identificada por el marcador de la cuota en `ss_asds.observac`.
3. Su monto coincide con el neto de la cuota y su haber es 2417, conforme al contrato actual de ingreso.
4. Hay exactamente un CC para esa asignación, con unidad financiera, CC, subítem vigente único, importe y fechas coincidentes. Corresponde al alcance aprobado de 100 % en un CC.

El backend devuelve `integrityStatus`, `costCenterStatus`, `amountMatches`, `payrollCodeMatches` y `resolutionStatus` como atributos derivados. El campo `state` existente conserva los valores `registered`, `probablyRegistered`, `notRegistered` para no cambiar las guardas de ingreso ni el control de duplicados.

Si el PA instalado es anterior y no devuelve las comprobaciones, la integridad queda Sin consultar; no se deduce completa del marcador. Si falla la consulta, tampoco se informa No encontrada. Una coincidencia sin marcador requiere revisión y no acredita atribución exacta a la cuota.

## Consulta por página

La bandeja escucha el evento `input` de las filas visibles de BootstrapVue, ya reenviado por BaseTable. Consulta las cuotas de esa página en un lote mediante la API existente `sisper-status`, sin modificar el componente compartido DNA ni hacer una llamada por fila. La página ofrece actualización manual.

Las respuestas llevan una versión local para ignorar resultados de páginas anteriores que lleguen tarde. Cambiar página/filtros limpia los indicadores anteriores mientras se consulta. No se introduce polling ni se consulta todo el listado SISPER por cada render. El listado base conserva su mecanismo de carga previo; este cambio acota la consulta adicional de indicadores, no implementa paginación SQL del listado completo.

## Archivos y despliegue

- PA: `cambios_pa/sg_epag/sg_epagsSecgen06.sql` y `.txt`, idénticos.
- Backend: helper `src/utils/sisper-resolution.ts`, DTO `du288-sisper-registration-request.model.ts` y mapeo de `toSisperRegistrationStatus`.
- Frontend: etiquetas `lang/es/pds.js`, indicador compartido, helper `sisperRegistration.js`, bandeja Finanzas, encabezado del detalle y tarjetas por cuota.
- No requiere DDL, nuevos estados, cambios de índices ni ejecución de una transición.

Publicar backend/frontend y recompilar `secgen_db.Analisis2.sg_epagsSecgen06` del paquete actualizado. Verificar permisos de lectura existentes sobre `sp_resl`, `ss_asds`, `ss_ccas` y el catálogo de subítems desde el PA. Probar en el ambiente un registro completo, otro sin CC, diferencias de monto/ítem, posible coincidencia y consulta fallida. No se ejecutó Sybase desde esta sesión.

## Verificación local

Se agregan casos específicos para no confundir marcador con integridad, CC incorrecto/duplicado, montos y haber distintos, PA anterior sin campos e indicadores no consultados. La compilación/estándar visual se verifican con las herramientas del proyecto; no sustituyen la ejecución ASE ni la revisión visual de ambiente.

Resultado de esta sesión: backend compilado; 28 pruebas unitarias SISPER aprobadas; casos del helper frontend aprobados; ESLint de los archivos revisados aprobado; estándar DU288 validado en 55 archivos; plantillas compiladas y SQL/TXT idénticos. También se comprobó que una respuesta de página anterior no sobrescriba la actual y que un fallo de consulta no se presente como asignación ausente. No se hizo validación visual en navegador ni ejecución ASE.


### Ajuste de presentación: detalle de Finanzas

- La bandeja de Finanzas deja de mostrar Registro SISPER y de consultar sus comprobaciones por página.
- Al abrir el detalle desde Finanzas se consultan resolución, asignación de la cuota y centro de costo.
- Las tres etiquetas se muestran al final de los antecedentes de la prestación, sin sección independiente ni indicador global.
- Se conservan los resultados de coincidencia probable y diferencias; no equivalen a registro confirmado ni a pago efectivo.
- La actualización manual queda junto a las etiquetas del detalle.
