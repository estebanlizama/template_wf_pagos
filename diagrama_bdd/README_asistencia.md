# Modelo de asistencia — índice

Una ficha por tabla, con su estructura, contenido real y uso en el WF de pagos.

| Archivo | Tabla | Rol |
| :--- | :--- | :--- |
| [diagrama_sp_as01.md](./diagrama_sp_as01.md) | `sisper_db..sp_as01` | **Registro diario** — una fila por funcionario y día calendario |
| [diagrama_sp_as21.md](./diagrama_sp_as21.md) | `sisper_db..sp_as21` | Ausencias del día (1:N) |
| [diagrama_sp_eaus.md](./diagrama_sp_eaus.md) | `sisper_db..sp_eaus` | **Catálogo de ausencias** — licencias y permisos |
| [diagrama_sp_easi.md](./diagrama_sp_easi.md) | `sisper_db..sp_easi` | Estados del día |
| [diagrama_sp_turn.md](./diagrama_sp_turn.md) | `sisper_db..sp_turn` | Turnos — trae `ver_hora` |
| [diagrama_sp_as31.md](./diagrama_sp_as31.md) | `sisper_db..sp_as31` | Justificaciones del día |
| [diagrama_sp_tjus.md](./diagrama_sp_tjus.md) | `sisper_db..sp_tjus` | Tipos de justificación |
| [diagrama_sp_cjus.md](./diagrama_sp_cjus.md) | `sisper_db..sp_cjus` | Categorías: Laboral / Personal |
| [diagrama_es_tfer.md](./diagrama_es_tfer.md) | `ufro_db..es_tfer` | Tipos de feriado |

```
sp_as01 ──── cod_estasi ────► sp_easi
        ──── cod_turno  ────► sp_turn
        ◄─── cod_asist  ──── sp_as21 ──── (tip_agraus, cod_agraus) ────► sp_eaus
        ◄─── cod_asist  ──── sp_as31 ──── cod_tipjus ────► sp_tjus
                                     ──── cod_catjus ────► sp_cjus
                                     ──── cod_tipmar ────► sin catalogo identificado

ufro_db..es_cfer ──── cod_tipfer ────► ufro_db..es_tfer
```

---

## Lo que estos datos resolvieron

### Licencia médica y permiso sin goce **sí tienen fuente**

`sp_eaus` los clasifica por grupo:

| Grupo | Contenido |
| :---: | :--- |
| 1 | Permisos — incluye **Sin Goce de Sueldo** (cod 2) |
| **2** | **Licencias médicas** — siete tipos |
| 3 | Comisiones |
| 20 | Feriados |

S0-013 tenía Q-H01 y Q-H07 marcadas como *sin fuente definida*. El módulo de asistencia ya las
registra, día a día, con el motivo. **No hace falta una integración nueva con SISPER.**

### `es_tfer` es el nombre correcto

No `es_tipfer`. Era la única dependencia que podía impedir que el PA compilara.

### `sp_as01` ya trae los minutos calculados

`min_atraso`, `min_adelan` y `min_extras` están en la tabla. El PA no necesita recalcularlos
desde las horas.

### Hay marcas intermedias

`f_ent_int` y `f_sal_int` registran la colación. El tiempo efectivamente trabajado hay que
calcularlo descontándolas.

### `sp_as21` es 1:N, confirmado con datos

Un día con dos ausencias distintas existe en los datos reales. Justifica el cursor.

---

## Lo que quedó abierto

| # | Pregunta |
| :-- | :--- |
| 1 | **Días duplicados** — 11 días con dos filas en `sp_as01`. ¿Cuál vale? |
| 2 | **Estado 3 Incompleto** — marcó una sola vez. ¿Acredita ejecución? |
| 3 | **Estado 1 Editado** — registro corregido a mano. ¿Sirve como evidencia? |
| 4 | **Justificaciones de registro fallido** (tipos 11, 13, 15) — deberían acreditar el día |
| 5 | **Comisiones y capacitaciones** — trabajó, pero no en lo comprometido |
| 6 | **Feriado tipo 3** — suspender clases no suspende el trabajo administrativo |
| 7 | **`cod_tipmar`** en `sp_as31` — sin catálogo identificado |
| 8 | **Marcas en `00:00`** — son *sin dato*, no medianoche |

Las tres primeras son las que bloquean escribir la regla de acreditación.
