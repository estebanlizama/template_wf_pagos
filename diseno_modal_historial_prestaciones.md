# Historial de prestaciones del funcionario

**Qué es este documento:** la explicación, para quien revisa o mantiene el sistema,
de cómo DGDP compara una prestación con las demás del mismo funcionario antes de
aprobarla o de pagarla, y de qué se cita cuando algo no cumple.  
**Pantalla:** modal «Historial de Prestaciones de Servicio del funcionario»
(`components/services-provision/Du288StaffPreviousProvisionsModal.vue`).  
**Actualizado:** 04-11-2026.

---

## 1. La idea en una frase

Cuando DGDP revisa algo de un funcionario, necesita saber si **lo que tiene
delante choca con lo que ese mismo funcionario ya tiene autorizado o pagado**.
El modal responde eso primero, con un sí o un no y el motivo, y deja el resto de
la información como respaldo para quien quiera verificarlo.

Se usa en dos momentos y **muestra la misma información en los dos**: las mismas
secciones, las mismas validaciones de la prestación y los mismos datos de
cuotas, topes y horas. Lo único que cambia es qué se revisa:

| Momento | Quién | Qué tiene delante | Qué se agrega |
| :--- | :--- | :--- | :--- |
| **WF resolución** | DGDP visando una solicitud | Una **solicitud** de prestación: un período de ejecución, un monto, cuotas declaradas, un horario y compensaciones | La cita para la devolución o el rechazo |
| **WF pagos** | DGDP visando una cuota | La **prestación** a la que pertenece la cuota, más la **cuota**: los meses que agrupa, su mes de pago y su monto | Tres validaciones de la cuota: su mes de pago en el cupo, que sus meses no estén en otra cuota del centro de costo y su monto contra el tope congelado |

El solicitante también puede abrir el historial desde el formulario, solo para
consultarlo. No puede citar.

---

## 2. Contra qué se compara: no todas las prestaciones pesan igual

Un funcionario puede tener prestaciones en varios centros de costo, de distintos
años y en distintos estados. **Compararlo todo contra todo confunde**: una
prestación de 2016 en otro centro de costo no tiene nada que decir sobre una
solicitud de noviembre de 2026.

Por eso cada prestación del historial se ubica en **una** de estas relaciones,
siempre respecto de lo que se está revisando:

| Relación | Cuándo | Para qué sirve |
| :--- | :--- | :--- |
| **Impide aprobar** | Es la causa de una regla que no se cumple | Es la que hay que mirar y citar |
| **Mismo centro de costo** | Comparte centro de costo (la misma actividad) | Pesa en el cupo de meses de pago, el mes ya tomado y el tope |
| **Coincide en el tiempo** | Otro centro de costo, pero se ejecuta en las mismas fechas | Pesa en lo que es límite de la persona: horario, compensación y horas semanales |
| **Continuidad de fechas** | Terminó 15 días o menos antes de que empiece esta | Solo aviso: podría ser la misma actividad partida en dos |
| **Sin relación** | Nada de lo anterior | Se lista, pero no influye en nada |

La relación se calcula una sola vez, contra lo que se revisa. **No cambia al
hacer clic en otra fila**, que era uno de los problemas del modal anterior.

### Qué regla mira qué prestaciones

Esta es la parte que más conviene tener clara, porque responde a decisiones
ya tomadas:

| Regla | Qué prestaciones cuenta | Por qué |
| :--- | :--- | :--- |
| Cupo de meses de pago (2 al año, 12 con extensión) | Solo las del **mismo centro de costo**, en el mismo año | El cupo es de la actividad, no del funcionario (decisión del 03-11-2026) |
| Mes ya tomado | Solo las del **mismo centro de costo** | Un mes se paga una vez por actividad |
| Tope mensual | Solo las del **mismo centro de costo** que coinciden en el tiempo | El tope es por centro de costo y se aplica por cuota (decisión del 03-11-2026) |
| Horario | **Cualquier centro de costo**, si coinciden en el tiempo | Una persona no puede estar en dos lugares a la misma hora |
| Compensación | **Cualquier centro de costo** | Las mismas horas no se compensan dos veces |
| Horas semanales (56 h) | **Cualquier centro de costo**, si coinciden en el tiempo | Es la carga de la persona |

---

## 3. Qué se ve, en el orden en que importa

El modal está ordenado **en preguntas**. DGDP no tiene que interpretar tablas:
cada pregunta trae su respuesta escrita y por qué, un borde de color y, debajo,
solo el dato que la sostiene y las validaciones que la responden. Lo que sigue a
las preguntas es respaldo.

**El modal apoya el criterio de quien revisa; no lo reemplaza.** Por eso:

- **No dicta la decisión.** Habla de «Sin observaciones» y de «N puntos a
  revisar», no de «puede» o «no puede continuar». Al inicio hay una nota fija:
  las validaciones aplican la norma, los avisos quedan a su criterio y la
  decisión es de quien revisa.
