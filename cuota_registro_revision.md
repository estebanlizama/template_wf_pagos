# Registro de la cuota — qué se paga y qué no

**Fecha:** 05-10-2026
**Alcance:** formulario de cuota (V6) y listado de cuotas (V5), vistos sobre la pantalla en ejecución.

---

## 1. El problema: la pantalla no decía lo que paga

El formulario mostraba un monto por mes y un total, y nada más. Faltaba lo esencial:

| | Antes | Por qué importa |
| :--- | :--- | :--- |
| Cuánto se paga | había que sumar mentalmente | es la única cifra que el jefe de proyecto necesita confirmar |
| Qué meses | una lista de casillas sin encabezado | no se veía el rango de un vistazo |
| Cuándo se paga | dos selectores ambiguos | se confundía el mes de pago con el mes trabajado |
| Qué meses no entran | se filtraban de la lista | desaparecer no explica; el usuario no sabía por qué faltaba un mes |

El mes además se mostraba como `202609`. `period` es un **número** que el backend arma como
`año * 100 + mes` para ordenar, no una etiqueta. Mismo defecto que en el bloque de meses.

---

## 2. El titular: una frase que resume la cuota

Lo primero que se ve, antes de cualquier control:

```
Esta cuota solicita   $141.111
1 mes · Septiembre 2026 · se paga en Octubre 2026  Pago corriente
```

El verbo es **solicita**, no *paga*. El jefe de proyecto pide un monto; cuánto se paga finalmente lo
resuelve la visación. Decirle *paga* daba la cifra por cerrada cuando DGDP todavía puede rebajarla.

Sin meses marcados queda en gris con la indicación de elegir al menos uno: es un estado vacío, no un
error.

---

## 3. Año y mes de pago: se confundían con el mes trabajado

Dos selectores sueltos rotulados *Año de pago* y *Mes de pago*, justo encima de una lista de meses,
no dicen a cuál de los dos meses se refieren. Son cosas distintas:

| | |
| :--- | :--- |
| **Mes trabajado** | el mes de ejecución que se está cobrando (`sg_fume.ano_prop`/`mes_prop`) |
| **Mes de pago** | el mes de remuneraciones en que se ejecuta el pago (`sg_epag.ano_pago`/`mes_pago`) |

Ahora van en un bloque propio con la pregunta como título y la aclaración explícita:

```
¿Cuándo se ejecuta el pago?
Mes de remuneraciones en que se pagará esta cuota.
No es el mes trabajado: esos se eligen más abajo.

  [ Mes en que se paga: Octubre ]   [ Año: 2026 ]

  Octubre 2026 · Pago corriente
```

El mes va primero —es lo que se decide; el año casi siempre es el actual— y debajo queda la frase
resuelta, para no tener que armarla mentalmente desde dos controles. La lista de meses trabajados se
rotuló **"Meses trabajados que se pagan en esta cuota"**, que nombra su propio sujeto.

*Vigente* / *Atrasado* pasaron a **Pago corriente** / **Pago atrasado**: *vigente* en este sistema
significa otra cosa (`ecct.vigente`, el responsable del centro de costo).

---

## 3.1 Los descuentos no van en este formulario

**Ningún PA escribe `mto_deslic` ni `mto_dessg`.** Se leen en `sg_epagsSecgen01`,
`sg_epagsSecgen02`, `sg_fumesSecgen02` y `sg_fupssSecgen17`, y nada las llena — ni en
`cambios_pa` ni en `sissolic-procedimientos`.

Es coherente con a quién le corresponden. Los descuentos salen de revisar licencia médica y permiso
sin goce del mes, que es lo que marcan `val_licmed` y `val_singoce` junto a `fec_valida`: una
validación de **DGDP durante la visación**, no del jefe de proyecto, que además no tiene esa
información.

Vale la regla ya establecida en este flujo: *el estado guarda hechos y decisiones, nunca resultados
de validación*. Un descuento es el resultado de la validación de DGDP.

