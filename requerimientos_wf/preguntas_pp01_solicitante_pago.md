# Preguntas de Levantamiento - PP01 Solicitante de Pago

Este documento contiene preguntas para cerrar las zonas grises de la **Pantalla PP01: Solicitud de Pago de Prestacion de Servicios**.

Se cruza con el modelo definido en `bdd_maestros.md`, especialmente:

- `sg_soli`: cabecera comun de solicitud.
- `sg_paso`: cabecera especifica de solicitud de pago.
- `sg_fucu`: cuotas pagables generadas desde meses aprobados.
- `sg_pade`: detalle de cuotas/personas incluidas en una solicitud de pago.
- `sg_fuev`: evidencias y constancias por funcionario.
- `sg_tevi`: tipos de evidencia/constancia.

---

## 1. Objetivo de PP01

PP01 debe permitir que un usuario autorizado busque una PDS formalizada, seleccione una o mas cuotas/personas disponibles para pago, cargue evidencias y cree una solicitud de pago para enviarla a DGDP.

Regla base del modelo:

```text
sg_soli solicitud de pago
  -> sg_paso cabecera de pago, apunta a PDS origen
      -> sg_pade detalle de cuotas/personas seleccionadas
          -> sg_fucu cuota base
              -> sg_fume mes aprobado
                  -> sg_fups funcionario PDS
```

---

## 2. Accion: Buscar PDS Disponible para Pago

### 2.1 Preguntas funcionales

| Pregunta | Por que importa | Tabla / dato afectado |
| :--- | :--- | :--- |
| Quien puede buscar PDS para pago: solicitante original, jefe de proyecto, delegado o administrativo autorizado? | Define permisos de consulta. | `sg_soli.rut_solici`, delegacion, perfiles. R: lo puede hacer tanto el jefe de proyecto como un delegado del jefe que a su vez el sistema espera buscar al responsable de ese delegado y obtendra todos sus cctos asociaddos junto a sus prestaciones.|
| La busqueda se restringe por Centro de Costo, por usuario, por unidad o por delegacion? | Define filtros principales. | `sg_prse.cod_unifin`, `sg_prse.cod_ccto`, delegacion. R: por el el resposnable del centro de cosot esto quiere dcir que aun que se delege buscara al responsable que delego. que en este caso los solicigtante son los jefes de proyectos/ccto.|
| Se deben mostrar solo PDS formalizadas o tambien PDS aprobadas sin resolucion archivada? | Define estado minimo habilitante. | `sg_soli.cod_estsol`, `sg_rslc` R: se debe mostrar pds aprobandos con o sin resolucion archivada de ese centro de costos.|
| Que estados de `sg_soli` habilitan pago? | Evita pagos sobre solicitudes incompletas. | `sg_esol`. R: solo los que tienen resoluciones externas asociadas y que estén vigentes, como tambien hayan pasado por cada una de las firmas esperadas.|
| Se puede buscar por numero de PDS, resolucion, funcionario, actividad, Centro de Costo y periodo? | Define modal de busqueda. | `sg_prse`, `sg_fups`, `sg_fume`, `sg_soli`. R:para la busqueda lo principal seria la resolyucion excenta/externa. lo de mas es un plus|
| Se debe mostrar si la PDS tiene funcionarios pendientes de pago? R:claro se debe mostrar todos los datos de duotas asociadas al esa prestacion para ese funcioanrio. si esta pagado, total, pendiente, el mes al cual esta asociado, si tiene que hacer el pago de los dos meses al momento. etc| Mejora seleccion. | `sg_fucu`, `sg_pade`. |

### 2.2 Resultado esperado

La busqueda debe devolver solo PDS que:

1. esten formalizadas;
2. tengan al menos una cuota disponible o pendiente de pago;
3. pertenezcan al ambito autorizado del usuario;
4. no correspondan a funcionarios rechazados o excluidos de la PDS (`sg_fups.cod_estfun` con valores `4` o `5`).

---

## 3. Accion: Seleccionar PDS

### 3.1 Preguntas funcionales

