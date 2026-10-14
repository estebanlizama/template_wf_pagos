# Impacto 19 — Estado real de las validaciones de pago

**Fecha:** 14-10-2026
**Contrastado contra:** `requerimientos_wf/8_matriz_validaciones_resolucion_a_pago.md`,
`9_catastro_validaciones_y_saldos.md`, `reglas_pagos/01` y `02`, y
`contexto_reglas_cambios_agregados/06`.
**Método:** lectura del código y de los PA del paquete. No se ejecutó SQL contra la base.

---

## 1. El hallazgo de fondo: la capa autoritativa está vacía

La matriz define tres capas y es explícita en que **UI no es autoritativa** y que
PA-TX es «sin caché, dentro de la transacción». Después marca **más de veinte**
validaciones como PA-TX.

De esas veinte, la única que hoy vive en un PA transaccional es el **saldo del monto
total autorizado** (`sg_epaguSecgen02:179`). El resto está en la pantalla y, desde el
13-10, en la compuerta del envío del backend — que es capa API, no PA-TX.

| Capa | Qué hay hoy |
| :--- | :--- |
| UI | el panel de 9 chips, `isValid` del formulario, `unpayableMonths` |
| API | `assertInstallmentNormativeCompliance`: contrato, cargo, asignaciones, tope vigente, saldo del CC |
| PA-TX | meses disponibles, mes repetido, cuota ya tomada, cuotas autorizadas, mes de pago mínimo, evidencia, **saldo autorizado** |

**Por qué no es formalismo:** entre que la pantalla valida y el PA escribe pasa tiempo
y pasan otros usuarios. Hoy el tope por cuota, el cruce de año calendario y la cobertura
del contrato no los mira nadie dentro de la transacción.

---

## 2. Matriz A — revalidadas y adaptadas

| Código de la matriz | Clase | Capa exigida | Estado |
| :--- | :---: | :--- | :--- |
| `costCenterNotCurrent` | R | PA-TX | implícito: los PA filtran por vigencia, la prestación desaparece sin avisar |
| `responsibleNotCurrent` | R | API + PA-TX | cubierto por el mismo filtro |
| `incompatibleFinancing` | R | PA-TX | **falta**: `afec_du9` solo se muestra, no bloquea |
| `continuingEducation` | H + N | UI + DGDP | **falta** |
| `requiredWorkflow` | A | API | **falta** |
| `costCenterNoAvailableBalance` | A | PA-TX | UI + compuerta; no en PA |
| `CONTRATO_NO_CUBRE_RANGO` / `_MESES` | A | PA-TX | **falta** |
| `persistedContractUnavailable` | R | PA-TX | cubierto en la compuerta |
| `CARGO_CONTRATO_MODIFICADO` | R | DGDP | **falta** |
| `CARGO_INHABILITADO_DU288` | R | PA-TX | compuerta, no PA |
| `ASIGNACION_DU288_INHABILITADA` | A | PA-TX | compuerta, y no evalúa el período cubierto |
| `VALIDACION_CARGO_PENDIENTE` | R | PA-TX | UI bloquea; la compuerta trata «no habilitado» como error |
| `DEUDA_INSTITUCIONAL` | R | PA-TX | **no existe en pagos** |
| `TOPE_EXCEDIDO` | A | PA-TX | UI; ningún PA lo mira |
| `TOPE_FALTANTE` | R | PA-TX | cubierto en la compuerta |
| `capExemptAnid` | H | UI | ligado a `ext_cuotas`; ver §5 |
| `topExceededPaymentMonths` → `MAX_CUOTAS` | A | PA-TX | valida `tot_cuotas`, no el máximo de 2 por año |
| `amountGreaterThanZero` | R | UI + PA-TX | cubierto |
| `compensationDateOutOfPeriod` y familia | A | UI + PA-TX | cubierto (`sg_fuc2iSecgen01:163`) |
| `LIMITE_SEMANAL_EXCEDIDO` | A | UI + PA-TX | UI; fuera de la compuerta por decisión |
| `periodCrossoverCalendarYear` | R | PA-TX | **falta** |
| `workerExecutionStartOutOfPeriod` | A | PA-TX | cubierto: los meses salen de `sg_fume` |

---

## 3. Matriz B — las nuevas del flujo de pago

