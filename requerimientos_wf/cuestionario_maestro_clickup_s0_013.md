# S0-013 — Cuestionario maestro de requerimientos del Workflow de Pagos

**Estado:** levantamiento funcional. Este cuestionario no autoriza desarrollo mientras existan decisiones bloqueantes sin aprobar.

## Objetivo y forma de responder

Definir completamente el flujo que transforma una PDS/resolución formalizada en una o varias solicitudes de pago trazables, revisadas por DGDP y procesadas por Finanzas/Tesorería.

Cada pregunta debe responderse en la misma descripción usando:

```text
Respuesta:
Estado: pendiente | preliminar | aprobada | descartada
Responsable que responde:
Fecha:
Fundamento normativo, evidencia o ejemplo:
Impacto en flujo, datos, BDD, PA, backend y frontend:
```

Una respuesta no queda cerrada con “sí” o “no”. Debe identificar la regla, su dueño, la fuente del dato, el momento de evaluación, el resultado, las excepciones y al menos un caso de aceptación.

## Antecedentes ya respaldados que deben ratificarse

- La PDS/resolución conserva el rango de ejecución, monto total autorizado, regla/tope, contrato, modalidad, horarios y compensaciones aprobadas. El pago no modifica esos antecedentes.
- En DU288 implementado, la resolución no crea cuotas ni define meses efectivos de pago. `mto_total` es el monto oficial; `periodos = 1` y `monto_mes = mto_total` son compatibilidad de la BDD.
- `sg_fups` representa al funcionario incluido en la PDS; `sg_fume` representa sus cuotas financieras.
- Hipótesis de diseño: una solicitud de pago pertenece a una sola PDS y contiene detalles por funcionario + cuota + cobertura/periodo. Debe confirmarse si una cabecera puede incluir varios funcionarios.
- Una cuota no debería equivaler obligatoriamente a un mes. Puede respaldar uno o varios periodos o un hito, pero el reparto mensual debe respetar el tope aplicable.
- Dividir el pago en varias cuotas dentro del mismo mes no debe permitir superar el tope mensual: se valida la suma mensual del funcionario.
- Las reglas permanentes de la resolución se consultan como antecedentes; las reglas que pueden cambiar se recalculan por solicitud/detalle de pago.
- Se reutiliza el motor configurable de flujo, tareas y auditoría de la solicitud de resolución, con etapas y acciones específicas del pago.

## Catálogo registrado actualmente en `sg_ecuo`

| Código | Estado actual de cuota | Decisión requerida |
| :---: | :--- | :--- |
| 1 | Propuesta | ¿Se utilizará en el nuevo flujo o quedará solo histórico? |
| 2 | En visación | ¿Corresponde a una etapa vigente o solo histórica? |
| 3 | Observada | ¿Quién observa, qué se edita y si libera la cuota? |
| 4 | Aprobada | ¿Aprobada por DGDP, Finanzas u otro actor? |
| 5 | Disponible pago | Confirmar que es la cuota seleccionable. |
| 6 | Solicitada pago | Confirmar que se asigna al enviar, no al guardar borrador. |
| 7 | Autorizada pago | Confirmar actor y reserva financiera asociada. |
| 8 | Enviada remuneraciones | Confirmar sistema receptor y acuse requerido. |
| 9 | Pagada | Confirmar evidencia que constituye pago efectivo. |
| 10 | Rechazada | Definir si es rechazo definitivo de cuota o solo de un intento. |
| 11 | Devuelta Finanzas | Definir destinatario, campos editables y liberación. |
| 12 | Bloqueada | Definir causal, responsable, vigencia y desbloqueo. |

No se deben usar estos estados para reemplazar el estado de cabecera ni el resultado individual de un intento. Se requieren tres niveles: solicitud, detalle/intento y cuota acumulada.

---

# A. Unidad de pago, cardinalidad y relación con la PDS

**Q-A01.** ¿El objeto que se paga es la PDS completa, una prestación/actividad, un funcionario, una cuota del funcionario o una combinación de estos?

**Q-A02.** ¿Confirmamos que cada solicitud de pago pertenece exactamente a una sola PDS/resolución?

