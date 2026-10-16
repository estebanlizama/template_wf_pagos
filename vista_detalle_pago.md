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

---

## 8. Qué falta para cerrar la vista — auditoría del 13-10-2026

Contrastado contra `reglas_pagos/02_vista_solicitud_pago.md` §4 y §5, verificando
en ejecución sobre la prestación 8. `backend_lo_que_falta.md` quedó desactualizado
en dos puntos: la evidencia **sí** está implementada (ver, descargar, reemplazar,
quitar) y la bandeja DGDP con observar/aprobar/rechazar también.

### 8.1 Datos que la pantalla debería mostrar y no muestra

| # | Qué falta | Por qué |
| :-: | :--- | :--- |
| 1 | **Motivo de la devolución** | La cuota llega *Devuelta* y no dice **por qué**, quién la revisó ni cuándo. El payload de `sg_epagsSecgen02` no trae observación, RUT revisor ni fecha porque `sg_epag` no tiene esas columnas. Es el dato que más le falta al solicitante: le devuelven la cuota y tiene que adivinar qué corregir. |
| 2 | **`afec_du9` y `con_topdu9`** | *Flujo DU288* y *Régimen de cuotas* muestran «No informado». **Doble causa**: `sg_fupssSecgen18` no está desplegado, y además el detalle lee `activeStaff` —el objeto de la resolución— mientras los dos campos se mapearon en `Du288PayableProvisionResponse`, que esta vista nunca carga. Desplegar el PA **no alcanza**: falta la conexión. |
| 3 | **Saldo de la prestación, 2 de 4 columnas** | §4.3 pide autorizado / pagado / comprometido en otras solicitudes / disponible. La pantalla muestra *Total decretado* (`authorized`) y *Saldo por gestionar* (`remaining`); `consumed` y `proposed` viajan en `paymentBalance` y no se pintan. |
| 4 | **Centro de costo incompleto** | Faltan tipo y fuente de financiamiento, modalidad de prestación y `des_unifin`. Dependen de `sg_fupssSecgen18`. |
| 5 | **Resumen de confirmación (Q-F11)** | *«Cuota a enviar: Cuota N° 1 · $222.222»* dice cuánto, no **qué abarca**. Q-F11 pide las dos cosas. |

### 8.2 Validaciones que faltan

| # | Qué | Estado |
| :-: | :--- | :--- |
| 6 | **Revalidación normativa al enviar (V5)** | **No existe en el backend.** `submitInstallment` solo comprueba la evidencia y llama a `sg_epaguSecgen02`. El panel afirma *«se consultan con datos vigentes y se repiten al enviar»* y eso **hoy es falso**: solo bloquea el frontend. Un `POST` directo al endpoint pasa con el contrato vencido, el cargo cambiado o el centro de costo sin saldo. Es el hallazgo más serio de la vista. |
| 7 | **Q-B09 — cruce de año calendario** | Sin implementar. Una cuota puede abarcar diciembre y enero de años distintos. |
| 8 | **T-05 / C-05 — dos cuotas en el mismo mes de pago** | Sin implementar ni en el frontend ni en `sg_epagiSecgen01`, que solo valida el rango de `@ano_pago` / `@mes_pago`. Necesita antes definir qué cuenta como deuda o atraso. |
| 9 | **Apartado 2** | Los dos defectos de `plan_saldo_ejecucion_y_cuotas.md` §8, con plan en §9. |

### 8.3 Lo que no depende de esta vista

| # | Qué | Efecto |
| :-: | :--- | :--- |
| 10 | **Tres transiciones DGDP de ocho** | Existen decisión (observar / aprobar / rechazar) y descuentos. Faltan **enviar a Finanzas** (4→8), **registrar devolución de Finanzas** (8→11) y **excluir un mes no pagable** (→4). Sin la primera, una cuota aprobada **nunca llega a pago** y el flujo del solicitante no se cierra. |
| 11 | **`ALTER` de `sg_epag`** | Es lo que desbloquea el punto 1. Sin ventana de DDL, el motivo de la devolución no tiene dónde guardarse. |

### 8.4 Orden sugerido

1. **Punto 6** — la revalidación del envío. No depende de nadie y hoy la pantalla promete algo que el backend no cumple.
2. **Punto 9** — los dos defectos del apartado 2, ya planificados.
3. **Punto 2** — conectar `afec_du9` / `con_topdu9` al detalle, junto con el despliegue de `sg_fupssSecgen18`; arrastra el punto 4.
4. **Punto 3 y 5** — son pintar datos que ya llegan.
5. **Punto 10** — enviar a Finanzas, para que el flujo termine.
6. **Puntos 1 y 11** — juntos, cuando haya ventana de DDL.
7. **Puntos 7 y 8** — reglas sin implementar; el 8 necesita una definición antes.

