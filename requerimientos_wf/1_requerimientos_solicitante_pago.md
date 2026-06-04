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

## 2.1 Relación con Solicitud PDS Formalizada

- El pago nace desde una PDS formalizada y con resolución/documento firmado.
- `sg_prse` y `sg_fups` son la fuente de datos aprobados.
- `sg_fume` contiene los meses aprobados por funcionario.
- `sg_fucu` contiene las cuotas generadas desde esos meses aprobados.
- `sg_paso` crea la solicitud formal de pago asociada a la PDS.
- `sg_pade` registra qué cuotas se solicitan pagar.
- `sg_fuev` registra las evidencias/constancias por funcionario/mes/pago.
- El pago no modifica la PDS, funcionarios, meses ni topes aprobados.
- Un rechazo de pago no debe usar `sg_fups.ind_retfun`.

### Matriz de Validaciones de Pago

| Regla | Resuelta en PDS | Revalidar en Pago |
| :--- | :--- | :--- |
| Cargo inhabilitado | Sí | Solo mostrar antecedente |
| Asignación directiva | Sí | Solo mostrar antecedente |
| Formación continua | Sí | Solo mostrar antecedente |
| Tope mensual | Sí | Revalidar si cambia monto solicitado |
| Máximo 2 meses | Sí | Validar cuota generada coherente |
| SEA | Sí | Mostrar antecedente |
| Compensación | Sí | Mostrar y exigir si falta respaldo |
| Licencia médica | Puede haber sido evaluada | Sí, por mes ejecutado |
| Permiso sin goce | Puede haber sido evaluado | Sí, por mes ejecutado |
| Receso | No siempre | Sí, requiere constancia |
| Deudas 2027 | Puede haber sido evaluada | Sí, si fecha aplica |
| Ausencias | No estática | Sí, ajuste proporcional |
| Saldo CC | Informativo/aprobado PDS | Sí, final en Finanzas |
| Evidencia | Planificada | Carga real obligatoria |

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

# 3. Rol y responsabilidad del actor

| Elemento | Descripción |
| :--- | :--- |
| **Actor principal** | Solicitante de pago / Jefe de Unidad / Responsable de Proyecto |
| **Contexto** | Usuario que originó la PDS y que ahora solicita el pago de las labores ya ejecutadas. |
| **Puede hacer** | Buscar PDS, seleccionar cuotas disponibles, ingresar monto (total o parcial), cargar evidencias, guardar borrador, enviar a DGDP y corregir si el expediente es devuelto. |
| **No puede hacer** | Modificar la PDS aprobada, editar datos normativos del funcionario, establecer fecha efectiva de pago (eso corresponde a Finanzas). |

---

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
| Control Presupuestario | Muestra saldo disponible para el monto a pagar, como antecedente informativo para el solicitante. |

### E. Reglas de negocio

- El Centro de Costo no se puede editar desde el pago.
- El monto a aprobar debe calcularse desde la PDS y el periodo seleccionado.
- El saldo disponible debe mostrarse si existe PA de consulta.
- Si falta PA de saldo disponible, debe mostrarse como dato pendiente de integracion, no como aprobado.
- Finanzas realiza la validacion final presupuestaria. En PP01, la falta de saldo del Centro de Costo no bloquea el envio; solo debe mostrarse como alerta o antecedente informativo.

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
| Inhabilidad por cargo aprobada en PDS | Mostrar el resultado validado en el workflow de solicitud PDS; no se recalcula en PP01 salvo cambio normativo o alerta posterior. |
| Deudas pendientes | Revalidar solo si la regla se encuentra vigente al momento del pago o si existe PA/servicio actualizado para el periodo. |
| Contrato asociado OK | Existe contrato seleccionado para la prestacion. |
| Meses asignados OK | El periodo a pagar pertenece a los meses aprobados. |
| Monto OK | El monto solicitado se compara contra monto bruto aprobado, cuotas pagadas/en tramite y saldo pendiente. |
| Jornada/SEA OK | Se informa si esta dentro/fuera de jornada y si pertenece a SEA. |
| Compensacion OK | Si requiere compensacion, la tabla existe y fue registrada. |
| Tope mensual aprobado en PDS | Mostrar el resultado de tope validado en la solicitud PDS/DGDP; PP01 no recalcula topes si el monto solicitado no supera lo aprobado. |
| Ausencias del periodo OK | Revalidar para el mes de ejecucion a pagar, ya que puede afectar el monto proporcional efectivamente pagable. |

### D. Reglas de negocio

- La ficha es de solo lectura, salvo seleccion del periodo a pagar y carga de evidencia.
- Las validaciones deben mostrarse como informacion para el solicitante y antecedente para DGDP.
- No debe existir una seccion independiente de elegibilidad base, porque esa revision ya fue resuelta en el workflow anterior. Solo se muestran resultados y antecedentes aplicables al pago.
- Las validaciones normativas resueltas en la solicitud PDS se muestran como antecedentes heredados. PP01 solo revalida condiciones dinamicas o propias del pago: cuota disponible, duplicidad, saldo pendiente, evidencia cargada, mes de pago solicitado, licencias/permisos/receso/deudas vigentes cuando apliquen al periodo de ejecucion.

### E. Historia de usuario

**HU-PP01-05:** Como solicitante de pago, quiero revisar la ficha completa del funcionario, para confirmar que el periodo y monto a pagar corresponden a lo aprobado.

### F. Requerimientos funcionales

