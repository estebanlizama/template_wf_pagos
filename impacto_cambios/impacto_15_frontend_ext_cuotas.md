# Impacto en el frontend — `ext_cuotas` como check del centro de costo

Decisión: la extensión pasa a ser un **check que el solicitante marca**, asociado al centro de
costo, que viaja y se persiste **desde borrador hasta el envío**.

---

## 1. Lo que hay hoy: derivación en 14 puntos

Todo nace de una función:

```js
// utils/textSimilarityUtil.js:20
export const isAnidCostCenter = (source = {}) => {
  const indicator = source.ind_anid ?? source.indAnid ?? source.isAnid ?? source.esAnid
  if (indicator === true || ['S','SI','TRUE','1'].includes(...)) return true

  // sg_cctosSecgen05 entrega cod_tfinan; 44 corresponde a fondos de
  // terceros y es la señal ANID usada por el prototipo DU288 vigente.
  return Number(source.financingType ?? source.cod_tfinan ?? source.financiamiento_id) === 44
}
```

El comentario lo dice: *"la señal ANID usada por el **prototipo**"*. Es el mismo 44 que ya
eliminamos del backend y de los PA. **Es la última derivación viva.**

`PdsDu288RequestForm.vue` la envuelve en `isSelectedCostCenterAnid()` (`:4398`) y la consume en
**13 lugares**:

| Línea | Uso | Efecto |
| :--- | :--- | :--- |
| 339 | contexto del modal | informativo |
| 1194 | `getMaxDeclarableInstallments` | **cupo: 2 → 12** |
| 1420, 1452 | snapshot del centro | informativo |
| 2342 | contexto de validación | |
| 2838 | clave de caché | invalidación |
| 3013-3014 | etiqueta `capExemptAnid` | texto del tope |
| 3100 | validación de tope | **exención** |
| 3140 | nota de reducción de cupo | se omite |
| 4033 | **payload `indAnid` → PA 14** | **habilita cargo 3110** |
| 4352 | validación de monto | **exención** |
| 5330 | **payload `indAnid` → PA 15** | **habilita cargo 3110** |

Y `Du288StaffPreviousProvisionsModal.vue:1289` la recibe por contexto.

---

## 2. Pantallas y vistas afectadas

```
pages/services-provision/new-request-du288.vue     crear
pages/services-provision/_id/index.vue             ver / editar
     └── PdsDu288RequestForm.vue                   ← el check va acá
            ├── Du288RequestHeaderSection.vue      selección del centro de costo
            ├── Du288StaffRequestSection.vue       selector de cuotas (tot_cuotas)
            ├── ExecutionMonthsTags.vue            montos por mes
            └── Du288StaffPreviousProvisionsModal.vue   comparador DGDP
```

| Pantalla | Qué cambia |
| :--- | :--- |
| **Formulario, bloque centro de costo** | **nuevo check** "Extensión de cuotas autorizada" |
| **Formulario, selector de cuotas** | su máximo pasa a depender del check, no del catálogo |
| **Formulario, campo de tope** | la exención pasa a depender del check |
| **Modal comparador** | ya muestra el indicador; pasa a leerlo de la marca persistida |
| **Bandeja de pagos** | ya muestra el badge; sin cambios |

---

## 3. Servicios y payload

### 3.1 Lo que falta enviar

`extCuotas` **no se envía hoy** en el payload de la solicitud. El backend lo espera en
`request.provision.extCuotas` y sin eso `getCapExemptionIndicator` devuelve `undefined` →
`hasDeclaredCapExemption` da `false` → en edición se manda `NULL` y el PA conserva… **el valor
anterior, que nunca se escribió**.

Hay que agregarlo donde se arma `provision`, y debe viajar **también al guardar borrador**, no
solo al enviar.

### 3.2 Lo que ya se envía, y es el problema

Dos llamadas mandan `indAnid` derivado del catálogo:

| Servicio | Línea | PA destino |
| :--- | :--- | :--- |
| validación de inhabilidad de contrato | 4033 | `sg_fupssSecgen14` |
| `getNormativeStaffAssignments` | 5330 | `sg_fupssSecgen15` |

Los PA ya reciben `@ext_cuotas` en vez de `@ind_anid`, así que **el nombre del parámetro no
calza** — habrá que renombrarlo en el store y en el backend, o quitarlo (ver §6).

