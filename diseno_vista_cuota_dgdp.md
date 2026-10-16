# Vista DGDP de una cuota — organización propuesta

**Fecha:** 15-10-2026
**Estado:** propuesta, sin implementar. Reemplaza al bloque «Ejecución mes a
mes» agregado el mismo día, cuyo contenido se absorbe dentro de cada mes.

---

## 1. La idea que ordena todo

La vista revisa **una cuota**. Una cuota es un conjunto de **meses de
ejecución** que se pagan juntos en una remuneración. Entonces la pantalla tiene
dos niveles y solo dos:

```
CUOTA  ─ resumen de lo solicitado, igual que lo vio el solicitante antes de enviar
  └── MES ─ card con su propio resumen, que se despliega al detalle del mes
```

Todo lo que hoy vive en secciones paralelas —calendario, compensación,
descuentos, asistencia— es **detalle de un mes**, no de la cuota. Mientras esté
en secciones separadas, el revisor tiene que cruzar a mano qué día de qué
sección corresponde a qué mes.

### Lo que se elimina como sección propia

| Sección actual | A dónde va |
| :--- | :--- |
| Ejecución mes a mes | dentro de cada card de mes |
| Ejecución comprometida y calendario | el calendario del mes, dentro de su card |
| Meses incluidos en la cuota (tabla) | se convierte en las cards |
| Ausencias del período | se mantiene aparte: es del período, no de un mes |

---

## 2. Nivel 1 — Resumen de la cuota

El mismo lenguaje que el solicitante vio antes de enviar
(`Du288InstallmentFormSection`), para que revisor y solicitante discutan sobre
la misma pantalla:

```
Cuota 1 de 2                                        [En visación]
Total de la cuota   $255.296      4 meses · Enero 2016 – Abril 2016
Total descuentos    −$46.643      A pagar   $208.653
Mes de pago         Agosto 2026   Tiempo en espera   1 día
```

Debajo, la franja de límites que el solicitante también veía —tope por cuota,
saldo autorizado, saldo después de esta cuota— y los mensajes de estado en el
orden del §5.4: error, advertencia, información.

---

## 3. Nivel 2 — Cards de mes

Una card por mes de la cuota. **Cerrada** muestra lo que decide:

```
┌───────────────────────────────────────────────────────┐
│ Enero 2016                              Comprometida  │
│ Solicitado   $74.074    Descuentos  −$46.643          │
│ A pagar      $27.431                                  │
│ [Compensación: parcial]  [Licencia médica]  [2 cambios]│
│                                            Ver detalle │
└───────────────────────────────────────────────────────┘
```

**Abierta**, el desglose del mes. Acá están las tres variantes.

### Variante A — Acordeón por bloques *(recomendada)*

La card se expande hacia abajo con los bloques uno tras otro:

1. **Compensación** — comprometida frente a informada, con los días del mes y
   las tres marcas (comprometido · informado · reloj). Clic en un día abre su
   detalle: horas, turno, exceso, ausencia, justificación.
2. **Descuentos** — licencia médica y permiso sin goce, **editables** detrás de
   *Editar descuentos*, con el neto recalculando al escribir.
3. **Cambios de monto** — el historial de `sg_fum2`, con su fecha de gestión.
4. **Marcas de auditoría** — las cuatro `val_*` del mes.

**A favor:** todo visible sin más clics, se imprime y se lee entero.
**En contra:** un mes con muchos días deja la card larga.

### Variante B — Card con pestañas internas

La card se expande a un panel con pestañas: *Compensación · Descuentos ·
Asistencia · Cambios*.

**A favor:** altura constante, aguanta meses con mucho detalle.
**En contra:** esconde información detrás de un clic; el revisor puede aprobar
sin haber abierto la pestaña que importaba.

### Variante C — Lista compacta y panel lateral

Se mantiene una lista densa de meses y al seleccionar uno se abre a la derecha
el panel con todo su detalle.

**A favor:** comparar meses entre sí es inmediato; es lo más cerca de lo que
hay hoy, por lo tanto el cambio más barato.
**En contra:** en pantallas angostas el panel cae debajo y se pierde la ventaja.

### Recomendación

**A**, por una razón de fondo: el revisor debe *mirar* cada mes antes de
aprobar la cuota. B y C permiten decidir sin haber abierto el detalle. A obliga
a pasar por delante de la información, que es lo que una revisión necesita.

---

## 4. Qué se puede editar, y qué falta para poder

Es la parte que condiciona el alcance.

