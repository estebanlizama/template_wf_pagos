# Bandeja de pagos del solicitante — qué falta en el backend

Rama `bandeja_pagos`, limpia. Revisión de lo que ya existe y lo que hay que agregar.

---

## 1. Lo que ya está construido

| Pieza | Archivo |
| :--- | :--- |
| Controlador | `controllers/service-provision/service-provision-payment.controller.ts` |
| Repositorio | `repositories/storedProcedures/service-provision-payment-procedures.repository.ts` |
| Query | `db-assets/.../service-provision-payment/` — un template |
| Modelos | `du288-payable-provision-response.model.ts` · `du288-payment-access-summary.model.ts` |
| PA | `cambios_pa/sg_fupssSecgen18.sql` — **no desplegado** |
| Frontend | `store/service-provision-payments.js` · `pages/services-provision/payments/index.vue` |

**Dos endpoints, ambos de lectura:**

```
GET /requests/service-provision/payments/payable-provisions   lista de prestaciones pagables
GET /requests/service-provision/payments/access-summary       si mostrar el menu
```

El RUT sale del token, nunca de la query: es el criterio de autorización de la bandeja. El PA
sólo devuelve prestaciones de centros de costo donde ese RUT es responsable vigente.

### El módulo ya está activo

`service-provision-payments` está en `ACTIVE_MODULES` en los dos lados (backend
`config/modules.config.ts` y frontend `config/active-modules.js`). La bandeja carga, el menú
aparece para quien es responsable vigente de un centro de costo DU288 y `sg_fupssSecgen18` está
desplegado con `cod_estfum`.

---

## 2. Lo que falta

La bandeja **lista** prestaciones pero no permite **hacer** nada con ellas: no hay acción para
iniciar una solicitud de pago, ni detalle, ni borrador.

### 2.1 Se puede agregar ahora — no depende del DDL nuevo

| # | Endpoint | Para qué | Fuente |
| :-- | :--- | :--- | :--- |
| A1 | `GET /payments/provisions/{idFunprse}` | Detalle de la prestación: montos, tope, contrato, horario comprometido | `sg_fups` + `sg_fuho` + `sg_fuco` |
| A2 | `GET /payments/provisions/{idFunprse}/months` | **Meses disponibles** para armar una cuota, con su estado | `sg_fume` |
| A3 | `GET /payments/provisions/{idFunprse}/attendance` | Asistencia del periodo, como antecedente para el revisor | `sp_as01sSecgen01` |
| A4 | `GET /payments/provisions/{idFunprse}/validations` | Panel normativo revalidado | los mismos PA de resolución |
| A5 | `GET /payments/cost-centers/{unifin}/{ccto}/balance` | Saldo del centro de costo | `valida_saldo_cc_cs` |

**A2 es el que destraba la pantalla.** Sin la lista de meses disponibles, el solicitante no tiene
con qué armar una cuota.

**A4 y A5 se reutilizan de resolución**, no hay que escribir PA nuevos: son `sg_fupssSecgen12`,
`13`, `14`, `15` y `sg_cctosSecgen06`, que el flujo de resolución ya invoca.

### 2.2 Depende del DDL de `sg_epag` y `sg_dpag`

| # | Endpoint | Para qué |
| :-- | :--- | :--- |
| B1 | `POST /payments/quotas` | Crear el borrador de cuota con sus meses |
| B2 | `PUT /payments/quotas/{idFunprse}/{nroCuota}` | Editar montos, mes de pago, meses que abarca |
| B3 | `DELETE /payments/quotas/{idFunprse}/{nroCuota}` | Eliminar el borrador |
| B4 | `POST /payments/quotas/{idFunprse}/{nroCuota}/evidence` | Adjuntar el PDF |
| B5 | `POST /payments/quotas/{idFunprse}/{nroCuota}/submit` | **Enviar** — la transacción autoritativa |

---

## 3. Lo que hay que corregir de lo existente

### 3.1 `sg_fupssSecgen18` cuenta meses y los reporta como cuotas

