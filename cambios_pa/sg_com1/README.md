# PA de comentarios de cuota — `sg_com1`

Comentarios y observaciones que **DGDP** deja sobre una cuota de pago. Reemplaza
el camino anterior, que escribía en `sg_hist` con un prefijo `#PRS{id}-C{n}#`
dentro del texto libre para identificar a qué cuota correspondía.

| PA | Qué hace | Quién lo llama |
| :--- | :--- | :--- |
| `sg_com1sSecgen01` | Hilo de una cuota, o de todas las de la prestación si no se indica `@nro_cuota`; del más reciente al más antiguo | revisor DGDP |
| `sg_com1sSecgen02` | Comentario vigente de **cada** cuota de la prestación, en una consulta | jefe de proyecto |

Un PA por rol, como el resto del flujo: `sg_epagsSecgen01` es la lectura del jefe
de proyecto y `sg_epagsSecgen03`/`sg_epagsSecgen04` las de DGDP. Cada uno lleva el
`not exists` de su propio rol, copiado del PA equivalente.

El **insert no tiene PA propio**: va inline en `sg_epaguSecgen03` al resolver
desde estado 2 y en `sg_epaguSecgen05` al reabrir desde estado 4, dentro de la
misma transacción que mueve `cod_estcuo`. Un comentario siempre acompaña una
decisión, así que separarlos solo abre la puerta a los dos estados inconsistentes
que antes existían —cuota devuelta sin motivo, o motivo sin devolución—. Si más
adelante DGDP necesita dejar una nota **sin** mover el estado, ahí sí corresponde
un `sg_com1iSecgen01`.

No hay PA de `update` ni de `delete`:

- **update**: la tabla es un registro de auditoría. Corregir un comentario es
  agregar otro; el vigente es el de fecha mayor.
- **delete**: una cuota con comentarios está en estado 3 o 10, y
  `sg_epagdSecgen01` solo borra borradores (estado 1), que nunca tienen
  comentarios. La única cascada pendiente es el borrado de la solicitud completa
  (`sg_solidSecgen01`), que hoy tampoco borra `sg_epag` ni `sg_dpag`.

---

## El modelo

```sql
create table secgen_db.dbo.sg_com1 (
    id_funprse int      not null,   /* cuota: prestacion…      */
    nro_cuota  tinyint  not null,   /* …y correlativo de cuota */
    f_observa  datetime not null,
    id_tipacc  tinyint  not null,   /* la accion, catalogo sg_tacc */
    rut_accion char(9)  not null,
    observaci  text         null,
    constraint SG_COM1_PK primary key (id_funprse, nro_cuota, f_observa)
)
-- FK (id_funprse, nro_cuota) -> sg_epag
-- FK id_tipacc              -> sg_tacc
```

### La FK es el aislamiento

La tabla cuelga de `sg_epag(id_funprse, nro_cuota)`, que **es** la llave de una
cuota de pago. Una fila que no sea de pagos no se puede insertar: la restricción
la rechaza. No hace falta prefijo en el texto, ni rango de códigos reservado, ni
un `where` que alguien pueda olvidar.

Y ninguna lectura de `sg_hist` la ve, así que las dos consultas de resolución que
antes recibían filas de pago en su payload vuelven a devolver solo lo suyo.

### Los códigos de `sg_tacc` siguen siendo necesarios

`id_tipacc` tiene **FK a `sg_tacc`**, así que los dos códigos del WF de pagos
siguen vigentes y ahora son obligatorios:

| `id_tipacc` | `des_accion` | Cuándo |
| :---: | :--- | :--- |
| 32 | DGDP devolvio a correccion la cuota de pago | `cod_estcuo` → 3 |
| 33 | DGDP rechazo la cuota de pago | `cod_estcuo` → 10 |
| 34 | DGDP devolvio una cuota aprobada a visacion | `cod_estcuo` 4 → 2 |

Los carga `datos_base/05_sg_tacc_acciones_pago.sql`. **Tiene que estar aplicado
antes** de recompilar `sg_epaguSecgen03` y `sg_epaguSecgen05`: sin la acción usada,
el `insert` viola la FK y la transacción se revierte, de modo que DGDP no puede
resolver o reabrir una cuota.

Lo que dejó de usarse es `sg_hist` como tabla y el prefijo en el texto. El código
de acción no: se mudó de una columna sin FK a una con FK.

### La fecha es parte de la llave

`(id_funprse, nro_cuota, f_observa)`. El comentario vigente se obtiene con un
`max(f_observa)` por cuota, sin correlativo que mantener.

El costo es que dos decisiones sobre la misma cuota dentro del mismo tick del
motor (≈3,3 ms en ASE) chocarían. No se agregó lógica para esquivarlo: la
colisión es imposible en la práctica —la cuota sale de estado 2 con la primera
decisión, así que la segunda ya no pasa el `holdlock`— y si ocurriera, el
`@@error` del `insert` revierte la transacción y el mensaje llega al usuario,
igual que cualquier otro fallo.

### Lo que el modelo no guarda

- **`id_perfil`** — con qué perfil actuó el revisor. `sg_hist` lo guarda;
  `sg_com1` no. Si la auditoría lo necesita, es una columna más; si no, se deriva
  del rol vigente, con el riesgo de que la persona lo pierda después.
- **El estado resultante.** Se guarda la acción (`id_tipacc`), no el
  `cod_estcuo`. El estado vive en `sg_epag`; para reconstruir la decisión hay que
  traducir el código de acción.

---

## Largo del texto

`observaci` es `text`, pero un parámetro de PA no puede serlo: `@observacion` es
`varchar(255)`, el mismo largo que ya declaraba `sg_epaguSecgen03`.

El límite efectivo sube: el camino por `sg_hist` tenía 250 por el parámetro de
`sg_histiSecgen03`, menos el prefijo `#PRS{id}-C{n}# `, lo que dejaba 220 en el
backend. Sin prefijo son 255 completos.

---

## Acceso

Cada lectura valida a su llamador con el mismo `not exists` que ya usa el PA
equivalente del flujo:

| PA | Guardia | Copiada de |
| :--- | :--- | :--- |
| `sg_com1sSecgen01` | asignación vigente en `sisper_db..sp_orde` con `cod_organi = 696` | `sg_epagsSecgen04` |
| `sg_com1sSecgen02` | responsable vigente del centro de costo en `fin21_db..es_ecct` | `sg_epagdSecgen01` |

No hay un PA que acepte los dos roles: el estándar del repositorio separa por
rol, y un `exists` con `union` adentro tampoco lo admite el motor.