---

## 9. Lo aplicado el 13-10-2026 — puntos 2, 3, 4 y 6

Los puntos 1, 5, 7, 8, 10 y 11 de §8 quedan **descartados o fuera de alcance**
por decisión del 13-10-2026: el motivo de la devolución no tiene dónde
guardarse en el esquema vigente, y la cuota se devuelve únicamente al
solicitante, que ya sabe cuál es la suya.

### 9.1 Punto 2 y 4 — el régimen y los antecedentes presupuestarios

El diagnóstico de §8.1 era de dos causas, y las dos están cerradas.

**La conexión que faltaba.** El detalle se arma con los recursos del flujo de
resolución, que nunca cargan la fila de la bandeja. Se agregó
`GET /requests/service-provision/payments/provisions/{id}/summary`, que
reutiliza `sg_fupssSecgen18` con `@ano = 0` y filtra la prestación en el
controlador. No necesita guarda extra: el PA ya acota por responsable vigente
del centro de costo, así que pedir una prestación ajena devuelve vacío.

En el frontend viaja por `provisionSummary` en el store de detalle, se recarga
al cambiar de funcionario —si no, el bloque mostraría los datos del anterior— y
`costCenterRegime` lo lee con `activeStaff` como respaldo.

**Las columnas que faltaban en el PA.** `sg_fupssSecgen18` ganó nueve columnas
y cuatro `left join`:

| Columna | Origen |
| :--- | :--- |
| `cod_tfinan`, `des_tfinan` | `es_ccto` + `es_tfin` |
| `cod_ftfn`, `des_ftfn` | `es_ccto` + `sf_ftfn` |
| `des_unifin` | `es_ufin` |
| `cod_sitm`, `itm_global` | `sg_fups` |
| `cod_modprs`, `des_modprs` | `sg_prse` + `sg_tmod` |
| `cod_contra`, `cod_cargo` | `sg_fups` — los necesita la compuerta del punto 6 |

Son los mismos joins que `sg_prsesSecgen01` usa en el flujo de resolución, así
que el dato es el mismo que ya se muestra allá. Van también al `group by`.

**Hasta desplegar el PA**, los cuatro campos nuevos y los dos del régimen
muestran *No informado*. La conexión ya está hecha: el día que el PA entre, se
llenan solos.

### 9.2 Punto 3 — el saldo de la prestación, las cuatro columnas

§4.3 pedía autorizado / pagado / comprometido / disponible. Había dos.

El cálculo local **no servía** para desglosarlas: `resolvePaymentAmountBalance`
suma en `consumed` los estados 2, 3, 4, 8 y 11, o sea mezcla *comprometido* con
*pagado*, y en `proposed` solo los borradores. Etiquetar `consumed` como
«Pagado» habría sido falso —en la prestación 8 habría dicho $222.222 pagados
cuando no se ha pagado nada—.

El desglose real lo trae el resumen, que los separa en origen
(`mto_pagado` y `mto_gestion`):

| Campo | Fuente | Prestación 8 |
| :--- | :--- | ---: |
| Total decretado | `sg_fups.mto_total` | $444.444 |
| Pagado | `mto_pagado` | $0 |
| En trámite | `mto_gestion` | $222.222 |
| Saldo por gestionar | `mto_saldo` | $222.222 |

Si el resumen no llegara, `inProgressAmount` cae a `consumed − pagado`.

### 9.3 Punto 6 — la compuerta del envío

`submitInstallment` llama ahora a `assertInstallmentNormativeCompliance` antes
de tocar la cuota. Cubre las **cuatro validaciones bloqueantes** del panel del
solicitante, en el mismo orden en que la pantalla las presenta:

| Validación | PA | Bloquea cuando |
| :--- | :--- | :--- |
| contrato | `selectNormativeStaffProfile` | el contrato con el que se autorizó la prestación ya no está vigente |
| cargo | `getStaffNormativeDisablement` | `habilitado_du288 <> 'S'` |
| asignaciones | `selectNormativeStaffAssignments` | alguna asignación con `habilitado_du288 = 'N'` |
| tope del cargo | `selectNormativeStaffPositionCap` | no hay tope vigente, o la cuota lo supera sin extensión |
| saldo del centro de costo | `validateNormativeCostCenterBalance` | el ítem no tiene saldo para el monto de la cuota |

El contrato se busca por `cod_contra` de `sg_fups`, no por «algún contrato
vigente del RUT»: la pregunta es si **ese** contrato sigue en pie.

**Lo que queda fuera, a propósito y documentado en el código:**

- **carga semanal** — necesita los horarios de las prestaciones concurrentes y
  el cálculo de `evaluatePaymentWeeklyLoad`, que hoy solo existe en el
  frontend. Portarlo es un trabajo aparte.