| Código | Capa exigida | Estado |
| :--- | :--- | :--- |
| `EVIDENCIA_FALTANTE` | UI + PA-TX | cubierto |
| `SALDO_AUTORIZADO_EXCEDIDO` | PA-TX | cubierto |
| `CUOTA_COMPROMETIDA` | PA-TX | cubierto |
| `MES_EJECUCION_YA_CUBIERTO` | PA-TX | cubierto |
| `PERIODO_DUPLICADO` | PA-TX | cubierto vía `sg_dpag` |
| `CUOTA_FINAL_ANTICIPADA` | PA-TX | cubierto |
| `COMPENSACION_NO_ACREDITADA` | DGDP | advierte y bloquea la última cuota |
| `SALDO_INSUFICIENTE` | PA-TX | UI + compuerta, no PA |
| `MAX_CUOTAS_EXCEDIDO` | PA-TX | parcial |
| `PRORRATEO_POR_AUSENCIA` | DGDP | existe el descuento, no la regla de prorrateo |
| `LICENCIA_PERIODO_CUBIERTO` | PA-TX | DGDP descuenta; **no bloquea** |
| `SIN_GOCE_PERIODO` | PA-TX | ídem |
| `PROYECTO_CERRADO` | PA-TX | **falta**: `val_ciecc` solo se lee |
| `RECESO_NO_ACREDITADO` | DGDP | **falta** |
| `CONSTANCIA_PARENTESCO_FALTANTE` | DGDP | el chip existe; solo bloquea en la revisión |
| `TRANSACCION_FALTANTE` | PA-TX | fase Finanzas, fuera de alcance |

---

## 4. Lo que los análisis anteriores no habían visto

Cuatro, y las cuatro salen de la matriz, no del código:

1. **`DEUDA_INSTITUCIONAL`** — inhabilidad absoluta desde el 2027-01-01, advertencia
   antes. En pagos no hay consulta ni chip. Es la ausencia más grande.
2. **`PROYECTO_CERRADO`** — `sg_fume.val_ciecc` existe, los PA de lectura lo proyectan
   y **ningún PA lo escribe ni lo comprueba**. Se paga ejecución posterior al cierre
   del proyecto sin que nada lo note.
3. **`incompatibleFinancing` es bloqueante**, no informativo. Lo tratamos como dato de
   lectura («Flujo DU288») cuando la matriz lo marca R / PA-TX: *prohibición
   estructural del D.U. 9, no pagar con presupuesto de base*.
4. **`RECESO_NO_ACREDITADO`** y **`continuingEducation`** — ninguno existe.

---

## 5. ANID: tres orígenes posibles, ninguno confirmado

| Candidato | Dónde aparece |
| :--- | :--- |
| `con_topdu9 = 'N'` | `sg_cctosSecgen05:65` → `ind_anid` |
| `afec_du9 = 'S'` | `sg_cctosSecgen05:64` → `ind_financiamiento_du288` |
| `cod_tfinan = 44` | `impacto_18` §2.1 |
| `ext_cuotas = 'S'` | lo que usa hoy el formulario de pago |

El flujo de pago usa el cuarto, que es el único que **no** aparece en los PA como
origen de ANID. `impacto_18` ya documenta que en resolución la exención es inconsistente
entre funciones. Es una decisión funcional pendiente: cambia a quién se le aplica el tope.

---

## 6. El calendario institucional no debería ser un check

El chip dice *«Calendario institucional consultado · se consultaron N fechas»*. Nunca
bloquea y nunca falla de forma accionable: confirma que una consulta ocurrió, no valida
nada. Ocupa un lugar en una lista donde todo lo demás decide si se puede enviar.

La matriz no lo lista como validación en ninguna de sus dos tablas. Las fechas
institucionales son **insumo** del cálculo de carga semanal y de compensación, no un
resultado que el usuario deba revisar.

**Propuesta:** sacarlo de la lista de validaciones. Si el dato importa, va como nota al
pie del bloque de compensación, que es quien lo usa.

---

## 7. Qué pasa hoy cuando una validación rechaza

| Momento | Qué ve el usuario |
| :--- | :--- |
| al armar la cuota | el chip se pone en rojo y el botón de enviar queda deshabilitado, con el motivo al lado |
| al guardar | `installmentError`, junto al formulario, persistente |
| **al enviar** | **un toast** (`this.$toast.error`) con el mensaje del backend |

El tercero es el problema. La compuerta devuelve un 422 con un motivo preciso y ese
motivo se muestra en un aviso que **se desvanece**: no queda junto a la cuota, no marca
qué chip falló, y el panel no se vuelve a consultar, así que los chips siguen en verde
contradiciendo al rechazo.