---

## 4. 🔴 El bloqueo: `getTopValidation` ignora la exención

`PdsDu288RequestForm.vue:3368` y `:3395`:

```js
if (capAmount <= 0) {
  return { valid: false, code: 'TOPE_FALTANTE', ... }   // bloquea
}
...
const isExceededByAppliedCap = monthlyAmount > capAmount  // compara igual
```

**No consulta la exención en ningún punto.** Mientras el backend con la marca activa omite la
validación completa (`:2908`), el front sigue bloqueando.

Consecuencia: **el usuario marca el check y el formulario no lo deja guardar.** El check no sirve
de nada hasta que esto se corrija.

---

## 5. Borrador → envío: qué implica persistir desde el borrador

La marca debe estar en `sg_fups.ext_cuotas` desde el primer guardado. Eso ya funciona: los PA
`sg_fupsiSecgen01` y `sg_fupsuSecgen01` la escriben en cualquier estado de la solicitud, no solo
al enviar.

Lo que **no** debe pasar es que el frontend la recalcule al recargar. Hoy sí lo hace:

- `PdsDu288RequestForm.vue:5117` reconstruye el centro de costo desde el catálogo vigente antes
  de reenviar
- `isSelectedCostCenterAnid()` lo deriva de ese centro recién leído

Entonces: se guarda `S`, se recarga, el catálogo dice otra cosa, y al reenviar va `N`. La marca se
pierde sin que nadie la toque.

**Al cargar la solicitud hay que leer `ext_cuotas` de la respuesta**, que ya viene expuesta por
`sg_fupssSecgen02`, y usar ese valor como estado del check — no volver a derivarlo.

---

## 6. Lo que arrastra: el cargo 3110

Con el 44 fuera, la única señal que llega a los PA 14/15 es la marca. Entonces **marcar el check
habilita al decano** (Q-D10).

| Opción | Qué implica |
| :--- | :--- |
| Dejarlo | el check libera meses, montos **y** cargos. Simple, pero un usuario decide una inhabilidad |
| Quitar el parámetro a los PA 14/15 | el check solo libera meses y montos; los cargos vuelven a la regla general |
| Agregar causal (`cod_excext`) | el check libera meses y montos; la causal ANID libera cargos |

**Esta decisión cambia el diff de los PA 14 y 15**: hoy renombré el parámetro; si se quita, el
diff correcto es eliminarlo.

---

## 7. Plan de cambios en el frontend

| # | Cambio | Archivo | Riesgo |
| :-- | :--- | :--- | :---: |
| 1 | `getTopValidation` respeta la exención | `PdsDu288RequestForm.vue:3368,3395` | **alto — bloquea el flujo** |
| 2 | Agregar `extCuotas` al payload de `provision` | `PdsDu288RequestForm.vue` | alto |
| 3 | Leer `ext_cuotas` al cargar y no derivar | `PdsDu288RequestForm.vue:5117` | alto |
| 4 | Check en el bloque de centro de costo | `Du288RequestHeaderSection.vue` | medio |
| 5 | `isSelectedCostCenterAnid()` → leer el check | `:4398` + los 13 consumidores | medio |
| 6 | Quitar el 44 de `isAnidCostCenter` | `textSimilarityUtil.js:20` | bajo |
| 7 | Renombrar `indAnid` → `extCuotas` en los 2 servicios | `:4033`, `:5330` + store | bajo |
| 8 | Renombrar `MAX_ANID_INSTALLMENTS` | `formatters.js:16` | bajo |
| 9 | Textos: `capExemptAnid` → extensión | `lang/es/pds.js` | bajo |

**El 1 va primero**: sin eso el check existe pero el formulario no deja avanzar.

El **3** es el que hace que "se guarde desde borrador hasta enviar" funcione de verdad; sin él la
marca se pierde en cada recarga.

---

## 8. Lo que no cambia

| | Por qué |
| :--- | :--- |
| `ExecutionMonthsTags.vue` | calcula desde el periodo y `cod_tpps` |
| Cupo por centro de costo (`monthDistributionCheck`) | cuenta claves año-mes; la exención entra por `getMaxDeclarableInstallments` |
| Traslapes de periodo y horario | fechas |
| Compensación, 56 hrs, parentesco | no dependen de la extensión |
| Bandeja de pagos | ya lee el indicador del PA 18 |