- **RF-PP01-018:** El sistema debe mostrar ficha completa por funcionario.
- **RF-PP01-019:** El sistema debe mostrar contrato, meses, monto, jornada, SEA y compensacion.
- **RF-PP01-020:** El sistema debe mostrar validaciones por funcionario aplicables al pago.
- **RF-PP01-021:** El sistema debe evitar editar datos aprobados en la PDS.

---

# PP01-B06 - Seleccion de cuotas de pago

## Funcionalidad PP01-F06 - Seleccionar cuotas generadas desde los meses aprobados

### A. Descripcion funcional

El solicitante debe seleccionar la o las cuotas disponibles de pago para cada funcionario habilitado. Estas cuotas no se crean libremente en la pantalla de pago: se generan previamente en el cierre del workflow de solicitud PDS, una vez que la PDS queda completamente firmada y formalizada con resolucion/documento final.

La cantidad de cuotas corresponde automaticamente a los meses de trabajo asignados al funcionario en la PDS. Por ejemplo, si a un funcionario se le asignaron dos meses de ejecucion, el sistema debe registrar dos cuotas asociadas a esos meses: cuota 1/2 y cuota 2/2. En la solicitud de pago se seleccionan las cuotas disponibles y se completan los datos de pago que correspondan.

La solicitud de pago gestiona pagos por labores ya ejecutadas y correctamente respaldadas. Por lo tanto, cada cuota debe quedar asociada al mes de ejecucion validado, al mes al que corresponde solicitar el pago, al funcionario y al monto bruto que se solicita pagar. La fecha efectiva o programada de pago se define en la etapa de Finanzas.

### B. Datos de entrada

- Funcionario seleccionado.
- Mes de ejecucion/cuota disponible.
- Mes al que corresponde solicitar el pago.
- Numero de cuota y total de cuotas registrado previamente.
- Evidencia asociada posteriormente.

### C. Datos que debe mostrar el sistema

- Meses aprobados en la PDS.
- Meses ya pagados.
- Meses en tramite.
- Cuotas generadas para cada funcionario.
- Numero de cuota, por ejemplo 1/2 o 2/2.
- Mes de ejecucion asociado a cada cuota.
- Mes de pago solicitado.
- Cuotas disponibles para pago.
- Monto bruto aprobado/referencial de la PDS.
- Monto ya pagado.
- Saldo pendiente por funcionario.
- Total calculado de la solicitud.

### D. Reglas de negocio de selección de cuotas

> [!IMPORTANT]
> **Regla de monto parcial:** El monto solicitado por cuota (`mto_solpag`) puede ser igual al monto base de la cuota o menor a él. Si `mto_solpag < mto_cuota`, se considera pago parcial de la cuota y el solicitante debe registrar el motivo de ajuste. El saldo restante de la cuota puede solicitarse posteriormente en una nueva solicitud de pago.

- No se puede seleccionar un mes no aprobado en la PDS.
- No se puede seleccionar una cuota ya pagada o en tramite activo en otra solicitud.
- La cantidad de cuotas se determina automaticamente desde los meses asignados al funcionario en la PDS formalizada.
- La tabla de cuotas debe quedar registrada previamente al inicio del pago, al finalizar el workflow PDS y quedar firmada la resolucion final.
- La solicitud de pago no puede crear cuotas adicionales ni eliminar cuotas generadas desde la PDS.
- La cantidad maxima de cuotas por una misma actividad en el ano calendario es de 2, salvo excepcion formalmente autorizada.
- La seleccion de cuota es obligatoria antes de enviar.
- La suma de los montos pagados y solicitados por funcionario no puede superar el monto bruto aprobado para ese funcionario en la PDS.
- Una solicitud de pago puede incluir uno o varios funcionarios y una o mas cuotas disponibles de la misma PDS.

### D.1 Separación de reglas: selección vs. monto

| Ámbito | Regla |
| :--- | :--- |
| **Selección de cuota** | Solo cuotas en estado DISPONIBLE pueden seleccionarse. |
| **Monto de la cuota** | `mto_solpag` puede ser total (`= mto_cuota`) o parcial (`< mto_cuota`). |
| **Pago parcial** | Si `mto_solpag < mto_cuota`, es obligatorio registrar motivo de ajuste en `sg_pade.motivo_ajuste`. |
| **Restricción de exceso** | `mto_solpag > mto_cuota` está bloqueado siempre. |
| **Mes de pago** | `nro_mespag` / `anio_pag` registran el mes de cobro; no son el mes de ejecución. PP01 no define la fecha efectiva de pago: esa responsabilidad corresponde a Finanzas. |

### E. Historia de usuario

**HU-PP01-06:** Como solicitante de pago, quiero seleccionar las cuotas disponibles por funcionario y mes de ejecucion, para solicitar pagos solo sobre labores aprobadas, ejecutadas y no pagadas previamente.

### F. Requerimientos funcionales

- **RF-PP01-022:** El sistema debe mostrar meses aprobados, cuotas generadas, cuotas pagadas, cuotas en tramite y cuotas disponibles.
- **RF-PP01-023:** El sistema debe permitir seleccionar solo cuotas disponibles.
- **RF-PP01-024:** El sistema debe mostrar el monto bruto aprobado, total pagado, total solicitado y saldo pendiente por funcionario.
- **RF-PP01-025:** El sistema debe bloquear pagos duplicados por PDS, funcionario, mes de ejecucion y numero de cuota.
- **RF-PP01-026:** El sistema debe validar que la suma de cuotas no supere el monto bruto aprobado del funcionario.
- **RF-PP01-027:** El sistema debe permitir armar una solicitud de pago con varios funcionarios y cuotas distintas de una misma PDS.

---

# PP01-B06b - Asignacion de monto bruto y mes de pago por cuota

