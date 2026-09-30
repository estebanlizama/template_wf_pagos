# Plan de implementación del frontend — extensión de cuotas

Criterio: **cada etapa deja el sistema funcionando**. Ninguna rompe lo ya desarrollado, y el
comportamiento actual se conserva mientras la marca no esté activa.

## Estado actualizado — 29/09/2026

Las etapas funcionales 1 a 6 están implementadas. Además se incorporó el
endurecimiento de coordinación asincrónica del frontend:

- PA14/PA15 usan control de última solicitud vigente; una respuesta antigua no
  puede sobrescribir el último valor de `extCuotas`.
- Mientras se revalida, cargos y asignaciones quedan explícitamente pendientes
  y las acciones se bloquean.
- Un error de PA15 no reutiliza resultados anteriores: permite guardar el
  borrador, bloquea el envío y ofrece reintento.
- El switch permanece deshabilitado hasta seleccionar centro de costo.
- La sugerencia del centro se aplica antes de disparar su revalidación y no
  reemplaza la marca persistida durante la recarga.
- Existen pruebas para normalización persistida, bloqueo, error, invalidación y
  respuestas fuera de orden.

Verificación: `npm test`, `npm run lint:du288-ui`, ESLint dirigido y `npm run build`.

---

## 0. Estado del que partimos

| Capa | Listo |
| :--- | :---: |
| PA | ✅ 12 archivos |
| Backend | ✅ compila, 182 tests |
| **Frontend** | ❌ nada |

El backend espera `request.provision.extCuotas`. Hoy nunca llega: `getCapExemptionIndicator`
devuelve `undefined` y se persiste `NULL`. **La extensión no opera.**

Y el frontend sigue derivando con el 44 en `isAnidCostCenter` (`textSimilarityUtil.js:20`), que es
la última derivación viva del sistema.

---

## Etapa 1 — Desbloquear el tope 🔴

**Sin esto nada más sirve:** con la marca activa el formulario igual bloquea.

`PdsDu288RequestForm.vue:3368` y `:3395` no consultan la exención:

```js
if (capAmount <= 0) {
  return { valid: false, code: 'TOPE_FALTANTE', ... }   // bloquea
}
const isExceededByAppliedCap = monthlyAmount > capAmount  // compara igual
```

**Cambio:** que `getTopValidation` reciba la exención y, cuando esté activa, devuelva
`valid: true` con severidad informativa en vez de bloquear. El tope se sigue **calculando y
mostrando** —es trazabilidad— pero deja de ser comparación bloqueante.

| Riesgo | Sin la marca el comportamiento es idéntico. La rama nueva solo se alcanza con extensión |
| :--- | :--- |
| Verificación | los 9 archivos de prueba siguen pasando |

---

## Etapa 2 — Que la marca viaje

**2.1 Estado del formulario**

Agregar `extCuotas: 'N'` a `form` (`:727`). Un campo más en un objeto que ya existe.

**2.2 Payload**

`buildProvisionPayload()` (`:7567`) agrega una línea:

```js
extCuotas: this.form.extCuotas || 'N',
```

Viaja en los dos puntos que lo usan (`:6943` guardar, `:7419` enviar), así que **queda cubierto
borrador y envío** sin tocar nada más.

**2.3 Carga**

`restoreCostCenterFromProvision()` (`:5117`) debe tomar `prov.extCuotas` y escribirlo en
`form.extCuotas`. **Sin esto la marca se pierde en cada recarga**, porque el centro se reconstruye
desde el catálogo vigente.

| Riesgo | Mientras nada escriba `form.extCuotas`, siempre viaja `'N'` — el comportamiento actual no cambia |
| :--- | :--- |

---

## Etapa 3 — El check

**3.1 Componente**

Check en el bloque de centro de costo de `Du288RequestHeaderSection.vue`, con `v-model` contra
`form.extCuotas`. Habilitado solo con centro de costo seleccionado y solicitud editable
(borrador o devuelta a corrección).

**3.2 Valor propuesto**

Al elegir el centro de costo, pre-marcar si `isAnidCostCenter(raw)` lo sugiere — pero **solo como
sugerencia inicial**, nunca sobrescribiendo un valor ya cargado desde la BDD.

