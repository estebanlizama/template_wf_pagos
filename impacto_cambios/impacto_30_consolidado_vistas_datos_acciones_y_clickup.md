# Impacto 30 — Consolidado de vistas, datos, decisiones y actualización de ClickUp

**Corte de revisión:** 30-10-2026, zona America/Santiago.
**Base:** archivos actuales de frontend, backend y `cambios_pa`, impactos 19–29 y lectura de la lista ClickUp WF de Pago.
**Alcance:** inventario y corrección documental. No modifica funciones de la aplicación ni ejecuta SQL en la base.

«Implementado» significa presente en fuentes locales, incluso cambios sin commit. «Preparado» identifica scripts/helpers sin acción de usuario conectada. «Pendiente» requiere desarrollo o decisión. Ninguna de esas etiquetas acredita instalación, certificación ni pago efectivo.

La página de Finanzas estaba siendo ajustada durante el corte. La lectura final considerada es la versión con una sola descarga proyectada desde SG; queda reemplazada la descripción anterior de dos descargas. Volver a contrastar si cambia ese archivo antes del pase.

## 1. Inventario de vistas actuales

| Vista | Unidad de trabajo | Datos/acciones observados | Fuente principal |
| --- | --- | --- | --- |
| Prestaciones por pagar | Funcionario/prestación archivada | Filtros, pendientes y acceso a gestión | `pages/services-provision/payments/index.vue`, `sg_fupssSecgen18` |
| Detalle del solicitante | Solicitud con funcionario seleccionado y cuotas | Gestión de pago / Antecedentes; contexto decretado, presupuesto, semana, cuotas, compensación, respaldo, validaciones y envío | `payments/_nroSolici/index.vue`, store `service-provision-payment-detail` |
| Bandeja DGDP | Cuota | Consulta por estado, filtros, antigüedad y entrada al detalle | `payments/review/index.vue`, `sg_epagsSecgen03` |
| Detalle DGDP | Prestación + número de cuota | Cuota, Resumen de cuotas, Documento de respaldo, Documento de resolución; edición habilitada por estado y dictamen | `payments/review/_staffProvisionId/_installmentNumber.vue` |
| Cuotas para Finanzas | Selección de cuotas aprobadas/enviadas | Tabla con columnas del Excel, filtro de oportunidad, selección múltiple y una descarga desde SG; entrada al mismo detalle | `payments/finance/index.vue` |

La pestaña nueva Resumen de cuotas pertenece al detalle compartido DGDP/Finanzas; no se agregó al detalle del solicitante, cuyas pestañas actuales son Gestión de pago y Antecedentes.

## 2. Datos visibles y persistencia

