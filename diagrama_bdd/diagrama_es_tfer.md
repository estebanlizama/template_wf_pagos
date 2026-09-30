# `ufro_db..es_tfer` — tipos de feriado

Catálogo institucional. Clasifica los días no laborales del calendario.

---

## Estructura

| Columna | Qué es |
| :--- | :--- |
| `cod_tipfer` | PK |
| `des_tipfer` | descripción |

---

## Contenido

| cod | Descripción |
| :---: | :--- |
| 1 | Feriado Nacional |
| 2 | Feriado Universitario |
| 3 | Suspensión Actividades Lectiva |

---

## El nombre de la tabla

Se llama **`es_tfer`**, no `es_tipfer`. En S0-013 quedó anotado con el otro nombre; el dato real
confirma el primero.

Era la única dependencia que podía impedir que el PA de asistencia compilara. **Queda resuelta.**

---

## Relaciones

```
ufro_db..es_cfer ──── cod_tipfer ────► ufro_db..es_tfer
```

`es_cfer` es el calendario: una fila por fecha no laboral, con su `cod_tipfer`.

Y hay un espejo dentro de SISPER:

```
sisper_db..sp_eaus  grupo 20  ──  los mismos tres codigos y descripciones
```

Los feriados están representados **dos veces**: como calendario institucional en `ufro_db`, y
como grupo de ausencia en `sp_eaus`. Conviene usar `es_cfer` + `es_tfer` como fuente, porque es
el calendario propiamente tal; `sp_eaus` grupo 20 refleja cómo el módulo de asistencia marca esos
días en un registro concreto.

---

## Uso en el WF de pagos

| Tipo | Significado para una prestación |
| :---: | :--- |
| **1** Feriado Nacional | día no laboral por ley |
| **2** Feriado Universitario | **el receso** — bloques de varios días |
| **3** Suspensión Actividades Lectiva | sin clases, pero la universidad funciona |

El **tipo 2** es el que activa la regla del decreto: no se paga receso universitario salvo trabajo
efectivo acreditado y asumido por el proyecto.

En los datos revisados aparece en bloques:

```
25-30 enero 2016       6 dias
18-22 julio 2016       5 dias
26-30 diciembre 2016   5 dias
30-31 enero 2017
```

El **tipo 3** es distinto y no debería bloquear el pago: suspender clases no suspende el trabajo
administrativo ni la ejecución de una prestación.

> Esa distinción entre el 2 y el 3 no está resuelta en las reglas del WF. Hoy se trata todo como
> "receso", y no son lo mismo.
