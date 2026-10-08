# Detalle DGDP: validaciones, asistencia y descuentos

**Fecha:** 06-10-2026
**Complementa:** [detalle_dgdp_que_se_espera.md](./detalle_dgdp_que_se_espera.md), que define la estructura de la vista. Este documento define **qué se valida, con qué fuente y qué falta construir**.
**Fuentes:** `requerimientos_wf/9_catastro_validaciones_y_saldos.md` (RES-* y PAG-*), `cambios_pa/asistencia/` completo, `decisiones_flujo_pago.md`.

Respuesta corta a lo preguntado: **sí a todo, y la mayor parte ya tiene PA**. Lo que falta son tres PA de lectura y tres de escritura, más el cableado de la asistencia.

---

## 1. Asistencia: ¿se muestra por PA y se compara con lo realizado?

**Sí.** El PA existe: `cambios_pa/asistencia/sp_as01sSecgen01.sql`.

| | |
| :--- | :--- |
| Entrada | `@rut`, y `@cod_periodo` o el par `@f_inicio`/`@f_termino` en YYYYMMDD |
| Salida | una fila por día: fecha, día de semana, marca de entrada y salida, horario de turno, `min_marcados`, `min_turno`, estado, ausencia con su motivo, justificación, feriado con su tipo, minutos de atraso y anticipo, y las tolerancias aplicadas |
| Estado | **artefacto SQL escrito, no desplegado y no cableado en el backend** |

### 1.1 Cómo se compara con lo realizado

El cruce ya está diseñado en `cambios_pa/asistencia/cruce_con_nuestra_bdd.md`. Tiene dos formas según `sg_fups.dentro_jor`:

**Fuera de jornada** (`dentro_jor = 'N'`): lo comprometido vive en `sg_fuho`, que es **recurrente** (día de la semana + tramo). Hay que proyectarlo sobre `f_inicio`–`f_termino` para obtener las fechas, y recién ahí comparar contra las marcas.

**Dentro de jornada** (`S` o `D`): lo comprometido vive en `sg_fuco` con **fecha exacta**, y lo informado en `sg_fuc2`. No hay que proyectar nada.

En ambos casos el excedente del día se mide **neto**: `min_marcados − min_turno`. No por la hora de salida, que es lo que el documento descartó explícitamente.

### 1.2 Qué puede y qué no puede acreditar

De doce preguntas, el cruce responde diez: si el día comprometido existió, si era hábil, si trabajó, cuánto estuvo, si trabajó fuera de turno, si cubrió el tramo, si hubo licencia o sin goce, cuánto descontar, si trabajó en receso y si la compensación se hizo.

Las dos que no: **para qué se usó ese tiempo** y **si hizo la actividad comprometida**. El reloj no registra el motivo.

Por eso la decisión del 30-09-2026 (Alex y José Luis, informada a Jaime) dejó la asistencia como **antecedente del revisor, no como validación automática**. No bloquea el envío ni determina por sí sola si un mes es pagable. Lo que esta vista debe ofrecer es exactamente lo que esa decisión listó: mostrar el detalle diario, cruzarlo con lo comprometido, presentarlo lado a lado y aportar el contexto de licencias, permisos y feriados.

**⚠️ Nota de desfase:** `cruce_con_nuestra_bdd.md` §1 afirma que *"`sg_fuc2` no lo teclea nadie, se construye cruzando las fechas comprometidas contra las marcas reales"*. Eso quedó superado: el flujo implementado tiene al jefe de proyecto registrando `sg_fuc2` a mano con `sg_fuc2iSecgen01`, y la decisión del 30-09 quitó a la asistencia su carácter autoritativo. El contraste que queda es declarativo — `sg_fuco` contra `sg_fuc2` — con la asistencia como tercera columna informativa.

### 1.3 Lo que falta

| # | Pendiente | Origen |
| :-- | :--- | :--- |
| 1 | Desplegar `sp_as01sSecgen01` y cablearlo como query asset + endpoint con guardia DGDP | — |
| 2 | Confirmar si `sp_as21` registra licencias reales — en pruebas está vacía | condición 1 del cruce |
| 3 | Confirmar la ventana de horario flexible con SISPER | condición 3 |
| 4 | Definir qué hacer con los días marcados **Incompleto** | condición 4, nuestra |
| 5 | Definir cuál registro vale cuando hay duplicados del mismo día | condición 5, nuestra |

Las decisiones 4 y 5 se pueden cerrar sin esperar a nadie. La 2 es la que define si los descuentos por licencia son automáticos o quedan a criterio de DGDP.

---

## 2. Licencias médicas y permiso sin goce: validar, calcular y permitir ingresar

### 2.1 De dónde sale el dato

| Concepto | Fuente | Clave |
| :--- | :--- | :--- |
| Licencia médica | `sisper_db..sp_as21` | `tip_agraus = 2` |
| Permiso sin goce | `sisper_db..sp_as21` | `tip_agraus = 1`, `cod_agraus = 2` |
| Texto del motivo | `sisper_db..sp_eaus` | clave compuesta `(tip_agraus, cod_agraus)` → `res_ausen` |

`sp_as21` es detalle 1:N de `sp_as01` por `cod_asist`: la ausencia es **del día**, no un rango. El rango se arma agrupando días consecutivos.

### 2.2 Qué escribe cada marca

| Columna de `sg_fume` | Se determina con | Regla |
| :--- | :--- | :--- |
| `val_licmed` | `sp_as21` grupo 2 | `S` si algún día del mes tiene licencia |
| `val_singoce` | `sp_as21` grupo 1 código 2 | `S` si algún día tiene permiso sin goce |
| `val_inabili` | `sg_fupssSecgen14`/`15` | no viene de asistencia |
| `val_ciecc` | `sg_prse` + FIN21 | no viene de asistencia |
| `mto_deslic` | días hábiles con licencia ÷ días hábiles del mes | proporción sobre `mto_apagar` |
| `mto_dessg` | días hábiles sin goce ÷ días hábiles del mes | ídem |
| `mto_realpa` | `mto_apagar − mto_deslic − mto_dessg` | resultado |

Ejemplo del documento de cruce: marzo 2016 tiene 31 días corridos y **22 hábiles** descontando sábados, domingos y los feriados del 25 y 26. Una licencia del 07 al 11 afecta 5 días hábiles, así que `mto_deslic = mto_apagar × 5 / 22`.

Los días hábiles salen del calendario institucional, `es_cfersSecgen01`, que ya está cableado.