**Q-A03.** ¿Una solicitud puede contener varios funcionarios de la misma PDS o debe crearse una solicitud por funcionario?

**Q-A04.** ¿Una solicitud puede contener varias cuotas del mismo funcionario?

**Q-A05.** ¿Una solicitud puede contener varias actividades/prestaciones de la misma PDS? ¿Cómo se identifica cada una?

**Q-A06.** ¿Una actividad de un funcionario puede originar más de una solicitud de pago hasta agotar el monto autorizado?

**Q-A07.** ¿La unidad mínima de decisión será `PDS + funcionario + actividad + cuota + cobertura`?

**Q-A08.** ¿DGDP y Finanzas aprueban/rechazan la solicitud completa o cada detalle individual?

**Q-A09.** Si un detalle se observa o rechaza, ¿los demás pueden continuar o se devuelve toda la cabecera?

**Q-A10.** ¿Puede una cabecera mezclar centros de costo, proyectos, ítems o monedas? Si no, ¿qué combinación obliga a crear otra solicitud?

**Q-A11.** ¿Cuál es el folio visible del pago y cuándo se genera: al guardar borrador o al enviar?

**Q-A12.** ¿Qué relación debe mostrarse entre número de PDS, resolución, funcionario, cuota, solicitud de pago y transacción financiera?

# B. Creación y significado de cuotas (`sg_fume`)

**Q-B01.** ¿Quién define las cuotas: solicitante/jefe de proyecto, DGDP, Finanzas o el sistema?

**Q-B02.** ¿Cuándo se crea `sg_fume`: al guardar borrador, al enviar o al aprobar DGDP?

**Q-B03.** ¿Cuál debe ser el estado inicial de una cuota nueva?

**Q-B04.** ¿Una cuota representa un monto, un mes efectivo de pago, un periodo de ejecución, un producto/hito o una combinación?

**Q-B05.** ¿Una sola cuota puede abarcar varios meses o días de ejecución? ¿Cómo se registra la cobertura?

**Q-B06.** Si una cuota cubre varios meses, ¿el monto se distribuye manualmente por mes o el sistema lo propone?

**Q-B07.** ¿La distribución propuesta puede editarse? ¿Quién puede hacerlo y hasta qué etapa?

**Q-B08.** ¿El sistema crea automáticamente la cantidad mínima de cuotas según monto y tope, o el solicitante decide la distribución?

**Q-B09.** ¿Cuál es el número máximo de cuotas por funcionario, actividad, PDS y año calendario?

**Q-B10.** ¿El número de cuota se conserva durante devoluciones y reintentos?

**Q-B11.** Ante pago parcial, ¿el saldo queda en la misma cuota o se crea una nueva?

**Q-B12.** ¿Una cuota puede tener varias transacciones/abonos? Si puede, ¿se necesita una tabla de movimientos?

**Q-B13.** ¿Qué significan definitivamente `ano_prop/mes_prop`, `ano_ejec/mes_ejec` y `ano_pago/mes_pago`?

**Q-B14.** ¿`sg_fups.tot_cuotas` será plan, total definitivo o valor derivado?

**Q-B15.** ¿Qué debe ocurrir con las cuotas históricas creadas por el mecanismo anterior?

# C. Periodos, meses, prorrateo y topes

**Q-C01.** ¿El límite general confirmado es un máximo de dos meses efectivos de pago por la misma actividad dentro del año calendario?

**Q-C02.** ¿Ese máximo se cuenta por PDS, actividad, funcionario o conjunto de pagos del funcionario?

**Q-C03.** ¿La duración de la ejecución puede ser superior a dos meses aunque el pago se distribuya en un máximo de dos meses?

**Q-C04.** ¿Una solicitud de pago puede abarcar uno o varios meses? ¿Cuál es su máximo?

**Q-C05.** ¿Una cuota puede cubrir parte de un mes, días específicos o un rango arbitrario?

**Q-C06.** Si una solicitud cubre solo parte de un mes, ¿ese mes queda bloqueado para otro pago de la misma actividad?

**Q-C07.** ¿El saldo del tope mensual puede utilizarse en otra cuota o solicitud del mismo mes?

