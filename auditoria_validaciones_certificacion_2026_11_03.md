# Auditoría de validaciones y desarrollo — WF pagos y WF resolución

**Fecha:** 03-11-2026
**Objetivo:** determinar, antes del pase a certificación, si las validaciones —el
núcleo de la aplicación— se cumplen y están bien aplicadas en los dos flujos;
qué falta, qué sobra y qué datos lo condicionan; y si el desarrollo sigue los
estándares esperados.
**Tipo:** auditoría de solo lectura. No se modificó código, PA ni datos.

**Vara de medida** (en este orden de autoridad):

1. `requerimientos_wf/8_matriz_validaciones_resolucion_a_pago.md` — matriz oficial.
2. `impacto_cambios/impacto_19_estado_validaciones_pago.md` §9–§15 — decisiones
   del 14-10-2026 y la lista final de 9 validaciones de pago (§11.7).
3. `impacto_cambios/impacto_30` (corte 30-10) e `impacto_31` (02-11).
4. `checklist_validaciones_y_paso_a_certificacion.md` e `INTERRUPTOR-DU09.md`.
5. `template-du09/.../contexto_reglas_cambios_agregados/06`, `07`, `09` — reglas
   de resolución.
6. Skill `ufro-typescript-fullstack` y `estandar_visual_obligatorio_du288.md`.

El catastro de validaciones desactivadas entregado para esta revisión se
contrastó punto por punto contra el código: la §1 lo corrige donde no calza.

---

## 0. Resumen ejecutivo

### 🔴 Bloquean la certificación

| # | Hallazgo | Dónde |
|:-:|:--|:--|
| 1 | **La aprobación DGDP no tiene compuerta normativa.** El endpoint de decisión solo verifica el permiso, y `sg_epaguSecgen03` solo verifica actor, estado 2 y motivo. Una llamada directa aprueba una cuota sin saldo, con el centro de costo cerrado o sin tope. Las validaciones de la aprobación existen únicamente en el navegador. El checklist propio lo registra como Paso 8; el catastro entregado lo omite. | `service-provision-payment.controller.ts:206-236` · `sg_epaguSecgen03.sql` |
| 2 | **El `dist/` local publica 40 RUT reales.** `SIMULATION_USERS` está poblado en `.env` (41 usuarios) y el build del 30-10-2026 se hizo con `NODE_ENV` distinto de `production`, así que el guard de `pages/access/index.vue:371` no eliminó la rama: 40 de los 41 identificadores están horneados en `dist/_nuxt/46b704c.js` y `e1d6488.js`. Si ese `dist` es el artefacto que se sube, cualquier navegador los lee. | `.env` · `dist/_nuxt/` te respondo aqui segun lo esperado el acces y todo lo que tiene que ver con falsear el login para probar desde el .env se debe eliminar al pasar a prod por lo cual se debe quitar toda esta funcionalidad tanto en el front como en el backend revismosy analizamos adetalle solo todo lo que tiene que ver con /sg-solicitudes/access |
| 3 | **`DISABLE_AUTH=false` no protege nada.** El catastro dice «fijarlo en false», pero la cadena `"false"` es verdadera en JS (el propio `nuxt.config.js:58-61` lo advierte). La única protección es `NODE_ENV=production`; un ambiente de certificación con otro `NODE_ENV` y la variable presente queda **sin `auth` ni `guardian`**. | `nuxt.config.js:62` R: aqui respecto a esto gtiene que ver con falsear tambien lo que es el login por lo cual se debe ajustar para no tener problemas. esto es mas que nada una configuracion para el ambiente de prueba. por lo cual se espera no tutlizar en certificacion.|
| 4 | **La versión de `sg_usacsSecgen01` del repo de release no tiene el rol revisor de pagos.** 137 líneas y 0 menciones de `es_revisor_pago`, contra 168 y 2 en el paquete de pagos. Desplegada desde release, el login funciona y la bandeja DGDP aparece vacía sin error. | `sissolic-procedimientos/sg_usacsSecgen01.txt`  R: respecto a esto espero acutalizar por mi cueta cada uno de  los procedimientos que estan en esta cartpeta por lo cual no hacer nada por el moemnto.|
| 5 | **37 PA que invoca el backend viven solo en el paquete de pagos** (el impacto 27 contaba 32). Un despliegue desde `sissolic-procedimientos/` no los instala. | `cambios_pa/` R: lo mismo apra esto ahsta el momento se dejan o se trabaja solo con cambios_pa y el otro repo no se toca lo hare manual. |