## Funcionalidad PP01-F06b - Completar monto bruto y mes de pago solicitado por cuota

### A. Descripcion funcional

Una vez que el solicitante ha seleccionado las cuotas disponibles, el sistema debe mostrar una tabla donde, por cada cuota, funcionario y mes de ejecucion, se ingrese el **monto bruto a pagar** y el **mes al que corresponde solicitar el pago**.

La PDS formalizada define los meses de ejecucion y el monto bruto aprobado para el funcionario. Al formalizarse la resolucion final, el sistema debe generar y registrar las cuotas segun esos meses. En PP01, el solicitante completa la distribucion real del pago sobre esas cuotas.

Ejemplo: si un funcionario tiene dos meses/cuotas y un monto bruto aprobado de $1.000.000, el solicitante podria registrar cuota 1/2 por $400.000 y cuota 2/2 por $600.000, cada una asociada al mes de ejecucion y al mes de pago solicitado, siempre que la suma no exceda el monto aprobado.

La fecha efectiva o programada en que se ejecutara el pago no se define en PP01; debe ser asignada por la etapa de Direccion de Finanzas.

### B. Datos de entrada

| Campo | Descripcion |
| :--- | :--- |
| Funcionario | RUT y nombre del funcionario asociado a la PDS. |
| Mes de ejecucion | Mes de trabajo aprobado y validado desde la PDS. |
| Numero de cuota | Numero correlativo y total de cuotas, por ejemplo 1/2. |
| Monto bruto aprobado PDS | Solo lectura. Monto bruto aprobado para el funcionario en la resolucion/PDS. |
| Total pagado previo | Solo lectura. Suma de cuotas pagadas previamente al funcionario. |
| Saldo pendiente | Solo lectura. Diferencia entre monto aprobado y pagos registrados/en tramite. |
| Monto cuota a pagar | Editable. Monto bruto que se solicita pagar en esta cuota. |
| Mes de pago solicitado | Mes al cual se solicita imputar o gestionar el pago de la cuota. |
| Responsable/usuario solicitante | Usuario que registra la solicitud de pago o responsable delegado, segun corresponda. |

### C. Reglas de negocio

- El monto de una cuota no puede superar el saldo pendiente del funcionario.
- La suma de todas las cuotas pagadas, en tramite y solicitadas no puede superar el monto bruto aprobado del funcionario en la PDS.
- El monto mensual solicitado debe respetar el tope normativo aplicable al estamento del funcionario, salvo proyectos con excepcion ANID u otra excepcion formal registrada.
- Si existen ausencias durante el mes de ejecucion, el solicitante puede ajustar manualmente el monto (`mto_solpag`) a pagar de forma proporcional, ingresando el motivo justificante.
- Si hay licencias o ausencias pero el objetivo técnico o producto comprometido se cumplió de forma efectiva e íntegra (por ejemplo, mediante teletrabajo documentado o compensación autorizada), el solicitante puede requerir el pago completo de la cuota cargando la constancia explicativa correspondiente.
- El mes de pago solicitado debe quedar registrado en la cuota para diferenciar el mes trabajado del mes en que se gestiona el cobro.
- La fecha efectiva/programada de pago debe ser registrada posteriormente por Direccion de Finanzas.
- Si el mes de pago solicitado es posterior al mes de ejecución, el sistema debe mostrarlo como pago posterior al periodo trabajado, sin bloquear por si mismo.
- El monto total de la solicitud se calcula sumando todos los montos ingresados en la tabla y se muestra en el panel inferior fijo.
- El monto de cuota y el mes de pago solicitado son obligatorios antes de enviar la solicitud a DGDP.
- El sistema debe conservar el avance de cuotas por funcionario, identificando cuota actual, total de cuotas, cuotas pagadas, cuotas en tramite y cuotas pendientes.

### D. Validaciones

| Codigo | Validacion | Efecto esperado |
| :--- | :--- | :--- |
| **VAL-PP01-MDP-01** | `mto_solpag` supera el saldo pendiente del funcionario. | Bloquear envio. |
| **VAL-PP01-MDP-02** | Mes de pago solicitado (`nro_mespag`) no ingresado. | Bloquear envio a DGDP. |
| **VAL-PP01-MDP-03** | Mes de pago solicitado posterior al mes de ejecucion. | Advertencia informativa; registrar trazabilidad. No bloquear. |
| **VAL-PP01-MDP-04** | `mto_solpag` igual a 0. | Advertencia de monto vacío. Bloquear envio. |
| **VAL-PP01-MDP-05** | Cuota ya pagada o en tramite activo. | Bloquear seleccion y envio. |
| **VAL-PP01-MDP-06** | Suma de cuotas solicitadas + pagadas supera el monto bruto aprobado. | Bloquear envio. |
| **VAL-PP01-MDP-07** | `mto_solpag` supera tope normativo del estamento. | Bloquear envio, salvo excepcion ANID/formal registrada. |
| **VAL-PP01-MDP-08** | Ausencias en el mes de ejecucion sin ajuste proporcional ni constancia. | Alerta informativa; no bloquea si se adjunta constancia/justificacion. |
| **VAL-PP01-MDP-09** | `mto_solpag > mto_cuota` (monto supera la base de la cuota). | Bloquear envío siempre. |
| **VAL-PP01-MDP-10** | `mto_solpag < mto_cuota` (pago parcial de cuota) sin motivo de ajuste. | Bloquear envío hasta ingresar `motivo_ajuste`. |
| **VAL-PP01-MDP-11** | Constancias especiales (licencia, permiso, receso) presentes. | Advertencia visible y derivación para resolución normativa de DGDP; no bloquea PP01 si se adjunta constancia. |

