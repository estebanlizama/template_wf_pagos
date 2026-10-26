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

---

## 10. ¿Se pierde el dinero de una cuota rechazada? No

Verificado el 26-10-2026, capa por capa. La pregunta importa porque si se
construye una regla sobre una premisa equivocada, el error queda en la base.

### 10.1 Lo que vuelve, y dónde está escrito

| Qué | Dónde se libera | Verificado |
| :-- | :--- | :--- |
| El **cupo** de cuotas | `sg_epagiSecgen01` cuenta `where cod_estcuo <> 10`, dos veces: el prechequeo (línea 139) y el recuento con `holdlock` dentro de la transacción (línea 237) | sí |
| El **saldo** en pesos | `paymentInstallmentConsumedAmount` no incluye el 10 → aporta 0 al `consumed`, así que el `remaining` sube | sí |
| Los **meses** | `sg_epaguSecgen03` los devuelve a `sg_fume.cod_estfum = 1` | sí |
| El **monto del mes** | `sg_fumeuSecgen02` admite cambios cuando `cod_estfum = 1`, y no tiene cota superior contra el monto decretado: solo el tope mensual | sí |

Es decir: **el solicitante puede rearmar la cuota y volver a pedir lo mismo.**
Los meses vuelven a Propuesta, admiten cambio de monto, el cupo queda libre y el
saldo también. `sg_epagiSecgen01` exige que los meses estén propuestos (línea
211), y después del rechazo lo están.

La base y la vista coinciden en esto, que es lo que más importa: el frontend
(`resolvePaymentQuota`) y el PA (`cod_estcuo <> 10`) liberan el cupo con el mismo
criterio. No hay una pantalla prometiendo un cupo que el PA después niegue.

### 10.2 Un detalle de numeración que sí se nota en pantalla

`sg_epagiSecgen01` línea 250 numera con `max(nro_cuota) + 1` **sin** excluir el
10, y tiene que ser así: `nro_cuota` es parte de la PK y lo referencian `sg_dpag`
y `sg_com1`, así que no puede reutilizarse. El límite lo pone el conteo, no el
número.

Consecuencia: con `tot_cuotas = 2`, si se rechaza la cuota 2, la siguiente es la
**cuota 3 de 2 autorizadas**. Es correcto en la base y se ve mal en pantalla:

- `Du288InstallmentsSection` rotula la fila `Cuota 3`.
- `Du288InstallmentSummarySection` —si alguna vez se monta— arma
  `Cuota 3 de 2` y calcula `remaining = max(authorized − installmentNumber, 0)`,
  que da 0 y hace decir «es la última cuota» cuando el cupo está libre.

El arreglo es usar el **conteo de cuotas vigentes**, no el `nro_cuota`, para todo
rótulo de «X de Y». El `nro_cuota` sigue siendo el identificador; deja de ser el
ordinal que se muestra.

### 10.3 Dónde sí se pierde dinero, y no es el rechazo

Hay una pérdida real en el flujo, y conviene no confundirla con esta:
`resolvePaymentDroppedAmount` y `unreachableAmount`. Se pierde plata cuando un
mes se baja para que la cuota entre bajo el tope, o cuando quedan meses sin
pagar y ya no hay cuotas donde ponerlos. Eso es independiente del rechazo —de
hecho el rechazo **devuelve** una cuota al cupo y por lo tanto reduce esa
pérdida.

Y hay un caso que vale revisar aparte: tras un rechazo, los meses vuelven a
Propuesta **con el monto que tenían al enviarse**, no con el decretado. Si para
entrar bajo el tope se habían bajado, vuelven bajados. No es dinero perdido
—`sg_fumeuSecgen02` permite subirlos de nuevo— pero el solicitante tiene que
acordarse de hacerlo, y nada en la pantalla se lo recuerda. Ahí sí hay una
mejora: al rehacer una cuota con meses que vienen de un rechazo, avisar cuánto
están por debajo de su monto decretado.

### 10.4 Entonces qué mejoramos

El requisito «no se debe perder lo que se asignó» es correcto y es exactamente lo
que §9 arregla, con una corrección de alcance: no se pierde el **dinero**, se
pierde el **registro**. Y como no se pierde el dinero, no hace falta que la foto
sea pobre. Propongo dos capas:

**Capa 1 — las dos columnas de §9.2.** `mto_rechaz` y `cant_mesre` en el
encabezado. Alimentan la fila y el resumen: *«Cuota 2 · Rechazada · solicitaba
$X en N meses · no aplica»*. Tres PA, sin migración. Cierra el requisito.

**Capa 2 — la foto del detalle, `sg_dpa2`.** Una tabla con la misma forma que
`sg_dpag` más el monto del mes al momento del rechazo:

```sql
create table secgen_db.dbo.sg_dpa2 (
    id_funprse int      not null,
    nro_cuota  tinyint  not null,
    corr_fume  tinyint  not null,
    mto_apagar int      not null,
    constraint SG_DPA2_PK primary key (id_funprse, nro_cuota, corr_fume)
)
```

`sg_epaguSecgen03` la llena con un `insert … select` desde `sg_dpag`
inmediatamente antes del `delete` que ya hace, dentro de la misma transacción.
Y como **nadie más la lee**, no hereda ninguna de las 39 revisiones de §9.1: no
responde «¿en qué cuota está este mes?», solo «qué contenía esta cuota cerrada».
Una lectura nueva (`sg_dpa2sSecgen01`) la expone cuando se abre una cuota
rechazada.

Con las dos capas no se pierde nada: el resumen muestra el total, la fila muestra
lo solicitado anulado, y el detalle muestra mes por mes con cuánto pedía cada
uno. El motivo ya lo guarda `sg_com1`.

Mi recomendación es hacer las dos en la misma entrega: la capa 2 agrega una tabla
y un PA de lectura, no toca nada de lo existente, y es la diferencia entre «sé
que me rechazaron $X» y «sé exactamente qué me rechazaron».

**Corrección (ver §11): `sg_dpa2` no hace falta.** `sg_fum2`, en su versión
actualizada del 26-10, ya es esa tabla. La capa 2 pasa a ser «usar `sg_fum2`
como corresponde», que es más barato y además arregla cuatro PA que hoy no
compilarían.

