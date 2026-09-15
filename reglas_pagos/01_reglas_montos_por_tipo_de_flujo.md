# Reglas de montos, topes y cuotas — Workflow de Pagos DU288 / D09-2026

Fecha: 2026-09-07

## Fuentes y vigencia

| Fuente | Estado |
|---|---|
| **ClickUp S0-013 (`86e2zrkh4`)** — cuestionario maestro con respuestas funcionales | **Vigente. Fuente autoritativa.** |
| Análisis de diseño de esta sesión (2026-09-07) | Vigente |
| `requerimientos_wf/*.md` (docs 0 a 9, ADR-PP-001, matriz y catastro) | **Deprecado y desactualizado.** No usar como fuente de reglas. |

Este documento es el **primer filtro**: lo que aquí se autorice mal se
arrastra hasta el pago efectivo de un haber. Las reglas sin respuesta en
S0-013 se marcan como abiertas en vez de asumir criterio.

## 1. Vocabulario (no intercambiable)

| Concepto | Definición | Límite |
|---|---|---|
| **Mes de ejecución** | Mes en que se realiza la actividad | Hasta 12 por año calendario; **no puede cruzar el año** (Q-B09) |
| **Cuota** | Unidad de **pago**: un trabajo realizado en un periodo definido (Q-B04) | El máximo se cuenta **por cuota**, no por meses (Q-C01) |
| **Mes de pago** | Mes en que el dinero se paga | Puede ser de otro año calendario que el de ejecución (Q-C11) |

Una cuota **no** equivale a un mes: *"una cuota puede pagar más de un mes de
ejecución"* (Q-B05). Confundirlos es la fuente principal de error del módulo.

## 2. Regla del tope — CERRADA

> **El tope se valida por cuota, no por mes.**
> *"limita por cuota no por meses"* (Q-C01)
> *"ese máximo se determina por cuota y cada cuota es independiente en tope
> para la siguiente si corresponde"* (Q-C02)

Consecuencias:

| # | Regla | Fuente |
|---|---|---|
| T-01 | Cada cuota dispone del **tope completo**; el tope **se reinicia** para la siguiente cuota | Q-C02, confirmación 2026-09-07 |
| T-02 | Una cuota que cubre varios meses de ejecución consume **un solo tope** | Q-B05 + Q-C01 |
| T-03 | El tope **no es acumulativo**: lo no usado en la primera cuota **no se traspasa** a la segunda. *"si no ocupé el 50% de la anterior no aplica para la segunda cuota"* | Q-A07 |
| T-04 | El techo real de cada cuota sigue acotado por el **saldo del monto total autorizado** en la resolución: *"si se paga 100 en la primera no se puede pagar 100000"* | Q-A07 |
| T-05 | Cuando dos cuotas caen en el **mismo mes** (solo permitido por deudas/atrasos), sí se evalúa además la **suma mensual** del funcionario contra el tope de ese mes | Q-C05, Q-C08 |
| T-06 | Las cuotas **ya pagadas o en transacción** consumen cupo y saldo; no se recalculan ni se liberan | Confirmación 2026-09-07 |
| T-07 | En **monto fijo**, la factibilidad se mide sobre la **cuota más cargada**, no sobre la razón `total ÷ tope`: los meses son indivisibles y la cuota agrupa meses enteros | Deducida de §5 + C-03 + T-01/T-02; confirmación 2026-09-09 |
| T-08 | El reparto de un monto **fijo** entre los meses usa el **método de resto mayor**: cada mes recibe el piso de la división y los pesos sobrantes se entregan de a uno a los primeros meses. La suma de los meses es **siempre** exactamente `mto_total` | Estándar de asignación (Hamilton / largest remainder); corrección 2026-09-15 |

### T-07 — factibilidad del reparto en monto fijo

En **fijo** cada mes lleva exactamente `mto_total ÷ meses` y una cuota agrupa
**meses enteros** (C-03). Entonces la cuota más cargada tiene
`ceil(meses ÷ cuotas)` meses, y **es esa** la que debe caber bajo el tope:

```
ceil(meses ÷ cuotas) × (mto_total ÷ meses)  ≤  tope
```