### E. Historia de usuario

**HU-PP01-06b:** Como solicitante de pago, quiero ingresar el monto bruto (pudiendo ser parcial o total) y el mes de pago solicitado de cada cuota disponible, para dejar registrada la distribucion real del pago antes de enviar la solicitud a DGDP.

### F. Requerimientos funcionales

- **RF-PP01-028b:** El sistema debe mostrar cuotas por funcionario con estado (DISPONIBLE, EN_TRAMITE, PAGADA, PENDIENTE_SALDO) y montos base.
- **RF-PP01-029b:** El sistema debe permitir ingresar `mto_solpag` por cuota seleccionada. El monto puede ser total (`= mto_cuota`) o parcial (`< mto_cuota`).
- **RF-PP01-030b:** Si `mto_solpag < mto_cuota`, el sistema debe exigir el campo `motivo_ajuste` antes de enviar.
- **RF-PP01-031b:** El sistema debe permitir ingresar `nro_mespag` y `anio_pag` (mes de cobro solicitado) por cuota. PP01 **no** permite fijar la fecha efectiva de pago; esa responsabilidad es de Finanzas.
- **RF-PP01-032b:** Si `nro_mespag > mes_ejecucion` o `anio_pag > anio_ejecucion`, el sistema debe mostrar etiqueta "Pago posterior al periodo trabajado" sin bloquear.
- **RF-PP01-033b:** El sistema debe calcular el total de la solicitud como suma de todos los `mto_solpag` ingresados.
- **RF-PP01-034b:** El sistema debe bloquear envío si falta monto o mes de pago solicitado en alguna cuota seleccionada.
- **RF-PP01-035b:** El sistema debe mostrar avance de cuotas por funcionario: cuotas pagadas, en tramite, disponibles y pendientes.
- **RF-PP01-036b:** El sistema debe registrar el responsable/usuario solicitante y el responsable delegado cuando aplique.
- **RF-PP01-037b:** Las constancias especiales (licencia, permiso, receso) no bloquean el envío en PP01; solo generan advertencia visible y quedan como antecedente para resolución normativa de DGDP.

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
- La evidencia debe vincularse a solicitud de pago, funcionario y mes de ejecucion.
- La evidencia debe ser individual por funcionario y por mes de ejecucion justificado.
- Los archivos de evidencia no reemplazan la resolucion firmada; son respaldo de ejecucion.
- El solicitante puede reemplazar evidencias solo en borrador o devuelta a correccion.
- Si el mes de ejecucion presenta licencia medica, permiso, receso u otra condicion especial, el solicitante debe adjuntar una constancia adicional donde declara que conoce dicha condicion y que las labores fueron efectivamente cumplidas en los dias habilitados o bajo la excepcion correspondiente.
- La constancia no elimina la revision posterior de DGDP; queda como antecedente para validar procedencia del pago.

### D. Validaciones

| Codigo | Validacion | Efecto esperado |
| :--- | :--- | :--- |
| **VAL-PP01-EVI-01** | Falta evidencia obligatoria. | Bloquea envio a DGDP. |
| **VAL-PP01-EVI-02** | Archivo no permitido. | Rechaza carga. |
| **VAL-PP01-EVI-03** | Evidencia sin funcionario/periodo. | Bloquea envio. |
| **VAL-PP01-EVI-04** | Condicion especial sin constancia del solicitante. | Bloquea envio hasta adjuntar constancia. |

### E. Requerimientos funcionales

- **RF-PP01-028:** El sistema debe permitir cargar evidencias por funcionario y mes de ejecucion.
- **RF-PP01-029:** El sistema debe mostrar evidencias comprometidas en la PDS original.
- **RF-PP01-030:** El sistema debe validar evidencia obligatoria antes de enviar.

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

- **RF-PP01-031:** El sistema debe incluir un tab de resolucion/documento firmado.
- **RF-PP01-032:** El sistema debe mostrar firmas o visaciones del workflow anterior.
- **RF-PP01-033:** El sistema debe bloquear envio si no existe documento formalizado.

---

# PP01-B09 - Validacion y envio

## Funcionalidad PP01-F09 - Ejecutar validaciones antes de enviar a DGDP

### A. Descripcion funcional

Antes de enviar, el sistema debe validar que la PDS fue seleccionada, que existe periodo a pagar, que el monto corresponde, que hay evidencia y que no existen bloqueos evidentes.

Las validaciones de PP01 se dividen en dos grupos:

- **Antecedentes heredados desde la solicitud PDS:** condiciones ya revisadas y aprobadas en el workflow anterior, como flujo D9, centro de costo seleccionado, formacion continua, inhabilidad por cargo, maximo de meses, tope normativo, SEA, compensacion horaria, monto bruto aprobado y resolucion/documento firmado.
- **Validaciones propias del pago:** condiciones que deben evaluarse en la solicitud de pago porque dependen del mes/cuota, del mes de pago solicitado, de condiciones vigentes o del estado acumulado de pagos, como cuota disponible, duplicidad, saldo pendiente, evidencia efectiva, licencia/permisos/receso/deudas vigentes y vigencia del proyecto al periodo de ejecucion.

### B. Validaciones minimas

