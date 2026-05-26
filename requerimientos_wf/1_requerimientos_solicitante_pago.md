# PDS Normativo D9 / DU288 / DU09

## Flujo de Pago - Pantalla PP01: Solicitante de Pago

### Requerimientos por pantalla, funcionalidad y casos de uso

---

# 1. Proposito de esta seccion

Este documento organiza la **Pantalla PP01: Solicitud de Pago de Prestacion de Servicios** del workflow de pagos PDS.

La pantalla corresponde a una etapa posterior al workflow de solicitud definido en `template-du09`. Por lo tanto, el usuario no vuelve a crear la PDS ni vuelve a ingresar los datos normativos desde cero. El objetivo es **buscar una PDS ya aprobada/formalizada, seleccionarla, cargar todos sus datos, seleccionar el pago a solicitar, adjuntar evidencias y enviar la solicitud a DGDP**.

Se toma como referencia la vista `template-du09/01_vista_formulario_solicitud.html`, especialmente:

- El buscador/modal de Centro de Costo.
- La seleccion desde modal con autollenado de datos.
- Los checks financieros del Centro de Costo.
- La visualizacion de meses, montos, SEA y compensacion horaria.
- La tabla de personal incorporado a la PDS.

---

# 2. Principio de la pantalla de pago

La pantalla debe operar con dos ideas base:

1. **Buscar y seleccionar una PDS formalizada:** el usuario busca por Centro de Costo, numero de PDS/resolucion, funcionario o texto libre, usando un modal similar al buscador de Centro de Costo de la Pantalla 01 del workflow de solicitud.
2. **Mostrar datos heredados de la PDS:** una vez seleccionada la PDS, el sistema llena automaticamente los datos de centro de costo, prestacion, funcionarios, montos, validaciones, compensacion horaria, evidencias comprometidas y resolucion firmada.

Regla base: la solicitud de pago **no modifica la PDS original**. Solo la referencia, muestra sus datos y registra el pago solicitado con sus evidencias.

---

# 3. Identificacion general de la pantalla

| Elemento | Descripcion |
| :--- | :--- |
| **Codigo de pantalla** | PP01 |
| **Nombre** | Solicitud de Pago de Prestacion de Servicios |
| **Perfil principal** | Solicitante de pago / Jefe de Unidad / Responsable de Pago |
| **Flujo asociado** | Workflow de Pago PDS Normativo D9 / DU288 / DU09 |
| **Estado inicial** | Borrador de pago |
| **Objetivo principal** | Buscar una PDS aprobada, mostrar todos sus datos, seleccionar funcionario(s)/periodo(s), adjuntar evidencia y enviar el pago a DGDP. |
| **Resultado esperado** | Solicitud de pago creada, vinculada a una PDS formalizada, con evidencias cargadas y derivada a DGDP. |

---
### 4.1 Visualización de centros de costo y prestaciones

El solicitante, típicamente el jefe de proyecto o responsable del centro de costo (ccto), podrá:

- Ver la lista de centros de costo asignados a su proyecto y las prestaciones asociadas.
- Validar que las prestaciones corresponden al presupuesto aprobado.
- Identificar prestaciones que aún no han sido pagadas, tanto del mes actual como de períodos anteriores.
- Al seleccionar una prestación, el sistema mostrará los datos asociados, incluyendo funcionarios ya pagados y los pendientes, considerando que la prestación puede abarcar todo el año mientras la actividad del individuo cubre solo dos meses.


# 4. Objetivo funcional de la Pantalla PP01

La pantalla debe permitir que el solicitante de pago:

1. Busque correctamente una PDS aprobada mediante un modal de busqueda.
2. Busque dentro del modal por Centro de Costo, PDS/resolucion, funcionario, actividad o unidad.
3. Seleccione una PDS y cargue automaticamente la informacion de la solicitud.
4. Visualice el Centro de Costo, sus datos financieros y controles de disponibilidad.
5. Visualice items presupuestarios por cargo y el monto a aprobar/pagar.
6. Visualice datos de la prestacion: actividad, unidad, jefe de proyecto, periodo, tipo de prestacion y estado.
7. Visualice datos de solicitud y prestaciones asociadas.
8. Visualice el personal asociado a la PDS usando la misma informacion registrada en el workflow anterior.
9. Visualice por funcionario contrato asociado, meses asignados, monto, jornada, SEA y compensacion horaria.
10. Visualice las validaciones asociadas al Centro de Costo y al funcionario.
11. Seleccione mes(es) o periodo(s) disponibles para pago.
12. Adjunte evidencias de ejecucion.
13. Cambie a un tab de resolucion/documento firmado para revisar el acto administrativo y sus firmas.
14. Guarde borrador o envie la solicitud de pago a DGDP.

