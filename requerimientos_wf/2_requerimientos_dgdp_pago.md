# PDS Normativo D9 / DU288 / DU09

## Flujo de Pago - Pantalla PP02: Revision DGDP

### Requerimientos por pantalla, funcionalidad y casos de uso

---

# 1. Proposito de esta seccion

Este documento organiza la **Pantalla PP02: Revision DGDP de Solicitud de Pago PDS** para el workflow de pagos de Prestacion de Servicios.

La pantalla corresponde a la primera etapa revisora posterior al envio realizado por el solicitante de pago. Su objetivo es que DGDP pueda **visualizar toda la informacion de la PDS, revisar el pago solicitado por funcionario y periodo, validar el cumplimiento normativo del Decreto 009/2026 / DU288, revisar las evidencias adjuntas y resolver si el pago puede avanzar a Finanzas, debe corregirse o debe rechazarse**.

Se toma como referencia:

1. `reglas_restricciones_du288_d09.md`, para las reglas normativas aplicables.
2. `template-du09/04_vista_visacion_dgdp.html`, por su enfoque de auditoria por funcionario, estado individual, alertas, causales y trazabilidad.
3. `1_requerimientos_solicitante_pago.md`, como origen de la solicitud de pago enviada a revision.

---

# 2. Diferencia con DGDP del workflow de solicitud

En el workflow de solicitud, DGDP valida si un funcionario puede ser incluido en una PDS.

En el workflow de pago, DGDP valida si un funcionario ya aprobado **puede recibir el pago de un periodo especifico**, considerando:

| Aspecto | Solicitud PDS | Solicitud de pago |
| :--- | :--- | :--- |
| Momento | Antes de formalizar la PDS. | Despues de formalizar la PDS. |
| Objeto revisado | Incorporacion del funcionario a la PDS. | Pago de un periodo/mes de la PDS. |
| Datos clave | Elegibilidad, contrato, tope, actividad, SEA, compensacion. | Evidencia, periodo pagado, licencia, permiso, cierre, receso, deuda, duplicidad. |
| Resultado | Funcionario habilitado o excluido de la PDS. | Pago aprobado, devuelto o rechazado por funcionario/periodo. |

Regla base: DGDP no modifica la PDS original ni los montos aprobados. Solo resuelve la procedencia del pago solicitado.

---

# 3. Identificacion general de la pantalla

| Elemento | Descripcion |
| :--- | :--- |
| **Codigo de pantalla** | PP02 |
| **Nombre** | Revision DGDP de Solicitud de Pago PDS |
| **Perfil principal** | Analista / Profesional DGDP autorizado |
| **Flujo asociado** | Workflow de Pago PDS Normativo D9 / DU288 / DU09 |
| **Estado de entrada** | En revision DGDP |
| **Objetivo principal** | Revisar la procedencia normativa del pago por funcionario y periodo, con evidencia y validaciones a la vista. |
| **Resultado esperado** | Solicitud aprobada y derivada a Finanzas, devuelta a correccion o rechazada con causal trazable. |

---

# 4. Objetivo funcional de la Pantalla PP02

La pantalla debe permitir que DGDP:

1. Visualice la solicitud de pago enviada por el solicitante.
2. Visualice la PDS de origen y su resolucion/documento firmado.
3. Revise la nomina de funcionarios incluidos en el pago.
4. Acceda al detalle por funcionario y periodo solicitado.
5. Visualice montos, meses aprobados, pagados, en tramite y pendientes.
6. Revise la evidencia cargada para acreditar el cumplimiento de la prestacion.
7. Visualice las validaciones normativas del periodo de pago.
8. Determine si cada funcionario/periodo cumple, requiere correccion o debe rechazarse.
9. Registre causales y observaciones por funcionario.
10. Resuelva globalmente la solicitud de pago y derive a Finanzas si corresponde.

---

# 5. Estructura funcional general

