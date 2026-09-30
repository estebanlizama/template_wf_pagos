# Validaciones de ejecución y compensación contra asistencia

Cómo se comparan el horario comprometido en la resolución y las compensaciones contra el
registro de asistencia, y qué se puede identificar de licencias y permisos.

---

## 1. La distinción que ordena todo: dentro o fuera de jornada

`sg_fups.dentro_jor` decide **qué es verificable con asistencia y qué no**.

### Fuera de jornada — `dentro_jor = 'N'`

La prestación se ejecuta **además** del turno habitual. El funcionario cumple su jornada y
después hace la actividad.

```
turno       08:30 ─────────────────── 17:18
prestacion                                    18:00 ──── 21:00
```

La asistencia **sí lo ve**: la marca de salida se corre, o quedan minutos extra. Es directamente
verificable.

### Dentro de jornada — `dentro_jor = 'S'`

La prestación se ejecuta **durante** el turno. Las horas comprometidas están adentro del horario
normal.

```
turno       08:30 ─────────────────── 17:18
prestacion              09:00 ── 12:00
```

La asistencia **no lo distingue**: marcó igual que cualquier otro día. No hay forma de saber si
esas tres horas fueron para la prestación o para su trabajo habitual.

**Por eso el decreto exige compensación en este caso.** Y la compensación sí ocurre fuera del
turno, así que **esa sí es verificable**.

> Consecuencia de diseño: la asistencia no valida lo mismo en los dos casos. En *fuera de
> jornada* valida la **ejecución**; en *dentro de jornada* valida la **compensación**.

---

## 2. Validar la ejecución — sólo si es fuera de jornada

### Lo que se compara

| Origen | Qué aporta |
| :--- | :--- |
| `sg_fuho` | horario comprometido: **día de la semana** + tramo horario |
| PA de asistencia | lo que ocurrió cada día del periodo |

`sg_fuho` es **recurrente**: guarda *"lunes 18:00-21:00"*, no fechas. Hay que proyectarlo sobre
el rango de la cuota para obtener las fechas concretas.

### El procedimiento

```
1. Proyectar sg_fuho sobre el rango
      cod_diasem = 1  →  todos los lunes entre f_inicio y f_termino
      resultado: lista de fechas con su tramo comprometido

2. Unir con la asistencia por fecha

3. Por cada fecha comprometida:

      ¿es feriado?
         tipo 2 receso        → solo cuenta si hubo marca (trabajo en receso)
         tipo 1 o 3           → el compromiso no era exigible ese dia
      ¿hay ausencia?
         grupo 2 licencia     → el dia no se ejecuto
         grupo 1 cod 2        → el dia no se ejecuto
      ¿hay justificacion 11, 13 o 15?
         si                   → fallo el reloj, el dia cuenta
      ¿cod_estasi?
         2 Completo           → comparar la marca contra el tramo
         3 Incompleto         → ambiguo
         0                    → no se ejecuto
```

### La comparación del tramo

Para un compromiso de 18:00 a 21:00 con turno que termina 17:18:

| Indicador | Qué dice |
| :--- | :--- |
| `f_salida >= 21:00` | cubrió el tramo completo |
| `min_extras >= 180` | trabajó al menos los minutos comprometidos |
| `f_sal_int` / `f_ent_int` | si hubo corte entre jornada y prestación, queda registrado |

`min_extras` es el indicador más simple: ya viene calculado en `sp_as01` y no depende de
interpretar horas.

---

## 3. Validar la compensación — el caso de dentro de jornada

### Lo que se compara

| Origen | Qué aporta |
| :--- | :--- |
| `sg_fuco` | compensación comprometida: **fecha exacta** + tramo |
| `sg_fuc2` | compensación efectivamente realizada, por cuota |
| PA de asistencia | si esa fecha muestra trabajo fuera del turno |

A diferencia de `sg_fuho`, `sg_fuco` **ya tiene fechas concretas**. No hay que proyectar nada.

### El procedimiento

```
por cada fecha comprometida en sg_fuco:

   traer el dia desde el PA de asistencia

   ¿la marca se extiende mas alla del turno?
      f_salida  >  hora_sal_o   →  compenso despues de su jornada
      f_entrada <  hora_ent_o   →  compenso antes
      min_extras >= minutos comprometidos  →  cubrio el tramo

   ¿el dia era habil?
      es_feriado = 'S' y hubo marca  →  compenso en dia no laboral
```

### Por qué esto sí funciona

La compensación **tiene que ocurrir fuera del turno** — ese es su sentido: devolver las horas
que se usaron del horario institucional. Y todo lo que pasa fuera del turno queda en
`min_extras` o en marcas corridas.

Es la validación más sólida de las tres: fecha exacta, tramo exacto, y un indicador que el
módulo ya calcula.

---

## 4. Identificar licencia, permiso sin goce y demás

### Directo, y por día

```sql
sp_as21 → sp_eaus

tip_agraus = 2                 →  licencia medica    (7 tipos)
tip_agraus = 1 and cod = 2     →  permiso sin goce
tip_agraus = 1 and cod = 5     →  vacaciones
tip_agraus = 3                 →  comision de servicio
```

