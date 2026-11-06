# INTERRUPTOR-DU09 — estado y verificación de punta a punta

> **Esto es temporal.** Se encendió el **14-10-2026** para poder probar el envío
> a DGDP de punta a punta mientras los centros de costo de prueba no tienen
> cargadas sus marcas presupuestarias. **No puede llegar a certificación así:
> a master se entra con todas las validaciones bloqueando.**
>
> **Estado al 06-11-2026: los 6 puntos están encendidos en el repositorio.**
>
> - Puntos 1 y 2: las constantes de frontend y backend valen `true`.
> - Puntos 3 a 5: guardas `afec_du9` descomentadas.
> - Punto 6: criterio invertido a `afec_du9 = 'S'`.
> - El aviso «Modo de prueba» y sus textos se retiraron.
> - El `grep` del §3 ya no encuentra la marca en el código.
>
> **Antes de compilar los PA 3 a 6 en certificación**, deben cumplirse R1 a
> R4 (§2). Si no, el flujo de pagos se apaga entero. Después se verifica con
> V1 a V10 (§5).
>
> Además, desde ese día:
> - la compuerta de envío **rechaza** una prestación sin ítem presupuestario,
>   en vez de omitir el saldo;
> - la aprobación DGDP tiene su propia compuerta en el servidor (§7):
>   respaldo, tope, DU09, saldo y parentesco con constancia.
>
> Historial: el 04-11-2026 los 6 puntos seguían apagados.

---

## 1. Estado actual: interruptores encendidos

Los diagnósticos continúan visibles y sus condiciones bloquean envío/aprobación:

| Validación | Qué se ve | Qué hace hoy | Dónde se aplica |
| :--- | :--- | :--- | :--- |
| Saldo del centro de costo | chip *Centro de costo sin saldo*, bloqueante | bloquea envío y aprobación | pantalla y compuertas backend |
| Pertenencia a DU09 (`afec_du9`) | estado informativo/errores de validación | bloquea creación, edición, envío y aprobación; centros fuera de flujo no aparecen en la selección | backend de aprobación, PA de cuota y PA de centros de costo |

**Sigue bloqueando**, sin cambios: contrato habilitado, cargo habilitado,
asignaciones, tope de la cuota (contra el tope congelado de la resolución),
**centro de costo cerrado**, evidencia obligatoria, mes de pago de la última
cuota, saldo del monto total autorizado y los meses ya tomados por otra cuota
del mismo centro de costo.

El saldo de WF resolución también está activo en pantalla y revalidado en
servidor. La compilación y los permisos del PA de saldo siguen pendientes de
evidencia por ambiente.

---

## 2. Requisitos previos — no encender sin esto

| # | Requisito | Cómo se comprueba | Si no se cumple |
| :-: | :--- | :--- | :--- |
| R1 | `afec_du9 = 'S'` cargado en los centros de costo DU288 de `fin21_db..es_ccto` | Correr `soporte_certificacion/06_marcas_du09_centro_costo.sql` (solo lectura) | Con la columna vacía, el punto 6 devuelve **cero** centros de costo para cualquier RUT —sin error— y los puntos 3 a 5 rechazan toda cuota. Se apaga el flujo completo |
| R2 | Finanzas confirma `fin21_db.Analisis.valida_saldo_cc_cs` y sus casos de prueba | Casos con saldo, sin saldo y sobregiro autorizado, ejecutados contra certificación | El saldo bloquea con datos que nadie validó |
| R3 | La prestación tiene **ítem presupuestario** (`sg_fups.cod_sitm`) | Revisar bandeja/resumen y registros a enviar | Sin ítem, backend rechaza con 422 porque no se puede validar saldo |
| R4 | Ventana de despliegue de base de datos coordinada | — | Los PA y el backend deben quedar en la misma entrega (§4) |

Cargar `afec_du9 = 'S'` se hace **caso a caso**: esa marca habilita pagar con
ese presupuesto.

---

## 3. Inventario de los puntos (no reconmutar)

### 3.1 Aplicación (puntos 1 y 2, más el aviso)

| Punto | Archivo | Estado de fuente |
| :-: | :--- | :--- |
| **1** | `sg-solicitudes-frontend/store/service-provision-payment-detail.js` | ✅ `BALANCE_VALIDATION_BLOCKS_SUBMISSION = true`; controla UI de envío y aprobación DGDP |
| **2** | `sg-solicitudes-backend/src/controllers/service-provision/service-provision-payment.controller.ts` | ✅ `BALANCE_BLOCKS_SUBMISSION = true`; protege envío y aprobación al llamar API |
| aviso | `Du288PaymentValidationsSection.vue`, `lang/es/pds.js` | ✅ Aviso «Modo de prueba» y sus traducciones retirados |
| comentario histórico | Fuentes frontend/backend | ✅ Marca del interruptor retirada de código; este documento conserva su nombre para identificar el paquete |

**Los puntos 1 y 2 deben mantenerse sincronizados.** Activar solo el backend deja la
pantalla en verde y el envío fallando con 422; encender solo el frontend deja
la API abierta a una llamada directa.

