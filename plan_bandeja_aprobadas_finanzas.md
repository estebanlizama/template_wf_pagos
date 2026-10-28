# Plan propuesto: bandeja de cuotas aprobadas para Finanzas

**Fecha:** 27-10-2026  
**Estado:** incorpora los acuerdos funcionales del 27-10-2026, la revisión contra el código y las dos decisiones de arquitectura de esa fecha (§B y §C). **Las fases 1 a 3 quedan listas para implementar**; la del Excel sigue bloqueada por las tres columnas sin fuente y por el mes de proceso del ejemplo.

## Objetivo

Agregar una vista de solo lectura para las cuotas de prestaciones aprobadas por
DGDP que se prepararán para enviar a Finanzas. Desde la bandeja se podrán
buscar cuotas, abrir su resumen sin acciones de edición/decisión y descargar un
Excel con las filas que correspondan a los filtros activos.

## Comportamiento ya implementado

- El módulo `service-provision-payments` ya contiene la revisión DGDP.
- El permiso `provision-payment-read-waiting` protege la bandeja y sus vistas de
  consulta, separado de `provision-payment-approve`, que es el que exigen las
  siete operaciones de escritura. **No es derivado**: es asignado, de la tabla
  de permisos. El único permiso derivado del módulo es
  `provision-payment-manage`, que se concede en `/auth/user` a quien es
  responsable vigente de un centro de costo DU288.
- **Los PA exigen además pertenecer a la unidad DGDP.** Las 13 PA de pagos
  llevan `orde.cod_organi = 696` con contrato vigente, 26 veces en total. El
  permiso por sí solo no abre nada: sin esa pertenencia el PA responde
  «El usuario no tiene asignacion vigente para revisar cuotas DGDP.» y el
  repositorio lo convierte en 403.
- `sg_epag.cod_estcuo = 4` representa una cuota aprobada. El PA
  `sg_epagsSecgen03` acepta un estado concreto como filtro y devuelve datos de
  funcionario, RUT, centro de costo, resolución, período de pago, montos y
  cantidad de meses.
- La bandeja de revisión actual ya tiene filtros de persona, RUT, centro,
  resolución, número, período de pago y alertas. Esos filtros se aplican en el
  cliente después de cargar la lista.
- La ruta de detalle DGDP ya permite consultar cuotas aprobadas, y **ya es de
  solo lectura para ellas**: `RESOLVABLE_STATUS = [2]`, así que con estado 4
  `canResolve` es falso, los botones de decisión no se renderizan y la sección
  de meses se monta con `editable=false`, que es su valor por omisión.
- Las dos PA de meses (`sg_fumesSecgen03`, `sg_epagsSecgen04`) aceptan
  `cod_estcuo in (2, 3, 4, 8, 10, 11)`: una cuota aprobada carga sus meses
  completos, no vuelve vacía.
- La bandeja DGDP ya ofrece el estado 4 en su selector de estado, y sus columnas
  ya son las que el plan dibuja: funcionario, cuota, centro de costo,
  resolución, actividad, mes a pagar, meses cubiertos, solicitado, con
  descuentos, estado y acción.
- El frontend ya incluye `xlsx`; no hace falta agregar otra dependencia para
  generar el archivo.

## Acuerdos confirmados por el usuario (27-10-2026)

- El Excel es un archivo de traspaso para cargarlo en otro sistema de Finanzas.
  Debe contener solo las columnas del formato indicado, en el orden entregado.
- Descargar el Excel no cambia el estado de la cuota ni registra que fue
  exportada. La cuota sigue aprobada en estado 4.
- El monto a exportar es el neto aprobado, descontando licencias y ausencias.
- El Código de Unidad de Resolución es constante `05`; el Excel lo representará
  como texto `05000000`, según el ejemplo, para conservar los ceros iniciales.
- Las fechas expresan el período que se pagará. El archivo no distingue ni
  etiqueta cuota vigente versus atrasada; esa condición se entiende a partir
  de las fechas y del mes del proceso de pago (por ejemplo, septiembre).