**Q-C08.** ¿La suma de todas las cuotas/pagos/compromisos del funcionario en el mismo mes debe ser menor o igual al tope mensual disponible?

**Q-C09.** ¿Los meses efectivos de pago pueden ser posteriores al rango de ejecución? ¿Cuánto tiempo después?

**Q-C10.** ¿Se pueden mezclar meses atrasados y el mes actual en una solicitud?

**Q-C11.** ¿Se puede pagar en un año calendario distinto al de la ejecución o resolución?

**Q-C12.** ¿Cómo se calcula el monto habilitado cuando la ejecución abarca solo parte de un mes: días, horas, producto cumplido o decisión DGDP?

**Q-C13.** ¿Qué fecha determina el tope: mes de ejecución, mes solicitado, mes de autorización o mes efectivo de pago?

**Q-C14.** Si la fecha efectiva cambia de mes después de autorizar, ¿se recalcula el tope?

**Q-C15.** ¿Qué ocurre cuando el monto autorizado requiere más meses que el máximo permitido?

# D. Proyectos ANID y excepciones de distribución

**Q-D01.** ¿Cómo se identifica que el proyecto es ANID o científico-tecnológico con financiamiento externo: CC, tipo de fondo, convenio, certificado DIUFRO/DITT u otro dato?

**Q-D02.** ¿Cuál es la fuente maestra y quién certifica esta condición?

**Q-D03.** ¿La excepción ANID elimina el tope del 50 %, usa el tope de las bases del proyecto o requiere un monto máximo explícito?

**Q-D04.** ¿ANID permite más de dos meses/cuotas automáticamente o requiere solicitud excepcional?

**Q-D05.** ¿Quién solicita la extensión: jefe de proyecto, director de unidad u otro actor?

**Q-D06.** ¿Quién la aprueba: DGDP, DIUFRO/DITT, Finanzas u otra autoridad?

**Q-D07.** ¿Qué documento justifica que la entidad mandante exige rendir el gasto como asignación de prestación de servicios?

**Q-D08.** ¿La excepción debe indicar cantidad máxima de meses, cuotas, monto y vigencia?

**Q-D09.** ¿Puede modificarse una distribución excepcional después de aprobada? ¿Quién autoriza el cambio?

**Q-D10.** ¿La excepción ANID habilita a Decanos? ¿Qué otros cargos o inhabilidades modifica?

**Q-D11.** Si un centro de costo ANID no tiene certificación vigente, ¿se aplica la regla general o se bloquea?

**Q-D12.** ¿Qué debe mostrar Solicitante, DGDP y Finanzas para distinguir una excepción ANID válida, vencida o pendiente?

# E. Inicio, actores, etapas y término del flujo

**Q-E01.** ¿Qué estado exacto de PDS/resolución habilita iniciar el pago?

**Q-E02.** ¿Debe estar cumplido el periodo/hito antes de crear el borrador o solo antes de enviarlo?

**Q-E03.** ¿El solicitante del pago es el jefe de proyecto, responsable del centro de costo, titular de la PDS, delegado o sustituto?

**Q-E04.** ¿Cómo se obtiene y valida la delegación, su vigencia y su alcance?

**Q-E05.** ¿El flujo esperado es Solicitante/Jefe de Proyecto → DGDP → Finanzas → sistema financiero/Tesorería?

**Q-E06.** ¿Participa Jefatura Directa para certificar ejecución? ¿Antes de DGDP, en paralelo o fuera del sistema?

**Q-E07.** ¿Puede una misma persona solicitar, certificar y aprobar el mismo detalle?

**Q-E08.** ¿Quién reemplaza a cada actor cuando está ausente o no existe asignación vigente?

**Q-E09.** ¿Qué actor puede observar, devolver, rechazar, anular, bloquear, desbloquear y reabrir?

**Q-E10.** ¿Cuáles son los SLA de Solicitante, Jefatura, DGDP, Finanzas y Tesorería?

**Q-E11.** ¿El flujo termina cuando Finanzas autoriza, cuando envía a Remuneraciones/Tesorería, cuando recibe confirmación de pago o después de conciliación?

**Q-E12.** ¿Qué sistema es responsable del estado final pagado y cuál es la fuente maestra de la transacción?

