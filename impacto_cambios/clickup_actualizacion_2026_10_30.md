# Texto de actualización de ClickUp — 30-10-2026

Copia de los bloques vigentes preparados desde el contraste de fuentes. Se agregan antes de las descripciones históricas, conservando estado, fechas y responsables.

Publicación confirmada en las seis tarjetas el 30-10-2026. Relectura posterior: bloque vigente e histórico presentes; estados conservados.

## [Sprint 2 — PP01 Solicitante](https://app.clickup.com/t/86e2kw64y)

## Estado vigente contrastado — 30-10-2026

Este bloque sustituye las afirmaciones históricas incompatibles de esta tarjeta. Revisión de fuentes locales; no acredita despliegue ni pruebas en ambiente.

**Vistas actuales.** Prestaciones por pagar y detalle de solicitud con pestañas **Gestión de pago / Antecedentes**. La nueva pestaña «Resumen de cuotas» está en el detalle compartido DGDP/Finanzas, no en el solicitante.

**Datos y acciones implementados:** funcionario/prestación/resolución externa, período y jornada, total/tope/cuotas autorizadas, CC/proyecto/responsable/financiamiento, presupuesto por ítem y semana comprometida; creación/edición de cuota, asociación de meses, mes de pago, montos, compensación realizada, PDF por cuota, guardado y envío con validaciones. Los importes por mes y sus descuentos alimentan solicitado/neto; los antecedentes de resolución se consultan.

**Persistencia:** sg_fups = marco autorizado; sg_fume = mes y montos; sg_epag = cuota; sg_dpag = relación cuota–mes; sg_fuco = compensación comprometida; sg_fuc2 = realizada; sg_fum2 = versiones; sg_epag.id_evidenc = respaldo.

**Límites actuales:** sg_dpag no guarda monto por relación. Que la consulta pueda mostrar un mes en varias cuotas no habilita su reparto monetario ni un segundo pago; esa definición requiere persistencia/guardas propias. Mes de ejecución y mes de remuneración son datos distintos.

**Pendientes para cierre:** verificar en ambiente montos fijos/variables, cupo autorizado/extensión, compensación, PDF y cuota observada; confirmar instalación de PA. Saldo y DU09 conservan interruptores desactivados en el código revisado. Reactivarlos después de confirmar fuentes/datos maestros y en sincronía con backend/SQL. No trasladar las antiguas marcas «por desplegar» como estado actual del servidor sin comprobación.

**Evidencia local:** template_wf_pagos/impacto_cambios/impacto_30_consolidado_vistas_datos_acciones_y_clickup.md; impactos 19, 20, 21 y 22. No se ejecutaron tests ni SQL durante esta revisión documental.

---

## [Sprint 4 — PP02 DGDP](https://app.clickup.com/t/86e2kw655)

## Estado vigente contrastado — 30-10-2026

Este bloque sustituye afirmaciones históricas incompatibles: **DGDP sí puede ajustar el aporte bruto**, los motivos **sí se guardan en sg_com1**, el versionado incluye descuentos/neto y el cierre **4→8 ya tiene PA/API**. Existencia en fuentes no acredita instalación.

**Detalle actual:** Cuota → Resumen de cuotas → Documento de respaldo → Documento de resolución. Revisión y Finanzas usan la misma página. La pestaña nueva presenta resumen general y tarjetas agrupadas por cuota, meses cronológicos, relación mes+cuota y meses sin asignar. Rojo rechazado, azul cuota actual, verde aprobado/enviado, amarillo otras en trámite y gris/candado no habilitado. Cuenta meses únicos; conserva todas las relaciones de meses compartidos y evita atribuirles un total por cuota sin desglose.

**Edición:** monto a pagar, licencia y permiso sin goce; sg_fumeuSecgen03 guarda versión previa en sg_fum2 y deja neto en sg_fume.mto_realpa. Se puede ajustar mes/año de pago durante visación. La query de todos los meses llama sg_fumesSecgen03; el SELECT directo de la documentación antigua es histórico.

**Decisiones y estados:** aprobar 2→4 conserva meses comprometidos (2); observar 2→3 conserva relaciones y registra motivo (acción 32); rechazar 2→10 bloquea meses (4), conserva sg_dpag y registra motivo (33). No libera automáticamente meses.

**Devolver aprobada:** endpoint reopen + sg_epaguSecgen05, de 4→2, desde detalle abierto por Finanzas; exige motivo y todos los meses comprometidos. sg_com1 guarda actor/fecha/motivo con acción 34. Se agregó guarda de catálogo faltante. El usuario informó haber cargado la acción 34 después de una FK; falta evidencia del reintento exitoso.

**Cierre:** sg_epaguSecgen04 actúa por cuota, versiona, lleva meses 2→3 y cuota 4→8, y persiste total neto de cierre. La API organiza lotes con resultado por cuota; la plantilla actual de Finanzas no tiene ese botón de cierre conectado. Tampoco se identificó congelación del neto de cabecera en la aprobación 2→4: esa mejora sigue pendiente.