- Si hay períodos atrasados que se pagarán juntos, se representan mediante un
  rango de fechas y además se agrega una fila para el período actual.
- El Excel histórico se armaba manualmente; no hay una regla preexistente que
  permita derivar de forma confiable los rangos y montos de cada fila.
- Regla acordada para el archivo: agrupar los períodos atrasados en un rango y
  poner esa fila primero; después agregar la fila del período nuevo/actual. El
  monto de cada fila será el neto aprobado sumado para los meses que abarca.
- El usuario confirma que el tramo `01-09-2026` a `31-12-2026` del ejemplo
  representa atrasos acumulados. El período de pago del Excel debe ser
  posterior a diciembre para que esas fechas sean atrasadas en sentido
  cronológico; esto debe reconciliarse con el ejemplo anterior de un Excel para
  pago en septiembre.

## Propuesta de integración

## Distribución propuesta de las dos vistas

### Vista 1: Bandeja «Cuotas aprobadas para Finanzas»

```text
Prestaciones / Cuotas aprobadas para Finanzas
Cuotas aprobadas por DGDP, disponibles para preparar el archivo de pago.

[Filtros]
Período de pago* [MM/AAAA]  Nombre funcionario  RUT  N° solicitud/cuota
N° resolución               Centro de costo      Fecha de envío desde / hasta
[Buscar] [Limpiar]

[Cuotas aprobadas: N] [Funcionarios: N] [Monto neto aprobado: $N]

[Descargar Excel de las N cuotas filtradas]

Funcionario / RUT | Solicitud | Resolución | Centro de costo / Actividad
Cuota | Períodos incluidos | Período de pago | Monto neto aprobado | Ver
----------------------------------------------------------------------------
Nombre Apellido      12345      2379/2026    4000.952 / Actividad ...
12.345.678-K         Cuota 1/2  ...          ago–sep 2026    sep 2026   $N
                                                                  [Ver detalle]
```

- `Período de pago` es obligatorio para definir el mes del proceso y ordenar
  los períodos cubiertos entre atrasados y nuevo/actual.
- Los filtros se combinan; el botón Excel exporta todas las cuotas que calzan,
  no solo una selección manual ni la página visible.
- `Monto neto aprobado` se calcula después de descuentos. El total superior
  debe coincidir con la suma neta de las cuotas filtradas.
- El `Corr` secuencial pertenece a las filas del archivo Excel; no es el número
  de cuota ni necesita mostrarse como identificador de la bandeja.
- La tabla debe tener estados de carga, error y sin resultados. Si no hay
  resultados, se informa que los filtros no encontraron cuotas aprobadas.

### Vista 2: Detalle de cuota aprobada, solo lectura

```text
‹ Volver a cuotas aprobadas para Finanzas

Detalle de cuota aprobada                          [Aprobada]
Solicitud 12345 · Cuota 1 de 2 · Resolución 2379/2026
Funcionario: NOMBRE APELLIDO · RUT: 12.345.678-K

[Resumen del pago]
Período de pago | Períodos incluidos | Monto solicitado
Descuentos       | Monto neto aprobado

[Cuota] [Documento de respaldo] [Documento de resolución]

Pestaña «Cuota» — misma información y detalle que en la revisión DGDP, en modo lectura
Funcionario y prestación
  Nombre, RUT, actividad, centro de costo, contrato y responsable

Resolución y financiamiento
  Número/año de resolución, unidad, código de centro e ítem

Períodos incluidos en la cuota
  Período | Estado | Monto bruto | Licencias | Ausencias | Neto aprobado
  ...

Justificaciones y descuentos
  Motivo/antecedente del descuento y su detalle, según la información disponible en DGDP

Pestaña «Documento de respaldo»
  Visualizador del justificativo o respaldo de pago, opción para abrir/descargar

Pestaña «Documento de resolución»
  Visualizador de la resolución, opción para abrir/descargar si está disponible
```

- Reutilizar calcada la vista de DGDP, con las mismas secciones y tres
  pestañas: `Cuota`, `Documento de respaldo` y `Documento de resolución`.
  Abrir por defecto `Cuota`.