---

# 5. Estructura funcional general

| Codigo | Bloque de pantalla | Proposito |
| :--- | :--- | :--- |
| **PP01-B01** | Busqueda modal de PDS | Buscar y seleccionar la prestacion que se desea pagar. |
| **PP01-B02** | Datos cargados de la PDS | Mostrar datos generales de solicitud, prestacion, actividad, unidad y jefe de proyecto. |
| **PP01-B03** | Centro de costo y control financiero | Mostrar CC, estado, saldo disponible, items presupuestarios por cargo y monto a aprobar. |
| **PP01-B04** | Personal asociado a la PDS | Mostrar funcionarios aprobados en el workflow anterior con sus datos completos. |
| **PP01-B05** | Detalle funcionario/prestacion | Mostrar contrato, meses, monto, jornada, SEA, compensacion y validaciones. |
| **PP01-B06** | Seleccion de pago | Seleccionar funcionario(s), mes(es) o periodo(s) disponibles y calcular monto. |
| **PP01-B07** | Evidencias de pago | Adjuntar documentos que respalden la ejecucion del periodo. |
| **PP01-B08** | Tab resolucion firmada | Visualizar resolucion/documento final y firmas del workflow anterior. |
| **PP01-B09** | Validacion y envio | Validar, guardar borrador y enviar a DGDP. |

---

# 6. Desglose funcional

---

# PP01-B01 - Busqueda modal de PDS

## Funcionalidad PP01-F01 - Buscar y seleccionar PDS a pagar

### A. Descripcion funcional

El sistema debe disponer de un campo de solo lectura y un boton **Buscar PDS**, similar al patron de busqueda de Centro de Costo de la vista `01_vista_formulario_solicitud.html`.

Al presionar el boton, se debe abrir un modal amplio que permita buscar, filtrar y seleccionar la PDS formalizada que se desea pagar.

### B. Busqueda dentro del modal

El modal debe permitir buscar por:

| Criterio | Uso esperado |
| :--- | :--- |
| Centro de Costo | Codigo, nombre o unidad financiera. |
| Prestacion de servicio | Numero de solicitud PDS, numero de resolucion, actividad o nombre del proyecto. |
| Funcionario | RUT o nombre de un funcionario asociado a la PDS. |
| Unidad | Unidad ejecutora o unidad asociada al proyecto/prestacion. |
| Estado | Solo PDS aprobadas, formalizadas, firmadas o archivadas, segun regla final. |

### C. Resultados del modal

La tabla de resultados debe mostrar:

- Numero de solicitud PDS.
- Numero/anio de resolucion.
- Centro de Costo.
- Nombre Centro de Costo.
- Unidad ejecutora.
- Jefe de proyecto.
- Actividad o nombre de la prestacion.
- Periodo aprobado.
- Cantidad de funcionarios.
- Monto total aprobado.
- Monto pendiente de pago.
- Estado PDS.
- Indicador de resolucion firmada.
- Accion **Seleccionar**.

### D. Efecto de seleccionar

Al seleccionar una PDS, el sistema debe:

- Cerrar el modal.
- Completar el campo principal con una etiqueta legible de la PDS.
- Cargar todos los datos de la PDS en la pantalla.
- Cargar Centro de Costo y datos financieros.
- Cargar personal asociado y periodos disponibles.
- Cargar resolucion/documento firmado.
- Ejecutar validaciones iniciales del pago.

### E. Reglas de negocio

- Solo se puede seleccionar una PDS formalizada y con documento firmado.
- No se deben listar PDS rechazadas, anuladas o en borrador.
- Si una PDS no tiene periodos pendientes de pago, debe mostrarse como no disponible.
- El modal no registra pago; solo selecciona el origen de la solicitud.

### F. Validaciones

| Codigo | Validacion | Efecto esperado |
| :--- | :--- | :--- |
| **VAL-PP01-BUS-01** | Sin resultados. | Informar que no se encontraron PDS disponibles para pago. |
| **VAL-PP01-BUS-02** | PDS sin resolucion/documento firmado. | Bloquear seleccion. |
| **VAL-PP01-BUS-03** | PDS sin saldo/periodos pendientes. | Mostrar como no disponible para nuevo pago. |
| **VAL-PP01-BUS-04** | Usuario sin permiso sobre la PDS. | Ocultar o bloquear seleccion. |

### G. Historia de usuario

**HU-PP01-01:** Como solicitante de pago, quiero buscar y seleccionar una PDS desde un modal, para cargar automaticamente la informacion necesaria para solicitar su pago.

### H. Requerimientos funcionales