**Pendientes:** prueba funcional/visual y PA instalados, fuentes normativas y biométricas, semántica de meses compartidos, segregación de funciones y devolución posterior 8→11. El detalle consume el interruptor presupuestario del store actualmente apagado; no declarar saldo siempre bloqueante. El pago efectivo es externo.

Fuentes: impactos 20, 21, 23, 29 y consolidado 30 de template_wf_pagos/impacto_cambios.

---

## [Sprint 5 — PP03 Finanzas](https://app.clickup.com/t/86e2kw658)

## Alcance vigente contrastado — 30-10-2026

El estado «completado» leído de esta tarjeta se conserva. La siguiente ampliación documenta la bandeja y sus nuevos límites; **no acredita ingreso directo a SISPER, conciliación completa ni remuneración pagada**.

**Vista Cuotas para Finanzas:** consulta aprobadas (4) y enviadas (8), muestra las 13 columnas del Excel, cuota/solicitud, oportunidad y acceso al detalle. Filtros: estado, oportunidad, rango de pago, funcionario, RUT, CC, resolución, solicitud y cuota. «Pago desde» abre vacío y «Pago hasta» usa el mes actual para incluir anteriores. Actividad y fechas de envío no están en el formulario actual.

**Archivo actual:** una descarga desde SG, Cuotas_Finanzas_AAAAMM.xlsx, hoja Finanzas. Corr; Nombre; RUT; Código Haber; Monto; Fec_inicio; Fec_Termino; CC; Item; Porcentaje CC; Nº Resol; Cod_Unidad Res; Año Resol. Una fila por cuota seleccionada, usando projectFinanceExcelRows, sin exigir asignación previa en SISPER. Selección individual/todos los resultados y límite visual de 300 cuotas.

**Datos:** netAmount; fechas del mes programado de cada cuota; CC de la prestación; 100 % y unidad 05000000. El código fija haber 2417: ratificar frente a la indicación anterior de que depende de la prestación. El puente de subítem convierte solo 300→30000, 303→30300 y 306→30600; los demás quedan sin equivalencia. Nº Resol usa el dato externo y Año Resol se entrega separado.

**Atrasos:** compara mes programado con «Pago hasta». Cambiar el filtro no reprograma fechas ni montos. Existe aviso por varias cuotas de una misma prestación/mes; la descarga actual no bloquea ese conflicto ni todos los campos incompletos. Requiere validación antes de tratar el archivo como definitivo.

**Detalle compartido:** pestaña Resumen de cuotas con tarjetas por cuota/mes y devolución de aprobada 4→2 con motivo.

**Preparado en backend/SQL:** API de consulta finance-excel-rows y sg_epagsSecgen05 para leer asignaciones/CC existentes; corrección local de error 146, sin nueva ejecución ASE verificada. API de cierre por lote y PA sg_epaguSecgen04 por cuota. La plantilla actual solo conecta la descarga de lote.

**Pendientes de la ampliación:** botón/endpoint de ingreso directo con resolución→asignación→CC; recuperación de inserciones parciales y control de duplicados; vínculo persistido cuota↔ficha/cod_asign SISPER; conciliación de importaciones externas; caso atrasos vs vigente recurrente y solapamiento del primer mes. sg_asdiSecgen01 acepta año de pago distinto del año de resolución, pero solo un mes completo.

Fuentes: impactos 24–26, 29 y consolidado 30 de template_wf_pagos/impacto_cambios. No se cambió el estado de esta tarjeta ni se dio por certificada la ampliación.

---

## [Sprint 6 — Integración, seguridad y certificación](https://app.clickup.com/t/86e2kw659)

## Revisión de alcance para certificación — 30-10-2026

Contraste de código e impactos; ninguna nueva ejecución en ASE, navegador o pruebas E2E durante esta actualización.

**Incluir en la matriz de aceptación:**
- Solicitante: crear/guardar/enviar cuota, PDF, montos fijos/variables, compensación y cuotas observadas.
- DGDP: edición de bruto/licencia/permiso, neto persistido e historial completo; aprobar, observar y rechazar con motivo.
- Reapertura 4→2 con sg_epaguSecgen05: catálogo acción 34 instalado, comentario/actor/fecha y meses comprometidos.
- Cierre 4→8 con sg_epaguSecgen04: API por lote/resultado individual, PA por cuota, meses 2→3, fec_envrem y netos consistentes.
- Resumen: ambas entradas al detalle, agrupación por cuota y meses compartidos sin perder relaciones ni duplicar conteo/importes.
- Excel: 13 encabezados reales, selección, neto, CC, 100 %, unidad, resolución externa, subítem y fechas; campo incompleto y mismo funcionario/prestación/mes.
- Diciembre→enero conservando año de resolución; no asumir registro recurrente de varios meses.
- Compilación y ejecución ASE de sg_epagsSecgen05 tras corrección error 146; no confundir su conciliación con la proyección del archivo.
- Concurrencia/reintento, autorización por RUT autenticado y mensajes sin datos sensibles.
- Logs: las fuentes actuales usan log-masking en SybaseService; verificar que no filtren parámetros sensibles en ambiente.

