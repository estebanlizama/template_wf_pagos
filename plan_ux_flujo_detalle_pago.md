# Plan UX/UI — flujo guiado del detalle de pago

**Fecha:** 05-10-2026  
**Revisión:** 2 — jerarquía de acciones, iconos, etiquetas, modales y espaciado  
**Ruta:** `/prestacion-de-servicios/pagos/:nroSolici`  
**Estado:** propuesta para revisión; no implementada  
**Alcance:** frontend Nuxt 2/Vue 2. No requiere cambios de base de datos, PA ni contratos API.

## 1. Objetivo

Ordenar la gestión de pago como una secuencia natural de trabajo, sin numerar pasos ni utilizar un
*stepper* artificial. El usuario debe poder entender siempre:

- qué información ya está lista;
- qué mes está revisando;
- qué acción está realizando;
- qué falta para guardar una cuota;
- qué impide enviarla a validación.

La pantalla no debe desplazar al usuario hacia editores que aparecen lejos del botón presionado ni
crear varias secciones abiertas simultáneamente.

## 2. Diagnóstico de la vista actual

### Hallazgos principales

| Hallazgo | Efecto en el usuario |
| :--- | :--- |
| «Editar compensación» abre otra sección debajo de la tabla | se pierde la relación entre el mes seleccionado y el editor |
| «Cerrar edición» solo oculta la sección | no expresa una tarea ni ayuda a completar el pago |
| El formulario de cuota aparece después de la lista de cuotas | el usuario debe desplazarse y buscar dónde ocurrió la acción |
| «Guardar como borrador» existe dentro del formulario y nuevamente en el pie | dos acciones equivalentes compiten entre sí |
| Meses, compensación y cuotas pueden quedar abiertos al mismo tiempo | aumenta la altura y se pierde el foco de la tarea activa |
| La acción final está lejos de la cuota que se enviará | cuesta reconocer qué borrador será enviado |
| Con hasta 12 meses, las listas crecen verticalmente | el resumen, el formulario y las acciones pueden quedar separados por varias pantallas |
| Los errores técnicos y de negocio no siempre permanecen junto al contexto que los produjo | obliga a buscar el problema después de una operación |

### Lo que se conserva

- La pestaña principal «Gestión de pago» y la pestaña «Antecedentes».
- El resumen de la prestación y el selector de funcionario.
- Los estados reales de mes y cuota.
- El contraste entre compensación comprometida y realizada.
- El calendario y el registro por tramos.
- La lista de cuotas y su formulario de borrador.
- Los tags normativos y la revalidación antes de enviar.
- El modal final con resumen y destinatario.

## 3. Principio de interacción aprobado para la propuesta

Se utilizará un patrón **lista + área de trabajo contextual**.

- La lista conserva el contexto general.
- Solo existe una tarea de edición activa a la vez.
- El área de trabajo cambia de contenido sin agregar una nueva sección distante.
- Las acciones pertenecen al bloque que modifican.
- La acción de envío permanece al final como cierre del flujo.
- No se muestran números de paso, círculos numerados ni porcentaje de avance.

La orientación se comunica mediante estados breves:

```text
Meses preparados     Compensación pendiente     Cuota en borrador     Validación pendiente
```

Estos estados son informativos y se derivan de los datos; no funcionan como navegación obligatoria.

## 4. Arquitectura visual propuesta

```text
Encabezado de la prestación
  Resolución · Centro de costo · Actividad

Prestación seleccionada
  Funcionario · monto · tope · cuotas solicitadas · cuotas restantes

Preparación del pago
┌───────────────────────────────┬────────────────────────────────────────┐
│ Meses de ejecución            │ Área de trabajo del mes seleccionado   │
│                               │                                        │
│ Sep 2026  Disponible          │ Compensación de septiembre 2026        │
│ Oct 2026  Pendiente           │ Comprometido · Informado · Diferencia  │
│ Nov 2026  Compensación lista  │ Calendario + detalle del día           │
│ ... hasta 12 meses            │                                        │
└───────────────────────────────┴────────────────────────────────────────┘

Cuotas de pago
┌───────────────────────────────┬────────────────────────────────────────┐
│ Cuotas registradas            │ Compositor de la cuota activa          │
│                               │                                        │
│ Cuota 1 · Borrador            │ Mes de pago                            │
│ Cuota 2 · En visación         │ Meses incluidos                        │
│                               │ Resumen y Guardar borrador             │
└───────────────────────────────┴────────────────────────────────────────┘

Validaciones normativas
  Tags vigentes · motivo bloqueante visible

Acción de cierre
  Cuota seleccionada · [Enviar a validación]
```