- **RF-PP01-001:** El sistema debe mostrar un campo de PDS seleccionada y un boton de busqueda.
- **RF-PP01-002:** El sistema debe abrir un modal de busqueda de PDS.
- **RF-PP01-003:** El modal debe permitir buscar por Centro de Costo, PDS/resolucion, funcionario y unidad.
- **RF-PP01-004:** El sistema debe permitir seleccionar una PDS formalizada.
- **RF-PP01-005:** Al seleccionar la PDS, el sistema debe autollenar la informacion de la solicitud de pago.

---

# PP01-B02 - Datos cargados de la PDS

## Funcionalidad PP01-F02 - Mostrar informacion general de solicitud y prestacion

### A. Descripcion funcional

Una vez seleccionada la PDS, el sistema debe mostrar la informacion general que viene del workflow anterior.

### B. Datos que debe mostrar el sistema

- Numero de solicitud PDS.
- Numero y anio de resolucion.
- Estado de la PDS.
- Solicitante original.
- Unidad ejecutora.
- Actividad general aprobada.
- Tipo(s) de prestacion.
- Periodo general de ejecucion.
- Jefe de proyecto: RUT y nombre.
- Fecha de formalizacion.
- Monto total aprobado.
- Monto ya pagado.
- Saldo/monto pendiente.
- Estado del documento firmado.

### C. Reglas de negocio

- Todos estos campos son de solo lectura.
- La solicitud de pago debe guardar referencia a la PDS seleccionada.
- Si existen diferencias entre PDS y resolucion firmada, deben mostrarse como alerta.

### D. Historia de usuario

**HU-PP01-02:** Como solicitante de pago, quiero ver los datos generales de la PDS seleccionada, para confirmar que corresponde al pago que estoy solicitando.

### E. Requerimientos funcionales

- **RF-PP01-006:** El sistema debe cargar datos generales de la PDS seleccionada.
- **RF-PP01-007:** El sistema debe mostrar actividad, unidad, jefe de proyecto, periodo y montos.
- **RF-PP01-008:** El sistema debe mantener la informacion de PDS en modo solo lectura.

---

# PP01-B03 - Centro de costo y control financiero

## Funcionalidad PP01-F03 - Mostrar Centro de Costo, items presupuestarios y saldo disponible

### A. Descripcion funcional

El sistema debe mostrar el Centro de Costo asociado a la PDS y los controles financieros necesarios para saber si el pago puede ser solicitado.

### B. Datos que debe mostrar el sistema

- Codigo Centro de Costo.
- Unidad financiera.
- Nombre Centro de Costo.
- Tipo de financiamiento.
- Decreto afecto o clasificacion de origen.
- Unidad ejecutora.
- Proyecto global o cuenta global, si aplica.
- Jefe de proyecto.
- Saldo disponible del Centro de Costo.
- Monto a aprobar/pagar en esta solicitud.
- Monto total aprobado en la PDS.
- Monto ya pagado.
- Saldo pendiente de la PDS.

### C. Items presupuestarios por cargo

El sistema debe mostrar una tabla de items presupuestarios asociados a los cargos/funcionarios de la PDS:

| Dato | Descripcion |
| :--- | :--- |
| Cargo o tipo de cargo | Cargo/jerarquia usado para la PDS. |
| Funcionario asociado | RUT y nombre del funcionario. |
| Item presupuestario | Item asignado al cargo/prestacion. |
| Monto aprobado | Monto aprobado para el funcionario/cargo. |
| Monto solicitado a pago | Monto del periodo seleccionado. |
| Saldo disponible del item | Saldo disponible para ese cargo/item. |
| Estado presupuestario | Disponible, alerta o sin saldo. |

### D. Validaciones financieras visibles

El sistema debe mostrar los checks equivalentes a la vista de solicitud:

| Check | Resultado esperado |
| :--- | :--- |
| No es Estructural | El CC no corresponde a presupuesto estructural/base no permitido. |
| CC Habilitado | El CC esta habilitado para operar. |
| CC Vigente | El CC esta vigente para el periodo de pago. |
| Formacion Continua OK | La PDS no corresponde a formacion continua o CC de formacion continua no permitido para DU288. |
| Control Presupuestario | Existe saldo disponible para el monto a pagar. |

### E. Reglas de negocio

- El Centro de Costo no se puede editar desde el pago.
- El monto a aprobar debe calcularse desde la PDS y el periodo seleccionado.
- El saldo disponible debe mostrarse si existe PA de consulta.
- Si falta PA de saldo disponible, debe mostrarse como dato pendiente de integracion, no como aprobado.
- Finanzas realiza la validacion final presupuestaria, pero el solicitante debe ver alertas tempranas.

### F. Historia de usuario

