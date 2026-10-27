# Plan propuesto: bandeja de cuotas aprobadas para Finanzas

**Fecha:** 27-10-2026  
**Estado:** borrador de análisis; incorpora acuerdos funcionales del 27-10-2026. Falta reconciliar el mes del proceso de pago con las fechas del ejemplo antes de implementar.

## Objetivo

Agregar una vista de solo lectura para las cuotas de prestaciones aprobadas por
DGDP que se prepararán para enviar a Finanzas. Desde la bandeja se podrán
buscar cuotas, abrir su resumen sin acciones de edición/decisión y descargar un
Excel con las filas que correspondan a los filtros activos.

## Comportamiento ya implementado

- El módulo `service-provision-payments` ya contiene la revisión DGDP.
- El permiso `provision-payment-read-waiting` se deriva para el revisor DGDP y
  protege la bandeja y sus vistas de consulta. No depende del Director DGDP ni
  de `eta/apso`.
- `sg_epag.cod_estcuo = 4` representa una cuota aprobada. El PA
  `sg_epagsSecgen03` acepta un estado concreto como filtro y devuelve datos de
  funcionario, RUT, centro de costo, resolución, período de pago, montos y
  cantidad de meses.
- La bandeja de revisión actual ya tiene filtros de persona, RUT, centro,
  resolución, número, período de pago y alertas. Esos filtros se aplican en el
  cliente después de cargar la lista.
- La ruta de detalle DGDP ya permite consultar cuotas aprobadas dentro de su
  historial, junto con el resumen y los meses asociados.
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
