# PA del Workflow de Pagos DU288

> [!IMPORTANT]
> **Dos carpetas, dos ambientes. No son versiones de lo mismo.**
>
> | | |
> | :--- | :--- |
> | `cambios_pa/` | **desarrollo** — lo que se está probando. Esta carpeta |
> | `sissolic-procedimientos/` | **última release** — lo que corre en producción |
>
> Un PA puede diferir entre las dos y que ambas estén correctas: producción tiene el
> esquema anterior y sus PA, desarrollo tiene el nuevo y los suyos. Comparar una contra
> otra para "verificar" lleva a falsas alarmas.
>
> Para saber qué hay en un servidor concreto: `sp_helptext` o `syscomments`, contra ese
> servidor.

Procedimientos del flujo de pago, sobre el esquema vigente
(`diagrama_bdd/diagrama_pagos_actualizada.md`). Estos archivos contienen PA; los cambios de
esquema propuestos, como la auditoría DGDP opcional, se mantienen aparte en `datos_base/`.

## El grano, en tres niveles

```
sg_fups  (id_funprse)                           un funcionario y su marco autorizado
  sg_fume  (id_funprse, corr_fume)              un MES propuesto   -> estado en sg_efum
  sg_epag  (id_funprse, nro_cuota)              una CUOTA          -> estado en sg_ecuo
    sg_dpag  (id_funprse, nro_cuota, corr_fume) qué meses abarca
```

La cuota **ya no es** la fila de `sg_fume`: son dos entidades con catálogos de estado
distintos, y sus códigos no coinciden. Mientras DGDP visa u observa la cuota, el mes no
se mueve.

## Quién es dueño de qué

| | Dueño | En la release |
| :--- | :--- | :--- |
| `sg_epag` · `sg_dpag` · `sg_fuc2` · `sg_ecuo` | pagos | no, son nuevos |
| `sg_fumesSecgen02` · `sg_fumeuSecgen02` | pagos | no, son nuevos |
| `sg_fume/sg_fumeuSecgen01` · `sg_fupssSecgen17` · `sg_fups/*` | resolución | **sí, con el esquema anterior** |
| `sg_ccto/sg_cctosSecgen05` | solicitud (compartido) | **sí** |

La última fila es la que importa para planificar: esos PA **ya existen en producción**, pero con
`nro_cuota` y `cod_estcuo`. Su migración a `corr_fume` / `cod_estfum` viaja junto con el cambio
de esquema, y **tiene que salir antes o con** lo de pagos — no después.

Pagos **no modifica** un PA de resolución para sus propias necesidades: crea uno nuevo.
El detalle de cada cambio está en [QUE_CAMBIO_Y_POR_QUE.md](QUE_CAMBIO_Y_POR_QUE.md).

Formato según `reglas_bdd_pa/reglas_estandarizacion_pa.md`.

## sg_fupssSecgen18 — listado de prestaciones pagables

Alimenta la bandeja del jefe de proyecto: prestaciones DU288 con resolucion
archivada de las que es responsable, con el avance de pago de sus cuotas.

### Por que filtra por el responsable vigente y no por `sg_prse.rut_jefpro`

Gestiona el pago quien esta a cargo del centro de costo hoy, no quien quedo
declarado en la resolucion. Filtrar por `rut_jefpro` dejaba las cuotas
impagables al cambiar el jefe de proyecto: el saliente perdia el acceso y el
entrante no recibia ninguna fila, porque el RUT congelado en la prestacion ya
no correspondia a nadie con el rol. Cerrando asi el conflicto entre S0-001
("jefe de proyecto del centro de costo", apunta al vigente) y Q-E03
("supervisor de dicha actividad", apunta al declarado): manda el vigente, y
`rut_jefpro` se devuelve igual como dato informativo para que el nuevo
responsable sepa a quien preguntar por la actividad.

Va como `exists` y no como `inner join` a proposito. Si un centro de costo
tuviera dos responsables vigentes, el join multiplicaria las filas y **todos
los `sum()` quedarian inflados** -- montos pagados y saldos al doble.

Con este filtro la autorizacion queda dentro del PA: quien no es responsable
vigente de ningun centro de costo recibe cero filas, sin necesitar una guarda
de rol aparte en el backend.

Queda un borde: un centro de costo sin responsable vigente deja sus
prestaciones invisibles para todos. Es poco probable, pero las cuotas se
pierden en silencio, asi que conviene una vista de DGDP sin el filtro o un
conteo de huerfanas.

### Normalizacion del RUT

El parametro es `char(9)`. Si el llamador envia menos caracteres, el motor
completa con espacios a la derecha y la comparacion falla en silencio. El PA
rellena con ceros a la izquierda para tolerar ambas formas.