---

## 11. `sg_fum2` actualizado: qué cambió y por qué importa acá

Comparación entre `template-du09/.../maestros/diagrama_secgen_actualizado.md`
(el anterior) y `diagrama_bdd/diagrama_secgen_act_26_10.md` (el vigente).

### 11.1 El diff

| | Antes (18 columnas) | Ahora (23 columnas) |
| :-- | :--- | :--- |
| Identifica el mes con | `nro_cuota` | **`corr_fume`** |
| PK | `(id_funprse, nro_cuota, correlativ)` | `(id_funprse, corr_fume, correlativ)` |
| Estado versionado | `cod_estcuo` | **`cod_estfum`** |
| Montos | solo `mto_apagar` | `mto_apagar` + **`mto_realpa`**, **`mto_deslic`**, **`mto_dessg`** |
| Autoría de la versión | no tenía | **`rut_regist`**, **`f_regist`** |
| FK | `sg_fume(id_funprse, nro_cuota)` | `sg_fume(id_funprse, corr_fume)` |

El cambio de fondo: `sg_fum2` dejó de ser el historial *de la cuota* y pasó a ser
el historial **del mes**, espejo exacto de `sg_fume` más tres columnas de versión.
Y ganó precisamente lo que faltaba para guardar una decisión: los descuentos, el
neto y **quién la registró y cuándo**.

### 11.2 Nuestros PA quedaron a medio camino

Están migrados en la llave —ya usan `corr_fume`— pero no en el resto:

| PA | Línea | Problema |
| :-- | :--- | :--- |
| `sg_fum2sSecgen01` | 54, 76 | lee `h.cod_estcuo` |
| `sg_fum2sSecgen02` | 69, 82, 105 | lee `h.cod_estcuo` |
| `sg_fumeuSecgen02` | 172 | inserta en la columna `cod_estcuo` |
| `sg_fumeuSecgen03` | 127 | inserta en la columna `cod_estcuo` |

`cod_estcuo` **no existe** en el `sg_fum2` vigente. Los cuatro fallarían a la
compilación con *invalid column name*. Según `cambios_pa/README.md` línea 40
estos PA son nuevos y no están desplegados, así que **corregirlos no cuesta nada
en producción**: es una corrección previa al despliegue, no una migración.

Dos consecuencias más, que no son renombres:

1. **`sg_fumeuSecgen03` calcula `mto_deslic`, `mto_dessg` y `mto_realpa`** en
   `sg_fume` pero **no los versiona** en `sg_fum2`, aunque las tres columnas
   ahora existen para eso. El historial de descuentos se está perdiendo hoy.
3. **`rut_regist` y `f_regist` nunca se escriben.** Ninguna versión dice quién la
   hizo. Es justo el dato que falta para que el historial sirva como respaldo.

Un falso positivo que descarté: `sg_fum2sSecgen02` línea 69 filtra
`cod_estcuo in (2, 3, 4, 8, 10, 11)`, pero sobre `sg_epag`, no sobre `sg_fum2`.
Está correcto, es el estado de la cuota.

### 11.3 Por qué esto reemplaza a `sg_dpa2`

Tenías razón: para guardar estos datos ya está `sg_fum2`. Con las cinco columnas
nuevas, una fila de versión puede decir *«este mes pedía $Y, con estos
descuentos, en este estado, registrado por R el día F»*. Eso es exactamente la
foto que §9.4 quería lograr con una tabla nueva.

Le falta una sola cosa: **en qué cuota estaba el mes.** El diagrama anterior lo
tenía (`nro_cuota`) y la actualización lo quitó al cambiar la llave al mes. Para
el rechazo hace falta, porque la pregunta es «qué contenía la cuota 2 cuando la
rechazaron».

Propongo agregarlo como columna de contenido, no de llave:

```sql
alter table secgen_db.dbo.sg_fum2 add nro_cuota tinyint null
```

Nula para las versiones que el mes tenga fuera de toda cuota. Con eso `sg_fum2`
queda autosuficiente y el detalle del rechazo sale de una sola lectura, sin
tabla nueva y sin tocar `sg_dpag`.

### 11.4 El plan que queda

1. **Corregir `cod_estcuo` → `cod_estfum`** en los cuatro PA, y resolver el
   filtro de `sg_fum2sSecgen02`. Sin costo: no están desplegados.
2. **Agregar `nro_cuota` a `sg_fum2`** y poblarlo en los dos `insert` que ya
   existen, leyéndolo de `sg_dpag`.
3. **Versionar los tres montos y la autoría** en los dos `insert`:
   `mto_realpa`, `mto_deslic`, `mto_dessg`, `rut_regist`, `f_regist`.
4. **`sg_epaguSecgen03` versiona al rechazar.** Antes del `delete` de `sg_dpag`,
   un `insert into sg_fum2` por cada mes de la cuota, con su monto, su cuota, el
   RUT del revisor DGDP y la fecha. Ahí queda la foto completa, en la tabla
   correcta, dentro de la transacción que ya está abierta.
5. **Las dos columnas de §9.2 en `sg_epag`** siguen siendo útiles para que la
   fila y el resumen no tengan que agregar el historial en cada render.

Esto deja sin efecto la propuesta de `sg_dpa2`.

---

## 12. Lo implementado el 26-10-2026

Regla decidida por el usuario: **el rechazo bloquea y descuenta.** Eso dejó sin
efecto las dos columnas nuevas de §9.2: al conservar `sg_dpag`, `mto_cuota` y
`cant_meses` siguen saliendo del join de siempre, así que la cuota rechazada
muestra lo que solicitó sin DDL alguno.

**Base de datos — `cambios_pa`**

- `sg_epaguSecgen03`: al rechazar, versiona cada mes de la cuota en `sg_fum2`
  (con los tres montos, `rut_regist` y `f_regist` del revisor), pasa los meses a
  `sg_efum = 4` y **ya no borra `sg_dpag`**. Todo en la transacción que ya existía,
  con guarda de 255 versiones y `rollback` en cada `@@error`.
