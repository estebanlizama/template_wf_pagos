# Vista de detalle de pago — ingreso de la compensación realizada

**Fecha:** 01-10-2026
**Ruta propuesta:** `/prestacion-de-servicios/pagos/:nroSolici`
**Rol:** jefe de proyecto (`provision-payment-manage`)

Se entra desde la bandeja «Prestaciones por pagar». La bandeja lista **por funcionario**, porque
así se busca a una persona; el enlace lleva a la **resolución** y ancla en esa fila, porque el
saldo y el tope que hay que validar son del centro de costo.

---

## 1. Qué se ingresa acá

Lo nuevo de esta pantalla respecto a resolución es una sola cosa: **la compensación que el
funcionario efectivamente hizo**, contra la que se había comprometido.

| | tabla | cuándo | quién |
| :--- | :--- | :--- | :--- |
| comprometida | `sg_fuco` | al crear la resolución | jefe de proyecto |
| **realizada** | `sg_fuc2` | **acá** | jefe de proyecto |

La diferencia de grano importa: `sg_fuco` es por prestación, `sg_fuc2` es por prestación **y mes**
(`corr_fume`). Por eso el ingreso vive dentro de un mes y no suelto.

Solo aplica cuando `sg_fups.dentro_jor` es `S` o `D`. Quien ejecuta fuera de jornada no compensa
nada y la sección no debe aparecer.

---

## 2. Anatomía de la pantalla

Sigue el orden obligatorio de §4 del estándar visual: encabezado, estado, secciones en orden
funcional, resumen, acciones.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  SOLICITUD DE PAGO                                                           │
│  Resolución Exenta N° 45 · ADMINISTRACION BUS (9010-36) · 2026               │
│  Actividad: …                            Período: 01/09/2026 – 30/09/2026    │
└──────────────────────────────────────────────────────────────────────────────┘

┌─ Funcionario ────────────────────────────────────────────────────────────────┐
│  JEANETTE DEL PILAR POZA ARAVENA · 87.962.717                                │
│                                                                              │
│  Tipo de pago   Fija (meses)      Total autorizado   $141.111                │
│  Tope mensual   $155.254          Cuotas             1 de 1 autorizadas      │
│  Jornada        Dentro            Saldo              $141.111                │
└──────────────────────────────────────────────────────────────────────────────┘

┌─ Meses de ejecución ─────────────────────────────────────────────────────────┐
│                                                                              │
│   Mes          Estado        Monto      Compensación        Cuota            │
│  ────────────────────────────────────────────────────────────────────────    │
│  ▸ Sep 2026    Propuesta     $141.111   8 h de 8 h  ✓       —        [Editar]│
│    Oct 2026    En ejecución  —          —                   —                │
│                                                                              │
│  Solo se puede gestionar el pago de meses cuya ejecución ya terminó.         │
└──────────────────────────────────────────────────────────────────────────────┘

┌─ Compensación realizada · Septiembre 2026 ───────────────────────────────────┐
│                                                                              │
│   Comprometido        Informado           Diferencia                         │
│   8 h                 8 h                 0 h                                │
│                                                                              │
│  ┌── Comprometido en la resolución ──┐  ┌── Realizado ──────────────────┐   │
│  │  Lu 07/09   09:00 – 11:00   2 h   │  │  Lu 07/09   09:00 – 11:00  2h │   │
│  │  Mi 09/09   09:00 – 12:00   3 h   │  │  Mi 09/09   08:30 – 11:30  3h │   │
│  │  Vi 11/09   15:00 – 18:00   3 h   │  │  Ju 10/09   15:00 – 18:00  3h │   │
│  └───────────────────────────────────┘  └───────────────────────────────┘   │
│                                                                              │
│   [ Calendario de septiembre: clic en un día para agregar o quitar tramos ]  │
│   [ Copiar lo comprometido ]                                                 │
└──────────────────────────────────────────────────────────────────────────────┘