- **calendario institucional** — en el panel nunca bloquea.
- **parentesco** — solo bloquea en la revisión DGDP
  (`requireRelationshipCertificate: true`), no en el envío del solicitante.
  Replicarlo acá habría endurecido la regla, no reproducido la pantalla.

**La rama del saldo necesita `cod_sitm`**, que llega con el despliegue del PA.
Hasta entonces esa validación se omite y las otras cuatro corren igual.

### 9.4 Verificación

`tsc --noEmit` limpio, `eslint` limpio, **201 tests** en verde. En pantalla,
sobre la prestación 8: las cuatro columnas del saldo correctas y los campos
nuevos en *No informado*, como corresponde con el PA sin desplegar.

### 9.5 Por desplegar

`sg_fupssSecgen18` — las nueve columnas nuevas. Sin él, los puntos 2 y 4 se ven
pero vacíos, y la compuerta del punto 6 corre con cuatro validaciones en vez de
cinco.

---

## 10. Incidente — `sg_fupssSecgen18` rompió la bandeja (13-10-2026)

**Qué pasó.** Las nueve columnas que §9.1 agregó al PA entraron también al
`group by`, que pasó de 27 a 38 expresiones. Sybase ASE 12.5 corta en 31:

```
Maximum number of group-by expressions exceeded. Limit is 31, found 38
```

El PA falla entero, así que **todo lo que lo consume deja de responder**:
`payable-provisions` (la bandeja), `provisions/{id}/summary` y
`provisions/{id}/previous-provisions`. En desarrollo la bandeja devolvía cero
filas y el detalle no llegaba a montar.

**El límite no está en la documentación del proyecto** y no se detecta
compilando: el PA se crea sin error y revienta al ejecutarse.

**Corrección.** El grano del `select` ya es `fu.id_funprse`, así que las nueve
columnas nuevas y `cod_contra` / `cod_cargo` son funcionalmente dependientes:
salen del `group by` y se proyectan con `max()`.

```sql
max(ccto.cod_tfinan)                    as cod_tfinan,
rtrim(isnull(max(tfin.des_tfinan), '')) as des_tfinan,
...
```

El `group by` vuelve a 27 expresiones, las mismas de antes del cambio.

**Regla para la próxima vez:** en este PA, una columna nueva de una tabla
unida va con `max()`, nunca al `group by`. Quedan cuatro de margen.

**Requiere redesplegar `sg_fupssSecgen18`.**

---

## 11. Validaciones de resolución frente a las de pago — 14-10-2026

Contraste de `validateNormativeRequestStaff` y sus auxiliares contra lo que hoy
valida el flujo de pago, en sus tres capas: pantalla, compuerta del envío y PA.

### 11.1 El cuadro

| Validación en resolución | Dónde vive allá | Estado en pagos |
| :--- | :--- | :--- |
| Un solo funcionario por solicitud | `DU288_STAFF_CARDINALITY` | heredada; no se rehace |
| El solicitante no es el funcionario | `DU288_APPLICANT_IS_STAFF` | heredada |
| Actividad con al menos 10 caracteres | `DU288_INVALID_ACTIVITY` | heredada |
| Fechas de inicio y término coherentes | `validateStaffExecutionPeriod` | heredada |
| **El período no cruza el año calendario** | `validateStaffExecutionPeriod:2785` | **falta** a nivel de cuota (Q-B09) |
| Período de ejecución ≤ 12 meses | `validateStaffExecutionPeriod:2792` | heredada |
| Compensaciones dentro del período | `validateStaffExecutionPeriod:2823` | ✅ `sg_fuc2iSecgen01:163` |
| Monto total autorizado mayor que cero | `validateStaffAuthorizedAmount` | ✅ PA |
| Cuotas declaradas dentro del máximo | `validateStaffAuthorizedAmount` | ✅ `sg_epagiSecgen01:116` |
| **Factibilidad del reparto (T-07)** | `validateStaffAuthorizedAmount` | **parcial**: `unpayableMonths` es solo pantalla e informativo; la base no lo mira |
| **Monto mensual + prestaciones concurrentes ≤ tope** | `validateStaffAuthorizedAmount:3093` | **falta** |
| Contrato y cargo habilitados | `validateStaffContractDisablement` | ✅ panel + compuerta del envío |
| Asignaciones habilitadas | `validateStaffAssignments` | ✅ panel + compuerta |
| Carga semanal con prestaciones concurrentes | `validateStaffWorkload` | ✅ panel; **no** en la compuerta (§9.3) |
| Calendario institucional | `getInstitutionalCalendar` | ✅ panel, nunca bloquea |
| Saldo del centro de costo | `validateNormativeCostCenterBalance` | ✅ panel + compuerta |
| Parentesco | frontend de resolución | panel; bloquea solo en la revisión DGDP |