### `@mes` es un corte, no un mes exacto

Trae las cuotas hasta `@ano`/`@mes` inclusive. Con mes exacto, una cuota
atrasada de agosto desaparecia al filtrar septiembre, que es justo lo que mas
urge gestionar.

### `cant_cuotas_disp` — cuotas sobre las que hoy se puede pedir pago

Cuenta las cuotas sin gestionar cuya ejecucion ya termino: su mes es anterior
al mes en curso, o la prestacion completa cerro antes de hoy. El segundo caso
cubre una prestacion corta dentro del mes actual, que de otro modo habria que
esperar al mes siguiente para cobrar. Responde a Q-A02: solo se paga trabajo
ya realizado.

### `per_pendiente_min` — atraso real

Mes mas antiguo sin gestionar, como entero `aaaamm`. Permite ordenar por
antiguedad y mostrar el atraso. La diferencia en meses debe calcularse como
`ano * 12 + mes`, no restando los enteros: `202601 - 202512` no es 1.

### `cod_estpag` — estado de pago derivado

Se calcula en el PA para que exista una sola definicion. La etiqueta de cada
codigo vive en el lang del frontend, igual que `paymentStatusLabel` en el modal
de prestaciones previas.

| Codigo | Estado | Condicion |
| :---: | :--- | :--- |
| 0 | Sin cuotas | La prestacion no tiene filas en `sg_fume` |
| 1 | Sin gestionar | Todas las cuotas en estado 1 |
| 2 | En tramite | Alguna cuota en 6, 7 u 8 |
| 3 | Pago parcial | Alguna cuota pagada y otras no |
| 4 | Pagada | Todas las cuotas en 9 |
| 5 | Con rechazo | Alguna cuota en 10 |

### `ext_cuotas` — extensión congelada en la resolución

El listado devuelve `sg_fups.ext_cuotas` junto con `tot_cuotas`. El backend lo
expone como `installmentExtensionIndicator` y `hasInstallmentExtension`, y la
bandeja muestra una marca cuando la prestación fue autorizada con extensión.
Para resoluciones nuevas, el flujo de pagos consume el snapshot y no permite
editarlo.

`ext_cuotas` es la única fuente de la excepción. Los PA de consulta devuelven
el valor persistido sin derivarlo de `cod_tfinan`, `ind_anid` ni otro dato del
centro de costo. Por lo mismo, un registro histórico nulo continúa nulo.

Cuando vale `S`, amplía el máximo desde 2 hasta 12 cuotas —sin superar los
meses de ejecución ni el año calendario— y omite la comparación contra el tope
mensual. Se mantienen las validaciones de saldo, monto total positivo, período
de ejecución y estado de los meses. PA14 y PA15 reciben la misma señal para las
validaciones de contrato y asignaciones.

### Activacion del menu de pagos

El menu se activa cuando la persona tiene al menos una prestacion en proceso,
es decir `cod_estpag` distinto de 4 (pagada) y de 0 (sin cuotas). Lo resuelve
`GET /requests/service-provision/payments/access-summary`, que el frontend
consulta una vez por sesion y cachea: no es un chequeo por render.

Ese resumen devuelve `isProjectManager` aparte, tomado de `sg_cctosSecgen05`
con `@id_modprse = 2` -- la misma definicion de jefe de proyecto que ya usa el
lado solicitante. Se mantiene separado porque sin el, cero prestaciones no
distingue "no tienes el rol" de "no tienes nada pendiente", y el estado vacio
no podria explicar por que la tabla esta vacia.

#### Si el menu no aparece: mirar primero `sg_cctosSecgen05`

El menu tiene tres cerrojos y los tres cuelgan del mismo privilegio derivado:

1. `layouts/default.vue` solo despacha `fetchAccessSummary` a quien ya trae
   `provision-payment-manage` en el token. Sin el privilegio, **la bandeja no
   se consulta nunca** -- no es que falle, es que no se pide.
2. `buildMenuForUser` descarta los items con `paymentsBranch` cuando
   `hasPaymentWork` es falso, que es su valor inicial.
3. El item declara `guardian: [provision-payment-manage]`.