| Codigo | Bloque de pantalla | Proposito |
| :--- | :--- | :--- |
| **PP02-B01** | Encabezado y resumen ejecutivo | Mostrar datos principales del pago, PDS, estado y montos. |
| **PP02-B02** | Expediente PDS de origen | Mostrar la PDS aprobada, centro de costo, funcionarios y resolucion firmada. |
| **PP02-B03** | Panel de funcionarios a pagar | Listar funcionarios/periodos incluidos y su estado de revision DGDP. |
| **PP02-B04** | Ficha normativa por funcionario | Mostrar datos contractuales, actividad, montos, topes, SEA y compensacion. |
| **PP02-B05** | Evidencias de ejecucion | Revisar archivos cargados por funcionario/periodo. |
| **PP02-B06** | Validaciones de pago | Mostrar controles de licencia, permiso, cierre, receso, deuda, duplicidad y otros. |
| **PP02-B07** | Decision individual DGDP | Aprobar, observar/devolver o rechazar por funcionario/periodo. |
| **PP02-B08** | Decision global y trazabilidad | Resolver la solicitud completa y registrar historial. |

---

# 6. Desglose funcional

---

# PP02-B01 - Encabezado y resumen ejecutivo

## Funcionalidad PP02-F01 - Visualizar resumen de la solicitud de pago

### A. Descripcion funcional

El sistema debe mostrar un resumen ejecutivo para que DGDP identifique rapidamente que se esta pagando, a quien corresponde, en que periodo y con que monto.

### B. Datos que debe mostrar el sistema

- ID de solicitud de pago.
- Estado actual: En revision DGDP.
- Usuario solicitante de pago.
- Fecha de envio.
- PDS de origen.
- Numero y anio de resolucion.
- Centro de costo.
- Jefe de proyecto.
- Periodo(s) solicitados a pago.
- Cantidad de funcionarios incluidos.
- Monto total solicitado.
- Monto observado, si existe.
- Monto rechazado, si existe.
- Monto habilitado para avanzar a Finanzas.

### C. Reglas de negocio

- El resumen debe actualizarse cuando DGDP apruebe, observe o rechace funcionarios.
- Si todos los funcionarios/periodos son rechazados, no se puede aprobar globalmente la solicitud.

### D. Historia de usuario

**HU-PP02-01:** Como DGDP, quiero ver un resumen ejecutivo del pago solicitado, para entender rapidamente el alcance de la revision.

### E. Requerimientos funcionales

- **RF-PP02-001:** El sistema debe mostrar identificacion y estado de la solicitud de pago.
- **RF-PP02-002:** El sistema debe mostrar monto total solicitado y monto vigente segun decisiones DGDP.
- **RF-PP02-003:** El sistema debe mostrar cantidad de funcionarios incluidos, aprobados, observados y rechazados.

---

# PP02-B02 - Expediente PDS de origen

## Funcionalidad PP02-F02 - Visualizar PDS aprobada y documento firmado

### A. Descripcion funcional

DGDP debe acceder a la PDS formalizada que da origen al pago, incluyendo su resolucion/documento firmado y los datos aprobados en el workflow anterior.

### B. Datos que debe mostrar el sistema

- Numero de solicitud PDS.
- Estado de la PDS de origen.
- Actividad general aprobada.
- Tipo(s) de prestacion.
- Periodo general aprobado.
- Centro de costo y financiamiento.
- Jefe de proyecto.
- Nomina original aprobada.
- Funcionarios excluidos en la PDS, si existieron.
- Documento de resolucion firmado en visor integrado.
- Anexos o documentos asociados.

### C. Reglas de negocio

- La PDS de origen es de solo lectura.
- El documento firmado debe estar disponible antes de aprobar un pago.
- Si el documento no existe o no es accesible, DGDP debe poder devolver la solicitud a correccion/regularizacion documental.

### D. Historia de usuario

**HU-PP02-02:** Como DGDP, quiero revisar la PDS y su resolucion firmada, para verificar que el pago solicitado tiene respaldo formal.

### E. Requerimientos funcionales

- **RF-PP02-004:** El sistema debe mostrar la PDS de origen en modo solo lectura.
- **RF-PP02-005:** El sistema debe mostrar la resolucion o documento firmado en un visor integrado.
- **RF-PP02-006:** El sistema debe alertar si falta el documento formalizado.