| Dato | ¿Editable hoy por DGDP? | Qué falta |
| :--- | :--- | :--- |
| Descuento por licencia médica | **sí** | — |
| Descuento por permiso sin goce | **sí** | — |
| Compensación registrada por el funcionario | **no** | PA de escritura + endpoint + permiso |
| Monto del mes | **no** | `sg_fumeuSecgen02` valida contra el solicitante, no contra DGDP |
| Excluir un mes de la cuota | **no** | uno de los ocho PA de DGDP que faltan |

Lo pedido —«editar la información registrada por el funcionario»— cae en la
segunda fila: hoy **no existe** forma de que DGDP toque una compensación. La
card puede mostrarla y dejar el lugar de la acción, pero la escritura es
trabajo de base de datos, no de pantalla, y conviene decidirlo antes de diseñar
el control.

Dos caminos, y hay que elegir uno:

1. **DGDP corrige directamente.** Rápido para el revisor, pero borra el rastro
   de qué declaró el funcionario. Exigiría versionar la compensación como se
   hizo con los montos en `sg_fum2`.
2. **DGDP observa y el solicitante corrige.** Es el flujo que ya existe —la
   cuota vuelve devuelta— y no necesita PA nuevo. Más lento, pero cada dato lo
   escribe quien responde por él.

---

## 5. Orden final de la pantalla

```
1  Antecedentes de la prestación      (4 bloques, ya hecho)
2  Resumen de la cuota                (nivel 1)
3  Meses de la cuota                  (cards, nivel 2)
4  Ausencias del período              (general, se mantiene)
5  Validaciones normativas
6  Dictamen
```

Las pestañas *Documento de respaldo* y *Documento de resolución* no cambian.

---

## 6. Antes de implementar hay que cerrar

1. **Qué variante**: A, B o C.
2. **Qué pasa con la edición de compensaciones**: camino 1 o camino 2 del §4.
3. **Si el calendario del mes va dentro de la card** o se mantiene un
   calendario único arriba. Dentro es más coherente; repetir doce calendarios
   en una cuota larga puede pesar.

---

## 7. Desglose de las validaciones — agregado el 15-10-2026

Hoy el panel normativo son nueve chips con un tooltip. Un chip verde dice *que*
el control pasó, no *con qué datos* pasó, y el revisor no puede comprobar nada:
tiene que creerle a la etiqueta. Cada validación pasa a tener su tabla.

| Validación | Tabla | Origen (ya se consulta) |
| :--- | :--- | :--- |
| Contrato | ficha, cargo, unidad, calidad, jerarquía, grado, horas, vigencia | `normative/staff-profile/{rut}` |
| Asignaciones | designación, cargo, unidad, vigencia, horas, habilitado, motivo | `normative/staff-assignments/{rut}` |
| Parentesco | relación, grado, si exige constancia | `normative/check-relationship` |
| Tope del cargo | tope del cargo vigente, tope congelado en la resolución, diferencia | `normative/staff-position-cap` |
| Saldo del centro de costo | ítem, solicitado, saldo inicial, remanente, estado, mensaje | `normative/cost-center-balance-validation` |
| Centro de costo | código, nombre, unidad ejecutora, financiamiento, flujo DU288, régimen | `sg_fupssSecgen18` vía el resumen |
| Carga semanal | prestaciones concurrentes, horas de cada una, total, tope | prestaciones previas + horarios |

**Una tabla vacía también informa.** Si el funcionario no tiene asignaciones
vigentes, la tabla se muestra con su leyenda —«sin asignaciones vigentes»— en
vez de desaparecer: que no haya nada es parte de lo que el revisor comprueba, y
una sección ausente se confunde con una que no cargó.

### 7.1 Lo que hay que cambiar para poder mostrarlas

`revalidateNormative` **consulta las cinco fuentes y descarta los payloads**:
arma los chips con ellos y solo guarda el saldo del centro de costo. Las tablas
no necesitan consultas nuevas, necesitan que el store **conserve lo que ya
trajo**:

```js
commit('SET_NORMATIVE_SOURCES', { profile, assignments, relationship, cap, balance, workload })
```

Con eso las dos vistas pueden desglosar sin pedir nada otra vez.

### 7.2 Dónde van

Debajo de cada chip, desplegable. El panel conserva su lectura rápida —nueve
chips, los bloqueantes primero— y el desglose queda a un clic del chip que
corresponde, no en una sección aparte que obligue a buscar.

---

## 8. Decisiones tomadas para implementar

Tres preguntas quedaron abiertas en §6. Se avanza con estos valores, que son
reversibles:

| Pregunta | Decisión | Por qué |
| :--- | :--- | :--- |
| Variante de card | **A**, acordeón | obliga a pasar por delante del detalle antes de aprobar |
| Edición de compensaciones | **camino 2**: DGDP observa, el solicitante corrige | el camino 1 necesita PA, endpoint, permiso y versionado que hoy no existen; el 2 ya funciona |
| Calendario dentro de la card | **no**: lista de días, no rejilla | doce rejillas en una cuota larga pesan; la lista da lo mismo en una línea por día |

La card muestra la compensación registrada **en modo lectura**, con el detalle
de días. Si algo está mal, el camino es observar la cuota. El día que exista el
PA de escritura, el control entra en esa misma card sin mover nada más.

---

## 9. Aplicado — 15-10-2026

Variante **A**, camino **2** para la edición, lista de días en vez de rejilla.

### 9.1 Cards de mes

`Du288PaymentMonthsReviewSection` deja de ser una tabla. Una card por mes:

| Cerrada | Abierta |
| :--- | :--- |
| período · estado · solicitado · descuentos · a pagar | **Compensación del mes**: los días comprometidos e informados, con las tres marcas (C · I · R) |
| chips de marcas de auditoría, días con compensación y cambios de monto | **Descuentos**: los dos campos, editables solo con el modo edición abierto |

Los días salen de agrupar `committed` y `executed` por `monthSequence` —el
modelo de compensación ya trae `corr_fume`—, así que no hizo falta ninguna
consulta nueva. Un día comprometido y no informado **aparece igual**, con la
marca apagada: es justamente lo que el revisor busca.

### 9.2 Fuera «Ejecución mes a mes»

El bloque que se había agregado esa misma mañana se retira: su contenido es
ahora el detalle de cada card. En la sección de ejecución quedan el calendario
—que es la vista transversal del período— y el horario comprometido como su
referencia. Se eliminaron `monthBreakdown` y `breakdownDay`.

### 9.3 Desglose de las validaciones

Componente nuevo `Du288NormativeDetailSection`, debajo del panel de chips. Seis
bloques desplegables: contrato, asignaciones, parentesco, tope, saldo y centro
de costo.

Para que exista, `revalidateNormative` ahora **conserva lo que ya traía**:
antes consultaba las cinco fuentes, armaba los chips y descartaba los payloads.
Se agregó `SET_NORMATIVE_SOURCES` al store. **Cero consultas nuevas.**

La tabla de asignaciones se muestra vacía con su leyenda cuando no hay
ninguna: que el funcionario no tenga asignaciones es parte de lo que se
comprueba, y una sección ausente se confunde con una que no cargó.

### 9.4 Verificación

`eslint` limpio; los cinco `.vue`, el store y `pds.js` compilan. **Sin
verificación visual**: el panel del navegador no se pinta (§14.4 de
`vista_detalle_pago.md`).

### 9.5 Lo que queda

| | Qué |
| :-- | :--- |
| 1 | **Resumen de la cuota** (§2): el nivel 1 todavía no se arma como en el solicitante; hoy sus cifras están repartidas entre el título, antecedentes y los totales de la sección de meses |
| 2 | **Carga semanal** en el desglose de validaciones: necesita cruzar prestaciones previas con sus horarios, que hoy solo calcula el store para el chip |
| 3 | **Editar la compensación del funcionario**: camino 1 del §4, si se decide que DGDP corrija en vez de observar |
| 4 | Verificar las dos pantallas en vivo |

### 9.6 Corrección — `Cannot read properties of undefined (reading 'title')`

El bloque de textos `normativeDetail` quedó en
`payments.review.detail.normativeDetail`, pero el componente lo leía en
`payments.detail.normativeDetail`. `this.text` era `undefined` y la primera
lectura —`text.title`— reventaba **la vista entera**, no solo esa sección.

Corregida la ruta. Y se dejaron dos verificaciones que esto justifica:

1. **Rutas `$pdsText`**: se resuelve cada `$pdsText.a.b.c` de los archivos
   tocados contra `pds.js` cargado de verdad. Las siete pasan.
2. **Accesos anidados**: se resuelve también `text.a.b` y `labels.a.b` dentro
   de los componentes cuyo `text()` se conoce, que es el patrón exacto que
   falló: la ruta base existía, la sub-clave no.

Ninguna de las dos la detectan `eslint` ni el compilador de plantillas, que es
por lo que pasó. Los scripts quedan en el scratchpad de la sesión; si esto se
repite, conviene moverlos al repositorio como verificación previa al commit.

---

## 10. Resumen de la cuota y verificación del respaldo — 15-10-2026