### 🟠 Corregir antes de producción

| # | Hallazgo |
|:-:|:--|
| 6 | Si no se encuentra el perfil del contrato, la compuerta de envío **omite en silencio** la revalidación de cargo y asignaciones (`controller.ts:985`, `if (profile)`). La matriz marca `VALIDACION_CARGO_PENDIENTE` como «mantener el bloqueo: no se paga sobre una habilitación no confirmada». | se debe activar para que funcione correcamnte.
| 7 | Cuatro de las nueve validaciones de pago acordadas el 14-10 siguen sin implementar (§3). identifica cuales son las validaciones que faltan |
| 8 | El rechazo del envío (422) sigue llegando como **toast que se desvanece** (`_nroSolici/index.vue:972`), el defecto que el impacto 19 §7 pidió corregir. | ajustamos.
| 9 | **37 mensajes de error devuelven el RUT en claro** al cliente (`El funcionario con RUT ${rut}…`), contra la regla del skill de enmascarar identificadores. | que me recomiendas en este apartado ? 
| 10 | Dos `console.log` de depuración imprimen el RUT y los datos del usuario en el log del servidor, en el camino de autenticación (`user-permissions.repository.ts:302` y `:310`). |qutiamops estos log para no imprimir datos criticos.
| 11 | El Excel de Finanzas se descarga aunque haya dos cuotas de la misma prestación y mes, o campos vacíos: solo se valida cantidad (`finance/index.vue:496-498`). | esta bien la idea es guardar lo mismo que se meustra en la tabla segun estandares y filtros ingresados.
| 12 | Backend de resolución más restrictivo que el frontend: el cupo anual no filtra por centro de costo (`getCommittedInstallmentMonthsForYear`, `:462`). Gap documentado en ADR-020, sigue abierto. | esto no se aplica o si pero ten en cuenta que anual tambien requeire pagos desfasados y otras circunstancias si no se tiene claridad no se aplica. o si es un documento antiguo verifiacar. por que dicha descripcion puede no estar acorde a lo ya desarrolado. 

### Lo que sí está bien

- Backend: `npm run build` limpio y **288 pruebas unitarias en verde, 0 fallando**. Las dos fallas de `sg_com1` que el checklist registraba el 29-10 ya no existen.
- Frontend: 23 archivos de prueba en verde, estándar visual validado en 55 archivos, ESLint limpio en todo `services-provision`, stores y utils DU288.
- Ninguna vista de `services-provision` llama HTTP directo: todo pasa por Vuex.
- Los archivos de pagos (`service-provision-payment.controller.ts` y su repositorio) tienen **0 usos de `any`**.
- Los PA de cuota rechazan bien lo estructural: CC cerrado, mes repetido, mes ya asignado, cuota final anticipada, evidencia, saldo autorizado, máximo de cuotas. Los pares `.sql`/`.txt` revisados son idénticos.
- Resolución revalida en servidor al guardar: período, contrato, monto autorizado, inhabilidad de contrato, asignaciones y carga horaria.

---

## 1. El catastro entregado, verificado punto por punto