| Dato | Fuente y almacenamiento | Tratamiento actual |
| --- | --- | --- |
| Funcionario, actividad, período, jornada, monto autorizado, tope y cuotas | `sg_fups` y contexto de prestación/resolución | Antecedentes decretados de lectura |
| Resolución visible | Número externo y año de `sg_rslc` | Identidad documental visible; no sustituye la clave interna usada para pedir el PDF |
| CC, proyecto, responsable, unidad y financiamiento | Contexto de `sg_prse` y consultas presupuestarias/personal | Se informa ausencia cuando no hay fuente |
| Semana de ejecución | `sg_fuho` | Compromiso semanal; componente compartido con resolución |
| Mes de ejecución | `sg_fume`, clave prestación+`corr_fume` | Período propuesto, monto vigente, descuentos, neto y estado del mes |
| Cuota | `sg_epag`, clave prestación+`nro_cuota` | Estado, mes/año de pago, evidencia y neto de cierre |
| Meses de la cuota | `sg_dpag` | Relación sin importe propio; no respalda reparto parcial entre cuotas |
| Monto solicitado por mes | `sg_fume.mto_apagar` | DGDP puede ajustar mediante `sg_fumeuSecgen03` cuando la cuota admite revisión |
| Descuentos | `sg_fume.mto_deslic`, `mto_dessg` | Edición explícita, valores no negativos y neto resultante |
| Neto por mes | `sg_fume.mto_realpa` | Se escribe al ajustar descuentos; el cierre completa solo nulos |
| Neto de cuota | `sg_epag.mto_realpa` | `sg_epaguSecgen04` lo escribe al cerrar 4→8; no se identificó esa escritura al aprobar 2→4 |
| Historia de mes | `sg_fum2` | Estado anterior, montos/descuentos, actor `rut_regist` y fecha `f_regist` |
| Compensación comprometida | `sg_fuco` | Antecedente de resolución |
| Compensación realizada | `sg_fuc2` | Declaración por mes; consulta/edición según actor y estado |
| Asistencia y ausencias | Consulta `sp_as01sSecgen01` y fuentes de asistencia | Antecedente, no atribución automática de trabajo a la PDS |
| Motivo de observar/rechazar/devolver aprobada | `sg_com1` + `sg_tacc` | Acciones 32/33/34; no requiere inventar columnas de observación en `sg_epag` |
| Evidencia | `sg_epag.id_evidenc` y repositorio documental | PDF por cuota, obligatorio para enviar; resolución firmada se consulta aparte |
| Registro SISPER | `sp_resl`, `ss_asds`, `ss_ccas` | PA preparados; falta orquestación y vínculo persistido a cuota SG |

Las propuestas de nuevos atributos del impacto 22 no se consideran instaladas. El archivo de esquema revisado no declara `fec_envepa` ni `rut_envepa`; el cierre fuente tampoco los escribe.

## 3. Acciones y efectos actuales

| Acción | Cambio | Observación para ClickUp |
| --- | --- | --- |
| Crear/guardar cuota | Cabecera y relaciones de meses | Borrador y envío son actos distintos |
| Adjuntar respaldo | Evidencia de la cuota | No sustituye la resolución firmada |
| Enviar a DGDP | Cuota 1/3→2; meses propuestos→comprometidos | Revalidación y controles estructurales; algunos bloqueos presupuestarios están apagados |
| Editar montos/descuentos DGDP | `sg_fume` + versión previa `sg_fum2` | La descripción antigua «DGDP solo edita descuentos» está superada |
| Ajustar mes/año de pago | `sg_epag.ano_pago/mes_pago` | Cambia período de pago; conserva período de ejecución |
| Aprobar | Cuota 2→4; meses siguen 2 | No ingresa SISPER ni confirma remuneración pagada |
| Observar | Cuota 2→3; conserva relaciones y meses comprometidos | Motivo guardado, acción 32 |
| Rechazar | Cuota 2→10; meses comprometidos→4 | Conserva `sg_dpag`, versiona; no libera automáticamente meses |
| Devolver aprobada | Cuota 4→2 | Motivo acción 34, todos sus meses en 2; disponible desde detalle abierto por Finanzas |
| Registrar envío | PA 4→8; meses 2→3; neto y fecha por mes | API de lote existente, PA por cuota; sin botón conectado en la plantilla actual de Finanzas |
| Descargar Excel | Genera archivo desde selección | No cambia estado ni demuestra ingreso SISPER |
| Agregar a SISPER | Pendiente | Faltan endpoint/orquestación, idempotencia, vínculo y resultado por cuota |
| Devolución posterior de Finanzas | 8→11, pendiente de escritor verificado | No confundir con reabrir aprobada 4→2 |

## 4. Resumen por cuota y meses repetidos

Ver impacto 29. Se conservan todas las relaciones mes+cuota, con agrupación por cuota y meses cronológicos. Rojo para rechazo; azul para cuota actual; verde para aprobadas/enviadas; amarillo para otras en trámite; gris/candado para no habilitados. El resumen general cuenta meses únicos.

Si un mes aparece en más de una cuota, no se inventan montos por relación. Mostrar la asociación es una mejora de consulta, no una nueva autorización de escritura ni la implementación de pago parcial del mes. Antes de habilitar ese pago deben definirse persistencia y validaciones para el reparto.