### Los siete tipos de licencia

| cod | Tipo |
| :---: | :--- |
| 1 | Enfermedad o Accidente No del Trabajo |
| 2 | Prórroga Medicina Preventiva |
| 3 | Licencia Maternal |
| 4 | Enfermedad Grave Hijo Menor de 1 Año |
| 5 | Accidente del Trabajo |
| 6 | Enfermedad Profesional |
| 7 | Patología del Embarazo |

El decreto no distingue entre ellos: cualquiera impide pagar el periodo cubierto. Pero conviene
guardar cuál fue, porque la causal queda en el expediente.

### El prorrateo se vuelve posible

Como el registro es **por día**, un mes con licencia parcial no bloquea el mes completo:

```
mes de 30 dias, 22 habiles
licencia del 05 al 14  →  8 dias habiles con licencia

monto del mes × (22 - 8) / 22
```

Eso responde Q-H03 de S0-013 —*"¿una superposición parcial bloquea toda la cuota o calcula
proporción?"*— con un dato que ya existe.

### `correlativ` agrupa el periodo

Las ausencias largas comparten `correlativ`, que referencia el documento que las autoriza. Eso
permite reconstruir *"licencia del 5 al 14, resolución 109803"* sin recorrer día a día.

> El campo no está normalizado: en los datos aparece `1117` y `01117`. Hay que limpiarlo antes
> de usarlo como llave.

---

## 5. Lo que **no** se puede verificar, y por qué

### La actividad comprometida

El reloj registra **presencia**, no contenido. Una prestación compromete *"apoyo técnico de
laboratorio"*; la asistencia sólo dice que estuvo entre las 18:00 y las 21:00.

**El PDF de respaldo sigue siendo la única evidencia de qué se hizo.** La asistencia lo
complementa: acredita que el tiempo existió.

### La prestación dentro de jornada

Si `dentro_jor = 'S'`, no hay ninguna señal en la asistencia que separe las horas de la
prestación de las del trabajo habitual. Se validan por su sombra: **la compensación**.

### El lugar

`id_lect_e` / `id_lect_s` identifican **el reloj** por el que marcó. Si los lectores estuvieran
asociados a una ubicación, se podría aproximar *"¿estuvo donde debía?"*.

**No está verificado.** Vale la pena preguntarlo: sería el único dato que acerca la asistencia
al lugar de la prestación.

### Tres situaciones sin respuesta en los datos

| | |
| :--- | :--- |
| **Día Incompleto** | una sola marca; no se deduce cuánto estuvo |
| **Días duplicados** | dos filas para el mismo día, una con marca y otra sin |
| **Día Editado** | corregido a mano, no viene del reloj |

---

## 6. Resumen

| Validación | Fuente | ¿Verificable? |
| :--- | :--- | :---: |
| Ejecución **fuera** de jornada | `sg_fuho` + marcas + `min_extras` | **Sí** |
| Ejecución **dentro** de jornada | — | **No** — se valida por la compensación |
| Compensación comprometida | `sg_fuco` + marcas fuera del turno | **Sí** |
| Compensación efectiva | `sg_fuc2` + asistencia | **Sí** |
| Licencia médica | `sp_as21` grupo 2 | **Sí**, por día |
| Permiso sin goce | `sp_as21` grupo 1 cod 2 | **Sí**, por día |
| Vacaciones | `sp_as21` grupo 1 cod 5 | **Sí**, por día |
| Comisión de servicio | `sp_as21` grupo 3 | **Sí**, por día |
| Trabajo en receso | `es_feriado` + `cod_tipfer = 2` + marca | **Sí** |
| Prorrateo por días de ausencia | conteo de días hábiles afectados | **Sí** |
| Actividad efectivamente realizada | — | **No** — PDF |
| Lugar de la prestación | `id_lect_*` | **Por confirmar** |

**Diez de doce validaciones son verificables hoy**, sin integración nueva. Las dos que no, se
cubren con el respaldo documental que el WF ya exige.

---

## 7. Lo que hay que definir

| # | Decisión | Bloquea |
| :-- | :--- | :--- |
| 1 | Días duplicados: ¿cuál prima? | toda la validación diaria |
| 2 | Estado 3 Incompleto: ¿acredita? | el conteo de días ejecutados |
| 3 | Estado 1 Editado: ¿evidencia válida? | la solidez de la acreditación |
| 4 | Vacaciones: ¿interrumpen la prestación? | el prorrateo |
| 5 | Comisión: trabajó, pero no en lo comprometido | el prorrateo |
| 6 | Feriado tipo 3: no debería bloquear | la regla de receso |
| 7 | Justificaciones 11, 13, 15: deberían acreditar | el conteo de días |
| 8 | Tolerancia sobre el tramo comprometido | la comparación de horas |

La **8** es nueva y vale la pena explicitarla: existe una tolerancia institucional de 5 minutos
para el turno. ¿Aplica igual al tramo comprometido de una prestación, o ahí se exige exactitud?
