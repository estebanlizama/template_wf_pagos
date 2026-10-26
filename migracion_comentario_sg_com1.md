# De `sg_hist` con prefijo a `sg_com1`: qué hay hoy y qué cambia

`sg_com1` ya existe en la BDD de prueba. Este documento contrasta el camino que
está implementado —`sg_hist` con la cuota codificada en el texto— con el que
habilita la tabla nueva, y deja los PA de lectura escritos.

Fecha: 26-10-2026.

---

## 1. Lo que hay hoy, exacto

### Escritura

`service-provision-payment-procedures.repository.ts` → `recordInstallmentHistory`,
llamada **antes** de `resolveDgdpInstallment` (líneas 876 y 887):

```ts
const prefix = `#PRS${staffProvisionId}-C${installmentNumber}# `;
const fullObservation = `${prefix}${observation}`.slice(0, 250);
const actionType = status === 3
  ? HistoryActionType.PAYMENT_INSTALLMENT_RETURNED   // 32
  : HistoryActionType.PAYMENT_INSTALLMENT_REJECTED;  // 33
try {
  await this.databaseService.runQuery(QUERY_CONTEXT, 'insertInstallmentHistory', {...});
} catch {
  /* La inserción de historial no bloquea la resolución */
}
```

`insertInstallmentHistory` ejecuta el PA **existente** `sg_histiSecgen03` con
`cod_tipsol`, `nro_solici`, `nro_resolu`, `ano_resolu`, `id_tipacc`, `observaci`,
`rut_accion` e `id_perfil = NULL`.

### Lectura

Dos métodos del mismo repositorio, los dos con `try/catch` silencioso y los dos
activos solo si alguna cuota está en estado 3 o 10:

| Método | Para quién |
| :--- | :--- |
| `attachReviewObservations(requestId, installments)` | solicitante |
| `attachDgdpReviewObservations(items)` | bandeja DGDP |

Los dos llaman `selectRequestHistorical` (`sg_histsSecgen02 @nro_solici`), que
devuelve **el historial completo de la solicitud** ordenado por `f_creacion`, y
después filtran en memoria: `id_tipacc in (32, 33)` y
`String(h.observaci).startsWith('#PRS{id}-C{n}#')`. El texto se entrega sin el
prefijo.

### Vista

`installment.reviewObservation`, en `Du288InstallmentFormSection.vue:41` y
`Du288InstallmentsSection.vue:49`.

### Y el límite de texto

220 caracteres: 250 del parámetro de `sg_histiSecgen03`, menos el prefijo.

---

## 2. Los cinco problemas de ese camino

1. **El error se silencia.** `sg_hist` **tiene** `FK_sg_hist_sg_tacc_4` sobre
   `id_tipacc`, y las semillas base de `sg_tacc` llegan hasta el código 30. Si
   `datos_base/05_sg_tacc_acciones_pago.sql` no está aplicado, **todo insert de
   comentario viola la FK**, el `catch` se lo come, DGDP devuelve la cuota y el
   motivo no se guarda. La pantalla no avisa nada.
2. **No es atómico.** Son dos llamadas sin transacción común. Si la segunda falla
   queda un motivo colgado; si el orden se invirtiera, una cuota devuelta sin
   decir por qué.
3. **La llave de la cuota vive en texto libre.** `#PRS4-C1#` no es indexable y
   ningún constraint la protege: si alguien edita `observaci` por fuera, la fila
   queda huérfana.
4. **Las filas de pago viajan en dos endpoints de resolución.**
   `sg_histsSecgen02` y `selectByNroResolutionAndRequestId` no filtran por
   `id_tipacc` ni por módulo. El aislamiento depende de un filtro del frontend
   que alguien tiene que recordar.
5. **Para un comentario se lee todo.** El historial completo de la solicitud
   —decretación, firmas, archivo— para quedarse con una fila.

---

## 3. Qué resuelve `sg_com1`

```sql
create table secgen_db.dbo.sg_com1 (
    id_funprse int      not null,
    nro_cuota  tinyint  not null,
    f_observa  datetime not null,
    id_tipacc  tinyint  not null,
    rut_accion char(9)  not null,
    observaci  text         null,
    constraint SG_COM1_PK primary key (id_funprse, nro_cuota, f_observa)
)
-- FK (id_funprse, nro_cuota) -> sg_epag
-- FK id_tipacc              -> sg_tacc
```