- Mantener el detalle de meses, montos, descuentos y justificaciones/respaldo,
  para que Finanzas pueda revisar por qué el neto aprobado tiene ese valor.
- Mantener los documentos disponibles para visualizar/descargar.
- Quitar o deshabilitar todas las acciones de edición, aprobación, observación,
  rechazo, cambio de fechas/montos, registro o eliminación de compensaciones,
  carga/borrado de documentos y guardado. Todo el contenido queda en consulta.
- No mostrar acciones de aprobar, observar, rechazar, editar, guardar ni borrar.
- Dejar como acción principal únicamente «Volver a cuotas aprobadas para
  Finanzas». La descarga del Excel queda en la bandeja para que respete sus
  filtros.

### 1. Navegación y autorización

- Agregar una opción «Cuotas aprobadas para Finanzas» bajo el módulo existente
  de pagos.
- Usar el permiso de lectura DGDP ya derivado, sujeto a validar con usuarios
  que el alcance de la bandeja aprobada es el mismo que el de revisión.
- Fijar la consulta en estado 4; el usuario no necesita escoger estado para
  esta bandeja.
- Mantener la protección de lectura y volver a validar el estado autorizado en
  el backend al abrir el detalle y al preparar el Excel.

### 2. Bandeja y filtros

- Crear una vista dedicada, reutilizando la tabla, filtros y formato de datos
  de la bandeja DGDP cuando corresponda.
- Propuesta inicial de filtros: persona, RUT, centro de costo, resolución,
  número de solicitud/cuota, fecha de solicitud y período/fecha de pago.
- Definir explícitamente cuáles fechas filtran la búsqueda: `fec_solici` es la
  fecha de envío a DGDP; `ano_pago`/`mes_pago` es el período de pago. No son el
  período trabajado que cubre la cuota.
- Al ser datos financieros que pueden crecer, evaluar pasar filtros y
  paginación al PA en vez de cargar la bandeja completa al navegador.

### 3. Detalle de solo lectura

- Reutilizar el resumen de la cuota DGDP, incluyendo datos de la prestación,
  resolución, centro de costo, meses, montos y antecedentes disponibles.
- Ocultar acciones para aprobar, observar, rechazar, editar montos,
  compensaciones, descuentos, fechas de pago y adjuntos.
- Además de ocultar controles, verificar que cada operación de escritura
  rechace cuotas en estado 4. El permiso de lectura por sí solo no debe
  permitir cambiar datos.

### 4. Excel para Finanzas

- Exportar todas las filas que coincidan con los filtros vigentes, no solo las
  filas visibles en una página de tabla.
- Mantener las columnas y el orden del formato entregado: `Corr`, `Nombre`,
  `RUT`, `Código Haber`, `Monto`, `Fec_inicio`, `Fec_Termino`, `CC`, `Item`,
  `Porcentaje CC`, `Nº Resol`, `Cod_Unidad Res`, `Año Resol`.
- Usar `xlsx` ya instalado en frontend y conservar el RUT como texto para no
  transformar dígitos ni perder el dígito verificador `K`.
- Normalizar nombre en mayúsculas y espacios simples; producir RUT sin puntos,
  guion ni espacios. La fuente debe confirmar si entrega los dos nombres de
  pila en un único campo.
- Agrupar meses de ejecución atrasados consecutivos en una fila, ordenada
  primero; luego agregar el mes nuevo/actual. El monto de cada fila suma el
  neto aprobado de sus meses. El mes de proceso debe ser un criterio explícito
  de la exportación para establecer cuáles meses ya son atrasados.
- El ejemplo contiene una fila del 01-09 al 30-09 y otra del 01-09 al 31-12;
  esta segunda fila fue identificada por el usuario como atrasos acumulados.
  Falta reconciliar esas fechas con el ejemplo de un archivo para pago en
  septiembre; el llenado anterior era manual y no debe tomarse como regla
  temporal sin cerrar esa diferencia.