- `sg_epagiSecgen01`: el conteo de cupo —las dos veces, el prechequeo y el
  recuento con `holdlock`— ya no excluye el estado 10. La cuota rechazada
  consume su cupo.
- `sg_fum2sSecgen01`, `sg_fum2sSecgen02`, `sg_fumeuSecgen02`, `sg_fumeuSecgen03`:
  `cod_estcuo` → `cod_estfum`, el nombre del diagrama vigente. Sin esto los
  cuatro fallaban a la compilación.
- `sg_fumeuSecgen02` y `sg_fumeuSecgen03`: los dos `insert` a `sg_fum2` ahora
  versionan `mto_realpa`, `mto_deslic`, `mto_dessg`, `rut_regist` y `f_regist`.

**Catálogos y decisiones**

- `datos_base/01_sg_ecuo.sql`: el 10 pasa de «libera cupo, saldo y meses» a
  «bloquea», con la fecha y el motivo del cambio.
- `datos_base/02_sg_efum.sql`: la transición `2 → 1` pasa a `2 → 4`, PAGOS ya no
  escribe el 1, y la sección «los dos rechazos son distintos» se reescribió: el
  estado del mes es el mismo y lo que cambia es el alcance.
- `decisiones_flujo_pago.md` §3.2: la regla «rechazar sí libera» quedó invertida
  y fechada.

**Backend**

- `du288-month-version-response.model.ts`: `statusCode` lee `cod_estfum`, y el
  comentario que justificaba el nombre viejo se reemplazó por el del cambio.

**Frontend**

- `paymentValidations.js`: el 10 entra en `paymentInstallmentConsumedAmount`,
  `resolvePaymentQuota` cuenta todas las cuotas, y se agregó
  `resolvePaymentRejectedTotals` —solo para mostrar, porque el monto ya está en
  `consumed` y sumarlo al saldo lo contaría dos veces—.
- `store/service-provision-payment-detail.js`: getter `paymentRejected`, y
  `usedQuota` pasó a leer `quotaSummary.requested` en vez de recontar con otro
  criterio, que era una segunda definición del mismo cupo.
- `Du288InstallmentsSection.vue`: la fila rechazada muestra el monto solicitado
  tachado y atenuado, con el rótulo «Rechazado» en vez de «Solicitado».
- `Du288PaymentContextSection.vue`: línea «Rechazado» en el resumen de montos,
  con el total, el conteo y la explicación en el `hint`. Solo aparece si hay
  rechazos.

**Verificación**

- Frontend: 14 archivos de prueba, 16 casos en `paymentValidations`, todo
  correcto. ESLint limpio en los seis archivos tocados.
- Backend: `lb-tsc` sin errores, 230 pruebas unitarias correctas.
- PA: paridad `.sql`/`.txt`, CRLF y ASCII verificados en los seis; balance de
  `begin`/`end` de `sg_epaguSecgen03` cuadrado a mano.
- **Nada se ejecutó contra Sybase.** La compilación de los seis PA y el
  comportamiento del rechazo en la base siguen sin verificar.

**Lo que queda pendiente**

- El encabezado propio del estado 10 en el detalle (§6.4): sigue diciendo
  «Observación de la DGDP» y el formulario sigue cayendo en «Continuar».
- `Du288InstallmentSummarySection.vue` sigue sin montarse (§8.5).
- El aviso de meses que vuelven por debajo de su monto decretado ya no aplica:
  con la regla nueva los meses no vuelven.
- Las brechas 6.2, 6.3 y 6.5 siguen abiertas.

---

## 13. `sg_fume` → `sg_fum2`: el historial completo

### 13.1 Qué cambió en `sg_fume` (el diff que faltaba)

| | Antes | Ahora (26-10) |
| :-- | :--- | :--- |
| Llave | `(id_funprse, nro_cuota)` | `(id_funprse, corr_fume)` |
| Estado | `cod_estcuo`, FK a `sg_ecuo` | `cod_estfum`, FK a `sg_efum` |
| Salieron | `fec_pago`, `ano_pago`, `mes_pago` | — (se fueron a `sg_epag`) |
| Entraron | — | `mto_realpa`, `mto_deslic`, `mto_dessg` |

El cambio de fondo es el mismo que en `sg_fum2`: **el mes dejó de pertenecer a
una cuota.** Antes la llave del mes incluía `nro_cuota`, así que un mes era de
una cuota por definición; ahora el mes existe por sí solo y el vínculo vive en
`sg_dpag`. Por eso el período de pago se fue al encabezado: es de la cuota, no
del mes.

### 13.2 `sg_fum2` es un espejo exacto

Las 20 columnas de `sg_fume`, más tres de versión:

| | |
| :-- | :--- |
| `correlativ` | qué versión es |
| `rut_regist` | **quién** la provocó |
| `f_regist` | **cuándo** |

No falta ninguna columna y no hay ninguna de más. Es la forma correcta para un
historial: cada fila es el mes completo tal como estaba **antes** del cambio, y
las tres columnas dicen quién lo cambió y cuándo.

### 13.3 Auditoría: los seis escritores de `sg_fume`

| PA | Qué escribe en `sg_fume` | Versionaba antes | Ahora |
| :-- | :--- | :--- | :--- |
| `sg_fumeuSecgen02` | el monto del mes | sí | sí |
| `sg_fumeuSecgen03` | descuentos DGDP y neto | sí | sí |
| `sg_epaguSecgen03` | rechazo: estado → 4 | no | **sí** |
| `sg_epaguSecgen02` | ENVIAR: estado 1 → 2 | **no** | **sí** |
| `sg_epaguSecgen01` | editar cuota observada: 2 → 1 y 1 → 2 | **no** | **sí** |
| `sg_fumeuSecgen01` | crea y borra meses (RESOLUCION) | no | no, ver 13.5 |

Tres escrituras cambiaban el estado del mes **sin dejar historial**. Eran justo
las del ciclo de trabajo: enviar la cuota, reacomodar sus meses y rechazarla.
El historial registraba los cambios de plata y se perdía los de estado.

### 13.4 Cómo quedó implementado