Cierra el nivel 1 del §2, que había quedado pendiente en §9.5.

### 10.1 Por qué no se reutilizó `Du288InstallmentFormSection`

Era la opción obvia —es el componente que ya pinta ese panel en la pantalla del
solicitante— y se descartó por una razón concreta, no estética:

1. Su método `open()` consulta los meses de la cuota con el action del
   **solicitante**, que el endpoint rechaza para un revisor DGDP.
2. Más grave: recibe **todos los meses de la prestación**, no los de la cuota.
   Sus avisos de *«N meses quedan para la cuota siguiente»* y *«queda fuera del
   pago $X»* se calculan contra los meses **no marcados**. Alimentado solo con
   los meses de la cuota, `plannedTotal` colapsa al total de esta cuota y el
   componente informaría una pérdida enorme e inventada.

Un panel que miente sobre plata es peor que un panel que falta.

### 10.2 Lo que sí se hizo

`Du288InstallmentSummarySection`, con las **mismas etiquetas** del solicitante
—se leen de `payments.detail.installmentModal`, no se copian— para que revisor
y solicitante discutan sobre las mismas cifras:

```
Total de la cuota  $255.296      4 meses · Enero 2016 – Abril 2016
Total descuentos   −$46.643      A pagar  $208.653
Tope por cuota  $256.250 · Espacio en esta cuota  $954
Saldo autorizado disponible  $444.444 · Saldo después de esta cuota  $189.148
```

**Los totales se suman de los meses, no del encabezado**: si DGDP acaba de
registrar un descuento, el encabezado todavía trae el valor anterior.

Mensajes, en el orden del §5.4: supera el tope · supera el saldo · exención por
extensión · **estado del PDF justificativo** · quién registra los descuentos.

### 10.3 Verificación del respaldo

`hasEvidence` sale de `installment.evidenceId`. El PDF es obligatorio para
enviar, así que una cuota enviada **sin** respaldo es una anomalía que el
revisor tiene que ver antes de aprobar: aparece como advertencia, no como dato
silencioso. El documento en sí se revisa en su pestaña, que ya existía.

### 10.4 Lo que todavía falta, y por qué

| | Qué | Bloqueo |
| :-- | :--- | :--- |
| 1 | **«Queda fuera del pago»** y **«N meses quedan para la cuota siguiente»** | necesitan **todos** los meses de la prestación; el endpoint DGDP solo devuelve los de la cuota |
| 2 | **Detalle de las cuotas posteriores** | mismo bloqueo: hace falta saber qué meses quedan sin asignar |
| 3 | Editar la compensación del funcionario | camino 1 del §4: PA, endpoint, permiso y versionado |

Los puntos 1 y 2 se resuelven con **un PA de lectura** —el equivalente DGDP de
`sg_fumesSecgen02`, acotado por asignación del revisor— y su endpoint. Es la
misma forma de `sg_fum2sSecgen02` frente a `sg_fum2sSecgen01`. Con eso, el
resumen puede además reutilizar tal cual el cálculo de reparto del solicitante
en vez de aproximarlo.

### 10.5 Verificación

`eslint` limpio, los cinco `.vue` y `pds.js` compilan, y las dos
comprobaciones de rutas de texto de §9.6 pasan. **Sin verificación visual.**

---

## 11. Cards en cuadrícula y edición desde la card — 15-10-2026

### 11.1 Cuadrícula

`.months-cards` pasa de una columna a
`repeat(auto-fill, minmax(260px, 1fr))`: los meses se ven de un vistazo, uno
al lado del otro, como en la pantalla del solicitante.

Dos detalles que no son cosméticos:

- **`min-width: 0` en la card.** Los items de grid no encogen por defecto
  (`min-width: auto`), así que un período largo estiraba su columna y rompía la
  cuadrícula entera. Es el mismo defecto que desbordó las cards del solicitante
  en su momento.
- **La card abierta ocupa el ancho completo** (`grid-column: 1 / -1`). Su
  desglose —días de compensación con sus marcas— no cabe en 260 px, y partirlo
  en dos columnas es exactamente lo que ya falló antes.

### 11.2 Filas clave/valor

En una columna de 260 px las tres cifras en fila se pisaban. Pasan a filas
clave/valor con la etiqueta a la izquierda y la cifra a la derecha, que es la
forma a la que llegó la card del solicitante por el mismo motivo. El descuento
en cero ya no ocupa una fila: solo aparece si existe.

### 11.3 Editar desde la card

