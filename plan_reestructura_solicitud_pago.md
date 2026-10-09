# Plan — reestructura de la solicitud de pago

**Fecha:** 08-10-2026
**Ruta:** `/prestacion-de-servicios/pagos/:nroSolici`
**Estado:** **aplicado** el 09-10-2026. Ver §7 para lo que quedó y lo que no.
**Origen:** la cuota es la tarea principal; los meses de ejecución son la
selección que la cuota abarca, la compensación se ajusta ahí mismo y el PDF
justificativo se asigna a la cuota generada.

---

## 1. Qué hay hoy

La pestaña **Gestión de pago** apila seis bloques del mismo peso visual:

| # | Bloque | Qué es |
| :--- | :--- | :--- |
| 1 | Validación presupuestaria | solo lectura |
| 2 | Funcionario | solo lectura (+ selector si hay varios) |
| 3 | Horario de ejecución | solo lectura |
| 4 | **Área de trabajo "Meses"** | lista de meses + editor de compensaciones |
| 5 | **Área de trabajo "Cuotas"** | lista de cuotas + compositor de la cuota |
| 6 | Validaciones + envío | decisión |

### El problema: los meses salen dos veces

| | Bloque 4 — lista de meses | Bloque 5 — compositor |
| :--- | :--- | :--- |
| Qué muestra | todos los meses propuestos | **los mismos** meses |
| Qué deja hacer | abrir compensaciones | marcar cuáles entran, fijar monto |
| Estado que pinta | compensación pendiente / parcial / completa | disponible / en otra cuota / ejecución sin terminar |

Son dos lecturas del mismo objeto, una encima de la otra, cada una con la mitad
de la información. El usuario tiene que mirar arriba para saber si un mes está
compensado y abajo para meterlo en la cuota.

Tres de los seis bloques (1, 2, 3) son contexto de solo lectura y ocupan la
primera pantalla completa antes de llegar a lo único que se hace.

---

## 2. Qué no se puede mover, y por qué

Antes de reordenar, dos restricciones reales del modelo.

### 2.1 La compensación no es de la cuota, es del mes

`sg_fuc2` cuelga de `sg_fume` por `(id_funprse, corr_fume)`, no de `sg_epag`.
Y la regla de los PA es:

```sql
if @cod_estfum <> 1 and isnull(@cod_estcuo, 0) <> 3
    'El mes de ejecucion ya no admite cambios'
```

Es decir: **un mes se compensa mientras está propuesto**, pertenezca o no a una
cuota. Esto ya costó un defecto, documentado en §5.1 de
`mapa_escrituras_y_estados.md`: cuando la pantalla cerraba la compensación al
meter el mes en una cuota, no había forma de terminarla — había que borrar la
cuota, compensar y rehacerla.

**Consecuencia para esta reestructura:** si la compensación queda solo dentro
del compositor, hay que garantizar que se pueda compensar un mes **sin
marcarlo** en la cuota. La acción se habilita por `acceptsChanges`, nunca por
`checked`.

### 2.2 El PDF sí es de la cuota

`sg_epag.id_evidenc`. Está bien donde está: se sube desde el compositor y queda
atado a la cuota. No hay nada que mover.

---

## 3. La estructura propuesta

Cuatro bloques en vez de seis, y los meses una sola vez.

```
┌─ A · Contexto ────────────────────────────────────────────┐
│  Funcionario · Resolución · Centro de costo · Saldo        │
│  Horario de ejecución                       [ver detalle]  │
└────────────────────────────────────────────────────────────┘

┌─ B · Cuotas de pago ──────────────────────── [Nueva cuota] ┐
│  N° 1  Ene–Mar 2016   $222.222   Borrador   PDF ✓  Comp ✓  │
│  N° 2  Abr–Jun 2016   $222.222   —          PDF ✗  Comp ⚠  │
└────────────────────────────────────────────────────────────┘

┌─ C · Cuota N° 1 ─────────────── [Editar] [Cancelar] [Guardar] ┐
│  1. Cuándo se paga         Mes / Año                           │
│  2. Meses que abarca                                           │
│     ☑ Enero 2016   Comprometida   4 h / 4 h ✓  $74.074  [⚙]   │
│     ☑ Febrero 2016 Comprometida   4 h / 2 h ⚠  $74.074  [⚙]   │
│     ☐ Abril 2016   En otra cuota  —            —        [⚙]   │
│  3. Documento justificativo        [Seleccionar PDF]           │
│  4. Resumen y límites                                          │
└────────────────────────────────────────────────────────────────┘

┌─ D · Validaciones y envío ────────────────────────────────┐
└────────────────────────────────────────────────────────────┘
```