- **No afirma lo que no sabe.** Cada respuesta tiene tres estados:
  - **Sí**;
  - **No**;
  - **Por confirmar**, cuando falta un dato. Hoy pasa cuando una prestación que
    coincide en el tiempo no informa su horario, o mientras se carga: horario y
    56 h no se pueden confirmar, y el modal lo dice con el número de la
    prestación.
- **Dice qué resolvería cada «No».** Bajo cada validación que no se cumple va
  «Qué lo resolvería», por ejemplo «Declare 1 cuota o menos». Si un mes ya está
  tomado, sugiere los meses libres más cercanos en ese centro de costo.
- **Separa norma de criterio.** Las validaciones son la norma. Los avisos van
  bajo «Para su criterio» porque no impiden aprobar.
- **Fecha el dato.** «Datos al 04-11-2026 10:32», porque los estados de meses y
  cuotas cambian mientras la pantalla está abierta.
- **Muestra el estado de todo.** Para cada mes, cuota y pago se ve en qué estado
  está:
  - meses: propuesto, comprometido, enviado a pago o rechazado;
  - cuotas: borrador, en visación, observada, aprobada, enviada a
    remuneraciones, rechazada o devuelta;
  - prestaciones: sin cuotas, pendiente de pago, en pago, pago parcial o pagada.

  Las etiquetas salen del código del estado, no del texto del catálogo, que en
  el servidor de prueba puede venir con problemas de codificación.

La vista es **la misma en WF resolución y en WF pagos**. Lo único que cambia es
qué se evalúa: una solicitud o una cuota. Por eso WF pagos suma una tercera
pregunta sobre la cuota.

1. **Qué se revisa.** Una línea que dice exactamente qué está en juego:
   *«Solicitud N° 213 · 9070.1 Adm. camioneta Chevrolet LUV — ejecución
   02/11–31/12/2026, $151.111 variable en 2 cuotas, dentro de jornada, tope
   $256.250»*. En WF pagos: *«Cuota N° 1 de la prestación N° 210 · 9010.8 —
   pago en agosto 2026, meses julio 2026, $1.111.111, tope $1.200.000»*.
   Debajo van el resultado de todas las validaciones juntas («Sin
   observaciones», «N puntos a revisar» o «N validaciones no se pueden
   confirmar todavía»), la nota de apoyo y la fecha del dato.

2. **Pregunta 1 — ¿Puede comprometer estos meses de ejecución?** En WF pagos
   se pregunta «¿Los meses de esta cuota están libres?». La respuesta nombra
   cada mes que falla y por qué, por ejemplo *«No: noviembre 2026 (tomado por
   N° 214 y supera el tope)»*. La tabla tiene una fila por mes con:
   - **Lo que se revisa:** el estado de ese mes en la propia prestación, por
     ejemplo «propuesto · sin cuota» o «comprometido · cuota 1 aprobada · pago
     diciembre 2026 · pagado $70.000».
   - **En este centro de costo:** «Libre» o «Tomado por N° 220 (comprometido,
     cuota aprobada)».
   - **Tope comprometido:** lo que suman ese mes las prestaciones del centro de
     costo frente al tope, en rojo si lo supera.
   - **Otros centros de costo:** quién ejecuta ese mes, en qué estado y si
     choca en horario, compensación o 56 h.

   Debajo están las validaciones de esta pregunta: mes ya tomado, tope mensual,
   horario, compensación y carga semanal.

3. **Pregunta 2 — ¿Tiene cuotas para el pago en este centro de costo?** Es la
   respuesta a «¿le quedan cuotas?, ¿cuál es el máximo?». Cuenta las cuotas
   pagadas, en gestión y por crear. Muestra cuatro cifras:
   - el límite del año: 2, o 12 con extensión;
   - lo ya usado;
   - lo disponible;
   - el máximo que puede declarar, que es el menor entre lo disponible y los
     meses de ejecución.

   En WF pagos se suma una quinta cifra: con qué mes de pago quedaría la cuota.
   Debajo aparecen:
   - cuánto se le ha pagado en ese centro de costo en el año y en total;
   - **en qué estado está todo en ese centro de costo**, incluida la propia
     prestación. Por ejemplo: meses «2 propuestos · 3 comprometidos · 1 enviado
     a pago»; cuotas «1 en visación · 2 enviadas a remuneraciones»; pago de las
     prestaciones «1 pendiente de pago · 1 pagada»;
   - una fila por cada prestación del mismo centro de costo, con lo pagado, lo
     que está en trámite, lo que falta por crear y si comparte cupo;
   - la validación del cupo de meses de pago.

   Con extensión de cuotas el cupo es propio de la prestación. Lo pagado en otras
   resoluciones se informa, pero no lo reduce.