### 3.2 Procedimientos almacenados (puntos 3 a 6)

Todos viven en `nuevo_workflow_fase_2/template_wf_pagos/cambios_pa/`. En cada
uno: las guardas/criterios ya están activos en las fuentes `.sql`; los cuatro
pares `.sql/.txt` están idénticos. Confirmar cabecera, versión y compilación
instalada en ASE durante el pase.

**Puntos 3, 4 y 5 — guardas de `afec_du9` activas**

| Punto | Archivo | Estado | Qué valida |
| :-: | :--- | :--- | :--- |
| **3** | `sg_epag/sg_epagiSecgen01.sql/.txt` | ✅ `if @afec_du9 <> 'S'` ejecutable; compilar en ASE | crear la cuota |
| **4** | `sg_epag/sg_epaguSecgen01.sql/.txt` | ✅ `if @afec_du9 <> 'S'` ejecutable; compilar en ASE | editar la cuota |
| **5** | `sg_epag/sg_epaguSecgen02.sql/.txt` | ✅ `if @afec_du9 <> 'S'` ejecutable; compilar en ASE | enviar la cuota a visación |

El bloque activo, después de la guarda de centro de costo cerrado, es:

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

Rama `@id_modprse = 2` (DU288). Los dos criterios ya usan `afec_du9`:

| Par | Estado activo |
| :-: | :--- | :--- |
| Indicador | `case when isnull(ccto.afec_du9, 'N') = 'S' then 'S' else 'N' end as ind_financiamiento_du288` |
| Filtro | `and ccto.afec_du9 = 'S'` |

Los dos criterios están sincronizados en los archivos de entrega. Mantenerlos
juntos si se modifica el contrato del PA; no reactivar el filtro antiguo por
tipo de financiamiento.

**El punto 6 afecta también a WF resolución.** `sg_cctosSecgen05` lista los
centros de costo de los dos flujos y de él se deriva el privilegio
`provision-payment-manage`. Al cambiarlo:

- el formulario de solicitud de resolución solo ofrece centros con
  `afec_du9 = 'S'`;
- «Financiamiento compatible» pasa a depender de la marca y no del tipo de
  financiamiento;
- un jefe de proyecto sin centros marcados pierde el menú de prestaciones por
  pagar.

Los puntos 3 a 6 dependen de que los datos `afec_du9` estén regularizados. Sin
esa marca, la validación activa puede rechazar pagos y excluir centros de costo.

---

## 4. Cuándo y en qué orden

Las fuentes de aplicación ya tienen los interruptores encendidos. Para certificar, completar el despliegue y evidencia en este orden:

| Paso | Qué | Dónde | Por qué en este orden |
| :-: | :--- | :--- | :--- |
| 1 | Correr `06_marcas_du09_centro_costo.sql` y regularizar `afec_du9 = 'S'` caso a caso (R1) | Base de certificación | Evita exclusión/rechazo de centros autorizados |
| 2 | Confirmar R2 y R3 con Finanzas | Finanzas / certificación | Saldo, permisos, ítem presupuestario y escenarios esperados |
| 3 | Instalar DDL/catálogos y compilar los PA actuales, incluidos puntos 3 a 6 | `datos_base/`, `cambios_pa/` → Sybase | Fuentes `.sql/.txt` están listas; instalación real falta evidenciar |
| 4 | Desplegar backend y frontend de la misma entrega | Aplicación | Conservar ambas constantes en `true` |
| 5 | Verificar V1 a V10, pruebas técnicas y llamadas directas protegidas | Certificación | Guardar evidencia, errores y versiones instaladas |

Aplicación y base deben quedar coordinadas en la misma ventana de despliegue.
No volver a apagar el frontend/backend como método de corregir datos faltantes;
regularizar la marca y corregir la causa antes del cierre.

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

## 7. Compuerta de aprobación DGDP y límites

> **Resuelto el 06-11-2026.** El endpoint de decisión tiene compuerta propia al
> aprobar: `assertDgdpApprovalCompliance`, en
> `service-provision-payment.controller.ts`. Revalida:
>
> - el respaldo adjunto;
> - el tope de la cuota, salvo extensión;
> - DU09 y el saldo del ítem;
> - que el servicio de parentesco responda y que la relación no requiera constancia.
>
> No revalida el contrato vigente en SISPER, por la razón que sigue. Devolver
> y rechazar no pasan por ella. Lo de abajo queda como antecedente.

La compuerta rechaza los datos de pertenencia DU09 faltantes o distintos de `S`;
saldo sin ítem; saldo insuficiente; respaldo ausente; tope excedido (salvo
extensión); parentesco no verificable o que requiere constancia. El servidor no
revalida vigencia SISPER del contrato para no bloquear cuotas devengadas por
desfase administrativo. Formación Continua/PAG-39, cierre del proyecto/PAG-36 y
la comprobación positiva de constancia RES-IN-07 requieren evidencia adicional
y se detallan en el checklist principal §3.