La razón simple `ceil(total ÷ tope) ≤ cuotas` **no alcanza**, porque asume que
el monto se puede cortar en cualquier punto. Contraejemplo real:

> $300.000 en **3 meses**, tope $150.000, **2 cuotas**, fijo.
> `ceil(300.000 ÷ 150.000) = 2 ≤ 2` → la aprobaría.
> Pero cada mes lleva $100.000 y toda agrupación de 3 meses en 2 cuotas deja una
> cuota de 2 meses = **$200.000 > tope**. No existe partición válida: la
> solicitud se aprobaría y después no se podría pagar dentro del tope.

Se resuelve al revés, que además da el mínimo de cuotas necesario:

```
meses por cuota   = floor(tope ÷ (mto_total ÷ meses))
cuotas necesarias = ceil(meses ÷ meses por cuota)
```

Si `meses por cuota < 1`, un solo mes ya excede el tope y **ninguna cantidad de
cuotas lo arregla**: hay que bajar el monto o extender la ejecución.

De la misma desigualdad sale el **techo del bruto en fijo**, que tampoco es
`tope × cuotas`:

```
bruto máximo (fijo) = tope × meses ÷ ceil(meses ÷ cuotas)
```

Con 3 meses y 2 cuotas el techo real es `tope × 1,5`, no `tope × 2`.

En **variable** nada de esto aplica: el monto de cada mes se define al pagar, se
reparte libremente entre las cuotas, y sigue valiendo `ceil(total ÷ tope) ≤
cuotas` con techo `tope × cuotas`. Es la misma frontera que separa a ADR-010.

Monto máximo de una cuota:

```
monto de la cuota = MIN(
    tope aplicable completo para esta cuota,        (T-01, T-02)
    monto total autorizado − pagado − comprometido, (T-04, T-06)
    monto ajustado por licencia o permiso           (Q-B12)
)
```

### T-08 — reparto del monto fijo entre los meses

En **fijo** cada mes lleva `mto_total ÷ meses`, pero esa división casi nunca
da exacta y el peso no se puede partir. Repartir con `Math.round` rompe por
las dos puntas:

| Total | Meses | `Math.round` | Error |
|---|---|---|---|
| $600.000 | 7 | 85.714 × 7 = 599.998 | **−$2**, se pierde |
| $200.000 | 3 | 66.667 × 3 = 200.001 | **+$1, excede lo autorizado** |
| $850.000 | 11 | 77.273 × 11 = 850.003 | **+$3, excede lo autorizado** |

Los casos `+` son los graves: violan T-04 pagando más de lo que la resolución
autorizó. El redondeo bancario **no** resuelve esto — corrige el sesgo al
redondear valores independientes, pero no garantiza que las partes sumen el
total; medido sobre estos mismos casos da exactamente el mismo error.

El reparto correcto es en dos pasos:

```
base  = floor(mto_total ÷ meses)        // el piso, para todos
resto = mto_total − base × meses        // siempre 0 ≤ resto < meses
mes i = base + (i < resto ? 1 : 0)      // el sobrante, de a un peso
```

**Invariante:** `Σ meses = mto_total`, exacto, siempre. Y como `resto` es
menor que la cantidad de meses, ningún mes difiere de otro en más de 1 peso.

Que el peso extra vaya a los **primeros** meses es decisión nuestra, no del
estándar: con meses de igual peso todos los restos empatan, y el método deja
el desempate abierto. Se fija en los primeros por ser determinista, auditable
y la implementación convencional.

No aplica a **variable**: ahí el monto de cada mes lo define el solicitante al
pagar, no sale de una división.

Implementado en `getFixedMonthAmounts` (`normative/formatters.js`), con los
casos de regresión en `paymentMonthsValidation.test.cjs`. Los tests previos
usaban 111.111÷3 y 250.000÷1 — que sí dividen exacto — y por eso el defecto
pasó inadvertido.

## 3. Cuotas: cuántas, cuándo y quién