El botón **Editar descuentos** aparece ahora también dentro de la card abierta,
junto al título de la sección de descuentos. El revisor abre un mes porque
quiere revisar **ese** mes; obligarlo a subir al encabezado de la sección para
habilitar la edición es un viaje sin motivo.

El modo de edición sigue siendo **uno solo** para toda la cuota, así que
*Guardar descuentos* y *Cancelar edición* del pie siguen valiendo para todos
los meses. Abrirlo desde cualquier card no cambia el alcance de lo que se
guarda.

### 11.4 Verificación

`eslint` limpio, plantilla y script compilan, y las comprobaciones de rutas de
texto pasan. **Sin verificación visual**: la cuadrícula y el ancho de la card
abierta son justamente lo que habría que mirar a 1366 y a 375 px.

---

## 12. Validaciones en tablas y cards afinadas — 15-10-2026

### 12.1 El desglose de validaciones deja de ser acordeón

Cada control es ahora **un apartado con su tabla a la vista**, no un
desplegable. El motivo es simple: un acordeón obliga a abrir seis veces para
comprobar seis cosas, y **el que no se abre es el que no se comprueba**. Si la
tabla está para verificar, tiene que estar visible.

Y el bloque **sube**: va antes del resumen de la cuota y de las cards.

```
1  Antecedentes de la prestación
2  Saldo del centro de costo
3  Detalle de las validaciones   ← tablas, sin desplegar
4  Resumen de la cuota
5  Meses de la cuota             ← cards en cuadrícula
6  Ausencias del período
7  Ejecución y calendario
8  Validaciones normativas       ← chips, el veredicto
9  Dictamen
```

Primero con qué datos se evalúa, después lo que se pide pagar, al final el
veredicto y la decisión. Los chips se mantienen tal como estaban.

### 12.2 Lo duplicado que se quitó

El encabezado de la sección de meses repetía **Solicitado · Descuentos · A
pagar**, que es exactamente lo que trae el resumen de la cuota. Dos lugares
diciendo lo mismo obligan a compararlos; se quitó del encabezado y queda solo
en el resumen, que es su dueño.

### 12.3 La card dice qué descuento es

«Descuentos −$46.643» no dice si fue licencia médica o permiso sin goce, que es
lo primero que se pregunta al revisar. El resumen de la card los separa, y cada
uno aparece **solo si existe**: un descuento en cero no gasta una fila.

### 12.4 La compensación dice si se cumplió

Antes el chip contaba días —«3 días con compensación»—, que no responde la
pregunta. Ahora dice el estado:

| Estado | Cuándo |
| :--- | :--- |
| Sin compromiso | el mes no comprometió horas |
| Compensación cumplida | todos los días comprometidos tienen informe |
| Compensación parcial | algunos |
| Compensación pendiente | ninguno |

Se mide **por día, no por horas**: un día comprometido sin informar es un día
que falta, aunque otro día se haya informado de más. El tooltip lleva el
conteo exacto.

### 12.5 El detalle es un botón de icono

`pds-ui-icon-button` de 40×40 alineado a la derecha de la card, con `title` y
`aria-label` que incluyen el mes, y `aria-expanded` para el lector de pantalla.
El icono cambia entre lista y chevron según esté cerrado o abierto.

### 12.6 Orden dentro de la card abierta

**Compensación primero, descuentos después**: es el orden en que ocurren —el
funcionario compensa, DGDP descuenta— y el orden en que se revisan.

### 12.7 Verificación

`eslint` limpio, los cuatro `.vue` y `pds.js` compilan, las rutas de texto
resuelven y las variables CSS usadas existen en `pds-du288.css`. **Sin
verificación visual.**

---

## 13. Pendiente — ronda del 15-10-2026 (incompleta)

Se aplicaron dos de los doce puntos pedidos; el resto quedó sin tocar por
corte de la sesión.

### 13.1 Aplicado

1. **Subtítulo del encabezado retirado.** Repetía funcionario, solicitud y
   centro de costo, que ya están en Antecedentes.
2. **El desglose de validaciones deja de ser una sección única.** Cada control
   es ahora **su propia sección** —Contrato · Asignaciones vigentes ·
   Parentesco · Tope del cargo · Saldo del centro de costo · Centro de
   costo—, con su icono, su subtítulo y su tabla a la vista. El revisor busca
   «el contrato», no «el detalle de las validaciones».

Verificado: `eslint` limpio, componente, página y `pds.js` compilan, rutas de
texto resuelven.

### 13.2 Pendiente, por orden de lo pedido