## 5. Archivo y bandeja de Finanzas al corte

La tabla y `Cuotas_Finanzas_AAAAMM.xlsx` usan las mismas 13 columnas: Corr, Nombre, RUT, Código Haber, Monto, Fec_inicio, Fec_Termino, CC, Item, Porcentaje CC, Nº Resol, Cod_Unidad Res, Año Resol.

- Fuente de la descarga actual: `projectFinanceExcelRows`, una fila por cuota desde SG.
- Neto: `netAmount` de la cuota; fechas: primer/último día de su mes programado.
- Proyección: porcentaje 100 y unidad 05000000. Haber 2417 fijo en código, pendiente de ratificar frente al criterio anterior de valor por prestación.
- Subítem: puente 300→30000, 303→30300 y 306→30600; otros códigos de tres dígitos no se completan por inferencia.
- Filtros actuales: estado 4/8, oportunidad, rango de pago, funcionario, RUT, CC, resolución, solicitud y cuota. Actividad y fechas de envío no están en el formulario actual.
- El filtro inicial incluye períodos anteriores hasta el mes actual. El período de proceso sale de «Pago hasta».
- Atraso: mes programado anterior al período procesado. No cambia automáticamente las fechas de la cuota ni las del archivo.
- Selección individual o de todos los resultados; límite visual de 300 cuotas.
- Existe aviso de dos cuotas de una misma prestación y mes de pago. La función de descarga actual no detiene ese caso ni los campos vacíos: endurecer validación antes de utilizarlo como archivo definitivo.
- Navegación conserva filtros explícitos en URL, pero no se encontró oportunidad en `detailRoute`.

La API conciliadora `finance-excel-rows` y `sg_epagsSecgen05` permanecen en backend, aunque la página actual ya no los llama para descargar. Consultar SISPER y preparar un registro para ingresarlo son dos operaciones distintas. No declarar implementada una conciliación automática completa.

## 6. Decisiones, implementación y pendientes

| Tema | Clasificación al corte | Próximo cierre requerido |
| --- | --- | --- |
| Cuota con varios meses; ejecución distinta de pago | Implementado | Evidencia en ambiente |
| Porcentaje 100 y unidad 05000000 | Indicación del usuario y proyección implementada | Contrastar una exportación real |
| Edición de bruto/descuentos y versionado | Implementado en fuentes | Confirmar PA y esquema instalado |
| Motivos 32/33/34 y reapertura 4→2 | Implementado en fuentes | Usuario informó carga de 34; falta reintento exitoso documentado |
| Corrección ASE error 146 | Script SQL/TXT actualizado | Recompilar y probar en ASE |
| Año de resolución distinto del mes de pago | Permitido por PA de asignación fuente | Caso diciembre→enero en SISPER |
| Rango recurrente septiembre–diciembre | Decisión abierta; PA actual solo mensual | Confirmar significado de valor, vigencia y solapamiento del primer mes |
| Haber por prestación frente a 2417 constante | Conflicto de decisión/código | Ratificar fuente y alcance |
| Ingreso directo de cuota a SISPER | Pendiente | Crear/reutilizar resolución, asignación y CC, con control de reintentos |
| Vínculo cuota↔asignación SISPER | Pendiente | Guardar identificadores y conciliar importaciones externas |
| Propuesta de congelar neto al aprobar 2→4 | No implementada en PA revisado | Decidir y actualizar contrato completo |
| Reprogramar atrasos al mes procesado | Pendiente | Acción explícita; hoy filtrar/clasificar no actualiza fechas |
| Bloqueos de saldo/DU09 | Interruptores apagados en fuentes | Confirmar datos maestros, reactivar sincronizados y certificar |
| Datos maestros de autoridades ambiguos | Diagnóstico documentado, no saneamiento acreditado | Resolver titular/subrogación con fuente autorizada; selector manual es propuesta |
| Certificación y producción | No verificadas | Instalación, pruebas, evidencias y aprobación del ambiente |