El patrón es el mismo en los tres PA, deliberadamente repetido en vez de
abstraído, como el resto del repositorio: recorrer los meses afectados con un
`while`, y por cada uno calcular `max(correlativ) + 1` con `holdlock`, guardar
la fila completa de `sg_fume` en `sg_fum2` con `rut_regist` y `f_regist`, y
recién después hacer el `update`. Todo dentro de la transacción que cada PA ya
abría, con guarda de 255 versiones y `rollback` ante `@@error`.

- `sg_epaguSecgen02`: recorre los meses de la cuota vía `sg_dpag`, solo en la
  rama `@cod_estcuo = 1`. En un reenvío desde Observada los meses ya están en 2
  y no cambian, así que no hay nada que versionar.
- `sg_epaguSecgen01`: junta en `#cambio` los meses que **salen** (están en 2 y
  ya no figuran en `sg_dpag`) y los que **entran** (están en `#corr` y en 1), y
  los versiona en un solo recorrido. Una fila por mes y por edición: el mes
  cambia una sola vez en la operación.
- `sg_epaguSecgen03`: recorre los meses de la cuota antes de bloquearlos en 4.

Dos columnas más que nadie llenaba, ya corregidas en los dos `insert` que sí
existían: `sg_fumeuSecgen02` y `sg_fumeuSecgen03` ahora versionan también
`mto_realpa`, `mto_deslic`, `mto_dessg`, `rut_regist` y `f_regist`. Antes el
historial de descuentos se perdía aunque la tabla ya tenía dónde guardarlo.

### 13.5 Lo único que no se puede versionar

`sg_fumeuSecgen01`, del flujo de RESOLUCION, crea y borra meses:

- **Al crear** no hay nada que versionar: el mes no existía antes.
- **Al borrar** no se puede. `sg_fum2` tiene FK a `sg_fume` con
  `ON DELETE RESTRICT`, así que una fila de historial **impediría** el borrado
  del mes. Hoy el `delete` funciona justamente porque no hay historial.

Si se quiere conservar el rastro de un mes borrado hay que decidirlo aparte:
cambiar la FK, o aceptar que el acortamiento del período borra el mes sin
registro. No lo toqué: es del flujo de resolución, y la regla del proyecto es
que pagos no modifica un PA de resolución para sus necesidades.

### 13.6 En qué momento exacto se escribe una versión

Cinco acciones la escriben, y cada una tiene su guarda. En todas la fila se
inserta **antes** del `update`, dentro de la transacción del PA, así que guarda
el mes tal como estaba antes del cambio.

| Acción del usuario | PA | Se versiona cuando | Qué queda en la foto |
| :-- | :--- | :--- | :--- |
| El jefe de proyecto cambia el monto de un mes | `sg_fumeuSecgen02` | `@mto_actual <> @mto_apagar` | el monto anterior |
| DGDP registra descuentos del mes | `sg_fumeuSecgen03` | cambia `mto_apagar`, `mto_deslic` **o** `mto_dessg` | descuentos, neto y `val_*` anteriores |
| El jefe de proyecto envía la cuota a visación | `sg_epaguSecgen02` | solo si la cuota venía del estado 1 | el mes en Propuesta, antes de comprometerse |
| El jefe de proyecto reacomoda los meses de una cuota observada | `sg_epaguSecgen01` | solo si la cuota está en 3, y solo los meses que entran o salen | el mes antes de entrar o de salir |
| DGDP rechaza la cuota | `sg_epaguSecgen03` | solo con destino 10 | el mes comprometido, antes de bloquearse |

**Guardar sin cambiar nada no versiona.** Las dos primeras comparan contra el
valor vigente, así que reenviar el mismo monto o los mismos descuentos no
ensucia el historial. Las tres últimas versionan solo los meses que realmente
cambian de estado.

**Qué NO escribe historial de mes, y está bien:** devolver la cuota (3) y
aprobarla (4). Ninguna de las dos toca el mes —se queda en 2— así que no hay
nada de él que fotografiar. Esas decisiones viven en `sg_com1`, que es el
historial de la cuota. Son dos historiales con grano distinto: `sg_fum2` guarda
lo que le pasó al mes, `sg_com1` lo que DGDP decidió sobre la cuota.

### 13.7 El hueco que apareció al revisar los momentos

`sg_fumeuSecgen03` versionaba **solo si cambiaba el monto**
(`if @mto_nuevo <> @mto_apagar_actual`), pero su `update` escribe siete campos:
`mto_apagar`, `mto_deslic`, `mto_dessg`, `mto_realpa`, `val_licmed`,
`val_singoce` y `fec_valida`.

Consecuencia: en el caso normal —DGDP registra una licencia médica sin tocar el
monto solicitado— **no se escribía ninguna versión**. Los descuentos anteriores,
el neto y las marcas `val_*` se sobrescribían sin dejar rastro. Era la decisión
más importante que DGDP toma sobre un mes y era la única sin historial.

Corregido: el PA ahora lee `mto_deslic` y `mto_dessg` vigentes y versiona si
cambia cualquiera de los tres.

### 13.8 Cómo llega el historial a las dos vistas

Auditoría del 26-10-2026. La cadena del historial **de meses** ya está completa
de punta a punta en los dos roles; no hay nada que construir ahí.

| Capa | Solicitante | DGDP |
| :-- | :--- | :--- |
| PA | `sg_fum2sSecgen01`, 29 columnas, acota por responsable del centro de costo | `sg_fum2sSecgen02`, las mismas 29, acota por asignación vigente |
| Grano | **por mes** (`@corr_fume`, opcional) | **por cuota** (`@nro_cuota`, vía `sg_dpag`) |
| Modelo | `Du288MonthVersionResponse`, incluye `rut_regist` → `registeredByRut` y `f_regist` → `registeredAt` | el mismo |
| Endpoint | `/payments/provisions/{id}/month-versions?monthSequence=` | `/payments/dgdp/provisions/{id}/installments/{n}/month-versions` |
| Store | `fetchMonthVersions` | `fetchDgdpMonthVersions` |
| Vista | `Du288MonthVersionsModal` montado en `_nroSolici/index.vue` | el mismo modal en `review/.../_installmentNumber.vue` |

El modal ya muestra versión, monto, descuentos, monto a pagar, variación,
estado, **registrado por** y **fecha de registro**, y agrega la fila vigente al
final para que la lectura sea continua.