| | Qué | Nota |
| :-- | :--- | :--- |
| 1 | Resumen de la cuota **mejor distribuido** | hoy las cifras se apelmazan a la izquierda; la rejilla debe usar el ancho |
| 2 | **Meses arriba**, antes de las tablas de validación | reordenar la página |
| 3 | **Sacar la lista de días** de la card → modal de compensación | |
| 4 | **Sacar «Ejecución comprometida y calendario»** de la vista → modal | |
| 5 | Nuevo apartado **Semana de ejecución** con su tabla | el componente ya tiene `weekRows` y `weekFields` |
| 6 | Mostrar **el mes que se paga junto a lo pagado** | |
| 7 | Calendario dentro del mes desglosado con comprometido / compensado / ejecutado | |

### 13.3 Pendiente y **bloqueado por backend**

Lo pedido como «editar el mes desglosado», «editar montos solicitados» y
«editar las compensaciones como en la solicitud» **no es trabajo de pantalla**:

| Acción | Qué falta |
| :--- | :--- |
| Editar el monto del mes | `sg_fumeuSecgen02` valida contra el solicitante, no contra DGDP |
| Editar o registrar compensaciones | no existe PA, endpoint ni permiso para que DGDP escriba `sg_fuc2` |

Sigue abierta la decisión del §4: **camino 1** (DGDP corrige, con versionado) o
**camino 2** (DGDP observa y el solicitante corrige, que ya funciona). Hasta
cerrarla, la card solo puede mostrar y abrir en modo lectura.

---

## 14. Correcciones sobre la vista ya aplicada — 15-10-2026

### 14.1 «Queda fuera del pago» mostraba $0 sin haberlo calculado

`droppedAmount` devolvía `0` salvo que alguien le pasara el dato por prop, y
nadie se lo pasaba. El panel afirmaba **«No se pierde dinero»** sin haber hecho
la cuenta: en el caso de la pantalla se perdían **$41.000**.

Se calcula ahora del **historial de montos**, que ya se consultaba para el
contador de cambios: la **versión más baja** de cada mes es lo que la
resolución decretó, y lo que se bajó desde ahí no vuelve (C-10).

```
dropped = Σ max(monto_decretado(mes) − monto_actual(mes), 0)
```

Con abril a $33.074 sobre $74.074 decretados da los $41.000 del ejemplo. **Sin
endpoint nuevo**: sale de `loadMonthVersionCounts`, que ya traía las filas.

**Lo que esta cuenta no cubre:** los meses que quedaron fuera de **toda** cuota.
El endpoint DGDP entrega los meses de la cuota, no los de la prestación, así
que esa parte sigue necesitando el PA de lectura del §10.4.

### 14.2 Fuera los recuadros de color

Los tres *callouts* azul, verde y rojo se reemplazan por la misma lista de
mensajes que usa la solicitud, en el orden del §5.4. El color refuerza el
mensaje; no es el mensaje. Con la pérdida ya calculada, el aviso dice además
**cómo evitarla**, igual que en la solicitud: una cifra sola no indica qué
hacer.

### 14.3 Cuántas cuotas hay y cuántas quedan

El número de cuota solo dice dónde se está parado. Se agrega, como mensaje:

> Cuota 1 de 2. Quedan por pedir 1 cuota, con un saldo de $189.148.

Y cuando es la última: *«Es la última cuota que la resolución autoriza.»* Sin
eso no se puede saber si lo que no entró tiene dónde ir.

### 14.4 La card desbordaba

`.months-card-compensation-bar` usaba `justify-content-between` **sin permitir
envolver**: en una card de ~280 px el botón *Ver compensación* se salía de la
tarjeta, que es lo que se veía en pantalla. Ahora envuelve, y el grupo de la
izquierda lleva `min-width: 0` para que encoja en vez de empujar.

Es el mismo defecto de siempre en este módulo: un contenedor flex o grid cuyo
hijo no puede encoger.

### 14.5 Editar desde DGDP — sigue sin backend

La pantalla muestra *Editar cuota* y el bloque *¿Cuándo se paga?*. Conviene
decirlo con claridad: **el único endpoint de escritura que DGDP tiene hoy es la
decisión** (aprobar, observar, rechazar) **y los descuentos del mes**.

| Acción | Endpoint |
| :--- | :--- |
| Decisión de la cuota | existe |
| Descuentos del mes | existe |
| **Mes de pago** | **no existe** |
| **Monto del mes** | **no existe** |
| **Compensaciones** | **no existe** |

Cualquier control de edición sobre los tres últimos es un botón que no escribe.
Antes de construirlos hay que cerrar la decisión del §4 y hacer los PA.