| Codigo | Validacion | Resultado esperado |
| :--- | :--- | :--- |
| **VAL-PP01-ENV-01** | PDS seleccionada y formalizada. | Bloquea envio si falta. |
| **VAL-PP01-ENV-02** | Resolucion/documento firmado disponible. | Bloquea envio si falta. |
| **VAL-PP01-ENV-03** | Centro de Costo no estructural aprobado en PDS. | Mostrar como antecedente heredado; no recalcular en PP01 salvo integracion definida. |
| **VAL-PP01-ENV-04** | CC habilitado/vigente en PDS y vigencia al periodo de pago. | Mostrar antecedente PDS y alertar/bloquear si el CC o proyecto no está vigente para el mes de ejecucion. |
| **VAL-PP01-ENV-05** | Formacion continua descartada en PDS. | Mostrar como antecedente heredado; bloquear solo si el expediente no trae validacion aprobada. |
| **VAL-PP01-ENV-06** | Saldo disponible al momento de solicitud. | Mostrar como alerta temprana no bloqueante; la decision presupuestaria final corresponde a Finanzas. |
| **VAL-PP01-ENV-07** | Funcionario habilitado. | Bloquea si fue excluido o no aprobado. |
| **VAL-PP01-ENV-08** | Cuota/mes dentro de meses aprobados. | Bloquea cuota fuera de los meses aprobados en PDS. |
| **VAL-PP01-ENV-09** | Cuota no pagada ni en tramite. | Bloquea duplicidad por PDS, funcionario, mes y numero de cuota. |
| **VAL-PP01-ENV-10** | Monto dentro del saldo aprobado. | Bloquea si supera monto bruto aprobado, saldo pendiente o monto de cuota permitido. |
| **VAL-PP01-ENV-11** | Evidencia obligatoria cargada. | Bloquea envio si falta respaldo. |
| **VAL-PP01-ENV-12** | Compensacion horaria aprobada cuando aplica. | Mostrar como antecedente heredado desde PDS/DGDP; bloquear si falta en el expediente aprobado. |
| **VAL-PP01-ENV-13** | Maximo dos cuotas/meses por actividad aprobado en PDS. | Mostrar como antecedente heredado; bloquear si la PDS no trae cuotas generadas coherentes con la resolucion. |
| **VAL-PP01-ENV-14** | Tope mensual por estamento o excepcion ANID aprobado en PDS. | Mostrar como antecedente heredado; revalidar solo si el monto solicitado excede lo aprobado o cambia la regla final. |
| **VAL-PP01-ENV-15** | Licencia medica o permiso sin goce en periodo solicitado. | No bloquea automaticamente si existe evidencia y constancia del solicitante que justifica labores efectivamente cumplidas en dias habilitados; queda alerta para DGDP. |
| **VAL-PP01-ENV-16** | Receso universitario. | Bloquea solo si no existe constancia/evidencia de trabajo efectivo y costo asumido por el proyecto. |
| **VAL-PP01-ENV-17** | Deudas no regularizadas desde 01-01-2027. | Bloquea pago desde la vigencia de la regla. |
| **VAL-PP01-ENV-18** | Periodo dentro de vigencia del proyecto. | Bloquea pagos posteriores al cierre del proyecto. |
| **VAL-PP01-ENV-19** | Ausencias del periodo con ajuste proporcional o constancia. | Bloquea si corresponde ajuste/constancia y no fue aplicada o adjuntada. |

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

- **RF-PP01-034:** El sistema debe guardar borrador de pago.
- **RF-PP01-035:** El sistema debe validar datos antes de enviar.
- **RF-PP01-036:** El sistema debe enviar la solicitud a DGDP.
- **RF-PP01-037:** El sistema debe registrar historial de envio.

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
- `cuotas_generadas`
- `cuotas_pagadas`
- `cuotas_en_tramite`
- `cuotas_disponibles`
- `monto_bruto_aprobado`
- `total_aprobado`
- `total_pagado`
- `saldo_pendiente`
- `inhabilidad_cargo_ok`
- `deudas_pendientes_ok`
- `contrato_asociado_ok`
- `monto_ok`
- `tope_mensual_aplicable_aprobado_pds`
- `tope_mensual_ok_aprobado_pds`
- `excepcion_anid_ok_aprobada_pds`
- `licencia_medica_periodo`
- `permiso_sin_goce_periodo`
- `receso_universitario_periodo`
- `trabajo_efectivo_receso_ok`
- `ausencias_periodo`
- `requiere_ajuste_proporcional`
- `monto_ajustado_proporcional`
- `vigencia_proyecto_ok`

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
- `mes_ejecucion_asociado`
- `anio_ejecucion_asociado`
- `obligatoria`
- `archivo_cargado`
- `estado_evidencia`

## 9.6 Cuotas de pago

- `id_cuota_pago`
- `id_solicitud_pds`
- `rut_funcionario`
- `mes_ejecucion`
- `anio_ejecucion`
- `numero_cuota`
- `total_cuotas`
- `monto_bruto_aprobado_funcionario`
- `monto_pagado_previo`
- `monto_en_tramite`
- `saldo_pendiente_funcionario`
- `monto_cuota_solicitado`
- `mes_pago_solicitado`
- `anio_pago_solicitado`
- `fecha_pago_programada_finanzas`
- `estado_cuota`
- `ind_pago_posterior_mes_ejecucion`
- `ind_ajuste_ausencias`
- `monto_tope_mensual_aprobado_pds`
- `monto_base_calculo_tope_aprobado_pds`
- `ind_excepcion_tope_aprobada_pds`
- `rut_usuario_solicitante`
- `rut_responsable_delegado`
- `rut_responsable_origen`
## 9.7 Constancias por condiciones especiales

- `id_constancia_pago`
- `id_solicitud_pago`
- `rut_funcionario`
- `mes_ejecucion`
- `anio_ejecucion`
- `tipo_condicion`
- `descripcion_constancia`
- `id_doc_constancia`
- `rut_usuario_declara`
- `fecha_hora_declara`