### A · Contexto

Los tres bloques de solo lectura se funden en uno. Lo que hoy son tres tarjetas
grandes pasa a una rejilla de campos (`.pds-ui-read-field`) más la tabla
presupuestaria. El horario de ejecución queda tras un enlace, porque se consulta
una vez y no se vuelve a mirar.

**Excepción:** si el saldo del centro de costo está en rojo, se muestra abierto.
Es bloqueante y no puede quedar escondido.

### B · Cuotas

Pasa a ser el primer bloque accionable. La fila suma dos columnas que hoy hay
que ir a buscar a otro lado: **PDF** y **compensación**, porque son los dos
requisitos para enviar.

### C · Compositor

Cuatro pasos numerados en orden de decisión. La fila de mes concentra todo lo
que hoy está repartido:

| Columna | De dónde sale hoy |
| :--- | :--- |
| casilla | compositor |
| período | los dos |
| estado del mes | lista de meses |
| compensación (comprometida / realizada + chip) | lista de meses |
| acción de compensar | lista de meses |
| monto, descuentos, neto | compositor |

La compensación se abre en **modal** desde la fila, no en un panel que empuja
el resto de la pantalla. Es una edición acotada que se abre, se resuelve y se
cierra.

### D · Validaciones y envío

Sin cambios. Ya cierra la pantalla, que es donde corresponde.

---

## 4. Qué desaparece

| Hoy | Después |
| :--- | :--- |
| `Du288PaymentWorkspace` de "Meses" | se elimina |
| `Du288PaymentMonthsSection` | se absorbe en la fila del compositor |
| `Du288PaymentScheduleSection` como sección | pasa a modal del contexto |
| `Du288PaymentBudgetSection` + `Du288PaymentStaffSection` | se funden en el contexto |
| `autoSelectPendingMonth` | deja de abrir un panel: pasa a ser un aviso en la cuota |

`Du288ExecutedCompensationSection` se conserva tal cual; solo cambia de
contenedor (de panel del área de trabajo a cuerpo de modal).

---

## 5. Lo que hay que resolver antes de implementar

1. **Compensar sin cuota abierta.** Con el compositor como único lugar donde
   viven los meses, entrar a la pantalla sin ninguna cuota creada deja los meses
   sin acceso. Dos salidas: el compositor abre en "nueva cuota" por defecto
   (lista todos los meses, ninguno marcado), o el bloque B ofrece
   "Compensar meses" como acción aparte. La primera es menos superficie.

2. **Varios funcionarios.** El selector de funcionario vive hoy en el bloque 2.
   Al comprimir el contexto hay que decidir dónde queda. En DU288 hoy hay uno
   solo (§4 de `diagrama_pagos_actualizada.md`), pero el modelo admite varios.

3. **Alto del compositor.** Con 6 meses y las columnas nuevas, la fila crece.
   Hay que verificar §13 del estándar visual a 1366 y 768 sin scroll horizontal.

---

## 6. Orden de implementación sugerido

| Paso | Alcance | Riesgo |
| :--- | :--- | :--- |
| 1 | Fundir A (contexto) y mover el horario a modal | bajo, es solo lectura |
| 2 | Mover la compensación a modal desde la fila del compositor | **medio** — es el punto 5.1 |
| 3 | Eliminar el área de trabajo de meses | bajo, una vez hecho el 2 |
| 4 | Columnas de PDF y compensación en la lista de cuotas | bajo |
| 5 | Pasos numerados en el compositor | bajo |

Cada paso deja la pantalla usable; no hace falta hacerlos todos de una vez.


---

## 7. Qué quedó aplicado

