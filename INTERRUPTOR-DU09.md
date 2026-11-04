# INTERRUPTOR-DU09 — procedimiento de activación de punta a punta

> **Esto es temporal.** Se encendió el **14-10-2026** para poder probar el envío
> a DGDP de punta a punta mientras los centros de costo de prueba no tienen
> cargadas sus marcas presupuestarias. **No puede llegar a certificación así:
> a master se entra con todas las validaciones bloqueando.**
>
> **Estado verificado el 04-11-2026:** los 6 puntos siguen apagados.
> Actualizado ese día con el procedimiento completo: archivos, cambios exactos,
> orden, verificación y vuelta atrás.

---

## 1. Qué está apagado y qué sigue bloqueando

Dos validaciones **se siguen mostrando** y **dejaron de impedir el envío del
solicitante y la aprobación DGDP**:

| Validación | Qué se ve | Qué hace hoy | Quién la aplica al encender |
| :--- | :--- | :--- | :--- |
| Saldo del centro de costo | chip *Centro de costo sin saldo*, en rojo | no bloquea | pantalla (punto 1) y compuerta del backend (punto 2) |
| Pertenencia a DU09 (`afec_du9`) | chip *Centro de costo fuera de DU09*, advertencia | no bloquea | PA de cuotas (puntos 3 a 5) y lista de centros de costo (punto 6) |

**Lo que se apagó es el bloqueo, no el diagnóstico.** Los chips quedan a la
vista a propósito: si además se ocultaran, al volver a encenderlos aparecerían
problemas que llevaban semanas ahí sin que nadie los viera.

**Sigue bloqueando**, sin cambios: contrato habilitado, cargo habilitado,
asignaciones, tope de la cuota (contra el tope congelado de la resolución),
**centro de costo cerrado**, evidencia obligatoria, mes de pago de la última
cuota, saldo del monto total autorizado y los meses ya tomados por otra cuota
del mismo centro de costo.

**No es parte de este interruptor**, pero se activa con la misma lógica: el
saldo en el **formulario de WF resolución** (`enableCostCenterBalanceSubmitValidation`,
ver `checklist_validaciones_y_paso_a_certificacion.md` §1.0). Conviene
encenderlo en la misma entrega, porque usa el mismo PA de saldo.

---

## 2. Requisitos previos — no encender sin esto

| # | Requisito | Cómo se comprueba | Si no se cumple |
| :-: | :--- | :--- | :--- |
| R1 | `afec_du9 = 'S'` cargado en los centros de costo DU288 de `fin21_db..es_ccto` | Correr `datos_base/06_marcas_du09_centro_costo.sql` (solo lectura) | Con la columna vacía, el punto 6 devuelve **cero** centros de costo para cualquier RUT —sin error— y los puntos 3 a 5 rechazan toda cuota. Se apaga el flujo completo |
| R2 | Finanzas confirma `fin21_db.Analisis.valida_saldo_cc_cs` y sus casos de prueba | Casos con saldo, sin saldo y sobregiro autorizado, ejecutados contra certificación | El saldo bloquea con datos que nadie validó |
| R3 | La prestación tiene **ítem presupuestario** (`sg_fups.cod_sitm`) | La bandeja muestra el ítem en el resumen de la cuota | La compuerta del backend recibe el ítem vacío y **omite** la consulta de saldo sin avisar (`assertCostCenterBalanceCompliance`) |
| R4 | Ventana de despliegue de base de datos coordinada | — | Los PA y el backend deben quedar en la misma entrega (§4) |

Cargar `afec_du9 = 'S'` se hace **caso a caso**: esa marca habilita pagar con
ese presupuesto.

---

## 3. Archivos y cambios exactos

Buscar la marca ubica todos los puntos:

```bash
grep -rn "INTERRUPTOR-DU09" sg-solicitudes-frontend sg-solicitudes-backend nuevo_workflow_fase_2/template_wf_pagos/cambios_pa
```

### 3.1 Aplicación (puntos 1 y 2, más el aviso)

| Punto | Archivo | Cambio |
| :-: | :--- | :--- |
| **1** | `sg-solicitudes-frontend/store/service-provision-payment-detail.js` (L25) | `const BALANCE_VALIDATION_BLOCKS_SUBMISSION = false` → **`true`**. Gobierna **dos pantallas**: el envío del solicitante y la aprobación DGDP (`pages/services-provision/payments/review/_staffProvisionId/_installmentNumber.vue` lee `balanceBlocks`). Los chips de saldo y de DU09 pasan de advertencia a rojo y bloquean |
| **2** | `sg-solicitudes-backend/src/controllers/service-provision/service-provision-payment.controller.ts` (L66) | `const BALANCE_BLOCKS_SUBMISSION = false` → **`true`**. Con eso la compuerta de `submitInstallment` pasa el ítem a `assertCostCenterBalanceCompliance` y rechaza con 422 si no hay saldo |
| aviso | `sg-solicitudes-frontend/components/services-provision/payments/Du288PaymentValidationsSection.vue` (L26-L29) | El `b-alert` «Modo de prueba» (`v-if="!balanceBlocks"`) desaparece solo con el punto 1, pero queda como código muerto: **borrarlo** |
| aviso | `sg-solicitudes-frontend/lang/es/pds.js` (L2569-L2570) | Borrar `testModeTitle` y `testModeDetail` |
| comentarios | Los dos archivos de los puntos 1 y 2 | Reemplazar el bloque `/* INTERRUPTOR-DU09 — apagado el 14-10-2026 … */` por un comentario que explique la regla vigente, sin la marca, para que el `grep` del §3 quede vacío al terminar |