4. **Pregunta 3 — ¿Se puede pagar esta cuota?** (solo WF pagos). La respuesta
   dice dónde queda la cuota frente a las demás de su prestación, por ejemplo
   *«Cuota N° 2 de 3 declaradas. Las demás: 1 enviada a pago · 0 en gestión ·
   1 por crear»*. La tabla tiene todas las cuotas de la prestación, con la
   revisada marcada «Esta cuota». Cada fila muestra el estado de la cuota, el
   mes de pago, los meses que agrupa con su estado («noviembre 2026 (enviado a
   pago)»), el monto, los descuentos y lo pagado. Debajo se listan los meses que
   todavía no tienen cuota, con su estado, y las validaciones de la cuota:
   - cupo de meses de pago con este mes;
   - mes ya pagado;
   - tope de la cuota.

5. **Como persona, en todos los centros de costo.** Lo que cruza todas sus
   prestaciones, sin importar el centro de costo:
   - horas semanales con su desglose;
   - horarios ya ocupados por otras prestaciones del mismo período, con su
     número;
   - compensaciones del período: las de lo que se revisa y las propuestas y
     realizadas de las demás.

6. **Los avisos.** Hechos que **no impiden** aprobar, pero que DGDP debería
   conocer. Solo aparecen si vienen de una prestación relacionada.

7. **Respaldo plegado.** Cada sección muestra un resumen en el título y se abre
   sola si tiene hallazgos. «Ver respaldo», junto a una validación que no se
   cumple, lleva a la sección que corresponde.
   - **¿Puede optar a otra resolución o a cuotas en otros centros de costo?**
     Abierta desde el inicio. Tiene una fila por centro de costo, la del que se
     revisa primero, con:
     - cuántas prestaciones tiene;
     - los meses de pago usados del año;
     - lo pagado y lo que está en trámite;
     - **¿Otra resolución?:** «Sí, hasta N cuotas» o «No: cupo completo». En el
       centro de costo que se revisa ya se descuenta lo que pide la solicitud;
     - **¿Cuotas por generar o pagar?:** «Sí: N por crear», «N por crear, sin
       cupo en el año» o «No hay cuotas por crear».

     Con muchos centros de costo se muestran 8 y un buscador.
   - **Cuotas por estado, descuentos y pagos** de las prestaciones relacionadas,
     con totales.
   - **Compensaciones por fecha:** las de lo que se revisa frente a las
     propuestas y realizadas de otras prestaciones.
   - **Rechazos y devoluciones:** de la solicitud, de los meses y de las
     cuotas, con fecha, detalle y motivo. Se informan para su criterio y no
     cuentan para ninguna validación (ver §7).
   - **Línea de tiempo del año:** «E» donde se ejecuta y «P» donde se paga.

8. **La lista de prestaciones**, ordenada por relación, con buscador,
   paginación y el detalle mes a mes de cada una.

9. **Los hallazgos para citar.** Solo DGDP en WF resolución, porque en WF pagos
   la devolución de una cuota tiene su propio motivo. Es una lista para marcar.
   El texto se arma al usar «Citar en devolución» o «Citar en rechazo» del pie.

Se retiraron, porque repetían lo que ya responden las preguntas:
- el bloque «Topes y carga semanal»;
- la tarjeta «Validaciones aplicadas», ahora repartida entre las preguntas;
- el cruce mes a mes, ahora en la tabla de la pregunta 1;
- el resumen «Cuotas y pagos», ahora en la pregunta 2;
- la vista previa «Texto para».

---

## 4. Las reglas, explicadas

### 4.1 En WF resolución

| Regla | Qué pregunta | Ejemplo de texto si no cumple |
| :--- | :--- | :--- |
| Cupo de meses de pago | ¿Le quedan meses de pago a esta actividad en el año para las cuotas que se piden? | «9070.1 en 2026: 2 de 2 meses de pago ya usados por la prestación N° 205. Esta solicitud pide 2 y quedan 0.» |
| Mes ya tomado | ¿Algún mes de esta solicitud ya lo compromete otra prestación de la misma actividad? | «Noviembre 2026 ya está tomado en 9070.1 por la prestación N° 206.» |
| Tope mensual | ¿Lo que se paga al mes en esta actividad, sumando lo concurrente, cabe en el tope? | «9070.1: con la prestación N° 207 suma $351.111 al mes, sobre un tope de $256.250.» |
| Horario | ¿El horario semanal choca con el de otra prestación que se ejecuta al mismo tiempo? | «El martes de 10:00 a 12:00 ya está ocupado por la prestación N° 214.» |
| Compensación | ¿Alguna compensación cae sobre una propuesta o realizada de otra prestación? | «El 10/11 de 18:00 a 19:00 se cruza con una compensación propuesta de la prestación N° 214 (18:30–20:00).» |
| Horas semanales | ¿Contrato, honorarios y ejecución **fuera de jornada** superan 56 h? | «Carga semanal: 56,5 h (44 h de contrato y honorarios, 0 h de esta solicitud y 12,5 h de la prestación N° 214), sobre el máximo de 56 h.» |