### 2.3 Cómo debe comportarse la vista

1. **Propone** el descuento calculado por la regla de proporción, con el desglose visible: días afectados, días hábiles del mes, porcentaje y monto.
2. **Permite editar** el monto de `mto_deslic` y `mto_dessg` por mes, porque el cálculo es una propuesta y la decisión es del revisor — y porque mientras `sp_as21` no esté poblada en producción, es la única vía.
3. **Recalcula** `mto_realpa` en vivo y muestra la comparación: solicitado, descuentos, resultante, y la diferencia contra lo que vería Finanzas.
4. **Valida** que cada descuento sea ≥ 0 y que la suma no supere `mto_apagar` del mes; un descuento igual al monto equivale a excluir el mes y debe ofrecer ese camino (B6 del diagrama) en vez de dejar un mes en cero.
5. **Marca** `val_licmed` y `val_singoce` automáticamente cuando la fuente los informe, y deja constancia de que el revisor los ajustó si difieren de lo propuesto.

### 2.4 Lo que falta

| # | Pendiente | Tipo |
| :-- | :--- | :--- |
| 1 | **PA de ausencias por periodo** — no existe. `sp_as01sSecgen01` entrega el motivo del día como texto libre concatenado, no agrupado por `(tip_agraus, cod_agraus)` ni con rangos. Se necesita uno que, dado RUT y periodo, devuelva las ausencias clasificadas con fecha de inicio y término | PA nuevo de lectura |
| 2 | **PA de escritura de descuentos** — ningún PA escribe `mto_deslic` ni `mto_dessg`. `sg_fumeuSecgen02` solo escribe `mto_apagar`, `ano_ejec` y `mes_ejec` | PA nuevo de escritura |
| 3 | **PA de cierre** que persista `mto_realpa` en `sg_epag` y `sg_fume` en la misma transacción — están denormalizados a propósito | PA nuevo de escritura |
| 4 | **Conteo de días hábiles del mes** descontando feriados: la fuente existe, falta la función | cálculo |

---

## 3. Todas las validaciones que deben aparecer en esta vista

El criterio ya cerrado en `decisiones_flujo_pago.md` §11: **el envío y la visación revalidan el panel normativo completo con datos frescos**, y **las reglas normativas no se reescriben en SQL** — se reutilizan los PA de resolución. Entre el decreto y el pago pueden haber cambiado el contrato, el cargo, el saldo o la vigencia del responsable.

La columna «PA» marca ✓ cuando ya es query asset del backend y solo falta exponerlo al rol DGDP.

### 3.1 Centro de costo, financiamiento y saldo

| ID | Control | Fuente | Severidad | PA |
| :--- | :--- | :--- | :--- | :---: |
| RES-CC-01/02 | CC obligatorio, vigente y asociado al responsable | `sg_cctosSecgen05` | bloqueo | ✓ |
| RES-CC-03 | Responsable del CC vigente | `sp_orcosSecgen01` | bloqueo | ✓ |
| RES-CC-04 | Financiamiento compatible con DU288 | ficha del CC | bloqueo | ✓ |
| RES-CC-05 · PAG-39 | No es Formación Continua | ficha del CC | bloqueo | ✓ |
| RES-CC-08 · SAL-01 | Saldo por ítem presupuestario | `sg_cctosSecgen06` | **en pago es obligatorio**, no informativo | ✓ |
| PAG-36 | Proyecto vigente y no cerrado al momento de la ejecución | nuevo | bloqueo | ✗ |
| — | `val_ciecc` · cierre del CC en el mes | `sg_epagsSecgen04` | marca por mes | ✓ |

Nota: RES-CC-07, el saldo por `valida_saldo_cc_cs`, está **apagado** en resolución (§2.4 del catastro). En pago no puede seguir apagado: es la plata que se va a girar.

### 3.2 Contrato y cargo

| ID | Control | Fuente | Severidad | PA |
| :--- | :--- | :--- | :--- | :---: |
| RES-FU-04/05/06 | Contrato válido, vigente o en trámite, con horas informadas | `sg_fupssSecgen16` | bloqueo | ✓ |
| RES-FU-07/08 | El contrato cubre el rango y los meses de ejecución | fechas del contrato | bloqueo | ✓ |
| RES-FU-09 | El contrato persistido sigue disponible y vigente | comparación con la ficha | bloqueo | ✓ |
| RES-FU-10 · PAG-41 | Cargo o contrato modificado después de la resolución | comparación | advertencia · severidad por decidir | ✓ |
| PAG-30 | Cargo o contrato habilitado **a la fecha de pago** | `sg_fupssSecgen14` | bloqueo | ✓ |

PAG-30 no es RES-IN-01 repetida: cambia la fecha de evaluación. Un cargo habilitado al decretar puede no estarlo al pagar.

### 3.3 Inhabilidades

| ID | Control | Fuente | Severidad | PA |
| :--- | :--- | :--- | :--- | :---: |
| RES-IN-01/02 | Cargo y contratos habilitados | `sg_fupssSecgen14` | bloqueo | ✓ |
| RES-IN-03 · PAG-31 | Sin asignación o designación inhabilitante en el periodo pagado | `sg_fupssSecgen15` | bloqueo | ✓ |
| RES-IN-05 | Asignación próxima a vencer, 30 días | `sg_fupssSecgen15` | advertencia | ✓ |
| RES-IN-06 | Parentesco con incompatibilidad absoluta | `sg_fupssSecgen12` | bloqueo | ✓ |
| RES-IN-07 · PAG-32 | Constancia jurada de parentesco | `sg_fupssSecgen12` | **bloqueo, diferido desde la resolución a este punto** | ✓ |
| RES-IN-08 · PAG-37 | Deuda institucional no regularizada | sin fuente integrada | bloqueo desde 2027-01-01 | ✗ |

RES-IN-07 es informativa en resolución **porque se difirió al pago**. Esta vista es donde se exige la constancia; si no se implementa aquí, no se exige en ninguna parte.

### 3.4 Tope, haberes y monto