**Lo mínimo:** llevar el error del envío a `installmentError`, que ya persiste en la
tarjeta, y disparar `revalidateNormative` al recibir un 422 para que los chips cuenten
la misma historia que el rechazo.

---

## 8. Orden sugerido

| | Qué | Por qué en ese lugar |
| :-- | :--- | :--- |
| 1 | Rechazo persistente + revalidación tras el 422 | hoy el usuario pierde el motivo del rechazo |
| 2 | `TOPE_EXCEDIDO` en `sg_epaguSecgen02` | la validación PA-TX más citada y la única que deja entrar datos inválidos |
| 3 | `CONTRATO_NO_CUBRE_MESES` | silenciosa y con plata de por medio |
| 4 | Sacar el calendario de la lista de checks | cuesta nada y limpia la lectura |
| 5 | `DEUDA_INSTITUCIONAL` | tiene fecha de entrada en vigor: 2027-01-01 |
| 6 | `PROYECTO_CERRADO` sobre `val_ciecc` | la columna existe y está muerta |
| 7 | `incompatibleFinancing` bloqueante | requiere confirmar que en pago también prohíbe |

Los puntos 5, 6 y 7 necesitan confirmación funcional antes de escribirse. Los cuatro
primeros no.

---

## 9. Decisiones del 14-10-2026 y lo que confirman

### 9.1 Deuda institucional — no se valida, y se dice

No hay fuente de datos. Se cierra como **no validable**, no como pendiente: en
la lista aparece *Deuda institucional · Sin información*, sin bloquear.

Es distinto de omitirla. Un chip que falta se lee como «no corresponde»; uno que
dice *Sin información* deja constancia de que la regla existe y de que el sistema
no puede responderla. Cuando aparezca la fuente, el chip ya tiene su lugar.

Queda fuera del orden de §8.

### 9.2 Centro de costo cerrado — aplica, y el hueco es real

La regla no es sobre el proyecto sino sobre el **centro de costo**: no se puede
generar una cuota si está cerrado.

Verificado, y el resultado es peor de lo que decía §3:

| | Qué se filtra | Dónde |
| :--- | :--- | :--- |
| responsable del CC | `es_ecct.vigente = 'S'` | **los 26 PA de pago** |
| **el centro de costo** | `es_ccto.vigente` | **ningún PA** |

Los dos nombres se parecen y por eso pasó inadvertido: `es_ecct` es la relación
RUT ↔ centro de costo, `es_ccto` es el centro de costo. `sg_fupssSecgen18` une
`es_ccto` solo para leer el nombre y las marcas; nunca exige que esté vigente.

**Hoy un centro de costo cerrado sigue en la bandeja y admite cuotas nuevas.**

### 9.3 Financiamiento compatible = `afec_du9`, y bloquea

La compatibilidad se verifica contra la marca de pertenencia a DU09, que es la
variable que ya proyectamos. `afec_du9` deja de ser un dato de lectura y pasa a
ser **validación bloqueante**, coherente con la clase `R` / `PA-TX` de la matriz.

Se lee hoy en `sg_epagsSecgen03`, `sg_fupssSecgen17` y `sg_fupssSecgen18`, y
**ninguno lo usa como condición**.

### 9.4 Formación continua — cubierta por la anterior

Correspondería validarla, pero un centro de costo de formación continua no
pertenece a DU09, así que `afec_du9 = 'N'` ya lo detiene. **No se implementa
aparte**: una segunda regla que siempre coincide con la primera solo agrega
superficie de error.

Si alguna vez un CC de formación continua quedara marcado como DU09, eso sería
un dato mal cargado, no un caso que la pantalla deba resolver.

### 9.5 Dónde ponerlas

Las dos nuevas —`ccto.vigente` y `afec_du9`— son condición de **crear, editar y
enviar** una cuota, así que van en `sg_epagiSecgen01`, `sg_epaguSecgen01` y
`sg_epaguSecgen02`.

**No** se agregan como filtro de `sg_fupssSecgen18`. Filtrar haría desaparecer la
prestación de la bandeja, que es justo el defecto que §12.2 de
`vista_detalle_pago.md` señala del responsable vigente: el jefe de proyecto
pierde de vista trabajo ya ejecutado y no sabe por qué. La prestación se sigue
viendo, con el motivo escrito y la acción bloqueada.