---

# PP02-B03 - Panel de funcionarios a pagar

## Funcionalidad PP02-F03 - Visualizar funcionarios y periodos incluidos en el pago

### A. Descripcion funcional

La pantalla debe listar los funcionarios incluidos en la solicitud de pago, mostrando el periodo solicitado y el estado de revision individual.

### B. Datos que debe mostrar el sistema

Por cada funcionario/periodo:

- RUT.
- Nombre completo.
- Estamento.
- Cargo/jerarquia.
- Periodo solicitado a pago.
- Monto del periodo.
- Actividad especifica.
- Estado individual DGDP: pendiente, cumple, observado, rechazado.
- Causal principal, si existe.
- Indicador de evidencia cargada.
- Indicador de alertas normativas.

### C. Reglas de negocio

- DGDP debe resolver todos los funcionarios/periodos antes de aprobar globalmente.
- Un funcionario puede aprobarse para un periodo y rechazarse para otro, si la solicitud permite multiples periodos.
- Los funcionarios rechazados no deben avanzar a Finanzas.

### D. Historia de usuario

**HU-PP02-03:** Como DGDP, quiero ver una lista clara de funcionarios y periodos a pagar, para revisar uno por uno su cumplimiento normativo.

### E. Requerimientos funcionales

- **RF-PP02-007:** El sistema debe listar funcionarios y periodos incluidos en el pago.
- **RF-PP02-008:** El sistema debe mostrar estado individual de revision DGDP.
- **RF-PP02-009:** El sistema debe permitir seleccionar un funcionario para ver su ficha completa.

---

# PP02-B04 - Ficha normativa por funcionario

## Funcionalidad PP02-F04 - Revisar antecedentes del funcionario evaluado a pago

### A. Descripcion funcional

Al seleccionar un funcionario, DGDP debe visualizar todos los antecedentes necesarios para determinar si el pago del periodo cumple con el Decreto 009/2026 / DU288.

### B. Datos que debe mostrar el sistema

- RUT y nombre.
- Estamento: academico, administrativo, tecnico, auxiliar u otro.
- Cargo/jerarquia.
- Unidad de desempeno.
- Contrato seleccionado para la PDS.
- Jornada y horas contratadas.
- Modalidad de ejecucion: dentro o fuera de jornada.
- Actividad especifica aprobada.
- Mes/periodo solicitado.
- Monto bruto mensual aprobado.
- Monto del periodo solicitado.
- Total aprobado en la PDS para el funcionario.
- Total pagado previamente.
- Saldo pendiente.
- Tope normativo calculado.
- Porcentaje de uso del tope.
- Condicion SEA, si aplica.
- Compensacion horaria registrada, si aplica.
- Excepcion ANID/DIUFRO/DITT, si aplica.
- Observaciones previas del workflow de solicitud.

### C. Reglas de negocio

- La ficha debe distinguir datos originales de la PDS y datos del pago actual.
- Los montos no deben ser editables por DGDP.
- Si el funcionario fue excluido en el workflow de solicitud, no puede aprobarse pago.
- Las alertas deben quedar visibles aunque no sean bloqueantes.

### D. Historia de usuario

**HU-PP02-04:** Como DGDP, quiero revisar la ficha normativa del funcionario evaluado a pago, para validar que el desembolso respeta las reglas del decreto.

### E. Requerimientos funcionales

- **RF-PP02-010:** El sistema debe mostrar datos contractuales y laborales del funcionario.
- **RF-PP02-011:** El sistema debe mostrar montos, saldos y topes normativos.
- **RF-PP02-012:** El sistema debe mostrar SEA, compensacion horaria y excepciones aplicables.
- **RF-PP02-013:** El sistema debe mostrar observaciones previas del workflow de solicitud.

---

# PP02-B05 - Evidencias de ejecucion

## Funcionalidad PP02-F05 - Revisar evidencia cargada por funcionario y periodo

### A. Descripcion funcional

