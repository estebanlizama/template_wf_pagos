# Próximo visador, borrador y etapa — ¿se puede sin tocar el esquema?

Pregunta: con el modelo actualizado, ¿dónde quedan registrados el **estado borrador** del
encabezado, la **etapa** del flujo y el **próximo visador**, sin modificar la BDD?

**Respuesta corta: sí se puede, y la premisa es correcta — el pago no crea una solicitud nueva.**

---

## 1. La premisa es correcta

El pago **no genera una `sg_soli` nueva**. Se apoya en la solicitud de la resolución, que ya
existe, está archivada y tiene su número. Lo que el pago agrega son datos colgados de esa misma
prestación.

Eso tiene una consecuencia limpia: **los dos estados no compiten**.

| Qué | Dónde | Valor típico durante el pago |
| :--- | :--- | :--- |
| Estado de la **resolución** | `sg_soli.cod_estsol` | 11 Archivada — no se mueve |
| Estado del **pago** | `sg_epag.cod_estcuo` | 1 → 6 → 2 → 4 → 8 |
| Estado de cada **mes** | `sg_fume.cod_estfum` | 1 → 2 → 3 |

Nadie sobreescribe a nadie. La resolución queda archivada para siempre y el pago corre por su
cuenta sobre la misma prestación.

---

## 2. Estado borrador del encabezado — ✅ ya resuelto

`sg_epag.cod_estcuo = 1 Propuesta`. Es exactamente para eso que conservamos el código 1 en
`sg_ecuo` al depurar el catálogo.

Y el encabezado ya trae quién y cuándo:

| Columna | Para qué |
| :--- | :--- |
| `rut_solici` | quién armó la solicitud de pago |
| `fec_solici` | cuándo la envió |

**No hace falta nada más.** El borrador es una fila de `sg_epag` en estado 1, con sus filas de
`sg_dpag`, y meses que siguen en estado 1 — es decir, sin comprometer cupo ni saldo.

---

## 3. Próximo visador — ✅ `sg_apso` ya sirve, sin cambios

`sg_apso` es la tabla de aprobaciones del motor configurable, y **ya tiene todas las columnas que
el flujo de pago necesita**:

| Columna | Qué aporta al pago |
| :--- | :--- |
| `nro_aproba` | PK propia → varias aprobaciones por solicitud, sin chocar |
| `nro_solici` | **el número de la resolución**. No hace falta uno nuevo |
| `id_funprse` | 🔑 ya existe, permite colgar del funcionario-prestación |
| `cod_flusol` + `cod_etapa` | FK a `sg_eta1`: el motor de etapas configurable |
| `rut_usua` | **el visador asignado** |
| `rut_autori` | quién autorizó de hecho, para subrogancia |
| `cod_estapr` | estado de esa aprobación |
| `comentario` | la observación de DGDP |
| `f_aprobac` · `f_creacion` · `f_ultmodif` | trazabilidad |

Es la misma maquinaria de la resolución. Lo único que cambia es el **flujo**: el pago usa su
propio `cod_flusol`.

### Lo que hay que agregar es DATO, no esquema

| Tabla | Qué se inserta |
| :--- | :--- |
| `sg_tfls` | una fila para el flujo de pago (nuevo `cod_flusol`) |
| `sg_eta1` | sus etapas, con `cod_perfil`, `est_final` y `vigente` |

Eso va en `datos_base`, junto con los catálogos de estado. **Cero DDL.**

---

## 4. Etapa actual del flujo — ✅ derivable, sin columna nueva

En resolución la etapa vigente está **denormalizada** en `sg_prse.cod_flusol` / `cod_etapa`, y
`sg_fupssSecgen17` la lee joinando `sg_eta1`:

```sql
left join sg_eta1 etapaAct
    on etapaAct.cod_flusol = prse.cod_flusol
   and etapaAct.cod_etapa  = prse.cod_etapa
```

Para el pago **no hace falta replicar esa columna**: la etapa vigente es la de la fila de
`sg_apso` que todavía no tiene `f_aprobac`.