| Bloque | Componente | Estado |
| :--- | :--- | :--- |
| A · Contexto | `Du288PaymentContextSection.vue` (nuevo) | funde funcionario + saldo; horario en modal |
| B · Cuotas | `Du288InstallmentsSection.vue` | chips **PDF** y **compensación** por fila |
| C · Compositor | `Du288InstallmentFormSection.vue` | fila de mes con estado, compensación y acción |
| Compensación | `Du288ExecutedCompensationSection.vue` | sin cambios, ahora dentro de un `b-modal` |
| Meses | `Du288PaymentMonthsSection.vue` | **eliminado** |
| Funcionario | `Du288PaymentStaffSection.vue` | **eliminado**, absorbido por el contexto |

### Lo verificado en pantalla (usuario Jefe de Proyecto de Pagos)

- El contexto abre la validación presupuestaria **sola** porque el centro de
  costo está sin saldo; con saldo sano queda plegada.
- La fila de la cuota muestra *PDF adjunto* y *Compensación al día*.
- El compositor lista los seis meses del período, no solo los tres de la cuota,
  y cada uno trae su estado (*Incluido en esta cuota* / *Disponible para
  incluir*) junto al de compensación (*Completa* / *Otros días* / *Sin
  compromiso*).
- La acción de compensar está en los **seis** meses: se abrió la de Abril 2016,
  que no pertenece a ninguna cuota. Es el punto 2.1, resuelto.
- Cerrar el modal de compensación **no** cierra la cuota que estaba abierta
  debajo.
- Editar cuota → 6 casillas habilitadas (incluidos los tres meses ya
  comprometidos) y `max` = monto propuesto en cada input. Cancelar edición
  devuelve a consulta con 0 casillas habilitadas.

### Decisiones tomadas sobre el punto 5 del plan

1. **Compensar sin cuota abierta** — resuelto por la vía de listar todos los
   meses en el compositor. La acción se habilita por `acceptsChanges`, nunca
   por `checked`.
2. **Varios funcionarios** — el selector se conservó, ahora en la cabecera del
   contexto.
3. **`autoSelectPendingMonth`** — eliminado. Abría un panel al entrar; con la
   compensación en modal eso sería abrir un modal sin que nadie lo pida. El
   chip por mes y el de la fila de cuota cumplen el mismo aviso.

---

## 8. Pasada visual sobre lo aplicado (09-10-2026)

Seis defectos encontrados sobre la pantalla ya reestructurada.

### 8.1 Textos encabalgados en la tarjeta de mes — **causa raíz**

La tarjeta era una rejilla de dos columnas (`minmax(0,1fr) minmax(112px,auto)`)
y la columna de montos **no tenía `min-width: 0`**. En CSS Grid el mínimo por
defecto de un ítem es `auto`, así que un texto largo —"Repartido por el sistema.
Puede ajustarlo a la baja."— desbordaba su pista y se pintaba encima de la
columna del período. De ahí "Solicitado" sobre "Enero 2016".

Se reemplaza por una tarjeta de **una sola columna** con filas clave/valor:
cabecera (casilla + período + estado), compensación, solicitado, descuentos,
neto y nota. Cada fila es un `flex` con `min-width: 0` en la clave y
`flex: 0 0 auto` en el valor: el que se parte es el rótulo, nunca la cifra.

### 8.2 Botones `size="sm"` pintados como primario sólido

`app.css:87` declara `.btn.btn-sm { border: 0; background-color: #00396c;
color: #fff; padding: 6px 30px }`. Eso gana por especificidad a
`.btn-outline-*` y convierte **cualquier** botón pequeño del módulo en un
primario sólido: el icono de compensación salía como un cuadrado azul oscuro de
40 px, y lo mismo les pasaba a "Descargar" y "Ver historial".

Rompe el §5.4 del estándar (el color es para la semántica). Se añade en
`pds-du288.css` un bloque que restituye la variante **sin tocar la geometría**,
que la siguen fijando `.pds-ui-action-button` y `.pds-ui-icon-button`.

El botón de compensación pasa además de `pds-ui-icon-button` (40 px) a
`pds-ui-compact-action` (32 px): dentro de una fila de 26 px, 40 px desalineaba
todo.

### 8.3 "Devolver" como estado de la cuota

El catálogo `sg_ecuo` guarda el **verbo de la acción**, no el estado, y la
tarjeta lo mostraba crudo. Una cuota no está "Devolver": está **Devuelta**. Se
agrega `installments.statusLabel` con los seis códigos y el `item.status` de la
BDD queda solo como respaldo.