**HU-PP01-03:** Como solicitante de pago, quiero ver el Centro de Costo, items presupuestarios y saldo disponible, para saber si el pago tiene respaldo financiero antes de enviarlo.

### G. Requerimientos funcionales

- **RF-PP01-009:** El sistema debe mostrar datos financieros del Centro de Costo.
- **RF-PP01-010:** El sistema debe mostrar saldo disponible del Centro de Costo.
- **RF-PP01-011:** El sistema debe mostrar items presupuestarios por cargo/funcionario.
- **RF-PP01-012:** El sistema debe mostrar el monto a aprobar/pagar.
- **RF-PP01-013:** El sistema debe mostrar checks de CC no estructural, habilitado, vigente, formacion continua y saldo.

---

# PP01-B04 - Personal asociado a la PDS

## Funcionalidad PP01-F04 - Mostrar personal aprobado en el workflow anterior

### A. Descripcion funcional

El sistema debe mostrar el personal asociado a la PDS usando la misma informacion registrada y aprobada en el workflow anterior de solicitud.

### B. Datos que debe mostrar el sistema

Por funcionario:

- RUT.
- Nombre completo.
- Estamento.
- Cargo/jerarquia.
- Unidad.
- Contrato asociado a la prestacion.
- Actividad especifica aprobada.
- Tipo de prestacion.
- Meses asignados a la prestacion.
- Meses pagados.
- Meses en tramite.
- Meses disponibles para pago.
- Monto mensual aprobado.
- Total aprobado.
- Total pagado.
- Saldo pendiente.
- Modalidad: dentro o fuera de jornada.
- Pertenece a SEA, si aplica.
- Compensacion horaria, si aplica.
- Estado del funcionario en la PDS: aprobado, excluido, observado, sin saldo.

### C. Reglas de negocio

- No se deben volver a ingresar funcionarios.
- No se deben editar datos de contrato, monto, meses, SEA ni compensacion desde esta pantalla.
- Solo funcionarios aprobados y con periodos disponibles pueden seleccionarse para pago.
- Funcionarios excluidos en el workflow anterior deben mostrarse solo como antecedente, no como pagables.

### D. Historia de usuario

**HU-PP01-04:** Como solicitante de pago, quiero ver el personal aprobado en la PDS, para seleccionar correctamente a quien corresponde pagar.

### E. Requerimientos funcionales

- **RF-PP01-014:** El sistema debe mostrar la nomina aprobada de funcionarios.
- **RF-PP01-015:** El sistema debe reutilizar datos registrados en el workflow anterior.
- **RF-PP01-016:** El sistema debe mostrar meses, montos, contrato, jornada, SEA y compensacion.
- **RF-PP01-017:** El sistema debe bloquear seleccion de funcionarios excluidos o sin saldo.

---

# PP01-B05 - Detalle funcionario/prestacion

## Funcionalidad PP01-F05 - Consultar ficha completa del funcionario a pagar

### A. Descripcion funcional

Al seleccionar un funcionario, el sistema debe mostrar una ficha completa de datos heredados de la PDS, equivalente a la informacion revisada en el workflow anterior.

### B. Datos que debe mostrar el sistema

- Identificacion del funcionario.
- Datos contractuales.
- Contrato que se asocia a la prestacion.
- Cargo/jerarquia.
- Estamento.
- Actividad especifica aprobada.
- Tipo de prestacion.
- Meses asignados.
- Meses disponibles para pago.
- Mes o periodo seleccionado para pago.
- Monto mensual.
- Monto solicitado en esta solicitud.
- Total aprobado.
- Total pagado.
- Saldo pendiente.
- Dentro o fuera de jornada.
- SEA: si/no/no aplica.
- Tabla de compensacion horaria cuando corresponda.
- Observaciones de etapas anteriores.

### C. Validaciones por funcionario visibles

| Validacion | Resultado esperado |
| :--- | :--- |
| Inhabilidad por cargo OK | El cargo del funcionario no impide pago, o tiene excepcion valida. |
| Deudas pendientes OK | No registra deuda no regularizada o queda alerta segun regla temporal. |
| Contrato asociado OK | Existe contrato seleccionado para la prestacion. |
| Meses asignados OK | El periodo a pagar pertenece a los meses aprobados. |
| Monto OK | El monto proviene de la PDS y no excede el autorizado. |
| Jornada/SEA OK | Se informa si esta dentro/fuera de jornada y si pertenece a SEA. |
| Compensacion OK | Si requiere compensacion, la tabla existe y fue registrada. |

### D. Reglas de negocio

