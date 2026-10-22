# Reglas por tipo de monto y extensión: qué cuidar al crear cuotas

Las cuatro combinaciones —fijo o variable, con extensión o sin ella— no son
cuatro variantes de lo mismo: cambian **quién decide el monto de cada mes** y
**qué limita el total**. Esta nota ordena las reglas implementadas, los riesgos
de tocarlas y los flujos que hay que cubrir.

Fecha: 21-10-2026.

---

## 1. Las cuatro combinaciones

`cod_tpps` / `amountType`: **1 = fijo**, **2 = variable**.
Extensión: `sg_fups.ext_cuotas`.

| | Tope mensual | Monto de cada mes | Techo por mes |
| :--- | :--- | :--- | :--- |
| **Fijo, sin extensión** | aplica, con una vuelta de tuerca (§2) | repartido parejo por `getFixedMonthAmounts` | lo decretado de ese mes |
| **Fijo, con extensión** | **no aplica**: se libera el total autorizado | repartido parejo | lo decretado de ese mes |
| **Variable, sin extensión** | aplica: `tope × cuotas` | lo define quien arma la cuota | sin techo por mes |
| **Variable, con extensión** | **no aplica** | lo define quien arma la cuota | sin techo por mes |

Las dos reglas de monto viven en código y conviene no reimplementarlas:

- `getFixedMonthAmounts` (`utils/services-provision/normative/formatters.js:62`)
  divide el total entre los meses y reparte el resto de a **$1** entre los
  primeros, de modo que la suma cuadre exacto. Devuelve `null` si el tipo es
  variable: ese `null` es la señal de "acá el monto lo pone el usuario", no un
  error.
- `resolveAuthorizedAmount` (`paymentValidations.js:183`) decide el total
  disponible: `if (hasExtension || cap <= 0 || installments <= 0) return authorizedTotal`.
  O sea, **con extensión o sin tope configurado, el límite es el total
  decretado y nada más**.

En fijo hay además un techo por mes: `maxAmount` se fija en lo decretado del mes
y `overProposed` marca cuando lo pedido lo supera
(`Du288InstallmentFormSection.vue:352-353`). En variable ese techo es `0`, que
significa "sin límite", **no** "límite cero".

---

## 2. El cálculo del tope en fijo no es `tope × cuotas`

```js
const grossCap = Number(amountType) === 1 && months > 0
  ? Math.floor((cap * months) / Math.ceil(months / installments))
  : cap * installments
```

En variable es `tope × cuotas`. En **fijo** es `tope × meses / meses-por-cuota`,
porque el monto mensual ya está decretado y lo que se agrupa son meses: una cuota
de 3 meses lleva 3 montos mensuales, no 1.

**Cuidado al tocarlo:** cambiar esta fórmula cambia cuánto se puede pagar en
fijo, y la diferencia solo se nota cuando `meses` no es múltiplo de `cuotas` —
justo el caso que nadie prueba. 12 meses en 5 cuotas da `ceil(12/5) = 3`, así que
el techo es `tope × 4`, no `tope × 5`.

---

## 3. El error que esto destapó, y por qué importa más allá de este caso

`store/service-provision-payment-detail.js` evaluaba el tope en cadena y ponía
*"Tope no configurado"* **antes** de la exención por extensión. Una prestación
extendida con tope sin configurar quedaba bloqueada por una regla que no le
aplica.

Lo grave no es el orden: es que **dos capas decían cosas opuestas sobre el mismo
caso**. `resolveAuthorizedAmount` ya trataba `hasExtension || cap <= 0` como "sin
tope efectivo", mientras la etiqueta lo declaraba bloqueante. Mientras las dos
convivan, cualquier arreglo en una deja a la otra mintiendo.

**La acción que queda:** que la etiqueta no reimplemente la regla, sino que
consuma la misma función. Hoy el orden está corregido, pero siguen siendo dos
implementaciones del mismo criterio.

---

## 4. Riesgos al tocar esto

| Riesgo | Por qué | Cómo evitarlo |
| :--- | :--- | :--- |
| **Confundir `0` con "sin límite"** | `tope = 0`, `maxAmount = 0` y `grossCap` tratan el cero como *no aplica*; una comparación `> 0` mal puesta bloquea todo | Nunca comparar contra el tope sin preguntar antes si aplica |
| **Reimplementar el reparto de fijo** | `getFixedMonthAmounts` ajusta el resto de a $1; una división simple deja descuadre de hasta `meses - 1` pesos | Llamar al helper, no dividir a mano |
| **Tomar `null` como error** | En variable el helper devuelve `null` a propósito | Tratar `null` como "monto libre" |
| **Validar el tope en variable como en fijo** | Las fórmulas difieren (§2) | Ramificar por `amountType`, nunca asumir |
| **Mover una rama de la cadena de etiquetas** | El orden **es** la regla: la primera que calza gana | Al agregar una rama, decidir explícitamente si va antes o después de la exención |
| **Que front y PA diverjan** | El PA valida por su cuenta; si el front es más permisivo, el usuario descubre el límite al guardar | Toda regla nueva de monto va en los dos lados |