```sql
count(fume.nro_cuota) AS cant_cuotas
sum(case when fume.cod_estcuo = 1        then 1 else 0 end) AS cant_cuotas_pend
sum(case when fume.cod_estcuo in (6,7,8) then 1 else 0 end) AS cant_cuotas_gest
sum(case when fume.cod_estcuo = 9        then 1 else 0 end) AS cant_cuotas_paga
sum(case when fume.cod_estcuo = 10       then 1 else 0 end) AS cant_cuotas_rech
```

Hoy da lo mismo porque una cuota es un mes. Con el modelo nuevo deja de serlo, y además los
códigos `6,7,8,9,10` no existen en `sg_efum`.

El PA **no está desplegado**, así que se puede corregir antes de que entre.

### 3.2 El modelo arrastra el mismo nombre

`du288-payable-provision-response.model.ts` mapea `cant_cuotas` → `installmentCount` y así con
las cinco. Si el PA pasa a contar meses, el modelo y la página deben decir *meses*.

> `ext_cuotas` → `installmentExtensionIndicator` ya está mapeado en el modelo. Falta que alguien
> lo escriba: hoy ninguna capa lo hace.

---

## 4. Orden propuesto

| # | Paso | Depende de |
| :-- | :--- | :--- |
| 1 | Corregir `sg_fupssSecgen18` a `cod_estfum` y renombrar salidas a meses | migración de `sg_fume` |
| 2 | Actualizar el modelo y la página con los nombres nuevos | 1 |
| 3 | **A2** — meses disponibles | 1 |
| 4 | **A1** — detalle de la prestación | — |
| 5 | **A4** y **A5** — validaciones y saldo, reutilizando resolución | — |
| 6 | **A3** — asistencia | PA desplegado |
| 7 | DDL de `sg_epag` + `sg_dpag` | decisiones abiertas |
| 8 | **B1** a **B5** | 7 |
| ~~9~~ | ~~Activar el módulo en `ACTIVE_MODULES`~~ | **hecho** |

Los pasos **4, 5 y 6** no dependen de nada y se pueden hacer en paralelo.

---

## 5. Estado de las decisiones que bloqueaban el paso 7

`sg_ecuo`, `sg_epag` y `sg_dpag` ya están creadas en `secgen_db`, y el DDL desplegado cierra
tres de las cinco.

| # | Decisión | Estado |
| :-- | :--- | :--- |
| 1 | ¿`sg_fuc2` cuelga de `sg_epag` o de `sg_fume`? | **Cerrada** — de `sg_fume`, la FK compuesta está declarada |
| 2 | ¿Los montos pasan a `decimal(19,2)`? | **Cerrada** — no; `int` es correcto para CLP sin decimales |
| 3 | ¿`sg_epag` lleva `nro_solici`? | **Cerrada** — no; se llega por `sg_fups.nro_solici → sg_prse` |
| 4 | ¿Se renombra `installments` → `months` en la API? | Abierta |
| 5 | Índice único sobre `sg_dpag` para la regla Q-C06 | **Abierta y urgente** |

Detalle en `diagrama_bdd/diagrama_pagos_actualizada.md` §8.

La **5** pasó de defensa en profundidad a candado del negocio: la PK
`(id_funprse, nro_cuota, corr_fume)` admite el mismo mes en dos cuotas, y es justo la relación
que arma la pantalla de gestión. Hoy lo impide solo la aplicación, filtrando por
`cod_estfum = 1`.

```sql
create unique index UQ_sg_dpag_mes on secgen_db.dbo.sg_dpag (id_funprse, corr_fume)
```

Aparecen además dos faltantes que no estaban en esta lista: `sg_fum2` quedó sin las tres
columnas de monto de `sg_fume` y todavía con `cod_estcuo`, y `sg_epag` no tiene historial de
estados (se resuelve con `sg_apso` y un `cod_flusol` propio de pagos, sin tabla nueva).

---

## 6. Lo que la decisión de asistencia simplifica

Según lo acordado con Alex y Jose Luis, la asistencia **no valida automáticamente** la ejecución:
queda como antecedente para el revisor.

Eso significa que **A3 es sólo lectura y no participa del ENVIAR**. El endpoint entrega el
detalle diario y el frontend lo muestra; no hay regla que evaluar ni resultado que persistir.

Simplifica B5: la transacción de envío no tiene que consultar SISPER.