- La ficha es de solo lectura, salvo seleccion del periodo a pagar y carga de evidencia.
- Las validaciones deben mostrarse como informacion para el solicitante y antecedente para DGDP.
- No debe existir una seccion independiente de elegibilidad base, porque esa revision ya fue resuelta en el workflow anterior. Solo se muestran resultados y antecedentes aplicables al pago.

### E. Historia de usuario

**HU-PP01-05:** Como solicitante de pago, quiero revisar la ficha completa del funcionario, para confirmar que el periodo y monto a pagar corresponden a lo aprobado.

### F. Requerimientos funcionales

- **RF-PP01-018:** El sistema debe mostrar ficha completa por funcionario.
- **RF-PP01-019:** El sistema debe mostrar contrato, meses, monto, jornada, SEA y compensacion.
- **RF-PP01-020:** El sistema debe mostrar validaciones por funcionario aplicables al pago.
- **RF-PP01-021:** El sistema debe evitar editar datos aprobados en la PDS.

---

# PP01-B06 - Seleccion de pago

## Funcionalidad PP01-F06 - Seleccionar mes o periodo disponible de pago

### A. Descripcion funcional

El solicitante debe seleccionar el mes o periodo a pagar para cada funcionario habilitado. Esta seleccion debe basarse en los meses aprobados en la PDS y en el historial de pagos previos.

### B. Datos de entrada

- Funcionario seleccionado.
- Mes o periodo disponible.
- Evidencia asociada posteriormente.

### C. Datos que debe mostrar el sistema

- Meses aprobados en la PDS.
- Meses ya pagados.
- Meses en tramite.
- Meses disponibles.
- Monto por mes/periodo.
- Total calculado de la solicitud.

### D. Reglas de negocio

- No se puede seleccionar un mes no aprobado en la PDS.
- No se puede seleccionar un mes ya pagado.
- No se puede seleccionar un mes que ya este en tramite.
- El monto se calcula automaticamente desde la PDS.
- La seleccion de mes/periodo es obligatoria antes de enviar.

### E. Historia de usuario

**HU-PP01-06:** Como solicitante de pago, quiero seleccionar el mes disponible que corresponde pagar, para evitar duplicidad o pagos fuera del periodo aprobado.

### F. Requerimientos funcionales

- **RF-PP01-022:** El sistema debe mostrar meses aprobados, pagados, en tramite y disponibles.
- **RF-PP01-023:** El sistema debe permitir seleccionar solo periodos disponibles.
- **RF-PP01-024:** El sistema debe calcular automaticamente el monto del pago.
- **RF-PP01-025:** El sistema debe bloquear pagos duplicados por funcionario/periodo.

---

# PP01-B07 - Evidencias de pago

## Funcionalidad PP01-F07 - Adjuntar evidencia de ejecucion

### A. Descripcion funcional

El solicitante debe adjuntar documentos que acrediten que las labores aprobadas fueron efectivamente realizadas durante el mes o periodo solicitado.

### B. Datos que debe mostrar el sistema

- Evidencias comprometidas en la PDS original.
- Evidencias requeridas para el periodo.
- Archivo cargado.
- Fecha de carga.
- Usuario que carga.
- Estado: pendiente, cargado, observado, reemplazado.
- Vista previa o descarga.

### C. Reglas de negocio

- Todo funcionario/periodo solicitado debe tener evidencia asociada.
- La evidencia debe vincularse a solicitud de pago, funcionario y periodo.
- Los archivos de evidencia no reemplazan la resolucion firmada; son respaldo de ejecucion.
- El solicitante puede reemplazar evidencias solo en borrador o devuelta a correccion.

### D. Validaciones

| Codigo | Validacion | Efecto esperado |
| :--- | :--- | :--- |
| **VAL-PP01-EVI-01** | Falta evidencia obligatoria. | Bloquea envio a DGDP. |
| **VAL-PP01-EVI-02** | Archivo no permitido. | Rechaza carga. |
| **VAL-PP01-EVI-03** | Evidencia sin funcionario/periodo. | Bloquea envio. |

### E. Requerimientos funcionales

- **RF-PP01-026:** El sistema debe permitir cargar evidencias por funcionario y periodo.
- **RF-PP01-027:** El sistema debe mostrar evidencias comprometidas en la PDS original.
- **RF-PP01-028:** El sistema debe validar evidencia obligatoria antes de enviar.

---

# PP01-B08 - Tab resolucion firmada

## Funcionalidad PP01-F08 - Visualizar resolucion/documento final del workflow anterior

### A. Descripcion funcional

La pantalla debe incluir tabs o pestanas para alternar entre:

1. **Datos de solicitud de pago:** PDS, centro de costo, funcionarios, periodos, evidencias y validaciones.
2. **Resolucion/documento firmado:** acto administrativo generado en el workflow anterior, con sus firmas/visaciones.

