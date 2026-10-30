# Atributos faltantes por tabla — WF de pagos

> Relectura 30-10-2026: este documento contiene propuestas de DDL y hallazgos históricos, no una constancia de que todas las columnas hayan sido agregadas. Los PA actuales sí versionan montos y descuentos en `sg_fum2` con `rut_regist`/`f_regist`; el cierre 4→8 escribe `sg_epag.mto_realpa`. El nuevo consolidado `impacto_30` separa esos cambios de las propuestas aún no verificadas. No presentar `rut_actua`, `fec_actua` u otros ALTER de este archivo como instalados sin contraste de catálogo.

Revisión de las tablas del flujo de pagos contra lo que los PA ya escriben y leen.

**Fuente de verdad usada:** los PA de `cambios_pa/`, no el diagrama. `diagrama_secgen_actualizado.md`
está atrasado — ya no tiene `ext_cuotas` en `sg_fups`, que sí existe y tres PA lo leen.

---

## Respuesta corta

Sí, `sg_fum2` necesita el par fecha + rut. Pero conviene ponerlo en **las dos** tablas, no solo
en el histórico, y con una semántica concreta:

| Columna | Dónde | Qué significa |
| :--- | :--- | :--- |
| `rut_actua char(9)` | `sg_fume` **y** `sg_fum2` | quién escribió **esa** versión |
| `fec_actua datetime` | `sg_fume` **y** `sg_fum2` | cuándo la escribió |

Se copia a `sg_fum2` igual que las demás columnas. Así cada fila del histórico queda atribuida a
**su autor**, y la pregunta *«quién la cambió»* la responde la fila siguiente — o `sg_fume`, si es
la última. Si el par se guardara solo en `sg_fum2` describiendo *al que la reemplazó*, la versión 1
quedaría sin autor y la vigente tampoco tendría ninguno.

### Y arregla un abuso que ya existe

Hoy `fec_valida` hace de «última gestión»: `sg_fumeuSecgen02` y `sg_fumeuSecgen03` ambos hacen
`fec_valida = getdate()`. Pero `fec_valida` es la fecha de validación DGDP y viaja junto a los
`val_*`. Cuando el jefe de proyecto corrige un monto, **el mes queda con fecha de validación sin
haber sido validado**.

Con `fec_actua` en su lugar, `fec_valida` vuelve a escribirse solo con los `val_*`.

Además `sg_fumeuSecgen02` ya recibe `@rut_person` y hoy **no lo guarda en ninguna parte**: valida
con él y lo descarta. El dato está disponible, falta la columna.

---

## `sg_fume` — delta contra el diagrama

| # | Baseline | Debe quedar | Estado |
| :--: | :--- | :--- | :--- |
| 1 | `nro_cuota tinyint` | `corr_fume tinyint` | PK, índice único y las 2 FK que lo referencian |
| 2 | `cod_estcuo` FK→`sg_ecuo` | `cod_estfum` FK→**`sg_efum`** | **hay que recrear la FK**, ver abajo |
| 3 | — | `+ mto_realpa int` | lo escribe `sg_fumeuSecgen03` |
| 4 | — | `+ mto_deslic int` | idem |
| 5 | — | `+ mto_dessg int` | idem |
| 6 | — | `+ rut_actua char(9)` | nuevo |
| 7 | — | `+ fec_actua datetime` | nuevo |
| 8 | `fec_pago`, `ano_pago`, `mes_pago` | **sobran** | migraron a `sg_epag`; ningún PA las lee ya |

### La FK no se puede dejar como está

`FK_sg_fume_sg_ecuo` apunta al catálogo de la **cuota**. Los dos catálogos comparten los códigos
1..4 con significados distintos:

| cod | `sg_ecuo` (cuota) | `sg_efum` (mes) |
| :--: | :--- | :--- |
| 1 | Propuesta | Propuesta |
| 2 | En visación | Comprometida |
| 3 | Observada | Enviada a pago |
| 4 | Aprobada | **Rechazada** |