### 1.1 Interruptores
respecto a esto debemos tener plemenamente idnetificado los codigios y calidacdicones trampa que se agregaron apra rpobar el sistema ya que se deben quitar del codigo y adecuar para que funcione correcamnte como por ejemplo valciones o vraibles que modifcan tood el flujo para apsar sin vertifiacion.  idnentifvica claro tanto PA, backecn y fron donde se aplcian y lo que se debe cambiar end to end a detalle.
| # | El catastro dice | En el código | Veredicto |
|:-:|:--|:--|:--|
| 1 | `BALANCE_VALIDATION_BLOCKS_SUBMISSION = false` | `store/service-provision-payment-detail.js:23`, `false`. Lo consumen **dos** pantallas: envío del solicitante (`_nroSolici/index.vue:193`) y aprobación DGDP (`_installmentNumber.vue:128`, `:1568`). | ✅ correcto |
| 2 | `BALANCE_BLOCKS_SUBMISSION = false` | `controller.ts:66` (el checklist dice L57). Solo protege el **envío**: no cubre la aprobación (hallazgo 1). | ✅ correcto; línea desactualizada |
| 3 | Guarda `afec_du9` comentada en `sg_epagiSecgen01` L120-127 | L120-127, comentada. `.txt` idéntico. | ✅ correcto |
| 4 | Ídem `sg_epaguSecgen01` L129-136 | L129-136. `.txt` idéntico. | ✅ correcto |
| 5 | Ídem `sg_epaguSecgen02` L104-111 | L104-111. `.txt` idéntico. | ✅ correcto |
| 6 | `sg_cctosSecgen05` filtra por `cod_tfinan in (21, 44)` | L66-68 y L89-91, los dos pares. | ✅ correcto |
| 7 | `ATTENDANCE_TEST_RUT = ''` | `payment-procedures.repository.ts:122` (el checklist dice L84), vacío. | ✅ correcto; línea desactualizada |
| 8 | `DISABLE_AUTH` false en producción | **Insuficiente**: ver hallazgo 3. Lo que hay que exigir es `NODE_ENV=production` en el build y la ausencia de la variable. | ❌ la indicación no protege |

> El punto 6 modifica `sg_cctosSecgen05`, que es el PA que lista centros de
> costo para el **formulario de resolución** (`enabled-cost-center.ts:7`).
> Encender el interruptor cambia también qué centros ve el solicitante de una
> resolución. Es coherente con el criterio DU09, pero hay que probarlo en los
> dos flujos, no solo en pagos.

### 1.2 Validaciones relajadas del formulario de resolución

| El catastro dice | En el código | Veredicto |
|:--|:--|:--|
| Sin contratos vigentes: toast y permite continuar | `PdsDu288RequestForm.vue:5019-5022`. Y el backend no lo compensa: `validateStaffContractValidity` (`request-procedures.repository.ts:2908`) **sale sin error si no hay fecha de inicio de contrato**, de modo que un funcionario sin contrato pasa también en servidor. | ✅ correcto, y más grave de lo descrito |
| Cobertura de fechas del contrato deshabilitada | **Inexacto.** Lo deshabilitado es solo la alerta sobre el contrato **persistido** al rehidratar una fila (`:5816-5818`). La validación en vivo `CONTRATO_NO_CUBRE_MESES` **está activa** (`:6378-6390`) y el backend también la aplica al guardar (`:2897-2915`). | ⚠️ corregir el catastro |
| `getCostCenterBalance` con TODO de permisos | Sin cambios respecto de lo descrito. | ✅ correcto |

### 1.3 Scripts de base de datos

| El catastro dice | En el repositorio | Veredicto |
|:--|:--|:--|
| `01_sg_ecuo.sql` elimina 5, 7, 9, **11**, 12 | Elimina **5, 6, 7, 9, 12** y conserva 1, 2, 3, 4, 8, 10, **11** (`01_sg_ecuo.sql:82-109`). El checklist repite el error y además dice que conserva el 6. | ❌ catastro y checklist erróneos |
| `05_sg_tacc` registra acciones 32 y 33 | Registra **32, 33 y 34** (34 = reabrir cuota aprobada). | ⚠️ incompleto |
| — | **`04_roles_privilegios_pagos.sql`** (rol 33 `PAGO_DGDP`) no figura en el catastro. Sin él, DGDP no tiene privilegios. | ❌ omitido |
| — | **`07_sg_ecuo_descripciones.sql`** no figura en ningún documento de pase. Desde el 02-11 la pantalla muestra `des_estcuo` directo de la base (impacto 31): sin este script, una base existente muestra los nombres antiguos de los estados. | ❌ omitido |
| `sp_as01sSecgen01` por compilar y cablear | Sin cambio verificable sin acceso a ASE. | — |
respecto a bdd de o cambios lo utlimo desarrollado es lo que se debe aplciar ya sea para estados u tablas estrucutrales y base. revismso  
### 1.4 Limpieza