### B. Datos que debe mostrar el tab de resolucion

- Visor PDF o vista documental integrada.
- Numero y anio de resolucion.
- Fecha de firma/formalizacion.
- Estado documental.
- Firmas o visaciones de roles del workflow anterior:
  - Jefe de Proyecto.
  - Jefatura Directa/Jefe Departamento, si aplica.
  - DGDP.
  - Finanzas Facultad.
  - Decano.
  - Finanzas Central.
  - Decretacion.
  - Secretario General.
  - Rector.
  - Contraloria/Contralor, si aplica.
  - Archivo Universitario, si aplica.
- Anexos o documentos asociados.

### C. Reglas de negocio

- La solicitud de pago no puede enviarse si no existe documento final formalizado.
- La resolucion se visualiza como antecedente; no se edita.
- Si el documento no esta disponible, debe quedar alerta bloqueante.

### D. Historia de usuario

**HU-PP01-07:** Como solicitante de pago, quiero revisar la resolucion firmada y sus visaciones, para confirmar que la PDS ya fue formalizada antes de solicitar pago.

### E. Requerimientos funcionales

- **RF-PP01-029:** El sistema debe incluir un tab de resolucion/documento firmado.
- **RF-PP01-030:** El sistema debe mostrar firmas o visaciones del workflow anterior.
- **RF-PP01-031:** El sistema debe bloquear envio si no existe documento formalizado.

---

# PP01-B09 - Validacion y envio

## Funcionalidad PP01-F09 - Ejecutar validaciones antes de enviar a DGDP

### A. Descripcion funcional

Antes de enviar, el sistema debe validar que la PDS fue seleccionada, que existe periodo a pagar, que el monto corresponde, que hay evidencia y que no existen bloqueos evidentes.

### B. Validaciones minimas

| Codigo | Validacion | Resultado esperado |
| :--- | :--- | :--- |
| **VAL-PP01-ENV-01** | PDS seleccionada y formalizada. | Bloquea envio si falta. |
| **VAL-PP01-ENV-02** | Resolucion/documento firmado disponible. | Bloquea envio si falta. |
| **VAL-PP01-ENV-03** | Centro de Costo no estructural. | Alerta o bloqueo segun regla. |
| **VAL-PP01-ENV-04** | CC habilitado y vigente. | Alerta o bloqueo segun regla. |
| **VAL-PP01-ENV-05** | Formacion continua OK. | Bloquea si corresponde a flujo no permitido. |
| **VAL-PP01-ENV-06** | Saldo disponible suficiente. | Alerta o bloqueo segun integracion/rol de Finanzas. |
| **VAL-PP01-ENV-07** | Funcionario habilitado. | Bloquea si fue excluido o no aprobado. |
| **VAL-PP01-ENV-08** | Periodo dentro de meses aprobados. | Bloquea periodo fuera de rango. |
| **VAL-PP01-ENV-09** | Periodo no pagado ni en tramite. | Bloquea duplicidad. |
| **VAL-PP01-ENV-10** | Monto coincide con PDS aprobada. | Bloquea si fue alterado o no corresponde. |
| **VAL-PP01-ENV-11** | Evidencia obligatoria cargada. | Bloquea envio si falta respaldo. |
| **VAL-PP01-ENV-12** | Compensacion horaria existente cuando aplica. | Alerta o bloqueo segun regla final. |

### C. Guardar borrador

El sistema debe permitir guardar la solicitud como borrador:

- PDS seleccionada.
- Funcionarios/periodos seleccionados.
- Evidencias cargadas parcialmente.
- Validaciones ejecutadas hasta el momento.

### D. Enviar a DGDP

Al enviar:

- Cambia a estado **En revision DGDP**.
- Bloquea edicion para el solicitante.
- Registra historial.
- Deja disponible la solicitud en bandeja DGDP.

### E. Requerimientos funcionales

- **RF-PP01-032:** El sistema debe guardar borrador de pago.
- **RF-PP01-033:** El sistema debe validar datos antes de enviar.
- **RF-PP01-034:** El sistema debe enviar la solicitud a DGDP.
- **RF-PP01-035:** El sistema debe registrar historial de envio.

---

# 7. Casos de uso principales

## CU-PP01-01 - Buscar y seleccionar PDS para pago

| Elemento | Descripcion |
| :--- | :--- |
| Actor | Solicitante de pago |
| Precondicion | Existen PDS formalizadas y con resolucion/documento firmado. |
| Flujo principal | El usuario abre el modal, filtra por CC/PDS/funcionario/unidad, selecciona la PDS y el sistema carga sus antecedentes. |
| Resultado | PDS seleccionada con datos visibles en pantalla. |
| Alternativas | Sin resultados, PDS sin documento, PDS sin periodos pendientes, usuario sin permiso. |