Si la FK sigue contra `sg_ecuo`, un mes rechazado (4) **pasa la integridad** satisfaciendo
*Aprobada*. No falla: se corrompe en silencio. Es el peor caso posible.

---

## `sg_fum2` — delta

| # | Baseline | Debe quedar |
| :--: | :--- | :--- |
| 1 | `nro_cuota tinyint` | `corr_fume tinyint` — PK `(id_funprse, corr_fume, correlativ)` y FK a `sg_fume(id_funprse, corr_fume)` |
| 2 | `cod_estcuo tinyint` | `cod_estfum tinyint` |
| 3 | — | `+ mto_realpa int` |
| 4 | — | `+ mto_deslic int` |
| 5 | — | `+ mto_dessg int` |
| 6 | — | `+ rut_actua char(9)` |
| 7 | — | `+ fec_actua datetime` |

### El 2 ya está pasando

`sg_fumeuSecgen02:170` y `sg_fumeuSecgen03:131` insertan `sg_fume.cod_estfum` **dentro** de la
columna llamada `cod_estcuo`, y `sg_fum2sSecgen01/02` la leen haciendo
`left join sg_efum e on e.cod_estfum = h.cod_estcuo`.

O sea: la columna ya contiene códigos de mes, con nombre de cuota. Funciona y da el resultado
correcto. Solo miente. No tiene FK — por eso no revienta.

### El 3, 4 y 5 son un agujero funcional, no cosmético

`sg_fumeuSecgen03` versiona el mes **antes** de sobrescribir `mto_deslic`, `mto_dessg` y
`mto_realpa`… y el snapshot no incluye ninguna de las tres.

Consecuencia concreta: DGDP registra un descuento por licencia de $50.000, después lo corrige a
$30.000. `sg_fum2` guarda el `mto_apagar` anterior pero **no el descuento anterior**. El valor que
más se discute es justo el que no queda en el histórico.

Y hay un segundo efecto: el versionado solo se dispara si cambia `mto_apagar`
(`if @mto_nuevo <> @mto_apagar_actual`). Si DGDP corrige **solo** el descuento, no se versiona
nada. Con las tres columnas en `sg_fum2`, la condición debe pasar a:

```sql
if @mto_nuevo     <> @mto_apagar_actual
or @mto_deslic    <> isnull(@mto_deslic_actual, 0)
or @mto_dessg     <> isnull(@mto_dessg_actual, 0)
```

---

## `sg_epag` — lo que falta no son columnas, es quién las escribe

Columnas hoy: `id_funprse`, `nro_cuota`, `cod_estcuo`, `rut_solici`, `fec_solici`, `id_evidenc`,
`fec_pago`, `ano_pago`, `mes_pago`, `mto_realpa`.

| Columna | Lecturas | Escrituras |
| :--- | :--: | :--- |
| `fec_pago` | 2 | **ninguna** |
| `mto_realpa` | 2 | **ninguna** |

Las dos se llenarían en la transición a *Enviada remuneraciones* (`cod_estcuo = 8`), que **no
existe como PA**. `sg_epaguSecgen03` solo acepta destinos 3, 4 y 10.

`mto_realpa` del encabezado es redundante con `sum(sg_fume.mto_realpa)` — `sg_epagsSecgen03:113`
lo calcula así. Pero vale conservarla: una vez enviada a Finanzas el monto informado tiene que
quedar **congelado**, aunque después se edite un mes. Es un valor histórico, no un derivado.

### Falta el par del visador

`sg_epaguSecgen03` registra la decisión DGDP escribiendo **solo** `cod_estcuo`. No queda quién
decidió ni cuándo. `rut_solici` / `fec_solici` no sirven: `sg_epaguSecgen02:218` los sobrescribe
con el rut del que envía, así que significan «último que movió», no «quien creó».

Y `@observacion` está **declarado y nunca usado** — el motivo de rechazo se descarta.