| Pregunta | Por que importa | Tabla / dato afectado |
| :--- | :--- | :--- |
| Al seleccionar una PDS, se cargan todos los funcionarios o solo los que tienen cuotas disponibles? | Define grilla inicial. | `sg_fups`, `sg_fume`, `sg_fucu`. se cargan todos los funcionarios asociados a esa pds.  pero solo se marcan para pago los que esten vigentes y con cuotas impagas |
| Se deben mostrar funcionarios ya pagados como historico? | Define contexto de usuario. | `sg_fucu.cod_estcuo`, `sg_pade.cod_estdet`. se debe mostrar como un tema historico, es decir con un color distint  y que no se pueda marcar para pago |
| Se deben mostrar funcionarios rechazados o excluidos de la PDS? | Evita confusion y seleccion indebida. | `sg_fups.cod_estfun`, `sg_efun`. Se deben mostrar solo como historico, con color distintivo y sin opcion de marcar para pago. |
| Se debe mostrar monto total aprobado, pagado, en tramite y saldo pendiente?R: se debe mostrar todo lo que se pueda ver en los distintos estados que tenga la cuota por funcioanrio, lo que esta en tramite o pendiente de pago debe marcarse para pago. lo pagado no se puede tocar | Define resumen financiero. | `sg_fups.mto_total`, `sg_fucu`, `sg_pade`. |
| La PDS puede tener meses distintos por funcionario y se deben mostrar separados? | Define estructura visual. | `sg_fume.nro_mes`, `sg_fume.anio`. R. la idae es ver por cada funcioarnio los meses que tiene aprobado y sus  meses pagados, ademas de si tiene algun saldo pendiente y toda la informacion posible de pagos.|

### 3.2 Datos minimos a mostrar

| Bloque | Datos |
| :--- | :--- |
| PDS | numero PDS, resolucion, actividad, periodo, Centro de Costo, jefe proyecto, modalidad. |
| Funcionario | RUT, nombre, cargo, contrato, jornada, monto mensual, total aprobado. |
| Mes/cuota | mes ejecucion, anio, nro cuota, total cuotas, monto cuota, estado cuota. |
| Pago | monto ya pagado, monto en tramite, monto disponible, ultima solicitud de pago. |
| Evidencia | tipos requeridos, evidencia cargada, constancias pendientes. |

---

## 4. Accion: Seleccionar Funcionarios y Cuotas

### 4.1 Preguntas funcionales

| Pregunta | Por que importa | Tabla / dato afectado |
| :--- | :--- | :--- |
| La solicitud de pago puede incluir uno, varios o todos los funcionarios de la PDS? R:aun se esta defininedo pero se podria dejar por mas de uno. | Confirma flexibilidad del modelo. | `sg_pade`. |
| Se permite seleccionar varias cuotas de un mismo funcionario en una misma solicitud? R:lo ideal seria no limitar por cuotas, si no que por mes y si hay saldo pendiente se pueda seleccionar sin problemas. | Define pago acumulado. | `sg_fucu`, `sg_pade`. |
| Se permite seleccionar cuotas de distintos meses en una misma solicitud? R: si, se debe poder pagar mas de un mes de una misma prestacion / por que puede pasar que no tenga saldo el item de presupuesto del ccto para ese funcioanrio asi que pasa al siguiente mes en ese caso ese siguiente mes espera el pago de 2 cuotas juntas| Define `nro_mespag` y `anio_pag`. | `sg_pade`. |
| Se permite pagar cuotas atrasadas junto con el mes actual, ?R: mientras se cumpla con las reglas definidas no deberia haber problema  | Define regla de deuda/pago retroactivo. estas se encuentran en D:\trabajo_ufro_2026\nuevo_workflow_fase_2\reglas | `sg_fucu.cod_estcuo`. |
| Que estados de cuota son seleccionables? las pendientes tambien puede haber algunas en tramite que no deberian tomar en cuenta cierto? pero si la pds esta aprobada si se deben tomar en cuenta. | Evita duplicidad. | `sg_fucu.cod_estcuo`. |
| Una cuota pendiente por falta de saldo puede volver a seleccionarse automaticamente? auntomaticamente no es necesario solo que se pueda volver a seleccinar| Define reintento. | `sg_fucu.cod_estcuo`, `sg_pade.cod_estdet`. |
| Se permite editar el monto solicitado por cuota? R:claro la idea mas quenada en la solictud de pago es definir a esa cantidad de cuiotas que ya viene de la etapa anteirior. distribuir el dinero en distintas cuotas con disstintos montos. se define en la solicitud y se permite guardar a cada cuota.| Define control de monto. | `sg_pade.mto_solpag`. |
| El sistema sugiere monto completo o proporcional por ausencia? R: aqui puede pasar que una persoan  tiene licencia pero si cumple con los obejtivos en 4 dias resptante esto quiere decir que se le paga el mes completo. pero si no cumple se le paga solo los dias que se quedo. entonces la idea es que se pueda pagar  proporcional por ausencia? R: aqui puede pasar que una persoan  tiene licencia pero si cumple con los obejtivos en 4 dias resptante esto quiere decir que se le paga el mes completo. pero si no cumple se le paga solo los dias que se quedo.  esto lo decide quien solicita el pago. por que esta ya validadno que se realizo la activida. | Define regla de calculo. | `sg_pade.mto_solpag`, ausencias externas. |