### 11.2 La que falta de verdad: el monto concurrente

La resolución no compara solo contra el tope del cargo: suma el **monto mensual
equivalente de las otras prestaciones vigentes del mismo funcionario** y
compara el agregado.

En pagos, la concurrencia se mira **solo en horas** —`evaluatePaymentWeeklyLoad`
cruza los horarios de las prestaciones que se superponen— y el **dinero** se
compara únicamente contra el tope de esta cuota. Si el funcionario cobra otra
prestación DU288 en el mismo mes de remuneraciones, nada suma las dos.

Es más amplio que T-05, que solo habla de dos cuotas **de la misma prestación**
cayendo en el mismo mes: acá son prestaciones distintas. Y es justamente lo que
Q-C08 pide revalidar al pagar, porque la resolución lo validó con los datos de
entonces y el pago ocurre meses después.

**Para cerrarla hace falta**, en este orden:

1. Leer las prestaciones concurrentes del funcionario, que ya se consultan para
   la carga semanal (`previous-provisions`), y quedarse con las que tienen pago
   en el mismo `ano_pago` / `mes_pago`.
2. Sumar su aporte mensual al de esta cuota y comparar contra el tope vigente.
3. Replicarlo en `sg_epaguSecgen02`, porque la pantalla no es la frontera.

### 11.3 Las otras dos, ya anotadas

- **Cruce de año calendario (Q-B09)** — §8.2 punto 7. La resolución lo valida
  sobre el período; en pagos una cuota puede abarcar diciembre y enero de años
  distintos sin que nadie lo mire.
- **T-07 en la base** — la arista A de `plan_saldo_ejecucion_y_cuotas.md` §11.5.
  La pantalla calcula la factibilidad del reparto; ningún PA la comprueba.

### 11.4 Lo que no hay que revalidar

Cardinalidad, solicitante distinto del funcionario, largo de la actividad y
coherencia de fechas son propiedades de la **resolución archivada**: no cambian
entre el decreto y el pago, y rehacerlas en pagos solo agregaría ruido. Se
dejan explícitamente fuera.

---

## 12. Alcance acotado y los chips de resolución — 14-10-2026

Corrige §11.2 y mapea los dos bloques de chips del formulario de resolución.

### 12.1 El cruce es dentro del centro de costo

§11.2 proponía sumar **todas** las prestaciones concurrentes del funcionario.
El alcance correcto es más estrecho: **solo las del mismo centro de costo**.
Eso cambia la implementación —`sg_fupssSecgen18` ya lista exactamente eso— y
reduce el trabajo a filtrar por `cod_unifin` + `cod_ccto` antes de sumar.

### 12.2 De dónde salen los chips de centro de costo

Todos los indicadores del bloque de centro de costo de resolución se calculan
en `sg_cctosSecgen05` sobre columnas de `es_ccto`, la misma tabla que
`sg_fupssSecgen18` ya une:

| Chip en resolución | Cómo se calcula | Estado en pagos |
| :--- | :--- | :--- |
| Financiamiento compatible | `afec_du9 = 'S'` | ✅ **ya está**, como *Flujo DU288* |
| ANID / sin tope | `con_topdu9 = 'N'` | ✅ **ya está**, como *Régimen de cuotas* |
| Centro de costo vigente | `ccto.vigente` | implícito: todos los PA de pago filtran por él |
| Responsable vigente | `ecct.vigente` | implícito: el filtro por `es_ecct.rut` lo exige |
| Decreto afecto | `decr_afect is not null` | falta; informativo |
| Formación continua | `decr_afect = '1'` | falta; informativo |
| Saldo disponible | `sg_cctosSecgen06` | ✅ panel + compuerta |

**Corrección a §11.1:** «Financiamiento compatible» no faltaba. Es el mismo
`afec_du9` que ya proyectamos; en resolución se rotula como financiamiento y en
pagos como flujo.

**Lo implícito merece hacerse explícito.** Que el centro de costo o el
responsable dejen de estar vigentes no produce un error: la prestación
**desaparece de la bandeja**, porque todos los PA filtran por
`ecct.vigente = 'S'` y por el RUT del responsable. Es seguro pero mudo — el
jefe de proyecto no sabe por qué dejó de ver una prestación que gestionaba.

### 12.3 ANID no es la extensión de cuotas

`sg_cctosSecgen05:65`:

```sql
case when isnull(ccto.con_topdu9, 'S') = 'N' then 'S' else 'N' end as ind_anid
```

O sea el flujo de resolución deriva **ANID de `con_topdu9`**, no de
`ext_cuotas`. Y A-02 dice que lo que elimina el tope es ANID.

El formulario de pago hace lo contrario:

```js
effectiveCap() {
  return this.hasExtension || this.monthlyCap <= 0 ? Infinity : this.monthlyCap
}
```

`hasExtension` es `ext_cuotas`. Con el dato que ahora proyecta
`sg_fupssSecgen18` la corrección es directa —`costCenterCapped === 'N'` es
ANID—, pero **cambia a quién se le aplica el tope**, así que es una decisión
funcional, no una corrección de oficio. Es la arista F de
`plan_saldo_ejecucion_y_cuotas.md` §11.5, ahora con evidencia de cuál es el
criterio en resolución.

### 12.4 Bloque del funcionario

| Chip en resolución | Estado en pagos |
| :--- | :--- |
| Contrato | ✅ |
| **Contrato cubre período solicitado** | ❌ **falta** |
| Principal | falta; informativo |
| Cargo habilitado | ✅ |
| Sin parentesco | ✅ (no bloquea al solicitante) |
| Dentro / fuera de jornada | ✅ como dato en *Prestación seleccionada* |
| Compensación no requerida | ✅ por mes |

**El que falta importa.** La compuerta del envío comprueba que el contrato
**exista y esté habilitado**, no que **cubra los meses que se están pagando**.
Un contrato que terminó en marzo deja pasar el pago de un mes de junio. En
resolución esto es `isContractValidityCompatible`; acá habría que comparar la
vigencia del contrato contra el período de los meses incluidos en la cuota.

### 12.5 Las cinco que pediste revisar

| Pedido | Estado |
| :--- | :--- |
| El mes ya se ocupó o se pagó | ✅ `availabilityOf` + `sg_epagiSecgen01:191`, revalidado dentro de la transacción |
| Máximo de cuotas permitidas | ⚠️ se valida contra `tot_cuotas` de la resolución, **pero no** el máximo por año calendario que resolución aplica a las extendidas |
| Diferencias si es extendida | ⚠️ hoy la extensión exime del tope; ver §12.3 |
| Documento de respaldo | ✅ obligatorio al enviar, en backend y PA |
| Horas de compensación bien asignadas | ✅ por mes, con período validado en `sg_fuc2iSecgen01:163`, y bloquea la última cuota |
| Que no pase el tope válido | ✅ en pantalla · ❌ en la base (arista A) |
| Avisar que se pierde dinero | ✅ aplicado, `plan_saldo_ejecucion_y_cuotas.md` §12 |

---

## 13. Dos secciones y el saldo siempre visible — 14-10-2026

### 13.1 El saldo deja de plegarse

La tabla de validación presupuestaria estaba dentro de un `b-collapse` que se
abría solo cuando el saldo bloqueaba. Pasa a estar **siempre abierta**: es una
validación que impide enviar, y esconderla obligaba a descubrir el problema
recién al intentar el envío. Se fueron con ella el botón de plegado, el estado
`budgetOpen` y el `watch` que lo abría.

### 13.2 Un bloque para la prestación y otro para el centro de costo

Catorce campos en una sola rejilla no dejaban ver a qué pertenecía cada dato, y
son cosas que cambian por motivos distintos: lo que la resolución autorizó para
esta persona no se mueve, mientras el centro de costo y su saldo sí. Se separan
igual que en el formulario de resolución:

| Prestación autorizada | Centro de costo y presupuesto |
| :--- | :--- |
| Funcionario · Actividad | Centro de costo · Unidad ejecutora |
| Resolución · RUT jefe de proyecto | Tipo y fuente de financiamiento |
| Extensión de cuotas · Modalidad de jornada | Ítem presupuestario |
| Tipo de monto · Total decretado · Tope mensual | Modalidad de prestación |
| Cuotas solicitadas / autorizadas | Flujo DU288 · Régimen de cuotas |
| Pagado · En trámite · Saldo por gestionar | **+ tabla de saldo, siempre visible** |
| Período de ejecución | |

Los dos del régimen —*Flujo DU288* y *Régimen de cuotas*— se mudaron al bloque
del centro de costo, que es de donde salen: los dos son columnas de `es_ccto`
(§12.2), no atributos de la prestación.

*Unidad ejecutora* también cambió de bloque por lo mismo, y de paso ahora
muestra el nombre junto al código cuando `des_unifin` llega.

Verificado ejecutando los computed reales con datos de la prestación 8.

---

## 11. Vista DGDP — reordenamiento (14-10-2026)

Auditoría de `review/_staffProvisionId/_installmentNumber.vue` con el mismo
criterio que se aplicó al detalle del solicitante: cada dato en un solo lugar,
la edición detrás de una acción explícita y el estado visible antes de actuar.

### 11.1 Hecho antes de este plan