La ejecución **dentro de jornada** no suma horas: ya es parte del contrato.

### 4.2 En WF pagos

| Regla | Qué pregunta | Ejemplo de texto si no cumple |
| :--- | :--- | :--- |
| Cupo de meses de pago | ¿El mes de pago de esta cuota cabe en los 2 del año de la actividad? | «9010.8 en 2026: con el pago en agosto 2026 serían 3 meses de pago, sobre el límite de 2.» |
| Mes ya pagado | ¿Algún mes que agrupa esta cuota ya está en una cuota de otra prestación de la misma actividad? | «Julio 2026 ya está en una cuota de la prestación N° 209, en 9010.8.» |
| Tope de la cuota | ¿El monto cabe en el tope que autorizó la resolución? | «$1.111.111 supera el tope autorizado de $1.000.000.» |
| Compensación | ¿Alguna compensación de la cuota se cruza con la de otra prestación? | Igual que en resolución |

Un límite que conviene saber: el historial no trae las **otras cuotas de la
misma prestación** que se está pagando. Que no se pase de sus cuotas declaradas
lo controla el procedimiento de pagos (`sg_epagiSecgen01`), no este modal.

### 4.3 Los avisos

| Aviso | Ejemplo |
| :--- | :--- |
| Otra prestación se ejecuta en el mismo período | «La prestación N° 214 (9010.8) se ejecuta en el mismo período, con $200.000 al mes. No comparte cupo ni tope con esta solicitud.» |
| Una cuota se paga dentro del período | «La prestación N° 214 tiene la cuota N° 1 (aprobada) con pago en noviembre 2026.» |
| Hay compensaciones propuestas sin realizar | «La prestación N° 214 tiene 1 compensación propuesta aún sin realizar.» |
| Faltan cuotas por crear en la misma actividad | «La prestación N° 205 tiene 1 de 2 cuotas creadas; las que faltan pueden consumir cupo de meses de pago.» |
| Continuidad de fechas | «La prestación N° 211 terminó 15 días o menos antes de que empiece esta solicitud. Revise si es la misma actividad fraccionada.» |

---

## 5. Qué se cita y cuándo

Citar sirve para que el solicitante entienda **por qué** se devuelve o se rechaza
su solicitud. Por eso se cita solo lo que sostiene la decisión.

**Se cita:**

- Las reglas que no se cumplen. Vienen **marcadas** de antemano.
- Los avisos, solo si DGDP los marca a mano. Sirven en una devolución para pedir
  que se revise algo; rara vez en un rechazo.

**No se cita:**

- Lo que cumple. No aporta.
- Datos de prestaciones sin relación.
- Coincidencias que no son conflicto (mismo cargo, mismo ítem).
- Problemas de calidad de los datos del sistema. Son del sistema, no del
  funcionario, y se reportan aparte.

**La devolución y el rechazo dicen cosas distintas**, porque piden cosas
distintas:

> **Devolución** — se pide corregir, así que cada hallazgo dice qué hacer:
>
> *DGDP devuelve la solicitud N° 213 para corregir lo siguiente, según el
> historial de prestaciones del funcionario:*  
> *1. Compensación: el 10/11 de 18:00 a 19:00 se cruza con una compensación
> propuesta de la prestación N° 214 (18:30–20:00). Cambie la fecha u hora de esas
> compensaciones.*

> **Rechazo** — se cierra la solicitud, así que basta el motivo:
>
> *DGDP rechaza la solicitud N° 213 porque no cumple lo siguiente, según el
> historial de prestaciones del funcionario:*  
> *1. Cupo de meses de pago: 9070.1 en 2026: 2 de 2 meses de pago ya usados por
> la prestación N° 205. Esta solicitud pide 2 y quedan 0.*

El texto se lleva al modal de devolución o de rechazo de la etapa. Si la etapa no
tiene esa acción, el historial vuelve a abrirse con lo marcado y lo avisa.

En **WF pagos** no se cita desde aquí: la devolución o el rechazo de una cuota
tiene su propio motivo en la pantalla de revisión.

---

## 6. Otras formas de mostrar la información

La estructura actual pone todo a la vista. Si en el uso resulta larga, estas son
las alternativas, de menor a mayor cambio. **Ninguna está aplicada todavía.**

| Opción | Qué cambia | A favor | En contra |
| :--- | :--- | :--- | :--- |
| **A. Respaldo plegado** | Veredicto y avisos siempre abiertos; cruce, compensaciones, cuotas y línea de tiempo plegados con un título que resume («Compensaciones: 1 cruce») | La decisión cabe en una pantalla | Un clic más para verificar |
| **B. Solo lo relacionado** | La lista muestra por defecto solo prestaciones con relación, con «Ver todas (4)» | Desaparece el ruido de prestaciones antiguas | Hay que recordar que existen las demás |
| **C. Línea de tiempo arriba** | La línea de tiempo pasa a estar debajo del veredicto, como vista principal | Se ve de un vistazo dónde chocan los meses | Ocupa ancho; en pantallas chicas se lee peor |
| **D. Detalle junto al hallazgo** | Cada regla que no cumple se puede desplegar ahí mismo para ver los meses, cuotas o tramos que la provocan | El respaldo aparece donde se necesita | Requiere más trabajo de interfaz |

