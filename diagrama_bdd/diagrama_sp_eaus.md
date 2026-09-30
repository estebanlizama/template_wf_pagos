# `sisper_db..sp_eaus` — catálogo de ausencias

Clasifica **por qué** un funcionario no estuvo. Es la tabla más relevante del módulo para el WF
de pagos: aquí viven las licencias médicas y los permisos sin goce.

---

## Estructura

| Columna | Qué es |
| :--- | :--- |
| `tip_agraus` | **grupo** de ausencia — la dimensión que ordena todo |
| `cod_agraus` | código dentro del grupo |
| `des_ausen` | descripción completa |
| `res_ausen` | descripción **truncada a 15 caracteres** |

La clave es **compuesta**: `(tip_agraus, cod_agraus)`.

> ⚠️ `res_ausen` viene cortado — *"Permiso Adminis"*, *"Enfermedad o Ac"*. El script original
> usaba esa columna. **Hay que usar `des_ausen`.**

---

## Contenido

### Grupo 1 — Permisos

| cod | Descripción |
| :---: | :--- |
| 1 | Permiso Administrativo |
| 2 | **Permiso Sin Goce de Sueldo** |
| 3 | Ausencia |
| 4 | Autorización Especial |
| 5 | Vacaciones |
| 6 | Otro |
| 7 | Permiso Paternal |
| 8 | Permiso Laboral por duelo |
| 9 | Permiso Matrimonial |

### Grupo 2 — Licencias médicas

| cod | Descripción |
| :---: | :--- |
| 1 | Enfermedad o Accidente No del Trabajo |
| 2 | Prórroga Medicina Preventiva |
| 3 | Licencia Maternal |
| 4 | Enfermedad Grave Hijo Menor de 1 Año |
| 5 | Accidente del Trabajo |
| 6 | Enfermedad Profesional |
| 7 | Patología del Embarazo |

### Grupo 3 — Comisiones

| cod | Descripción |
| :---: | :--- |
| 1 | Comisión de Perfeccionamiento |
| 2 | Comisión de Estudios |
| 3 | Comisión de Servicio |
| 4 | Otro |

### Grupo 20 — Feriados

| cod | Descripción |
| :---: | :--- |
| 1 | Feriado Nacional |
| 2 | Feriado Universitario |
| 3 | Suspensión Actividades Lectiva |

Espeja a `ufro_db..es_tfer` con los mismos códigos.

---

## Por qué importa

Esta tabla **responde dos preguntas que S0-013 tenía marcadas como sin fuente**:

| Pregunta | Respuesta |
| :--- | :--- |
| Q-H01 · ¿Cuál es la fuente de licencias médicas? | `tip_agraus = 2`, siete tipos |
| Q-H07 · ¿Cuál es la fuente de permiso sin goce? | `tip_agraus = 1, cod_agraus = 2` |

Se creía que había que integrar SISPER por otra vía. **El módulo de asistencia ya lo registra**,
día a día, con el detalle del motivo.

---

## Cómo se usa en el WF de pagos

```
grupo 2          → el mes no es pagable, o se descuenta en proporción
grupo 1, cod 2   → el mes no es pagable
grupo 1, cod 5   → vacaciones: decidir si interrumpen la prestación
grupo 3          → comisión: estuvo trabajando, en otro lugar
grupo 20         → día no laboral
```

**Los grupos 1 y 3 necesitan decisión de negocio.** Un permiso administrativo o una comisión de
servicio no son lo mismo que una licencia, y el decreto no los menciona.

---

## Relación

```
sp_as21 ──── (tip_agraus, cod_agraus) ────► sp_eaus
```