En la pantalla, las dos van como chips del bloque **Centro de costo y
presupuesto**, que ya existe desde §13 de la vista.

### 9.6 Orden actualizado

| | Qué | Capa |
| :-- | :--- | :--- |
| 1 | Rechazo persistente + revalidación tras el 422 | front |
| 2 | `TOPE_EXCEDIDO` en `sg_epaguSecgen02` | PA |
| 3 | **Centro de costo cerrado** y **`afec_du9`** en los tres PA de cuota | PA + front |
| 4 | `CONTRATO_NO_CUBRE_MESES` | PA |
| 5 | Sacar el calendario de la lista de checks | front |
| 6 | Chip *Deuda institucional · Sin información* | front |

Salen del orden anterior: `PROYECTO_CERRADO` como regla propia —queda absorbido
por el punto 3—, `continuingEducation` —absorbido por `afec_du9`— y
`DEUDA_INSTITUCIONAL` como validación.

---

## 10. Lista de cierre

### 10.1 Se agregan — seis validaciones

| | Validación | Condición | Dónde |
| :-: | :--- | :--- | :--- |
| 1 | Centro de costo cerrado | `es_ccto.vigente <> 'S'` | `sg_epagiSecgen01` · `u01` · `u02` |
| 2 | Centro de costo fuera de DU09 | `afec_du9 <> 'S'` | los mismos tres |
| 3 | Tope por cuota | suma de la cuota > `mto_tope`, salvo exención | los mismos tres |
| 4 | Contrato no cubre los meses | vigencia de `cod_contra` contra el período de la cuota | `sg_epaguSecgen02` |
| 5 | La cuota cruza el año calendario | dos `ano_prop` distintos en una cuota | `sg_epagiSecgen01` · `u01` |
| 6 | Asignaciones sobre el período cubierto | `sg_fupssSecgen15` con `fechaEval` del período, no de hoy | compuerta del envío |

Las cinco primeras son reglas que hoy **no existen en ninguna capa** o existen
solo en la pantalla. La sexta corrige una que existe pero pregunta por la fecha
equivocada.

### 10.2 Se agregan — tres de presentación

| | Qué |
| :-: | :--- |
| 7 | El rechazo del envío deja de ser un toast: pasa a `installmentError` y dispara `revalidateNormative` |
| 8 | Chip *Deuda institucional · Sin información*, no bloqueante |
| 9 | Sale el chip de calendario institucional de la lista de validaciones |

### 10.3 No se agregan, y por qué

| Regla de la matriz | Motivo |
| :--- | :--- |
| `DEUDA_INSTITUCIONAL` | sin fuente de datos; queda como chip informativo (§9.1) |
| `continuingEducation` | absorbida por `afec_du9` (§9.4) |
| `PROYECTO_CERRADO` | absorbida por el centro de costo cerrado (§9.2) |
| `TRANSACCION_FALTANTE` | fase Finanzas, fuera del alcance actual |
| las marcadas **H** y **X** | antecedentes de la resolución; repetirlas convertiría el pago en una segunda resolución |

### 10.4 Siguen abiertas — necesitan definición funcional

| Regla | Qué hay que decidir |
| :--- | :--- |
| `MAX_CUOTAS_EXCEDIDO` | el máximo de 2 por año se libera en ANID; depende de cuál es el origen de ANID |
| `capExemptAnid` | `con_topdu9`, `afec_du9`, `cod_tfinan = 44` o `ext_cuotas` (§5) |
| `LICENCIA_PERIODO_CUBIERTO`, `SIN_GOCE_PERIODO` | la matriz los marca error; hoy DGDP descuenta en vez de bloquear. ¿Cuál manda? |
| `CARGO_CONTRATO_MODIFICADO` | la matriz deja abierta la severidad: advertencia o bloqueo |
| `requiredWorkflow` | si es lo mismo que `afec_du9` o se refiere al flujo configurado en `sg_tfls` |
| `RECESO_NO_ACREDITADO` | sin definición de cómo se acredita |
| Monto concurrente en el mismo CC | si se cruza por mes de pago o por meses de ejecución |

---

## 11. Decisiones del 14-10-2026 sobre lo que quedaba abierto

### 11.1 ANID se cierra: es la extensión

`capExemptAnid` deja de existir como concepto propio. La exención del tope la
decide la **extensión de cuotas**, que es lo que el formulario de pago ya usa.

