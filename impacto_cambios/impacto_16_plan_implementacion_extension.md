# Plan de implementación — validar por extensión

Principio: **la extensión reemplaza al concepto ANID.** ANID pasa a ser una causal entre otras;
lo que el sistema evalúa es si la prestación tiene extensión autorizada.

---

## 1. Lo que la extensión libera, y lo que no

| Regla | ¿La libera la extensión? | Por qué |
| :--- | :---: | :--- |
| Cupo de 2 cuotas por año y centro de costo | **Sí** | es el objeto de la extensión |
| Techo de cuotas: 2 → 12 | **Sí** | acotado a los meses de ejecución |
| Tope mensual del 50 % | **Sí** | Q-D03: *"si es ANID elimina el tope"* |
| Cupo compartido entre prestaciones | **Sí** | la extendida no consume cupo ajeno |
| **Habilitación del cargo 3110 (decano)** | **No** | ver abajo |

### Por qué el 3110 queda fuera

Q-D10 lo condiciona explícitamente a ANID:

> *"Sí habilita a decanos de facultad, pero ninguno más — **esto si es anid** va a permitir
> asociar para que pueda realizar una prestación de servicios."*

Si la extensión generaliza más allá de ANID, usarla para habilitar cargos significa que **una
extensión no-ANID habilitaría al decano sin fundamento normativo**. Y quien marca el check es el
solicitante, no DGDP: sería un usuario levantando una inhabilidad.

**Decisión propuesta: los PA 14 y 15 dejan de recibir la marca.** El cargo 3110 vuelve a la regla
general hasta que exista una señal propia para ANID.

> Esto cambia el diff que ya hicimos en esos dos PA: en vez de renombrar `@ind_anid` →
> `@ext_cuotas`, hay que **eliminar el parámetro** y la rama del 3110.

---

## 2. Por rol

| Rol | Qué hace con la extensión |
| :--- | :--- |
| **Jefe de proyecto** | **Marca el check** al elegir el centro de costo. Puede cambiarlo mientras la solicitud esté en borrador o devuelta a corrección |
| **Revisores del flujo** (visaciones) | La **ven** en el resumen; no la editan |
| **DGDP** | La ve en el comparador de prestaciones previas. Q-D06: *"en caso de extender debería aprobar DGDP dicha extensión"* → debería poder observarla o devolver la solicitud si no corresponde |
| **Finanzas** | La ve en la bandeja de pagos como badge; no la edita |

### Lo que falta definir

Q-D06 pide que **DGDP apruebe** la extensión. Hoy solo la vería. Dos caminos:

- **Implícito**: aprobar la solicitud aprueba la extensión. No requiere pantalla nueva
- **Explícito**: DGDP puede desmarcarla al revisar. Requiere permiso de edición sobre el campo

El implícito alcanza para esta fase y no bloquea nada.

---

## 3. Por pantalla

### 3.1 Formulario de solicitud — `PdsDu288RequestForm.vue`

| Bloque | Cambio |
| :--- | :--- |
| **Centro de costo** | **Check nuevo**: "Extensión de cuotas autorizada". Se pre-marca si el CC lo sugiere, pero el valor es del usuario |
| **Selector de cuotas** | Su máximo pasa de `min(2, meses)` a `min(12, meses)` con el check |
| **Campo de tope** | Con el check: no bloquea por `TOPE_FALTANTE` ni compara contra el tope |
| **Resumen del funcionario** | Muestra que la prestación está extendida |

### 3.2 Modal comparador — `Du288StaffPreviousProvisionsModal.vue`

Ya muestra el indicador. Cambia de dónde sale: de la marca persistida, no del catálogo del CC.

Y las prestaciones previas **extendidas no consumen cupo** del funcionario — eso ya está en
`getCommittedInstallmentMonthsForYear:467`.

### 3.3 Bandeja de pagos — `pages/services-provision/payments/index.vue`

Sin cambios. Ya lee el indicador del PA 18.

---

## 4. Por validación

| Validación | Dónde | Con extensión |
| :--- | :--- | :--- |
| Máximo de cuotas declarables | `getMaxDeclarableInstallments` | 12 en vez de 2, acotado a meses |
| Cupo anual por centro de costo | `monthDistributionCheck` | la prestación no consume cupo |
| Tope mensual | `getTopValidation` 🔴 | **se omite** — hoy no lo respeta |
| Factibilidad del plan de pago | `paymentPlanFeasibility` | ya la respeta |
| Monto total vs tope × cuotas | `capNoteForRelated` | ya la respeta |
| Cantidad de cuotas en el PA | `sg_fupsi/u` | ≤ 12 con marca, ≤ 2 sin ella |
| Inhabilidad por cargo | PA 14/15 | **sin cambio** — ver §1 |

---

## 5. Orden de implementación

### Bloque A — desbloquear el flujo

| # | Cambio | Archivo |
| :-- | :--- | :--- |
| 1 | `getTopValidation` respeta la exención | `PdsDu288RequestForm.vue:3368,3395` |
| 2 | `extCuotas` viaja en el payload de `provision` | `PdsDu288RequestForm.vue` |
| 3 | Al cargar, leer `ext_cuotas` y no derivar | `PdsDu288RequestForm.vue:5117` |

Sin el **1** el check no deja guardar. Sin el **3** la marca se pierde en cada recarga.

### Bloque B — el check

| # | Cambio | Archivo |
| :-- | :--- | :--- |
| 4 | Check en el bloque de centro de costo | `Du288RequestHeaderSection.vue` |
| 5 | `isSelectedCostCenterAnid()` pasa a leer el check | `:4398` + 13 consumidores |
| 6 | Quitar el 44 de `isAnidCostCenter` | `textSimilarityUtil.js:20` |

### Bloque C — coherencia

| # | Cambio | Archivo |
| :-- | :--- | :--- |
| 7 | **Quitar el parámetro a los PA 14 y 15** | `cambios_pa/sg_fups/` |
| 8 | Quitar `indAnid` de los 2 servicios | `:4033`, `:5330` + store + backend |
| 9 | `MAX_ANID_INSTALLMENTS` → `MAX_EXTENDED_INSTALLMENTS` | `formatters.js:16` |
| 10 | Textos: `capExemptAnid` → extensión | `lang/es/pds.js` |

---

## 6. Riesgo de datos

Las prestaciones ya archivadas tienen `ext_cuotas` en `NULL`. Con el 44 fuera, **todas pasan a
tratarse como sin extensión**.

Si alguna era ANID y superó las 2 cuotas, el comparador la mostrará consumiendo cupo que antes no
consumía. No corrompe nada, pero puede bloquear solicitudes nuevas del mismo funcionario.

Conviene una regularización: identificar las prestaciones archivadas que realmente eran ANID y
marcarlas. Es un `UPDATE` acotado, pero necesita que alguien diga cuáles son — que es
exactamente lo que el acta del 26/05 dejó pendiente en Finanzas.

---

## 7. Resumen

**Una marca, cuatro efectos**: cupo, techo de cuotas, tope mensual y cupo compartido.
**El cargo 3110 queda fuera**, porque Q-D10 lo condiciona a ANID y la extensión ya no es ANID.

**Lo que bloquea hoy**: `getTopValidation`. Es el único cambio sin el cual el check no funciona.