| ID | Control | Fuente | Severidad | PA |
| :--- | :--- | :--- | :--- | :---: |
| RES-TO-01 | Tope mensual disponible y válido | `sg_fupssSecgen13`, `funps13` | bloqueo | ✓ |
| RES-TO-02 | Tope especial por cargo o contrato | `sg_tocasSecgen01` | bloqueo | ✓ |
| RES-TO-04 | Haberes del mes anterior disponibles | `sg_fupssSecgen13` | bloqueo | ✓ |
| RES-TO-05 | Excepción ANID: se ignora el tope del 50 % | marca del CC + certificación DIUFRO/DITT | informativa | ✓ |
| SAL-02 | **El tope entra completo por cuota**, sin descontar cuotas anteriores | `sg_fups.mto_tope` | bloqueo | ✓ |
| RES-TO-08 · B3 | Prestaciones previas del funcionario | `sg_fupssSecgen17` | informativa con alerta de concurrencia | ✓ |
| PAG-40 | Ajuste proporcional por ausencias | §2 de este documento | advertencia con ajuste de monto | ✗ |

### 3.5 Jornada y compensación

| ID | Control | Fuente | Severidad | PA |
| :--- | :--- | :--- | :--- | :---: |
| RES-JO-05 | Tramos sin solapamiento ni duplicados | `formatters.js` | bloqueo | n/a |
| RES-JO-06 | Fecha del tramo dentro del periodo habilitado | `formatters.js` | bloqueo | n/a |
| RES-JO-07 · PAG-38c | Compensación fuera de la jornada 08:30–17:18, lunes a viernes | `compensationOverlapsInstitutionalWorkday` | bloqueo | n/a |
| RES-JO-09 | Límite de 56 horas semanales, sumando contrato, honorarios y PDS activas | `sg_fupssSecgen13` | bloqueo | ✓ |
| RES-JO-10 | Distribución horaria de ejecución consistente | `sg_fuhosSecgen01` | bloqueo | ✓ |
| — | El tramo no cae en feriado nacional | `es_cfersSecgen01` | bloqueo | ✓ |
| PAG-38 | Lo informado en `sg_fuc2` cubre lo comprometido en `sg_fuco` | `sg_fucosSecgen01` + `sg_fuc2sSecgen01` | **bloquea el envío, no el registro** | ✓ |
| ~~PAG-38b~~ | ~~Recompromiso de solo los tramos faltantes~~ | — | **no implementable**: `sg_fuc2` no distingue realizado de recomprometido | — |

### 3.6 Ausencias — exclusivas del pago

| ID | Control | Fuente | Severidad | PA |
| :--- | :--- | :--- | :--- | :---: |
| PAG-33 | Sin licencia médica en el periodo cubierto | `sp_as21` grupo 2 | bloqueo | ✗ |
| PAG-34 | Sin permiso sin goce en el periodo cubierto | `sp_as21` grupo 1 código 2 | bloqueo | ✗ |

Ambas aparecen en `9_catastro...` §12 como *«controles declarados sin fuente integrada»* que se retiraron de la resolución con la nota «deben vivir en Pago, por periodo cubierto». Esta vista es ese lugar.

### 3.7 Transversales

| ID | Control | Severidad |
| :--- | :--- | :--- |
| PAG-70 | Historial: actor, perfil, acción, estado anterior y nuevo, fecha, observación | regla de sistema · ✗ no existe |
| PAG-71 | La evidencia se versiona lógicamente; reemplazar no borra el respaldo anterior | regla de sistema · ✗ |
| PAG-72 | Los antecedentes de la PDS son de solo lectura en todo el flujo | bloqueo de edición |
| PAG-73 | Toda validación monetaria se repite en el PA transaccional | regla de sistema |
| PAG-74 | Ningún código sin entrada de catálogo se muestra como etiqueta | presentación · `sg_ecuo`, `sg_efum` |

**Conteo:** 38 controles. **28 tienen su PA ya cableado** y solo necesitan exponerse al rol DGDP con su propia guardia; 3 se resuelven en el cliente; 7 requieren trabajo nuevo.

---

## 4. Comparar resoluciones y centros de costo del funcionario

**Sí, y el PA ya existe y está cableado:** `sg_fupssSecgen17`, expuesto como `GET /normative/staff-previous-provisions` y consumido por `Du288StaffPreviousProvisionsModal`.

Por cada prestación previa del funcionario entrega, entre otros: solicitud, actividad, periodo y fechas de ejecución, **centro de costo con unidad financiera, ítem presupuestario y fuente de financiamiento**, monto total y mensual, cuotas autorizadas y marca de extensión, tipo de monto, **cargo, contrato, haber de referencia y tope con su fecha de cálculo**, **resolución interna y externa con su año**, estado de la solicitud y etapa actual, y los datos de horario y compensación planificada.

Con eso la vista arma la matriz de concurrencia del mockup 04: una fila por PDS del año, con N° de solicitud, resolución exenta, centro de costo, monto mensual, estado de pago y alerta de concurrencia. Y responde dos preguntas que hoy nadie responde en pantalla:

- **¿este funcionario tiene más de una PDS viva?** → alerta de concurrencia;
- **¿se están imputando a centros de costo distintos?** → comparación de `cod_unifin`/`cod_ccto`/`cod_sitm` entre filas.

**Lo que falta:** el acumulado mensual que exige V8 del diagrama. El catastro no define de dónde sale el consumo mensual del funcionario sumando varias PDS. `sg_fupssSecgen17` entrega el monto mensual de cada una, así que el acumulado es derivable en el cliente — pero conviene cerrarlo como regla antes de pintarlo como semáforo del tope del 50 %.

---

## 5. Resumen de lo que falta construir

**PA nuevos de lectura (3)**

1. Ausencias por periodo, agrupadas por `(tip_agraus, cod_agraus)` con rangos de fecha — para PAG-33 y PAG-34.
2. Detalle de una cuota por su clave, independiente de la bandeja — ya listado en el documento anterior.
3. Vigencia y cierre del proyecto a la fecha de ejecución — PAG-36.

**PA nuevos de escritura (3)**

4. Descuentos del mes: `mto_deslic` y `mto_dessg`.
5. Exclusión de un mes de la cuota.
6. Cierre: `mto_realpa` en `sg_epag` y `sg_fume`, cuota → 8, meses 2 → 3.

**Cableado sin PA nuevo**

7. Desplegar y cablear `sp_as01sSecgen01`.
8. Endpoint de contexto normativo para DGDP que reúna los 28 PA ya existentes, con guardia `provision-payment-read-waiting`.

**Decisiones que faltan**

9. ¿`sp_as21` tiene licencias reales en producción? Define si el descuento es automático o propuesto.
10. Qué hacer con los días **Incompleto** y con los registros duplicados del mismo día.
11. De dónde sale el acumulado mensual del funcionario para el tope del 50 %.
12. Severidad definitiva de PAG-41, hoy «por decidir».