Esto ya está diseñado en `comentario_devolucion_dgdp_tabla.md` como tabla `sg_vpag`
(`rut_valida`, `id_perfil`, `observacio`, `f_creacion`), pendiente de implementar. No lo cuento
como hallazgo nuevo: lo cuento como la razón de que `sg_epag` no necesite el par fecha+rut — va en
`sg_vpag`, que además guarda el historial completo de decisiones y no solo la última.

---

## `sg_fume` — dos estados sin escritor

Ningún PA escribe `cod_estfum = 3` (Enviada a pago) ni `= 4` (Rechazada). Solo se escriben 1 y 2.

| Lo que depende del 3 | Resultado hoy |
| :--- | :--- |
| `sg_epagsSecgen03:116` → `mto_pagado` | siempre 0 |
| `sg_epaguSecgen02:197` → `@mto_usado` | siempre 0 |
| `sg_fupssSecgen18:91` → `cant_cuotas_paga` | siempre 0 |
| cupo numeral 6, tramo irreversible | nunca se alcanza |

| Lo que depende del 4 | Resultado hoy |
| :--- | :--- |
| `sg_epagsSecgen01` → `cant_meses_rech` | siempre 0 |
| `isRejected` en el frontend | nunca true |

Por eso tampoco tienen escritor `rut_autori`, `fec_autori` ni `fec_envrem`: las tres columnas
existen, se leen, se copian a `sg_fum2`, y **nada las setea nunca**. Se llenan en esas dos
transiciones que faltan.

No es un atributo faltante — son los dos PA terminales del flujo.

---

## `sg_fuc2` — compensación anónima

Columnas: `id_funprse`, `corr_fume`, `fec_comrea`, `hora_ini`, `hora_ter`.

La compensación realizada es evidencia: es lo que se contrasta contra el horario comprometido para
autorizar el pago. Hoy no queda **quién la registró ni cuándo**. Si aparece un tramo que el
funcionario no reconoce, no hay a quién preguntarle.

| Faltaría | |
| :--- | :--- |
| `rut_regist char(9)` | quién registró el tramo |
| `f_creacion datetime` | cuándo lo registró — distinto de `fec_comrea`, que es cuándo se compensó |

`sg_fuc2iSecgen01/02` ya reciben `@rut_person`. Igual que en `sg_fume`: el dato está, falta dónde
ponerlo.

> Nota aparte: `fec_comrea` guarda fecha **y** hora de inicio (`@inicio_dt = fecha + @min_ini`), así
> que `hora_ini` es redundante con su parte horaria. No es un defecto — la PK
> `(id_funprse, corr_fume, fec_comrea)` depende de eso para admitir dos tramos el mismo día.

---

## `sg_dpag`

`(id_funprse, nro_cuota, corr_fume)`. Puente puro, sin atributos propios. **No falta nada**: quién
y cuándo agrupó los meses es la misma información que `sg_epag` / `sg_vpag` ya guardan del
encabezado, y las filas se borran y recrean completas en cada edición
(`sg_epaguSecgen01:281`), así que un `f_creacion` aquí describiría la última edición, no el origen.

---

## Tipos de dinero — pendiente transversal

| Columna | Tipo hoy |
| :--- | :--- |
| `sg_fups.mto_total` | `decimal(19,2)` |
| `sg_fups.mto_tope`, `mto_haber` | `int` |
| `sg_fume.mto_apagar`, `mto_realpa`, `mto_deslic`, `mto_dessg` | `int` |
| `sg_epag.mto_realpa` | `int` |

Q-J13 pide no redondear. Con `mto_total` en decimal y todo lo que lo reparte en `int`, la suma de
los meses no cuadra con el total cuando el reparto no es exacto. Si las nuevas columnas van a
nacer, nacen `decimal(19,2)`.

---

## DDL

Orden importa: primero las columnas nuevas, después los renombres, al final las FK.