- Definir reglas de redondeo/formato, fechas, y fuente o valor constante de
  Código Haber, Item y Porcentaje CC.
- Si el archivo se produce desde datos consultados en frontend, la API debe
  entregar el conjunto íntegro y filtrado. Alternativamente, se puede construir
  el libro en backend si Finanzas exige un archivo controlado centralmente.

### 5. Datos y backend

- Reutilizar el PA de bandeja con `@cod_estcuo = 4` si sus campos bastan para
  filtrar y exportar.
- Ampliar la consulta/DTO o agregar una lectura dedicada para los campos que
  no aparecen hoy en la respuesta DGDP, entre ellos el código de ítem, Código
  Haber y las fechas/grano de exportación que se acuerden. Cod_Unidad Res se
  incluiría con el valor constante acordado.
- La descarga no persiste estado de exportación ni altera la cuota aprobada.
- Cualquier cambio Sybase debe incluir su par SQL/TXT de certificación.

## Decisiones pendientes

1. ¿Qué mes de proceso corresponde al ejemplo con atrasos 01-09 a 31-12? Si
   el proceso es septiembre, ¿se referían a fechas de otro año, o el ejemplo
   corresponde a un proceso posterior a diciembre?
2. ¿Cómo se obtiene el neto de la fila de atraso cuando la cuota tiene meses
   con montos distintos? La regla acordada es sumar los netos de los meses
   agrupados; confirmar que las fechas de inicio y término representen esos
   mismos meses.
3. ¿`Código Haber` (2417), `Item` (30600) y `Porcentaje CC` (100) son
   constantes para DU288 o provienen de datos distintos según
   solicitud/funcionario?
4. ¿Los filtros de fecha deben incluir fecha de solicitud y período de pago,
   o también fechas de inicio/término del Excel?
5. ¿El archivo debe respetar una plantilla oficial existente (nombre de hoja,
   encabezados exactos, formatos de fecha/monto, ceros iniciales y formato de
   número), además de las columnas del ejemplo?

## Siguiente paso sugerido

Reconciliar primero el mes de proceso con las fechas del ejemplo y confirmar
los campos de Finanzas que son constantes. Luego contrastar el Excel de
ejemplo con un archivo plantilla real y preparar el contrato de
lectura/exportación. Este documento no autoriza aún cambios de código ni de
base de datos.

---

## Revisión contra el código (27-10-2026)

Se contrastó el plan con el módulo implementado. El resultado mueve el peso del
trabajo: **la parte de pantallas está casi hecha y la parte de Excel tiene tres
bloqueos de fondo**, uno de ellos anterior a cualquier línea de código.

### A. Lo que ya existe

| Lo que pide el plan | Estado real |
| :--- | :--- |
| Bandeja con filtros de persona, RUT, centro, resolución, número y período de pago | **existe**, en `payments/review/index.vue` con `servicesProvisionDgdpReviewFilter.js` |
| Columnas de la bandeja | **existen todas** en el esquema DGDP, incluida «Meses cubiertos» |
| Consultar solo cuotas aprobadas | **existe**: el selector de estado ya ofrece el 4 |
| Detalle con tres pestañas `Cuota`, `Documento de respaldo`, `Documento de resolución` | **existe**, con `du288-payment-document-tab` reutilizado en las dos de documentos |
| Detalle en modo lectura, sin aprobar/observar/rechazar/editar | **existe por construcción**: con estado 4, `canResolve` es falso |
| Meses, montos, licencias, ausencias y neto por mes | **existen** en `du288-payment-months-review-section`, que ya tiene `editable` con omisión `false` y rotula «solo lectura» |
| Justificaciones y respaldo | **existen** en la pestaña de respaldo |
| `xlsx` en frontend | **existe**, `^0.16.9` |

Conclusión: **no hay que calcar la vista de detalle, hay que llegar a ella.** La
pantalla que el plan describe como «Vista 2» es la que ya se usa; lo que falta es
el punto de entrada, el rótulo y el botón «Volver» apuntando a la bandeja nueva.
Duplicar las 1.423 líneas de `_installmentNumber.vue` para quitarle botones que
ya no se dibujan sería crear un segundo lugar donde arreglar cada cosa.