Es lo que permite sacar el 44 después sin perder la comodidad: cuando Finanzas entregue el campo
real, solo cambia de dónde sale la sugerencia.

| Riesgo | El check arranca desmarcado y el usuario decide. Nada cambia si no lo marca |
| :--- | :--- |

---

## Etapa 4 — Conectar los consumidores

`isSelectedCostCenterAnid()` (`:4398`) pasa a leer el check en vez de derivar:

```js
isSelectedCostCenterAnid() {
  return String(this.form.extCuotas || 'N').trim().toUpperCase() === 'S'
}
```

**Un solo cambio y los 13 consumidores quedan conectados**, porque todos pasan por esa función:

| Línea | Efecto que se activa |
| :--- | :--- |
| 1194 | cupo de cuotas 2 → 12 |
| 3013 | etiqueta del tope |
| 3100, 4352 | exención de tope |
| 3140 | se omite la nota de cupo reducido |
| 4033, 5330 | `indAnid` a los PA 14/15 |
| 339, 1420, 1452, 2342, 2838 | contexto, snapshot y caché |

Conviene renombrarla a `hasInstallmentExtension()` en la misma pasada.

| Riesgo | **El más alto del plan.** Cambia el origen de 13 decisiones a la vez |
| :--- | :--- |
| Mitigación | hacerla después de la 3, cuando el check ya alimenta el campo |

---

## Etapa 5 — Retirar la derivación

**5.1** Quitar el bloque del 44 de `isAnidCostCenter` (`textSimilarityUtil.js:20`). Queda leyendo
solo `ind_anid` / `indAnid` / `isAnid`, que es lo que servirá cuando exista el campo.

**5.2** Renombrar los 2 servicios: `indAnid` → `extCuotas` en `:4033` y `:5330`, en el store y en
el backend que arma esas queries.

| Riesgo | Después de la etapa 4 nadie depende del 44 para decidir. Solo queda como sugerencia |
| :--- | :--- |

---

## Etapa 6 — Nombres y textos

| Cambio | Archivo |
| :--- | :--- |
| `MAX_ANID_INSTALLMENTS` → `MAX_EXTENDED_INSTALLMENTS` | `formatters.js:16` |
| `isCapExempt` → `hasInstallmentExtension` | `formatters.js`, `textSimilarityUtil.js` |
| `capExemptAnid` → etiqueta de extensión | `lang/es/pds.js` |
| Mensajes que digan "ANID" | `normative/messages.js` |

Cosmético, sin efecto funcional. Se puede diferir.

---

## Resumen de etapas

| # | Qué | Riesgo | Deja funcionando |
| :-: | :--- | :---: | :---: |
| 1 | `getTopValidation` respeta la exención | bajo | ✅ |
| 2 | La marca viaja y se recupera | bajo | ✅ |
| 3 | El check en el formulario | bajo | ✅ |
| 4 | Conectar los 13 consumidores | **alto** | ✅ |
| 5 | Retirar el 44 | medio | ✅ |
| 6 | Nombres y textos | nulo | ✅ |

**Las etapas 1 a 3 no cambian ningún comportamiento**: agregan capacidad sin activarla. El
sistema se comporta igual que hoy hasta que alguien marque el check, y eso recién importa en la
etapa 4.

---

## Verificación por etapa

```
npm test            9 archivos de prueba
npm run lint:du88-ui   estándar visual
```

Y una prueba funcional al terminar la 4:

1. Crear solicitud sin marcar → selector de cuotas tope 2, tope mensual bloquea sobre el límite
2. Marcar el check → selector hasta 12, el tope deja de bloquear
3. Guardar borrador, recargar → **el check sigue marcado**
4. Enviar → la marca queda persistida
5. Abrir el comparador desde otra solicitud → la prestación extendida no consume cupo

El punto 3 es el que valida la etapa 2; el 5, que el backend la esté leyendo.

---

## Lo que queda fuera

| | Por qué |
| :--- | :--- |
| Aprobación explícita de DGDP | Q-D06 la pide; con aprobar la solicitud alcanza en esta fase |
| Regularización de prestaciones archivadas | necesita que Finanzas identifique cuáles eran ANID |
| Campo real del centro de costo | pendiente en Finanzas desde el acta del 26/05 |