| # | Regla | Fuente |
|---|---|---|
| C-01 | Las define el **solicitante** (jefe de proyecto), no DGDP ni el sistema | Q-B01, Q-E03 |
| C-02 | Se crean **al enviar**, no al guardar borrador; son eliminables mientras el borrador nunca haya sido enviado | Q-B02, Q-F10 |
| C-03 | El solicitante **distribuye manualmente** los meses en cuotas; el sistema no lo propone | Q-B06, Q-B08 |
| C-04 | La ejecución **puede superar** los 2 meses; el pago se distribuye en cuotas | Q-C03 |
| C-05 | Los pagos deben caer en **meses distintos**. Dos cuotas en el mismo mes **solo cuando hay deudas/atrasos** | Q-C05 |
| C-06 | La **última cuota** se paga solo una vez terminada la ejecución completa | Q-C06, Q-E02 |
| C-07 | Se permite **pago parcial** de un periodo ya ejecutado, con monto ajustado | Q-E02, Q-B11 |
| C-08 | Se pueden mezclar **meses atrasados y el mes actual** en una misma solicitud | Q-C10 |
| C-09 | Un mes ya usado queda **bloqueado para la misma actividad** | Q-C06 |
| C-10 | El monto de una cuota puede **reducirse** por licencia o permiso; nunca subir | Q-B12 |

## 4. Cardinalidad

> *"1 prestación, 1 resolución archivada, 1 funcionario, varias cuotas a
> pagar, varias solicitudes de pago"* (Q-A12)

| # | Regla | Fuente |
|---|---|---|
| K-01 | Una solicitud de pago pertenece a **una sola resolución** | Q-A02, Q-A05 |
| K-02 | Lo ideal es **un funcionario por solicitud** | Q-A03 |
| K-03 | Mismo centro de costo con **dos resoluciones distintas** ⇒ **dos solicitudes de pago** separadas | Q-A03 |
| K-04 | Una solicitud puede incluir **varias cuotas** del mismo funcionario, incluidas atrasadas, siempre de la misma resolución | Q-A04 |
| K-05 | Se pueden crear **varias solicitudes** para la misma prestación **hasta agotar el monto autorizado** | Q-A06 |
| K-06 | Si un detalle se observa o rechaza, **se devuelve la solicitud completa** | Q-A09 |
| K-07 | Solo se paga trabajo **ya realizado**: la fecha de la prestación debe haber pasado | Q-A02 |

## 5. Pagos fijos y variables

Único respaldo funcional explícito: *"claro la idea es que se pague pero
también hay **pagos fijos y variables**"* (Q-A06).

Implementación acordada (2026-09-07): se reutiliza `sg_fups.cod_tpps`
(catálogo `sg_tpps`), **sin columnas nuevas**.

| `cod_tpps` | Tipo | Comportamiento del monto |
|---|---|---|
| 1 | **Fijo** | Monto parejo entre los meses de ejecución (`mto_total ÷ meses`, calculado en pantalla). Conocido con certeza desde la solicitud. |
| 2 | **Variable** | El monto real de cada mes no se conoce al crear la solicitud. La solicitud declara solo el **techo máximo**; la distribución se define al pago. |

Coherente con C-03 (el solicitante distribuye manualmente en ambos casos) y
con C-10 (en ambos el monto solo puede bajar respecto del techo).

## 6. ANID

| # | Regla | Fuente |
|---|---|---|
| A-01 | Se identifica **automáticamente por centro de costo**; no requiere certificado ni carga documental | Q-D01, Q-D11 |
| A-02 | Elimina el tope y **permite ingresar libremente el pago de cuotas** | Q-D03, Q-D04 |
| A-03 | No es una extensión solicitable: *"al pertenecer ANID ya se cuenta como una extensión en sí misma"* | Q-D05, Q-D08 |
| A-04 | No se puede modificar: depende del centro de costo | Q-D09 |
| A-05 | Habilita a **Decanos** (y a nadie más) para realizar prestación de servicios | Q-D10 |

## 7. Matriz de flujos