### 4.2 Regla esperada

Una solicitud de pago puede contener uno o muchos detalles `sg_pade`. Cada detalle representa una cuota concreta `sg_fucu`.

---

## 5. Accion: Crear Borrador de Pago

### 5.1 Preguntas funcionales

| Pregunta | Por que importa | Tabla / dato afectado |
| :--- | :--- | :--- |
| Cuando se crea el borrador: al seleccionar PDS o solo al guardar?R. al guardar explicitamente con una accion. | Define momento de insercion. | `sg_soli`, `sg_paso`. |
| Se permite guardar borrador sin cuotas seleccionadas?R: No es necesario tener cuotas seleccionadas para guardar borrador.  | Define minimo de borrador. | `sg_pade`. |
| Se permite guardar borrador sin evidencias?R: No es necesario tener evidencias para guardar borrador.  | Define etapa documental. | `sg_fuev`. |
| Quien queda como solicitante del pago?R: el usuario que crea el borrador. | Define responsable. | `sg_soli.rut_solici`. |
| Se debe registrar delegacion usada al crear el pago?R: lo ideal seria que todo lo que tenga que ver con delegaciones quede registrado para poder tener traza de quien hizo que. | Trazabilidad de permisos. | Posible historial o campo futuro. |
| El borrador bloquea las cuotas seleccionadas para otros usuarios?R: no deberia bloquear las cuotas seleccionadas para otros usuarios. las cuotas y meeses deberian ser independientes por funcionario. | Evita duplicidad. | `sg_fucu.cod_estcuo`. |

### 5.2 Datos minimos a guardar

| Tabla | Datos |
| :--- | :--- |
| `sg_soli` | tipo solicitud pago, rut solicitante, estado borrador, fecha. |
| `sg_paso` | `nro_solici`, `nro_solpds`, `f_creacion`, `vigente`. |
| `sg_pade` | cuotas seleccionadas, monto solicitado, mes/anio de pago solicitado, estado detalle. |

---

## 6. Accion: Cargar Evidencias y Constancias

### 6.1 Preguntas funcionales

| Pregunta | Por que importa | Tabla / dato afectado |
| :--- | :--- | :--- |
| Que tipos de evidencia son obligatorios para cada modalidad/PDS? R:La evidencia es se establecel en primera instacioa al crear la solicitud de PDS, y en etapas posterior ir pidiendo constancias firmadas para otro tipos como, que el juefe firma que esta en conocimietno qe el funcioanrio tiene inhabilidades de parentezco pero aun asi permite la solicitud en base a ese documento. | Define catalogo y validacion. | `sg_tevi`. |
| Las evidencias se definen desde la PDS o se eligen al momento del pago? R: las evidencias se definen desde la creacion de la PDS pero en etapa de pago se deben cargar constancias de que no existen inhabilidades y otros tipos que se veran y aplica para cada rol en distintas estapas. | Define origen de requerimientos. | `sg_tevi`, `sg_fuev`. |
| La evidencia se carga por funcionario, por mes o por cuota? R: por mes y por funcionario. | Define nivel de asociacion. | `sg_fuev.id_funprse`, `id_funmes`, `nro_solpag`. |
| Se permite una misma evidencia para varios meses? R: si se pagan 2 meses a cada mes se debe cargar evidencia para cada uno de los meses ya que se evidencia que se realizo sus actividades y que la cuota que se le va a pagar es acorde a lo trabajado. | Define reutilizacion. | Puede requerir duplicar referencia documental. |
| Se permite reemplazar evidencia en borrador?si | Define versionado o vigencia. | `sg_fuev.vigente`. |
| Se requiere comentario al cargar o reemplazar evidencia?no | Define trazabilidad. | Historial o campo adicional. |
| Las constancias se cargan igual que evidencias?no, las constancias se deben descargar un formato y deben estar firmadas por quien corresponda. en este caso pro ejemplo si se da que va a aprobar el dgdp se debe agregar una cosntacioa firmad e que que aprueba y valida que se pase a la etapa de finazas para generar el pago. aun que tenga una inhabilidad de parentezco. | Normaliza documentos especiales. | `sg_tevi.cod_tievi`. |
| Si falta constancia por licencia/permiso/receso, se bloquea envio?no | Define validacion de envio. | `sg_fuev`, validaciones externas. |