**La diferencia que importa:** DGDP ve el historial **de toda la cuota** en una
sola tabla; el solicitante lo abre **mes por mes** desde la fila del mes. No
tiene el «qué cambió en esta cuota» completo.

### 13.9 Lo corregido ahora en el modal

La columna «Variación» se calculaba solo con el delta de monto, así que una
versión cuyo cambio fue el **estado** —y desde §13.3 esas son la mayoría:
enviar, reacomodar, rechazar— aparecía con un guión, igual que una fila vacía.
Ahora dice «Solo estado», atenuado, y el subtítulo del modal menciona los
cambios de estado entre lo que registra.

### 13.10 Lo que falta para el historial por cuota, y lo que cuesta

1. **Vista por cuota para el solicitante — solo frontend.** `monthSequence` ya
   es opcional en el store, en el controlador y en el PA, así que una llamada
   sin ese parámetro devuelve el historial de toda la prestación. La página ya
   sabe qué meses tiene la cuota activa, así que alcanza con filtrar por ellos y
   abrir el mismo modal desde la cuota en vez de desde el mes. **Sin PA nuevo y
   sin endpoint nuevo.**
2. **El hilo de decisiones para el solicitante.** `sg_com1sSecgen02` devuelve
   solo el comentario más reciente de cada cuota, por diseño. Para que el
   solicitante vea todas las devoluciones de su cuota hace falta un parámetro
   que desactive el `max(f_observa)`, o una lectura nueva. Es una decisión
   funcional: hoy se decidió mostrarle solo el vigente.
3. **Los dos historiales siguen separados.** `sg_fum2` responde «qué le pasó al
   mes» y `sg_com1` «qué decidió DGDP sobre la cuota». Hoy viven en dos lugares
   distintos de la pantalla. Lo natural sería un solo «Historial de la cuota»
   que mezcle las dos fuentes ordenadas por fecha: las decisiones con su motivo
   y los cambios de mes con su monto. No es gratis —hay que unificar dos formas
   de fila en una vista— pero es lo que convierte dos tablas técnicas en una
   historia legible.

Mi recomendación es el 1 primero, porque no toca la base y le da al solicitante
exactamente lo que DGDP ya tiene. El 3 después, como vista propia. El 2 depende
de que se decida mostrarle el hilo completo.

### 13.11 Repaso de UX sobre lo agregado

Revisión del 26-10-2026 de lo que quedó en pantalla, buscando efectos
secundarios de haber conservado `sg_dpag`.

**Dos defectos reales, corregidos**

1. **La cuota rechazada mostraba «A pagar».** `netLabel` se pinta cuando el neto
   difiere de lo solicitado. Si DGDP había registrado descuentos antes de
   rechazar, la fila de una cuota terminal anunciaba un monto a pagar que no va
   a ocurrir. Ahora el neto no se muestra en estado 10.
2. **La cuota rechazada reclamaba requisitos.** Los chips «Sin PDF» y
   «Compensación pendiente» se calculaban igual para el 10, mandando a resolver
   algo que ya no tiene cómo resolverse. Ahora una cuota rechazada no exige
   nada.

**Un pendiente de §6.4, cerrado**

El cuadro de la observación usaba el mismo encabezado para el 3 y el 10. Ahora
el 10 dice «Motivo del rechazo» —y el `aria-label` del textarea también—, porque
no dicen lo mismo: en una devuelta el texto es lo que hay que corregir, en una
rechazada es la razón por la que quedó cerrada. El título del modal y el borde
rojo del bloque ya estaban resueltos.

**Lo que revisé y está correcto**

- El selector de meses ya contempla el mes bloqueado: `availabilityOf` marca no
  seleccionable cuando `statusCode === 4` o la cuota del mes está en 10, con su
  razón. Estaba escrito anticipando esta regla.
- `availableMonths` excluye los meses asignados a una cuota, así que los de una
  rechazada no vuelven a ofrecerse.
- `monthsMissingCompensation` se acota a la cuota por enviar, que siempre es
  editable, así que nunca apunta a una rechazada.
- El monto anulado no depende solo del color: cambia el rótulo a «Rechazado»,
  va tachado y la insignia roja con ícono dice «Rechazada». Tres señales, no
  una.
- «Cuota N de M» dejó de poder decir «3 de 2»: al consumir el cupo, la
  numeración ya no puede pasarse del total autorizado.

**Lo que queda, menor**

- Los `hint` del resumen se muestran como `title` del `dd`, así que no se
  alcanzan por teclado ni los lee todo lector de pantalla. Es el patrón de todo
  el componente —los seis `hint` existentes son iguales—, así que cambiarlo solo
  para «Rechazado» sería incoherente. Si se arregla, va de una vez para los
  siete.
- La fila rechazada dice «N meses» sin señalar que quedaron bloqueados. La
  insignia y el motivo lo explican, pero el dato suelto no.
- Falta verificar en navegador: el tachado y el rótulo nuevo a 991, 768 y
  375 px, y el modal de versiones con filas «Solo estado».

### 13.12 Segunda pasada: un defecto más de versionado y tres textos que mentían

**Versionado: `sg_fumeuSecgen02` tenía el mismo defecto que los descuentos.**

El `update` escribe cuatro columnas —`mto_apagar`, `ano_ejec`, `mes_ejec` y
`fec_valida`— pero versionaba solo `if @mto_actual <> @mto_apagar`. **Cambiar el
mes de ejecución sin tocar el monto no dejaba rastro.** Corregido igual que el
caso de los descuentos: lee los valores vigentes y versiona si cambia cualquiera
de los tres (`fec_valida` es `getdate()`, derivado, no entra en la condición).

Auditoría completa de columnas de `sg_fume` escritas por pagos:

| PA | Columnas que escribe | Versiona si cambia |
| :-- | :--- | :--- |
| `sg_epaguSecgen01` | `cod_estfum` (a 1 y a 2) | sí, los meses que entran y salen |
| `sg_epaguSecgen02` | `cod_estfum` a 2 | sí |
| `sg_epaguSecgen03` | `cod_estfum` a 4 | sí |
| `sg_fumeuSecgen02` | `mto_apagar`, `ano_ejec`, `mes_ejec`, `fec_valida` | **los tres** (antes solo el monto) |
| `sg_fumeuSecgen03` | `mto_apagar`, `mto_deslic`, `mto_dessg`, `mto_realpa`, `val_licmed`, `val_singoce`, `fec_valida` | **los tres de entrada**; los otros se derivan de ellos |

No queda ninguna escritura de pagos sin historial.

**Columnas que pagos no escribe nunca:** `fec_envrem`, `rut_autori`,
`fec_autori`, `val_inabili` y `val_ciecc`. Pertenecen al cierre hacia Finanzas
—el estado 8, que según §1 no es alcanzable—. `sg_fum2` ya tiene lugar para
ellas; cuando ese paso se implemente, su PA tiene que versionar también.

**Las dos vistas: tres textos que describían la regla vieja.**

1. 🔴 **El diálogo de confirmación de DGDP.** `effectReject` decía: *«La cuota
   queda Rechazada, sus meses vuelven a Propuesta y se liberan para otra cuota.
   Libera el cupo.»* Exactamente lo contrario de lo que ahora ocurre, en la
   única decisión sin vuelta atrás y justo en el momento de confirmarla. Ahora
   dice que los meses quedan bloqueados, que el monto se descuenta del total,
   que la cuota consume su cupo y que no se puede deshacer.
2. ⚠️ **La nota bajo los botones.** `note` repetía lo mismo. Reescrita.
3. ⚠️ **La bandeja DGDP.** `releasedMonths` («Meses liberados por el rechazo»)
   se muestra cuando la cuota tiene cero meses. Al conservar `sg_dpag` eso ya no
   pasa por un rechazo: pasa en un **borrador sin meses todavía**, que habría
   quedado rotulado como rechazo. Ahora dice «Sin meses asignados».

El primero es el hallazgo importante de esta pasada: el resto de la pantalla ya
reflejaba la regla nueva, pero el texto que el revisor lee antes de apretar
«Rechazar» le prometía algo reversible.

### 13.13 Verificación

Balance de `begin`/`end` cuadrado a mano en los dos PA editados (descontando
los `case … end`), paridad `.sql`/`.txt`, CRLF y ASCII correctos. **Ningún PA se
compiló contra Sybase**: el `while` sobre `#cambio`, los `holdlock` dentro de la
transacción y el largo de las listas de columnas siguen sin verificar en el
motor.

---

## 14. Lo que falta: el DDL no existía

### 14.1 El hallazgo

Un `grep` de `alter table|create table secgen` en todo el proyecto devuelve dos
resultados, y los dos están **dentro de un comentario** de
`datos_base/03_migracion_sg_fume.sql`, describiendo el plan. No había ni una
sentencia DDL ejecutable en el proyecto.

Lo que sí había:

- `diagrama_bdd/diagrama_secgen_act_26_10.md` — el destino, como diagrama.
- `datos_base/orden_de_despliegue.md` — una tabla de 10 pasos que *narra*
  «CREATE TABLE sg_efum», «ALTER TABLE sg_fume ADD cod_estfum», en prosa.
- `datos_base/README.md` — decía literalmente «El DDL va aparte, en el modelo».

«En el modelo» significaba: en ninguna parte que se pueda correr.

### 14.2 Por qué bloquea todo lo demás

Los PA escritos en esta sesión referencian columnas y tablas que el esquema
anterior no tiene:

| Referencia | Dónde |
| :--- | :--- |
| `sg_fum2.correlativ`, `rut_regist`, `f_regist` | los 4 PA que versionan |
| `sg_fum2.cod_estfum`, `mto_realpa`, `mto_deslic`, `mto_dessg` | los 4 PA que versionan + los 2 de lectura |
| `sg_fume.cod_estfum`, `mto_deslic`, `mto_dessg`, `mto_realpa` | casi todos |
| `sg_epag`, `sg_dpag`, `sg_com1` | todo el flujo de pagos |

Comparando la lista de tablas de los dos diagramas: el anterior tiene las 67
tablas del esquema y **no contiene `sg_com1`, `sg_dpag`, `sg_efum` ni
`sg_epag`**. Las cuatro son nuevas, y de las cuatro el orden de despliegue solo
menciona la creación de `sg_efum`.

Sin el DDL, ninguno de los PA de pagos compila. No es un pendiente de mejora: es
el primer paso del despliegue.

### 14.3 Lo que se escribió

`datos_base/00_ddl_pagos.sql`. Tres criterios:

1. **Idempotente.** Cada paso se guarda contra `sysobjects` o `syscolumns` y
   dice qué hizo o por qué no hizo nada. Correrlo dos veces no falla.
2. **No borra nada.** Los `DROP` de `cod_estcuo` y de
   `fec_pago`/`ano_pago`/`mes_pago` siguen siendo el paso 9 del orden de
   despliegue, después de verificar la migración. Adelantarlos deja caído el WF
   de resolución — es la ventana 1 de `orden_de_despliegue.md`.
3. **Sin la FK de `cod_estfum`.** La columna nace `NULL` porque hay que poblarla
   con `03_migracion_sg_fume.sql` antes de poder exigirla. Pasarla a `NOT NULL`
   con su FK es el paso 5, y va aparte a propósito.

Termina con tres consultas de verificación. La última es la que importa:
devuelve las columnas de `sg_fume` que faltan en `sg_fum2`, y **debe salir
vacía** — si no, el espejo histórico no es espejo y las lecturas de `sg_fum2`
mienten sin avisar.

### 14.4 Lo que el script no puede saber

Se escribió comparando los dos diagramas, no contra la base. Hay dos cosas que
solo se resuelven con acceso al motor:

- Si `sg_epag`, `sg_dpag` o `sg_com1` **ya existen** en el ambiente real a pesar
  de no estar en el diagrama anterior. Si existen con otra estructura, el script
  las deja como están y lo informa; hay que resolverlo a mano.
- Los tipos exactos. `mto_*` como `int`, `rut_*` como `char(9)` y `corr_fume`
  como `tinyint` vienen del diagrama y de lo que ya usan los PA, pero nadie los
  verificó contra `syscolumns`.