| El catastro dice | Estado real |
|:--|:--|
| Eliminar `d:\trabajo_ufro_2026\components` | **Ya no existe.** Ítem cerrado. |
| Revisar `SIMULATION_USERS` | Ver hallazgo 2: el problema no es solo el `.env`, es el `dist/` ya construido. |
| Correr `limpia_datos_pds_desarrollo.sql` | Existe en `nuevo_workflow_fase_2/` (el catastro no indica la ruta). |

### 1.5 Validaciones normativas pendientes

Las seis del catastro (deuda, cierre de proyecto, formación continua, licencias,
constancia de parentesco, receso) están descritas con el estado que tenían
antes del 14-10. Varias tienen una **decisión posterior** que el catastro no
recoge:

| Validación | Decisión vigente (impacto 19) | Estado en código |
|:--|:--|:--|
| Deuda institucional | §9.1: no validable por falta de fuente; chip «Sin información» no bloqueante | ✅ implementada así (`payment-detail.js:369`) |
| Cierre de proyecto (`val_ciecc`) | §9.2: absorbida por «centro de costo cerrado» | ✅ CC cerrado bloquea en los 3 PA. `val_ciecc` sigue siendo columna sin escritor |
| Formación continua | §9.4: absorbida por `afec_du9` | depende del interruptor apagado |
| Licencias y sin goce | §11.2: **no bloquean**, se descuentan; el neto puede quedar en 0 | ✅ coherente; el descuento manual es lo esperado |
| Receso | §11.4: **fuera**, no se implementa | ✅ no debe figurar como pendiente |
| Constancia de parentesco | no reabierta | ❌ sigue sin bloqueo en servidor |

---

## 2. Lo que el catastro no menciona

1. **Aprobación DGDP sin compuerta** (hallazgo 1). El propio checklist lo pone
   como último paso antes de certificar. Hay que decidir **qué validaciones
   aplican al aprobar** —no son las mismas que al enviar: el controlador
   establece que un contrato no vigente no debe bloquear cuotas devengadas— y
   llevarlas al endpoint de decisión. Mínimo razonable: centro de costo
   vigente, saldo (con el interruptor) y estado de la evidencia.
2. **Habilitación omitida sin perfil** (hallazgo 6).
3. **`SIMULATION_USERS` dentro del bundle** (hallazgo 2).
4. **`DISABLE_AUTH` mal especificado** (hallazgo 3).
5. **`sg_usacsSecgen01` y los 37 PA** (hallazgos 4 y 5).
6. **Scripts 04 y 07** (§1.3).
7. **Excel sin bloqueo** (hallazgo 11).
8. **Logs con RUT en autenticación** (hallazgo 10).

---

## 3. WF pagos — las nueve validaciones acordadas (impacto 19 §11.7)

| # | Validación | Severidad acordada | Estado |
|:-:|:--|:--|:--|
| 1 | Centro de costo cerrado | bloquea, 3 PA | ✅ implementada (`vig_ccto <> '1'`) en `sg_epagiSecgen01`, `u01`, `u02` |
| 2 | Centro de costo fuera de DU09 | bloquea, 3 PA | 🟡 escrita y comentada por el interruptor |
| 3 | Flujo de pago configurado | bloquea, compuerta | ❌ **no implementada** en ninguna capa |
| 4 | Tope por cuota | bloquea, 3 PA | 🟡 solo en la compuerta API (`controller.ts:1071-1100`), **no en PA-TX** |
| 5 | Contrato cubre los meses de la cuota | bloquea, `u02` | ❌ **no implementada** |
| 6 | Cuota que cruza el año calendario | bloquea, `i01`/`u01` | ✅ cubierta estructuralmente: resolución ya prohíbe que la prestación cruce de año (`request-procedures.repository.ts:2802`), así que sus meses no pueden hacerlo |
| 7 | Asignaciones sobre el período cubierto | bloquea, compuerta | ❌ la compuerta las evalúa **a hoy** (`controller.ts:1051`, sin fecha) |
| 8 | Mes ya pagado en otra prestación del mismo CC | bloquea, `i01`/`u01` | ❌ **no implementada**: el chequeo sigue acotado a `dpag.id_funprse = @id_funprse` (`sg_epagiSecgen01.sql:213-217`) |
| 9 | Cargo o contrato modificado | advierte | ❌ no existe en pagos |