**Aplicado el 04-11-2026: A y B**, más una versión liviana de la D. Lo que se ve
ahora:

- **Qué se revisa** lleva una etiqueta «WF resolución» o «WF pagos», para que
  nunca haya duda de qué pantalla es.
- **El resultado** muestra un ícono grande y el motivo en una línea. Las reglas
  que no cumplen quedan con fondo rojo suave y un enlace **«Ver respaldo»**, que
  abre la sección que las explica y lleva hasta ella.
- **Los avisos** dicen en su encabezado que no impiden aprobar.
- **El respaldo** (cruce mes a mes, compensaciones, cuotas y pagos, línea de
  tiempo) va plegado. Cada sección muestra en su título un resumen, por ejemplo
  «1 cruce · 1 sin realizar». Las que tienen hallazgos se abren solas y llevan
  la marca «Con hallazgos».
- **El cruce mes a mes y las compensaciones** pintan en rojo suave la celda o el
  día que se pasa del tope o se cruza.
- **La línea de tiempo** tiene leyenda de colores: lo que se revisa en azul
  sólido, el mismo centro de costo en azul claro y los demás en gris.
- **La lista de prestaciones** muestra solo las relacionadas, con «Ver todas (n)»
  para el resto.
- **La cita** explica el paso a seguir; el texto se arma con los botones del
  pie «Citar en devolución» o «Citar en rechazo».
- Al abrir el historial de otra solicitud o funcionario, todo vuelve al estado
  inicial.

Queda pendiente la **D completa** (el detalle desplegado dentro de la misma fila
de la regla). Conviene decidirla con el uso real.

### 6.1 Cuando el funcionario tiene cientos de prestaciones

Un funcionario puede tener prestaciones en muchos centros de costo. La regla
general es: **primero lo que pesa en la decisión, el resto a un clic**, y ningún
texto enumera sin límite.

| Parte | Comportamiento |
| :--- | :--- |
| Textos de reglas y avisos | Nombran como máximo 3 prestaciones o casos: «… por la prestación N° 205, N° 207, N° 209 y 12 más» |
| Avisos | Los 5 primeros; «Ver N más» para el resto |
| Cruce mes a mes | Cada celda muestra hasta 3 prestaciones y «y N más». La primera columna queda fija al desplazar en horizontal |
| Compensaciones | Primero los cruces y lo pendiente, después el resto; hasta 15 filas y «Ver N más» |
| Cuotas y pagos | El mismo centro de costo primero; hasta 10 prestaciones y «Ver N más» |
| Línea de tiempo | Lo revisado arriba, después lo relacionado; hasta 12 filas y «Ver N más». Ancho mínimo con desplazamiento horizontal |
| Lista de prestaciones | Solo las relacionadas; «Ver todas (n)». Con más de 10, un buscador por N°, centro de costo o estado. Páginas de 15 |
| Hallazgos para citar | Todas las reglas incumplidas y, como mucho, los 10 primeros avisos |

**Rendimiento medido** (sin la interfaz, con 6 meses y 8 compensaciones por
prestación): 600 prestaciones se evalúan en unos 0,12 s y 2.000 en unos 0,45 s.
Antes de optimizar la comparación de compensaciones eran 2,5 s y 9 s. La versión
optimizada da el mismo resultado que la original en 5.000 casos aleatorios.

**Pendiente:** la regla de horario carga el horario de cada prestación que
coincide en el tiempo con una consulta por prestación. Con pocas concurrentes no
se nota; con decenas convendría una consulta única por funcionario.

### 6.2 Pantallas chicas

- La lista de reglas pasa de tres columnas a dos: el ícono y, debajo del nombre,
  el texto.
- La etiqueta «WF resolución / WF pagos» baja de línea cuando no cabe.
- Las tablas y la línea de tiempo se desplazan en horizontal, sin apretarse.
- Los botones del pie se acomodan en varias líneas.

---

## 7. De dónde sale cada dato

Todo llega en **una sola lectura por funcionario**, sin consultas por prestación.