---

# 10. Procedimientos almacenados o servicios BDD a definir

| Necesidad | Entrada estimada | Resultado esperado |
| :--- | :--- | :--- |
| Buscar PDS disponibles para pago | Texto, CC, numero PDS/resolucion, RUT funcionario, unidad | Lista de PDS formalizadas con disponibilidad de pago. |
| Obtener detalle completo de PDS para pago | ID PDS o resolucion | Datos de solicitud, prestacion, centro de costo, funcionarios, periodos, evidencias y documento. |
| Generar cuotas desde PDS formalizada | ID PDS o resolucion firmada | Cuotas por funcionario y mes de ejecucion, numeradas segun meses asignados. |
| Obtener saldo disponible del Centro de Costo | ID/Codigo CC, fecha o periodo | Saldo disponible y estado de disponibilidad. |
| Obtener items presupuestarios por cargo | ID PDS, CC, funcionario/cargo | Items, montos aprobados, monto a pagar y saldo por item. |
| Obtener cuotas pagables por funcionario | ID PDS, RUT funcionario | Cuotas aprobadas, pagadas, en tramite y disponibles, con mes de ejecucion asociado. |
| Validar duplicidad de pago | ID PDS, RUT funcionario, mes ejecucion, numero cuota | Indicador de si la cuota ya fue pagada o esta en tramite. |
| Validar saldo de cuotas por funcionario | ID PDS, RUT funcionario, monto solicitado | Indicador de si la suma pagada/en tramite/solicitada supera el monto bruto aprobado. |
| Validar restricciones dinamicas de pago | ID PDS, RUT funcionario, mes/anio ejecucion | Licencia medica, permiso sin goce, receso, deudas vigentes desde 01-01-2027 y vigencia del proyecto. |
| Obtener validaciones aprobadas de la PDS | ID PDS o resolucion | Resultados heredados de solicitud: topes, excepcion ANID, inhabilidad por cargo, formacion continua, SEA, compensacion, meses aprobados y monto bruto aprobado. |
| Validar monto contra aprobado PDS | ID PDS, RUT funcionario, cuota, monto solicitado | Resultado de cumplimiento respecto a monto bruto aprobado, cuotas pagadas/en tramite y saldo pendiente. |
| Obtener ausencias del periodo | RUT funcionario, mes/anio ejecucion | Dias de ausencia y monto ajustado proporcional sugerido. |
| Obtener resolucion firmada | ID PDS o resolucion | Documento y firmas/visaciones del workflow anterior. |
| Registrar borrador de pago | ID PDS, usuario, funcionarios/cuotas, montos y mes de pago solicitado | ID solicitud de pago en borrador. |
| Registrar evidencia de pago | ID solicitud pago, RUT, mes/anio de ejecucion, archivo | Evidencia vinculada al pago. |
| Registrar constancia por condicion especial | ID solicitud pago, RUT, mes/anio ejecucion, tipo condicion, archivo/texto | Constancia vinculada al funcionario y mes de ejecucion. |
| Enviar pago a DGDP | ID solicitud pago | Cambio de estado e insercion en bandeja DGDP. |

---

# 11. Reglas generales de negocio

1. El flujo de pago solo puede iniciarse desde una PDS formalizada.
2. La PDS original no debe modificarse desde esta pantalla.
3. La busqueda y seleccion de PDS debe funcionar mediante modal con filtros internos.
4. Al seleccionar la PDS, el sistema debe autollenar toda la informacion necesaria.
5. Cada pago debe vincular PDS, funcionario, mes de ejecucion, mes de pago solicitado, cuota, monto y evidencia.
6. No se puede duplicar un pago para la misma PDS, funcionario, mes de ejecucion y cuota.
7. La cantidad de cuotas se genera automaticamente desde los meses asignados al funcionario en la PDS formalizada.
8. El monto de cada cuota se registra en la solicitud de pago y su suma no puede exceder el monto bruto aprobado para el funcionario.
9. La fecha efectiva/programada de pago debe ser registrada por Direccion de Finanzas; PP01 solo registra el mes de pago solicitado.
10. Los topes mensuales, excepciones ANID/formales, inhabilidades por cargo, SEA, compensacion horaria y descarte de formacion continua se heredan desde la PDS aprobada y deben mostrarse como antecedentes del expediente.
11. PP01 debe validar el monto solicitado contra el monto bruto aprobado, cuotas pagadas/en tramite y saldo pendiente del funcionario.
12. Si el funcionario registra ausencias durante el mes de ejecucion, el pago debe ajustarse proporcionalmente al tiempo efectivamente trabajado.
13. No procede pago durante licencia medica, permiso sin goce de sueldo, fuera de vigencia del proyecto o receso universitario sin justificacion de trabajo efectivo.
14. Desde el 01-01-2027, no procede pago a funcionarios con deudas no regularizadas con la Universidad.
15. Las evidencias son obligatorias antes de enviar a DGDP y se asocian al funcionario y mes de ejecucion.
16. La resolucion firmada del workflow anterior debe estar disponible en tab separado.
17. El solicitante solo puede editar en Borrador o Devuelta a correccion.
18. Toda accion relevante debe quedar registrada en historial.

---

# 12. Especificaciones de Modelo Normalizado para PP01

## 12.1 Creacion de solicitud de pago

PP01 debe crear una solicitud de pago vinculada a una PDS formalizada, pero no debe obligar a que la solicitud incluya a todos los funcionarios de la PDS.