## CU-PP01-02 - Revisar datos cargados de la PDS

| Elemento | Descripcion |
| :--- | :--- |
| Actor | Solicitante de pago |
| Precondicion | PDS seleccionada. |
| Flujo principal | El sistema muestra datos de solicitud, prestacion, centro de costo, items presupuestarios, funcionarios, periodos, validaciones y resolucion. |
| Resultado | Usuario confirma que corresponde solicitar pago sobre esa PDS. |

## CU-PP01-03 - Seleccionar funcionario y mes a pagar

| Elemento | Descripcion |
| :--- | :--- |
| Actor | Solicitante de pago |
| Precondicion | PDS tiene funcionarios y meses disponibles. |
| Flujo principal | El usuario selecciona funcionario(s), mes(es) disponibles y el sistema calcula el monto a pagar. |
| Resultado | Pago armado con funcionario, periodo y monto calculado. |
| Alternativas | Mes ya pagado, mes en tramite, funcionario excluido, falta saldo. |

## CU-PP01-04 - Revisar resolucion firmada

| Elemento | Descripcion |
| :--- | :--- |
| Actor | Solicitante de pago |
| Precondicion | PDS seleccionada. |
| Flujo principal | El usuario cambia al tab de resolucion, revisa el documento y sus firmas/visaciones. |
| Resultado | Resolucion visualizada como antecedente formal. |

## CU-PP01-05 - Cargar evidencia y enviar a DGDP

| Elemento | Descripcion |
| :--- | :--- |
| Actor | Solicitante de pago |
| Precondicion | Funcionario/periodo seleccionado. |
| Flujo principal | El usuario carga evidencia, el sistema valida completitud y envia a DGDP. |
| Resultado | Solicitud queda En revision DGDP. |
| Alternativas | Evidencia faltante, archivo invalido, validacion bloqueante. |

---

# 8. Estados minimos esperados para la solicitud de pago

| Codigo sugerido | Estado | Descripcion |
| :--- | :--- | :--- |
| 1 | Borrador | Solicitud creada pero no enviada. |
| 2 | En revision DGDP | Solicitud enviada a DGDP para validar procedencia del pago. |
| 3 | Devuelta a correccion | DGDP u otra etapa devuelve al solicitante. |
| 4 | Rechazada | Solicitud no procede por causal normativa, documental o financiera. |
| 5 | En revision Finanzas | Solicitud aprobada por DGDP y enviada a revision presupuestaria. |
| 6 | Aprobada para pago | Solicitud aprobada administrativamente para ejecutar pago. |
| 7 | Pagada | Pago ejecutado/cerrado. |
| 8 | Archivada | Expediente cerrado documentalmente. |

---

# 9. Datos minimos de retorno esperados desde BDD

## 9.1 Busqueda de PDS para pago

- `id_solicitud_pds`
- `nro_resolucion`
- `ano_resolucion`
- `estado_pds`
- `actividad`
- `unidad_ejecutora`
- `cod_unifin`
- `cod_ccto`
- `nombre_centro_costo`
- `tipo_financiamiento`
- `rut_jefe_proyecto`
- `nombre_jefe_proyecto`
- `periodo_desde`
- `periodo_hasta`
- `monto_total_pds`
- `total_pagado`
- `saldo_pendiente`
- `cantidad_funcionarios`
- `tiene_documento_firmado`
- `tiene_periodos_pendientes`

## 9.2 Centro de costo y presupuesto

- `cod_unifin`
- `cod_ccto`
- `nombre_centro_costo`
- `unidad_ejecutora`
- `tipo_financiamiento`
- `decreto_afecto`
- `saldo_disponible_ccto`
- `monto_a_aprobar`
- `no_es_estructural`
- `cc_habilitado`
- `cc_vigente`
- `formacion_continua_ok`
- `control_presupuestario_ok`
- `items_presupuestarios_por_cargo`

## 9.3 Funcionario/prestacion

- `rut_funcionario`
- `nombre_funcionario`
- `estamento`
- `cargo`
- `unidad`
- `contrato_pds`
- `actividad_especifica`
- `tipo_prestacion`
- `modalidad_jornada`
- `sea`
- `compensacion_horaria`
- `meses_asignados`
- `meses_pagados`
- `meses_en_tramite`
- `meses_disponibles`
- `monto_mensual`
- `total_aprobado`
- `total_pagado`
- `saldo_pendiente`
- `inhabilidad_cargo_ok`
- `deudas_pendientes_ok`
- `contrato_asociado_ok`
- `monto_ok`