Cuando no hay una tarea activa, el panel derecho explica la acción disponible en vez de quedar
vacío. Ejemplo: «Seleccione un mes para revisar su compensación».

### 4.1 Jerarquía de información

La pantalla se recorre de arriba hacia abajo con este orden visual:

1. Identidad de la prestación y estado general.
2. Resumen útil para decidir: funcionario, monto autorizado, cuotas solicitadas/restantes y período.
3. Preparación de meses y compensaciones.
4. Creación o revisión de la cuota.
5. Validaciones vigentes.
6. Envío de la cuota seleccionada.

La numeración anterior documenta la prioridad y no se muestra como pasos en la interfaz. Una sección
no repite datos ya visibles en la anterior salvo el resumen mínimo necesario para mantener contexto.

Cada sección utiliza la misma anatomía:

```text
Título + estado resumido                         utilidades por icono
Descripción breve, solo si evita una duda
Contenido principal
Error o estado vacío en la misma posición
Pie estable con la acción principal, solo cuando existe una edición
```

- Separación entre secciones: 24 px.
- Separación entre título y contenido: 16 px.
- Separación entre campos o acciones relacionadas: 8 px.
- El fondo permanece blanco; bordes y espaciado construyen la agrupación.
- No se crean tarjetas internas para cada dato ni fondos grises decorativos.
- El elemento activo usa borde y resplandor primario, no un badge ni un relleno de color.

### 4.2 Regla para botones, iconos y menús

Los iconos se utilizan para reducir ruido, pero no reemplazan acciones cuyo significado o efecto
debe quedar explícito.

| Tipo de acción | Representación | Ubicación |
| :--- | :--- | :--- |
| Guardar borrador | botón con texto e icono opcional | pie estable del compositor |
| Enviar a validación | botón con texto e icono opcional | pie final de la página |
| Registrar un tramo | botón con texto | pie del formulario del día |
| Seleccionar/revisar un mes | icono `+`, lápiz u ojo según estado | columna de acciones de la fila |
| Continuar/ver una cuota | icono lápiz u ojo | columna de acciones de la fila |
| Eliminar un registro permitido | icono papelera de peligro | junto al registro afectado |
| Volver a consultar validaciones | icono actualizar | encabezado de Validaciones |
| Acciones secundarias poco frecuentes | menú de tres puntos | extremo derecho de la fila |

Reglas obligatorias:

- Todos los controles, incluidos los de solo icono, miden 40 × 40 px.
- Un botón de icono tiene `title`, `aria-label`, foco visible y tooltip con verbo + objeto, por
  ejemplo «Revisar compensación de septiembre».
- La columna de acciones conserva posición y ancho para que los iconos no se desplacen entre filas.
- El orden es estable: acción principal de fila, ver/revisar y, al final, eliminar o menú adicional.
- No se muestran más de tres iconos juntos; las acciones restantes pasan al menú contextual.
- El icono nunca es el único indicador de un estado. El estado se lee en su etiqueta independiente.
- Guardar, enviar y confirmar una acción destructiva nunca quedan como icono aislado.
- Durante una operación, el control se deshabilita, conserva su ancho y muestra un spinner.
- No se usa una `X` grande para «Cerrar edición». El usuario cambia de contexto seleccionando otro
  elemento; en móvil puede existir un icono «Volver a la lista» si el panel ocupa toda la vista.

### 4.3 Reglas para etiquetas de estado

Las etiquetas representan estados reales; no se utilizan como botones, títulos ni decoración.

- Texto breve, en formato oración y preferentemente entre 7 y 25 caracteres.
- Una misma condición siempre utiliza el mismo texto, color e icono.
- El detalle extenso se muestra debajo, en tooltip accesible o en el panel de detalle.
- Los colores se reservan para semántica: éxito, advertencia, error, información o estado neutro.
- La selección o edición activa no se comunica con una etiqueta de advertencia.
- Si coinciden estados, la prioridad visual es: bloqueo/error, advertencia, selección, válido.
- Toda etiqueta mantiene texto o icono semántico; el color nunca es la única señal.