### 14.6 Deuda menor detectada

La card de mes tiene **textos escritos directamente en la plantilla**
—«Compensación:», «Ver compensación», «Aporte a la cuota», «Descuentos
(Licencia / Permiso)»—. El §15 del estándar pide que todo texto salga de
`lang/es/pds.js`. No se corrigió en esta pasada para no mezclarlo con los
arreglos funcionales.

---

## 15. El PA que faltaba y el cálculo completo — 15-10-2026

### 15.1 `sg_fumesSecgen03` — los meses de la prestación para DGDP

Era el bloqueo que arrastrábamos desde §10.4. El endpoint DGDP entregaba **los
meses de la cuota**, y sin los demás no se puede decir si lo que no entró tiene
dónde ir ni cuánto del total decretado deja de pagarse.

El PA nuevo es a `sg_fumesSecgen02` lo que `sg_fum2sSecgen02` es a
`sg_fum2sSecgen01`: mismas columnas, **distinto criterio de acceso**. Aquel
acota por responsable vigente del centro de costo; éste valida, con el patrón
ya usado en la bandeja DGDP:

1. contrato vigente del revisor (`sp_cont`, calidad distinta de `01`);
2. asignación vigente a la unidad **696** (`sp_orde`);
3. que la cuota esté en un estado revisable (`cod_estcuo in (2,3,4,8,10,11)`).

ASCII 7-bit, CRLF, `.txt` idéntico al `.sql`.

| Capa | Qué |
| :--- | :--- |
| PA | `sg_fumesSecgen03` |
| Consulta | `selectDgdpProvisionMonths` |
| Repositorio | `selectDgdpProvisionMonths`, reusa `Du288ProvisionMonthResponse` |
| Endpoint | `GET .../dgdp/provisions/{id}/installments/{n}/provision-months` |
| Store | `fetchDgdpProvisionMonths` |

`tsc` limpio y **201 tests** en verde.

### 15.2 «Queda fuera del pago», ahora completo

Son **dos cosas distintas** y hay que sumarlas:

```
queda fuera = lo bajado a los meses de esta cuota
            + lo que ya no cabe en las cuotas que quedan
```

- **Lo bajado**: monto decretado del mes —la versión más baja del historial—
  menos el monto actual. No vuelve (C-10).
- **Lo inalcanzable**: los meses sin cuota cuyo total excede lo que las cuotas
  restantes pueden cargar. El tope no se acumula (T-03) y los meses entran
  enteros, así que la capacidad es `tope × cuotas restantes`. Si no queda
  ninguna cuota, se pierde todo lo suelto; con extensión no hay tope y no se
  pierde nada por esta vía.

Comprobado con los números de la pantalla: abril a $33.074 sobre $74.074 da
**$41.000**, y los dos meses sueltos ($148.148) caben en la cuota que queda
($256.250), así que no agregan pérdida. Coincide con lo que muestra la
solicitud.

El conteo de meses pendientes también deja de deducirse del número de cuotas:
**se cuentan** los meses sin cuota.

### 15.3 El resumen usa el ancho

Las cifras estaban en `flex` y se apelmazaban a la izquierda dejando media
pantalla vacía. Pasan a `grid` con `auto-fit`: cada una toma su columna y el
ancho se reparte.

### 15.4 Lo que sigue pendiente

| | Qué | Estado |
| :-- | :--- | :--- |
| 1 | Apartado **Semana de ejecución** con su tabla | no hecho |
| 2 | Mover los meses arriba de las tablas de validación | no hecho |
| 3 | Calendario dentro del mes desglosado | no hecho |
| 4 | Textos de la card a `pds.js` (§15 del estándar) | no hecho |
| 5 | Editar mes de pago, monto del mes y compensaciones | **sin backend**; depende de la decisión del §4 |

**Por desplegar:** `sg_fumesSecgen03`, además de los PA ya pendientes.

---

## 16. Limpieza: el detalle al modal y fuera lo redundante — 15-10-2026

### 16.1 «Ver detalle» ya no despliega: abre el modal

Y es lo correcto, por una razón concreta: la card vive en una **cuadrícula**.
Desplegar una card reflujaba toda la rejilla y empujaba las demás hacia abajo,
así que el revisor perdía de vista justo lo que estaba comparando. El modal
deja la cuadrícula quieta y da ancho real al detalle.

El modal del mes queda con **tres pestañas**:

| Pestaña | Qué |
| :--- | :--- |
| Descuentos y ausencias | los dos campos **editables** y las licencias/permisos del mes |
| Compensación | lo comprometido frente a lo informado, día a día |
| Ejecución y calendario | el cruce con el reloj control, acotado al mes |