---

## 6. Aplicado el 07-10-2026 — el panel de resolución corriendo en la cuota DGDP

Criterio del usuario: lo que ya está en el flujo de resolución está aprobado y
validado, así que es la base y no se reescribe. Se aplicó tal cual al detalle
de cuota del revisor.

### 6.1 El obstáculo real y cómo se resolvió

El panel ya existía para pagos — `revalidateNormative` en
`store/service-provision-payment-detail.js` — y corre los ocho controles con
los PA de resolución. Lo que impedía reutilizarlo en DGDP no era el panel sino
**de dónde saca su contexto**: la prestación, los horarios y las PDS previas
vienen de endpoints que exigen `assertRequestAccess`, es decir haber
participado en la solicitud, o ser el jefe de proyecto. El revisor DGDP no es
ninguna de las dos cosas.

En vez de abrir cinco guardias se agregó **un endpoint de contexto**:

```
GET /requests/service-provision/payments/dgdp/provisions/{id}/installments/{nro}/context
```

Guardado por `assertIsDgdpPaymentReviewer` y acotado por la propia bandeja: solo
responde por una cuota que el revisor ya puede ver. Devuelve la fila de bandeja,
la prestación del funcionario, sus horarios y sus PDS previas.

### 6.2 Lo único que cambia respecto de resolución

`revalidateNormative` pasó a aceptar tres parámetros opcionales, con el
comportamiento de resolución como omisión:

| Parámetro | Para qué |
| :--- | :--- |
| `previousProvisions` | las PDS previas ya cargadas, en vez de pedirlas al endpoint del jefe de proyecto |
| `previousProvisionsUrl` | el endpoint alternativo, si hiciera falta pedirlas |
| `evaluationDate` | la fecha contra la que se evalúa la habilitación |

`evaluationDate` es **PAG-30**: el solicitante evalúa al inicio de la ejecución,
que es lo que la resolución autorizó; DGDP evalúa al **primer día del mes de
pago**, porque un cargo habilitado al decretar puede no estarlo al pagar. Se ve
en la llamada: `fechaEval=2026-08-01` para una cuota que se paga en agosto.

`Du288PaymentValidationsSection` recibió `title`, `subtitle` y `readyLabel`
opcionales. El veredicto «Lista para enviar» no significa nada para quien visa
una cuota ya enviada; en DGDP dice «Sin observaciones normativas».

### 6.3 Verificado en local

Con la revisora DGDP sobre la cuota 1 de la prestación 8, los ocho controles
respondieron con datos reales: contrato habilitado, cargo habilitado, asignación
habilitada, sin parentesco, tope validado, carga semanal validada, calendario
consultado, y centro de costo sin saldo como advertencia no bloqueante.

### 6.4 Lo que esto no cubre

Los seis controles exclusivos del pago siguen pendientes: PAG-33 y PAG-34
(licencia y sin goce) porque falta el PA de ausencias por periodo; PAG-36
(vigencia del proyecto); PAG-37 (deuda institucional, sin fuente); PAG-40
(ajuste proporcional); y PAG-38 (cobertura de `sg_fuc2` sobre `sg_fuco`), que
necesita la sección de compensación en la vista. La asistencia sigue sin
cablear.

---

## 7. Aplicado el 07-10-2026 — la vista completa del revisor

Se armó el detalle con las secciones del §5 de
[detalle_dgdp_que_se_espera.md](./detalle_dgdp_que_se_espera.md) que no
dependen de un PA nuevo. Seis bloques, en el orden en que se revisa:

| # | Sección | De dónde sale |
| :-- | :--- | :--- |
| 1 | **Antecedentes de la prestación** — 17 datos: funcionario, cargo, estamento, contrato, solicitud, actividad, centro de costo, ítem presupuestario, resolución, período de ejecución, modalidad de jornada, tipo de monto, monto autorizado, tope mensual, cuotas autorizadas, fecha de envío y respaldo | bandeja + `context.staff`; solo lectura por PAG-72 |
| 2 | **Validación presupuestaria** — ítem, solicitado, saldo inicial, remanente, estado y mensaje | `Du288PaymentBudgetSection` con el saldo que deja el panel normativo |
| 3 | **Validaciones normativas** — los ocho controles del flujo de resolución | `revalidateNormative`, evaluado a la fecha de pago |
| 4 | **Meses de la cuota** — mes, estado, solicitado, descuentos, a pagar, **las cuatro marcas de auditoría de V7** y compensaciones, con totales en el encabezado | `sg_epagsSecgen04`, que ya entregaba todo esto y la tabla anterior descartaba |
| 5 | **Otras prestaciones del funcionario** — solicitud, resolución, centro de costo, período, monto mensual y estado, con alertas de cruce de período y de otro centro de costo | `context.previousProvisions` |
| 6 | **Dictamen** — observación con error junto al campo y modal de confirmación con resumen y efecto de cada decisión | `sg_epaguSecgen03` |

Detalles de criterio:

- **`mto_realpa` manda cuando existe.** La columna «A pagar» muestra lo que
  escribió el cierre; mientras la cuota está en trámite viene nulo y se deriva
  como solicitado menos descuentos.
- **El estado de las prestaciones previas sale del catálogo**, no del texto del
  PA: `des_estsol` vuelve de Sybase con la codificación rota y además PAG-74
  exige que ninguna etiqueta se muestre sin entrada de catálogo.
- **Ninguna decisión se ejecuta con un clic.** El modal resume qué se resuelve,
  por cuánto y qué efecto tiene — en particular que observar **no** libera los
  meses y rechazar sí.
- La nota al pie de los meses declara que los descuentos todavía no se pueden
  registrar, en vez de mostrar campos que no guardan nada.

### 7.1 Verificado en local

Cuota 1 de la prestación 8, con la revisora DGDP: las seis secciones con datos
reales; ocho controles normativos resueltos; tres meses con sus montos, marcas
y conteo de compensaciones; y tres prestaciones concurrentes, las tres marcadas
«Otro centro de costo».


### 7.3 Antecedentes y resolución firmada

Se agregó la pestaña **Antecedentes**, con el mismo contenido que las vistas
de solicitud: el detalle decretado —centro de costo, unidad ejecutora, jefe de
proyecto, ítem presupuestario, período, modalidad y horas contratadas, más la
tabla de funcionarios con jerarquía, funciones, monto bruto, período a pagar y
horario— y el **visor de la resolución firmada**.