DGDP debe revisar los documentos adjuntos que acreditan la ejecucion efectiva de la prestacion durante el periodo solicitado.

### B. Datos que debe mostrar el sistema

- Tipo de evidencia comprometida en la PDS.
- Descripcion esperada de la evidencia.
- Periodo asociado.
- Archivo cargado.
- Formato, peso y fecha de carga.
- Usuario que cargo el archivo.
- Vista previa o descarga.
- Estado DGDP de la evidencia: pendiente, aceptada, observada, rechazada.
- Comentario asociado a la evidencia.

### C. Reglas de negocio

- Todo funcionario/periodo solicitado debe tener evidencia.
- DGDP puede observar una evidencia y devolver la solicitud para correccion.
- DGDP puede rechazar el pago si la evidencia no acredita la labor o presenta inconsistencia grave.
- Si una evidencia es reemplazada en correccion, debe conservarse trazabilidad del archivo anterior.

### D. Historia de usuario

**HU-PP02-05:** Como DGDP, quiero revisar las evidencias cargadas por funcionario y periodo, para determinar si respaldan efectivamente el pago solicitado.

### E. Requerimientos funcionales

- **RF-PP02-014:** El sistema debe mostrar evidencias por funcionario y periodo.
- **RF-PP02-015:** El sistema debe permitir previsualizar o descargar la evidencia.
- **RF-PP02-016:** El sistema debe permitir marcar evidencia como aceptada, observada o rechazada.
- **RF-PP02-017:** El sistema debe exigir comentario cuando la evidencia sea observada o rechazada.

---

# PP02-B06 - Validaciones de pago

## Funcionalidad PP02-F06 - Visualizar controles normativos del periodo

### A. Descripcion funcional

El sistema debe mostrar para cada funcionario/periodo el resultado de las validaciones normativas que determinan si el pago procede.

### B. Validaciones requeridas

| Validacion | Resultado esperado |
| :--- | :--- |
| Licencia medica | Identificar si el periodo solicitado coincide total o parcialmente con licencia medica vigente. |
| Permiso sin goce de sueldo | Identificar si el funcionario tuvo permiso sin goce durante el periodo solicitado. |
| Cierre de proyecto o centro de costo | Verificar que la actividad/pago corresponda a un periodo dentro de vigencia. |
| Receso universitario | Identificar si el periodo corresponde a receso y si existe justificacion excepcional de trabajo efectivo. |
| Deudas institucionales | Mostrar si existen deudas no regularizadas, especialmente desde la regla 2027. |
| Inhabilidad por cargo | Verificar si el cargo sigue siendo habilitado o requiere excepcion. |
| Formacion continua | Verificar que la actividad no corresponda a diplomado, postitulo, postgrado, especialidad o curso similar. |
| Tope mensual | Comparar monto mensual contra el tope aplicable segun estamento. |
| Duracion/prorrateo | Verificar que el pago no exceda los meses autorizados por normativa. |
| SEA | Para academicos dentro de jornada, mostrar condicion SEA vigente o exigencia de compensacion. |
| Compensacion horaria | Para administrativos dentro de jornada, mostrar compensacion aprobada. |
| Duplicidad de pago | Verificar que el mismo funcionario/periodo no este pagado o en tramite. |
| Evidencia obligatoria | Verificar que exista respaldo documental para el periodo. |

### C. Semaforizacion sugerida

| Estado | Significado |
| :--- | :--- |
| Cumple | Validacion aprobada. |
| Alerta | Requiere revision DGDP, pero no necesariamente bloquea. |
| Bloqueante | No permite aprobar el pago mientras no sea corregido o resuelto. |
| No aplica | La regla no aplica al caso del funcionario. |

### D. Reglas de negocio

- Las validaciones bloqueantes deben impedir aprobar el funcionario/periodo.
- Las alertas deben exigir confirmacion o comentario DGDP si se aprueba.
- El sistema debe registrar fecha, resultado y fuente de cada validacion.
- Si un PA no existe aun, la pantalla debe dejar el dato como "pendiente de integracion" y no simular cumplimiento.