### 8.4 Una cifra sin rótulo que contradecía al resto

La tarjeta mostraba `netAmount ?? requestedAmount` sin etiqueta: decía
`$175.579` mientras el resumen y la barra de envío decían `$222.222`. Ahora van
las dos, rotuladas — **Solicitado** siempre, **A pagar** solo cuando difiere.

### 8.5 Tarjetas de distinto alto y rejilla irregular

`minmax(230px, 1fr)` dejaba la tarjeta de cuota en cuatro líneas con el botón
descolgado a media altura. Sube a 300 px, las tarjetas estiran al alto de su
fila (`align-items: stretch`) y la meta se ancla abajo con `margin-top: auto`.
En los meses, 260 px y el mismo criterio.

### 8.6 Combinador `>>>` obsoleto

Se eliminó el único uso, que generaba un warning en cada compilación.

### Verificación

Comprobación automática de solapes (intersección en ambos ejes entre hermanos),
desborde de hijos fuera de la tarjeta y scroll horizontal de página, con el
compositor abierto:

| Ancho | Solapes | Desbordes | Scroll horizontal |
| :--- | :--- | :--- | :--- |
| 1440 | 0 | 0 | no |
| 1366 | 0 | 0 | no |
| 1024 | 0 | 0 | no |
| 768 | 0 | 0 | no |
| 375 | 0 | 0 | no |

---

## 9. Segunda pasada: "editar" duplicado y lenguaje de agrupación (09-10-2026)

Contrastado contra `estandar_visual/estandar_visual_obligatorio_du288.md` v1.3
y `GUIDELINES_BACKEND_FRONT_V2.md`.

### 9.1 Se pedía editar dos veces

La fila de la cuota ofrecía "Corregir cuota" y, al abrirla, el compositor volvía
a pedir "Editar cuota": la misma decisión dos veces.

El §3.2 del estándar lo resuelve — *"creación, edición y lectura DEBEN
reutilizar la misma estructura; lectura es una variante de estado, no una
pantalla visual distinta"*. Abrir y editar son cosas distintas y el dueño del
estado es el compositor:

| | Antes | Ahora |
| :--- | :--- | :--- |
| Fila de la cuota | "Continuar borrador" / "Corregir cuota" / "Ver cuota" | **"Abrir cuota"**, siempre |
| Compositor | pedía "Editar cuota" otra vez | Editar / Cancelar edición / Guardar edición |

### 9.2 Cada mes se leía como una cuota de $74.074

Seis tarjetas iguales, cada una con su monto y sin nada que dijera que se
suman. Correcciones:

- el paso 2 se titula **"¿Qué meses de ejecución agrupa?"** y explica que *"una
  cuota agrupa varios meses de ejecución y se paga en una sola remuneración; el
  total es la suma de los meses incluidos"*;
- un contador **"3 meses agrupados de 6"** al lado del título;
- el monto del mes se rotula **"Aporta a la cuota"** cuando está incluido y
  "Monto del mes" cuando no;
- el panel de resumen pasa de "Esta cuota solicita" a **"Total de la cuota"**.

### 9.3 Los cuatro bloques quedan nombrados

| Bloque | Qué responde |
| :--- | :--- |
| 1. ¿Cuándo se paga? | mes de remuneraciones |
| 2. ¿Qué meses de ejecución agrupa? | selección y montos |
| 3. Documento justificativo | el PDF de la cuota |
| Compensación (por mes) | lo comprometido contra lo realizado |

La compensación vive **dentro de la tarjeta del mes**, con su etiqueta propia y
su botón, porque es del mes y no de la cuota (§2.1 de este plan).

### 9.4 Si se puede editar o no, declarado

Chip junto al título del compositor: **Solo lectura** · **Se puede editar** ·
**En edición**. Antes había que intentar tocar un campo para saberlo (§8 del
estándar: el estado deshabilitado debe ser distinguible).

### 9.5 Desvíos del estándar corregidos