Lo que sí falta en la bandeja: período de pago **obligatorio**, los tres
totalizadores (cuotas, funcionarios, monto neto), el filtro por fecha de envío
(`fec_solici`, que hoy no se filtra) y el botón de Excel.

### B. Bloqueo 1 — ¿de quién es esta bandeja? · **DECIDIDO: (a)**

> **Decisión del 27-10-2026.** La bandeja usa **el mismo permiso, el mismo rol y
> la misma condición que la bandeja DGDP de pagos**: `provision-payment-read-waiting`
> y la pertenencia a la unidad 696 que ya validan las PA. No se crea permiso ni
> se toca ninguna PA por autorización.

Esta pregunta decidía todo lo demás, y el plan la daba por resuelta cuando no lo
estaba.

Las decisiones de flujo ya registradas dicen:

> **Finanzas opera fuera del sistema.** El WF termina al registrar la petición
> de pago; no hay integración de ida ni de vuelta.
> La devolución **la registra DGDP a mano** cuando se lo comunican por fuera.

Y las 13 PA de pagos exigen `cod_organi = 696`, la unidad DGDP, 26 veces en
total.

De ahí salen dos lecturas, con consecuencias muy distintas:

| | Quién entra | Qué hay que construir |
| :--- | :--- | :--- |
| **(a) Bandeja de DGDP** para preparar el archivo que se le entrega a Finanzas | el mismo revisor DGDP de hoy | **nada de permisos ni de PA**: `read-waiting` ya sirve y las PA ya aceptan el estado 4 |
| **(b) Bandeja para usuarios de Finanzas** | personal de Finanzas, otra unidad | un permiso nuevo asignado, **y** resolver las 26 validaciones de unidad: PA nuevas para la consulta de Finanzas, o parametrizar la unidad en las existentes, que toca el guardián de DGDP |

La (a) es coherente con lo ya decidido —Finanzas no opera en el sistema— y
cuesta una fracción. La (b) es un alcance nuevo, con cambio de base de datos y
su par SQL/TXT de certificación por cada PA que se toque. **Mientras esto no se
decida, el resto del plan no se puede dimensionar.**

### C. Bloqueo 2 — la bandeja que nunca se vacía · **DECIDIDO: acción aparte**

> **Decisión del 27-10-2026.** La descarga sigue siendo una lectura que no cambia
> nada. Se agrega una acción explícita **«Marcar como enviada a Finanzas»** que
> lleva la cuota de 4 a 8 y sus meses de 2 a 3, grabando `fec_envrem`. El diseño
> está en el §G.

El plan acordó que descargar el Excel no cambia el estado ni registra la
exportación. Sin una acción aparte eso dejaba tres cosas abiertas:

1. **Nada distingue lo ya enviado.** La cuota sigue en 4 después de exportarse,
   así que el mes siguiente vuelve a aparecer en la bandeja junto a las nuevas.
   Quien arma el archivo no tiene en el sistema cómo saber qué ya subió: el
   riesgo concreto es exportar dos veces la misma cuota y pagarla dos veces.
2. **El estado 8 queda muerto.** El catálogo tiene `8 Enviada remuneraciones`
   con transición de meses `2 → 3` («su cuota se subió a Finanzas»), y los meses
   tienen `fec_envrem` y `mto_realpa` esperando justamente ese hecho. Con el
   acuerdo actual, esos dos campos y ese estado no se escriben nunca.
3. **El retorno de Finanzas se vuelve inalcanzable.** El estado
   `11 Devuelta Finanzas` se reincorporó a propósito para que DGDP registre la
   devolución. Se llega a él desde el 8. Sin 8 no hay 11.

Esto no contradice el acuerdo: **descargar** un archivo no debería cambiar
estados, es una lectura. Lo que falta es separar los dos actos:

- **Descargar el Excel** → lectura, no cambia nada. Como está acordado.
- **«Marcar como enviada a Finanzas»** → acción explícita, con confirmación, que
  lleva la cuota de 4 a 8 y sus meses de 2 a 3, grabando `fec_envrem`. Es el
  hecho que el modelo de datos ya está esperando.

Con eso la bandeja se vacía, el 11 vuelve a ser alcanzable y la descarga sigue
siendo inocua. Es una decisión funcional, no técnica: hay que confirmarla antes
de implementar la bandeja, porque cambia su columna de estado y su filtro por
omisión.

### D. Bloqueo 3 — el Excel

Es la única parte realmente nueva, y tiene tres problemas distintos.

#### D.1 Datos que no existen en ninguna respuesta de hoy

| Columna | De dónde sale |
| :--- | :--- |
| `Corr` | secuencial del archivo, se genera |
| `Nombre` | `nom_nombre` + `nom_appate` + `nom_apmate` ✅ |
| `RUT` | `rut_funcionario` ✅ |
| `Código Haber` | **no existe**. ¿constante 2417 o dato? |
| `Monto` | derivable por mes: `mto_apagar − mto_deslic − mto_dessg` ✅ |
| `Fec_inicio` / `Fec_Termino` | `ano_prop`/`mes_prop` por mes dan el período; las fechas se construyen |
| `CC` | `cod_ccto` ✅ |
| `Item` | **no existe** en la respuesta de pagos |
| `Porcentaje CC` | **no existe**. ¿constante 100? |
| `Nº Resol` | ⚠️ ver D.3 |
| `Cod_Unidad Res` | constante `05000000`, acordado |
| `Año Resol` | `ano_resolu` ✅ |

Tres columnas de trece no tienen fuente. Hasta saber si son constantes de DU288
o datos por solicitud, el contrato de exportación no se puede cerrar.

#### D.2 El archivo necesita los meses, y los meses vienen de a una cuota

La regla acordada —agrupar los atrasados en una fila y agregar la fila del
período actual, sumando el neto de los meses que abarca cada una— se calcula con
los **meses** de la cuota, no con la fila de la bandeja. La bandeja solo trae
`mes_prop_min`/`mes_prop_max` y los montos del encabezado.

Los meses se piden por cuota (`sg_epagsSecgen04`, un `id_funprse` + `nro_cuota`
por llamada). Exportar 80 cuotas filtradas desde el navegador serían 80
llamadas: un N+1 con 80 viajes a Sybase, cada uno reabriendo la validación de
unidad. Dos salidas:

- **PA nueva de exportación** que devuelva los meses de todas las cuotas
  aprobadas de un período de pago en una sola consulta, y armar el libro en
  frontend con `xlsx`.
- **Armar el libro en el backend**, que además es lo que corresponde si Finanzas
  exige un archivo controlado centralmente.

La segunda es preferible si el formato es contractual: el orden de columnas, los
ceros a la izquierda y el formato de fecha quedan en un solo lugar probado, y no
dependen de la versión de `xlsx` del navegador.

#### D.3 `Nº Resol` tiene que ser el número Exento

La resolución tiene dos números y no son intercambiables (ver §20 de
`rechazo_devolucion_y_estados.md`): `num_resolu_ext` es la **Resolución Exenta**,
el número impreso en el documento, y `nro_resolu` es el consecutivo interno de
SG-Solicitudes, que no aparece en ningún papel.

El Excel va a un sistema de Finanzas que calza contra el decreto, así que
`Nº Resol` es el **Exento**, con el `Año Resol` que le corresponde porque la
numeración Exenta se reinicia cada año. El modelo de la bandeja expone el
interno como `resolutionNumber`, que es el nombre más fácil de tomar por error.
El plan debe decirlo explícitamente: un archivo cargado con el número interno es
peor que una pantalla mal rotulada, porque nadie lo va a notar.

### E. Cómo implementarlo

El orden sale de los bloqueos: primero lo que no depende de decisiones, al final
lo que sí. **El desglose capa por capa, con archivos, contratos y verificación,
está en `implementacion_bandeja_finanzas.md`**; acá queda solo el orden.