| | Qué |
| :-- | :--- |
| 1 | `afec_du9` y `con_topdu9` como información, con las etiquetas del detalle |
| 2 | Encabezado de seis cifras a cuatro: se quitaron *Solicitado*, *Comprometido*, *Informado* y el conteo de bloqueantes, que ya viven en su sección; se agregaron **Cuota N de M** y **Mes de pago**, que no estaban en ninguna parte |
| 3 | Descuentos detrás de **Editar descuentos**, con *Cancelar edición*, *Guardar* y el chip **Sin guardar** |

### 11.2 Paso 1 — agrupar los antecedentes

Hoy `provisionFacts` es una lista plana de **24 campos** en una grilla de
`auto-fill`: el orden depende del ancho de la ventana, así que el cargo puede
quedar al lado del tope mensual. Se agrupan en cuatro bloques con título, que
es como se leen:

| Bloque | Campos |
| :--- | :--- |
| **Funcionario** | nombre y RUT · cargo · estamento · unidad |
| **Contrato** | vigencia · calidad · jornada · horas · inicio |
| **Prestación** | solicitud · actividad · resolución · período de ejecución · modalidad de jornada |
| **Centro de costo y montos** | centro de costo · flujo DU288 · régimen de cuotas · ítem presupuestario · tipo de monto · total autorizado · tope mensual · cuotas autorizadas · enviada el · evidencia |

El revisor entra a comprobar tres cosas —quién es, bajo qué vínculo trabaja y
con qué plata se paga—, y los bloques son exactamente esas tres más la
identificación.

### 11.3 Paso 2 — hacer visible el bloqueo antes de decidir

La compuerta **ya existe y está bien**: `askConfirmation('approve')` revalida
el panel y aborta si queda algún control bloqueante; observar y rechazar no lo
exigen, porque un control bloqueante suele ser justamente el motivo de la
devolución.

Lo que falta es que se **vea antes de hacer clic**. Hoy el botón *Aprobar* se
ve habilitado, el revisor lo pulsa y recién ahí aparece el error. En el detalle
del solicitante el botón de envío se muestra deshabilitado con el motivo al
lado; acá debe ser igual:

- *Aprobar* deshabilitado mientras el panel tenga controles bloqueantes, con el
  motivo junto al botón;
- la revalidación al pulsar **se mantiene**: es la que vale, porque entre
  abrir la vista y decidir pudo cambiar el contrato o el saldo;
- *Observar* y *Rechazar* quedan siempre habilitados.

### 11.4 Fuera de este plan

- **Saldo en cuatro columnas y datos presupuestarios del centro de costo**:
  `sg_epagsSecgen03` no proyecta `mto_pagado`, `mto_gestion` ni el
  financiamiento. Requiere tocar ese PA; no se hace junto con lo demás.
- **Reparto y tope del apartado 2**: no aplica, DGDP no arma cuotas.

### 11.5 Aplicado — paridad con el detalle del solicitante (14-10-2026)

**Antecedentes en cuatro bloques** (§11.2) y **bloqueo visible antes de
decidir** (§11.3), más el saldo que §11.4 daba por fuera de alcance y que sí se
pudo cerrar.

**Saldo de la prestación.** `sg_epagsSecgen03` proyecta ahora `mto_pagado` y
`mto_gestion` como subconsultas escalares —el mismo recurso que ya usaba para
`cant_compens`, así que el `group by` queda intacto en sus 25 expresiones, seis
bajo el límite de ASE—. Las definiciones son **copia literal** de
`sg_fupssSecgen18` líneas 98-99:

```sql
sum(case when cod_estfum = 3 then mto_realpa end)   -- pagado
sum(case when cod_estfum = 2 then mto_apagar end)   -- en tramite
```

No es un detalle: si las dos pantallas calcularan *pagado* de distinta forma,
el revisor y el solicitante discutirían cifras en vez del caso. El saldo se
deriva en el frontend (`total − pagado − en trámite`) para no agregar una
tercera subconsulta por la misma resta.

El bloque **Centro de costo y montos** queda con: centro de costo · flujo DU288
· régimen de cuotas · ítem · tipo de monto · monto autorizado · **pagado** ·
**en trámite** · **saldo por gestionar** · tope mensual · cuotas autorizadas.

### 11.6 Comparación de componentes entre las dos vistas

| Componente | Solicitante | DGDP | Nota |
| :--- | :--: | :--: | :--- |
| `Du288PaymentAntecedentsTab` | sí | sí | compartido |
| `Du288PaymentDocumentTab` | sí | sí | compartido |
| `Du288PaymentValidationsSection` | sí | sí | compartido |
| `Du288MonthVersionsModal` | sí | sí | compartido |
| `Du288PaymentContextSection` | sí | no | **no conviene compartirlo**: trae el selector de funcionario y el armado de cuotas, que DGDP no tiene. Lo que importaba era el contenido, y ese ya está igualado |
| `Du288PaymentBudgetSection` | no | sí | el solicitante tiene su propia copia dentro del contexto. **Duplicación real**, candidata a unificar |
| `Du288PaymentAbsencesSection` | no | sí | el solicitante no muestra licencias ni permisos, aunque expliquen los descuentos que no puede modificar |
| `Du288PaymentExecutionSection` | no | sí | el solicitante usa `Du288PaymentScheduleSection` en modal; son necesidades distintas |
| `Du288InstallmentFormSection` y compañía | sí | no | DGDP no arma cuotas |