**Qué se hizo.** Al crear o editar una cuota propuesta no se muestran: valen 0 y una fila
permanentemente en cero sugiere que el jefe tiene algo que decidir ahí. En su lugar va una línea que
dice de dónde vendrán:

> Los descuentos por licencia médica o permiso sin goce los determina DGDP al visar la cuota.

Las filas *Descuentos* y *Se paga* aparecen **solo cuando el valor existe** —una cuota observada que
vuelve a edición con los montos ya registrados— y en el listado, donde el contraste
solicitado-contra-pagado sí es real y auditable.

| Dónde | Qué muestra |
| :--- | :--- |
| Crear cuota | solo *Solicitado* y *Total solicitado* |
| Editar cuota observada | agrega *Descuentos* y *Se paga* si DGDP ya los fijó |
| Listado | *Se paga*, con *Solicitado · Descuentos* debajo cuando los hay |

---

## 4. Los meses que no entran, y por qué

Antes se filtraban. Ahora se listan deshabilitados con el motivo, derivado de lo que ya entrega
`sg_fumesSecgen02`:

| Situación | Qué dice |
| :--- | :--- |
| Ya está en esta cuota | *Incluido en esta cuota* |
| Lo tomó otra cuota (`installmentNumber`) | *Ya pertenece a la cuota N° 1* |
| No está propuesto (`cod_estfum <> 1`) | su propio estado |
| Propuesto pero la ejecución no terminó | *La ejecución del mes aún no termina* |

El segundo caso corregía un error real: `disponible` en el PA **no mira `sg_dpag`**, así que un mes
ya asignado a otra cuota llegaba con `isAvailable: true` y el formulario lo ofrecía como marcable.
El PA lo rechazaba después. Ahora no se ofrece.

---

## 5. Totales y tope

```
Total solicitado   Total descuentos   Total a pagar
$141.111           $0                 $141.111

Tope mensual autorizado: $256.250.
```

El tope se compara contra lo **solicitado**, igual que la validación normativa del store
(`'Tope excedido'`), para que las dos no digan cosas distintas. Si se excede, el mensaje lo dice y
**Guardar** queda deshabilitado. Con `ext_cuotas = 'S'` no aplica.

---

## 6. El listado de cuotas

Alineado con el mismo lenguaje:

| | Antes | Ahora |
| :--- | :--- | :--- |
| Columna del monto | *Monto neto* | *Se paga* |
| Bajo el monto | *Descuentos: $X* | *Solicitado $X · Descuentos −$Y*, solo si los hay |
| Meses | `2 mes(es)` | `2 meses` |
| Meses rechazados | no se mostraban | ficha con `rejectedMonths`, que es justo lo que no se paga |

---

## 7. Bloqueador: falta un PA por desplegar

Guardar una cuota falla con **500** antes de llegar a crearla. No es el código: el PA no existe en
la base.

```
QUERY ERROR serviceProvisionPayment.updateMonthAmount
Stored procedure 'secgen_db.Analisis2.sg_fumeuSecgen02' not found.
```

### Barrido de los 15 PA del flujo

Probando cada endpoint con datos que no existen: si el PA está desplegado contesta 422/404 con su
propio mensaje; si falta, el error sube como 500.

| PA | |
| :--- | :--- |
| `sg_fumeuSecgen02` | **500 · no desplegado** |
| `sg_fupssSecgen18` · `sg_fucosSecgen01` · `sg_fuc2sSecgen01` | 200 |
| `sg_fumesSecgen02` · `sg_epagsSecgen01` · `sg_ecuosSecgen01` · `sg_ecuosSecgen02` | 200 |
| `sg_fuc2iSecgen01` · `sg_fuc2dSecgen01` | 422 |
| `sg_epagiSecgen01` · `sg_epaguSecgen01` · `sg_epagdSecgen01` · `sg_epaguSecgen02` | 422 |
| `sg_epagsSecgen02` | 404 |

**Catorce de quince están arriba.** Falta uno.

Los endpoints de resolución y normativos que consume la pantalla —solicitud, detalle, funcionarios,
detalle de resolución, horarios FUHO, comentarios, calendario institucional, perfil y tope— responden
todos 200. No hay nada más pendiente de desplegar.

