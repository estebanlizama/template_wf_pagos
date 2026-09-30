# Auditoría de la implementación actual de ANID en el frontend

Revisión detallada de los 13 consumidores antes de migrarlos al check.

---

## 1. Lo que está bien resuelto

Tres decisiones del diseño actual conviene **conservarlas**, no solo migrarlas:

### 1.1 Un único punto de derivación

Los 13 consumidores pasan por `isSelectedCostCenterAnid()` (`:4398`), que envuelve a
`isAnidCostCenter()`. **Cambiar el origen es cambiar una función.** Sin eso, migrar al check
habría sido tocar 13 lugares.

### 1.2 El cupo se acota por cuotas declaradas, no por el cupo entero

`:1194`:

```js
// El techo lo fijan las cuotas DECLARADAS, no el cupo entero: si el
// solicitante declara 1 cuota pero pide mas de 1 tope, la solicitud
// no cuadra aunque le quedara cupo para una segunda (S0-013 Q-C01).
maxPaymentMonths: this.getDeclaredInstallments(),
isCapExempt: this.isSelectedCostCenterAnid(),
```

La exención y las cuotas declaradas son señales separadas. Correcto: la extensión sube el techo
disponible, pero el solicitante puede declarar menos.

### 1.3 La exención entra en la clave de caché

`:2838`:

```js
getSelectedCostCenterNormativeKey() {
  return [ ..., this.normalizeCachePart(this.isSelectedCostCenterAnid() ? 'S' : 'N') ].join('|')
}
```

Si el usuario cambia el check, la caché del tope por cargo se invalida sola. **Esto sigue siendo
necesario con el check** — de hecho más, porque el usuario podrá alternarlo varias veces en la
misma sesión.

---

## 2. Lo que está mal implementado

### 2.1 🔴 La exención no llega a `getTopValidation`

Es el hueco central. La exención se pasa a **cuatro** funciones:

| Función | Recibe la exención |
| :--- | :---: |
| `monthlyCapAggregateCheck` (`:1194`) | ✅ |
| `getMaxDeclarableInstallments` (`:3100`) | ✅ |
| `paymentPlanFeasibility` (`:4352`) | ✅ |
| **`getTopValidation` (`:3344`)** | ❌ |

`getTopValidation` calcula `capAmount` y compara sin consultarla. Resultado: el agregado y la
factibilidad reconocen la exención, pero la validación del campo la ignora y bloquea.

**Es inconsistente hoy, no solo con el check.** Un centro con `cod_tfinan = 44` ya sufre esto.

### 2.2 🟡 `getAvailableMonthSlots` no conoce la exención

`:3131`:

```js
getAvailableMonthSlots() {
  return Math.max(0, MAX_PAYMENT_MONTHS - this.editingWorkerCommittedInstallmentMonths.length)
}
```

Siempre resta sobre `MAX_PAYMENT_MONTHS = 2`, aunque la prestación esté exenta. No causa error
porque `getMaxDeclarableInstallments` lo ignora cuando `isCapExempt`:

```js
const cap = isCapExempt ? MAX_ANID_INSTALLMENTS : Math.max(0, Number(availableSlots ?? 0))
```

Pero es frágil: cualquier consumidor nuevo que llame a `getAvailableMonthSlots()` directo va a
obtener un número equivocado para una prestación extendida.

### 2.3 🟡 El snapshot viaja como `isAnid`, no como extensión

`:1420` y `:1452`:

```js
const currentCostCenter = { ...costCenter, isAnid: this.isSelectedCostCenterAnid() }
```

El motor de conflictos y el agregado de tope reciben la señal bajo el nombre `isAnid`. Con el
concepto generalizado, el nombre miente — y peor: `evaluatePdsConflictSeverity` puede volver a
derivarla con `isAnidCostCenter(costCenter)`, que reintroduce el 44 por dentro.

Hay que pasar un campo explícito y que el motor **no vuelva a derivar**.

### 2.4 🟡 `getTopBrutoReductionNote` acopla dos conceptos

`:3140`:

```js
getTopBrutoReductionNote() {
  if (this.isSelectedCostCenterAnid()) return null
  ...
}
```

Usa la exención para decidir si **mostrar un texto**. Funciona, pero mezcla "está exenta" con "no
mostrar la nota de cupo reducido". Con el check, un usuario que lo marque y desmarque verá la
nota aparecer y desaparecer — correcto, pero conviene que el motivo quede explícito en el código.

