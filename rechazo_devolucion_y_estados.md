# Rechazo, devolución y estados de la cuota — qué está implementado

Revisión del 26-10-2026. Complementa `decisiones_flujo_pago.md` §3.2 (el
catálogo decidido) y `revision_dgdp_implementado.md` (la pantalla de decisión).
Acá está **lo observable en el código**, el contraste con lo decidido, y el
análisis de cómo debería reaccionar.

Nada de esto se ejecutó contra Sybase. Lo que sigue se lee de los PA, del
repositorio y de las vistas.

---

## 1. La máquina de estados que el código implementa

Solo **dos** PA escriben `sg_epag.cod_estcuo`:

| PA | Transición | Guarda |
| :-- | :--- | :--- |
| `sg_epaguSecgen02` | 1 → 2 · 3 → 2 | `cod_estcuo not in (1, 3)` → rechaza |
| `sg_epaguSecgen03` | 2 → 3 · 2 → 4 · 2 → 10 | `cod_estcuo = 2` con `holdlock` y `@@rowcount <> 1` |

De ahí salen cinco transiciones sobre cuatro estados alcanzables:

```
1 Propuesta ──enviar──> 2 En visación ──┬──> 3 Observada ──enviar──> 2
                                        ├──> 4 Aprobada      (sin salida)
                                        └──> 10 Rechazada    (terminal)
```

**Los estados 8 y 11 no son alcanzables.** Ningún PA de `cambios_pa` los
escribe, y tampoco ninguno del repositorio de release: `sissolic-procedimientos`
solo menciona `cod_estcuo` en dos lecturas (`sg_fumeuSecgen01` y
`sg_fupssSecgen17`) y no tiene un solo `set cod_estcuo`. Es decir:

- **`4 Aprobada` es terminal en la práctica**, no un paso intermedio. No existe
  el cierre que movería 4 → 8.
- `sg_epag.mto_realpa` (`amountSent`) nunca se escribe hoy, porque lo escribiría
  ese cierre. Por eso la rama `status === 8` de
  `paymentInstallmentConsumedAmount` es código que todavía no se ejecuta.
- `11 Devuelta Finanzas` está decidido (§4 de `decisiones_flujo_pago.md`: «la
  devolución la registra DGDP a mano») pero **no tiene cómo registrarse**.

---

## 2. Qué hace exactamente el rechazo

`sg_epaguSecgen03` con `@cod_estcuo = 10`, todo dentro de una transacción:

1. **Exige motivo.** Si el estado es 3 o 10 y `@observacion` viene vacía →
   `Indique el motivo de la devolucion o del rechazo.`, antes de abrir la
   transacción. El rechazo sin razón es imposible por construcción.
2. **Relee el estado con `holdlock`.** Si la cuota ya no está en 2, hace
   `rollback` y devuelve `La cuota ya no esta en visacion.`. Dos revisores
   simultáneos no pueden resolver la misma cuota dos veces.
3. **Libera los meses:** `sg_fume.cod_estfum = 1` para los meses de la cuota que
   estaban en 2, vía `sg_dpag`.
4. **Borra `sg_dpag`** de la cuota.
5. **Marca el encabezado:** `cod_estcuo = 10`, con la guarda `cod_estcuo = 2` y
   `@@rowcount <> 1` → `rollback`.
6. **Inserta el motivo** en `sg_com1` con `id_tipacc = 33`, `rut_accion` del
   revisor autenticado y `f_observa = getdate()`. Si falla, `rollback`.

**No toca `sg_fups`.** Las cifras de la prestación no se guardan, se derivan.

El 3 (devolver) es el mismo PA sin los pasos 3 y 4: el encabezado pasa a 3, los
meses **siguen comprometidos** en 2, y el motivo entra con `id_tipacc = 32`.

---

## 3. Cómo queda bloqueada la cuota

El bloqueo está en la base, no solo en la pantalla. Las tres mutaciones del
solicitante se niegan por sí mismas:

| PA | Guarda | Mensaje |
| :-- | :--- | :--- |
| `sg_epaguSecgen01` editar | `cod_estcuo not in (1, 3)` | `Error: La cuota ya no es editable` |
| `sg_epaguSecgen02` enviar | `cod_estcuo not in (1, 3)` | `Error: La cuota no esta en un estado que permita enviarla` |
| `sg_epagdSecgen01` eliminar | `cod_estcuo <> 1` | `Error: Solo se puede eliminar una cuota en borrador` |