| Problema | Qué pasa con `sg_com1` |
| :--- | :--- |
| 1 · error silencioso | el `insert` va dentro de la transacción del PA: si falla, se revierte el cambio de estado y el mensaje llega al usuario |
| 2 · no atómico | una sola transacción: el motivo y el estado viven o mueren juntos |
| 3 · llave en texto | la FK compuesta a `sg_epag` **es** la llave de la cuota |
| 4 · acoplamiento | ninguna lectura de `sg_hist` la ve |
| 5 · leer todo | `max(f_observa)` por cuota, o el hilo de una cuota |

Y el límite de texto sube de 220 a 255: sin prefijo que descontar.

### Lo que **no** cambia: el código de acción

`id_tipacc` tiene **FK a `sg_tacc`**. Los códigos 32 y 33 siguen siendo
necesarios, y ahora son obligatorios de verdad: antes el insert podía fallar en
silencio; ahora bloquea la decisión.

Lo que se deja de usar es `sg_hist` **como tabla** y el prefijo en el texto. La
identificación por código de acción se mantiene, solo que pasa de una columna sin
FK a una con FK.

### Dos diferencias con el diseño previo (`sg_vpag`)

| | `sg_vpag` (propuesto) | `sg_com1` (real) |
| :--- | :--- | :--- |
| qué guarda | `cod_estcuo`, FK a `sg_ecuo` | `id_tipacc`, FK a `sg_tacc` |
| correlativo | `nro_linea` por cuota | `f_observa` en la PK |
| perfil | `id_perfil` | **no existe** |

- Guardar la **acción** en vez del **estado** obliga a traducir el código para
  reconstruir la decisión, y mantiene la dependencia de `sg_tacc`, que es un
  catálogo compartido con todo SISSOLIC.
- La fecha en la PK evita mantener un correlativo, a cambio de que dos
  comentarios de la misma cuota en el mismo tick del motor (≈3,3 ms en ASE)
  choquen. No se agregó lógica para esquivarlo: la cuota sale de estado 2 con la
  primera decisión, así que la segunda no pasa el `holdlock`, y si la colisión
  ocurriera, el `@@error` del `insert` revierte la transacción.
- Sin `id_perfil` se pierde *con qué perfil actuó* el revisor, que es el criterio
  de auditoría de `sg_hist`. Si importa, es una columna más.

---

## 4. Los PA

Escritos en `cambios_pa/sg_com1/`:

| PA | Para quién | Qué hace |
| :--- | :--- | :--- |
| `sg_com1sSecgen01` | revisor DGDP | hilo de una cuota, o de todas las de la prestación si no se indica `@nro_cuota`; más reciente primero |
| `sg_com1sSecgen02` | jefe de proyecto | comentario vigente de cada cuota de la prestación, en una consulta |

Un PA por rol, como el resto del flujo —`sg_epagsSecgen01` para el jefe de
proyecto, `sg_epagsSecgen03`/`sg_epagsSecgen04` para DGDP—. Cada uno lleva el
`not exists` de su rol copiado del PA equivalente: `sg_epagsSecgen04` para la
asignación DGDP (`sp_orde.cod_organi = 696`) y `sg_epagdSecgen01` para el
responsable vigente del centro de costo (`fin21_db..es_ecct`). Los dos reciben
`@id_funprse`, que es la mitad de la llave de la cuota; ninguno parte de
`@nro_solici`.

### El insert va inline en `sg_epaguSecgen03`

No hay PA de inserción. El motivo siempre acompaña una decisión, así que el
`insert` vive dentro de la transacción que mueve `cod_estcuo`, después de que el
`update` confirma que la cuota seguía en visación:

```sql
if @cod_estcuo in (3, 10)
begin
    declare @id_tipacc tinyint

    select @id_tipacc = case @cod_estcuo when 3 then 32 else 33 end

    insert into dbo.sg_com1 (...) values (..., getdate(), ...)

    if @@error <> 0
    begin
        rollback transaction
        select 'No fue posible registrar el motivo de la decision.' as msg
        return
    end
end
```