La vista quedó en dos pestañas, igual que el detalle del solicitante:
**Revisión** con las seis secciones del dictamen y **Antecedentes** con el
documento. Se reutiliza `Du288PaymentAntecedentsTab` sin tocarlo.

Dos cosas hubo que resolver:

- **Las tarjetas de antecedentes** salen de `/detail/{id}/info`, que exige
  `assertRequestAccess`. Se agregaron al endpoint de contexto DGDP, armándolas
  con la misma composición de `getInfoCards`.
- **El archivo decretado** se pide a `/resolution/file/{año}/{número}/2`, que
  solo exige sesión: el revisor lo consulta directo, sin endpoint nuevo. El
  `2` es el correlativo `SIGNED`; el `1` es la versión base.

> **Ojo con el número de resolución.** `MySecGen.sg_rslc_<año>` se escribe con
> el número **interno** (`soli.nro_resolu`), que es lo que pasa la subida del
> documento. El externo (`sg_rslc.num_resolu`, el que se cita en los oficios)
> no existe en esa tabla: consultarlo devuelve 404. La bandeja DGDP entrega
> los dos, así que la ruta tiene que armarse con el interno. El detalle del
> solicitante nunca tropezó con esto porque su modelo de resolución solo
> expone `resolutionId`, que ya es el interno.

De paso, el cálculo de la proporción de la primera página del PDF se sacó del
detalle del solicitante a `utils/services-provision/pdfAspectRatio.js`, que
ahora usan las dos vistas en vez de tenerlo duplicado.

### 7.2 Lo que sigue faltando

Lo que no se puede construir sin base nueva: la sección de compensación
comprometida contra realizada (PAG-38) necesita un PA de lectura con alcance
DGDP, porque `sg_fuc2sSecgen01` filtra por `es_ecct.rut` del jefe de proyecto y
devuelve vacío para el revisor. Y siguen pendientes los descuentos editables,
la asistencia, el visor del respaldo y la bitácora.

---

## 8. Aplicado el 07-10-2026 — sección de jornada y asistencia

Cruza las tres fuentes que acreditan la ejecución, en una tabla por día:

| Fuente | Qué aporta | Origen |
| :--- | :--- | :--- |
| **Comprometido** | los tramos que la resolución fijó | `sg_fuco` vía `sg_fucosSecgen01` |
| **Informado** | lo que el jefe de proyecto registró | `sg_fuc2` vía el PA nuevo `sg_fuc2sSecgen02` |
| **Marca real** | entrada, salida, turno y minutos fuera de turno | `sp_as01` vía `sp_as01sSecgen01` |

Más los días de ejecución proyectados desde `sg_fuho`, que llegan en el
contexto, y las observaciones del día: feriado, ausencia con su motivo,
justificación, comprometido sin informar e informado sin compromiso.

El encabezado resume comprometido, informado, minutos fuera de turno
acreditados y la **cobertura** de lo informado sobre lo comprometido, que es
PAG-38.

### 8.1 Criterios

- **El excedente se mide neto**: minutos marcados menos minutos de turno. Por
  la hora de salida le daría excedente a quien entró tarde y se quedó a
  recuperar.
- **La asistencia es antecedente, no validación.** La sección lo dice al pie:
  acredita que el tiempo existió, no a qué se dedicó. No bloquea la resolución.
- **Cada fuente informa su propio fallo** y no tumba la respuesta: perder una
  de las tres no debe esconder las otras dos ni impedir leer la revisión.
- **Sin registro de asistencia se ocultan las columnas del reloj** en vez de
  escribir «Sin marca» en cada fila, que insinuaría que la persona no marcó.
  Por lo mismo, la cobertura no se muestra cuando lo informado no se pudo
  consultar: un 0 % sería una cifra falsa.
- Fuera de jornada la sección lo declara y queda como contexto de ejecución,
  porque esa prestación no compensa.

### 8.2 PA nuevo

`sg_fuc2sSecgen02` — compensación realizada de los meses de una cuota, con
alcance DGDP. Existía `sg_fuc2sSecgen01`, pero filtra por `es_ecct.rut` del
responsable del centro de costo dentro de su propio `where`: para el revisor no
falla, devuelve cero filas. El nuevo valida la asignación en `sp_orde` 696 y
acota por `sg_dpag` a los meses de la cuota.

También se generó el `.txt` de certificación de `sp_as01sSecgen01`, que no lo
tenía.

### 8.3 Estado verificado

Con los dos PA sin aplicar todavía, la sección se comporta como debe: entrega
los 4 días comprometidos con sus tramos y 25 h totales, declara en rojo que no
pudo consultar lo informado, oculta las columnas del reloj con el aviso de que
la fuente no está disponible, y marca cada día como «Comprometido y no
informado». Al desplegar `sg_fuc2sSecgen02` y `sp_as01sSecgen01` la tabla se
completa sin más cambios de código.

---

## 9. Pasada visual del 07-10-2026

Ajustes contra `estandar_visual/estandar_visual_obligatorio_du288.md`, tomando
como referencia las pantallas de solicitud y el detalle de pago del solicitante.

| § | Hallazgo | Corrección |
| :--- | :--- | :--- |
| 6.2 | Los antecedentes usaban una rejilla propia de `dt`/`dd` | Pasan a `.pds-ui-read-field`, `.pds-ui-read-label` y `.pds-ui-read-value` |
| 6.2 | Valores ausentes con guion suelto | Usan el texto único del catálogo |
| 7 | Los botones de dictamen medían 31 px | `pds-ui-action-button`: 40 px, radio y ancho mínimo comunes |
| 8.1 | Chips de 27 caracteres en la tabla de jornada | «No informado» y «Sin compromiso», con la explicación en el `title` |
| 11 | El modal usaba el pie por defecto de BootstrapVue | Pie propio: cancelar `outline-secondary` a la izquierda, acción con spinner, `pds-ui-modal`, sin cerrar con `Esc` mientras guarda |
| 13 | La bandeja dejaba 15 px de scroll horizontal a 375 px | El encabezado deja de usar `.row`, cuyos márgenes negativos sacaban el contenido del contenedor |
| 13 | Tres botones de 132 px mínimos no caben en 375 px | En móvil pasan a ancho completo y en columna |
| 15 | «Hace 1 días» | Concordancia singular/plural |