| Dato | Tabla | Estados que importan |
| :--- | :--- | :--- |
| Prestación: centro de costo, período, ejecución, monto, tope congelado, cuotas declaradas, extensión | `sg_fups`, `sg_prse` | Estado de la solicitud |
| Mes de ejecución | `sg_fume` | 1 Propuesto (no consume) · 2 Comprometido · 3 Enviado a pago · 4 Rechazado (no consume) |
| Cuota que paga el mes: número, mes de pago, estado | `sg_dpag` → `sg_epag` | 1 Borrador · 2 En visación · 3 Observada · 4 Aprobada · 8 Enviada a remuneraciones · 11 Devuelta · la rechazada no se informa |
| Compensaciones realizadas | `sg_fuc2` | — |
| Compensaciones propuestas | `sg_fuco` | — |
| Horario semanal | `sg_fuho` | Se carga solo para las prestaciones que coinciden en el tiempo |
| Rechazos y devoluciones (solo informa) | `sg_hist`, `sg_fume`, `sg_com1` → `sg_fupssSecgen19` | Lectura aparte: nunca llega a las validaciones |

**Procedimientos que hay que desplegar:**

- `cambios_pa/sg_fume/sg_fupssSecgen17`: actualizado, agrega la cuota de cada mes.
- `cambios_pa/sg_fuco/sg_fucosSecgen02`: nuevo, trae las compensaciones propuestas.
- `cambios_pa/sg_fups/sg_fupssSecgen19`: nuevo, trae los rechazos y devoluciones
  de la solicitud, de los meses y de las cuotas, con su motivo. Es solo
  informativo y va aparte, para que lo rechazado no pueda contar en ninguna
  regla. El detalle está en `cambios_pa/README.md`.

**Lo rechazado se informa, no cuenta.** Hay tres niveles:
- **Solicitud rechazada:** el historial que alimenta las reglas la sigue
  descartando, igual que antes.
- **Mes rechazado** (estado 4): no consume cupo ni tope y ya **no toma el mes**
  en «mes ya tomado». Se corrigió en el frontend (`costCenterMonthLockCheck`) y
  en su espejo del servidor (`validateStaffCostCenterMonthLock`).
- **Cuota rechazada:** el mes vuelve a «propuesto» y no cuenta.

Los tres aparecen en la sección «Rechazos y devoluciones», junto con las
devoluciones de solicitudes y de cuotas y su motivo. En la pregunta 3 se
agrega lo que antes se rechazó o devolvió en la misma prestación.

Para lo que muestran las preguntas **no hace falta modificar otro
procedimiento**. Con esos tres, más los que ya existían, está todo:
- número, mes de pago, estado y montos de cada cuota (`mto_apagar`,
  `mto_realpa`);
- descuentos (`mto_deslic`, `mto_dessg`);
- compensaciones propuestas y realizadas;
- horarios.

La pregunta 3 de WF pagos necesita las cuotas de la propia prestación. El
servidor ya las tenía: el contexto de la cuota
(`service-provision-payment.controller.ts`) lee el historial una sola vez y
devuelve aparte `previousProvisions` (las demás prestaciones, igual que antes)
y `currentProvision` (la prestación de la cuota).

Mientras no estén desplegados, el modal funciona igual. Las cuotas aparecen como
«Sin cuota» y las compensaciones propuestas se reducen a la primera de cada
prestación.

**Código:**

- Reglas y datos de cada sección: `utils/services-provision/provisionHistoryEvaluation.js`.
  No tiene reglas propias: usa las mismas que el formulario y el servidor.
- Textos: `utils/services-provision/provisionHistoryTexts.js`.
- Preguntas: `QUESTION_RULES` agrupa las reglas por pregunta;
  `buildMonthCommitment` arma la tabla de la pregunta 1 y
  `buildOwnInstallments` la de la pregunta 3.
- Pruebas: `utils/services-provision/__tests__/provisionHistoryEvaluation.test.cjs`, 40 casos.

---

## 8. Estado

| Qué | Estado |
| :--- | :--- |
| Reglas y avisos de WF resolución y WF pagos | ✅ Aplicado y probado |
| Modal ordenado en preguntas (§3) | ✅ Aplicado; montado sin errores en 8 casos de prueba, incluido uno de 120 prestaciones en 60 centros de costo. Falta revisarlo en el navegador |
| Cita diferenciada para devolución y rechazo, solo DGDP | ✅ Aplicado |
| Procedimientos `sg_fupssSecgen17` y `sg_fucosSecgen02` | ⏳ Escritos, falta desplegarlos |
| Otras formas de mostrar la información (§6) | ✅ A y B aplicadas, con «Ver respaldo»; la D completa queda por decidir |
| Apoyo al criterio: tres estados, «Qué lo resolvería», fecha del dato, estados de meses, cuotas y pagos (§3) | ✅ Aplicado y probado; falta revisarlo en el navegador |
| Rechazos y devoluciones del funcionario, con su motivo (§7) | ✅ Aplicado y probado. Falta desplegar `sg_fupssSecgen19` y revisarlo en el navegador |
| «Mes ya tomado» ignora los meses rechazados | ✅ Aplicado en el frontend y en el servidor, con pruebas |

---

## 9. Historial de cambios