**Fase 0 — decidir (sin código).** ✅ Resueltas las dos que cambiaban la
arquitectura: §B (la bandeja es de DGDP, mismo permiso y condición) y §C (acción
aparte para marcar el envío). Queda abierto lo del archivo: las tres columnas sin
fuente de D.1 y el mes de proceso del ejemplo, que solo afectan la Fase 4.

**Fase 1 — la bandeja, reutilizando.**

- `pages/services-provision/payments/finance/index.vue`: la bandeja DGDP con el
  estado fijo en 4, sin selector de estado, con período de pago obligatorio y
  los tres totalizadores. Reutiliza `filterDgdpInstallments` tal cual.
- `servicesProvisionDgdpReviewFilter.js`: agregar el filtro por fecha de envío
  (`requestedAt`), que hoy no existe. Es el único cambio al módulo de filtros.
- El esquema de columnas se reutiliza; si hay que quitar «Estado de la cuota»
  —redundante cuando todas son aprobadas— conviene parametrizar el esquema
  existente, no copiarlo.
- `store/service-provision-payments.js`: no necesita acción nueva.
  `fetchDgdpInstallments({ statusCode: 4 })` ya sirve.

**Fase 2 — el detalle, sin duplicar.** La ruta
`payments/review/_staffProvisionId/_installmentNumber.vue` ya es la vista
pedida. Lo que hay que hacer:

- que `backRoute` vuelva a la bandeja desde la que se entró, por `query` o por
  nombre de ruta;
- rotular la cabecera según el origen, sin tocar el contenido;
- revisar que la pestaña de respaldo no ofrezca cargar ni borrar documentos con
  estado 4, igual que hace la sección de meses.

Si más adelante el detalle de Finanzas tiene que divergir de verdad, el camino
es extraer las secciones de la pestaña `Cuota` a un componente, no copiar la
página.

**Fase 3 — «Marcar como enviada a Finanzas».** La PA nueva, el endpoint detrás
del permiso de escritura y la acción de lote en la bandeja, según el §G. No
espera ninguna decisión del archivo, así que puede ir antes del Excel; y es la
que evita pagar dos veces la misma cuota.

**Fase 4 — el Excel.** Cerradas D.1, D.2 y D.3: una lectura dedicada que
devuelva, para un período de pago, las cuotas aprobadas con sus meses; y la
construcción del libro donde se decida. Con su par SQL/TXT de certificación si
toca Sybase.

**Transversal.** Cada operación de escritura ya está detrás de
`provision-payment-approve`, no de `read-waiting`, y las PA validan además el
estado de la cuota. Eso cubre lo que el plan pide en su punto 3; conviene
dejarlo escrito como verificación, no como trabajo pendiente.

### F. Decisiones pendientes, reordenadas

Las dos que bloqueaban la arquitectura quedaron decididas el 27-10-2026: la
bandeja es de DGDP con el mismo permiso y condición (§B) y el envío a Finanzas
se marca con una acción aparte (§C). Siguen abiertas las del archivo:

1. El mes de proceso frente a las fechas `01-09` a `31-12` del ejemplo: tal como
   está, un archivo de pago de septiembre no puede tener atrasos hasta
   diciembre. Sigue sin reconciliar.
2. El neto de la fila de atraso cuando los meses tienen montos distintos.
3. ¿`Código Haber`, `Item` y `Porcentaje CC` son constantes de DU288?
4. Qué fechas filtran la bandeja.
5. ¿Hay plantilla oficial del archivo (hoja, encabezados, formatos)?

### G. «Marcar como enviada a Finanzas»: diseño de la acción 4 → 8

Es el único trabajo nuevo de base de datos que las decisiones del 27-10-2026
dejan en firme. Lo que escribe es el hecho que el modelo ya esperaba.

#### Lo que hace