Encima de eso, la aplicación:

- `EDITABLE_STATUS = [1, 3]` en `du288-installment-response.model.ts` →
  `isEditable` falso para el 10.
- `activeInstallmentReadOnly` deja el detalle en solo lectura.
- `sendableInstallments` filtra por `isEditable`, así que el 10 no aparece en el
  selector de envío.
- `canDelete: code === 1` en `Du288InstallmentsSection.vue` → sin botón de
  eliminar.
- `Du288InstallmentEvidenceSection.vue` exige `[1, 3]` para permitir subir PDF.

Resultado: **una cuota rechazada es un registro permanente y de solo lectura**.
No se puede editar, reenviar, eliminar ni cambiarle el respaldo, y el motivo
queda colgado de ella en `sg_com1` con FK a `sg_epag`, así que sobrevive
mientras sobreviva la cuota — que es siempre.

---

## 4. Cómo se actualizan los datos de la cuota y de la prestación

**De la cuota:** solo `cod_estcuo`. El resto de la fila de `sg_epag` queda como
estaba.

**De la prestación:** nada se escribe. Los tres agregados se recalculan en el
frontend, en `utils/services-provision/normative/paymentValidations.js`, y los
tres excluyen el 10:

| Agregado | Función | Trato del 10 |
| :-- | :--- | :--- |
| Cupo de cuotas | `resolvePaymentQuota` | `filter(statusCode !== 10)` → libera el cupo |
| Saldo en pesos | `paymentInstallmentConsumedAmount` | no está en `[2,3,4,8,11]` → aporta 0 |
| Monto perdido | `resolvePaymentDroppedAmount` | recibe solo las no rechazadas |

Y los meses vuelven a `sg_efum = 1`, así que quedan disponibles para otra cuota.
Las tres liberaciones del catálogo —cupo, saldo y meses— están implementadas y
son consistentes entre la base y la vista.

---

## 5. Cómo se muestra hoy

**Lado solicitante** (`Du288InstallmentsSection.vue` + `Du288InstallmentFormSection.vue`):

- Insignia roja con `fa-circle-xmark` y la etiqueta `Rechazada`.
- Un chip `fa-comment-dots` cuando viene `reviewObservation`, con el texto
  completo en el `title` y el `aria-label` de «tiene observación».
- En el detalle, la sección «Observación de la DGDP» con la fecha y el texto en
  un cuadro de solo lectura.
- La fila se puede abrir: `actionOf` no mira el estado.

**Lado DGDP** (`pages/services-provision/payments/review/`): el hilo completo de
la cuota, de la decisión más reciente a la más antigua, con fecha y autor, por
el endpoint `.../installments/{n}/comments`.

---

## 6. Las seis brechas que encontré

Ninguna se corrigió: todas cambian comportamiento acordado o requieren una
decisión funcional.

### 6.1 La cuota rechazada pierde lo que se rechazó 🔴

Al borrar `sg_dpag` (paso 4), la lectura `sg_epagsSecgen01` agrupa sobre una
cuota sin meses. El solicitante ve:

```
Cuota 2 · Rechazada · $0 · 0 meses · —
```

`cant_meses = 0`, `mto_cuota = 0`, `mes_prop_min/max` nulos y —la ironía—
`cant_meses_rech = 0`, porque también cuenta a través de `sg_dpag`. Queda el
motivo en texto, pero **no queda rastro de cuánto ni qué meses se rechazaron**.
Para una decisión terminal con efecto patrimonial, el registro es un muñón.

Opciones, en orden de lo que cuesta:

1. **Dejarlo.** El motivo en texto alcanza como auditoría y la cifra se puede
   reconstruir de los meses, si nadie los reasignó. Es lo que hay hoy.
2. **No borrar `sg_dpag`, solo mover los meses a 1.** Preserva todo sin tabla
   nueva, pero obliga a filtrar `cod_estcuo <> 10` en cada lectura que una
   `sg_fume` con `sg_dpag`, o el mes aparecerá en dos cuotas. La PK de `sg_dpag`
   lo permite; el diseño no.
