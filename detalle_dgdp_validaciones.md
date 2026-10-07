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