Verificado a 375 px: sin scroll horizontal de página en ninguna de las dos
pantallas, las cuatro tablas con scroll interno controlado, la rejilla de
antecedentes en una columna y los botones de dictamen a 40 px de alto y ancho
completo.

### 9.1 Nota de entorno

`sg_epagsSecgen03` ya está aplicado: la bandeja muestra antigüedad, «Cuota 1 de
2», alertas de compensación y respaldo, y el monto con descuentos. Siguen sin
aplicar `sg_fuc2sSecgen02` y `sp_as01sSecgen01`, que son los de la sección de
jornada.

### 9.2 Desvío registrado, no corregido

El §6.2 pide «Sin información» o «No aplica» para el valor ausente; el catálogo
del proyecto usa «No informado» y lo comparten todas las pantallas. Se mantuvo
la convención del proyecto en vez de introducir un tercer literal solo en esta
vista.

---

## 10. Sección de ejecución y calendario · 07-10-2026

Agregada al detalle DGDP, antes de la sección de jornada. Tres bloques:

1. **Semana de ejecución** — una fila por día de la semana con sus tramos y
   horas, y el total semanal. Sale de `sg_fuho`, que es recurrente: define días
   de la semana, no fechas.
2. **Feriados dentro del período** — fecha, día, nombre del feriado, horas
   comprometidas ese día y el estado «No consideradas», con el total restado
   en el encabezado. Solo se listan los feriados que **efectivamente restan
   horas**; el resto se resume en una línea, porque un receso completo son
   decenas de fechas y listarlas con un guion esconde las que sí cambian el
   total.
3. **Calendario del período** — mes a mes, con navegación acotada al rango y un
   color por fuente: ejecución comprometida, compensación comprometida,
   compensación informada, feriado y día con marca. El feriado manda sobre el
   resto porque ese día no se ejecuta ni se compensa. Leyenda nombrada, porque
   el §14 no permite que el color sea el único indicador.

Los feriados salen de `es_cfersSecgen01` vía `/normative/institutional-calendar`,
la misma fuente que ya consultaba el panel normativo, que hasta ahora solo
contaba cuántas fechas había.

### 10.1 TODO de pruebas — RUT de asistencia sustituido

`ATTENDANCE_TEST_RUT = '06706447K'` en
`service-provision-payment-procedures.repository.ts`. Mientras esté definido,
la consulta de asistencia usa ese RUT en lugar del funcionario revisado, porque
es el único con marcas cargadas en el ambiente.

**Para retirarlo basta dejar la constante vacía**; no hay otro punto que tocar.
La respuesta expone `attendanceTestRut` y la sección de jornada pinta un aviso
en amarillo diciendo que esas marcas no son del funcionario de la cuota, para
que nadie las lea como reales.

---

## 11. Rediseño de la vista · 07-10-2026

El problema no era qué faltaba sino el orden y la fragmentación: **tres bloques
distintos hablaban de los mismos días** —semana de ejecución, feriados,
calendario— y un cuarto, la tabla de jornada, repetía la comparación en otra
forma. El revisor tenía que reconstruir mentalmente el cruce.

### 11.1 Orden nuevo, por lo que decide

| # | Sección | Por qué ahí |
| :-- | :--- | :--- |
| 1 | Validaciones normativas | Es lo primero que puede bloquear la aprobación |
| 2 | Meses y montos | Lo que se paga, con los descuentos editables |
| 3 | Jornada y ejecución | El cumplimiento de la compensación (PAG-38) |
| 4 | Otras prestaciones | Concurrencia y doble pago |
| 5 | Dictamen | La decisión, después de haber visto lo anterior |
| 6 | Validación presupuestaria | Contexto |
| 7 | Antecedentes de la prestación | Contexto, solo lectura |

Antes la pantalla abría con 17 campos de antecedentes y el saldo; ahora abre
con lo que decide y el contexto queda abajo, disponible sin estorbar.

### 11.2 Una sola sección de tiempo, con calendario interactivo

Las cuatro vistas del tiempo se fundieron en una:

- **Encabezado con el veredicto**: comprometido, informado, cobertura, total
  semanal y horas no consideradas por feriado.
- **Semana de ejecución** y **feriados que restan horas**, como tablas de apoyo.
- **Calendario del mes**, que ahora es la forma de navegar: cada día es un
  botón con un color por fuente —ejecución comprometida, compensación
  comprometida, compensación informada, feriado, día con marca— y al elegirlo
  se despliega abajo **el detalle de ese día** con las tres fuentes juntas.

La tabla día a día desapareció: el calendario cubre lo mismo sin obligar a leer
filas de «Sin compromiso». La selección usa el patrón de foco del §5.4 —borde y
resplandor, sin relleno— para no competir con los colores de las fuentes.

Ejemplo del cruce que antes había que armar a mano: el 13/01/2016 muestra
«Compensación comprometida 17:18–23:59 · 6 h 41 min» contra «Compensación
informada 17:18–18:18 · 1 h».

### 11.3 Descuentos editables

La columna «Descuentos» pasó a dos campos por mes —licencia médica y permiso
sin goce— con recálculo en vivo de «A pagar» y de los totales, validación de
que no superen lo solicitado, y un botón de guardar que solo se habilita si
algo cambió. Solo se editan mientras la cuota está en visación.

**PA nuevo:** `sg_fumeuSecgen03`. Valida el alcance DGDP, que la cuota siga en
estado 2 y que los descuentos no superen `mto_apagar`; escribe `mto_deslic`,
`mto_dessg`, deriva `val_licmed`/`val_singoce`, deja `mto_realpa` resuelto y
sella `fec_valida`, todo en una transacción. Endpoint
`PUT .../dgdp/provisions/{id}/months/{corr}/deductions`, con el permiso de
**resolución** y no el de lectura, porque cambia lo que se pagará.

### 11.4 Pendiente de despliegue

`sg_fumeuSecgen03`, `sp_as01sSecgen01` y el reinicio del backend para que tome
el RUT de asistencia de prueba.

---

## 12. Calendario por capas · 07-10-2026

Ajuste pedido: el calendario debe venir **primero** y permitir ver los cruces,
con cada fuente por separado.

### 12.1 Cuatro capas, no un color fundido

Cada día del calendario muestra **una marca por fuente**, una al lado de la
otra, en este orden:

1. **Ejecución comprometida** — el día de la semana que fija `sg_fuho`. No se
   pinta cuando ese día es feriado: ese día no se ejecuta.