| Elemento | Regla |
| :--- | :--- |
| Cabecera comun | Crear o actualizar registro en `sg_soli` con tipo solicitud de pago. |
| Cabecera de pago | Crear `sg_paso` con el mismo `nro_solici` de `sg_soli`. |
| PDS origen | Guardar `sg_paso.nro_solpds` apuntando a la PDS formalizada. |
| Seleccion de pago | Registrar en `sg_pade` solo las cuotas/personas seleccionadas. |
| Cuota seleccionable | Debe venir desde `sg_fucu`, generada a partir de `sg_fume`. |

La solicitud de pago se crea a nivel de PDS, pero su ejecucion se controla por detalle de funcionario/cuota. Por lo tanto, `sg_paso` identifica el expediente de pago y `sg_pade` identifica exactamente que cuotas se estan solicitando pagar.

Reglas de creacion:

1. Al guardar el primer borrador se debe crear la cabecera comun en `sg_soli`.
2. En el mismo proceso se debe crear `sg_paso` usando el mismo `nro_solici`.
3. `sg_paso.nro_solpds` debe apuntar a la PDS formalizada seleccionada.
4. Las cuotas seleccionadas deben registrarse en `sg_pade`.
5. Las cuotas no seleccionadas no cambian de estado y pueden solicitarse despues.

## 12.2 Seleccion flexible de funcionarios/cuotas

La pantalla debe permitir:

1. Solicitar pago para todos los funcionarios disponibles de una PDS.
2. Solicitar pago para un solo funcionario.
3. Solicitar pago para un grupo de funcionarios.
4. Solicitar una o mas cuotas disponibles por funcionario.
5. Dejar fuera del pago actual a funcionarios que no se desean pagar en esa solicitud.

Regla: un funcionario no incluido en una solicitud de pago no queda rechazado; simplemente queda pendiente para una nueva solicitud.

La grilla de seleccion debe trabajar sobre cuotas disponibles de `sg_fucu`, no directamente sobre `sg_fups`. Esto permite que un mismo funcionario tenga varios meses/cuotas y que solo algunas se incluyan en la solicitud actual.

Estados esperados para seleccion:

| Estado funcional de cuota | Comportamiento en PP01 |
| :--- | :--- |
| Disponible | Se puede seleccionar. |
| Pendiente por falta de saldo | Se puede seleccionar si negocio permite reintento. |
| Solicitada / en tramite | No se puede seleccionar nuevamente. |
| Pagada | No se puede seleccionar. |
| Rechazada definitiva / cerrada | No se puede seleccionar salvo accion administrativa. |

La pantalla debe mostrar, por funcionario, las cuotas pagadas, en tramite, disponibles y pendientes, para que el solicitante entienda que esta incluyendo y que queda fuera.

## 12.3 Validaciones de disponibilidad y duplicidad

Antes de enviar a DGDP, PP01 debe validar:

| Validacion | Regla |
| :--- | :--- |
| PDS formalizada | Solo se puede solicitar pago sobre PDS aprobada/formalizada. |
| Funcionario vigente | No se deben mostrar funcionarios retirados de PDS (`ind_retfun = 'S'`). |
| Cuota no pagada | No se puede seleccionar una cuota pagada. |
| Cuota no duplicada | No se puede seleccionar una cuota en tramite activo. |
| Monto solicitado | `sg_pade.mto_solpag` no debe superar el saldo disponible de la cuota. |
| Evidencia obligatoria | Debe existir evidencia/constancia requerida antes de enviar a DGDP. |

Validaciones adicionales esperadas:

| Validacion | Efecto esperado |
| :--- | :--- |
| Usuario autorizado sobre Centro de Costo o delegacion | Bloquea busqueda/seleccion si no corresponde. |
| Resolucion/PDS formalizada | Bloquea solicitud de pago si la PDS no esta habilitada. |
| Funcionario retirado de PDS | No debe aparecer como seleccionable. |
| Monto solicitado mayor que cuota | Bloquea envio. |
| Cuota en otra solicitud activa | Bloquea seleccion para evitar duplicidad. |
| Evidencia faltante | Bloquea envio a DGDP. |
| Restricciones externas preliminares | Muestra alerta o bloqueo segun regla DGDP/Finanzas. |

## 12.4 Evidencias y constancias

Las evidencias cargadas en PP01 deben guardarse por funcionario y, cuando aplique, por mes de ejecucion.

| Tabla | Regla |
| :--- | :--- |
| `sg_fuev.id_funprse` | Obligatorio; toda evidencia pertenece a un funcionario de la PDS. |
| `sg_fuev.id_funmes` | Obligatorio si la evidencia corresponde a un mes especifico. |
| `sg_fuev.nro_solpag` | Se informa cuando la evidencia se carga o usa en una solicitud de pago. |
| `sg_fuev.cod_tievi` | Distingue evidencia de ejecucion, constancia por licencia, permiso, receso u otra situacion. |

Reglas documentales:

1. PP01 debe mostrar los tipos de evidencia esperados desde la PDS o desde el catalogo `sg_tevi`.
2. El documento fisico cargado debe guardarse como referencia en `sg_fuev.id_docum`.
3. El usuario que carga debe quedar en `sg_fuev.rut_carga`.
4. La fecha y hora de carga debe quedar en `sg_fuev.f_carga`.
5. Si una evidencia se reemplaza antes de enviar, la version anterior debe quedar no vigente o trazada por historial, segun definicion documental.
6. No se debe crear estado propio de evidencia en esta etapa; la revision se resuelve por detalle de pago o solicitud.

## 12.5 Reintento sin redigitar

