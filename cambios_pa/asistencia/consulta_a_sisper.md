# Consulta al equipo de SISPER — datos de asistencia

Contexto: para el proceso de pago de prestaciones de servicios necesitamos acreditar que el
funcionario ejecutó las horas comprometidas en la resolución. Partimos del procedimiento de
asistencia que nos compartieron y lo adaptamos para consultar por rango de fechas.

Abajo va lo que devuelve la consulta y las dudas que surgieron al revisar los datos.

---

## 1. Qué devuelve la consulta

Una fila por día, con estas columnas:

| Columna | Origen |
| :--- | :--- |
| `cod_asist` | `sp_as01` |
| `fecha` · `fec_asist` | `sp_as01.f_ent_o` |
| `cod_diasem` · `des_diasem` | calculado |
| `hora_marca_ent` · `hora_marca_sal` | `sp_as01.f_entrada` / `f_salida` |
| `hora_turno_ent` · `hora_turno_sal` | `sp_as01.hora_ent_o` / `hora_sal_o` |
| `min_marcados` · `min_turno` | calculado |
| `cod_turno` · `ver_hora` | `sp_turn` |
| `cod_estasi` · `des_estasi` | `sp_easi` |
| `tie_ausenc` · `res_ausen` | `sp_as21` + `sp_eaus` |
| `tie_justif` · `excusa` | `sp_as31` + `sp_tjus` + `sp_cjus` |
| `es_feriado` · `cod_tipfer` · `des_tipfer` | `es_cfer` + `es_tfer` |
| `min_atraso` · `min_anticip` | calculado |
| `tol_entrad` · `tol_salida` | `sp_pasi` |

---

## 2. Ejemplos reales del resultado

### Día normal

```
cod_asist        6374
fecha            20160302   Miercoles
marca            08:23 - 17:27
turno            08:30 - 17:20
min_marcados     544        min_turno  530
estado           2 Completo
```

### Entrada tardía con salida tardía

```
cod_asist        6506
fecha            20160712   Martes
marca            09:19 - 18:24
turno            08:30 - 17:20
min_marcados     544        min_turno  530
estado           2 Completo
min_atraso       44   (calculado por nosotros, 49 min menos 5 de tolerancia)
```

### Entrada tardía sin compensar

```
cod_asist        6431
fecha            20160428   Jueves
marca            09:41 - 17:34
min_marcados     473        min_turno  530      (57 minutos menos que el turno)
min_atraso       66
```

### Día incompleto

```
cod_asist        6379
fecha            20160307   Lunes
marca            (sin entrada) - 17:49
min_marcados     (nulo)
estado           3 Incompleto
```

### Feriado trabajado

```
cod_asist        887954
fecha            20161010   Lunes
marca            08:24 - 17:23
estado           2 Completo
es_feriado       S    tipo 1 Feriado Nacional
```

### Día con justificación

```
cod_asist        887969
fecha            20161025   Martes
marca            08:29 - (sin salida)
estado           3 Incompleto
excusa           Error en  Biometrico / Laboral
```

### Salida en 00:00

```
cod_asist        5779
fecha            20160807   Domingo
marca            (sin entrada) - 00:00
estado           3 Incompleto
min_anticip      1035       (resultado absurdo de tomar 00:00 como hora valida)
```

### Dos registros para el mismo día

```
cod_asist   860014   20160901   turno 08:30-17:18   estado 0 Estado inicial   sin marca
cod_asist     6550   20160901   turno 08:30-17:20   estado 2 Completo         08:23 - 17:41
```

Se repite del 01 al 11 de septiembre de 2016.

---

## 3. Consultas

### 3.1 Horario flexible — la más importante

Entendemos que existe una ventana de entrada flexible: quien llega después de las 08:30 puede
hacerlo hasta cierta hora y compensar ese tiempo el mismo día.