**Los puntos 1 y 2 se encienden juntos.** Encender solo el backend deja la
pantalla en verde y el envío fallando con 422; encender solo el frontend deja
la API abierta a una llamada directa.

### 3.2 Procedimientos almacenados (puntos 3 a 6)

Todos viven en `nuevo_workflow_fase_2/template_wf_pagos/cambios_pa/`. En cada
uno: hacer el cambio en el `.sql`, actualizar la cabecera
`Actualizacion: ELA AAAA/MM/DD` con la fecha del cambio y **copiar el `.sql`
sobre el `.txt`** (deben quedar idénticos, CRLF y ASCII de 7 bits). Hoy los
cuatro pares son idénticos.

**Puntos 3, 4 y 5 — la guarda de `afec_du9`**

| Punto | Archivo | Comentario a quitar | Qué valida |
| :-: | :--- | :--- | :--- |
| **3** | `sg_epag/sg_epagiSecgen01.sql` (L120-L127) | `/* INTERRUPTOR-DU09 : punto 3 …` y su `*/` | crear la cuota |
| **4** | `sg_epag/sg_epaguSecgen01.sql` (L129-L136) | `/* INTERRUPTOR-DU09 : punto 4 …` y su `*/` | editar la cuota |
| **5** | `sg_epag/sg_epaguSecgen02.sql` (L104-L111) | `/* INTERRUPTOR-DU09 : punto 5 …` y su `*/` | enviar la cuota a visación |

Se borran **solo las dos líneas** del comentario (la de apertura con la marca y
el `*/`). El bloque queda así, después de la guarda de centro de costo cerrado:

```sql
if @afec_du9 <> 'S'
begin
    select 'Error: El centro de costo no pertenece al flujo DU09' as msg
    return
end
```

`@afec_du9` ya se declara y se carga más arriba (`isnull(ccto.afec_du9, 'N')`):
no hay que tocar nada más.

**Punto 6 — `sg_ccto/sg_cctosSecgen05.sql`, el único fuera de `sg_epag`**

Rama `@id_modprse = 2` (DU288). Invertir **los dos pares** rotulados
`CRITERIO DU288`:

| Par | Hoy (activo) | Después (activo) |
| :-: | :--- | :--- |
| 1 de 2, indicador (L66-L68) | `case when ccto.cod_tfinan in (21, 44) then 'S' else 'N' end as ind_financiamiento_du288,` | `case when isnull(ccto.afec_du9, 'N') = 'S' then 'S' else 'N' end as ind_financiamiento_du288,` |
| 2 de 2, filtro (L89-L91) | `and ccto.cod_tfinan in (21, 44)` | `and ccto.afec_du9 = 'S'` |

Borrar la línea vieja de cada par, no dejarla comentada, y quitar los rótulos
`INTERRUPTOR-DU09`.

**Los dos pares juntos, no uno.** Cambiar solo el filtro deja el indicador en
`'N'` para filas que el PA sí devolvió, y la validación normativa del
formulario las rechaza por financiamiento incompatible. Cambiar solo el
indicador deja entrar centros que no son DU288.

**El punto 6 afecta también a WF resolución.** `sg_cctosSecgen05` lista los
centros de costo de los dos flujos y de él se deriva el privilegio
`provision-payment-manage`. Al cambiarlo:

- el formulario de solicitud de resolución solo ofrece centros con
  `afec_du9 = 'S'`;
- «Financiamiento compatible» pasa a depender de la marca y no del tipo de
  financiamiento;
- un jefe de proyecto sin centros marcados pierde el menú de prestaciones por
  pagar.

**Va junto con los puntos 3 a 5:** la misma columna vacía que bloquea crear una
cuota deja sin privilegio al jefe de proyecto, así que encender uno sin el otro
deja el flujo a medias.

---

## 4. Cuándo y en qué orden

Todo en **una sola entrega**, en este orden:

| Paso | Qué | Dónde | Por qué en este orden |
| :-: | :--- | :--- | :--- |
| 1 | Correr `06_marcas_du09_centro_costo.sql` y cargar `afec_du9 = 'S'` caso a caso (R1) | Base de certificación | Sin la marca, los pasos 3 y 4 apagan el flujo |
| 2 | Confirmar R2 y R3 con Finanzas | — | Sin eso el saldo bloquea con datos no validados o se omite sin aviso |
| 3 | Editar los PA de los puntos 3 a 6, sincronizar sus `.txt`, compilarlos en Sybase | `cambios_pa/` → `secgen_db` | La guarda de `afec_du9` no depende de la aplicación: puede quedar activa antes |
| 4 | Editar los puntos 1 y 2, retirar el aviso y sus textos | Frontend y backend | Van juntos (§3.1) |
| 5 | Encender también el saldo de WF resolución (`checklist` §1.0), si Finanzas lo confirmó | Frontend y backend | Usa el mismo PA de saldo; activarlo después obliga a otra entrega |
| 6 | Pruebas automáticas y verificación manual (§5) | — | — |
| 7 | Comprobar que `grep -rn "INTERRUPTOR-DU09"` ya no devuelve nada salvo este documento | Repositorios | Es la señal de que no quedó ningún punto a medias |

Los pasos 3 y 4 deben llegar a certificación **en la misma ventana**: un PA ya
activo con la aplicación todavía en modo prueba no rompe nada (el PA rechaza y
la pantalla muestra el error), pero la inversa sí deja la API sin la guarda de
DU09.

---

## 5. Verificación de punta a punta

| # | Caso | Resultado esperado |
| :-: | :--- | :--- |
| V1 | Pantalla de pagos | El aviso amarillo «Modo de prueba» ya no existe |
| V2 | Envío con centro de costo **sin saldo** | El botón de enviar queda deshabilitado y el chip *Centro de costo sin saldo* cuenta entre los bloqueantes |
| V3 | `POST /requests/service-provision/payments/provisions/{id}/installments/{n}/submit` directo, sin saldo | 422 «No es posible enviar la cuota a visación: …» |
| V4 | Crear, editar y enviar una cuota de un centro de costo con `afec_du9` vacío | Los tres PA rechazan con «El centro de costo no pertenece al flujo DU09» |
| V5 | Formulario de solicitud de **WF resolución**, jefe con centros marcados y sin marcar | Solo aparecen los centros con `afec_du9 = 'S'`, con «Financiamiento compatible» en verde |
| V6 | Jefe de proyecto sin ningún centro marcado | No ve el menú de prestaciones por pagar (privilegio `provision-payment-manage`) |
| V7 | **Revisión DGDP** de una cuota sin saldo | El botón *Aprobar* queda deshabilitado y el chip pasa de ámbar a rojo; el modal de confirmación ya no muestra el aviso de advertencias |
| V8 | Chip de saldo del modal de confirmación DGDP | Mismo color que en la pantalla de envío: los dos salen del punto 1 |
| V9 | Envío con centro de costo **con saldo** y marcado | Pasa, igual que hoy |
| V10 | Pruebas automáticas | Frontend `node utils/__tests__/run-pds-tests.cjs` y `node utils/validateDu288Ui.js`; backend `npm run build` y `npx lb-mocha -r ./test-setup.js "dist/__tests__/unit/**/*.js"`, todo en verde |

---

## 6. Vuelta atrás

Si al encender aparece un bloqueo masivo (por ejemplo, centros sin marcar que
no se detectaron en el paso 1):

1. **Aplicación:** volver los puntos 1 y 2 a `false` en la misma entrega. No
   hace falta restaurar el aviso.
2. **PA:** recompilar desde el commit anterior la versión de `sg_epagiSecgen01`,
   `sg_epaguSecgen01`, `sg_epaguSecgen02` y `sg_cctosSecgen05`.
3. Preferible a lo anterior, si el problema es de datos: **corregir la marca
   `afec_du9`** del centro de costo afectado y dejar las guardas encendidas.

---

## 7. Lo que el interruptor **no** cubre: la aprobación DGDP

El punto 2 vive dentro de la compuerta de `submitInstallment`. El endpoint de la
decisión DGDP —`POST …/payments/dgdp/provisions/{id}/installments/{n}/decision`—
**no tiene compuerta normativa de ninguna clase**: valida el permiso
(`assertCanResolveDgdpPayment`) y nada más. Lo normativo lo decide el navegador,
con `blockingTags`, y el PA `sg_epaguSecgen03` solo exige la asignación DGDP
(`cod_organi = 696`) y que la cuota esté en estado 2.

Es decir: encender los puntos 1 y 2 deja el **envío** protegido en dos capas y
la **aprobación** protegida solo en la pantalla. Una llamada directa al endpoint
de decisión aprueba una cuota sin saldo, sin tope y sin evidencia.

Eso no lo arregla el interruptor: hace falta decidir **qué validaciones aplican
al aprobar**, que no son las mismas que al enviar. El propio controlador deja
dicho que un contrato no vigente en SISPER no debe bloquear el pago de cuotas ya
devengadas —«por desfase administrativo de pago»—, así que copiar
`assertInstallmentNormativeCompliance` tal cual bloquearía aprobaciones
legítimas. Está anotado en el checklist de certificación, §3, en tres controles
que piden exactamente eso (PAG-36, RES-CC-05/PAG-39 y RES-IN-07/PAG-32), y como
paso 10 de su secuencia.