El privilegio se deriva en cada `/auth/user` desde `sg_cctosSecgen05`, y ese
PA devuelve cero filas sin error cuando el centro de costo no cumple el
criterio DU288. En certificacion esto ocurrio con la version que filtraba por
`ccto.afec_du9 = 'S'` mientras la columna seguia nula: cero filas en 3 ms,
ningun mensaje, y el menu desaparecido junto con la bandeja y el listado. El
interruptor y la consulta de verificacion estan mas abajo, en
[sg_cctosSecgen05](#sg_cctossecgen05--criterio-du288-del-centro-de-costo).

`[AuthController] isCostCenterManager rut=... centros=N` deja el conteo en el
log del backend en cada login, que es la forma mas corta de separar "no tiene
el rol" de "el PA no encontro nada".

#### Este PA y el de permisos no usan el mismo criterio

`sg_fupssSecgen18` proyecta y agrupa `ccto.afec_du9` y `ccto.con_topdu9`, pero
no filtra por ellos: le basta `es_ecct.vigente = 'S'` mas el centro del
exists. `sg_cctosSecgen05` si filtra. Por eso una misma persona puede tener
prestaciones en la bandeja y no tener el privilegio para abrirla. Hoy es una
incoherencia conocida, no una regla: unificar la definicion en un solo lugar
queda pendiente de decision.

### Lo que el PA no resuelve

Devuelve conteos, no las cuotas una por una. Los chips de meses de la vista de
detalle se cargan con el PA de detalle, no con este.

---

## sg_cctosSecgen05 — criterio DU288 del centro de costo

Es un PA **compartido**, no de pagos: lo consulta el formulario de solicitud
para ofrecer centros de costo y `/auth/user` para derivar el privilegio
`provision-payment-manage`. Aparece acá porque el flujo de pagos es donde se
detectó que estaba dejando a todos afuera, y porque la corrección no es una
adaptación para pagos sino un arreglo del criterio que ambos lados comparten.
Por eso se edita en vez de crear uno nuevo, al revés de la regla general de
la sección anterior.

### El problema

Hay dos definiciones de «centro de costo afecto a DU288» conviviendo:

| Definición | Origen | Estado del dato |
| :--- | :--- | :--- |
| `cod_tfinan in (21, 44)` | se deduce del tipo de financiamiento | poblado |
| `afec_du9 = 'S'` | marca explícita del centro de costo | **nulo en todos los centros vigentes** |

La versión instalada en certificación filtra por `afec_du9` con la columna
todavía en blanco. Devuelve cero filas para cualquier RUT, sin error y en 3 ms.
Como de este PA se deriva el privilegio, eso apaga tres cosas de una: el menú
de prestaciones por pagar, la bandeja de gestión de pago y la selección de
centro de costo del formulario de solicitud.

### Cómo queda

`cod_tfinan in (21, 44)` **activo**, `afec_du9` **comentado**, con los dos
puntos de cambio rotulados dentro del propio PA:

```sql
/* CRITERIO DU288 (1 de 2) -- indicador */
case when ccto.cod_tfinan in (21, 44) then 'S' else 'N' end as ind_financiamiento_du288,
/* case when isnull(ccto.afec_du9, 'N') = 'S' then 'S' else 'N' end as ind_financiamiento_du288, */

/* CRITERIO DU288 (2 de 2) -- filtro */
and ccto.cod_tfinan in (21, 44)
/* and ccto.afec_du9 = 'S' */
```

Mantiene las columnas `afec_du9`, `con_topdu9` e `ind_anid` que la versión
instalada ya proyecta: se parte de ese cuerpo, no del de la última release.

### Al instalar en producción

Es el **punto 6** de `INTERRUPTOR-DU09`, y el único fuera de `sg_epag`. Se
enciende junto con los puntos 3 a 5: la misma columna vacía que bloquea crear
una cuota deja sin privilegio al jefe de proyecto, así que encender un lado sin
el otro deja el flujo a medias. Está rotulado con ese marcador dentro del PA,
de modo que `grep -rn "INTERRUPTOR-DU09"` lo encuentra.

Si `afec_du9` ya está poblada, se invierten **los dos** pares. No uno:

- Solo el `where` → `ind_financiamiento_du288` sigue saliendo `'N'` para filas
  que el PA sí devolvió, y la validación normativa del formulario las rechaza
  por financiamiento incompatible (`PdsDu288RequestForm.vue`,
  `compatibleFinancing !== 'S'`).
- Solo el indicador → entran centros que no son DU288.

Verificación de que la marca está lista, antes de invertir:

```sql
select isnull(ccto.afec_du9, '(nulo)') as afec_du9, count(*) as centros
from fin21_db..es_ccto ccto
where ccto.vigente = '1'
group by ccto.afec_du9
```

### Incoherencia conocida, no resuelta acá

`sg_fupssSecgen18` **lee** `afec_du9` y `con_topdu9` —los proyecta y los
agrupa— pero **no filtra** por ellos. Así, alguien puede tener prestaciones en
la bandeja y a la vez no tener la llave para abrirla. Unificar la definición en
un solo lugar queda pendiente de decisión.

---

## sp_as01sSecgen01 — consulta de asistencia, ausencias y justificaciones

Alimenta la validación de DGDP (Dependencia D3 / Sección H / PAG-33) para verificar si un
funcionario presenta licencias médicas, permisos sin goce o ausencias durante el periodo
de ejecución de una cuota de prestación DU288.

### Entradas
- `@rut char(9)`: RUT del funcionario a consultar.
- `@cod_periodo smallint`: Código de período de evaluación en `sisper_db..sp_prdo`.

### Salida
Devuelve el detalle diario ordenado cronológicamente con:
`diasem`, `feriado`, `fecha`, `hora_e`, `hora_s`, `m_ent`, `m_sal`, `res_ausen`, `excusa`, `cod_estasi`, `des_estasi`.

---

## sg_com1 — comentarios DGDP de una cuota

Tabla nueva, ya creada en la BDD de prueba. Reemplaza el camino anterior, que
guardaba el motivo en `sg_hist` con un prefijo `#PRS{id}-C{n}#` dentro del texto
libre para saber a qué cuota correspondía.

| PA | Para quién | Qué entrega |
| :--- | :--- | :--- |
| `sg_com1sSecgen01` | revisor DGDP | hilo de una cuota, o de todas las de la prestación si no se indica `@nro_cuota`; más reciente primero |
| `sg_com1sSecgen02` | jefe de proyecto | comentario vigente de cada cuota de la prestación, en una consulta |

El `insert` **no tiene PA propio**: va inline en `sg_epaguSecgen03`, dentro de la
misma transacción que mueve `cod_estcuo`. Un motivo siempre acompaña una
decisión, y separarlos reabre los dos estados inconsistentes que existían antes
—cuota devuelta sin motivo, o motivo sin devolución—. Tampoco hay `update` ni
`delete`: la tabla es auditoría, corregir es agregar otra fila, y una cuota con
comentarios nunca está en estado 1, que es el único que `sg_epagdSecgen01` borra.

Detalle del modelo, acceso y largos en [`sg_com1/README.md`](sg_com1/README.md).

### Orden de instalación

1. `sg_com1` — ya está en la BDD de prueba.
2. `datos_base/05_sg_tacc_acciones_pago.sql` — las acciones 32 y 33.
3. `sg_com1sSecgen01` y `sg_com1sSecgen02`.
4. `sg_epaguSecgen03` recompilado, junto con el backend.

**El paso 2 antes del 4, sin excepción.** `sg_com1.id_tipacc` tiene FK a
`sg_tacc` y el `insert` vive dentro de la transacción: sin las dos filas la
decisión se revierte y DGDP no puede resolver ninguna cuota. Antes ese mismo
error se perdía en un `catch` silencioso, así que la falta de semillas no se
notaba; ahora bloquea.

### Qué queda acoplado al backend

- El `@observacion` pasó a ser **obligatorio** cuando el destino es 3 o 10. El
  backend ya lo valida antes de llamar, así que recompilar el PA sin el backend
  no rompe nada, pero el backend sin el PA sí: la decisión falla al llegar al
  `insert`.
- El tope del texto subió de 220 a 255 en los tres puntos que lo declaraban
  (constante del repositorio, `maxLength` del request, `maxlength` del textarea).
  Sin prefijo que descontar, el parámetro se usa completo.
- Las dos lecturas no sirven al mismo consumidor. `sg_com1sSecgen02` entrega el
  motivo vigente **dentro de la fila de la cuota** para el jefe de proyecto, y
  `sg_com1sSecgen01` es un **recurso propio de la cuota** para DGDP, que la
  pantalla de revisión pide con `@nro_cuota`. Adjuntarlo a la bandeja obligaba a
  una consulta por prestación, y la bandeja por defecto son las cuotas en
  visación: era una consulta por fila en la vista que se abre siempre.

### Riesgos y decisiones abiertas

- Las filas con `id_tipacc in (32, 33)` que ya estén en `sg_hist` siguen ahí y
  `sg_histsSecgen02` las sigue devolviendo, con el prefijo a la vista en el
  historial de la resolución. Borrarlas es
  `delete from secgen_db.dbo.sg_hist where id_tipacc in (32, 33)`; conviene
  decidirlo antes de un ambiente con datos reales.
- `sg_com1` no guarda `id_perfil`, la única columna de auditoría que `sg_hist`
  tenía y esta no. Si la auditoría la necesita, es una columna más.
- Guarda la **acción** (`id_tipacc`), no el estado resultante. Reconstruir la
  decisión obliga a traducir el código contra `sg_tacc`.
- El comentario al **aprobar** no se registra. La tabla lo admite —`observaci`
  es nulable— y costaría un tercer código en `sg_tacc` y dos líneas en el PA.