| # | Tipo | ANID | Techo del monto | Cuotas | Afirmable en la solicitud |
|---|---|---|---|---|---|
| 1 | Fijo | No | Tope completo por cuota, acotado por saldo autorizado | Según distribución del solicitante | Monto por mes exacto |
| 2 | Fijo | Sí | Sin tope (A-02) | Libre | Monto por mes exacto |
| 3 | Variable | No | Tope completo por cuota, acotado por saldo autorizado | Según distribución del solicitante | Solo el techo |
| 4 | Variable | Sí | Sin tope (A-02) | Libre | Solo el techo |

## 8. Estado del frontend (actualizado 2026-09-09)

El campo **Cuotas esperadas** (`worker.nroCuotas`, acotado por
`getMaxDeclarableInstallments` a `min(cupo disponible, meses de ejecución)`) es
el dato que fija el techo, no los meses de ejecución — resuelve T-01/T-02 a
nivel de solicitud.

**El techo ya no es `tope × cuotas` para ambos tipos** (corrección 2026-09-09,
T-07): en fijo es `tope × meses ÷ ceil(meses ÷ cuotas)`, porque la cuota agrupa
meses enteros; en variable sigue siendo `tope × cuotas`.

Cubierto en el formulario de solicitud:

| Regla | Dónde |
|---|---|
| T-04 (techo acotado por saldo autorizado) | `workerPaymentMonthsValidation` |
| T-07 (factibilidad del reparto en fijo) | `getPaymentMonthsValidation` (frontend) y `validateStaffAuthorizedAmount` (backend); techo en `getTopBrutoLabel` |
| T-08 (reparto por resto mayor) | `getFixedMonthAmounts` (`normative/formatters.js`); visible mes a mes en `ExecutionMonthsTags` |
| C-01 (define el solicitante) | Campo "Cuotas esperadas" |
| C-09 (mes bloqueado para la misma actividad) | Regla 11 (`cost_center_month_locked`) |
| Numeral 2 / T-05 (suma mensual del funcionario) | Regla 3 (`monthlyCapAggregateCheck`), entre solicitudes concurrentes |
| §5 fijo/variable | `worker.codTpps`, reparto visible en `ExecutionMonthsTags` |

**No cubierto — son reglas de la etapa de pago, no de la solicitud** (T-01,
T-02, T-03, T-06, C-02 a C-08, C-10): dependen de que exista una cuota real
con su propio monto y estado, y hoy `sg_fume.mto_apagar` no se escribe (Q-B13
sigue bloqueando). Mientras tanto, la solicitud solo puede garantizar el
agregado (techo total), no el detalle por cuota.

## 9. Puntos abiertos — no asumir criterio

Sin respuesta en S0-013:

1. **Q-C13 / Q-C14** — qué fecha determina el tope (mes de ejecución,
   solicitado, de autorización o de pago efectivo) y si se recalcula cuando
   la fecha efectiva cambia de mes.
2. **Q-C07** — si el saldo del tope mensual puede usarse en otra cuota o
   solicitud del mismo mes. T-03 responde el caso entre cuotas consecutivas,
   pero no el caso intra-mes.
3. **Q-B13** — significado definitivo de `ano_prop/mes_prop`,
   `ano_ejec/mes_ejec`, `ano_pago/mes_pago`.
4. **Q-B14** — si `sg_fups.tot_cuotas` es plan, total definitivo o derivado.
5. **Q-B15** — qué hacer con las cuotas históricas del mecanismo anterior.
6. **Q-J07 a Q-J14** — sección completa de montos/contrato/haber/tope sin
   responder: si el monto lo propone el sistema o el usuario, cálculo del
   saldo contractual, qué pasa si cambia el tope entre etapas, y cómo se
   registra el tope independiente de ANID.
7. **Sección H completa** (licencia médica, permiso sin goce, vigencia de
   proyecto, receso) — todas las fuentes y tratamientos sin definir, pese a
   que C-10 depende de ellas para ajustar montos.

## 10. Referencias

- ClickUp S0-013 `86e2zrkh4` — cuestionario maestro (fuente autoritativa)
- Decreto 009/2026, numerales 2 y 6
- `sg_fups`, `sg_fume`, `sg_tpps`, `sg_ecuo` — DDL vigente en `secgen_db`