| Regla | Desvío | Corrección |
| :--- | :--- | :--- |
| §5.1 — títulos en formato oración | `app.css` declara `h6 { text-transform: uppercase; font-weight: 500 }` y el título salía "CORREGIR CUOTA" | `text-transform: none` y peso 700 en `.payment-installment-title` |
| §5.3 — tarjetas con radio de 10 px | las tarjetas de mes usaban el radio de control (6 px) | `--pds-du288-radius-lg` |
| §5.3 — botón solo icono 40 × 40 px | el de compensación había quedado en 32 px | pasa a botón **con texto** de 40 px ("Compensar" / "Ver compensación"), que además cumple §7: etiqueta verbal explícita |
| §13 — sin cortes en móvil | a 375 px el botón desbordaba la tarjeta 72 px | la línea de compensación envuelve y el botón baja a su propia fila |

### 9.6 Lo que NO se tocó, a propósito

- **DNA** — ninguna modificación (§3.3).
- **`app.css`** — el `.btn-sm` sólido y el `h6` en mayúsculas se corrigen
  **dentro de `.pds-du288-scope`**, no globalmente: el §3.1 prohíbe arreglar
  una vista DU288 alterando estilos de otros módulos. El resto del sistema
  sigue con ese comportamiento y corregirlo de raíz es una decisión aparte.

### Verificación

| Ancho | 1440 | 1366 | 1024 | 768 | 375 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Solapes | 0 | 0 | 0 | 0 | 0 |
| Desbordes | 0 | 0 | 0 | 0 | 0 |
| Scroll horizontal | no | no | no | no | no |
| Alto del botón | 40 | 40 | 40 | 40 | 40 |

---

## 10. Tercera pasada: modal de compensación y limpieza de ruido (09-10-2026)

### 10.1 El modal estaba fuera del alcance del módulo — **causa raíz**

Bootstrap-Vue monta el modal al final del `<body>`, fuera de
`.pds-du288-scope`. Como **todas** las reglas de `pds-du288.css` cuelgan de ese
selector, el modal de compensación (y el de horario) se quedaban sin el CSS del
módulo. Síntomas medidos:

| Elemento | Antes | Estándar |
| :--- | :--- | :--- |
| Botón "Cerrar" | 31 px | 40 px (§5.3) |
| Botón "Registrar tramo" | 30 px | 40 px |
| Botón de icono "Eliminar día" | 31 px | 40 × 40 px |
| Título | MAYÚSCULAS | formato oración (§5.1) |

El §3.1 ya lo dice: *"Todo modal DU288 DEBE utilizar `modal-class="pds-ui-modal"`
y `body-class="pds-ui-modal-body"`"*. Faltaban en los dos modales que introdujo
la reestructura. Agregadas, todos los botones pasan a 40 px y el título a
formato oración, sin tocar una sola regla nueva.

### 10.2 El modal no tenía encabezado ni pie reales

Se había montado con `hide-header hide-footer` y el componente dibujaba su
propio título y su botón de cerrar dentro del cuerpo — justo lo que prohíbe el
§11 (*"tener footer real para acciones"*, *"no se permiten botones simulados
dentro del cuerpo"*).

Ahora el modal lleva `:title`, `centered`, y un pie real con **Cerrar**. El
componente recibe `embedded` y oculta su propia cabecera cuando vive dentro de
un modal; fuera de él sigue dibujándola, así que no pierde el uso independiente.

### 10.3 La diferencia decía dos veces lo mismo

`formatSignedHours(0)` devolvía `"0 h · Al día"` y, al lado, el chip decía
`"Cumple en otros días"`. Dos afirmaciones del mismo hecho, y la primera
tapaba el matiz de la segunda. El cero queda como **`0 h`** y el chip es el
único que califica.

### 10.4 Tres niveles de scroll

El cuerpo del modal desplaza, y además cada panel de tramos tenía
`max-height: 11rem`. Con cinco filas ya aparecía un segundo scroll dentro de
una caja pequeña. El tope sube a 22 rem: ahora solo desplaza el cuerpo del
modal, salvo listas realmente largas.

### Verificación

Medido con el modal abierto, contando solapes entre hermanos, desbordes fuera
de cada caja y contenedores con scroll propio:

| Ancho | Solapes | Desbordes | Niveles de scroll | Alto del cuerpo |
| :--- | :--- | :--- | :--- | :--- |
| 1440 | 0 | 0 | 1 (`modal-body`) | 781 px |
| 1366 | 0 | 0 | 1 | 599 px |
| 768 | 0 | 0 | 1 | 731 px |
| 375 | 0 | 0 | 1 | 677 px |