## 7. Hallazgos corregidos en los impactos

1. Impacto 23 decía que aprobar dejaba meses en 4: se corrige a 2.
2. Impacto 23 decía que rechazar liberaba meses y eliminaba `sg_dpag`: el PA bloquea y conserva la relación.
3. Impacto 24 atribuía al cierre campos que no escribe y un lote dentro del PA: se corrigen campos y frontera API/PA.
4. Impacto 24 listaba parámetros de PA como si fueran columnas Excel: se reemplaza por los 13 encabezados reales.
5. Impactos 24/25 describían descargas/filtros anteriores: se actualizan con la plantilla actual.
6. Impacto 26 marcado como aplicado no demostraba ingreso directo: se separan PA preparados y flujo pendiente.
7. Impacto 22 mezclaba propuestas DDL con estado efectivo: se agrega nota de vigencia.
8. Impacto 20 conservaba un SELECT directo histórico; la query actual llama `sg_fumesSecgen03`.
9. «Aplicado» en el índice no se usa como confirmación de despliegue de todos los documentos históricos.

## 8. Correspondencia con ClickUp

La lista consultada contiene 29 tareas en una página, sin más resultados; las seis de este alcance fueron leídas con descripción. Se actualizan descripciones con el corte vigente, conservando el texto anterior como histórico y sin cambiar estados, fechas ni responsables.

| Tarjeta existente | Estado leído | Actualización de alcance |
| --- | --- | --- |
| [Sprint 2 — PP01 Solicitante](https://app.clickup.com/t/86e2kw64y) | en curso | Vistas reales del solicitante, datos, acciones, límites y evidencia pendiente |
| [Sprint 4 — PP02 DGDP](https://app.clickup.com/t/86e2kw655) | en curso | Edición de bruto/descuentos, motivos persistidos, reapertura, cierre existente y nueva pestaña |
| [Sprint 5 — PP03 Finanzas](https://app.clickup.com/t/86e2kw658) | completado | Nueva bandeja y Excel preparados; integración directa/conciliación quedan pendientes y no se heredan como completas |
| [Sprint 6 — Integración, seguridad y certificación](https://app.clickup.com/t/86e2kw659) | pendiente | Pruebas de estados/datos, catálogo, errores ASE y trazabilidad SISPER |
| [[DEPLOY] PA pendientes de instalar — compensación DGDP y contadores de bandeja](https://app.clickup.com/t/1dfdzjea3rk) | pendiente | Ampliar lista de verificación con consultas de resumen, acción 34 y PA modificados; instalación por confirmar |
| [Activar validación de saldo de centro de costo](https://app.clickup.com/t/86e2w3yw9) | en curso | Separar reglas de solicitud/resolución y pago; confirmar interruptores y datos antes del bloqueo |

Se conserva el estado leído de Sprint 5 para no convertir una revisión documental en un cierre/reapertura funcional no solicitado. La descripción debe indicar que los nuevos pendientes exceden lo que se había dado por terminado.

**Resultado:** las seis descripciones se actualizaron correctamente el 30-10-2026 mediante el conector ClickUp y se volvieron a leer. Se conservan estado y bloque histórico. La copia de los textos publicados está en [clickup_actualizacion_2026_10_30.md](clickup_actualizacion_2026_10_30.md).

## 9. Evidencia y límites

Se contrastaron fuentes locales y descripciones ClickUp. No se ejecutaron nuevos tests, no se abrió la interfaz en navegador y no se consultó el catálogo vivo de Sybase en esta revisión documental. No se afirma que un PA esté instalado solo porque su archivo existe.

Para cerrar, adjuntar evidencia de: cuota borrador/enviada/observada/rechazada/aprobada/devuelta, mes repetido sin duplicar totales, descuentos guardados e historial, PDF, Excel de selección real, monto/ítem/haber/fechas validados, y caso de año distinto. Completar pruebas de SISPER después de implementar la orquestación y conciliación.