Vocabulario inicial para pagos:

| Contexto | Etiquetas admitidas |
| :--- | :--- |
| Mes | Disponible, En cuota, No disponible |
| Compensación | No requerida, Pendiente, Parcial, Completa, Cerrada |
| Cuota | Propuesta, Observada, En validación, Aprobada, Rechazada |
| Validación | Vigente, Advertencia, Bloqueante, No disponible |

No se mostrarán frases completas dentro de una etiqueta. Por ejemplo, se utilizará «2 bloqueantes»
y el detalle explicará cuáles son, en vez de «No disponible para enviar por 2 incidencias
bloqueantes».

### 4.4 Uso de modales

Los editores extensos de compensación y cuota no se presentan en modal. Permanecen en el área de
trabajo porque requieren consultar antecedentes, comparar datos y manejar listas de hasta 12 meses.

Los modales quedan limitados a decisiones acotadas:

- confirmar eliminación de un tramo o una cuota;
- advertir que se perderán cambios sin guardar al cambiar de contexto;
- confirmar el envío mostrando cuota, meses, monto, resultado de validaciones y destinatario;
- presentar, solo si el detalle no cabe en la sección, información técnica o trazabilidad secundaria.

Todo modal utiliza `modal-class="pds-ui-modal"` y `body-class="pds-ui-modal-body"`, título de 16 px,
cuerpo con scroll interno, footer real y botones de 40 px. «Cancelar» queda a la izquierda y la acción
confirmatoria a la derecha. Al cerrar con botón, `Esc` o cancelación, el foco vuelve al control que lo
abrió. Mientras una operación irreversible está en curso no se permite un segundo envío ni el cierre
accidental.

## 5. Meses y compensación

### Lista de meses

La tabla se transforma en un navegador compacto de meses dentro de la misma sección. Cada fila o
tarjeta muestra:

- mes y año;
- estado del mes;
- monto;
- estado de compensación: No requerida, Pendiente, Parcial, Completa o Cerrada;
- cuota asociada, si existe;
- una acción contextual por icono en una columna estable.

Estado y acción contextual:

| Situación | Etiqueta | Control |
| :--- | :--- | :--- |
| No existe diferencia que compensar | **No requerida** | sin acción de edición |
| Existe diferencia y no hay tramos registrados | **Pendiente** | icono `+`, «Registrar compensación» |
| Existe diferencia y hay cobertura incompleta | **Parcial** | icono lápiz, «Continuar compensación» |
| La diferencia está cubierta y aún admite cambios | **Completa** | icono lápiz, «Revisar compensación» |
| El mes ya no admite cambios | **Cerrada** | icono ojo, «Ver compensación» |

Se elimina el botón textual repetido «Editar compensación». La etiqueta describe la condición y el
icono realiza la acción; su tooltip siempre incluye el mes para evitar ambigüedad.

### Área de trabajo de compensación

- En escritorio aparece a la derecha de la lista, sin desplazar el resto de la página.
- Cambiar de mes actualiza el panel derecho.
- Se elimina «Cerrar edición».
- El usuario sale del contexto seleccionando otro mes, una cuota o continuando con el flujo.
- Si existe un tramo sin guardar, cambiar de contexto muestra confirmación de descarte.
- Después de guardar o eliminar un tramo, el mismo mes permanece activo y se actualizan sus totales.
- El foco vuelve al control que inició la operación cuando corresponde.

Orden interno:

1. Resumen: comprometido, informado y diferencia.
2. Contraste de tramos comprometidos y realizados.
3. Calendario.
4. Detalle del día y formulario de nuevo tramo.

La numeración anterior solo describe el orden documental; no se presenta en pantalla.

### Acciones de compensación

- **Agregar tramo:** única acción principal del formulario del día.
- **Usar horas comprometidas:** utilidad secundaria junto a los campos que completa; puede ser icono
  si el tooltip explica «Usar horario comprometido».
- **Cargar compromiso completo:** utilidad por icono en el encabezado del contraste, visible solo
  cuando existe una diferencia y no reemplaza datos ya registrados sin confirmación.
- **Eliminar tramo:** papelera de peligro junto al tramo afectado, con nombre accesible y modal de
  confirmación que identifica fecha y horario.
- No existe un botón general «Guardar compensación»: cada tramo se persiste al registrarlo.