**Q-E13.** ¿Existe una etapa de archivo documental y quién la ejecuta?

**Q-E14.** ¿Qué ocurre si el sistema financiero registra el pago pero SecGen no recibe la respuesta, o viceversa?

# F. Información y acciones del Solicitante

**Q-F01.** ¿Qué filtros necesita para localizar la PDS: resolución, solicitud, RUT, proyecto, centro de costo, actividad o periodo?

**Q-F02.** ¿Debe ver todos los funcionarios o solo los que tienen saldo/cuota habilitada?

**Q-F03.** ¿Qué datos de contrato, monto autorizado, tope, pagos previos, compromisos y saldo debe ver?

**Q-F04.** ¿Qué información sensible debe ocultarse al Solicitante?

**Q-F05.** ¿La modalidad de ejecución se hereda seleccionada automáticamente desde la PDS y puede editarse? Si cambia, ¿requiere nueva validación o modificación de la PDS?

**Q-F06.** ¿La modalidad determina automáticamente si debe mostrarse la tabla de compensación?

**Q-F07.** ¿Qué datos puede editar: monto, cobertura, mes solicitado, actividad ejecutada, evidencia y motivo?

**Q-F08.** ¿Puede ajustar el monto por ausencia o solo proponerlo para revisión DGDP?

**Q-F09.** ¿Puede guardar borrador sin detalles o evidencias?

**Q-F10.** ¿Quién puede editar, asumir o eliminar lógicamente un borrador y cuánto dura?

**Q-F11.** ¿Qué resumen debe confirmar antes de enviar?

**Q-F12.** ¿Qué mensajes deben mostrarse por cuota no seleccionable, monto excedido, documentación faltante o fuente externa caída?

# G. Evidencias y medios de verificación

**Q-G01.** ¿Qué archivo debe subir el jefe de proyecto para acreditar la actividad a pagar?

**Q-G02.** ¿El respaldo es informe, producto, acta, registro horario, certificado del mandante u otro según modalidad?

**Q-G03.** ¿Quién define y mantiene el catálogo de evidencias por tipo de actividad/prestación?

**Q-G04.** ¿La evidencia pertenece a la PDS, funcionario, actividad, cuota, cobertura o intento de pago?

**Q-G05.** ¿Un documento puede respaldar varios funcionarios/cuotas? ¿Cómo se registra esa relación?

**Q-G06.** ¿Qué evidencias son obligatorias al guardar, enviar, aprobar DGDP y registrar pago?

**Q-G07.** ¿Qué formato, tamaño, firma, vigencia y nivel de confidencialidad se exige?

**Q-G08.** ¿Quién puede cargar, visualizar, descargar, observar y reemplazar cada documento?

**Q-G09.** ¿Reemplazar conserva la versión anterior y el motivo del cambio?

**Q-G10.** ¿Cómo valida DGDP que el medio de verificación corresponde a las funciones y periodo informados?

**Q-G11.** ¿Se requiere una declaración explícita del jefe de proyecto de que la actividad fue ejecutada?

**Q-G12.** ¿Qué evidencia prueba trabajo efectivo durante receso universitario y que el proyecto asume todos los costos?

**Q-G13.** ¿Qué evidencia prueba una extensión formal del proyecto?

**Q-G14.** ¿Cuál es el periodo de retención documental?

# H. Restricciones por periodo y fuente de cada validación

Para cada regla se debe definir: fuente, campos de consulta, cobertura temporal, momento de evaluación, severidad, resultado parcial/total, contingencia, responsable, excepción, evidencia y mensaje.

## H1. Licencia médica

**Q-H01.** ¿Cuál es la fuente maestra de licencias y qué servicio/PA entrega fecha inicio, término, tipo y estado?

**Q-H02.** ¿Se compara la licencia con periodo de ejecución, cobertura de cuota, mes efectivo de pago o todos?

**Q-H03.** ¿Una superposición parcial bloquea toda la cuota o calcula proporción por días/horas efectivamente trabajados?

**Q-H04.** ¿Quién determina el monto proporcional y la evidencia requerida?

**Q-H05.** ¿Existe alguna excepción por producto cumplido o la prohibición es absoluta?