**Bloqueos/pendientes:** activar saldo/DU09 solo tras confirmar marcas y fuente; completar controles documentados sin fuente; confirmar esquema/PA realmente instalados. Ingreso directo SISPER y relación cuota↔asignación siguen sin orquestación, por lo que su evidencia debe agregarse después del desarrollo. Exportación, registro SISPER y pago efectivo son hechos distintos.

**Decisiones por ratificar:** cuenta 2417 fija frente a haber por prestación, reprogramación de atrasos, semántica del rango recurrente y monto por relación de un mes compartido.

Evidencia local: impacto_27 y nuevo impacto_30 de template_wf_pagos/impacto_cambios. Las cifras de catastro antiguas no se recalcularon; confirmar el paquete de entrega real y su par SQL/TXT antes del pase.

---

## [[DEPLOY] PA pendientes de instalar — compensación DGDP y contadores de bandeja](https://app.clickup.com/t/1dfdzjea3rk)

## Revisión de dependencias de despliegue — 30-10-2026

La lista anterior se conserva como antecedente; esta lectura **no comprobó qué objetos están instalados hoy**. No marcar instalación finalizada por existencia del archivo local.

Además de compensación DGDP y contadores, verificar:
1. sg_fumesSecgen03: lectura de todos los meses/relaciones usada por Resumen de cuotas en detalle DGDP/Finanzas.
2. sg_fumeuSecgen03 y sg_fum2: monto/descuentos/neto y versión previa completa, incluyendo rut_regist/f_regist.
3. sg_epaguSecgen03: rechazo bloquea meses y conserva sg_dpag; motivos acciones 32/33.
4. datos_base/05_sg_tacc_acciones_pago.sql: carga repetible de acciones faltantes 32, 33 y 34.
5. sg_epaguSecgen05: devolución de aprobada 4→2 y guarda de acción 34 previa al cambio.
6. sg_epaguSecgen04: cierre 4→8, meses 2→3 y total neto.
7. sg_epagsSecgen05: recompilar corrección de error ASE 146 y ejecutar con selección controlada; sigue siendo consulta a SISPER existente, no la fuente de la descarga actual.
8. sg_usacsSecgen01 y rol revisor DGDP por sp_orde organización 696.
9. PA externos sg_resliSecgen01/sg_asdiSecgen01/sg_ccaiSecgen01: preparados para resolución/asignación/CC, permisos execute para UsuaVrac; su instalación no equivale a botón de ingreso conectado.
10. Pares .sql/.txt, catálogo y contrato backend/frontend del mismo paquete.

El usuario informó que agregó acción 34 tras el error FK_sg_com1_sg_tacc. Falta guardar evidencia de la devolución exitosa; no ejecutar ciegamente nuevamente sobre una cuota ya modificada.

Mantener checklist de INTERRUPTOR-DU09 y pruebas de permisos/datos por ambiente. Fuentes: impactos 23, 24, 26, 27 y 30 de template_wf_pagos/impacto_cambios.

---

## [Activar validación de saldo de centro de costo](https://app.clickup.com/t/86e2w3yw9)

## Precisión del alcance vigente — 30-10-2026

Separar reglas del formulario de resolución de las reglas del pago. Las cuatro validaciones históricas de esta tarjeta no equivalen por sí solas a un bloqueo de producción certificado.

**Código de pago observado:** BALANCE_VALIDATION_BLOCKS_SUBMISSION=false en store/service-provision-payment-detail.js y BALANCE_BLOCKS_SUBMISSION=false en el controller de pagos. El detalle DGDP consume el interruptor del store: no describir que el saldo siempre bloquea aprobar en esa vista mientras siga apagado.

**Dependencias:** confirmar saldo/ítem/movimiento y marcas fin21_db..es_ccto.afec_du9; coordinar los puntos SQL de creación/edición/envío y los criterios de sg_cctosSecgen05 con front/backend. El catastro identifica diferencias históricas entre los repositorios; comprobar los PA instalados del ambiente.

**Aceptación:** misma fuente/ítem y resultado visible entre solicitante y DGDP; bloquear únicamente conforme a regla activa; ausencia de dato no equivale a validación favorable; revalidar al enviar/resolver; evidencia con saldo suficiente/insuficiente y fuente no disponible.

La deuda sigue presentándose como validación pendiente sin fuente en el store revisado. ATTENDANCE_TEST_RUT está vacío en la fuente; no demuestra por sí solo el valor del despliegue.

Fuentes: impacto 19, checklist 27 y consolidado 30 de template_wf_pagos/impacto_cambios. Se conserva el estado de la tarjeta.

---

