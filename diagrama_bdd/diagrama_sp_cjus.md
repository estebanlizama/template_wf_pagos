# `sisper_db..sp_cjus` — categorías de justificación

Catálogo. Indica **si la justificación fue por motivos de trabajo o personales**.

---

## Estructura

| Columna | Qué es |
| :--- | :--- |
| `cod_catjus` | PK |
| `des_catjus` | descripción |

---

## Contenido

| cod | Descripción |
| :---: | :--- |
| 1 | Laboral |
| 2 | Personal |

Dos valores. Es la dimensión más corta del módulo y la más útil para clasificar.

---

## Cómo se combina

`sp_as31` apunta a **los dos catálogos a la vez**: el tipo (`sp_tjus`) y la categoría (`sp_cjus`).
El PA los concatena:

```
"Error en  Biometrico" + "/" + "Laboral"
```

La combinación es **libre**: cualquier tipo puede venir con cualquier categoría. Eso importa
porque el mismo tipo cambia de sentido según la categoría.

---

## Por qué importa para el WF de pagos

La categoría resuelve la ambigüedad que el tipo solo no puede:

| Tipo | Categoría | Lectura |
| :--- | :--- | :--- |
| Tramite Medico | Personal | ausencia propia |
| Tramite Medico | Laboral | gestión institucional |
| Autorizado por Jefatura | Laboral | encargo de trabajo |
| Autorizado por Jefatura | Personal | permiso concedido |

Sin la categoría, *Autorizado por Jefatura* es un comodín que no se puede clasificar. Con ella,
al menos se sabe de qué lado cae.

Para acreditar ejecución de una prestación, **`Laboral` es el filtro de primera aproximación**:
una justificación laboral sugiere que el tiempo se dedicó a trabajo, aunque no necesariamente al
trabajo comprometido en la resolución.

---

## Relación

```
sp_as31 ──── cod_catjus ────► sp_cjus
```
