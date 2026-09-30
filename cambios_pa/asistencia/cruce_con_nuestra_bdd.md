# Cruce de la asistencia con nuestras tablas

Qué se puede determinar de la ejecución, los descuentos y las compensaciones, cruzando el
registro de asistencia de SISPER con lo que tenemos en `secgen_db`.

---

## 1. El mapeo — qué columna nuestra se llena con qué dato

| Nuestra columna | Tabla | Se determina con | Cómo |
| :--- | :--- | :--- | :--- |
| `val_licmed` | `sg_fume` | `sp_as21` grupo **2** | `S` si algún día del mes tiene licencia |
| `val_singoce` | `sg_fume` | `sp_as21` grupo **1**, cod **2** | `S` si algún día tiene permiso sin goce |
| `val_ciecc` | `sg_fume` | nuestro `sg_prse` + FIN21 | no viene de asistencia |
| `val_inabili` | `sg_fume` | `sg_fupssSecgen14` / `15` | no viene de asistencia |
| `mto_deslic` | `sg_fume` | días con licencia ÷ días hábiles | proporción sobre `mto_apagar` |
| `mto_dessg` | `sg_fume` | días sin goce ÷ días hábiles | idem |
| `mto_realpa` | `sg_fume` | `mto_apagar − mto_deslic − mto_dessg` | resultado |
| `ano_ejec` · `mes_ejec` | `sg_fume` | mes con actividad confirmada | del propio cruce |
| `fec_valida` | `sg_fume` | fecha en que corrió la validación | del proceso |
| **filas de `sg_fuc2`** | `sg_fuc2` | marcas fuera del turno en las fechas de `sg_fuco` | **la compensación efectiva se deriva de la asistencia** |

La última fila es la más importante: **`sg_fuc2` no lo teclea nadie.** Se construye cruzando las
fechas comprometidas en `sg_fuco` contra las marcas reales.

---

## 2. Lo que aporta cada una de nuestras tablas al cruce

| Tabla | Qué aporta | Grano |
| :--- | :--- | :--- |
| `sg_fups.dentro_jor` | **decide qué se valida**: ejecución o compensación | prestación |
| `sg_fups.f_inicio` / `f_termino` | el rango a consultar en asistencia | prestación |
| `sg_fuho` | horario comprometido: **día de la semana** + tramo | recurrente |
| `sg_fuco` | compensación comprometida: **fecha exacta** + tramo | fecha |
| `sg_fume.ano_prop` / `mes_prop` | los meses que la cuota cubre | mes |
| `sg_fuc2` | compensación efectivamente realizada | fecha |

`sg_fuho` es recurrente y `sg_fuco` tiene fechas. Esa diferencia cambia el cruce: el horario hay
que **proyectarlo** sobre el rango; la compensación ya viene con fecha.

---

## 3. Ejemplo trabajado — marzo 2016

Con los datos reales de la muestra. Supongamos una prestación así:

```
sg_fups    f_inicio 2016-03-01   f_termino 2016-03-31
           dentro_jor = 'N'      fuera de jornada
           mto_total  400.000    mto_tope 450.000

sg_fuho    cod_diasem 1 (lunes)      18:00 - 20:00
           cod_diasem 3 (miercoles)  18:00 - 20:00
```

### Paso 1 — proyectar el horario comprometido

Lunes y miércoles de marzo 2016:

```
07, 09, 14, 16, 21, 23, 28, 30   →  8 dias comprometidos
2 horas cada uno                 →  16 horas = 960 minutos
```

### Paso 2 — traer la asistencia de esos días

| Fecha | Día | Marca | min marcados | Excedente sobre el turno |
| :--- | :--- | :--- | ---: | ---: |
| 20160307 | Lunes | — – 17:49 | *nulo* | **Incompleto** |
| 20160309 | Miércoles | 08:23 – 17:37 | 553 | +23 |
| 20160314 | Lunes | 08:27 – 17:29 | 542 | +12 |
| 20160316 | Miércoles | 08:18 – 17:25 | 546 | +16 |
| 20160321 | Lunes | 08:32 – 17:28 | 536 | +6 |
| 20160323 | Miércoles | 08:18 – 17:21 | 542 | +12 |
| 20160328 | Lunes | 08:28 – 17:25 | 536 | +6 |
| 20160330 | Miércoles | 08:37 – 17:40 | 542 | +12 |

### Paso 3 — comparar

```
comprometido      960 minutos
excedente real     87 minutos   (sin contar el dia Incompleto)
salida mas tardia  17:40        el compromiso empezaba a las 18:00
```