┌─ Cuota ──────────────────────────────────────────────────────────────────────┐
│  Meses que abarca   ☑ Sep 2026                                               │
│  Mes de pago        Octubre 2026          →  corriente                       │
│  Monto              $141.111                                                 │
│  Respaldo           [ Adjuntar ]                                             │
└──────────────────────────────────────────────────────────────────────────────┘

                             [ Guardar borrador ]  [ Enviar a visación ]
```

### Por qué dos columnas y no una

Comprometido y realizado lado a lado es el punto de la pantalla: lo que se audita es la
**diferencia**, no el dato suelto. Una sola lista editable con los valores precargados invita a
confirmar sin mirar, que es justo lo contrario de lo que el registro busca.

El calendario es el mismo `StaffCompensationSection` que ya usa resolución, acotado a un mes en
vez de navegar entre varios. Ya trae los totales requerido/compensado/saldo, los feriados
institucionales y el bloqueo de días tomados por otra PDS.

### Cuándo es editable

| estado del mes | compensación |
| :--- | :--- |
| `cod_estfum = 1` Propuesta | editable |
| `cod_estfum = 2` Comprometida, cuota en **3 Observada** | editable — DGDP devolvió para corregir |
| `cod_estfum = 2`, cuota en 2 o 4 | solo lectura |
| `cod_estfum = 3` Enviada a pago · `4` Rechazada | solo lectura |

---

## 3. PA que hay que crear

Espejo de los tres de FUCO, que sirven de plantilla exacta.

| PA | Espejo de | Entrada |
| :--- | :--- | :--- |
| `sg_fuc2sSecgen01` | `sg_fucosSecgen01` | `@nro_solici`, `@id_funprse`, `@corr_fume` |
| `sg_fuc2iSecgen01` | `sg_fucoiSecgen01` | `@id_funprse`, `@corr_fume`, `@fec_comrea`, `@hora_ini`, `@hora_ter` |
| `sg_fuc2dSecgen01` | `sg_fucodSecgen01` | `@id_funprse`, `@corr_fume` |

**`sg_fucosSecgen01` se reutiliza tal cual** para traer lo comprometido: ya lista por
`@nro_solici` sin filtrar por mes, y el frontend filtra. No hay que tocarlo.

### Lo que se copia sin cambios de `sg_fucoiSecgen01`

- la fecha se guarda **con la hora de inicio incrustada** (`@inicio_dt`), y el select la trunca de
  vuelta a día. Sin eso, la PK `(id_funprse, corr_fume, fec_comrea)` solo admite un tramo diario;
- modalidad DU288 y `dentro_jor in ('S','D')`;
- horas de inicio y término distintas;
- el tramo cae dentro de `f_inicio`–`f_termino`;
- no es feriado nacional (`ufro_db.dbo.es_cfer`, `cod_tipfer = 1`);
- no se superpone con otro tramo **del mismo funcionario**.

> La superposición se verifica contra todos los tramos de la persona, no solo los del mes. Dos
> horas son dos horas: si se solapan, da igual a qué `corr_fume` estén imputadas.

### Lo que cambia

**El borrado es por mes, no por funcionario.** `sg_fucodSecgen01` borra todo lo del
`id_funprse` de un viaje, porque el guardado es borrar-todo-y-reinsertar. En `sg_fuc2` eso
borraría meses que ya están comprometidos en una cuota enviada. La firma lleva `@corr_fume` y el
`delete` lo filtra.

**Verificar el estado del mes antes de escribir.** El PA de FUCO no lo necesita porque la
solicitud entera es borrador o no lo es. Acá cada mes tiene su propio estado, así que
`sg_fuc2iSecgen01` y `sg_fuc2dSecgen01` tienen que rechazar la escritura sobre un mes que ya no
admite cambios, según la tabla de arriba.

---

## 4. Dos definiciones pendientes

Las dos cambian el PA, así que conviene cerrarlas antes de escribirlo.

**a) ¿El tramo puede caer fuera del mes de su `corr_fume`?**
Trabajó el 30 de septiembre fuera de horario y compensa el 2 de octubre. En resolución la regla
era *«no tiene que ocurrir el mismo día, pero sí en la semana correspondiente»*; por mes no está
definida. Si se exige que caiga dentro del mes, una compensación a caballo entre dos meses no
tiene dónde registrarse.

**b) ¿Lo informado debe cuadrar con lo comprometido?**
En resolución la diferencia entre lo esperado y lo compensado es **error**: tiene que dar exacto,
y esa evaluación vive en el frontend (`getCompensationWorkloadEvaluation`), no en el PA. En pago,
informar menos horas de las comprometidas puede ser:

- un **bloqueo** — no se envía la cuota hasta que cuadre; o
- una **advertencia** — se informa el faltante y DGDP decide si descuenta.

La segunda parece más fiel a la realidad: el registro existe justamente para que la diferencia
llegue a quien decide. Pero es una decisión de negocio, no técnica.

**c) Derivada de (b):** si la diferencia no bloquea, ¿el botón «Copiar lo comprometido» debería
existir? Ahorra tipeo y a la vez facilita confirmar sin mirar.

---

## 5. Reglas de la compensación realizada

No se parte de cero: el catálogo `requerimientos_wf/9_catastro_validaciones_y_saldos.md` ya tiene
**PAG-38, PAG-38b y PAG-38c**, y PAG-38c dice explícitamente que las reglas horarias de resolución
(RES-JO-04 a RES-JO-09) se reaplican sobre los tramos nuevos.

### 5.1 Se reaplican tal cual

| Origen | Regla | Dónde está hoy |
| :--- | :--- | :--- |
| RES-JO-04 | Fecha, hora de inicio y hora de término obligatorias por tramo | formulario + `sg_fucoiSecgen01` |
| RES-JO-04 | Inicio y término distintos | `sg_fucoiSecgen01` |
| RES-JO-05 | Sin solapamiento ni duplicados | `formatters.js` + `sg_fucoiSecgen01` |
| RES-JO-06 | El tramo cae dentro de `f_inicio`–`f_termino` | `formatters.js` + `sg_fucoiSecgen01` |
| RES-JO-07 | **No puede caer en jornada institucional** — lun a vie 08:30–17:18 | `compensationOverlapsInstitutionalWorkday` |
| — | No es feriado nacional (`es_cfer`, `cod_tipfer = 1`) | `sg_fucoiSecgen01` |
| RES-JO-09 | Límite de 56 h semanales (`totHoras + hrsHonor + compensación`) | `getCompensationWorkloadEvaluation` |
| PAG-38c | Límite de 12 h diarias | **declarado, no implementado** |

> RES-JO-07 es la que más se malinterpreta por su nombre. Lo que la función evalúa es el
> **solapamiento** con la jornada institucional, y solapar es el error: la compensación tiene que
> ocurrir **fuera** de lunes a viernes 08:30–17:18. Es coherente con para qué existe — el
> funcionario hizo la prestación dentro de su jornada y repone esas horas fuera de ella.

### 5.2 Una se amplía

**RES-JO-05, solapamiento.** En resolución se verifica contra los otros tramos de `sg_fuco` del
mismo funcionario. En pago hay que verificar contra **todos los tramos de la persona**: los de
`sg_fuco` y los de `sg_fuc2`, de cualquier mes. Dos horas son dos horas; si se solapan da igual a
qué `corr_fume` estén imputadas o si una es compromiso y la otra ejecución.

### 5.3 Nuevas, propias del pago

| ID | Regla | Severidad |
| :--- | :--- | :--- |
| PAG-C1 | Solo aplica si `sg_fups.dentro_jor` es `S` o `D` | la sección no aparece |
| PAG-C2 | El mes admite escritura: `cod_estfum = 1`, o `2` con su cuota en `3 Observada` | bloqueo |
| PAG-C3 | El tramo pertenece al mes de su `corr_fume` | **por definir — ver §4.a** |
| PAG-38 | Lo informado cubre lo comprometido para ese mes | **por definir — ver §4.b** |
| PAG-38b | Si falta, se vuelven a comprometer solo los tramos faltantes | habilita corregir sin rehacer |

---

## 6. Dos cosas del catálogo que hay que corregir

### 6.1 PAG-38 quedó desactualizada

El catálogo dice:

> *La compensación comprometida se acreditó como ejecutada, contrastada contra **marcaje
> biométrico y registro de reloj** — bloqueo, con vía alternativa para quien no tiene marcaje
> obligatorio.*

La decisión de asistencia del **30-09-2026**, cerrada con Alex y José Luis, dice lo contrario: el
registro de asistencia **no valida automáticamente** y queda como antecedente para el revisor,
porque no tiene con qué atribuir el tiempo a una prestación — le faltan el horario del prestador,
el tipo de ingreso y el vínculo con `sg_fups`.

Así que PAG-38 ya no puede bloquear por contraste biométrico. Lo que queda es el contraste entre
**lo comprometido en `sg_fuco` y lo informado en `sg_fuc2`**, que es declarativo: lo afirma el
jefe de proyecto y lo pondera DGDP. Eso también vacía la «vía alternativa para quien no marca
reloj», que existía solo para salvar al personal académico del contraste automático.

### 6.2 PAG-38b no tiene dónde escribirse

> *Si la compensación no se cumplió o está incompleta, se vuelven a comprometer **solo los tramos
> faltantes** y la solicitud se revalida.*

Un tramo recomprometido es un **compromiso nuevo**, no una ejecución. Pero:

- escribirlo en `sg_fuco` rompe la frontera de solo lectura de resolución, que este flujo declara
  en el encabezado del modelo de datos;
- escribirlo en `sg_fuc2` lo mezcla con lo realizado, y la tabla **no tiene ninguna columna que
  los distinga**: `id_funprse`, `corr_fume`, `fec_comrea`, `hora_ini`, `hora_ter` y nada más.

Sin resolver esto, PAG-38b no es implementable. Las salidas posibles:

1. **Una columna de tipo en `sg_fuc2`** — `tip_compen char(1)`, `R` realizado / `C` recomprometido.
   Mínimo, y mantiene una sola tabla por mes.
2. **Tratar el recompromiso como realizado a futuro** — se registra con fecha futura y se distingue
   por la fecha. Frágil: el día que esa fecha pasa, deja de distinguirse.
3. **Dejar PAG-38b fuera del alcance** — si la compensación no se cumplió, DGDP descuenta o rechaza
   el mes, y no hay recompromiso. Es la más simple y la que menos supuestos agrega.

La **1** conserva la regla con el menor cambio. La **3** es legítima si el recompromiso resulta no
ser un requisito real: conviene confirmarlo antes de agregar una columna.

---

## 7. La compuerta de envío a visación

Guardar y enviar no validan lo mismo, y esa es la decisión de fondo: **el registro siempre acepta
lo que haya, el envío exige que esté completo.** Es el mismo criterio que ya usa resolución —
guardar borrador valida integridad mínima, enviar valida reglas completas (§6.3 del estándar
visual).

### 7.1 Lo que bloquea el envío

Agrupado por lo que verifica. Los IDs vienen del catálogo
`requerimientos_wf/9_catastro_validaciones_y_saldos.md`.

**Compensación** — decidido el 01-10-2026

| ID | Regla |
| :--- | :--- |
| PAG-38 | Lo informado en `sg_fuc2` cubre lo comprometido en `sg_fuco`, mes a mes |
| — | Solo se evalúa si `dentro_jor` es `S` o `D` |

**Estructura de la cuota**

| ID | Regla |
| :--- | :--- |
| — | La cuota tiene al menos un mes |
| PAG-08 | Cada mes tiene `mto_apagar > 0` |
| PAG-05 | Los meses siguen disponibles: no los tomó otra cuota mientras el borrador estaba abierto |
| PAG-11 | Evidencia adjunta — obligatoria al enviar, no al guardar |

**Cupo y cobertura**

| ID | Regla |
| :--- | :--- |
| PAG-14 · SAL-06 | Máximo 2 cuotas por PDS y funcionario en el año; sin límite con `ext_cuotas = 'S'` |
| PAG-13 · SAL-06c | El mes no está cubierto por otra cuota de la misma actividad |
| PAG-15 · SAL-06b | La última cuota solo se envía con la ejecución terminada |
| PAG-06 | El período cubierto cae dentro de `f_inicio`–`f_termino` |

**Montos**

| ID | Regla |
| :--- | :--- |
| PAG-09 · SAL-01 | Dentro del saldo contractual: `mto_total − pagado − comprometido` |
| PAG-10 · SAL-02 | Dentro del tope de la cuota, **completo y sin descontar cuotas anteriores** |
| PAG-03 · SAL-04 | El centro de costo tiene saldo presupuestario |

**Revalidación normativa** — se vuelve a correr entera, no se confía en lo que validó la resolución

| ID | Regla |
| :--- | :--- |
| PAG-02 | El usuario sigue siendo responsable vigente del centro de costo |
| PAG-03 | El centro de costo sigue vigente, no cerrado ni bloqueado |
| PAG-07 · PAG-30 | El contrato y el cargo cubren el período que se paga |
| PAG-31 | Sin asignación inhabilitante vigente en el período |
| PAG-32 | Constancia jurada de parentesco presentada |
| PAG-33 | Sin licencia médica en el período — `sp_eaus` grupo 2 |
| PAG-34 | Sin permiso sin goce de sueldo — `sp_eaus` grupo 1 código 2 |
| PAG-36 | Proyecto vigente y no cerrado al momento de la ejecución |
| PAG-39 | La actividad no es formación continua |

**Transaccional**

| ID | Regla |
| :--- | :--- |
| SAL-08 | Los montos se recalculan **dentro** de la transacción, sin caché |
| SAL-09 | Anticoncurrencia: ninguna cuota ni mes comprometido dos veces |

> SAL-09 es, en concreto, el índice único `(id_funprse, corr_fume)` sobre `sg_dpag`. Sin él, dos
> envíos simultáneos del mismo mes en cuotas distintas pasan las dos verificaciones y comprometen
> el mes dos veces.

### 7.2 Lo que advierte pero deja pasar

| ID | Regla |
| :--- | :--- |
| PAG-16 | Dos cuotas en el mismo mes de pago — se permite por atraso administrativo, con causal registrada |
| PAG-40 | Ajuste proporcional por ausencias en el período |
| PAG-12 | Vista previa del saldo presupuestario por ítem |
| — | Asistencia del período, como antecedente para el revisor (decisión del 30-09-2026) |

### 7.3 Tres cosas que la decisión sobre PAG-38 deja abiertas

**a) ¿Compensar de más también bloquea?**
En resolución la diferencia es error en los dos sentidos: `Math.abs(totalDifference) > 0.01`. En
pago, informar **más** horas de las comprometidas no perjudica a nadie — el funcionario repuso de
sobra. Bloquearlo obligaría a corregir hacia abajo un dato que es cierto. Propongo que el bloqueo
sea solo por defecto: `informado < comprometido`.

**b) ¿El bloqueo es por cuota o por mes?**
Si una cuota abarca septiembre y octubre y solo septiembre está completo, lo razonable es que el
mensaje nombre el mes y que el jefe de proyecto pueda **sacar octubre de la cuota y enviar
septiembre**. Eso exige que la verificación sea por mes, no un total agregado de la cuota.

**c) PAG-18 y PAG-38b siguen sin dónde escribirse.**
El recompromiso de los tramos faltantes necesita distinguir «realizado» de «recomprometido», y
`sg_fuc2` no tiene columna para eso. Mientras no se resuelva, la única salida ante una
compensación incompleta es completarla o sacar el mes de la cuota.

### 7.4 Dónde vive cada verificación

| Capa | Qué le toca |
| :--- | :--- |
| Pantalla | Totales y diferencia en vivo, y el botón deshabilitado con el motivo a la vista |
| Backend | Orquesta la revalidación normativa reutilizando los PA de resolución |
| PA de envío | Lo estructural y los saldos, **dentro de la transacción** |

La pantalla no es la que valida: adelanta el resultado para que el usuario no envíe a ciegas. Lo
que decide es el PA, porque es el único punto por el que pasan todas las escrituras y el único que
puede garantizar que el saldo que leyó sigue vigente al escribir.