El encabezado del script trae las dos consultas que hay que correr antes.

### 14.5 Documentos que quedaron al día

`datos_base/README.md` seguía describiendo el criterio anterior en cuatro
lugares, y es el documento que lee quien despliega:

| Dónde | Decía | Dice |
| :--- | :--- | :--- |
| catálogo `sg_ecuo`, el 10 | «libera cupo, saldo y meses» | «**bloquea** cupo, saldo y meses (26-10-2026)» |
| catálogo `sg_efum`, el 1 | «resolución · y pagos al liberar por rechazo» | «**solo resolución** · pagos ya no devuelve meses al 1» |
| «Los dos rechazos» | «Los meses vuelven a 1 Propuesta y liberan cupo y saldo» | quedan en 4, conservan `sg_dpag`, descuentan el monto, consumen el cupo |
| «Reglas de escritura» | «los valores 2, 3 y el retorno a 1» | 2 y 3; **nadie devuelve un mes al 1** |

Y la sección «Pendiente» —«si DGDP descarta un mes de una cuota que ya consumió
cupo, falta decidir si ese cupo se devuelve o se pierde»— **ya está decidida**:
se pierde. Reemplazada por la decisión con su fecha y su razón.

---

## 15. Repaso de consistencia, gestión y estándares

Tres hallazgos. Dos son contradicciones que dejó la regla del 26-10 y se
corrigieron; el tercero es una decisión funcional pendiente.

### 15.1 La bandeja invitaba a crear una cuota que la base iba a rechazar

`sg_fupssSecgen18` calcula el cupo así:

```sql
(select count(*)
   from secgen_db.dbo.sg_epag ep
  where ep.id_funprse = fu.id_funprse
    and ep.cod_estcuo <> 10)                                as cuotas_creadas,
```

Y `sg_epagiSecgen01` —el PA que crea la cuota— dejó de excluir el 10 en esta
misma sesión, porque el rechazo ahora consume el cupo. Las dos lecturas del
mismo cupo quedaron en desacuerdo.

El recorrido completo del defecto: `cuotas_creadas` → `createdInstallments`
(`du288-payable-provision-response.model.ts:49`) → `remainingInstallments()` y
`installmentsTooltip()` en `pages/services-provision/payments/index.vue`.

Con una resolución de 2 cuotas y las 2 rechazadas, la bandeja mostraba
**«0 de 2 cuotas»** y el tooltip **«2 cuotas restantes»**; el chip
`quotaExhausted` no aparecía nunca. El jefe de proyecto pedía una tercera y la
base le respondía que la resolución no autoriza más. La pantalla lo invitaba a
un callejón.

Corregido: la subconsulta ya no filtra por estado.

`cuotas_gestion` **sí** sigue excluyendo el 10, y está bien: una cuota rechazada
no está en trámite. Es una medida de actividad, no de cupo.

### 15.2 El saldo no descontaba lo rechazado — y una validación lo usaba

```sql
fu.mto_total
  - isnull(sum(case when fume.cod_estfum = 3 then fume.mto_realpa end), 0)
  - isnull(sum(case when fume.cod_estfum = 2 then fume.mto_apagar end), 0) as mto_saldo,
```

Restaba lo pagado y lo comprometido, pero no lo rechazado. Desde el 26-10 ese
dinero está descontado del total decretado, así que `mto_saldo` devolvía plata
que ya no existe.

Lo grave no es que se vea mal, es dónde se usa:

```js
const balanceAmount = Number(validationAmount || staff.remainingAmount || ...)
// store/service-provision-payment-detail.js:196
```

`remainingAmount` alimenta el saldo contra el que corren las validaciones de
monto. Una cuota nueva podía pasar la validación apoyada en el monto de una
cuota rechazada.

Corregido: se agregó la resta de los meses en `cod_estfum = 4`, que conservan su
`mto_apagar` precisamente porque el rechazo no borra lo solicitado.

En el frontend, la celda de monto solo mostraba el desglose cuando había algo
pagado. Con un rechazo y nada pagado se veía únicamente el total, sin señal de
que se hubiera descontado nada. Ahora el desglose aparece cuando el saldo dejó
de ser el total, cualquiera sea la razón — pagado, en gestión o rechazado.

No hace falta una columna `mto_rechaz`: el badge de la fila ya dice
«Con rechazo» (`cod_estpag = 5`) y el saldo corregido muestra el efecto.

### 15.3 Estándar: `sg_epaguSecgen03` era el único PA con `rollback` sin guarda

| PA | rollback | con `@@transtate` |
| :--- | :---: | :---: |
| `sg_epaguSecgen01` | 8 | 8 |
| `sg_epaguSecgen02` | 4 | 4 |
| `sg_fumeuSecgen02` | 3 | 3 |
| `sg_fupsuSecgen01` | 7 | 8 |
| **`sg_epaguSecgen03`** | **6** | **0** |

En ASE un `rollback transaction` sin transacción activa levanta el error 3903.
Si el motor ya abortó la transacción —una violación de integridad, por
ejemplo—, el `rollback` desnudo falla y el `select '…' as msg` que viene después
**no llega a correr**: el backend recibe un error de Sybase en vez del mensaje
de dominio, y lo mapea a un 500 genérico.

Justamente en el PA de la decisión DGDP, que es donde el mensaje importa:
«La cuota ya no esta en visacion» es lo que el revisor tiene que leer cuando
otro se le adelantó.

Corregido en los 6 sitios, con el orden de la casa: mensaje primero, rollback
guardado después.

```sql
select 'La cuota ya no esta en visacion.' as msg
if @@transtate = 2 rollback transaction
return
```

### 15.4 Las horas compensadas de una cuota rechazada — ajustado

Tres PA excluían del cruce de horarios los tramos cuya cuota quedó rechazada:

| PA | Qué hace |
| :--- | :--- |
| `sg_fuc2iSecgen01` | registro del tramo por el jefe de proyecto |
| `sg_fuc2iSecgen02` | registro del tramo por DGDP |
| `sg_fuc2sSecgen03` | lectura de los tramos ocupados, que pinta la pantalla |

