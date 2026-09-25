# ¿Agregar una etapa de pago al flujo de resolución, o un flujo nuevo?

---

## 1. El tamaño de lo que existe

| Tabla | Filas cargadas |
| :--- | ---: |
| `sg_tfls` — flujos | **8** (Facultad, Investigación, DITT, Instituto, VRAF, VRAC, VIPRE, VRIP) |
| `sg_eta1` — etapas | **99** |
| `sg_eta2` — transiciones | **265** |

Cada flujo va de *Solicitante* (10) a *Jefe Archivo Universitario*, que es la etapa con
`est_final = 'S'`. El número de esa etapa final **no es el mismo en todos**: 130 en los flujos
1-4, 110 en el 5, 120 en los 6-8.

---

## 2. Agregar una etapa al flujo de resolución — el costo

| Qué | Cuánto |
| :--- | :--- |
| Etapas nuevas en `sg_eta1` | **8** — una por flujo |
| Transiciones nuevas en `sg_eta2` | **≥ 8**, más las de devolución y rechazo |
| `UPDATE` para mover `est_final` de la etapa de archivo a la nueva | **8** |

Ya son 24 filas repartidas en 8 flujos con numeración inconsistente. Pero el costo en filas es lo
**menos** grave.

### 2.1 Rompe el cierre de la resolución

Quitarle `est_final = 'S'` a *Jefe Archivo Universitario* significa que **una resolución
archivada deja de estar terminada**. Consecuencias inmediatas:

| Qué se rompe | Por qué |
| :--- | :--- |
| El estado *Archivada* | La transición a la etapa nueva escribiría otro `cod_estsol` en `sg_soli` |
| La bandeja de resolución | Las archivadas aparecerían como pendientes de la etapa de pago |
| `sg_prse.cod_etapa` | Avanzaría a la etapa de pago, perdiendo el registro de que llegó a archivo |
| `sg_fupssSecgen17` | Muestra `cod_estsol = 11` como *"Resolución Archivada"* — dejaría de calzar |
| El buscador de resoluciones pagables | Filtra por archivada; si el estado cambia, no encuentra nada |

Y todo eso ocurre **8 veces**, una por flujo.

### 2.2 El problema de fondo: el pago se repite

Este es el argumento que decide, y no es de esfuerzo sino de modelado.

`sg_prse.cod_etapa` es **un solo valor**: la etapa actual. Una máquina de estados lineal puede
decir *"vamos en la etapa 60"*, pero no *"la etapa de pago se recorrió dos veces, una por
cuota"*.

Y el pago se repite: hasta 2 cuotas por año, sin límite si la prestación es extensible. Cada
cuota es un ciclo completo de enviar → validar → registrar.

> **El pago no es una etapa más de la resolución. Es un ciclo que se repite sobre una resolución
> ya terminada.** Meterlo como etapa lineal fuerza un modelo que no puede representarlo.

---

## 3. Flujo nuevo — el costo

| Qué | Cuánto |
| :--- | :--- |
| `sg_tfls` | **1** fila — el flujo de pago |
| `sg_eta1` | **1 a 3** etapas, con `cod_modulo` propio |
| `sg_eta2` | las transiciones de esas etapas |
| Resolución | **cero cambios** |

Un solo flujo alcanza: los 8 de resolución existen porque la escalera de visaciones depende de la
unidad (Facultad, Investigación, DITT…). El pago tiene **una sola etapa revisora, DGDP central**,
igual para todos. No hay escalera que diferenciar.

Y el `cod_modulo` propio aísla los roles en las consultas que ya existen — ver
[impacto_13](./impacto_13_apso_aislado_por_modulo.md).

### Con Finanzas fuera del sistema, ¿cuántas etapas?

| Etapa | ¿Hace falta? |
| :--- | :--- |
| Solicitante | Sólo si el borrador debe aparecer en una bandeja. El estado 1 del encabezado ya lo cubre |
| **Validación DGDP** | **Sí** — es la única etapa revisora |
| Envío a pago | No: es la acción terminal de DGDP, no una etapa con revisor |

**Con una etapa basta.** Dos si se quiere que el borrador tenga bandeja propia.

---

## 4. Y la tercera opción: sin flujo

Si no se usa `sg_apso`, no hace falta flujo ni etapas:

```
bandeja DGDP = encabezados de pago en estado 6
tomadas      = encabezados en estado 2
```

El estado **es** la bandeja, y el rol lo resuelve `sg_uspe` / `bd_pri2`. Cero filas de
configuración.

El costo es que hay que agregar `observacio` a `sg_epag` para el comentario de devolución, y que
sólo se guarda la última revisión en vez del historial completo — ver
[impacto_12](./impacto_12_bandeja_dgdp_sin_apso.md).

---

## 5. Comparación

| | Etapa en resolución | Flujo nuevo | Sin flujo |
| :--- | :---: | :---: | :---: |
| Filas de configuración | 8 + 8 + 8 UPDATE | 1 + 1..3 + transiciones | 0 |
| Toca la resolución | **Sí, la rompe** | No | No |
| Representa el ciclo repetido | **No puede** | Sí | Sí |
| Historial de revisiones | sí | sí (`sg_apso`) | sólo la última |
| Comentario de devolución | sí | sí (`sg_apso.comentario`) | falta 1 columna |
| DDL | 0 | 0 | 1 columna |
| Cambios en PA de resolución | muchos | 1 línea | 0 |

### Recomendación

**Flujo nuevo.** Cuesta casi lo mismo que no tener flujo, no toca la resolución, y a cambio trae
el historial completo de revisiones y el comentario sin agregar columnas.

**Agregar una etapa al flujo de resolución queda descartado** — no por las 24 filas, sino porque
rompe el cierre de la resolución en 8 flujos y porque una etapa lineal no puede representar un
ciclo que se recorre una vez por cuota.

---

## 6. Si se va por flujo nuevo, qué hay que definir

1. **El `cod_flusol`** — el siguiente disponible después del 8.
2. **El `cod_modulo`** — propio, para aislar los roles en `bd_per1` / `bd_pri2`.
3. **Una etapa o dos** — ¿el borrador necesita bandeja propia, o basta el estado 1 del encabezado?
4. **El `cod_perfil`** de la etapa DGDP — nuevo, o el 13 (*Director DGDP*) que ya usa resolución.
5. **Las transiciones** en `sg_eta2`: enviar, devolver, rechazar, aprobar, registrar — con el
   `cod_estsol` que corresponda… y aquí hay un detalle: `sg_eta2.cod_estsol` apunta al estado de
   **`sg_soli`**, que en el pago no se mueve. Habría que decidir si esa columna se deja en el
   valor actual de la resolución o si el motor tolera nulos.