Y el PA pasa a **exigir** `@observacion` cuando el destino es 3 o 10 — hasta ahora
lo declaraba y lo descartaba. Si más adelante DGDP necesita dejar una nota **sin**
mover el estado, ahí sí corresponde un `sg_com1iSecgen01`.

No hay PA de `update` ni de `delete`:

- **update**: es auditoría. Corregir un comentario es agregar otro; el vigente es
  el de fecha mayor.
- **delete**: una cuota con comentarios está en 3 o 10, y `sg_epagdSecgen01` solo
  borra borradores (estado 1). Editar una cuota observada **no** la devuelve a 1
  —`sg_epaguSecgen01` conserva el estado—, así que un borrador nunca tiene
  comentarios.

---

## 5. Estado por capa

### Aplicado

| Capa | Cambio |
| :--- | :--- |
| `db-assets/.../service-provision-payment.ts` | `selectDgdpInstallmentComments` y `selectInstallmentComments`; fuera `insertInstallmentHistory` y `selectRequestHistorical` |
| `…payment-procedures.repository.ts` | `recordInstallmentHistory` borrado; las dos lecturas reescritas sobre `sg_com1`, agrupadas por prestación; `applyInstallmentComments` compartido |
| idem | `resolveDgdpInstallment` ya no consulta la bandeja completa para ubicar la solicitud |
| idem | tope de observación 220 → 255 (`INSTALLMENT_COMMENT_MAX_LENGTH`) |
| `du288-payment-review-decision-request.model.ts` | `maxLength` 220 → 255 |
| `review/_staffProvisionId/_installmentNumber.vue` | `maxlength` 220 → 255 |
| `history-action-type.constant.ts` | sin cambios: los dos códigos siguen usándose, ahora para `sg_com1` |
| Vista | sin cambios: `installment.reviewObservation` sigue siendo el contrato |
| `du288-installment-comment-response.model.ts` | modelo nuevo para el hilo de la cuota; no expone `rut_accion` |
| `du288-installment-response.model.ts` | `reviewObservationDate` junto al motivo vigente del solicitante |
| `du288-payment-review-installment-response.model.ts` | se le quitaron los campos de observación: ya no los puebla nadie |
| `service-provision-payment.controller.ts` | `GET …/dgdp/provisions/{id}/installments/{n}/comments`, con `assertIsDgdpPaymentReviewer` |
| `store/service-provision-payments.js` | `fetchDgdpInstallmentComments` |
| `review/_staffProvisionId/_installmentNumber.vue` | panel «Observación anterior» con fecha y autor, antes de los botones de decisión; contador de caracteres en el textarea |
| `review/index.vue` | sin cambios: el comentario no viaja con la bandeja |
| `Du288InstallmentFormSection.vue` | fecha junto a la observación que ya mostraba al solicitante |
| `lang/es/pds.js` | `previousObservation`, `observationLimit`, `cells.observed`, `cells.observedPrefix` |
| `service-provision-payment-comments.unit.ts` | 13 pruebas nuevas |

### Los dos roles no consumen el comentario igual

El primer intento adjuntó el motivo a las dos listas con el mismo criterio de
estados, y eso falló por los dos lados a la vez.

Por el lado de DGDP faltaba el estado 2: una cuota devuelta que el jefe de
proyecto corrige y reenvía vuelve a la bandeja **en visación**, con su fila de
`sg_com1` intacta —la llave no incluye el estado—, así que el revisor habría
resuelto de nuevo sin ver lo que él mismo observó. Pero agregar el 2 al criterio
dejaba una **consulta por prestación en la bandeja por defecto**, que es
justamente la de las cuotas en visación: la vista que se abre siempre pagaba una
consulta por fila.

El reparto quedó por consumidor, no por estado:

| Rol | Cómo llega | Alcance |
| :--- | :--- | :--- |
| jefe de proyecto | `sg_com1sSecgen02`, **dentro de la fila** de la cuota | el motivo vigente, en los estados 3 y 10; al reenviar la cuota ya atendió lo observado |
| DGDP | `sg_com1sSecgen01`, **recurso propio** de la cuota (`GET …/installments/{n}/comments`) | el hilo completo de esa cuota, pedido solo al abrir la revisión |

Así la bandeja DGDP no hace ninguna consulta de comentarios y la pantalla de
revisión hace una. El motivo solo hace falta donde se resuelve.