### 2.5 🔴 Los dos servicios mandan el nombre viejo

`:4033` y `:5330`:

```js
indAnid: this.isSelectedCostCenterAnid() ? 'S' : 'N',
```

Los PA 14 y 15 ya reciben `@ext_cuotas`. **El nombre del parámetro no calza**: hay que renombrar
en el front, en el store y en el backend que arma esas queries. Si no, esas dos validaciones
quedan sin señal y el cargo 3110 nunca se habilita.

---

## 3. Lo que hay que ajustar además del cambio de origen

| # | Ajuste | Por qué |
| :-- | :--- | :--- |
| 1 | `getTopValidation` recibe y respeta la exención | inconsistencia actual, bloquea el check |
| 2 | `getAvailableMonthSlots` devuelve el techo correcto si hay extensión | evita que un consumidor futuro lea mal |
| 3 | El snapshot pasa `hasInstallmentExtension` explícito | el motor deja de derivar por dentro |
| 4 | `evaluatePdsConflictSeverity` y `monthlyCapAggregateCheck` leen ese campo | cierra la derivación |
| 5 | Renombrar `indAnid` → `extCuotas` en los 2 servicios | alinear con los PA |
| 6 | Mantener la exención en la clave de caché | ya está, no tocar |

---

## 4. Orden revisado

La auditoría cambia el plan anterior en un punto: **la etapa 4 no es solo cambiar el origen de
`isSelectedCostCenterAnid()`**, hay que cerrar antes las derivaciones internas del motor
(`textSimilarityUtil.js`). Si no, el check cambia el valor en el formulario pero el comparador
sigue derivando con el 44.

```
1. getTopValidation respeta la exención            (2.1)
2. getAvailableMonthSlots conoce la exención        (2.2)
3. La marca viaja en el payload y se recupera
4. El check en el formulario
5. isSelectedCostCenterAnid() lee el check
6. El snapshot pasa el campo explícito              (2.3)
7. El motor deja de derivar: quitar el 44           (2.4 del motor)
8. Renombrar los 2 servicios                        (2.5)
9. Nombres y textos
```

Los pasos **1 y 2 son correcciones de bugs existentes**: se pueden hacer y probar solos, sin
esperar al check.

---

## 5. Resumen

**Bien:** el punto único de derivación, la separación entre exención y cuotas declaradas, y la
invalidación de caché. Los tres se conservan.

**Mal:** `getTopValidation` no recibe la exención —inconsistencia que ya existe hoy—, el nombre
`indAnid` no calza con los PA, y el motor de conflictos puede volver a derivar el 44 por dentro
aunque el formulario ya no lo use.

---

## 6. Estado de cierre de la integración (29-09-2026)

Las brechas funcionales de esta auditoría quedaron integradas:

- los dos servicios frontend envían `extCuotas` y Vuex conserva ese nombre hasta los endpoints;
- los snapshots del formulario entregan `hasInstallmentExtension` al motor de conflictos;
- `monthDistributionCheck` y `monthlyCapAggregateCheck` leen esa señal explícita mediante
  `hasInstallmentExtension()` y no vuelven a derivar desde `cod_tfinan`;
- `cod_tfinan = 44` se conserva solo como sugerencia inicial del check mientras Finanzas no
  entregue el campo definitivo del centro de costo;
- al cambiar o limpiar el centro de costo se reinicia la sugerencia, evitando trasladar una
  extensión marcada a otra actividad;
- el backend eleva el `ext_cuotas` persistido en `sg_fups` a `provision.extCuotas` al recuperar
  una solicitud; el frontend mantiene además respaldo desde `staffList` para despliegues
  transitorios con una API anterior.

Evidencia automatizada al cierre:

- frontend: 9 archivos de pruebas correctos; motor DU288 con 70 casos, incluidos tres de
  regresión que prueban que el código de financiamiento no activa la extensión internamente;
- estándar visual DU288: 25 archivos validados;
- backend: compilación limpia y 183 pruebas unitarias correctas, incluida la recuperación de
  `ext_cuotas` desde el funcionario hacia `provision.extCuotas`.

Sigue pendiente solo la prueba funcional con Sybase real de guardar, recargar, enviar y abrir el
comparador. Esa prueba debe instalar primero el paquete coordinado de PA que expone y persiste
`ext_cuotas`.