3. **Congelar las cifras en el encabezado antes de borrar.** `mto_realpa` está
   libre (una cuota rechazada nunca se cierra), pero su significado documentado
   es «lo que se envía a Finanzas». Sobrecargarlo confunde el modelo de tres
   montos.

Mi recomendación es la 2 si el registro histórico importa, con el filtro añadido
en las lecturas de mes como parte del mismo cambio. La 3 no: ahorra una
migración y cuesta la claridad del modelo.

### 6.2 El 11 está decidido y no se puede registrar 🔴

`sg_epaguSecgen03` solo acepta cuotas en 2. La vuelta de Finanzas que §4 dice
que «DGDP registra a mano» no tiene PA, endpoint ni pantalla. Y como el 8
tampoco es alcanzable, la secuencia `4 → 8 → 11` del catálogo es hoy
documentación sin implementación. Falta decidir si entra en esta fase.

### 6.3 Editar una cuota observada sí cambia sus meses ⚠️

§3.2 dice: «una cuota observada **no puede cambiar los meses que abarca** — solo
montos y respaldo. Cambiarlos es rechazarla y rehacerla».

El código hace lo contrario, y a propósito: `sg_epaguSecgen01` borra y reinserta
`sg_dpag` también en estado 3, y tiene un bloque `if @cod_estcuo = 3` que
devuelve a 1 los meses que salieron y compromete en 2 los que entraron, cada uno
con su manejo de `@@error`. Eso no es un descuido, es una función construida.

La conducta implementada me parece la correcta —si DGDP devuelve justamente
porque un mes no corresponde, forzar un rechazo y rehacer la cuota es
desproporcionado— pero **la decisión escrita dice otra cosa**. Hay que corregir
el documento o el PA, y es decisión funcional.

### 6.4 El 3 y el 10 se muestran con el mismo encabezado ⚠️

La sección del detalle se titula «Observación de la DGDP» en los dos casos, y el
título del formulario usa `fixTitle` («Corregir») solo cuando el código es 3; en
el 10 cae en `continueTitle` («Continuar»), que invita a seguir trabajando algo
que está cerrado. Nada en la pantalla dice que el rechazo es **terminal** ni que
el cupo y los meses volvieron a estar disponibles.

Es el arreglo más chico y más visible de la lista: una etiqueta distinta para el
10 («Motivo del rechazo») y una línea que diga que la cuota quedó cerrada y que
los meses se liberaron.

### 6.5 La lectura del solicitante no filtra el tipo de acción ⚠️

`attachReviewObservations` filtra por **estado de la cuota**
(`COMMENTED_INSTALLMENT_STATUS = [3, 10]`) y toma el comentario más reciente sin
mirar `id_tipacc`. La lectura DGDP sí filtra, por `REVIEW_COMMENT_ACTION_TYPES`.
Hoy da igual porque solo existen el 32 y el 33, pero en cuanto se cargue el
código 34 (comentario al aprobar, decisión abierta), una nota de aprobación
aparecería en la pantalla del solicitante rotulada como el motivo de la
devolución. Conviene alinear las dos lecturas al mismo filtro antes de cargar
cualquier código nuevo en `sg_tacc`.

### 6.6 `sg_com1sSecgen02` devuelve un RUT que nadie usa 🔸

La lectura del jefe de proyecto trae `com.rut_accion` y el modelo lo descarta:
`Du288InstallmentResponse` solo expone `reviewObservation` y
`reviewObservationDate`, y así quedó por diseño (el solicitante no ve quién
decidió). Sacar la columna del `select` evita que el RUT viaje sin motivo.

---

## 7. Cómo debería reaccionar, en una línea por actor

- **La cuota:** queda terminal y de solo lectura. Ya lo hace, y lo hace en la
  base, no solo en la pantalla. Lo que falta es que **se vea** terminal (6.4) y
  que conserve qué se rechazó (6.1).
- **Los meses:** vuelven a Propuesta y quedan disponibles. Ya lo hace.
- **La prestación:** recupera cupo y saldo sin escribir nada. Ya lo hace, y las
  tres funciones de `paymentValidations.js` coinciden con el catálogo.