## 9.4 Resolucion/documento

- `id_documento`
- `nro_resolucion`
- `ano_resolucion`
- `fecha_firma`
- `url_documento`
- `estado_documento`
- `firmas_visaciones`

## 9.5 Evidencias

- `id_evidencia_origen`
- `tipo_evidencia`
- `descripcion_evidencia`
- `periodo_asociado`
- `obligatoria`
- `archivo_cargado`
- `estado_evidencia`

---

# 10. Procedimientos almacenados o servicios BDD a definir

| Necesidad | Entrada estimada | Resultado esperado |
| :--- | :--- | :--- |
| Buscar PDS disponibles para pago | Texto, CC, numero PDS/resolucion, RUT funcionario, unidad | Lista de PDS formalizadas con disponibilidad de pago. |
| Obtener detalle completo de PDS para pago | ID PDS o resolucion | Datos de solicitud, prestacion, centro de costo, funcionarios, periodos, evidencias y documento. |
| Obtener saldo disponible del Centro de Costo | ID/Codigo CC, fecha o periodo | Saldo disponible y estado de disponibilidad. |
| Obtener items presupuestarios por cargo | ID PDS, CC, funcionario/cargo | Items, montos aprobados, monto a pagar y saldo por item. |
| Obtener periodos pagables por funcionario | ID PDS, RUT funcionario | Meses aprobados, pagados, en tramite y disponibles. |
| Validar duplicidad de pago | ID PDS, RUT funcionario, periodo | Indicador de si el periodo ya fue pagado o esta en tramite. |
| Obtener resolucion firmada | ID PDS o resolucion | Documento y firmas/visaciones del workflow anterior. |
| Registrar borrador de pago | ID PDS, usuario, funcionarios/periodos | ID solicitud de pago en borrador. |
| Registrar evidencia de pago | ID solicitud pago, RUT, periodo, archivo | Evidencia vinculada al pago. |
| Enviar pago a DGDP | ID solicitud pago | Cambio de estado e insercion en bandeja DGDP. |

---

# 11. Reglas generales de negocio

1. El flujo de pago solo puede iniciarse desde una PDS formalizada.
2. La PDS original no debe modificarse desde esta pantalla.
3. La busqueda y seleccion de PDS debe funcionar mediante modal con filtros internos.
4. Al seleccionar la PDS, el sistema debe autollenar toda la informacion necesaria.
5. Cada pago debe vincular PDS, funcionario, periodo, monto y evidencia.
6. No se puede duplicar un pago para el mismo funcionario y periodo.
7. El monto de pago se calcula desde la PDS aprobada; no se digita libremente.
8. Las evidencias son obligatorias antes de enviar a DGDP.
9. La resolucion firmada del workflow anterior debe estar disponible en tab separado.
10. El solicitante solo puede editar en Borrador o Devuelta a correccion.
11. Toda accion relevante debe quedar registrada en historial.

---

# 12. Requerimientos no funcionales

| Codigo | Requerimiento | Descripcion |
| :--- | :--- | :--- |
| **RNF-PP01-001** | Usabilidad | La busqueda debe permitir encontrar una PDS sin conocer el numero exacto. |
| **RNF-PP01-002** | Trazabilidad | Toda solicitud de pago debe conservar referencia a la PDS original. |
| **RNF-PP01-003** | Integridad documental | Evidencias y resolucion firmada deben quedar vinculadas al expediente de pago. |
| **RNF-PP01-004** | Consistencia | Montos, meses, contrato, SEA y compensacion deben venir desde la PDS aprobada. |
| **RNF-PP01-005** | Seguridad | Solo usuarios autorizados deben buscar y solicitar pagos sobre PDS de su ambito. |
| **RNF-PP01-006** | Auditoria | El sistema debe registrar busqueda, seleccion, guardado, envio y reemplazo de evidencias. |

---

# 13. Alcances pendientes por confirmar

| Punto pendiente | Por que importa |
| :--- | :--- |
| Quienes pueden buscar y solicitar pago: solicitante original, jefe de proyecto o administrativo autorizado. | Define permisos del modal y alcance de resultados. |
| Si una solicitud de pago puede incluir varios funcionarios. | Define modelo de cabecera/detalle. |
| Si una solicitud de pago puede incluir varios meses por funcionario. | Define reglas de duplicidad y seleccion. |
| Cual PA entregara saldo disponible del CC por fecha/periodo. | Define control presupuestario inicial. |
| Cual PA entregara items presupuestarios por cargo/funcionario. | Define tabla financiera por cargo. |
| Donde queda almacenada la resolucion/documento firmado final. | Define integracion del tab documental. |