## 6. Cuotas de pago

### Lista y compositor en una sola sección

La lista queda a la izquierda y el compositor de la cuota activa a la derecha. Así «Nueva cuota» o
una acción de una cuota existente cambia el panel contiguo y no crea otra sección más abajo.

Estados y acciones:

| Estado | Etiqueta | Control de fila |
| :--- | :--- | :--- |
| Propuesta | **Propuesta** | icono lápiz, «Continuar borrador» |
| Observada | **Observada** | icono lápiz, «Corregir cuota» |
| En validación o posterior | estado real | icono ojo, «Ver cuota» |
| Sin cuotas y con meses disponibles | estado vacío explicativo | botón textual **Crear cuota** |

«Eliminar» se conserva como papelera de peligro únicamente para Propuesta y abre confirmación. Si la
fila supera tres acciones, se agrupa en un menú accesible; en móvil las acciones secundarias siempre
se agrupan para no competir con Crear, Guardar o Enviar.

### Un solo lugar para guardar

- **Guardar borrador** vive exclusivamente en el pie del compositor.
- Se elimina «Guardar como borrador» de la barra final de la página.
- Guardar no cierra ni desplaza el compositor.
- Tras guardar se muestra confirmación dentro de la sección y se actualiza la lista.
- El título cambia entre «Crear cuota», «Continuar borrador», «Corregir cuota» y «Detalle de cuota».
- La lectura reutiliza la misma estructura, con controles deshabilitados o valores de lectura.

### Manejo de hasta 12 meses

Doce meses no requieren paginación ni virtualización, pero sí un contenedor controlado:

- orden cronológico permanente;
- encabezado o resumen de selección visible mientras se desplaza la lista;
- altura máxima ligada al viewport, con desplazamiento interno solo en la lista de meses;
- cada mes conserva estado, monto, descuentos y razón de indisponibilidad;
- controles de al menos 40 px;
- selección múltiple accesible con teclado;
- en móvil, una tarjeta por mes con checkbox y monto debajo;
- meses no disponibles permanecen visibles y explican por qué no pueden seleccionarse.

El resumen de meses seleccionados no puede asumir que forman un rango continuo:

- si son contiguos: «Marzo – Junio 2026»;
- si no son contiguos: lista de meses o «6 meses seleccionados» con el detalle completo visible;
- nunca se representa una selección discontinua únicamente con el primer y último mes.

El resumen persistente del compositor muestra:

```text
Meses seleccionados     Total solicitado     Descuentos     Total a pagar
6                       $900.000              −$50.000       $850.000
```

## 7. Validaciones y envío

- Los tags normativos permanecen después de las cuotas.
- El panel muestra un resumen corto: «Listo para enviar» o «Requiere revisión».
- El encabezado incluye un icono de actualización «Volver a consultar validaciones» y la hora de la
  última consulta. No se agrega un botón grande dentro del contenido.
- Al volver a consultar, el icono gira o muestra spinner, queda deshabilitado y no transforma el
  estado anterior en válido mientras la respuesta está pendiente.
- El detalle completo continúa fuera de la etiqueta, en texto asociado, tooltip accesible o detalle
  desplegable. La etiqueta solo contiene estado o contador breve.
- La acción actualiza todas las fuentes en tiempo real definidas para resolución: inhabilidades,
  parentesco, tope, carga semanal y demás validaciones normativas aplicables. Los datos históricos
  inmutables no se consultan nuevamente sin necesidad.
- La validación de saldo mantiene el TODO temporal y no bloquea.
- La acción final contiene solo la selección de cuota, el motivo bloqueante y **Enviar a
  validación**.
- Si existe una sola cuota enviable, no se muestra selector.
- Si existen varias, el selector muestra número, meses y monto, no solo «Cuota N».
- El botón de envío no comparte el pie con acciones de edición o guardado.
- Al intentar enviar se lleva el foco al primer bloqueo y se conserva el contexto actual.
- El envío siempre ejecuta una revalidación completa aunque la consulta manual sea reciente. El
  estado mostrado en pantalla orienta, pero no autoriza por sí solo el envío.

## 8. Comportamiento responsive

### 1366 px

- Lista de meses: 320–360 px.
- Área de compensación: espacio restante.
- Lista de cuotas: 320–360 px.
- Compositor: espacio restante.
- Resumen de totales en cuatro columnas.