### 6.2 Regla esperada

Toda evidencia debe quedar asociada al funcionario de la PDS mediante `sg_fuev.id_funprse`.

Si corresponde a un mes especifico, debe usar `sg_fuev.id_funmes`.

Si se carga dentro del pago, debe informar `sg_fuev.nro_solpag`.

---

## 7. Accion: Validar Antes de Enviar a DGDP

### 7.1 Preguntas funcionales

| Pregunta | Por que importa | Tabla / dato afectado |
| :--- | :--- | :--- |
| Que validaciones bloquean envio y cuales solo alertan? R: esto ya lo tengo definido en la solitud de pds y en la reglas del sistema.| Define severidad. | Reglas de negocio. |
| PP01 valida saldo presupuestario o solo muestra advertencia? | Evita duplicar Finanzas. | PA Finanzas. |
| PP01 valida licencia, permiso, deuda y receso o solo lo hace DGDP? | Define responsabilidades. | SISPER/DGDP. |
| El sistema debe ajustar monto automaticamente por ausencia?no, el solicituante debe ajsutar monto dierectamenete. solo del pago solicitado. ademas debe quedar un registro de que se esta ajsutando monto y el motivo. | Define calculo de `mto_solpag`. | `sg_pade.mto_solpag`. |
| Si una cuota falla validacion, se excluye solo esa cuota o se bloquea toda la solicitud?R:se deberia permitir excluir a ese mes con ese funcioanio de la solicitud de pago. | Define rechazo parcial. | `sg_pade`. |
| Se permite enviar si algunos detalles tienen observaciones? se puede enviar si cumple con lo necesario. y solo hay observacioen s cyuando se "rechaza con observaciones" o cuando solo un funcioario es rechazado con observacion para regularizar.| Define aprobacion parcial posterior. | `sg_pade.cod_estdet`. |

### 7.2 Validaciones minimas sugeridas

| Validacion | Resultado esperado |
| :--- | :--- |
| PDS formalizada | Bloqueante. |
| Cuota disponible | Bloqueante. |
| No duplicidad en tramite/pagada | Bloqueante. |
| Evidencia obligatoria cargada | Bloqueante. |
| Monto solicitado dentro de saldo de cuota | Bloqueante. |
| Saldo presupuestario preliminar | Alerta o bloqueante, segun defina Finanzas. |
| Ausencias/licencias/deudas | Alerta o bloqueante, segun defina DGDP. |

---

## 8. Accion: Enviar Solicitud a DGDP

### 8.1 Preguntas funcionales

| Pregunta | Por que importa | Tabla / dato afectado |
| :--- | :--- | :--- |
| Al enviar, se bloquea la edicion de todos los detalles? | Define estados. | `sg_soli.cod_estsol`, `sg_pade.cod_estdet`. |
| Las cuotas pasan a estado solicitada? | Evita duplicidad. | `sg_fucu.cod_estcuo`. |
| Se debe insertar historial en `sg_hist`? | Trazabilidad y alertas. | `sg_hist`. |
| El historial permite saber que queda pendiente para DGDP? | Define contador por rol. | `sg_hist` o tabla futura. |
| Se notifica a rol DGDP o persona especifica? | Define asignacion. | Perfiles/usuarios. |

### 8.2 Resultado esperado

Al enviar:

1. `sg_soli` cambia a estado de revision correspondiente.
2. `sg_fucu` de las cuotas seleccionadas queda en estado solicitada/en tramite.
3. `sg_pade` queda en estado enviado a DGDP o pendiente revision.
4. Se registra accion en historial.
5. Inicia contador de dias para rol DGDP.

---

## 9. Accion: Corregir Solicitud Devuelta