Con eso **la arista F queda cerrada sin cambiar código**: `effectiveCap` sobre
`hasExtension` era correcto. Los otros tres candidatos de §5 —`con_topdu9`,
`afec_du9`, `cod_tfinan = 44`— quedan descartados como origen de la exención;
`afec_du9` conserva su propio papel, que es pertenecer a DU09 (§9.3).

También cierra el **máximo de cuotas**: son 2 por año, liberadas cuando hay
extensión. Lo único por confirmar es si el conteo de `sg_epagiSecgen01` es por
año de ejecución o por prestación completa.

### 11.2 Licencia y permiso sin goce no bloquean: se descuentan

No son una validación que impida pagar. El mecanismo es el **descuento que
aplica DGDP**, y cuando el mes completo no corresponde pagarse el descuento
iguala al monto del mes, con lo que el neto queda en **cero**. Esa es la forma
de expresar «no se paga este período».

`LICENCIA_PERIODO_CUBIERTO` y `SIN_GOCE_PERIODO` salen de la lista de reglas
bloqueantes de la matriz B.

**Lo que sí falta es mostrarlo bien.** La tarjeta del mes muestra hoy el
descuento **agregado** y dos chips con el motivo:

```
Descuentos   −$46.643
[Licencia médica] [Permiso sin goce]
```

El payload trae `medicalLeaveDeduction` y `unpaidLeaveDeduction` **por
separado** y la pantalla los suma. Hay que mostrar cuánto corresponde a cada
causal, no solo que ambas existen.

### 11.3 Cargo contra contrato: advertencia, por precedente

Se valida igual que en el flujo de solicitud. Y ahí ya está resuelta la
severidad que la matriz dejaba abierta:

```js
CARGO_CONTRATO_MODIFICADO: { label: 'Cargo o contrato modificado', severity: 'warning' }
```

Es **advertencia**, no bloqueo. Se replica tal cual: un cargo que cambió merece
que DGDP lo mire, no que el pago se detenga.

### 11.4 Receso: fuera

Los recesos no se acreditan. `RECESO_NO_ACREDITADO` no se implementa.

### 11.5 `requiredWorkflow`: se validan los dos

Pertenecer a DU09 (`afec_du9`) y tener el flujo de pago configurado son cosas
distintas y ambas se validan.

### 11.6 Monto concurrente: la pregunta estaba mal planteada

La regla real es más simple de lo que §12.1 proponía: **por mes de ejecución no
se puede pagar más de una cuota en ese centro de costo**. No es sumar montos
mensuales, es impedir que el mismo mes de trabajo se pague dos veces.

Y eso ya existe… **a medias**. `sg_epagiSecgen01:190`:

```sql
where dpag.id_funprse = @id_funprse
  and dpag.corr_fume  = c.corr_fume
```

El chequeo está acotado a **la misma prestación**. Dos prestaciones distintas
del mismo funcionario en el mismo centro de costo —que K-03 permite, porque son
resoluciones distintas— pueden cubrir el mismo mes y **cada una pagarlo**.

La validación que falta es la misma consulta sin el `id_funprse`, acotada por
RUT del funcionario, centro de costo y período de ejecución.

### 11.7 Lista final

| | Validación | Severidad | Dónde |
| :-: | :--- | :--- | :--- |
| 1 | Centro de costo cerrado | bloquea | `sg_epagiSecgen01` · `u01` · `u02` |
| 2 | Centro de costo fuera de DU09 | bloquea | los mismos tres |
| 3 | Flujo de pago configurado | bloquea | compuerta del envío |
| 4 | Tope por cuota | bloquea | los tres PA |
| 5 | Contrato no cubre los meses | bloquea | `sg_epaguSecgen02` |
| 6 | La cuota cruza el año calendario | bloquea | `sg_epagiSecgen01` · `u01` |
| 7 | Asignaciones sobre el período cubierto | bloquea | compuerta |
| 8 | Mes ya pagado en otra prestación del mismo CC | bloquea | `sg_epagiSecgen01` · `u01` |
| 9 | Cargo o contrato modificado | **advierte** | compuerta + panel |

Presentación:

| | Qué |
| :-: | :--- |
| 10 | Rechazo del envío persistente + revalidación tras el 422 |
| 11 | Descuento desglosado por causal en la tarjeta del mes |
| 12 | Chip *Deuda institucional · Sin información* |
| 13 | Sale el chip de calendario institucional |

Sin preguntas pendientes salvo una: si el máximo de cuotas se cuenta por año de
ejecución o por prestación (§11.1).