**Q-H06.** ¿Qué ocurre si SISPER no responde o la licencia está pendiente de resolución?

## H2. Permiso sin goce de sueldo

**Q-H07.** ¿Cuál es la fuente maestra y qué fechas/estado se consultan?

**Q-H08.** ¿La superposición parcial bloquea, prorratea o rechaza definitivamente?

**Q-H09.** ¿Puede existir excepción? ¿Quién la autoriza y con qué fundamento?

**Q-H10.** ¿Qué mensaje y causal se registran?

## H3. Vigencia y cierre del proyecto

**Q-H11.** ¿Cuál es la fuente oficial del inicio, término y cierre financiero del proyecto?

**Q-H12.** ¿Se valida la fecha de ejecución, la fecha de solicitud o la fecha efectiva de pago contra la vigencia?

**Q-H13.** ¿Una actividad ejecutada dentro de vigencia puede pagarse después del cierre?

**Q-H14.** ¿Cómo se registra una extensión formalmente aprobada: documento, nueva fecha, autoridad y sistema maestro?

**Q-H15.** ¿Qué ocurre si el convenio, resolución y FIN21 muestran fechas distintas?

## H4. Receso universitario

**Q-H16.** ¿Cuál es el calendario oficial de recesos y quién lo mantiene?

**Q-H17.** ¿La regla aplica por día, semana o mes completo?

**Q-H18.** ¿Quién declara y certifica que existió trabajo efectivo durante el receso?

**Q-H19.** ¿Cómo se acredita que el proyecto asume todos los costos asociados?

**Q-H20.** ¿DGDP aprueba la excepción por detalle o por solicitud completa?

## H5. Otras inhabilidades

**Q-H21.** ¿Cómo se obtiene cargo habilitado desde `sg_fupssSecgen14` y qué hacer si devuelve pendiente/sin datos?

**Q-H22.** ¿Qué cargos están inhabilitados y qué excepciones aplican, especialmente para Decanos/ANID?

**Q-H23.** ¿Cómo se consulta parentesco incompatible y cuándo una constancia solo advierte en vez de bloquear?

**Q-H24.** ¿Desde qué fecha y fuente se evaluarán deudas institucionales y fondos por rendir?

**Q-H25.** ¿Cómo se detecta que una actividad corresponde a formación continua y debe usar otro flujo?

# I. Jornada, modalidad y compensación horaria

**Q-I01.** ¿Qué regla propone automáticamente Dentro/Fuera de jornada según estamento, SEA y contrato?

**Q-I02.** Si el usuario cambia la modalidad heredada, ¿qué justificación y aprobación se exige?

**Q-I03.** ¿Cuándo debe aparecer automáticamente la tabla de compensación?

**Q-I04.** ¿Se reutiliza FUCO aprobado en la PDS o se registra ejecución efectiva en `sg_fuc2` por cuota?

**Q-I05.** ¿Qué horas se consideran para el máximo semanal de 56: contrato, honorarios, prestación y otras compensaciones?

**Q-I06.** ¿La regla máxima diaria es 12 horas totales? ¿Qué fuentes se suman y cómo se manejan cruces de medianoche?

**Q-I07.** ¿Se valida la planificación aprobada, las horas efectivamente realizadas o ambas?

**Q-I08.** ¿Qué ocurre si las horas efectivas difieren de la compensación aprobada?

**Q-I09.** ¿Quién certifica las horas realizadas y qué evidencia adjunta?

**Q-I10.** ¿Una infracción horaria bloquea la cuota completa o permite corregir cobertura/monto?

**Q-I11.** ¿Cómo se tratan días feriados, fines de semana, receso y superposición con jornada contractual?

# J. Montos, contrato, haber y tope

**Q-J01.** ¿Qué campos mínimos deben existir para permitir el pago: contrato, haber total, tope, regla, fecha de cálculo y monto total autorizado?

**Q-J02.** Si no existe contrato, `funps13` no devuelve datos o falta haber/tope, ¿se bloquea desde la búsqueda o al enviar?

**Q-J03.** ¿Qué contrato se utiliza cuando existen varios: principal, grado más alto o renta más alta?