### Por qué es obligatorio

`sg_epagsSecgen01` calcula el monto de la cuota como `sum(sg_fume.mto_apagar)`. Si el monto del mes
no se persiste, la cuota vale **$0** — también en modalidad Fija, donde la cifra la calcula el
sistema pero igual hay que guardarla.

### Qué desplegar

```
nuevo_workflow_fase_2/template_wf_pagos/cambios_pa/sg_fume/sg_fumeuSecgen02.sql
```

El archivo trae su propio `drop` condicional y el `grant execute ... to UsuaVrac`, así que se corre
tal cual. Para comprobar que quedó: guardar una cuota deja de dar 500, y con un `id_funprse`
inexistente el endpoint pasa a responder 422 en vez de 500.

### Pendientes de redespliegue, aparte de este

`sg_fuc2iSecgen01` está desplegado pero en una versión anterior: le faltan la regla de días hábiles
y el tope por totales (ver `compensacion_revision.md` §7.1 y §7.5). Mientras tanto ese tope solo lo
aplica la pantalla.

---

## 8. Fuera de alcance, anotado

En `lang/es/pds.js` quedan concordancias `(s)` del flujo de **resolución** —`tramo(s) semanal(es)`,
`cuota(s)`, `mes(es)`, `resultado(s)`—. Es el mismo defecto, pero en pantallas ya desplegadas; no se
tocaron aquí.

---

## 9. Borrador y envío: el orden de la pantalla

### 9.1 El borrador ya existía, solo no se decía

La pantalla no necesitaba un modo borrador nuevo. **`cod_estcuo = 1` (Propuesta) ya es el
borrador**, y no compromete nada:

| | |
| :--- | :--- |
| Se escribe | `sg_epag`, `sg_dpag` y `sg_fume.mto_apagar` |
| No se mueve | `sg_fume.cod_estfum` sigue en 1 |
| Se puede | editar, eliminar, compensar, cambiar montos |

Los meses recién pasan a `cod_estfum = 2` cuando se **envía**, en `sg_epaguSecgen02`. Inventar un
segundo estado de borrador habría significado estado nuevo, PA nuevo y migración —justo lo que no
corresponde hacer— para describir algo que el modelo ya hace.

Lo que faltaba era nombrarlo. *Guardar cuota* pasó a **Guardar como borrador**, la fila lleva una
ficha **Borrador** mientras está en estado 1, y la ayuda lo dice:

> Mientras la cuota esté en borrador no se compromete nada: los meses siguen disponibles y puede
> editarla o eliminarla.

### 9.2 Las validaciones cierran la pantalla

Estaban arriba del todo, donde se leen antes de que exista nada que validar. Ahora el orden sigue
la secuencia de trabajo:

```
Prestación seleccionada      quién y cuánto se autorizó
Meses de ejecución           qué hay para pagar
Compensación horaria         (si corresponde)
Cuotas de pago               lo armado
Formulario de cuota          (al crear o editar)
─────────────────────────────────────────────────
Validaciones normativas      lo último que se revisa
Acciones                     la decisión
```

### 9.3 El envío salió de la fila

*Enviar* era un tercer botón en cada fila de la tabla, junto a Editar y Eliminar, como si fuera
una edición más. No lo es: es la transición que compromete los meses y cierra la edición.

Ahora vive en el pie, bajo las validaciones, con la consecuencia escrita:

> Al enviar, la cuota pasa a visación y sus meses quedan comprometidos. Desde ahí ya no se pueden
> editar.

Cada botón dice por qué está bloqueado, en el aviso y en el `title`:

| Botón | Se habilita cuando |
| :--- | :--- |
| Guardar como borrador | hay un formulario abierto y válido |
| Enviar al siguiente rol | hay una cuota en borrador y ninguna validación bloqueante |

**Si hay más de una cuota en borrador** aparece un selector junto a los botones. Con una sola —el
caso normal— no se muestra. No se envían todas juntas a propósito: cada envío es su propia
transacción y un fallo a mitad dejaría unas enviadas y otras no.