Antes había dos modales distintos —uno de compensación y un desplegable con lo
demás—; ahora es uno solo por mes, que es como se revisa: un mes a la vez.

### 16.2 Lo que se quitó de la card

| Se quitó | Por qué |
| :--- | :--- |
| «Incluido en esta cuota» | en todas las cards de una sección llamada *Meses incluidos en la cuota* |
| «Descuento: −$46.643» como etiqueta | la cifra ya está en las filas de la card |
| Barra de compensación con su botón | el estado ya va como etiqueta y el botón duplicaba el de detalle |
| `badge-success` y compañía | las etiquetas usan `pds-ui-mini-chip`, como en la solicitud |

La card queda con **período · solicitado · descuentos si corresponde · a pagar**
y el botón de detalle. Nada más.

### 16.3 Los recuadros de color

Ya se habían reemplazado por la lista de mensajes; ahora se eliminó también su
CSS, que quedaba sin uso. El color refuerza el mensaje, no lo envuelve.

### 16.4 Dónde dejar ausencias y ejecución — el análisis

La pregunta era si mostrarlas de forma general o por mes. **Por mes, dentro del
modal**, y la razón es que ambas se usan **para decidir sobre un mes**: la
ausencia justifica el descuento de *ese* mes, y el calendario contrasta la
compensación de *ese* mes. Verlas a nivel período obliga a filtrar mentalmente
qué día pertenece a qué mes, que es el trabajo que la pantalla debería evitar.

Queda pendiente decidir si además se mantiene una vista general del período
—útil para ver solapamientos entre meses— o si con la del mes basta.

### 16.5 Pendiente

| | Qué |
| :-- | :--- |
| 1 | Subtítulo de la sección de meses: todavía dice «Marque los que se pagan en esta cuota», que es texto del solicitante y acá no aplica |
| 2 | Textos de la card en la plantilla, no en `pds.js` (§15 del estándar) |
| 3 | Apartado **Semana de ejecución** con su tabla |
| 4 | Editar mes de pago, monto del mes y compensaciones: **sin backend** |

---

## 17. Pendientes cerrados — 15-10-2026

### 17.1 El subtítulo que no correspondía

La sección de meses decía *«Estos son los meses propuestos en la resolución…
**Marque** los que se pagan en esta cuota»*. Es el texto del solicitante, y
describe una acción que la revisión **no tiene**: los meses ya están
decididos. Reemplazado por lo que acá sí aplica: los meses que el jefe de
proyecto agrupó, y que el detalle de cada uno se abre para revisar
compensación, ausencias y registrar descuentos.

### 17.2 Los textos salen de la plantilla

Catorce literales escritos directamente en el `<template>` —«Resumen de la
cuota», «Editar cuota», «Aporte a la cuota», «Descuentos (Licencia /
Permiso)»…— pasan a `lang/es/pds.js`, como pide el §15 del estándar. También
salió un `style="font-size: 1.05rem"` inline a su clase.

### 17.3 Apartado «Semana de ejecución»

Componente nuevo `Du288ExecutionWeekSection`, antes del detalle mes a mes: día,
tramos y horas, en **tabla**. En tabla se suman de un vistazo y se comparan con
lo que cada mes informó; como chips sueltos no se podían sumar.

Va como apartado propio porque el horario es de la **prestación**, no de un
mes: repetirlo dentro de cada card sería la misma fila doce veces.

### 17.4 Un defecto que apareció al revisar

El cálculo real de «queda fuera del pago» de §15.2 estaba en
`Du288InstallmentSummarySection`, **que ya no se usa**: el resumen se había
movido dentro de `Du288PaymentMonthsReviewSection`, y la versión de allí
devolvía `installment.droppedAmount || 0`, o sea **siempre 0**.

Portado al componente que sí se renderiza, con las dos partes: lo bajado a los
meses de esta cuota y lo que ya no cabe en las cuotas restantes. La página ya
le pasaba `originalAmounts` y `provisionMonths`; solo faltaba **declarar los
props**.

Vale la pena anotarlo: una corrección verificada en un componente no sirve de
nada si la vista renderiza otro. Conviene comprobar que el componente tocado
está efectivamente montado.

### 17.5 Estado

`eslint` limpio, los componentes y `pds.js` compilan, rutas de texto resuelven.
**Sin verificación visual.**

Sigue pendiente, y es lo único: **editar mes de pago, monto del mes y
compensaciones**, que no tiene backend y depende de la decisión del §4.