**Q-J04.** ¿La información contractual se congela desde la resolución o se recalcula para el pago y se conserva ambas versiones?

**Q-J05.** ¿El solicitante ve solo haber total y tope, mientras DGDP/Finanzas ven los componentes remuneracionales completos?

**Q-J06.** ¿Qué componentes remuneracionales puede ver cada perfil y cuáles se consideran sensibles?

**Q-J07.** ¿El monto lo propone el sistema desde saldo/tope o lo ingresa el usuario?

**Q-J08.** ¿Se permite pago parcial? ¿Qué motivo y aprobación requiere?

**Q-J09.** ¿Se permite un monto autorizado por Finanzas menor al aprobado por DGDP? ¿Quién acepta la diferencia?

**Q-J10.** ¿La validación correcta es sobre cada cuota y además sobre la suma mensual de todos los pagos/compromisos?

**Q-J11.** ¿Cómo se calcula el saldo contractual: autorizado menos pagado menos comprometido activo?

**Q-J12.** ¿Qué ocurre si cambian haber/tope entre solicitud, aprobación y pago efectivo?

**Q-J13.** ¿Qué redondeos y tipo monetario se utilizan? Recomendación técnica: `decimal(19,2)`.

**Q-J14.** ¿Cómo se registra el tope independiente de ANID/bases del proyecto?

# K. Saldo presupuestario y frontera con Finanzas

**Q-K01.** ¿`Analisis.valida_saldo_cc_cs` es la validación oficial para el nuevo pago?

**Q-K02.** ¿Se invoca con unidad financiera/CC de `sg_prse`, ítem de `sg_fups` y suma por agrupación?

**Q-K03.** ¿El resultado es vinculante o admite sobregiro/excepción formal?

**Q-K04.** ¿Cuándo se consulta: búsqueda, borrador, envío, DGDP, autorización y pago?

**Q-K05.** ¿Cuándo se reserva o compromete realmente el saldo?

**Q-K06.** ¿El borrador reserva cuota o presupuesto? Recomendación técnica: no.

**Q-K07.** ¿Cómo se descuentan compromisos activos de SecGen aún no registrados en FIN21?

**Q-K08.** ¿Qué ocurre cuando dos solicitudes compiten por el mismo saldo?

**Q-K09.** ¿Cómo se procesan `itm_global`, `cc_global` y `pry_global`?

**Q-K10.** ¿Qué significado operativo tiene `@Afecta`, actualmente declarado pero no usado?

**Q-K11.** ¿“No tiene fondos disponibles” deja Pendiente de saldo, devuelve a corrección o rechaza definitivamente?

**Q-K12.** ¿Quién reintenta cuando aparecen fondos y se debe volver a aprobar DGDP?

**Q-K13.** ¿SecGen consulta, reserva, registra compromiso, genera la orden o solo registra el resultado informado por Finanzas?

**Q-K14.** ¿Qué datos se envían a FIN21/Remuneraciones/Tesorería y qué respuesta se espera?

# L. Pago efectivo, reintentos, reversas y concurrencia

**Q-L01.** ¿Qué determina que un pago fue efectivo: número de transacción, fecha, respuesta de integración, archivo de retorno o conciliación?

**Q-L02.** ¿Quién registra monto efectivamente pagado, transacción y fecha?

**Q-L03.** ¿Puede haber una autorización sin pago efectivo y cuánto tiempo permanece vigente?

**Q-L04.** Si no hay pago efectivo, ¿la cuota permanece en espera, se libera o se crea un nuevo intento?

**Q-L05.** Si no hay fondos, ¿se puede reintentar la misma cuota sin redigitar PDS, funcionario, cobertura y evidencia?

**Q-L06.** ¿El reintento se realiza en la misma solicitud o en una nueva solicitud/detalle?

**Q-L07.** ¿Qué validaciones se repiten obligatoriamente antes del reintento?

**Q-L08.** ¿Una cuota en borrador puede ser seleccionada por otro usuario? ¿Qué ocurre al enviar simultáneamente?

**Q-L09.** ¿En qué estado una cuota queda comprometida y deja de estar disponible?

**Q-L10.** ¿Qué estados liberan automáticamente cuota y presupuesto?