- **El motivo:** obligatorio, inmutable, colgado de la cuota. Ya lo hace.
- **El solicitante:** debería poder crear una cuota nueva con esos meses de
  inmediato, sabiendo que la anterior está cerrada. Puede, pero la pantalla no
  se lo dice.

---

## 8. Qué se calcula y qué se muestra, en detalle

Revisado el 26-10-2026 a raíz del requisito: *al rechazar debe quedar en el
resumen que se rechazó y que no aplica, y se debe seguir mostrando lo
solicitado*.

### 8.1 Los tres agregados de la prestación

Los tres viven en `utils/services-provision/normative/paymentValidations.js`, se
exponen como getters en `store/service-provision-payment-detail.js` (líneas
95-96) y **se derivan de la lista de cuotas en cada render**. Ninguno se
persiste.

| Agregado | Getter | Fórmula | Aporte del estado 10 |
| :-- | :--- | :--- | :--- |
| Cupo de cuotas | `quotaSummary` | `authorized = tot_cuotas`; `requested` = cuotas con `statusCode !== 10`; `remaining = max(0, a − r)` | ninguno: libera el cupo |
| Saldo en pesos | `paymentBalance` | `authorized = mto_total`; `consumed = Σ paymentInstallmentConsumedAmount`; `proposed = Σ` estado 1; `remaining = max(0, a − c)` | 0: libera el saldo |
| Monto perdido | `resolvePaymentDroppedAmount` | recibe `otherInstallmentsAmount` solo de las no rechazadas | ninguno |

Las tres liberaciones son correctas y coinciden con el catálogo. **El problema no
está en el cálculo.**

### 8.2 Lo que muestra el resumen de la prestación

`Du288PaymentContextSection.vue`, grupo «Montos» (`amountFields`, líneas
128-155): tipo de monto, total decretado, tope mensual, «Cuota N de M», cuotas
decretadas, máximo normativo, pagado, comprometido y saldo.

**No hay una sola mención de rechazos.** Una cuota rechazada no aparece: solo
deja de contarse. Desde este resumen, «nunca pedí una segunda cuota» y «pedí una
segunda y me la rechazaron» se ven idénticos. Eso es justo lo que el requisito
pide corregir.

### 8.3 Lo que muestra la fila de la cuota

`Du288InstallmentsSection.vue`, `rows()` (líneas 168-187). Para una cuota
rechazada:

| Celda | Origen | Valor tras el rechazo |
| :-- | :--- | :--- |
| Solicitado | `requestedAmount` ← `mto_cuota` | **$0** |
| Neto | `netAmount` | vacío |
| Meses | `monthCount` ← `cant_meses` | **0 meses** |
| Período de pago | `mes_pago` / `ano_pago` | **se conserva** |
| Estado | `statusCode` | Rechazada, rojo, `fa-circle-xmark` |
| Comentario | `reviewObservation` | chip con el motivo en el `title` |
| Eliminar | `code === 1` | sin botón |

### 8.4 Por qué no es un problema de presentación

`cant_meses`, `mto_cuota`, `mto_deslic`, `mto_dessg`, `mes_prop_min`,
`mes_prop_max` y `cant_meses_rech` se calculan en `sg_epagsSecgen01` con un
`group by` sobre el `left join` a `sg_dpag`. El rechazo borra esas filas, así que
**el dato ya no existe cuando la pantalla lo pide**. Pintar «Rechazada» mejor no
alcanza: hay que conservar el vínculo cuota-meses o congelar las cifras.

Del encabezado sobrevive todo lo demás: `nro_cuota`, `cod_estcuo`, `rut_solici`,
`fec_solici`, `id_evidenc`, `fec_pago`, `ano_pago`, `mes_pago` y `mto_realpa`
(nulo). Es decir, la cuota rechazada conserva **cuándo se pidió, quién la pidió,
su PDF y su período de pago**; pierde **cuánto y qué meses**.

### 8.5 Una componente de resumen de cuota que no está montada

`Du288InstallmentSummarySection.vue` (340 líneas) calcula lo solicitado, los
descuentos, el neto, los topes, el saldo, lo que queda fuera del pago y una
lista de mensajes de estado. Es la candidata natural para «el resumen de la
cuota», pero **ninguna vista la monta**: la única referencia en todo el proyecto
es el registro de auto-importación de Nuxt (`.nuxt/components/index.js`). Y como
calcula todo desde su prop `months`, con `sg_dpag` vacío también daría cero.