```
etapa actual del pago =
    sg_apso  donde  id_funprse = X
                    y cod_flusol = <flujo de pago>
                    y f_aprobac is null
```

`sg_prse.cod_flusol`/`cod_etapa` **no se pueden reutilizar**: son la etapa de la resolución y
escribir ahí la del pago borraría el historial del acto administrativo.

> La denormalización de `sg_prse` es una caché de lectura, no la verdad. La verdad siempre estuvo
> en `sg_apso`. Para el pago se lee directo de la fuente.

---

## 5. La única limitación real: `sg_apso` no sabe de cuotas

`sg_apso` puede decir *"esta aprobación es del funcionario-prestación X en la etapa Y del flujo de
pago"*, pero **no** *"…de la cuota 2"*.

¿Alcanza? Depende de una decisión pendiente:

| Escenario | ¿`sg_apso` alcanza? |
| :--- | :--- |
| **Un solo envío vivo a la vez** por prestación | **Sí.** La aprobación abierta es la del envío vigente, sin ambigüedad |
| Dos envíos vivos simultáneos (cuota 1 en DGDP mientras se envía la cuota 2) | **No.** Dos filas abiertas sobre el mismo `id_funprse` y ninguna forma de saber a qué cuota corresponde |

Con el cupo de 2 cuotas al año, el segundo escenario es posible. Hay dos salidas:

- **Restringir a un envío vivo por prestación.** No toca el esquema, y además simplifica el cupo:
  mientras haya una solicitud de pago en trámite no se puede armar otra. Es una regla razonable
  y fácil de explicar.
- **Agregar `nro_cuota` a `sg_apso`.** Una columna, nullable, que solo usa el flujo de pago.
  Resuelve el caso general pero es DDL.

> **Recomendación: la restricción.** Es coherente con que las cuotas de un envío transicionan
> juntas (Q-A09) y evita el único caso en que el modelo se queda corto. Si más adelante el negocio
> necesita envíos paralelos, se agrega la columna entonces.

---

## 6. Resumen

| Necesidad | Dónde queda | ¿DDL? |
| :--- | :--- | :---: |
| Estado borrador del encabezado | `sg_epag.cod_estcuo = 1` | **No** |
| Quién y cuándo solicitó | `sg_epag.rut_solici` · `fec_solici` | **No** |
| Próximo visador | `sg_apso.rut_usua` con el `cod_flusol` del pago | **No** |
| Etapa actual | fila de `sg_apso` sin `f_aprobac` | **No** |
| Observación de DGDP | `sg_apso.comentario` | **No** |
| Subrogancia | `sg_apso.rut_autori` | **No** |
| Historial de transiciones | `sg_fum2` (meses) + `sg_apso` (etapas) | **No** |
| Flujo y etapas del pago | filas nuevas en `sg_tfls` y `sg_eta1` | **No** — son datos |
| Aprobación por cuota específica | ⚠️ requiere `nro_cuota` en `sg_apso`, **o** restringir a un envío vivo | depende |

**El esquema actual alcanza para todo el flujo**, con una sola decisión de negocio que evita la
única columna que faltaría.

---

## 7. Lo que hay que escribir en `datos_base`

Siguiendo el patrón de `certificacion_03_09_2026/datos_base/05_flujos_etapas_du288.sql`:

```
04_flujo_pagos.sql     -> sg_tfls: el flujo de pago
05_etapas_pagos.sql    -> sg_eta1: sus etapas con perfil y est_final
06_permisos_pagos.sql  -> perfiles y permisos del módulo
```

Antes de escribirlos falta definir:

1. **Cuántas etapas tiene el flujo de pago.** Con Finanzas fuera del sistema, el mínimo es una:
   *Validación DGDP*. ¿Hay alguna visación previa, o el envío va directo a DGDP?
2. **Qué perfil resuelve cada etapa** (`cod_perfil` en `sg_eta1`).
3. **Cuál etapa es terminal** (`est_final = 'S'`).
4. **La restricción de un envío vivo** por prestación, o su alternativa.