### E. Historia de usuario

**HU-PP02-06:** Como DGDP, quiero ver todas las validaciones normativas del periodo, para aprobar o rechazar el pago con fundamento.

### F. Requerimientos funcionales

- **RF-PP02-018:** El sistema debe mostrar validaciones normativas por funcionario/periodo.
- **RF-PP02-019:** El sistema debe distinguir validaciones cumplidas, alertas y bloqueantes.
- **RF-PP02-020:** El sistema debe registrar el resultado de cada validacion.
- **RF-PP02-021:** El sistema debe impedir aprobacion si existe bloqueo activo.

---

# PP02-B07 - Decision individual DGDP

## Funcionalidad PP02-F07 - Resolver funcionario/periodo

### A. Descripcion funcional

DGDP debe resolver individualmente cada funcionario y periodo incluido en la solicitud de pago.

### B. Acciones disponibles

| Accion | Uso |
| :--- | :--- |
| Aprobar funcionario/periodo | El pago cumple y puede avanzar a Finanzas. |
| Observar / devolver a correccion | Falta evidencia, existe error documental o se requiere aclaracion. |
| Rechazar funcionario/periodo | El pago no procede por causal normativa o inconsistencia grave. |

### C. Causales sugeridas

- Falta de evidencia.
- Evidencia insuficiente.
- Evidencia no corresponde al periodo.
- Licencia medica.
- Permiso sin goce.
- Proyecto o centro de costo cerrado.
- Receso sin justificacion excepcional.
- Deuda institucional no regularizada.
- Inhabilidad por cargo.
- Actividad de formacion continua.
- Exceso de tope.
- Exceso de meses/prorrateo.
- Pago duplicado.
- Error en datos de PDS o funcionario.
- Otra causal fundada.

### D. Reglas de negocio

- Toda observacion o rechazo debe tener comentario obligatorio.
- La aprobacion con alertas debe exigir comentario o confirmacion DGDP.
- El monto rechazado debe descontarse del monto que avanza a Finanzas.
- La decision debe quedar en historial por funcionario/periodo.

### E. Historia de usuario

**HU-PP02-07:** Como DGDP, quiero aprobar, observar o rechazar cada funcionario/periodo, para que solo avancen a Finanzas los pagos procedentes.

### F. Requerimientos funcionales

- **RF-PP02-022:** El sistema debe permitir resolver individualmente cada funcionario/periodo.
- **RF-PP02-023:** El sistema debe exigir causal y comentario en observacion o rechazo.
- **RF-PP02-024:** El sistema debe recalcular el monto habilitado segun decisiones individuales.
- **RF-PP02-025:** El sistema debe registrar historial por funcionario/periodo.

---

# PP02-B08 - Decision global y trazabilidad

## Funcionalidad PP02-F08 - Resolver solicitud de pago

### A. Descripcion funcional

Una vez revisados todos los funcionarios/periodos, DGDP debe resolver globalmente la solicitud de pago.

### B. Acciones globales

| Accion | Resultado |
| :--- | :--- |
| Aprobar y derivar a Finanzas | Avanzan solo los funcionarios/periodos aprobados por DGDP. |
| Devolver a correccion | La solicitud vuelve al solicitante para corregir evidencias o antecedentes. |
| Rechazar solicitud | El pago queda rechazado cuando no existe ningun item procedente o la causal afecta a todo el expediente. |

### C. Reglas de negocio

- No se puede aprobar globalmente si quedan funcionarios/periodos pendientes de decision.
- No se puede aprobar globalmente si todos los funcionarios/periodos fueron rechazados.
- Si hay observaciones corregibles, la solicitud debe devolverse, no aprobarse parcialmente, salvo que el negocio permita aprobacion parcial.
- La accion global debe registrar usuario, fecha, estado anterior, estado nuevo y comentario.

### D. Declaracion de responsabilidad DGDP

La pantalla debe incluir una declaracion visible que recuerde que DGDP certifica la revision laboral/normativa del pago y que la Universidad puede fiscalizar posteriormente la veracidad de evidencias y antecedentes.

