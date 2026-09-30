# `sisper_db..sp_as01` — registro diario de asistencia

La tabla central del módulo. **Una fila por funcionario y día calendario**, incluidos fines de
semana y feriados.

---

## Estructura

| Columna | Qué es |
| :--- | :--- |
| `cod_asist` | PK. Correlativo global, lo asignan desde `sp_pasi` |
| `rut` | funcionario, sin guion ni dígito verificador separado |
| `f_ent_o` | fecha del registro |
| `f_sal_o` | fecha de salida — distinta de `f_ent_o` sólo si el turno cruza medianoche |
| `hora_ent_o` | **horario de entrada que le correspondía** ese día |
| `hora_sal_o` | **horario de salida que le correspondía** |
| `f_entrada` | **marca real de entrada** |
| `f_salida` | **marca real de salida** |
| `f_ent_int` | marca de entrada **intermedia** — retorno de colación |
| `f_sal_int` | marca de salida **intermedia** — salida a colación |
| `id_lect_e` | lector biométrico por el que marcó la entrada |
| `id_lect_s` | lector biométrico de la salida |
| `min_atraso` | **minutos de atraso, ya calculados** |
| `min_adelan` | **minutos de salida anticipada, ya calculados** |
| `min_extras` | **minutos extra, ya calculados** |
| `cod_estasi` | estado del día → `sp_easi` |
| `cod_turno` | turno asignado → `sp_turn` |

---

## Lo que hay que tener claro

### El horario está en la fila, no en el turno

`hora_ent_o` / `hora_sal_o` son el horario asignado **a ese día en particular**, copiado en el
registro. `sp_turn` no guarda horas: guarda referencias (`cod_jorper`, `cod_hora`) y parámetros.

Se comprobó con datos: un mismo `cod_turno = 1` devuelve 17:20 en registros de 2016 y 17:18 en
los posteriores.

### Los minutos ya vienen calculados

`min_atraso`, `min_adelan` y `min_extras` **están en la tabla**. No hay que recalcularlos desde
las horas: el módulo ya aplicó su propia regla, incluida la tolerancia de `sp_pasi`.

### Hay marcas intermedias

`f_ent_int` / `f_sal_int` registran la colación. Para calcular tiempo efectivamente trabajado
hay que descontarlas:

```
trabajado = (f_salida - f_entrada) - (f_ent_int - f_sal_int)
```

---

## Relaciones

```
sp_as01 ──── cod_estasi ────► sp_easi    estado del día
        ──── cod_turno  ────► sp_turn    turno
        ◄─── cod_asist  ──── sp_as21     ausencias del día   (1:N)
        ◄─── cod_asist  ──── sp_as31     justificaciones     (1:N)
```

---

## Observaciones sobre los datos

**Días duplicados.** Se encontraron 11 días (01 al 11 de septiembre de 2016) con **dos filas**
para el mismo RUT, con `cod_asist` de series distintas (6xxx y 860xxx) y horarios de turno
distintos. Parece una recarga solapada. Hay que definir qué registro vale cuando esto ocurre.

**Marcas en `00:00`.** Varias filas traen `f_salida = 00:00`, que no es medianoche sino
*sin dato*. Tratarla como hora válida produce cálculos absurdos.

**Fechas con hora `01:00`.** Algunos `f_ent_o` traen `01:00:00` en vez de `00:00:00`. Cualquier
comparación por fecha debe normalizar con `convert(char(8), f_ent_o, 112)`.

---

## Uso en el WF de pagos

Responde *"¿trabajó este día y cuánto?"*. Se cruza con el horario comprometido en la resolución:

| Pregunta | Columnas |
| :--- | :--- |
| ¿Hubo actividad? | `cod_estasi` |
| ¿A qué hora llegó y salió? | `f_entrada`, `f_salida` |
| ¿Cuánto se atrasó? | `min_atraso` |
| ¿Salió antes? | `min_adelan` |
| ¿Trabajó de más? | `min_extras` |
| ¿Cuánto tiempo neto? | descontando `f_sal_int` / `f_ent_int` |