| # | Presentación | Estado |
|:-:|:--|:--|
| 10 | Rechazo del envío persistente + revalidación tras el 422 | ❌ sigue como toast (`_nroSolici/index.vue:972`). Hay revalidación **antes** de enviar, no después del rechazo |
| 11 | Descuento desglosado por causal | ✅ `medicalLeaveDeduction` y `unpaidLeaveDeduction` se muestran por separado |
| 12 | Chip *Deuda institucional · Sin información* | ✅ |
| 13 | Retiro del chip de calendario | ✅ |

**Sobre el punto 4.** La compuerta usa el tope **recalculado** del cargo
(`selectNormativeStaffPositionCap`) y cae al congelado (`sg_fups.mto_tope`)
solo si el primero no existe. La matriz §6.1 deja esa elección como decisión
abierta (S0-013 §J). El código la tomó sin registrarla. Además el mensaje de
rechazo imprime montos sin formato (`la cuota solicita 1111111 y el tope
vigente es 256250`, `:1097`).

**Sobre el punto 8.** Resolución impide pedir el mismo mes en el mismo centro
de costo (Regla 11, `cost_center_month_locked`), así que el caso solo aparece
si una resolución anterior a esa regla, o una excepción, lo dejó pasar. Aun
así la matriz lo exige en PA-TX como defensa en profundidad.

---

## 4. WF pagos — cobertura por capa de la matriz oficial

La matriz exige que toda validación monetaria o de disponibilidad se repita en
`PA-TX`. Estado por capa de los controles de más peso:

| Control | UI | API (envío) | PA-TX | API (aprobación) |
|:--|:-:|:-:|:-:|:-:|
| Centro de costo vigente | ✅ | — | ✅ | ❌ |
| Pertenencia DU09 (`afec_du9`) | ✅ advierte | — | 🟡 apagado | ❌ |
| Saldo del centro de costo | ✅ | 🟡 apagado | ❌ | ❌ |
| Saldo del monto autorizado | ✅ | — | ✅ | ❌ |
| Tope por cuota | ✅ | ✅ | ❌ | ❌ |
| Cargo habilitado | ✅ | ✅ *si hay perfil* | ❌ | ❌ |
| Asignaciones | ✅ | ✅ *a hoy* | ❌ | ❌ |
| Evidencia | ✅ | — | ✅ | ❌ |
| Mes ya cubierto (misma prestación) | ✅ | — | ✅ | — |
| Constancia de parentesco | ✅ chip | ❌ | ❌ | ❌ |

La columna de la aprobación es la que deja expuesto el flujo.

**Dependencia del saldo cuando se encienda.** La compuerta pasa
`provision.budgetItemCode` como `cod_sitm` al PA de saldo
(`controller.ts:1112`). Ese valor sale de `sg_fups.cod_sitm` y puede ser el
ítem de tres dígitos (306) en vez del subítem de cinco (30600) que usa el
puente de Finanzas. Confirmar qué formato espera `valida_saldo_cc_cs` antes de
encender el interruptor; es la misma decisión que la tarea pendiente de guardar
el subítem de cinco dígitos.

---

## 5. WF resolución — validaciones

### 5.1 Lo que el servidor revalida al guardar

`service-provision-request-procedures.repository.ts`: período de ejecución
(`:3946`), contrato vigente sobre el rango (`:3289`), monto autorizado y cupo
(`:3958`), inhabilidad de contrato (`:3965`), asignaciones (`:3971`) y carga
horaria de 56 h (`:3979`). Es la defensa en profundidad que pide el documento 06.