**Q-L11.** ¿Cómo se registra pago parcial y su saldo pendiente?

**Q-L12.** ¿Cómo se revierte un pago erróneo sin borrar el movimiento original?

**Q-L13.** ¿Quién autoriza la reversa y qué causal/evidencia requiere?

**Q-L14.** ¿La reversa reabre la cuota, crea una cuota nueva o exige un expediente especial?

# M. Estados y transiciones

**Q-M01.** ¿Cuáles serán los estados definitivos de la cabecera de solicitud?

**Q-M02.** ¿Cuáles serán los estados definitivos del detalle/intento?

**Q-M03.** ¿Se aprueban los 12 estados actuales de `sg_ecuo` para el nuevo flujo o algunos quedan solo históricos?

**Q-M04.** ¿Los estados 1–4 se reutilizan o el nuevo flujo comienza en 5 Disponible pago?

**Q-M05.** ¿“Aprobada” (4) y “Autorizada pago” (7) representan decisiones diferentes? ¿De quién?

**Q-M06.** ¿“Rechazada” (10) cierra definitivamente la cuota o solo el intento actual?

**Q-M07.** ¿“Devuelta Finanzas” (11) vuelve a Solicitante, Jefatura o DGDP?

**Q-M08.** ¿“Bloqueada” (12) requiere causal, responsable, fecha de vencimiento y acción de desbloqueo?

**Q-M09.** ¿“Pendiente de saldo” necesita un código propio o será estado del detalle con cuota liberada/comprometida?

**Q-M10.** ¿“Pago parcial” es estado persistido o resultado derivado de movimientos y saldo?

**Q-M11.** ¿Qué campos son editables y qué reservas existen en cada estado?

**Q-M12.** ¿Qué transiciones son automáticas, manuales, reversibles o terminales?

**Q-M13.** ¿Cuándo se archiva y quién puede reabrir?

# N. Vista y decisión esperada por actor

## Solicitante/Jefe de Proyecto

**Q-N01.** ¿Qué necesita ver para decidir qué funcionario/cuota solicitar, incluyendo autorizado, pagado, comprometido y saldo?

**Q-N02.** ¿Qué validaciones deben mostrarse antes de seleccionar y cuáles solo al enviar?

**Q-N03.** ¿Qué información contractual/remuneracional debe ocultarse o resumirse?

**Q-N04.** ¿Qué correcciones puede realizar después de una devolución?

## DGDP

**Q-N05.** ¿Qué espera revisar: PDS, contrato, cargo, modalidad, jornada, compensación, periodos, licencia, sin goce, receso, proyecto, tope, excepciones y evidencias?

**Q-N06.** ¿Necesita ver componentes remuneracionales completos, resultados de PA, fuente y fecha de cada validación?

**Q-N07.** ¿Puede modificar monto/cobertura o solo aprobar, observar, rechazar y autorizar excepción?

**Q-N08.** ¿Resuelve por detalle y permite resultados mixtos?

## Finanzas/Tesorería

**Q-N09.** ¿Qué espera revisar: imputación, CC, ítem, saldo, compromisos, monto aprobado DGDP, excepción y evidencia?

**Q-N10.** ¿Puede corregir la imputación o debe devolverla?

**Q-N11.** ¿Quién autoriza y quién registra/ejecuta el pago? ¿Existe segregación o doble firma?

**Q-N12.** ¿Qué información de conciliación y reversa necesita visualizar?

# O. Auditoría, seguridad, notificaciones y operación

**Q-O01.** ¿Qué perfiles y alcances permiten consultar, crear, editar, enviar, certificar, aprobar, pagar, revertir y administrar?

**Q-O02.** ¿Qué restricciones aplican por unidad, proyecto y centro de costo?

**Q-O03.** ¿Qué datos debe registrar `sg_hist` y qué resultados requieren historial estructurado adicional?

**Q-O04.** ¿Se conserva valor anterior/nuevo, actor, perfil, fecha, causal, comentario, fuente y evidencia?

**Q-O05.** ¿Qué eventos notifican a cada actor y por qué canal?

**Q-O06.** ¿Qué alertas se generan por SLA vencido, integración fallida, fondo disponible, excepción por vencer o documento pendiente?