### 9.1 Preguntas funcionales

| Pregunta | Por que importa | Tabla / dato afectado |
| :--- | :--- | :--- |
| DGDP puede devolver toda la solicitud o solo detalles especificos?si se devuelve al solicitante este podra mmodificar todo lo que necesite | Define correccion parcial. | `sg_pade.cod_estdet`. |
| El solicitante puede editar montos, evidencias y cuotas seleccionadas al corregir solo se podrammodificar lo que corresponde a desde el pago. no el detalle de la PDS. es decrirs monto, evidencias y cuotas | Define permisos. | `sg_pade`, `sg_fuev`. |
| Se puede quitar una cuota observada y reenviar las demas?no, solo se puede quitar el funcioanrio con su mes y cuota correspondiente | Define flexibilidad. | `sg_pade.vigente`. |
| Se puede agregar una nueva cuota en correccion? las cuotas se definen en resolucion por lo cuan solo aqui se puede asignar el monto distribuido en esas cuotas. | Define alcance del borrador corregido. | `sg_pade`, `sg_fucu`. |
| Las evidencias reemplazadas conservan historial, si se deberia conservar por auditoria? | Auditoria documental. | `sg_fuev.vigente`, historial. |

---

## 10. Accion: Cancelar o Anular Borrador

### 10.1 Preguntas funcionales

| Pregunta | Por que importa | Tabla / dato afectado |
| :--- | :--- | :--- |
| El solicitante puede eliminar un borrador?R: si ya que no se ha solicitado aprobacion de ninguna instancia. | Define ciclo de vida. | `sg_soli.cod_estsol`, `vigente`. |
| Si se anula el borrador, las cuotas vuelven a disponible?r: osea como esto se hace en resolucioin lo de crear nro ctioa como el total esto se mantiene se envie a DGDP o no, la cuota mientras no se pagen o si no esta en tramite deberian estar disponibles de seleecion | Evita bloqueo permanente. | `sg_fucu.cod_estcuo`. |
| Se eliminan detalles o se marcan no vigentes? si se elimina un borrado se avisar que son datos que no se encuentra. ademas siempre se deja no vijentes | Trazabilidad. | `sg_pade.vigente`. |
| Se eliminan evidencias o se dejan no vigentes?se deja no vigentes. | Auditoria documental. | `sg_fuev.vigente`. |

---

## 11. Preguntas Criticas para Cerrar PP01

1. PP01 puede crear una solicitud de pago para uno, varios o todos los funcionarios de una PDS? si 
2. Se pueden seleccionar varias cuotas de un mismo funcionario en una solicitud? si puede pasar que tenga cuotas atrasadas.
3. Que estados de cuota son seleccionables?los que no se han pagado (pendiente) se deberia bloquear si pretence a esta y esta en estado de tramite.
4. El borrador bloquea las cuotas seleccionadas? simplemente mantiene la seleccion.
5. Se permite guardar borrador sin evidencias?si ya que es un borrador y puede que se esta guardando info de la menera local.
6. PP01 valida saldo como bloqueo o solo advertencia?seria como advertencia hasta llegar al rol de finanzas ya que ahi es determinan te.
7. PP01 valida ausencias/licencias/deudas o eso queda para DGDP? si, DGDP es quien valida.
8. Una evidencia requerida se define desde la PDS o desde el pago? desde la PDS pero a medida que se avance en el pago como en el de pds se puede ir pidiendo y subiendo ciertas constancias que a su ves es evidencia.
9. DGDP puede devolver solo algunos detalles para correccion? si puede devolver solo algunos detalles para correccion.
10. Al enviar a DGDP, `sg_hist` registra el rol destino o solo la accion del usuario? 

---

## 12. Cambios Potenciales al Modelo Segun Respuestas

| Respuesta de negocio | Posible ajuste |
| :--- | :--- |
| Se requiere motivo de exclusion/rechazo por detalle | Evaluar catalogo de motivos para `sg_pade`. |
| Se requiere trazabilidad de asignacion por rol | Evaluar tabla satelite de tramos/asignacion. |
| Se requiere versionado documental | Evaluar version o historial de `sg_fuev`. |
| Se requiere guardar resultado de validaciones externas | Evaluar tabla de resultados de validacion. |
| Se requiere transaccion contable por detalle | Evaluar campo o tabla financiera asociada a `sg_pade`. |