### 5.2 Brechas

| Brecha | Detalle | Origen |
|:--|:--|:--|
| Cupo anual sin filtro por centro de costo | El backend cuenta todas las prestaciones del funcionario; el frontend solo las del mismo CC. Una solicitud válida en pantalla puede rechazarse al guardar con «cupo agotado». | ADR-020, abierto |
| ANID no suma entre solicitudes | Cada solicitud con extensión tiene su propio techo de 12, sin mirar las otras del mismo CC. | ADR-020, abierto |
| Funcionario sin contrato | Pasa en el formulario (toast) y en el servidor (la validación de contrato sale sin error si falta la fecha de inicio). | §1.2 |
| 56 h en el PA de horario | `sg_fuhosiSecgen01` no repite el tope; solo el backend lo valida. | documento 06 §2.1, brecha conocida |
| Deuda institucional | Pendiente de fuente; obligatoria desde el 01-01-2027. | matriz §4.3 |
| Parentesco | Bloquea solo `requiereConstancia = 'N'`; el resto se difirió al pago, que **no lo bloquea** (§4). Hoy la regla no se ejecuta en ninguna parte del sistema. | matriz §4.3, nota |

### 5.3 Un hallazgo pendiente de la sesión anterior, resuelto

En el modal de historial se había marcado como posible defecto que la fila
«Tope mensual aplicado» dijera *No aplica por extensión de cuotas* para la
N° 210 mientras WF pagos mostraba *Tope mensual $256.250*. **El modal está
bien**: la decisión del impacto 19 §11.1 fija que la extensión exime del tope,
y la compuerta de pago la aplica así (`controller.ts:1078-1080`, retorna antes
de comparar). Lo engañoso es pagos: `Du288PaymentContextSection.vue:152`
muestra el `mto_tope` guardado sin considerar la extensión, mientras otra
sección de la misma pantalla dice que el tope no se aplica.

---

## 6. Desarrollo y estándares

| Regla | Hallazgo | Severidad |
|:--|:--|:--:|
| Enmascarar identificadores (skill) | 37 mensajes de error con `RUT ${rut}` en claro, todos en `service-provision-request-procedures.repository.ts` (`:2788-2912` y otros); ninguno en pagos | 🟠 |
| Sin RUT en logs (skill) | `user-permissions.repository.ts:302`, `:310` — `console.log` de depuración con params y datos del usuario | 🟠 |
| Sin `any` en fronteras tocadas (skill) | 52 en `service-provision-request-procedures.repository.ts`, 9 en `service-provision-request.controller.ts`; **0** en los dos archivos de pagos | 🟡 |
| Reglas de negocio en la capa de servicio (skill) | La compuerta normativa del envío (`assertInstallmentNormativeCompliance` y sus tres ayudantes, ~200 líneas) vive en el **controlador**. Al agregar la de aprobación conviene moverlas a un servicio y no duplicar | 🟡 |
| Funciones pequeñas (skill) / extraer patrones (estándar §3.2) | `PdsDu288RequestForm.vue` tiene **8.851 líneas** y `Du288StaffPreviousProvisionsModal.vue` 3.294 | 🟡 |
| Sin números mágicos | `21` (`codTipmov`) en `controller.ts:1112`, `696` (`cod_organi` DGDP) en los PA, haber `2417` constante en la proyección del Excel (pendiente de ratificar, impacto 30) | 🟡 |
| Capas (skill) | Ninguna vista de `services-provision` llama HTTP directo | ✅ |
| Errores Sybase | Los repositorios mapean a errores HTTP seguros | ✅ |

---

## 7. Datos: lo que falta, sobra o es ambiguo