**Conclusión: la prestación no se acredita.** Ningún día muestra trabajo después de las 18:00, y
el excedente acumulado es 9 % de lo comprometido.

### El mes completo, para contexto

Sumando todos los días con marca de marzo: **+342 minutos** de excedente, 5 horas 42 minutos. Aun
contando todo el mes y no sólo los días comprometidos, no alcanza para 16 horas.

---

## 4. El mismo ejercicio para compensación

Si la prestación fuera **dentro de jornada** (`dentro_jor = 'S'`), lo comprometido serían fechas
exactas en `sg_fuco`:

```
sg_fuco   2016-03-09  18:00 - 20:00
          2016-03-16  18:00 - 20:00
```

El cruce es el mismo, pero sin proyectar. Y con el mismo resultado: las marcas del 09 y del 16
terminan a las 17:37 y 17:25. **La compensación no se acredita.**

Y `sg_fuc2` quedaría vacía, porque no hay tramo fuera del turno que registrar.

---

## 5. Descuentos

En marzo 2016 no hay ninguna fila en `sp_as21`, así que:

```
val_licmed  = 'N'      mto_deslic = 0
val_singoce = 'N'      mto_dessg  = 0
mto_realpa  = mto_apagar
```

Si hubiera licencia, el cálculo sería por días:

```
marzo 2016      31 dias corridos
                22 dias habiles  (sin sabados, domingos ni el 25 y 26 feriados)

licencia del 07 al 11   →  5 dias habiles afectados

mto_deslic = mto_apagar × 5 / 22
```

El dato de días viene de la asistencia; la proporción la calcula nuestro PA.

---

## 6. Qué se puede determinar y qué no

| | ¿Se puede? | Con qué |
| :--- | :---: | :--- |
| ¿Existió el día comprometido? | **Sí** | la fila existe siempre |
| ¿Era día hábil? | **Sí** | `es_feriado` + día de semana |
| ¿Trabajó ese día? | **Sí** | `cod_estasi = 2` |
| ¿Cuánto tiempo estuvo? | **Sí** | `min_marcados` |
| ¿Trabajó fuera de su turno? | **Sí** | excedente = `min_marcados − min_turno` |
| ¿Cubrió el tramo comprometido? | **Sí** | comparar la marca contra `sg_fuho` / `sg_fuco` |
| ¿Hubo licencia o sin goce? | **Sí**, por día | `sp_as21` grupos 2 y 1-2 |
| ¿Cuánto descontar? | **Sí** | proporción de días hábiles afectados |
| ¿Trabajó en receso? | **Sí** | `es_feriado` + `cod_tipfer = 2` + marca |
| ¿Se hizo la compensación? | **Sí** | marcas fuera del turno en las fechas de `sg_fuco` |
| **¿Ese tiempo fue de la prestación?** | **No** | el reloj no registra el motivo |
| **¿Hizo la actividad comprometida?** | **No** | sólo el PDF lo acredita |

**Diez de doce.** Las dos que no son las mismas de siempre: la asistencia acredita que el tiempo
existió, no para qué se usó.

---

## 7. Las condiciones que tienen que darse

Para que este cruce funcione en producción:

| # | Condición | Estado |
| :-- | :--- | :--- |
| 1 | Que `sp_as21` registre licencias reales | **por confirmar** — está vacía en pruebas |
| 2 | Que el excedente se calcule neto, no por hora de salida | resuelto: `min_marcados − min_turno` |
| 3 | Que se sepa si hay ventana de horario flexible | **por confirmar** con SISPER |
| 4 | Que se defina qué hacer con los días Incompletos | **pendiente** |
| 5 | Que se defina cuál registro vale cuando hay duplicados | **pendiente** |
| 6 | Que `sg_fuho` y `sg_fuco` estén poblados al momento del pago | dependen de la resolución |

La **1** es la que decide si los descuentos por licencia son automáticos o quedan a criterio de
DGDP. Las **4** y **5** son nuestras y se pueden cerrar sin esperar a nadie.

---

## 8. Lo que este ejemplo enseña

El caso de marzo 2016 no acredita la prestación, y eso es **útil**: muestra que el cruce
efectivamente discrimina. Si el funcionario hubiera trabajado 18:00–20:00 los lunes y miércoles,
las marcas de salida estarían cerca de las 20:00 y el excedente rondaría los 960 minutos.

Lo que el cruce responde con precisión es *"¿hubo tiempo fuera del turno en las fechas
comprometidas?"*. Lo que no puede responder es *"¿ese tiempo se dedicó a la actividad de la
prestación?"* — y para eso el WF ya exige el PDF de respaldo.