- **05-11-2026 (indicadores de cuotas).** Las cuatro cifras de antes (Límite,
  Usados, Disponibles, Máximo a declarar) se repetían y mostraban límites que
  no aplicaban: un 2 o un 12 en una prestación de un mes. Ahora son tres
  indicadores que responden la decisión y siempre dicen qué acota:
  - **WF resolución:**
    - **Pide** N cuotas.
    - **Puede hasta** M, con «lo limita: …». Se nombra solo lo que acota de
      verdad: «su único mes de ejecución», «sus 6 meses de ejecución», «el
      cupo del centro de costo (1 libre de 2)» o «el máximo con extensión».
    - **Después de esta**: «X de 2 libres para otras resoluciones», o «Cupo
      propio» con extensión.
  - **WF pagos:**
    - **Cuota** N° x de y decretadas.
    - **Pago en** el mes, con o sin extensión.
    - **Cupo con esta cuota** «X de L», con «lo limita: …».

  El detalle de lo usado (pagado, en trámite, por crear) pasa a la línea de
  abajo. Si pide más de lo que puede, el recuadro se marca en rojo.

- **05-11-2026 (cuatro variables).** Se quitó la insignia «WF pagos / WF
  resolución»: la vista es la misma y lo que se revisa ya lo dice el título.
  El subtítulo muestra igual en las dos pantallas lo que cambia la lectura de
  todo lo demás:
  - el tipo de monto, con el total y las cuotas;
  - si tiene extensión;
  - la jornada;
  - el tope por cuota, o «exento de tope».

  En WF pagos se agrega la cuota que se revisa. Cada combinación queda así:

  | | **Fijo** | **Variable** |
  | :--- | :--- | :--- |
  | **Sin extensión** | Tope **por cuota**: la cuota más cargada agrupa ⌈meses/cuotas⌉ meses y su suma no pasa el tope. Cupo: 2 meses de pago al año, compartido en el centro de costo. | Tope por cuota: el total repartido en las cuotas no pasa el tope en ninguna. El monto de cada mes se define al pagar, así que la pregunta 1 no afirma un monto por mes. Cupo: 2, compartido. |
  | **Con extensión** | Exento de tope. Cupo propio: hasta 12, acotado a sus meses de ejecución y, en WF pagos, a las cuotas decretadas. | Igual: exento de tope y cupo propio acotado. |

  Se corrigió:
  - **Fijo con menos cuotas que meses** pasaba aunque la cuota superara el
    tope: el modal comparaba el promedio por mes. Ahora usa la cuota más
    cargada, igual que el formulario (`getTopBrutoLabel`) y que el pago
    (`sg_fumeuSecgen02`).
  - **«1 de 12» con extensión.** El techo es el menor entre 12, los meses de
    ejecución y las cuotas decretadas. Una prestación de un mes y una cuota
    muestra «1 de 1», y el recuadro dice qué lo acota.
  - **En WF pagos**, «Máximo a declarar» pasa a «Cuotas decretadas», porque
    declarar cuotas es de la resolución.

- **05-11-2026 (revisión con datos reales, N° 213 y N° 210).** Se corrigió:
  - **«Cuotas por estado» mostraba «ninguna cuota»** aunque el funcionario
    tenía cuotas en otros centros de costo, porque solo miraba lo relacionado.
    Ahora lista todas sus prestaciones: primero el mismo centro de costo,
    después lo relacionado y al final el resto.
  - **Estados de cuota por código** en celdas, conteos y avisos, con el
    catálogo `sg_ecuo`:
    - 2 «en revisión DGDP»;
    - 3 «observada», que es la devuelta por DGDP;
    - 11 «devuelta por Finanzas»;
    - además 5, 6, 7, 9 y 12.

    Así deja de verse «revisi?n» cuando el texto del catálogo llega con
    problemas de codificación.
  - **El motivo de los rechazos y devoluciones de solicitud ya no muestra la
    nota de subrogancia.** Esa nota incluye el RUT del titular. Se quita en el
    servidor y queda solo lo que la persona escribió.
  - **Fila del centro de costo revisado** en la tabla de centros de costo:
    - dice «N + la revisada» prestaciones;
    - cuando el cupo lo completa la propia solicitud, dice «No: esta solicitud
      completa el cupo», en vez de «cupo completo».
  - **Botón «Actualizar datos»** junto a «Datos al …». Vuelve a consultar sin
    cerrar el modal:
    - en WF resolución, el historial y los rechazos;
    - en WF pagos, el contexto completo de la cuota, que antes se cargaba una
      sola vez con la página.

    Los horarios también se vuelven a pedir.