- **¿Existe esa ventana y cuál es su rango?**
- **¿La columna `sp_as01.min_atraso` ya la considera**, o sólo aplica la tolerancia de 5 minutos
  de `sp_pasi.tol_entrad`?

Lo preguntamos porque nosotros estamos recalculando el atraso y probablemente nos dé distinto
del valor oficial del módulo.

### 3.2 Criterio de `min_extras`

`sp_as01` trae `min_atraso`, `min_adelan` y `min_extras` ya calculados.

**¿`min_extras` cuenta el tiempo posterior al término del turno, o el saldo neto del día?**

Ejemplo del caso 6506: entró 09:19 y salió 18:24. Salió 64 minutos después del turno, pero llegó
49 tarde, así que el saldo neto es de sólo 15 minutos.

Nos importa porque para acreditar horas de una prestación necesitamos el excedente real, no el
tiempo posterior al turno.

### 3.3 Registros duplicados

Del 01 al 11 de septiembre de 2016 hay **dos filas por día** para el mismo RUT, con `cod_asist`
de series distintas y horarios de turno distintos (17:18 y 17:20).

**¿A qué corresponde? ¿Cuál registro debe considerarse válido?**

### 3.4 Marcas en `00:00`

Varias filas traen `f_salida = 00:00:00`.

**¿Significa "sin dato" o es una marca real a medianoche?**

### 3.5 Estados 1 y 4

El catálogo `sp_easi` tiene cinco estados; en los datos sólo aparecen 0, 2 y 3.

- **¿Cuándo se usa `1 Editado`?** ¿Quién puede editar un registro y queda traza?
- **¿Cuándo se usa `4 Error`?**

### 3.6 Estado 3 Incompleto

Cuando sólo hay una marca, **¿existe alguna forma de saber cuánto tiempo estuvo la persona?**
¿Hay un proceso posterior que complete esos registros?

### 3.7 Lectores biométricos

`sp_as01` trae `id_lect_e` e `id_lect_s`.

**¿Los lectores están asociados a una ubicación física** (edificio, facultad, dependencia)?

Si lo estuvieran, nos permitiría saber si la persona marcó en el lugar donde debía ejecutar la
prestación.

### 3.8 Marcas intermedias

**¿`f_ent_int` y `f_sal_int` corresponden a la salida y retorno de colación?** ¿Se registran
siempre o sólo en algunos turnos?

### 3.9 `cod_tipmar` en `sp_as31`

La tabla de justificaciones trae `cod_tipmar`.

**¿Qué valores toma y a qué marca se refiere** (entrada, salida, intermedias)?

### 3.10 Ausencias reales

En el ambiente de prueba, `sp_as21` no tiene registros para el funcionario que revisamos, aunque
el catálogo `sp_eaus` sí incluye licencias médicas y permisos sin goce.

**¿El módulo registra efectivamente las licencias médicas en producción**, o llegan por otra vía?

Esta es clave para nosotros: si las licencias están ahí, podemos validar día a día qué periodos
no son pagables.

### 3.11 Turnos sin marcaje

`sp_turn` tiene tres turnos con `ver_hora = 'N'` (3, 15 y 16).

**¿Corresponden a funcionarios sin obligación de marcar?** ¿Hay alguna otra forma de acreditar
su jornada?

---

## 4. Lo que ya resolvimos con los datos

Para que no repitan trabajo, estas dudas quedaron respondidas con lo que nos compartieron:

- El catálogo de feriados es **`es_tfer`** (no `es_tipfer`).
- `sp_as21` es **1:N**: un día puede tener varias ausencias. Confirmado con `cod_asist` 6241.
- El horario está en **`sp_as01`**, no en `sp_turn`: un mismo `cod_turno` aparece con horarios
  distintos según la fecha.
- `sp_eaus.res_ausen` viene **truncado a 15 caracteres**; usamos `des_ausen`.
- `sp_pasi` tiene una sola fila, con tolerancia de **5 minutos** en entrada y salida.
- `sp_pasi.n_dias_jus` está **vacío**.