Una consecuencia de este reparto: en el recurso propio, una guarda del PA que
rechaza al revisor responde **403**, porque el revisor pidió ese recurso. En la
lectura que viaja con la cuota el mismo rechazo solo se registra en el log, ya
que no debe tumbar la entrega del listado.

Dos cosas más cambiaron de forma además de origen:

- **Se consulta por prestación o por cuota, no por solicitud.** Antes había que
  traerse el historial completo de la solicitud —decretación, firmas, archivo—
  para quedarse con una fila. Ahora cada consulta devuelve solo comentarios de
  cuota.
- **La lectura filtra `id_tipacc`.** Solo 32 y 33 se muestran como motivo, de
  modo que un código futuro —un comentario de aprobación— no aparezca como
  causa de devolución sin que nadie lo decida.

El `try/catch` silencioso de la **escritura** desapareció del todo: el motivo lo
graba el propio PA dentro de la transacción que mueve `cod_estcuo`, así que un
fallo llega al usuario como cualquier otro error de la decisión.

### Falta

| Capa | Cambio |
| :--- | :--- |
| `datos_base/05_sg_tacc_acciones_pago.sql` | **aplicarlo**, si no lo está. Es ahora un prerrequisito duro |
| `sg_com1sSecgen01` · `sg_com1sSecgen02` | desplegar |
| `sg_epaguSecgen03` | recompilar **después** de que exista `sg_com1` y estén las semillas |

Nada de esto se ha ejecutado contra Sybase. El backend compila y las 230 pruebas
unitarias pasan, pero las tres consultas apuntan a PA que todavía no existen en
la base: hasta desplegarlos, las lecturas fallan y el comentario no se muestra
—sin romper la entrega de las cuotas, que es justo lo que el `catch` protege—, y
la decisión DGDP falla al llegar al `insert`.

### Orden de despliegue

1. `sg_com1` (ya está en la BDD de prueba).
2. Semillas 32 y 33 en `sg_tacc`.
3. `sg_com1sSecgen01` y `sg_com1sSecgen02`.
4. `sg_epaguSecgen03` recompilado + backend, juntos.

El paso 2 **antes** del 4, sin excepción: con el insert dentro de la transacción,
una semilla faltante ya no se silencia — revierte la decisión y DGDP no puede
resolver ninguna cuota.

### Los comentarios ya escritos en `sg_hist`

Si en la BDD de prueba hay filas con `id_tipacc in (32, 33)`, quedan donde están:
la vista las dejará de leer. Migrarlas es un `insert ... select` que parsea el
prefijo para sacar `id_funprse` y `nro_cuota`; para datos de prueba no vale la
pena, y conviene decidirlo antes de pasar a un ambiente con datos reales.

---

## 6. Decisiones pendientes

1. **¿Comentario al aprobar?** Hoy solo se guarda en 3 y 10. La tabla admite
   `observaci` nulo, así que registrar la aprobación costaría un tercer código en
   `sg_tacc` (34) y dos líneas en el PA. Hace falta decidir si la aprobación debe
   dejar rastro con autor y fecha, o si basta `sg_epag`.
2. **¿Se agrega `id_perfil`?** Es la única columna de auditoría que `sg_hist`
   tenía y `sg_com1` no.
3. **¿Nota sin decisión?** Si DGDP debe poder comentar mientras revisa, sin mover
   el estado, hay que escribir `sg_com1iSecgen01`.
4. **¿Se limpian las filas viejas de `sg_hist`?** Desde este cambio no entran
   más, pero las que haya en la base de prueba siguen ahí y las sigue devolviendo
   `sg_histsSecgen02`, con el prefijo `#PRS..#` a la vista en el historial de la
   resolución. Borrarlas es
   `delete from secgen_db.dbo.sg_hist where id_tipacc in (32, 33)`; conviene
   decidirlo antes de un ambiente con datos reales.
5. **¿Se expone el hilo completo?** `sg_com1sSecgen01` acepta `@nro_cuota` y
   devuelve todas las decisiones de esa cuota, de la más reciente a la más
   antigua. Hoy el backend lo llama sin cuota y usa solo la vigente, porque la
   pantalla muestra un único motivo. Si el hilo tiene valor para el revisor, el
   PA ya está; falta el endpoint y la vista.