### E. Historia de usuario

**HU-PP02-08:** Como DGDP, quiero resolver globalmente la solicitud de pago, para continuar el flujo solo con pagos revisados y trazables.

### F. Requerimientos funcionales

- **RF-PP02-026:** El sistema debe permitir aprobar y derivar a Finanzas.
- **RF-PP02-027:** El sistema debe permitir devolver a correccion.
- **RF-PP02-028:** El sistema debe permitir rechazar la solicitud.
- **RF-PP02-029:** El sistema debe bloquear la decision global si existen revisiones individuales pendientes.
- **RF-PP02-030:** El sistema debe registrar la decision global en historial.

---

# 7. Casos de uso principales

## CU-PP02-01 - Revisar solicitud de pago recibida

| Elemento | Descripcion |
| :--- | :--- |
| Actor | DGDP |
| Precondicion | Solicitud de pago en estado En revision DGDP. |
| Flujo principal | DGDP abre la solicitud, visualiza resumen, PDS de origen, resolucion firmada, funcionarios y monto solicitado. |
| Resultado | Solicitud preparada para revision individual. |

## CU-PP02-02 - Revisar funcionario/periodo

| Elemento | Descripcion |
| :--- | :--- |
| Actor | DGDP |
| Precondicion | Existe funcionario/periodo incluido en el pago. |
| Flujo principal | DGDP selecciona funcionario, revisa ficha normativa, evidencia, validaciones y decide. |
| Resultado | Funcionario/periodo queda aprobado, observado o rechazado. |

## CU-PP02-03 - Observar evidencia

| Elemento | Descripcion |
| :--- | :--- |
| Actor | DGDP |
| Precondicion | Evidencia cargada es insuficiente, erronea o no corresponde al periodo. |
| Flujo principal | DGDP marca evidencia observada, registra comentario y devuelve solicitud a correccion. |
| Resultado | Solicitud vuelve al solicitante con observacion trazable. |

## CU-PP02-04 - Rechazar pago por causal normativa

| Elemento | Descripcion |
| :--- | :--- |
| Actor | DGDP |
| Precondicion | Existe causal bloqueante no subsanable. |
| Flujo principal | DGDP selecciona causal, registra comentario y rechaza funcionario/periodo o solicitud completa. |
| Resultado | Pago rechazado con causal registrada. |

## CU-PP02-05 - Aprobar y derivar a Finanzas

| Elemento | Descripcion |
| :--- | :--- |
| Actor | DGDP |
| Precondicion | Todos los funcionarios/periodos fueron resueltos y existe al menos un pago aprobado. |
| Flujo principal | DGDP confirma aprobacion global, el sistema recalcula monto vigente y deriva a Finanzas. |
| Resultado | Solicitud queda En revision Finanzas. |

---

# 8. Datos minimos de retorno esperados desde BDD

## 8.1 Solicitud de pago

- `id_solicitud_pago`
- `estado_pago`
- `fecha_envio`
- `rut_solicitante_pago`
- `nombre_solicitante_pago`
- `id_solicitud_pds`
- `nro_resolucion`
- `ano_resolucion`
- `cod_unifin`
- `cod_ccto`
- `nombre_centro_costo`
- `periodos_solicitados`
- `monto_total_solicitado`
- `monto_aprobado_dgdp`
- `monto_rechazado_dgdp`

## 8.2 Funcionario/periodo

- `id_detalle_pago`
- `rut_funcionario`
- `nombre_funcionario`
- `estamento`
- `cargo`
- `contrato_pds`
- `actividad_especifica`
- `periodo_pago`
- `monto_periodo`
- `total_aprobado_pds`
- `total_pagado`
- `saldo_pendiente`
- `estado_revision_dgdp`
- `causal_dgdp`
- `comentario_dgdp`

## 8.3 Validaciones

- `id_validacion`
- `tipo_validacion`
- `resultado`
- `severidad`
- `descripcion`
- `fuente_dato`
- `fecha_validacion`
- `bloqueante`

## 8.4 Evidencias

