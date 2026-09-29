# Qué necesita el PA de asistencia para el WF de pagos

Partiendo de lo que el script original hace y de lo que el flujo de pagos tiene que validar.

---

## 1. Las tres preguntas que hay que responder

| Pregunta del WF | Qué se necesita saber por día |
| :--- | :--- |
| ¿Cumplió el horario comprometido del mes? | si hubo marca, a qué hora, y **cuántos minutos** |
| ¿Se cumplió la compensación comprometida? | lo mismo, en las fechas específicas comprometidas |
| ¿Trabajó durante el receso? | si el día era feriado **y aun así** hay marca |

Las tres se responden con el mismo detalle diario. No hacen falta tres consultas.

---

## 2. El cambio de fondo: el calendario completo, no sólo lo registrado

El script original devuelve **sólo los días que existen en `sp_as01`**. Para el WF de pagos eso
no alcanza, porque la pregunta central es al revés:

> El horario comprometido dice que trabajaba lunes y miércoles. ¿**Faltó** alguno?

Un día comprometido sin marca no aparece en el resultado, así que el consumidor no puede
distinguir *"no trabajó"* de *"el día no está en el rango"*.

**El PA debe devolver una fila por cada día del rango**, con o sin registro, y una bandera que
diga cuál es cuál. Así el contraste contra el horario comprometido se vuelve un `join` directo.

---

## 3. Datos disponibles en la fuente

De las tablas que el script recorre:

| Origen | Dato | ¿Lo devuelve el script? |
| :--- | :--- | :---: |
| `sp_as01` | fecha del registro | sí |
| `sp_as01` | marca real de entrada y salida | sí |
| `sp_as01` | horario del turno | sí |
| `sp_as01` | estado de asistencia | sí |
| `sp_as01` | identificador del registro | **no** |
| `sp_easi` | descripción del estado | sí |
| `sp_turn` | si el marcaje es exigible | parcial, oculto tras un literal |
| `sp_as21` + `sp_eaus` | motivo de ausencia | sí, pero **siempre nulo** |
| `sp_as31` + `sp_tjus`/`sp_cjus` | justificación | sí, **sólo una** |
| `es_cfer` + `es_tfer` | feriado o receso | sí, pero **siempre nulo** |
| — | **minutos trabajados** | **no, y hace falta** |
| — | **días sin registro** | **no, y hace falta** |

Los dos últimos son los que el WF necesita y la fuente no entrega directamente: hay que
calcularlos.

---

## 4. Contrato propuesto

### Entrada

```
@rut         char(9)   obligatorio
@f_inicio    char(8)   obligatorio, YYYYMMDD
@f_termino   char(8)   obligatorio, YYYYMMDD
```

Rango libre, no código de periodo: el periodo de una cuota lo define la prestación, y `sp_prdo`
es de otro dominio y está sin cargar desde 2017.

### Salida — una fila por día del rango

| Columna | Tipo | Qué es |
| :--- | :--- | :--- |
| `fecha` | `char(8)` | `YYYYMMDD`, ordenable |
| `cod_diasem` | `tinyint` | 1 = lunes … 7 = domingo, **normalizado** |
| `des_diasem` | `varchar(10)` | nombre del día |
| `tie_regist` | `char(1)` | **S/N — ¿hay registro de asistencia ese día?** |
| `cod_asist` | `int` | identificador del registro, nulo si no hay |
| `hora_marca_ent` | `char(5)` | marca real de entrada |
| `hora_marca_sal` | `char(5)` | marca real de salida |
| `min_marcados` | `int` | **minutos entre ambas marcas** |
| `hora_turno_ent` | `char(5)` | horario que correspondía |
| `hora_turno_sal` | `char(5)` | horario que correspondía |
| `min_turno` | `int` | **minutos del turno** |
| `ver_hora` | `char(1)` | S/N — si el marcaje es exigible para ese turno |
| `cod_estasi` | `tinyint` | estado de asistencia |
| `des_estasi` | `varchar(40)` | descripción del estado |
| `tie_ausenc` | `char(1)` | S/N |
| `res_ausen` | `varchar(255)` | **todos** los motivos, separados |
| `tie_justif` | `char(1)` | S/N |
| `excusa` | `varchar(255)` | **todas** las justificaciones, separadas |
| `es_feriado` | `char(1)` | S/N |
| `cod_tipfer` | `tinyint` | tipo de feriado |
| `des_tipfer` | `varchar(60)` | descripción del feriado |