---

## 12. Aplicado el 14-10-2026 — primera tanda

### 12.1 El panel cambia de composición

| Antes | Ahora |
| :--- | :--- |
| Contrato habilitado | Contrato habilitado |
| Cargo habilitado | Cargo habilitado |
| Asignación habilitada | Asignación habilitada |
| Sin parentesco | Sin parentesco |
| Tope validado | Tope validado |
| — | **Centro de costo vigente** |
| — | **Centro de costo en DU09** |
| Centro de costo sin saldo | Centro de costo sin saldo |
| ~~Carga semanal validada~~ | — |
| ~~Calendario institucional consultado~~ | — |
| — | **Deuda institucional sin información** |
| Compensada en otros días | Compensada en otros días |

**Lo que se fue también se dejó de calcular.** La carga semanal traía el horario
de cada prestación concurrente —la consulta más cara del panel— para alimentar
un chip que ya no va; se eliminaron esa llamada, la de `previous-provisions` que
la precedía y la del calendario, más los helpers que quedaron muertos.

### 12.2 Las dos nuevas bloquean en el PA, no en la pantalla

`sg_epagiSecgen01`, `sg_epaguSecgen01` y `sg_epaguSecgen02` reciben la misma
guarda, justo después de comprobar que la prestación es del solicitante:

```sql
if isnull(@vig_ccto, 'N') <> 'S'
    select 'Error: El centro de costo esta cerrado, no admite cuotas de pago' as msg

if @afec_du9 <> 'S'
    select 'Error: El centro de costo no pertenece al flujo DU09' as msg
```

Con eso **crear, editar y enviar** quedan cubiertos en la capa autoritativa, que
es lo que §1 echaba de menos. La pantalla solo lo adelanta.

### 12.3 «Sin informar» no bloquea, a propósito

`hasBlockingNormativeValidations` trata `pending` como bloqueante. Si los dos
chips nuevos nacieran `pending` + `blocking`, **la bandeja quedaría detenida
hasta desplegar `sg_fupssSecgen18`**, porque hoy la columna no llega.

Nacen como advertencia no bloqueante. No se pierde nada: los tres PA ya
rechazan el centro cerrado o fuera de DU09, y esa es la capa que manda.

### 12.4 Verificación

`tsc` limpio, `eslint` limpio, **12 archivos de prueba correctos**, estándar
visual DU288 validado en 39 archivos. Los cuatro escenarios del chip —vigente,
cerrado, fuera de DU09 y sin dato— ejecutados con la lógica real.

### 12.5 Por desplegar

`sg_fupssSecgen18` (ahora con `vig_ccto`), `sg_epagiSecgen01`,
`sg_epaguSecgen01` y `sg_epaguSecgen02`.

### 12.6 Pendiente de esta lista

Siguen sin implementar, por orden de §11.7: tope por cuota en el PA (4), flujo
de pago configurado (3), contrato cubre los meses (5), cruce de año calendario
(6), asignaciones sobre el período cubierto (7), mes ya pagado en otra
prestación del mismo CC (8), cargo o contrato modificado (9), rechazo
persistente (10) y descuento desglosado por causal (11).

---

## 13. Auditoría de aislamiento frente al WF de resolución — 14-10-2026

Pregunta: ¿algo de lo hecho en pagos toca el flujo de resolución? Revisado
archivo por archivo contra `git status` y las fechas de los PA.

### 13.1 Los PA de resolución están intactos

| PA | Quién lo usa | Última modificación |
| :--- | :--- | :--- |
| `sg_fumeuSecgen01` | **resolución** — escribe los meses de ejecución | 06-10, antes de este trabajo |
| `sg_fupssSecgen17` | resolución (modal de prestaciones previas) **y** pagos | 09-10, antes de este trabajo |

Ninguno de los dos se tocó. Los modificados son todos del paquete de pagos:
`sg_epagiSecgen01`, `sg_epaguSecgen01`, `sg_epaguSecgen02`, `sg_fupssSecgen18`,
`sg_fumeuSecgen02`, `sg_fum2sSecgen01` y `sg_fum2sSecgen02`.

`sg_fupssSecgen18` es exclusivo de pagos: solo lo invoca
`service-provision-payment-procedures.repository`.

**Importante:** sacar la consulta de `previous-provisions` del panel de pagos
**no** afecta al modal de resolución. `selectStaffPreviousProvisions` conserva
sus consumidores, incluido `service-provision-request.controller:1734`, que es
el de resolución.