---

## 5. Flujos que hay que cubrir antes de dar esto por cerrado

Ninguno está verificado hoy en pantalla.

**Por combinación**, creando una cuota y enviándola:

1. fijo sin extensión, tope configurado — el techo por mes debe respetarse
2. fijo sin extensión, **tope en 0** — debe bloquear con *"Tope no configurado"*
3. **fijo con extensión, tope en 0** — debe **permitir** (el caso de este arreglo)
4. variable sin extensión, tope configurado — techo `tope × cuotas`
5. variable con extensión — sin techo

**Casos de borde que la aritmética hace sospechosos:**

- meses **no múltiplos** de cuotas en fijo (12 meses / 5 cuotas), por §2
- total que no divide exacto entre los meses, para ver el reparto del resto
- **un mes en $0** dentro de una cuota: debe poder seleccionarse igual
- la **última** cuota, donde el saldo restante puede no alcanzar el monto mensual
- cuota de **un solo mes** en fijo, donde `meses-por-cuota = 1`

**Transiciones que cambian el resultado a mitad de camino:**

- la **extensión decretada difiere de la vigente** — ya hay aviso, pero el total
  disponible depende de con cuál se opere
- el **tope vigente cambia** después de decretada la resolución: hay etiqueta
  (`Tope vigente modificado`), pero es advertencia, no bloqueo
- el centro de costo **se queda sin saldo** entre que se arma la cuota y se envía

---

## 6. Lo que no hay que modificar

- `getFixedMonthAmounts` y `resolveAuthorizedAmount`: son el contrato de monto y
  están cubiertos por `paymentValidations.test.cjs`.
- El orden de la cadena de etiquetas, salvo con una razón escrita: cada `else if`
  depende de que ninguno anterior haya calzado.
- Las reglas de selección de meses (un mes sin marcar no persiste monto; el monto
  de un mes solo baja hasta lo decretado): son de una iteración anterior y
  cambiarlas reabre la discusión de la pérdida evitable.

---

## 7. Pendiente de definición

1. **¿El tope aplica en monto variable?** Hoy sí (`tope × cuotas`), pero si en
   variable el monto mensual no se conoce de antemano, el tope mensual puede no
   tener sentido como límite agregado.
2. **Cuando la extensión decretada y la vigente difieren, ¿con cuál se calcula el
   total disponible?** La recomendación sigue siendo la decretada.
3. **¿`Tope vigente modificado` debería bloquear** en vez de advertir, cuando el
   tope bajó y la cuota ya lo supera?

---

## 8. El backend aplicaba el tope con otro criterio al enviar (corregido 22-10-2026)

Síntoma: `POST .../provisions/4/installments/1/submit` devolvía **422** con
*"No es posible enviar la cuota a visación: el cargo no tiene tope mensual
configurado."* La prestación era **variable con extensión**, y el front la dejaba
llegar hasta la pantalla de confirmación con todas las validaciones en verde.

No era un desacuerdo de datos sino de criterio. `assertInstallmentNormativeCompliance`
exigía que el tope existiera **siempre**, con el argumento de que "la extensión
exime del monto, no de que el tope exista":

```ts
const currentCap = positionCap.mtoTope > 0 ? positionCap.mtoTope : provision.monthlyCap
if (currentCap <= 0) throw 422 'el cargo no tiene tope mensual configurado'
if (extension !== 'S' && requestedAmount > currentCap) throw 422 '...supera el tope'
```

El argumento no se sostiene: con `extension === 'S'` el valor no se vuelve a
usar en todo el método. La guarda bloqueaba por un dato que para esa prestación
no sirve para nada, y contradecía las dos reglas ya establecidas del §1 —la
extensión exime del tope, y un tope en cero es *"sin tope configurado"*, no un
tope de cero pesos— que el front aplica con `monthlyCapApplies`.

**Corrección:** la consulta del tope y sus dos guardas quedaron dentro de
`if (extension !== 'S')`. Una prestación extendida no consulta el tope (una
llamada menos al PA) y no puede ser rechazada por no tenerlo. Sin extensión, el
comportamiento no cambia: falta de tope y exceso de tope siguen devolviendo 422.

El caso sin extensión y sin tope ya estaba cubierto en el front por la etiqueta
`Tope faltante` (`status: 'error'`, bloqueante), así que ahí las dos capas
coincidían; el hueco era solo el extendido.

Cubierto por `src/__tests__/unit/service-provision-payment-submission-cap.unit.ts`
(5 casos: extendida sin tope pasa y no consulta, sin extensión y sin tope
rechaza, cuota sobre el tope rechaza, el tope vigente manda sobre el congelado,
y cuota dentro del tope pasa).