2. **Compensación comprometida** — `sg_fuco`.
3. **Compensación informada** — `sg_fuc2`.
4. **Marca de reloj control** — `sp_as01`.

El feriado no es una marca sino el fondo del día, porque es una condición de la
fecha y no una actividad. Antes las cuatro condiciones se fundían en un color
por celda, de modo que un día con compromiso **y** con compensación informada
se veía igual que uno con solo una de las dos: justo el cruce que había que
observar quedaba escondido.

Al elegir un día se despliega su detalle con las fuentes que aplican, con horas
y tramos.

### 12.2 Lo que viene después del calendario

- **Semana de ejecución**: son tres atributos, así que pasó de tabla a una fila
  de chips con el total y las horas no consideradas.
- **Feriados del período**: es solo información de apoyo, así que salió del
  flujo y quedó en un modal de desglose, accesible desde el encabezado del
  calendario.
- **Resumen por mes**: la tabla que sí se compara. Por cada mes entrega
  comprometido, informado, la diferencia que falta por explicar, los días con
  marca y los minutos fuera de turno acreditados.

### 12.3 Verificación

El componente quedó bien formado y ESLint y las 12 suites pasan. La
comprobación visual de esta última pasada quedó incompleta: el panel del
navegador dejó de responder. Lo verificado antes de ese punto —orden de
secciones, campos de descuento, calendario interactivo y detalle del día— sigue
siendo válido, pero las cuatro capas, la semana compacta, el modal de feriados
y el resumen por mes no se vieron renderizados.

### 12.4 Corrección: las capas eran ilegibles

Los puntos de 7 px no permitían distinguir qué ocurrió cada día: el color era
el único indicador y la ausencia no se veía en absoluto. Se reemplazaron por
**tres iniciales dentro de la celda** — `C` comprometido, `I` informado, `B`
biométrico — donde lo que **no** ocurrió también se muestra, en gris. Así un
día comprometido e informado pero sin marca se lee de inmediato.

La ejecución comprometida pasó a ser el fondo de la celda, como el feriado:
ambas son condiciones de la fecha, no actividades que se marquen.

En el resumen por mes, «Días con marca» dejó de ser un conteo y pasó a
enumerar **qué días** se marcó biométricamente. Un número no permitía
compararlos con los días comprometidos, que es la pregunta real.

Verificado: `13: C+ I+ B·` — comprometido e informado, sin marca biométrica.
Las `B` aparecen todas apagadas porque `sp_as01sSecgen01` sigue sin aplicarse.

---

## 13. La asistencia ya entrega datos · 07-10-2026

### 13.1 El RUT se estaba truncando

La consulta volvía vacía sin error. La causa: `normalizeRut` elimina todo lo
que no sea dígito, de modo que `06706447K` llegaba al PA como `006706447`, que
no existe. `sp_pers.rut_person` guarda el **dígito verificador dentro de los 9
caracteres**, así que un RUT terminado en K se pierde.

Se agregó `normalizeRutWithCheckDigit`, que conserva la K. `normalizeRut` sigue
sirviendo para los PA de pago, donde el parámetro es el RUT numérico del
responsable del centro de costo. Por eso el problema no se había visto: los
RUT de los revisores de prueba terminan en dígito.

Con el arreglo llegan **182 días, 103 con marca**, y el excedente calcula bien:
el 08/01/2016 marcó 573 minutos contra 530 de turno, es decir 43 minutos fuera
de turno con salida a las 18:05.

### 13.2 Tres estados, no dos

Los datos reales traen `cod_estasi` con tres valores: `Completo` (entrada y
salida), `Incompleto` (una sola marca) y `Estado inicial` (sin marcas). Antes
la vista solo distinguía «marcó» de «no marcó» usando `min_marcados`, que viene
vacío cuando falta una marca: los días incompletos se veían como si la persona
no hubiera ido.

Ahora son tres:

| Marca | Significado |
| :--- | :--- |
| `B` relleno | Marca completa: acredita presencia y permite medir tiempo |
| `B` con borde | Marca incompleta: acredita presencia, no permite medir tiempo |
| `B` en gris | Sin marca |

Esto cierra la condición 4 de `cruce_con_nuestra_bdd.md` —«definir qué hacer
con los días Incompletos»— con una decisión visible: se muestran como presencia
parcial y **no suman excedente**.

El detalle del día informa el estado y, cuando la marca es parcial, explica por
qué no se puede medir el tiempo.

### 13.3 Lectura del calendario, con datos reales

```
 4: C· I· B~    marca incompleta, sin compromiso ni informe
 5: C· I+ B+    informado y marcado, sin compromiso
13: C+ I+ B+    comprometido, informado y marcado
```

Y el resumen por mes ya enumera los días efectivamente marcados:
`Enero 2016 · 5, 8, 11, 12, 13, 14, 15, 18, 19, 20, 21 · 2 h 42 min fuera de turno`.

### 13.4 Corrección de un dato engañoso

Los meses fuera de la cuota mostraban «Cubierto» con 0 minutos comprometidos.
No hay nada que cubrir: ahora dicen «Sin compromiso».

---

## 14. Sin porcentajes de cumplimiento · 08-10-2026

Corrección de criterio pedida por el usuario: **no se puede afirmar que la
prestación se ejecutó**. Ni la declaración del jefe de proyecto ni el reloj
control lo acreditan, así que la vista no debe dar porcentajes ni veredictos.

| Antes | Ahora |
| :--- | :--- |
| Chip «Cobertura 100 %» | Comprometido y Informado en horas; si falta, «Falta informar N h» |
| «Cumplimiento jornada 100 %» en el encabezado | «Comprometido 25 h» y «Informado 25 h», separados |
| Chip verde «Cubierto» por mes | «Sin diferencia», en texto neutral |

El reloj control se describe como lo que es: «acredita que hubo tiempo, no a
qué se dedicó. Es un antecedente para ponderar, no una prueba de que la
prestación se ejecutó».

### 14.1 El biométrico solo donde se evalúa

La marca `B` aparece únicamente en días con **ejecución comprometida, o
compensación comprometida o informada**. En un día sin nada que contrastar el
reloj no dice nada de la prestación, y su marca era ruido. El resumen por mes
aplica el mismo criterio.

### 14.2 Antecedentes de contrato

Siguiendo la solicitud de resolución, el bloque de antecedentes agrega
vigencia, calidad jurídica, jornada contractual, horas de contrato, unidad y
fecha de inicio del contrato. El revisor necesita saber bajo qué vínculo se
ejecuta la prestación.