| | Antes | Después |
| :--- | :--- | :--- |
| `sg_epag.cod_estcuo` de la cuota | 4 Aprobada | **8 Enviada remuneraciones** |
| `sg_fume.cod_estfum` de sus meses | 2 Comprometida | **3 Enviada a pago** |
| `sg_fume.fec_envrem` | nulo | fecha de la acción |
| `sg_fume.mto_realpa` | nulo | el neto que se envió, por mes |

Los cuatro campos existen y ya se leen: las PA de historial de mes
(`sg_fum2sSecgen01/02`) proyectan `mto_realpa` y `fec_envrem` desde el
26-10-2026. Hoy vuelven siempre nulos porque nadie los escribe.

#### Por qué una PA nueva y no la de decisión

`sg_epaguSecgen03` registra la decisión DGDP y está acotada a propósito: sus
estados de destino son **3, 4 o 10**, y solo acepta cuotas en **estado 2**. Una
cuota aprobada no entra, y ampliarla a 4 → 8 mezclaría dos actos distintos en un
PA cuyo nombre y validaciones hablan de visación.

Siguiendo la regla del paquete —crear uno nuevo en vez de forzar el existente—
corresponde una PA de actualización propia, `sg_epaguSecgen04`, con el mismo
cuerpo de validación que ya usan sus hermanas:

- `@rut_person`, `@id_funprse`, `@nro_cuota` obligatorios.
- La misma validación de asignación DGDP (`cod_organi = 696`, contrato vigente)
  que llevan las otras 13 PA del paquete, para que la autorización no dependa
  solo del backend.
- Exigir `cod_estcuo = 4`: desde cualquier otro estado la PA aborta con `msg`,
  igual que hace `sg_epaguSecgen03` con el 2. Así una cuota ya enviada no se
  envía dos veces aunque llegue una segunda petición.
- Dentro de una transacción: la cuota a 8, y sus meses en estado 2 a 3 con
  `fec_envrem` y `mto_realpa`. Si una parte falla, no queda la cuota enviada con
  los meses sin marcar.
- Par SQL/TXT de certificación, como todo cambio Sybase del paquete.

Pendiente menor: si además se quiere una línea de historial, `id_tipacc` tiene
FK a `sg_tacc`, así que haría falta una fila nueva en ese catálogo —los pagos
usan 32 (devuelta) y 33 (rechazada), guardadas en `sg_com1`—. Sin ella el
rastro queda en `fec_envrem` y el estado 8, que ya es auditable. Decidir si hace
falta no bloquea nada.

#### Backend

- Endpoint `POST …/payments/dgdp/provisions/{staffProvisionId}/installments/{installmentNumber}/sent-to-payroll`.
- **Detrás de `assertCanResolveDgdpPayment`**, no de `read-waiting`: es una
  escritura, y el permiso de lectura por sí solo no debe cambiar estados. Es la
  misma separación que ya tienen las otras seis escrituras del controlador.
- El repositorio llama la PA nueva y trata la fila `msg` como 403/422, igual que
  el resto del módulo.

#### Frontend

- La acción vive **en la bandeja**, junto a la descarga, no en el detalle de
  solo lectura: lo que se envía es el lote del período, y así el detalle sigue
  siendo una vista sin escrituras.
- Confirmación obligatoria que diga qué cuotas se marcan y que la acción no se
  deshace desde el sistema —desde 8 el camino de vuelta es el 11, que DGDP
  registra a mano cuando Finanzas devuelve—.
- Después de marcar, esas cuotas salen de la vista por omisión (estado 4). La
  bandeja PA ya acepta el 8 como filtro, así que consultarlas después es
  agregar esa opción, no una consulta nueva.

#### Orden respecto del Excel

La acción no depende del Excel ni el Excel de ella: se puede implementar antes,
mientras siguen abiertas las tres columnas sin fuente y el mes de proceso del
ejemplo. Conviene hacerlo así, porque es lo que evita el riesgo de pagar dos
veces la misma cuota y no espera ninguna decisión.

### H. Lo que este documento no autoriza

Nada de lo anterior se implementó. Es revisión del plan contra el código: no se
tocó ninguna pantalla, PA ni modelo para esta bandeja.