### 1024 px

- Patrón de dos columnas más estrecho, sin truncar montos ni acciones.
- Calendario y detalle del día pueden apilarse dentro del panel derecho.
- Acciones de fila mantienen una sola etiqueta principal.

### 768 px

- Lista y área de trabajo se apilan.
- El mes/cuota activo queda en un encabezado contextual fijo dentro de la sección.
- La lista puede contraerse a un selector de elemento activo más un resumen de estados.
- No hay desplazamiento horizontal de página.

### 375 px

- Tarjetas de mes y cuota en una columna.
- Acciones principales a ancho completo.
- Acciones secundarias en una segunda fila o menú accesible.
- Calendario dentro de un contenedor con desplazamiento horizontal controlado si no caben siete
  columnas con objetivos táctiles válidos.
- Totales y campos se apilan conservando el mismo orden semántico.
- El pie de envío no tapa contenido ni controles del sistema.

## 9. Manejo de estados y errores

| Estado | Presentación |
| :--- | :--- |
| Cargando página | carga principal existente |
| Cargando compensación | esqueleto dentro del área de trabajo; la lista permanece visible |
| Cargando cuota | esqueleto dentro del compositor |
| Sin meses | estado vacío con explicación y sin acciones imposibles |
| Sin compensación requerida | etiqueta «No requerida»; no se abre editor |
| Sin tramos informados | explicación + «Registrar tramo» |
| Error de campo | debajo del campo, con `aria-invalid` y `aria-describedby` |
| Error de sección | dentro del área activa, sin desplazar a otra sección |
| Error técnico | toast breve; los datos ingresados se conservan |
| Múltiples errores de envío | resumen superior y foco al primer bloqueo |
| Guardado exitoso | confirmación no intrusiva dentro de la sección y actualización de estado |
| Solo lectura | misma composición, sin controles mutables |

Ningún error debe cerrar el editor, limpiar los meses seleccionados ni perder horas ingresadas.

## 10. Estado de interfaz y navegación

La página mantiene un único contexto explícito:

```js
activeWorkspace: null | 'compensation' | 'installment'
activeMonthSequence: number | null
activeInstallmentNumber: number | null
hasUnsavedChanges: boolean
```

Reglas:

- abrir compensación desactiva el compositor de cuota;
- abrir una cuota desactiva el editor de compensación;
- si hay cambios sin guardar, se confirma antes de cambiar;
- la URL puede conservar `funcionario` y añadir opcionalmente `mes` o `cuota` para restaurar el
  contexto al recargar, sin convertir esos parámetros en fuente de autorización;
- el componente padre coordina el contexto; los hijos siguen emitiendo eventos y no realizan
  navegación ni consultas por su cuenta.

## 11. Componentes afectados

| Componente | Cambio propuesto |
| :--- | :--- |
| Página `_nroSolici/index.vue` | coordinar área activa, cambios sin guardar, foco y acción final |
| `Du288PaymentMonthsSection.vue` | convertir tabla aislada en navegador de meses + ranura/panel contextual |
| `Du288ExecutedCompensationSection.vue` | eliminar «Cerrar edición» y adaptarse a modo embebido/lectura |
| `Du288InstallmentsSection.vue` | lista navegable con acciones según estado y panel contiguo |
| `Du288InstallmentFormSection.vue` | compositor persistente, un solo guardado y soporte visual de 12 meses |
| `Du288PaymentValidationsSection.vue` | añadir resumen breve y foco del primer bloqueo |
| Modal de envío existente | aplicar estructura común, resumen vigente, destinatario y bloqueo de doble envío |
| `lang/es/pds.js` | centralizar nuevos verbos, estados vacíos, confirmaciones y errores |
| `pds-du288.css` o estilos locales | usar únicamente tokens y patrones DU288 existentes |

No se modifica `dna/BaseTable` por una necesidad exclusiva de pagos. Si el patrón maestro-detalle no
se puede componer con la tabla actual, se crea un componente local `Du288PaymentWorkspace`.

## 12. Accesibilidad

- Navegación completa por teclado entre lista y área de trabajo.
- `aria-current` o estado seleccionado explícito para mes/cuota activa.
- Foco visible usando el patrón DU288 de borde y resplandor, sin relleno semántico.
- Al cambiar de elemento, anunciar título y estado del área de trabajo mediante región viva breve.
- Botones de icono con `title` y `aria-label`.
- Eliminar se identifica por forma, nombre accesible, tooltip y confirmación; no depende solo del
  color rojo.