### 14.3 Ejecución comprometida, explicada una vez

Pasó de una fila de cifras sueltas a un bloque con una línea de ayuda —«Días y
horas que la resolución fijó para esta prestación. Se repiten cada semana del
período»— y los días como chips, con el total y lo que resta por feriado en una
sola línea.

### 14.4 Pendiente

La jornada institucional fija de 08:30–17:18 sigue usada como referencia en las
reglas de compensación, pero el turno real varía por persona y por día y llega
en el propio registro de asistencia (`hora_turno_ent`/`hora_turno_sal`). El
detalle del día ya muestra el turno real; las reglas que asumen el horario fijo
quedan por revisar.

---

## 15. Catastro aplicado a la vista · 08-10-2026

Contraste del catastro contra el código, y correcciones de **pertinencia**: no
basta con que la consulta exista, tiene que evaluarse en el período correcto y
con la severidad que el pago exige.

### 15.1 Tres defectos de pertinencia corregidos

**1. Alcance temporal.** El panel evaluaba contra el período completo de la
prestación. Las reglas de pago deben mirar **los meses que cubre la cuota**:
eso es lo que se está pagando. `revalidateNormative` recibe ahora `periodFrom`
y `periodTo`; la vista DGDP pasa del primer día del mes más antiguo al último
del más reciente entre los meses de la cuota. Sin esos parámetros mantiene el
comportamiento del solicitante.

**2. PAG-32, constancia de parentesco.** La resolución difiere la constancia al
pago (RES-IN-07 es informativa **porque** se difiere). La vista la mostraba
como advertencia no bloqueante, de modo que no se exigía en ninguna parte del
flujo. Con `requireRelationshipCertificate`, en DGDP un parentesco que exige
constancia queda como **error bloqueante**.

**3. Aprobar no revalidaba.** El panel se podía refrescar a mano, pero aprobar
no forzaba consulta fresca ni miraba el resultado. Ahora aprobar vuelve a
consultar el panel y se detiene si hay controles bloqueantes o pendientes,
nombrándolos. Observar y rechazar no lo exigen: son salidas negativas y un
control bloqueante suele ser justamente el motivo.

### 15.2 Estado real por grupo

| Grupo | Estado |
| :--- | :--- |
| Contrato y cargo | ✓ consultado y revalidado a la fecha de pago. PAG-41 sigue como advertencia; su severidad está sin decidir |
| Asignaciones | ✓ ahora evaluadas con el período de la cuota |
| Parentesco | ✓ bloquea cuando exige constancia. **Falta** adjuntar y ver esa constancia |
| Tope y monto | ◐ el tope se controla. De los cuatro saldos, el presupuestario llega como advertencia no bloqueante |
| Carga horaria y PDS previas | ✓ consultadas, con alerta de concurrencia |
| Compensación | ✓ comprometido contra informado, por día y por mes. Depende de `sg_fuc2sSecgen02` |
| Ausencias | ✗ PAG-33 y PAG-34 sin fuente. Se **registra** el descuento, no se **detecta** la ausencia |
| Proyecto y deuda | ✗ PAG-36 y PAG-37 sin fuente |
| Formación continua y evidencia | ✗ la cuota guarda `id_evidenc`, pero no hay visor del PDF |
| Calendario | ✓ feriados en el calendario y descontados de las horas comprometidas |

### 15.3 Lo que sigue abierto, por orden de impacto

1. **Saldo presupuestario bloqueante.** En resolución el saldo está apagado y
   acá llega como advertencia. En el pago es la plata que se gira: debe decidirse
   si bloquea la aprobación.
2. **Visor del respaldo de la cuota.** Bloqueado por dónde vive el binario en
   MySQL.
3. **Ausencias automáticas.** Requiere el PA de `sp_as21` por período.
4. **Auditoría del dictamen.** `sg_epaguSecgen03` no persiste motivo, RUT ni
   fecha.
5. **RUT de asistencia de prueba.** `ATTENDANCE_TEST_RUT` sigue activo y debe
   retirarse antes de usar la asistencia como antecedente real.

---

## 16. Decisiones del 08-10-2026

### 16.1 El saldo del centro de costo bloquea

Decidido por el usuario. `revalidateNormative` recibe `balanceBlocks`; la
visación DGDP lo pasa en `true` y el control queda como **error bloqueante**.
El borrador del solicitante conserva la advertencia, porque ahí todavía no se
gira nada.

### 16.2 Ausencias desde la propia asistencia

`sp_as01sSecgen01` ya consultaba `sp_as21`, pero devolvía el motivo usando
`res_ausen` —truncado a 15 caracteres por el catálogo— y sin el grupo, de modo
que no se podía distinguir una licencia de un permiso.

Se corrigió:

- el motivo sale de **`des_ausen`**, completo;
- se arrastran `tip_agraus`/`cod_agraus` y se derivan dos banderas por día:
  **`tie_licmed`** (grupo 2, licencias médicas) y **`tie_singoce`**
  (grupo 1 código 2, permiso sin goce).

Con eso la vista gana un apartado **Ausencias en el período**, que agrupa los
días en tramos consecutivos del mismo tipo y muestra desde, hasta, días, tipo y
motivo, con el total de días con licencia y sin goce. Es la base de los
descuentos que el revisor ingresa en el bloque de meses.

Sin registro de asistencia la sección **no afirma que no hubo ausencias**: dice
que no se pudo saber, que es distinto.

Esto no cierra PAG-33 y PAG-34 por sí solo —siguen siendo controles que deben
bloquear, no solo informar— pero elimina la parte que faltaba: la fuente.

### 16.3 La auditoría del dictamen no necesita tabla nueva

`diagrama_bdd/diagrama_pagos_actualizada.md` §8.3 ya lo resuelve: **`sg_apso`
tiene la forma exacta** — `nro_solici`, `id_funprse` anulable, `comentario`,
`rut_usua`, `cod_estapr`, `f_aprobac` y el par `cod_flusol`/`cod_etapa`. Solo
necesita un `cod_flusol` propio del flujo de pagos.

Queda sin efecto lo que decía este documento sobre persistir la observación con
una extensión de esquema: `05_auditoria_revision_dgdp.sql` deja de ser el
camino. El trabajo es registrar la decisión en `sg_apso` al resolver, y leer
desde ahí el historial que pide PP02-F02.