### 9.4 Comprobado

Guardando desde la barra, con la cuota 1 ya creada:

```
sg_epag   cod_estcuo 1 Propuesta
sg_fume   cod_estfum 1 Propuesta · mto_apagar 141.111
```

Nada se comprometió, que es justamente lo que el borrador debe garantizar.

---

## 10. Homologación visual con el estándar

Contrastando la vista de pagos con la de resolución y con
`estandar_visual/estandar_visual_obligatorio_du288.md` (v1.3).

### 10.1 Rellenos de color donde el estándar no los permite

La norma es explícita en dos puntos y la vista los incumplía en siete lugares.

**§6.2** — *«Los bloques informativos, métricas y estados vacíos neutrales NO DEBEN utilizar
relleno gris. Los fondos de color se reservan exclusivamente para estados semánticos.»*

**§5.4** — *«"Seleccionado" o "en edición" NO es un estado semántico — es foco/actividad. DEBE
usar el mismo patrón del foco de un control (borde + resplandor suave), sin relleno de fondo de
color.»*

| Elemento | Tenía | Por qué sobraba | Ahora |
| :--- | :--- | :--- | :--- |
| Resumen de horas | relleno gris | es una métrica | blanco, agrupa el borde |
| Totales de la cuota | relleno gris | es una métrica | blanco |
| Titular de la cuota | relleno azul | es un resumen, no un estado | blanco con filete primario |
| Titular vacío | relleno gris | estado vacío neutral | solo cambia el filete |
| Panel del día | relleno gris | bloque informativo | blanco |
| Día seleccionado | relleno azul + aro | **selección** | borde + resplandor de foco |
| Mes marcado | relleno azul | **selección** | filete interior primario |

El resplandor es literalmente el del estándar, no uno inventado:

```css
box-shadow: 0 0 0 3px rgba(0, 57, 108, 0.12);   /* .pds-du288-scope .form-control:focus */
```

Quedan con fondo de color solo las fichas que **sí** son semánticas: compensación cumplida
(éxito), horas faltantes (advertencia), exceso (información).

### 10.2 Enviar: modal con resumen y destinatario

El envío se confirmaba con un `msgBoxConfirm` de una frase. Ahora hay un modal propio que responde
las dos preguntas que el usuario necesita antes de un paso irreversible: **qué se pide** y **a
quién va**.

```
Enviar cuota a visación

  → Se envía a
    DGDP · Dirección de Gestión y Desarrollo de Personas
    Revisa el cumplimiento normativo y visa la cuota.

  FUNCIONARIO                      CUOTA
  JEANETTE DEL PILAR POZA          N° 1
  ARAVENA · 087962717

  SE PAGA EN
  Octubre 2026

  MESES INCLUIDOS            MONTO SOLICITADO
  Septiembre 2026                    $141.111
  Total solicitado                   $141.111

  ⚠ Al confirmar, los meses de esta cuota quedan comprometidos
    y no se podrán editar ni compensar.

                        Cancelar   [Enviar a visación]
```

El destinatario no es decorativo: la cuota pasa a `cod_estcuo = 2 · En visación`, y quien la toma
desde ahí es DGDP. La advertencia tampoco — describe exactamente lo que hace `sg_epaguSecgen02`:
los meses pasan a `cod_estfum = 2` y con eso dejan de admitir cambios de monto y de compensación.

Cumple §11: centrado, footer real, cancelar a la izquierda de confirmar, sin cierre por `Esc`
mientras la operación corre, y spinner en la acción. Los datos de lectura usan
`.pds-ui-read-field` / `.pds-ui-read-label` / `.pds-ui-read-value`, como pide §6.2 y como ya lo
hace resolución.

### 10.3 Lo que el estándar ya respaldaba

§6.3 cierra con una frase que valida el corte del punto 9:

> Guardar borrador solo valida integridad mínima de persistencia. Enviar valida reglas completas.

Es exactamente el reparto que quedó implementado: el borrador no compromete nada y el envío
revalida la normativa antes de abrir el modal.