### 11.7 Lo que queda

| | Qué | Estado — ver §14 |
| :-- | :--- | :--- |
| 1 | Unificar la tabla de saldo presupuestario en `Du288PaymentBudgetSection` | **ya estaba hecho**; esta auditoría se equivocó (§14.1) |
| 2 | Agrupar los campos del contexto del solicitante | **aplicado**: de dos grupos a tres (§14.2) |
| 3 | Mostrar licencias y permisos en el detalle del solicitante | **no se implementa**: necesita endpoint nuevo y una decisión de privacidad (§14.3) |
| 4 | Verificar las dos pantallas en vivo | **causa cerrada**: el panel no se pinta, no es un bug (§14.4) |

**Por desplegar:** `sg_epagsSecgen03`.

---

## 14. Cierre de los cuatro pendientes de §11.7 — 15-10-2026

### 14.1 Punto 1 — ya estaba hecho; la auditoría anterior se equivocó

`Du288PaymentContextSection` **ya importaba y usaba** `Du288PaymentBudgetSection`
(cuelga del grupo de centro de costo, con `withBudget: true`). No había dos
implementaciones de la tabla presupuestaria.

De dónde salió el error: la auditoría leyó el computed `fields` —una lista de
catorce campos— y concluyó que el contexto era plano. `fields` es **uno de los
grupos**, no el total: el componente ya tenía `fieldGroups` con dos bloques.
Conviene mirar el computed que arma los grupos, no el primero que aparece.

### 14.2 Punto 2 — aplicado: de dos grupos a tres

Lo que sí era cierto es que el primer grupo mezclaba dos cosas en una sola
rejilla de catorce campos: la **identificación** de la prestación con el
**avance de los montos**, de modo que el RUT del jefe de proyecto quedaba junto
al tope mensual. Se consultan en momentos distintos —uno al abrir, el otro al
armar la cuota—, así que se separan:

| Grupo | Campos |
| :--- | :--- |
| **Prestación autorizada** | funcionario · actividad · resolución · RUT jefe de proyecto · extensión · modalidad de jornada · período |
| **Montos y cuotas** | tipo de monto · total decretado · tope mensual · cuotas · pagado · en trámite · saldo por gestionar |
| **Centro de costo y presupuesto** | centro de costo · unidad ejecutora · tipo y fuente de financiamiento · ítem · modalidad de prestación · flujo DU288 · régimen de cuotas · **tabla de saldo** |

Queda alineado con los cuatro bloques de la vista DGDP, que separa además
*Funcionario* y *Contrato* porque muestra antecedentes contractuales que el
solicitante no ve.

### 14.3 Punto 3 — no se implementa: necesita endpoint y una decisión

Mostrar licencias y permisos al solicitante **no es trabajo de pantalla**. El
único origen del dato es
`/payments/dgdp/provisions/{id}/installments/{n}/attendance`, con guarda de
revisor DGDP: no existe equivalente para el jefe de proyecto.

Habría que crear un endpoint nuevo y, antes, resolver si corresponde que el
jefe de proyecto vea **el motivo** del descuento. Hoy ve el monto agregado y la
leyenda de que lo aplicó DGDP. Pasar de ahí a *licencia médica del 3 al 9* es
exponer salud de un subordinado a su jefatura directa. No es una decisión de
diseño: se consulta y recién después se implementa.

### 14.4 Punto 4 — por qué "no hidrata": no es un bug, es el panel sin pintar

Diagnóstico cerrado, y conviene dejarlo escrito porque ya costó dos sesiones.

| Comprobación | Resultado |
| :--- | :--- |
| `window.$nuxt` | existe |
| `$nuxt.$route.path` | correcto |
| `layout` / `layoutName` | definidos (`default`) |
| `nuxt.err` | `null` |
| consola | sin errores |
| `#__layout` | presente, con clases `layout-leave layout-leave-active` |
| `$nuxt.$children` | solo `NuxtLoading` y `NuxtBuildIndicator` |
| **`requestAnimationFrame`** | **no dispara nunca** |

La cadena es esa última fila. El `<transition name="layout" mode="out-in">` que
Nuxt pone alrededor del layout usa `nextFrame()`, o sea dos `rAF` encadenados.
Si el documento no se pinta, `rAF` queda congelado, el *leave* no termina y con
`mode: out-in` el *enter* no empieza nunca: el layout no se monta y queda el
HTML del SSR con las clases de salida puestas.