Si una cuota no se incluye o no puede enviarse en una solicitud de pago:

1. La informacion de la PDS no se modifica.
2. La cuota queda disponible o pendiente segun su estado en `sg_fucu.cod_estcuo`.
3. Una nueva solicitud de pago puede incluir esa cuota cuando corresponda.
4. No se debe volver a digitar la informacion base del funcionario ni de la prestacion.

Casos de reintento:

| Caso | Regla |
| :--- | :--- |
| Cuota no seleccionada | Permanece disponible para otra solicitud. |
| Borrador anulado | Las cuotas seleccionadas deben volver a estar disponibles. |
| Devuelta a correccion | El solicitante puede corregir evidencia/monto/detalle segun observacion. |
| Rechazada por falta de saldo | Puede reintentarse cuando exista disponibilidad, si la cuota no queda cerrada definitivamente. |
| Pagada | No puede reintentarse. |

## 12.6 Alerta de bandeja para solicitante

PP01 debe mostrar las solicitudes devueltas o pendientes para el solicitante usando contador por etapa:

| Caso | Regla |
| :--- | :--- |
| Solicitud devuelta a correccion | El contador inicia desde la fecha en que quedo asignada al solicitante. |
| Mas de 3 dias sin accion | Marcar en rojo en la bandeja del solicitante. |
| Solicitante corrige y reenvia | Se cierra el tramo del solicitante y se abre el siguiente tramo de revision. |

La alerta debe calcularse dinamicamente desde el historial de la solicitud o desde una tabla de tramo/asignacion si `sg_hist` no permite identificar claramente el rol destino.

---

## 12.7 Acciones esperadas de la vista PP01

| Accion | Comportamiento esperado | Tablas impactadas |
| :--- | :--- | :--- |
| Buscar PDS | Busca PDS formalizadas por Centro de Costo, resolucion, funcionario, actividad o periodo, restringidas al ambito autorizado del usuario. | `sg_prse`, `sg_soli`, `sg_fups`, `sg_fume`, `sg_fucu` |
| Seleccionar PDS | Carga datos de PDS, funcionarios, meses, cuotas, montos, resolucion y evidencias esperadas. | Consulta sobre PDS y cuotas |
| Seleccionar cuotas | Permite elegir una o muchas cuotas disponibles de uno o varios funcionarios. | `sg_fucu`, `sg_pade` |
| Guardar borrador | Crea/actualiza `sg_soli`, `sg_paso` y detalles `sg_pade` sin enviar a DGDP. | `sg_soli`, `sg_paso`, `sg_pade` |
| Cargar evidencia | Guarda evidencia por funcionario/mes/solicitud de pago. | `sg_fuev`, `sg_tevi` |
| Validar envio | Ejecuta controles de PDS formalizada, duplicidad, monto, evidencia y permisos. | Consultas/PA |
| Enviar a DGDP | Cambia estado de solicitud, marca detalles/cuotas en tramite y registra historial. | `sg_soli`, `sg_fucu`, `sg_pade`, `sg_hist` |
| Corregir devuelta | Permite ajustar detalles, montos o evidencias observadas. | `sg_pade`, `sg_fuev`, `sg_hist` |
| Anular borrador | Deja sin efecto la solicitud y libera cuotas no enviadas/pagadas. | `sg_soli`, `sg_paso`, `sg_pade`, `sg_fucu` |

---

# 13. Requerimientos no funcionales

| Codigo | Requerimiento | Descripcion |
| :--- | :--- | :--- |
| **RNF-PP01-001** | Usabilidad | La busqueda debe permitir encontrar una PDS sin conocer el numero exacto. |
| **RNF-PP01-002** | Trazabilidad | Toda solicitud de pago debe conservar referencia a la PDS original. |
| **RNF-PP01-003** | Integridad documental | Evidencias y resolucion firmada deben quedar vinculadas al expediente de pago. |
| **RNF-PP01-004** | Consistencia | Meses, cuotas generadas, contrato, SEA, compensacion y monto bruto aprobado deben venir desde la PDS formalizada; los montos de cuota y fechas de pago se registran en la solicitud de pago. |
| **RNF-PP01-005** | Seguridad | Solo usuarios autorizados deben buscar y solicitar pagos sobre PDS de su ambito. |
| **RNF-PP01-006** | Auditoria | El sistema debe registrar busqueda, seleccion, guardado, envio y reemplazo de evidencias. |

---

# 14. Alcances pendientes por confirmar

| Punto pendiente | Por qué importa |
| :--- | :--- |
| Quiénes pueden buscar y solicitar pago: solicitante original, jefe de proyecto o administrativo autorizado. | Define permisos del modal y alcance de resultados. |
| Cuál PA entregará saldo disponible del CC por fecha/periodo. | Define control presupuestario inicial. |
| Cuál PA entregará ítems presupuestarios por cargo/funcionario. | Define tabla financiera por cargo. |
| Dónde queda almacenada la resolución/documento firmado final. | Define integración del tab documental. |

> [!NOTE]
> **Decisiones ya tomadas (no son pendientes):**
> - Se permite pago parcial de cuota (`mto_solpag < mto_cuota`) con motivo de ajuste obligatorio.
> - Las constancias especiales no bloquean el envío en PP01; son advertencias para DGDP.
> - PP01 no define fecha efectiva de pago; solo registra `nro_mespag` / `anio_pag`.
> - Un rechazo de pago no usa `sg_fups.ind_retfun`.
> - Los estados válidos de cuota son: `DISPONIBLE`, `EN_TRAMITE`, `PAGADA`, `PENDIENTE_SALDO`, `RECHAZADA`.