**21 columnas.** El script original devuelve 11, de las cuales 3 vienen vacías.

---

## 5. Por qué cada agregado

### `tie_regist` — la bandera que falta

Sin ella no se puede distinguir un día sin marca de un día fuera del rango. Es la columna que
habilita la validación de cumplimiento.

### `min_marcados` y `min_turno`

El WF valida horas, no horarios. Comparar dos cadenas `"08:27"` y `"08:30"` obliga al consumidor
a parsear; devolver minutos lo resuelve en la base, donde están los datos.

`min_turno` sirve de referencia: permite responder *"marcó 380 de 420 minutos"* sin tener que
consultar el turno aparte.

### `cod_asist`

Sin el identificador el consumidor no puede correlacionar una fila con el registro de origen ni
pedir detalle adicional.

### `tie_ausenc` y `tie_justif`

Evitan que el consumidor tenga que interpretar si una cadena vacía significa *"no hubo"* o
*"hubo pero no se pudo leer"* — que es exactamente lo que pasa hoy con el bug del cursor.

### `es_feriado` además de `cod_tipfer`

La pregunta *"¿trabajó en receso?"* se responde con `es_feriado = 'S' and tie_regist = 'S'`. Un
solo predicado, sin interpretar nulos.

### `cod_diasem` normalizado

El script usa `datepart(cdw, ...)`, que depende de `@@datefirst` del servidor. El PA debe
normalizar a **1 = lunes** de forma explícita, para que el resultado no dependa de la
configuración de la sesión.

---

## 6. Lo que el PA **no** hace

| No hace | Por qué |
| :--- | :--- |
| Comparar contra el horario comprometido | no conoce la prestación; eso se cruza en el consumidor |
| Decidir si el mes es pagable | es una regla de negocio |
| Totalizar por mes | se agrega trivialmente sobre el detalle |
| Reemplazar la hora por `"T.S.H."` | devuelve el dato y la bandera; decide el negocio |
| Devolver HTML | el separador es neutro |

---

## 7. Cómo se usa después

```
horario comprometido (resolución)          asistencia (este PA)
  lunes    09:00–12:00                       una fila por día del rango
  miércoles 14:00–17:00
              │                                       │
              └───────────── join por fecha ──────────┘
                              │
                    ¿tie_regist = 'N' en un día comprometido?  → no cumplió
                    ¿min_marcados < min comprometidos?          → cumplió parcial
                    ¿es_feriado = 'S' y tie_regist = 'S'?       → trabajó en receso
```

La comparación vive en el backend, que es quien conoce el horario comprometido. El PA sólo
entrega el lado de la asistencia, completo y sin huecos.

---

## 8. Consideraciones de implementación

### Generar la serie de fechas

ASE 12.5 no tiene generador de series. Se resuelve con un `while` que inserta en una temporal:
acotado, porque el rango de una cuota no pasa de unos cientos de días. Conviene **limitar el
rango a 400 días** y devolver error si se excede, para no dejar un bucle abierto.

### Cardinalidad

Con el calendario completo, el resultado es siempre `f_termino − f_inicio + 1` filas. Si sale
más, hay un join duplicando — y es exactamente la verificación que hay que correr contra el
script original.

### Rendimiento

Una cuota abarca como mucho 12 meses. Con índice por `(rut, f_ent_o)` en `sp_as01`, el detalle
diario es una lectura acotada.

---

## 9. Pendiente de confirmar contra el ambiente

1. `select @@datefirst` — para normalizar el día de la semana.
2. Si el catálogo es `es_tfer` o `es_tipfer`.
3. Si `es_cfer` tiene entradas por sede o unidad, o sólo por fecha.
4. Si `sp_as31` admite varias justificaciones por asistencia.
5. Si `f_entrada`/`f_salida` son el turno y `hora_ent_o`/`hora_sal_o` la marca, o al revés.
6. Hasta qué fecha llega `sp_as01`:

```sql
select convert(char(10), min(f_ent_o), 103) as primera,
       convert(char(10), max(f_ent_o), 103) as ultima,
       count(*) as registros
from sisper_db..sp_as01
```

El punto 6 es el que decide si esto sirve: si los datos terminan en 2017 como `sp_prdo`, la
validación de cumplimiento vuelve a quedar sin fuente.