Hay que decidir si se monta —y entonces es el lugar donde poner «rechazada, no
aplica»— o si se elimina.

### 8.6 Lo que hace falta para cumplir el requisito

Tres cambios, en este orden:

1. **Base: conservar el vínculo.** Quitar el `delete dbo.sg_dpag` de
   `sg_epaguSecgen03` y dejar solo la liberación de los meses a
   `sg_fume.cod_estfum = 1`. A cambio, toda lectura que una `sg_fume` con
   `sg_dpag` para saber en qué cuota está un mes debe filtrar
   `cod_estcuo <> 10`, o el mes aparecerá en dos cuotas a la vez. Hay que
   auditar esas lecturas antes de tocar el PA — es el trabajo real del cambio,
   no el `delete`.
2. **Agregados: que el rechazo no sume.** `paymentInstallmentConsumedAmount`
   seguirá devolviendo 0 para el 10 y `resolvePaymentQuota` seguirá
   filtrándolo, así que el «no aplica» queda garantizado por el cálculo actual
   sin tocar nada. Esto ya está; conviene cubrirlo con una prueba que fije la
   invariante, porque con `sg_dpag` vivo el `requestedAmount` de una cuota
   rechazada dejará de ser 0 y la tentación de sumarlo aparece sola.
3. **Pantalla: decirlo.** En la fila, mostrar el monto y los meses solicitados
   con un tratamiento de «no aplica» —tachado o atenuado— junto a la insignia
   Rechazada. En el resumen de la prestación, una línea con lo rechazado, para
   que la cifra no quede solo implícita en un conteo que bajó. Y en el detalle,
   el encabezado propio del 10 de §6.4.

Nada de esto se implementó todavía.

---

## 9. Recomendación: qué agregar y qué modificar

Auditoría del 26-10-2026 sobre las lecturas de `sg_dpag`, que es lo que decide
el camino.

### 9.1 Por qué cambié de opinión sobre conservar `sg_dpag`

En §6.1 recomendé no borrar `sg_dpag` y filtrar `cod_estcuo <> 10` en las
lecturas. La auditoría dice que eso cuesta mucho más de lo que parecía:

| Carpeta | PA que tocan `sg_dpag` | Referencias |
| :-- | :--- | :--- |
| `sg_epag` | 9 | 25 |
| `sg_fuc2` | 6 | 8 |
| `sg_fume` | 5 | 6 |
| **Total** | **20** | **39** |

No todas se rompen —muchas ya vienen acotadas por `nro_cuota`— pero **las 39 hay
que revisar una por una** para saberlo, y dos son bloqueantes:

- `sg_epagiSecgen01` líneas 215 y 262: dos `exists` sobre `sg_dpag`, el segundo
  con `holdlock` dentro de la transacción, que devuelven *«Error: Algun mes ya
  esta asignado a otra cuota»*. Con las filas de la cuota rechazada vivas,
  **el solicitante no podría volver a usar esos meses**. El rechazo dejaría de
  liberar justo lo que debe liberar.
- `sg_fumeuSecgen02`, `sg_fumeuSecgen03`, `sg_fuc2dSecgen01/02`,
  `sg_fuc2iSecgen01/02`: asignan `@cod_estcuo` a una variable escalar desde el
  join mes → cuota. Con dos cuotas candidatas, ASE toma una cualquiera, y de esa
  variable depende si el mes se puede editar o compensar. Es un error silencioso,
  del peor tipo.

Conclusión: `sg_dpag` es un vínculo **vivo** —responde «¿en qué cuota está este
mes?»— y una cuota rechazada ya no es parte del juego. Mantenerla ahí obliga a
que 39 lugares recuerden excluirla.

### 9.2 Lo que recomiendo: congelar las cifras en el encabezado

Una cuota rechazada es un registro **cerrado**. Lo que corresponde a un registro
cerrado es una foto, no un vínculo vivo. Y el modelo ya usa ese patrón:
`sg_epag.mto_realpa` existe precisamente para congelar en el encabezado el monto
final de la cuota al cerrarla. Guardar ahí lo rechazado no es sobrecargar una
columna ajena: es agregar su columna hermana.