- Al guardar, el foco permanece en el contexto; al cancelar un diálogo vuelve al disparador.
- Respeto de `prefers-reduced-motion`; el flujo no depende del desplazamiento animado.

## 13. Fases de implementación

### Base de navegación

- Incorporar el estado de área activa.
- Crear el contenedor maestro-detalle local.
- Evitar que compensación y cuota estén abiertas simultáneamente.
- Agregar protección ante cambios sin guardar.
- Consolidar posiciones, tamaños y orden de iconos de acción.
- Aplicar espaciado y anatomía común a todas las secciones.

### Meses y compensación

- Rediseñar la lista de meses.
- Integrar el editor en el panel contextual.
- Sustituir «Editar compensación» por verbos según estado.
- Eliminar «Cerrar edición».
- Mantener foco, errores y actualización del mes activo.

### Cuotas

- Integrar lista y compositor.
- Cambiar acciones a Crear, Continuar, Corregir y Ver.
- Dejar un único «Guardar borrador».
- Implementar resumen persistente y selección de hasta 12 meses.
- Representar correctamente selecciones discontinuas.

### Validación y cierre

- Simplificar la barra final.
- Incorporar actualización manual por icono, fecha de última consulta y estado de carga explícito.
- Normalizar textos, colores, iconos y longitud de las etiquetas.
- Mejorar la selección cuando existen varios borradores.
- Enfocar el primer bloqueo al enviar.
- Ajustar confirmaciones y envío al patrón de modal DU288.
- Conservar el TODO de saldo no bloqueante.

### Verificación UX/UI

- ESLint, pruebas PDS, `lint:du288-ui` y build.
- Pruebas con 1, 6 y 12 meses.
- Pruebas con compensación no requerida, vacía, parcial y completa.
- Pruebas con cuota nueva, propuesta, observada y solo lectura.
- Pruebas con una y varias cuotas enviables.
- Pruebas de error de carga, guardado y envío conservando los datos.
- Revisión visual y teclado en 1366, 1024, 768 y 375 px.

## 14. Criterios de aceptación

- Presionar una acción de mes o cuota no obliga a buscar un editor en otra parte de la página.
- Solo hay una tarea editable activa.
- No existe «Cerrar edición» en compensación.
- No existe un guardado de cuota duplicado.
- Cada grupo tiene una sola acción principal.
- Las acciones repetitivas de fila usan iconos de 40 × 40 px en una columna estable, con tooltip,
  `title`, `aria-label` y foco visible.
- Guardar, enviar y confirmar eliminaciones conservan una etiqueta verbal explícita.
- Ningún grupo presenta más de tres iconos sueltos; el excedente utiliza menú contextual accesible.
- Las etiquetas solo representan estados reales, usan vocabulario y color consistente y no contienen
  explicaciones extensas.
- «No requerida», «Pendiente», «Parcial», «Completa» y «Cerrada» determinan de forma inequívoca si
  una compensación puede registrarse, revisarse o solo verse.
- Los editores de compensación y cuota no se abren en modal; los modales quedan limitados a
  confirmaciones, descarte de cambios, envío y detalle secundario.
- «Volver a consultar validaciones» está en el encabezado como icono y muestra carga y fecha de
  actualización sin asumir éxito durante la consulta.
- Una cuota puede manejar 12 meses sin alargar descontroladamente la página.
- Las selecciones de meses discontinuas nunca se presentan como un rango continuo.
- En móvil no existe scroll horizontal de página.
- Los errores permanecen junto a la tarea y no borran lo ingresado.
- Guardar borrador y enviar a validación mantienen sus reglas distintas.
- Todos los textos provienen del catálogo y todos los controles cumplen tamaño, foco y accesibilidad
  del estándar DU288.

## 15. Decisiones funcionales que no cambia este plan

- La compensación realizada sigue guardándose por tramo.
- Guardar borrador no compromete los meses.
- Enviar compromete la cuota y sus meses.
- Solo se envía una cuota por operación.
- Las validaciones normativas se vuelven a consultar antes del envío.
- «Centro de costo sin saldo» continúa como TODO informativo no bloqueante hasta habilitar la fuente
  financiera definitiva.