- **05-11-2026 (tarde).** Se agregan dos cambios:
  - **Cuarto estado, «A su criterio»**, para lo que el sistema no bloquea. En WF
    pagos, el PA que crea la cuota (`sg_epagiSecgen01`) controla el total de
    cuotas, que el mes no esté en una cuota de otra prestación del mismo centro
    de costo y que la última cuota no se pague antes del término. No controla
    el cupo de meses de pago del año. Por eso, en WF pagos, las dos reglas de
    cupo (`monthDistribution` y `paymentMonthQuota`) y «¿Tiene cuotas para el
    pago?» se muestran «A su criterio» con la nota «El sistema no lo bloquea al
    crear la cuota», en vez de «No». El resto de las reglas sigue siendo norma.
    En WF resolución el cupo sigue siendo norma.
  - **Alcance del modal en la nota de apoyo.** Solo compara con las demás
    prestaciones del funcionario. Saldo, contrato, DU09 y deudas se validan en
    el formulario o en la pantalla de la cuota. Así, «Sin observaciones» no se
    lee como que todo está bien.

- **05-11-2026.** Revisión con el caso N° 210 (9010.8, fijo, con extensión,
  cuota 1 de 1). Se corrigió:
  - **De dónde sale la extensión.** En WF pagos se usa la de la resolución
    (`ext_cuotas`, congelada); en WF resolución, la del formulario. Antes, el
    tope mensual y el cupo leían la del centro de costo, que en pagos no venía,
    y el modal decía «no cumple tope mensual» y «1 de 2 meses» para una
    prestación exenta con cupo de 12. Ahora todas las reglas leen la misma.
  - **Cupo con extensión.** Es propio de la prestación: cuenta sus demás
    cuotas creadas. Antes decía «quedan 0 de 12 usados» sin contar la propia.
  - **Cupo sin extensión.** En WF pagos se suman las demás cuotas creadas de
    la misma prestación, que antes no se contaban porque el historial la
    excluye. No se proyectan cuotas futuras, porque lo declarado ya se contó al
    aprobar.
  - **Tope en la pregunta 1.** Con extensión la columna dice «exento de tope
    por extensión».
  - **Pregunta 3 sin las cuotas de la prestación.** Ya no cuenta la propia
    cuota como «por crear»; dice que no se pudieron cargar las demás.
  - **56 h en WF pagos.** La pantalla ahora pasa las horas del contrato
    vigente y si la ejecución es dentro de jornada. Antes mostraba «0 h de
    contrato» y sumaba las horas propias aunque fuera dentro de jornada.

  Criterios confirmados contra el código:
  - **Fijo:** aporta al mes el total dividido por los meses de ejecución.
  - **Variable:** aporta el total dividido por el menor entre las cuotas y los
    meses.
  - **Tope en WF pagos:** es por cuota, la suma de sus meses contra
    `mto_tope`, igual que `sg_fumeuSecgen02`, y exento con extensión.

- **04-11-2026 (cierre).** Lo rechazado se informa sin contar:
  - PA nuevo `sg_fupssSecgen19`, aparte del historial de las reglas;
  - endpoint de DGDP `.../staff-previous-provisions/{rut}/rejections`;
  - `rejections` en el contexto de la cuota de WF pagos;
  - sección «Rechazos y devoluciones» en el modal.

  «Mes ya tomado» deja de contar los meses rechazados, en el frontend y en el
  servidor.

- **04-11-2026 (noche).** El modal pasa a hablar como apoyo al criterio de quien
  revisa:
  - nota fija;
  - «Sin observaciones» o «N puntos a revisar»;
  - tercer estado «Por confirmar» cuando falta un horario;
  - «Qué lo resolvería» y meses libres sugeridos;
  - avisos como «Para su criterio»;
  - fecha del dato.

  Se agregó el estado de los meses, las cuotas y los pagos en las tres
  preguntas. En WF resolución el formulario lee el historial una vez sin
  excluir la solicitud y separa la propia prestación (`currentProvision`), igual
  que WF pagos. No se modificaron procedimientos.

- **04-11-2026 (tarde).** La vista se ordenó en preguntas: comprometer los
  meses, cuotas para el pago y, en WF pagos, pagar la cuota. Las validaciones se
  muestran bajo la pregunta que responden. La tabla de centros de costo pasó al
  respaldo, abierta desde el inicio. El contexto de WF pagos ahora trae la
  prestación de la cuota (`currentProvision`). No se modificaron procedimientos.
- **04-11-2026.** Se reemplazó el modal anterior. Tenía pestañas cuyas
  etiquetas cambiaban al hacer clic, una tabla comparativa de campos y un bloque
  de «integridad de los datos» con avisos falsos para el modelo de meses. El
  nuevo responde primero si se puede continuar. Las reglas se acotaron por centro
  de costo según las decisiones del 03-11-2026. Al probarlo apareció y se corrigió
  un desajuste en el formato de los meses (`AAAA-MM` frente a `AAAA-M`).
- **03-11-2026.** Decisiones de negocio: el tope y el cupo de meses de pago son
  por centro de costo; el tope se congela al pedir la resolución; las licencias y
  el receso se tratan en WF pagos con marcaje y documento explícito.
