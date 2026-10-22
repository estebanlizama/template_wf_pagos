# Simulación de armado de cuotas: cómo reacciona el sistema

17 escenarios ejecutados contra las funciones reales del repositorio
(`getFixedMonthAmounts`, `resolvePaymentPeriodCap`, `resolvePaymentDroppedAmount`,
`isPaymentLossAvoidable`, `monthlyCapApplies`), cubriendo fijo y variable, con y
sin extensión, meses partidos, descuentos, recortes, última cuota y aritmética
incómoda.

Simulador: `scratchpad/simula_cuotas.js` de la sesión. No es código del proyecto;
se ejecuta con `node` sobre los módulos reales.

Fecha: 22-10-2026. Reejecutado el mismo día tras aplicar los arreglos.

---

## 1. Lo que funciona bien

| Escenario | Resultado |
| :--- | :--- |
| Reparto en fijo | exacto: 7 meses de $700.007 dan $100.001 cada uno, sin descuadre |
| Tope del período en fijo | respeta la fórmula por meses-por-cuota: 12 meses en 5 cuotas da `tope × 4`, no `× 5` |
| Extensión | exime del tope en las cuatro combinaciones |
| Meses partidos (1-3-5) | agrupa no contiguos sin problema, en fijo y en variable |
| Cuota con todos los meses | no deja nada fuera y no bloquea |
| Tope excedido | se detecta cuando el tope aplica (1 sola cuota autorizada) |
| Remedio ofrecido | el texto cambia solo: "cuota nueva" mientras queden cuotas, "repartir" en la última |

---

## 2. Hallazgo abierto: los descuentos desaparecen del cálculo de pérdida

`selectedRequested` suma el monto **bruto** de cada mes; `deduction` se resta
solo para mostrar "A pagar". Pero `resolvePaymentDroppedAmount` recibe el bruto.

Simulación *"fijo ext, con descuento"*:

| | |
| :--- | ---: |
| Cuota (bruto) | $1.002.021 |
| Descuentos | $200.000 |
| **A pagar** | **$802.021** |
| Pospuesto | $11.022.231 |
| **Queda fuera del pago** | **$0** |

La prestación va a pagar $802.021 + $11.022.231 = **$11.824.252** de
$12.024.252 decretados. **$200.000 se pierden y la pantalla informa $0.**

Con varios meses descontados en varias cuotas, el desvío se acumula sin que nada
avise.

**Mitigación aplicada:** la vista ahora declara el descuento donde antes no
aparecía — en los límites de la cuota se agrega la línea "Descontado de lo
decretado" cuando hay descuentos seleccionados, con el aviso de que esa plata no
vuelve a quedar disponible. El cálculo sigue recibiendo el bruto.

**A definir antes de tocar el cálculo:** ¿el descuento es pérdida o es un ajuste
legítimo que no cuenta contra lo decretado? Si es lo segundo, el cálculo está
bien y bastaba con decirlo en pantalla, que es lo que se hizo. Si es lo primero,
`droppedAmount` debe recibir el neto.

---

## 3. Corregido: la severidad estaba invertida — $1 bloqueaba, $1.002.020 no

Dos escenarios consecutivos, el mismo recorte de un mes, antes del arreglo:

| Escenario | Recorte | ¿Bloqueaba? |
| :--- | ---: | :---: |
| fijo **con** extensión, recorte de $1 | $1 | **sí** |
| fijo **sin** extensión, recorte a $1 | $1.002.020 | **no** |

La causa estaba en `isPaymentLossAvoidable`: con extensión devolvía `true`
siempre (sin tope, siempre se puede repartir distinto), y sin extensión comparaba
`decreedTotal <= cap × cuotas` — con $12.024.252 contra $500.000 × 12 =
$6.000.000 daba `false`, o sea *"la pérdida es estructural, no hay remedio"*, y
se dejaba pasar.

El razonamiento era correcto para la pregunta que la función responde —si la
prestación **en conjunto** puede pagarse de otra forma—, pero se usaba para
decidir si **este recorte puntual** se admite. Son preguntas distintas: que la
prestación no pueda pagar todo no vuelve legítimo recortar un mes a $1. En las
prestaciones donde lo decretado excede la capacidad —justo las que más cuidado
necesitan— el control se apagaba por completo.

**Arreglo:** `isPaymentLossAvoidable` recibe `cutOnIncludedMonths`, el monto que
los meses **incluidos** en la cuota dejan de pagar respecto de lo decretado, y
lo resuelve antes de la prueba estructural: un mes incluido que paga menos de lo
suyo se arregla devolviéndolo a su monto, sin depender de si la prestación
alcanza a pagarse entera. El componente lo calcula sobre las filas marcadas.

En variable el valor es siempre 0: el mes no trae monto decretado, así que no hay
recorte que declarar y la decisión sigue saliendo de la exención de tope.

Reejecución: *"fijo sin ext, recorte grande"* pasa de `bloquea: false` a
`bloquea: true`, y el caso de $1 se mantiene bloqueando.

---

## 4. Descartado: el remedio de la última cuota sí existía

Escenario *"ULTIMA cuota con meses libres"* (11 cuotas ya creadas, 12
autorizadas, meses sin incluir):

- pospuesto: **$0** — correcto, no quedan cuotas
- queda fuera: **$11.022.231** — correcto, esa plata se pierde
- bloquea: **sí** — correcto

Se había anotado que el mensaje ofrecía "deje el que no entra para una cuota
nueva" cuando ya no hay cuota nueva que crear. **Es falso.** `lossAvoidableHint`
elige el texto según `quotaSummary.remaining`: con cuotas por crear usa
`lossAvoidableNewInstallment`, y sin cuotas usa `lossAvoidableRebalance`, que
dice que ya están creadas todas las cuotas autorizadas y que hay que repartir los
meses entre ellas. El error estuvo en simular la función de cálculo y suponer el
texto en vez de leer cómo lo elige el componente.

La reejecución lo confirma: las dos filas de última cuota resuelven el remedio
"repartir" y el resto "cuota nueva".

---

## 5. Hallazgo abierto: los descuentos pueden superar el monto del mes

Escenario *"variable ext, descuento > monto"*: cuota de $100.000 con $300.000 de
descuento → **a pagar $0**, y nada lo impide.

`isValid` exige `requested > 0`, que mira el **bruto**, así que una cuota cuyo
neto es cero pasa la validación. No se evaluó si corresponde permitirlo —puede
ser un caso legítimo de mes íntegramente descontado— pero hoy no hay regla ni
aviso.

---

## 6. Resumen de acciones

| # | Hallazgo | Estado |
| :-- | :--- | :--- |
| 2 | Los descuentos no entran en la pérdida | declarado en pantalla; el cálculo espera la definición de si el descuento es pérdida |
| 3 | $1 bloqueaba y $1M no | **corregido** con `cutOnIncludedMonths`, con prueba unitaria |
| 4 | Remedio imposible en la última cuota | **descartado**: el texto ya se elegía bien |
| 5 | Descuento mayor al monto del mes | abierto: falta definir si se admite |

Lo que queda pendiente son las dos definiciones funcionales (2 y 5), no código.

---

## 7. Lo que esta simulación no cubre

- **Las validaciones normativas** (compensación, respaldo, deudas, parentesco):
  viven en el store y dependen de consultas, no de estas funciones.
- **El PA**, que revalida al guardar y al enviar: si su criterio difiere del
  front, el usuario lo descubre recién al guardar.
- **La interacción real**: marcar, desmarcar y reordenar meses, donde el estado
  intermedio puede habilitar o bloquear de forma distinta a estos cálculos
  aislados.