### 13.2 Los dos archivos compartidos, solo con agregados

| Archivo | Riesgo | Resultado |
| :--- | :--- | :--- |
| `utils/.../normative/messages.js` | lo usa el formulario de resolución | **cero líneas eliminadas**; solo claves nuevas |
| `lang/es/pds.js` | catálogo de textos de todo el módulo | una sola línea reemplazada: `balanceShort`, dentro de `payments.detail.installmentModal`, con un único consumidor en `Du288InstallmentFormSection.vue` |

### 13.3 Lo que sí está modificado del lado de resolución, y no es de este trabajo

`git status` muestra tres archivos de resolución con cambios. Conviene
distinguirlos:

| Archivo | Cambio | Origen |
| :--- | :--- | :--- |
| `resolution.controller.ts` | `paymentInstallments` y `formatDeclaredInstallments` | **de este trabajo**, pedido explícito: indicar en la resolución en cuántas cuotas se distribuye el pago |
| `resolution.controller.ts` | `executingUnit` con fallback al centro de costo, `item` por defecto *No informado*, `modality` acepta `'D'` | **anterior**, ya estaba sin commitear al empezar |
| `service-provision-request-detail.controller.ts` | una línea: `executingUnitName` | **anterior** |
| `service-provision-request.repository.ts` | una línea: `dentroJor === 'D'` | **anterior** |

Los tres cambios «anteriores» no son de esta línea de trabajo y no se tocaron.

### 13.4 Conclusión

El único cambio deliberado sobre resolución es el que se pidió —cuántas cuotas
declara la resolución—. Todo lo demás vive en el paquete de pagos o es aditivo
sobre archivos compartidos.

**Regla para lo que queda por implementar (§12.6):** las nueve validaciones
pendientes se escriben en los PA de `sg_epag`, en la compuerta del envío y en
los componentes de pago. Ninguna necesita tocar `sg_fumeuSecgen01`,
`sg_fupssSecgen17` ni el formulario de resolución. Si alguna pareciera
necesitarlo, se detiene y se consulta antes.

---

## 14. Por qué no llegaba el centro de costo — 14-10-2026

Son dos cosas distintas, y una era un error en la guarda que acababa de escribir.

### 14.1 `es_ccto.vigente` es `'1'`, no `'S'`

El panel marcaba **«Centro de costo cerrado»** sobre un centro que está abierto.
El endpoint devolvía `costCenterActive: "1"`.

Las dos tablas tienen dominios distintos y los nombres invitan a confundirlas:

| Columna | Tabla | Dominio |
| :--- | :--- | :--- |
| `vigente` | `es_ecct` — relación responsable ↔ centro de costo | `'S'` / `'N'` |
| `vigente` | **`es_ccto`** — el centro de costo | **`'1'` / `'0'`** |

Resolución ya lo tenía resuelto y no lo miré: `sg_cctosSecgen05:84` filtra
`ccto.vigente = '1'` y el formulario compara `costCenterValidity === '1'`.

**La guarda de los tres PA comparaba contra `'S'`.** Desplegada así habría
rechazado **todas** las cuotas, de cualquier centro de costo. Corregido en
`sg_epagiSecgen01`, `sg_epaguSecgen01`, `sg_epaguSecgen02` y en el chip del
panel. Verificado en pantalla: el chip pasó a *Centro de costo vigente*.

### 14.2 `afec_du9` está vacío en la base, no falta en el PA

El PA sí está desplegado: llegan `financingTypeName`, `budgetItemCode`,
`provisionModeName`, `contractId` y `positionCode`. Lo que no llega es lo que
está en `NULL` en `es_ccto` para ese centro de costo:

| Columna | Efecto en pantalla |
| :--- | :--- |
| `afec_du9` | *Flujo DU09 sin informar* |
| `con_topdu9` | *Régimen de cuotas: No informado* |
| `cod_ftfn` → `des_ftfn` | *Fuente de financiamiento: No informado* |

No es un problema de proyección: es **dato sin cargar** en el centro de costo de
prueba.

**Y abre una decisión.** La guarda del PA exige `afec_du9 = 'S'`, igual que
resolución —`isnull(ccto.afec_du9, 'N')`—. Con la columna en `NULL`, ese centro
de costo quedará bloqueado para pagar en cuanto se desplieguen los PA.

Dos salidas, y la elección es funcional:

1. **Cargar el dato** en los centros de costo que sí pertenecen a DU09. Es lo
   coherente: si la marca existe para decidir, tiene que estar puesta.
2. **Tratar `NULL` como permitido**, que contradice a resolución y deja la
   validación sin efecto justo donde el dato falta.

Mientras tanto el panel lo muestra como **advertencia no bloqueante**, así que
nada se detiene antes de desplegar.

### 14.3 Ajuste aplicado y qué hace falta para cerrarlo

**Código.** La comparación corregida a `'1'` queda en los tres PA de `sg_epag` y
en el chip del panel. `tsc` limpio, `eslint` limpio, 12 archivos de prueba
correctos, estándar visual validado en 39 archivos, y los cuatro `.txt`
sincronizados con sus `.sql` en CRLF.

**Datos.** Falta saber en cuántos centros de costo está sin cargar `afec_du9`.
Para eso está `datos_base/06_marcas_du09_centro_costo.sql`, que **no modifica
nada**: lista los centros con prestaciones DU288 archivadas junto a sus marcas,
cuenta los que quedarían sin poder pagar, y deja el `update` comentado.

El criterio para cargarla: un centro de costo con una resolución DU288 archivada
pertenece al flujo por definición —la resolución no se habría podido decretar
sobre él si no—. Aun así la marca se carga revisando caso a caso, porque `'S'`
ahí habilita pagar con ese presupuesto.

**Redesplegar**, en este orden:

| | PA | Por qué |
| :-- | :--- | :--- |
| 1 | `sg_fupssSecgen18` | agrega `vig_ccto` |
| 2 | `sg_epagiSecgen01` · `sg_epaguSecgen01` · `sg_epaguSecgen02` | las guardas, ya con el dominio correcto |

Los de `sg_epag` **no deben desplegarse con la versión anterior de hoy**: la que
comparaba `vigente` contra `'S'` rechaza cualquier cuota.

---

## 15. INTERRUPTOR-DU09 — lo apagado y cómo encenderlo

Decisión del 14-10-2026: el saldo del centro de costo y la pertenencia a DU09
dejan de bloquear mientras los centros de costo de prueba no tengan cargadas sus
marcas presupuestarias.

### 15.1 Por qué interruptores y no desactivar el botón

Dejar enviar sin validar se lleva por delante **todas** las validaciones, no las
dos que estorban: contrato, cargo, asignaciones y tope siguen siendo correctas y
siguen siendo las que protegen el pago.

Y no alcanzaría: el saldo bloquea en **dos capas** desde el 13-10. Apagarlo solo
en la pantalla daría un 422 del backend igual, con el agravante de que el usuario
vería todo en verde y el envío fallando.

### 15.2 Los cinco puntos, con la misma marca

Un `grep -rn "INTERRUPTOR-DU09"` los encuentra todos:

| Archivo | Qué hace |
| :--- | :--- |
| `store/service-provision-payment-detail.js` | `BALANCE_VALIDATION_BLOCKS_SUBMISSION = false` |
| `service-provision-payment.controller.ts` | `BALANCE_BLOCKS_SUBMISSION = false` |
| `sg_epagiSecgen01` · `sg_epaguSecgen01` · `sg_epaguSecgen02` | la guarda de `afec_du9`, comentada |

### 15.3 Qué sigue funcionando

| | Estado |
| :--- | :--- |
| Centro de costo **cerrado** | **sigue bloqueando**, en los tres PA |
| Contrato, cargo, asignaciones, tope | sin cambios |
| Chip *Centro de costo sin saldo* | **sigue en rojo**, pero ya no impide enviar |
| Chip *Flujo DU09 sin informar* | advertencia, como estaba |

Los dos chips se mantienen a la vista a propósito: lo que se apagó es el
bloqueo, no el diagnóstico. Si además se ocultaran, al encender el interruptor
aparecerían problemas que llevaban semanas ahí sin que nadie los viera.

### 15.4 Para volver a encender

1. `BALANCE_VALIDATION_BLOCKS_SUBMISSION = true` en el store.
2. `BALANCE_BLOCKS_SUBMISSION = true` en el controller.
3. En los tres PA, borrar la línea de apertura y la de cierre del comentario que
   envuelve la guarda de `afec_du9`, y redesplegarlos.

Antes del paso 3, correr `datos_base/06_marcas_du09_centro_costo.sql` y cargar
`afec_du9` donde falte: encender la guarda con el dato vacío vuelve a dejar esos
centros de costo sin poder pagar.