**Q-O07.** ¿Qué reportes y bandejas necesita cada actor?

**Q-O08.** ¿Qué acción puede realizar soporte sin alterar una decisión funcional?

**Q-O09.** ¿Cuál es la política de retención y protección de información personal/remuneracional?

# P. Compatibilidad, migración e integraciones

**Q-P01.** ¿Se podrán pagar PDS históricas creadas fuera del nuevo workflow?

**Q-P02.** ¿Cómo se interpretarán cuotas históricas 1–4 y campos antiguos de meses?

**Q-P03.** ¿Qué PA existentes se reutilizan, adaptan o dejan de invocarse?

**Q-P04.** ¿Qué fuentes son maestras para personas/contratos, proyecto, presupuesto, documentos y pago?

**Q-P05.** ¿Qué hacer cuando los sistemas maestros entregan datos contradictorios?

**Q-P06.** ¿Qué política de timeout, reintento técnico e idempotencia requiere cada integración?

**Q-P07.** ¿Cómo se evita duplicar una orden o transacción cuando se repite una llamada?

# Q. Escenarios obligatorios para cerrar requerimientos

Para cada escenario se debe entregar un ejemplo anonimizado con datos iniciales, actor, acciones, validaciones, estados de cabecera/detalle/cuota, mensajes, integración y resultado.

1. Pago individual completo de una cuota.
2. Una PDS con varios funcionarios y varias cuotas.
3. Una actividad pagada mediante más de una solicitud.
4. Una cuota que cubre varios meses de ejecución.
5. Dos cuotas del mismo funcionario en el mismo mes sin superar el tope.
6. Parte de un mes pagada y saldo del mes utilizado después.
7. Ejecución superior a dos meses y pago distribuido en dos meses.
8. Proyecto ANID con más de dos meses/cuotas y autorización excepcional.
9. Licencia médica total y parcial.
10. Permiso sin goce total y parcial.
11. Proyecto cerrado y proyecto con extensión formal.
12. Trabajo efectivo durante receso con costos asumidos por el proyecto.
13. Compensación que supera 56 horas semanales o 12 diarias.
14. Sin contrato, sin haber o sin tope desde la fuente oficial.
15. Evidencia incompleta y posterior corrección.
16. Observación de un detalle mientras otros continúan.
17. Pago parcial.
18. Falta de saldo y posterior reintento.
19. Dos usuarios intentando enviar la misma cuota.
20. Ítem/CC/proyecto global.
21. Falla de SISPER, FIN21 o sistema documental.
22. Pago autorizado sin confirmación efectiva.
23. Varias transacciones para un detalle.
24. Pago erróneo y reversa.

## Preguntas bloqueantes que deben responderse primero

1. Q-A01 a Q-A09: unidad, cardinalidad y resolución individual.
2. Q-B01 a Q-B11: creación, significado y saldo de cuotas.
3. Q-C01 a Q-C08: meses, máximo y uso del tope.
4. Q-D01 a Q-D10: identificación y autorización ANID.
5. Q-E03, Q-E05, Q-E06 y Q-E11: actores, secuencia y término.
6. Q-G01, Q-G04 y Q-G06: evidencia mínima.
7. Q-H01 a Q-H20: fuente y tratamiento de las cuatro prohibiciones temporales.
8. Q-K05, Q-K11, Q-K13 y Q-L01: reserva, falta de saldo, frontera y pago efectivo.
9. Q-M03 a Q-M10: estados reales de cuota y estados faltantes.

## Criterio de cierre de S0-013

- Todas las preguntas bloqueantes están aprobadas por su dueño funcional.
- Las reglas distinguen antecedente heredado de validación dinámica.
- Cada validación tiene fuente, momento, severidad, excepción, contingencia y evidencia.
- Quedan definidos los tres niveles de estado y sus transiciones.
- Se conoce el alcance exacto de SecGen, DGDP, Finanzas, FIN21 y Tesorería/Remuneraciones.
- Los escenarios positivos, negativos, parciales, excepcionales, concurrentes y de reversa tienen resultado esperado.
- Cada decisión puede transformarse en requisito, cambio de BDD/PA/API/UI y caso de prueba.