| Dato | Situación | Efecto |
|:--|:--|:--|
| `es_ccto.afec_du9` | `NULL` en los centros de costo de prueba | Encender el interruptor sin cargarlo bloquea esos CC. Correr `06_marcas_du09_centro_costo.sql` primero |
| `sg_fups.cod_sitm` | ítem de 3 dígitos o subítem de 5, según el origen | Condiciona el saldo (§4) y el puente de Finanzas |
| `sg_fups.tot_cuotas` vs filas de `sg_fume` | Pueden no coincidir (N° 212: declara 2, tiene 6 meses) | El backend ya lo documenta; el modal lo reporta como inconsistencia |
| `sg_fume.val_ciecc` | Se lee, nadie la escribe | Columna muerta; absorbida por CC cerrado |
| `sg_epag.mto_realpa` al aprobar | No se congela el neto en 2→4; solo al cerrar 4→8 | Decisión abierta (impacto 30 §6) |
| `fec_envepa`, `rut_envepa` | No existen en el esquema | La trazabilidad de quién envió a Finanzas queda en `sg_fum2` |
| `sg_ecuo.des_estcuo` | La pantalla lo muestra directo desde el 02-11 | Requiere `07_sg_ecuo_descripciones.sql` en bases existentes |
| Tope en pagos con extensión | Se muestra `mto_tope` aunque no aplique | §5.3 |
| Haber `2417` | Constante en código | Ratificar contra el valor por prestación |

---

## 8. Verificación ejecutada

| Verificación | Resultado |
|:--|:--|
| Backend `npm run build` | sin errores |
| Backend `lb-mocha` unitarias | **288 pasando, 0 fallando** |
| Frontend pruebas PDS | 23 archivos, todos correctos |
| Estándar visual DU288 | 55 archivos validados |
| ESLint `services-provision`, stores y utils DU288 | limpio |
| Pares `.sql`/`.txt` de `sg_epagiSecgen01`, `u01`, `u02` | idénticos |

---

## 9. Orden sugerido hasta certificar

| Paso | Qué | Capa |
|:-:|:--|:--|
| 1 | Descartar el `dist/` actual y reconstruir con `NODE_ENV=production`; verificar que el bundle no contenga identificadores del catálogo | despliegue |
| 2 | Exigir `NODE_ENV=production` y la **ausencia** de `DISABLE_AUTH` en certificación; corregir la indicación del checklist | despliegue |
| 3 | Incluir en el paquete los 37 PA que solo están en `cambios_pa/`, la versión de 168 líneas de `sg_usacsSecgen01` y los scripts 04 y 07 | despliegue |
| 4 | Decidir y escribir la compuerta normativa de la **aprobación** DGDP | backend + PA |
| 5 | Quitar el `if (profile)` silencioso: sin perfil, bloquear como `VALIDACION_CARGO_PENDIENTE` | backend |
| 6 | Llevar el 422 del envío a `installmentError` y revalidar tras el rechazo | frontend |
| 7 | Enmascarar el RUT en los 37 mensajes y retirar los dos `console.log` | backend |
| 8 | Bloquear la descarga del Excel con duplicados o campos vacíos | frontend |
| 9 | Correr `06_marcas_du09`, cargar `afec_du9`, confirmar el formato de `cod_sitm` y recién entonces encender los 6 puntos del interruptor, sincronizados | datos + PA + backend + frontend |
| 10 | Validaciones 3, 5, 7, 8 y 9 de la §3, y tope por cuota en PA-TX | PA + backend |
| 11 | Filtrar por centro de costo el cupo del backend de resolución (ADR-020) | backend |
| 12 | Actualizar el checklist y el catastro con las correcciones de la §1 | documentación |

Los pasos 1 a 8 no requieren decisión funcional. El 4, el 10 y el 11 sí.

---

## 10. Límites de esta auditoría

- No se ejecutó SQL contra Sybase: que un PA exista en el repositorio no prueba
  que esté instalado, ni con qué versión.
- No se abrió la aplicación en el navegador: los hallazgos de pantalla salen
  del código fuente.
- El conteo de 37 PA compara contra `sissolic-procedimientos/` por nombre de
  archivo; no contrasta versiones salvo en `sg_usacsSecgen01`.
- Los identificadores del catálogo de simulación se contaron sin imprimirlos;
  este documento no contiene ninguno.