Y el documento no se pinta porque **la ventana de Claude está detrás de otra**.
Lo dice el propio error del screenshot: *"the page did not finish rendering…
Claude's window may be behind another window, which can stop the page from
drawing"*. `document.visibilityState` informa `visible`, que es lo que despista.

**La aplicación está bien.** Para verificar en vivo basta traer la ventana al
frente; con Claude in Chrome tampoco se pudo, porque no hay ninguna instancia
de la extensión conectada a esta cuenta.

Cómo confirmarlo en diez segundos desde la consola del navegador:

```js
await new Promise(r => { requestAnimationFrame(() => r('pinta')); setTimeout(() => r('congelado'), 2000) })
```

---

## 15. Vista DGDP por cuota — rediseño del 15-10-2026

La vista revisa **una cuota**, y la cuota agrupa meses de ejecución. Todo lo de
abajo sale de llevar esa idea a la pantalla.

### 15.1 Fuera la tira de cifras del encabezado

Mostraba *Cuota 1 de 2 · Mes de pago · A pagar · Tiempo en espera*. Tres de las
cuatro ya tenían lugar propio y la cuarta no era del encabezado:

| Dato | Dónde queda |
| :--- | :--- |
| Cuota 1 de 2 | en el **título**: «Cuota 1 de 2», con su chip de estado |
| Mes de pago | antecedentes → **Prestación** |
| A pagar | ya estaba en los totales de la tabla de meses |
| Tiempo en espera | antecedentes → **Prestación** |

Se eliminaron con ella el computed `headline`, su bloque de textos y el CSS de
las tarjetas KPI, que quedaban sin consumidor.

### 15.2 La ejecución pasa a leerse mes a mes

Eran dos bloques sueltos debajo del calendario: el **horario semanal** de la
resolución y una **tabla resumen por mes**. Para saber de qué día salía una
diferencia había que cruzarlos a mano contra el calendario.

Ahora hay un bloque por mes de la cuota:

```
Enero 2016    Comprometido 10:00 · Informado 8:00   [Falta informar 2:00]
  Lun 11   C I R   Compensación comprometida: 09:00–13:00 · Informada: 09:00–11:00
  Mié 13   C · ·   Compensación comprometida: 09:00–13:00
```

- Cada día trae **las mismas tres marcas del calendario** —comprometido,
  informado, reloj— con inicial y color, para que no dependa del matiz (§14).
- La fila es un botón: selecciona el día y alimenta el panel de detalle que ya
  existía, con sus horas, turno, exceso, ausencia y justificación.
- El horario semanal queda como **una línea de contexto**, que es lo que es:
  la referencia de qué significa «comprometido».
- Entran también los meses **sin compensación**: que un mes comprometido no
  informe nada es justamente lo que hay que ver.

**La regla de las marcas salió a un método `dayMarks(iso)`.** Estaba dentro de
`calendarCells`; duplicarla para el desglose habría garantizado que el
calendario y la lista terminaran contradiciéndose. Ahora el calendario también
la usa.

Se eliminaron `crossFields`, `crossRows`, `weekMinutes` y `notCountedMinutes`.

### 15.3 La tabla de meses dice qué cuota desglosa

El subtítulo agrega la cobertura: **«4 meses · Enero 2016 – Abril 2016»**. Sin
eso había que contar las filas para saber qué abarca la cuota.

### 15.4 Validaciones — un defecto real

El panel normativo es el mismo componente en las dos vistas, pero **la revisión
DGDP no le pasaba `balance-blocks`**, así que tomaba el valor por omisión
`true`. Con el INTERRUPTOR-DU09 apagado eso significaba que, en la revisión:

- el aviso amarillo de modo prueba **nunca aparecía**, y
- el panel daba por bloqueante un saldo que hoy no bloquea.

Es exactamente lo que advierte el comentario del interruptor: *«apagar solo uno
deja la pantalla y la compuerta diciendo cosas distintas»*. Corregido: la vista
DGDP lee el mismo getter que el detalle del solicitante.

### 15.5 Pendiente

- **Ausencias del período**: queda como está, general sobre las fechas de
  ejecución. Confirmado con el usuario.
- **Claves de texto muertas** en el bloque `execution` tras quitar la tabla
  resumen (`weekTotal`, `notCountedTotal`, `crossDayOne`…). No se eliminaron:
  varias se consumen como `labels.X` y no como `text.X`, y distinguirlas con
  seguridad exige revisar `selectedDayFacts` una por una. Sin riesgo funcional.
- **Verificación en vivo**: sigue bloqueada por el panel sin pintar (§14.4).