**Base de datos — dos columnas nuevas en `sg_epag`:**

```sql
alter table secgen_db.dbo.sg_epag add mto_rechaz int null
alter table secgen_db.dbo.sg_epag add cant_mesre tinyint null
```

Nulas para todas las cuotas; con valor solo cuando `cod_estcuo = 10`. Sin
migración de datos: las cuotas rechazadas que ya existan quedan en null y se
muestran como hoy.

**`sg_epaguSecgen03` — calcular antes de borrar.** En el bloque
`if @cod_estcuo = 10`, antes del `delete dbo.sg_dpag`, sumar lo que la cuota
pedía y cuántos meses abarcaba, y guardarlo en el `update` del encabezado que ya
existe. Es un `select` de agregados y dos columnas más en un `update` que ya está
escrito, todo dentro de la transacción que ya está abierta. **Un solo PA cambia.**

**`sg_epagsSecgen01` y `sg_epagsSecgen03` — devolver las dos columnas.** Dos
líneas en cada `select`. No cambian joins ni `group by`: son columnas del
encabezado, ya agrupado.

### 9.3 Backend

- `du288-installment-response.model.ts`: `mto_rechaz → rejectedAmount`,
  `cant_mesre → rejectedMonthCount`, más sus `@property`.
- Igual en `du288-payment-review-installment-response.model.ts` para la bandeja
  DGDP.
- Nada más. No hay lógica nueva: son dos campos que viajan.

### 9.4 Frontend

1. **`paymentValidations.js` — un helper nuevo y ningún cambio en los
   existentes.**

   ```js
   export const resolvePaymentRejectedTotals = (installments = []) => ...
   ```

   Suma `rejectedAmount` y cuenta las cuotas en estado 10. Los tres agregados
   actuales **no se tocan**: `paymentInstallmentConsumedAmount` sigue devolviendo
   0 para el 10 y `resolvePaymentQuota` sigue filtrándolo, que es exactamente el
   «no aplica» que se pide. Conviene una prueba que fije esa invariante, porque
   en cuanto `rejectedAmount` exista la tentación de sumarlo aparece sola.

2. **`Du288InstallmentsSection.vue` — mostrar lo solicitado como «no aplica».**
   En `rows()`, cuando el código es 10, tomar el monto y los meses de los campos
   congelados y marcarlos: tachado o atenuado, con la insignia Rechazada al lado.
   Hoy esa fila dice `$0 · 0 meses`; debe decir lo que se pidió, visiblemente
   anulado.

3. **`Du288PaymentContextSection.vue` — una línea en el resumen.** En
   `amountFields`, agregar «Rechazado» con el total y el conteo. Hoy el resumen
   no menciona rechazos en ninguna parte, así que «nunca pedí una segunda cuota»
   y «me rechazaron la segunda» se ven idénticos. Esta línea es la que cierra el
   requisito de *«que quede en el resumen que se rechazó»*.

4. **`lang/es/pds.js`** — los rótulos nuevos, y el encabezado propio del estado
   10 de §6.4 («Motivo del rechazo» en vez de «Observación de la DGDP», y no
   caer en «Continuar» para una cuota cerrada).

5. **`Du288InstallmentSummarySection.vue`** — decidir: montarla con el bloque de
   rechazo incluido, o borrarla. Hoy son 340 líneas que ninguna vista usa.

### 9.5 Costo comparado

| | Conservar `sg_dpag` | Congelar en el encabezado |
| :-- | :--- | :--- |
| PA a revisar | 20, en 39 lugares | 3 |
| DDL | ninguno | 2 columnas nulas |
| Migración | ninguna | ninguna |
| Riesgo | mes en dos cuotas, o rechazo que no libera | ninguno nuevo |
| Fidelidad | total: qué meses, con qué montos | el total y el conteo, no el detalle mes a mes |

Lo que se pierde en la opción recomendada es el **detalle mes a mes** de una
cuota rechazada. Si eso hace falta más adelante, se agrega una tabla de foto
(`sg_dpa2`) sin deshacer nada de esto.