```sql
use secgen_db
go

/* ---- 1. columnas nuevas ---- */

alter table secgen_db.dbo.sg_fume add mto_realpa decimal(19,2) null
alter table secgen_db.dbo.sg_fume add mto_deslic decimal(19,2) null
alter table secgen_db.dbo.sg_fume add mto_dessg  decimal(19,2) null
alter table secgen_db.dbo.sg_fume add rut_actua  char(9)       null
alter table secgen_db.dbo.sg_fume add fec_actua  datetime      null
go

alter table secgen_db.dbo.sg_fum2 add mto_realpa decimal(19,2) null
alter table secgen_db.dbo.sg_fum2 add mto_deslic decimal(19,2) null
alter table secgen_db.dbo.sg_fum2 add mto_dessg  decimal(19,2) null
alter table secgen_db.dbo.sg_fum2 add rut_actua  char(9)       null
alter table secgen_db.dbo.sg_fum2 add fec_actua  datetime      null
go

alter table secgen_db.dbo.sg_fuc2 add rut_regist char(9)  null
alter table secgen_db.dbo.sg_fuc2 add f_creacion datetime null
go

/* ---- 2. renombres ---- */

exec sp_rename 'secgen_db.dbo.sg_fum2.cod_estcuo', 'cod_estfum'
go

/* sg_fume.nro_cuota -> corr_fume y cod_estcuo -> cod_estfum:
   si aun no se aplicaron, van aqui, antes de las FK.
   Requieren soltar PK, indice unico y las FK que los referencian. */

/* ---- 3. FK al catalogo correcto ---- */

alter table secgen_db.dbo.sg_fume drop constraint FK_sg_fume_sg_ecuo
go
alter table secgen_db.dbo.sg_fume
    add constraint FK_sg_fume_sg_efum
    foreign key (cod_estfum) references secgen_db.dbo.sg_efum(cod_estfum)
go

/* ---- 4. columnas que sobran ---- */

/* sg_fume.fec_pago, ano_pago, mes_pago: ningun PA las lee.
   Soltarlas solo despues de verificar que 02_sg_efum.sql y la migracion corrieron. */
```

`sg_fum2` no necesita FK a `sg_efum`: es un histórico, y sus códigos deben poder sobrevivir a una
depuración del catálogo.

---

## Lo que arrastra en los PA

| PA | Cambio |
| :--- | :--- |
| `sg_fumeuSecgen01` | setear `rut_actua = @rut_person`, `fec_actua = getdate()` al insertar meses |
| `sg_fumeuSecgen02` | setear el par; `fec_valida` **deja** de escribirse aquí; agregar las 3 columnas al `insert` de `sg_fum2` y a su `select` |
| `sg_fumeuSecgen03` | setear el par; versionar también si cambia solo un descuento; agregar las 3 al `insert`/`select` de `sg_fum2` |
| `sg_fum2sSecgen01` · `02` | `h.cod_estcuo` → `h.cod_estfum`; devolver `mto_realpa`, `mto_deslic`, `mto_dessg`, `rut_actua`, `fec_actua` |
| `sg_fumesSecgen02` · `03` | devolver `rut_actua`, `fec_actua` |
| `sg_fupssSecgen17` | devolver `rut_actua`, `fec_actua` |
| `sg_fuc2iSecgen01` · `02` | setear `rut_regist = @rut_person`, `f_creacion = getdate()` |
| `sg_fuc2sSecgen01`…`03` | devolver los dos |
| **nuevo** `sg_epaguSecgen04` | *Aprobada → Enviada remuneraciones*: `cod_estcuo = 8`, `fec_pago`, `mto_realpa`, y por mes `cod_estfum = 3` + `fec_envrem` |
| **nuevo** `sg_fumeuSecgen04` | rechazo de un mes puntual: `cod_estfum = 4` |
| `sg_epaguSecgen03` | al aprobar, escribir `rut_autori` / `fec_autori` en los meses de la cuota |

Los dos PA nuevos son los que hoy dejan en cero cuatro agregados y `isRejected` en el frontend.