- `id_evidencia_pago`
- `id_detalle_pago`
- `tipo_evidencia`
- `descripcion`
- `nombre_archivo`
- `url_archivo`
- `fecha_carga`
- `estado_revision_dgdp`
- `comentario_revision`

---

# 9. Procedimientos almacenados o servicios BDD a definir

| Necesidad | Entrada estimada | Resultado esperado |
| :--- | :--- | :--- |
| Obtener solicitud de pago para DGDP | ID solicitud pago | Cabecera, PDS origen, montos, estado y resumen. |
| Obtener funcionarios/periodos de pago | ID solicitud pago | Lista de funcionarios y periodos incluidos. |
| Obtener ficha normativa de funcionario | ID PDS, RUT, periodo | Contrato, estamento, jornada, tope, SEA, compensacion, saldos. |
| Obtener evidencias de pago | ID detalle pago | Archivos cargados, tipo, estado y vista/URL. |
| Ejecutar validaciones de pago | RUT, periodo, ID PDS, centro de costo | Licencia, permiso, cierre, receso, deuda, duplicidad, evidencia, tope. |
| Registrar decision individual DGDP | ID detalle pago, accion, causal, comentario, usuario | Estado individual y trazabilidad. |
| Resolver solicitud DGDP | ID solicitud pago, accion global, comentario, usuario | Cambio de estado, monto aprobado/rechazado e historial. |

---

# 10. Reglas generales de negocio

1. DGDP revisa pagos por funcionario/periodo, no modifica la PDS original.
2. Todo funcionario/periodo debe quedar resuelto antes de la decision global.
3. Toda evidencia observada o rechazada requiere comentario.
4. Toda causal normativa debe quedar registrada con trazabilidad.
5. Las validaciones bloqueantes impiden aprobar el funcionario/periodo.
6. El pago no puede avanzar si no existe resolucion/documento formalizado.
7. El pago no puede avanzar si no existe evidencia obligatoria.
8. El pago no puede duplicar un periodo ya pagado o en tramite.
9. Si existe aprobacion parcial, solo avanza a Finanzas el monto aprobado por DGDP.
10. Si todos los funcionarios/periodos se rechazan, la solicitud completa debe rechazarse o devolverse, segun causal.

---

# 11. Requerimientos no funcionales

| Codigo | Requerimiento | Descripcion |
| :--- | :--- | :--- |
| **RNF-PP02-001** | Trazabilidad | Toda decision DGDP debe quedar asociada a usuario, fecha, funcionario, periodo y causal. |
| **RNF-PP02-002** | Legibilidad | La vista debe permitir revisar muchos funcionarios sin perder el contexto del expediente. |
| **RNF-PP02-003** | Integridad documental | Las evidencias revisadas deben conservar version, estado y comentario. |
| **RNF-PP02-004** | Auditoria | El sistema debe conservar resultados de validaciones y decisiones para fiscalizacion posterior. |
| **RNF-PP02-005** | Seguridad | Solo perfiles DGDP autorizados pueden resolver esta etapa. |
| **RNF-PP02-006** | Consistencia | El monto que avanza a Finanzas debe derivarse de los detalles aprobados, no de digitacion manual. |

---

# 12. Pendientes por confirmar

| Punto pendiente | Por que importa |
| :--- | :--- |
| Si DGDP puede aprobar parcialmente una solicitud con algunos funcionarios rechazados. | Define si se deriva a Finanzas solo el monto aprobado o si se devuelve todo. |
| Si licencia medica/permiso sin goce rechaza automaticamente o queda para decision DGDP. | Define severidad de validaciones. |
| Si deudas institucionales aplican desde 2027 como bloqueo absoluto o alerta previa. | Define regla temporal. |
| Si receso universitario puede ser autorizado en esta misma pantalla o debe venir autorizado desde solicitud PDS. | Define acciones DGDP. |
| Si DGDP revisa disponibilidad presupuestaria o solo Finanzas. | Evita duplicar controles de Finanzas. |
| Cual sera el repositorio definitivo de evidencias y documento firmado. | Define integracion documental. |