```sql
and not exists (
    select 1 from sg_dpag dp, sg_epag ep
    where dp.id_funprse = fc.id_funprse
      and dp.corr_fume  = fc.corr_fume
      and ep.id_funprse = dp.id_funprse
      and ep.nro_cuota  = dp.nro_cuota
      and ep.cod_estcuo = 10
)
```

#### Por qué se quitó: los dos cruces no decían lo mismo

Cada PA de registro hace **dos** controles de superposición, y no eran
simétricos:

| Control | Alcance | Filtro de estado |
| :--- | :--- | :--- |
| «El tramo está duplicado o superpuesto» | `fc.id_funprse = @id_funprse` | **ninguno** |
| «Ya tiene compensación en otra prestación» | `fc.id_funprse <> @id_funprse` | excluía el 10 |

Dentro de la misma prestación, el tramo de un mes rechazado **ya bloqueaba** —
el control no mira el estado de nada. Cruzando prestaciones, no. El mismo hecho
—horas ya compensadas sobre una cuota rechazada— bloqueaba o no según desde
dónde se mirara. Eso era incoherente antes del 26-10 y sigue siéndolo después.

El segundo argumento es la regla nueva. La exclusión se entendía mientras el
rechazo liberaba los meses: esas horas volvían a estar disponibles porque el mes
volvía a estar disponible. Desde el 26-10 el mes queda en `sg_efum = 4` y no se
ofrece nunca más, así que la hora ya trabajada no se libera tampoco.

Y el fondo es físico: `fec_comrea`, `hora_ini`, `hora_ter`. Una hora de reloj se
trabaja una vez. Que no se haya pagado no la devuelve.

#### Qué cambió

Se quitó el bloque en los tres. En `sg_fuc2sSecgen03` el `not exists` era el
único uso de `sg_dpag` y `sg_epag`, así que las dos tablas salieron del PA
completas; en los de registro quedan solo donde leen el estado de la cuota del
mes, que es su guarda de entrada.

Los tres tenían que moverse juntos. Lo dice el encabezado de la propia lectura:

> «Aplica los mismos filtros que el control de escritura de `sg_fuc2iSecgen01` y
> `sg_fuc2iSecgen02`. Si filtraran distinto, se mostrarían menos días ocupados
> de los que el registro rechaza, que es peor que no mostrarlos.»

Ese es justamente el valor del ajuste. La lectura alimenta
`Du288ExecutedCompensationSection.vue` («Compensado por el mismo funcionario en
otras prestaciones este mes»), que pinta los tramos ocupados para que el jefe de
proyecto elija alrededor de ellos. Con la exclusión, las horas de una cuota
rechazada se veían libres y el error aparecía al guardar. Ahora se ven ocupadas
antes de elegirlas.

#### Lo que esto le cuesta al funcionario

Nada que no estuviera decidido. No pierde horas: pierde **esas** horas, las que
ya usó. Puede compensar otras para la otra prestación. Es la misma penalización
que ya se aplica al mes dentro de su prestación, aplicada de forma consistente.

Lo que sí cambia es que casos que hoy pasan van a empezar a fallar, con el
mensaje «El funcionario ya tiene compensación realizada en ese horario en otra
prestación». Si eso no es lo que se busca, el ajuste a revertir son esos tres
bloques y nada más.

### 15.5 Lo que se revisó y estaba bien

- **Guardas de estado.** Los 4 PA de `sg_fuc2` y `sg_fumeuSecgen03` bloquean
  correctamente una cuota rechazada: los del jefe de proyecto exigen
  `cod_estfum = 1` o `cod_estcuo = 3`, los de DGDP exigen `cod_estcuo = 2`. Una
  cuota en 10 con meses en 4 falla en los dos caminos.
- **Estilo del mensaje.** `select '…' msg` y `select '…' as msg` conviven en
  `sissolic-procedimientos` (106 y 136 usos). Cada archivo de `cambios_pa` es
  internamente consistente, así que no hay nada que unificar.
- **`cant_cuotas_rech`** ya cuenta los meses en 4 y `cod_estpag = 5` ya pinta la
  fila como «Con rechazo». La señal visual del rechazo en la bandeja existía.

### 15.6 Verificación

ESLint limpio en la página modificada; 14 archivos de prueba del frontend y 16
casos de `paymentValidations` correctos.

Los 5 PA editados —`sg_fupssSecgen18`, `sg_epaguSecgen03`, `sg_fuc2iSecgen01`,
`sg_fuc2iSecgen02` y `sg_fuc2sSecgen03`— pasan paridad `.sql`/`.txt`, CRLF y
ASCII, con los `begin`/`end` cuadrados (18/18, 19/19 y 4/4 en los de `sg_fuc2`)
y sin referencias residuales a `cod_estcuo = 10`.

**Ninguno se compiló contra Sybase.** En particular, que los tres PA de
`sg_fuc2` sigan siendo sintácticamente válidos después de sacarles un
`not exists` del medio de un `where` largo —y que `sg_fuc2sSecgen03` funcione sin
`sg_dpag` ni `sg_epag` en su `from`— está verificado por lectura, no por el
motor.

### 15.7 Qué probar cuando haya base

Un recorrido corto que cubre los cuatro cambios:

1. Resolución de 2 cuotas. Crear la cuota 1, enviarla, rechazarla.
   → la bandeja debe decir **«1 de 2»**, no «0 de 2», y el saldo debe haber
   bajado en el monto de esa cuota.
2. Crear la cuota 2, enviarla, rechazarla.
   → la bandeja debe decir **«2 de 2»** con el chip de cupo agotado, y
   `sg_epagiSecgen01` debe negar una tercera.
3. Con dos revisores DGDP sobre la misma cuota, decidir en los dos al mismo
   tiempo.
   → el segundo debe recibir **«La cuota ya no esta en visacion.»**, no un 500.
4. Registrar un tramo de compensación en una prestación, rechazar su cuota, y
   registrar el mismo horario en otra prestación del mismo funcionario.
   → debe salir **«El funcionario ya tiene compensacion realizada en ese
   horario en otra prestacion»**, y la pantalla debe haber pintado ese horario
   como ocupado antes de intentarlo.
