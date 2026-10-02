# Backend de pagos — qué falta para el flujo completo

**Fecha:** 01-10-2026
**Rama:** `bandeja_pagos`

---

## 1. Lo que ya está

### Desplegado y funcionando

| | |
| :--- | :--- |
| Bandeja del solicitante | `sg_fupssSecgen18` + 2 endpoints |
| Permiso `provision-payment-manage` | derivado de ser responsable vigente de un CC DU288 |
| Módulo activo | en `ACTIVE_MODULES` de backend y frontend |
| Catálogo `sg_efum` + CRUD | 4 PA y 4 endpoints |

### Escrito, sin desplegar

| Grupo | PA | Endpoints |
| :--- | :--- | :--- |
| Compensación realizada | `sg_fuc2` × 3 | 4 |
| Cuotas | `sg_epag` × 5 | 5 |
| Catálogo de estados de cuota | `sg_ecuo` × 4 | 1 |

**12 PA y 12 endpoints** en el módulo de pagos. `tsc` limpio, 184 tests, `eslint` sin hallazgos.

---

## 2. Lo que falta — lado solicitante

### 2.1 Detalle de la resolución

La bandeja lista prestaciones, pero no hay con qué abrir una. Falta:

| # | Qué | Estado |
| :-- | :--- | :--- |
| S1 | PA de detalle: funcionarios de la resolución con su marco y avance | **escrito, fuera del repo** — `sg_fupssSecgen19` |
| S2 | PA de meses con estado, montos y la cuota que los contiene | **bloqueado** — ver 2.2 |
| S3 | PA que fija `mto_apagar` y la ejecución real de un mes | **escrito, fuera del repo** — `sg_fumeuSecgen02` |
| S4 | Endpoints de S1, S2 y S3 | — |

S1 y S3 están escritos pero quedaron fuera del repositorio cuando se decidió ir por partes. Se
pueden recuperar.

### 2.2 El PA de meses está roto

`sg_fumesSecgen01` **ya existe en la base** y lee columnas que la migración renombró:

```sql
SELECT fm.nro_cuota, fm.cod_estcuo ... LEFT JOIN sg_ecuo e ON fm.cod_estcuo = e.cod_estcuo
```

`sg_fume` ya no tiene `nro_cuota` ni `cod_estcuo`. **Nadie lo llama hoy** — está declarado como
`selectStaffMonths` en el mapa de consultas del backend y ninguna línea lo invoca —, así que no
hay un error en producción esperando. Pero el nombre está tomado.

Dos salidas: migrarlo a `corr_fume` / `cod_estfum` y ampliarlo con lo que la pantalla necesita, o
dejarlo morir y crear uno nuevo con otro nombre. Migrarlo es más limpio: la entrada muerta del
mapa de consultas también se limpia.

### 2.3 Evidencia de la cuota

`sg_epag.id_evidenc` está en el modelo y en los endpoints, pero **nada sube ni descarga el
archivo**. El binario va en MySQL, no en Sybase, y hay que decidir dónde:

| # | Qué | Bloquea |
| :-- | :--- | :--- |
| S5 | Decidir la tabla MySQL y el espacio de `id_evidenc` | todo lo demás |
| S6 | `POST` de subida — multipart, hex a MySQL | el envío, que la exige |
| S7 | `GET` de descarga, autorizado igual que el resto del módulo | la visación |

Detalle en [`evidencia_de_la_cuota.md`](evidencia_de_la_cuota.md).

### 2.4 La revalidación normativa del envío

`sg_epaguSecgen02` valida lo **estructural** y los saldos dentro de la transacción. Pero V5 exige
revalidar el panel normativo completo con datos frescos, y **nadie lo orquesta todavía**.

Los nueve PA ya existen y los usa resolución:

```
staff-profile · calculated-cap · staff-assignments · check-relationship
staff-position-cap · staff-previous-provisions · cost-center-balance
cost-center-balance-validation · institutional-calendar
```

| # | Qué |
| :-- | :--- |
| S8 | Servicio que los invoca antes del submit y aborta si alguno bloquea |
| S9 | Endpoint de solo lectura para que la pantalla muestre el panel sin enviar |

S8 es la pieza que cierra V5. Sin ella, el envío pasa con un contrato vencido.

---

## 3. Lo que falta — lado DGDP

**Nada de esto existe.** Es la mitad del flujo.

### 3.1 El permiso

`provision-payment-approve` no está en `permissions-const.ts`. A diferencia de
`provision-payment-manage`, que es derivado, éste **sí se asigna** en la tabla de permisos al
perfil DGDP.

| # | Qué |
| :-- | :--- |
| D1 | Crear el permiso y asignarlo al perfil |
| D2 | Exponerlo en `/auth/user` junto a los demás |

### 3.2 Columnas que faltan en `sg_epag`

Al sacar `sg_apso` del alcance, la cuota se quedó sin dónde registrar la observación:

```sql
alter table secgen_db.dbo.sg_epag
  add observacion varchar(255) null, rut_visa char(9) null, fec_visa datetime null
```

Sin eso, DGDP puede devolver una cuota pero no decir por qué.

### 3.3 Los PA de las transiciones

| # | PA | Transición | Efecto en los meses |
| :-- | :--- | :--- | :--- |
| D3 | bandeja de visación | lista cuotas en estado 2 | — |
| D4 | observar | 2 → 3 | ninguno |
| D5 | aprobar | 2 → 4 | ninguno |
| D6 | rechazar | 2 · 4 → 10 | 2 → 1, libera cupo y saldo |
| D7 | cerrar y enviar a Finanzas | 4 → 8 | 2 → 3, escribe `mto_realpa` |
| D8 | registrar devolución de Finanzas | 8 → 11 | 3 → 2 |
| D9 | aplicar descuentos de un mes | — | escribe `mto_deslic`, `mto_dessg` |
| D10 | excluir un mes no pagable | — | ese mes → 4 |

**D7 tiene una obligación extra:** `sg_epag.mto_realpa` y `sg_fume.mto_realpa` guardan la misma
cifra, una agregada y otra por mes. El cierre debe escribir ambas en la misma transacción.

### 3.4 Endpoints y modelos

| # | Qué |
| :-- | :--- |
| D11 | Bandeja de visación, filtrada por el permiso asignado |
| D12 | Un endpoint por transición, con el mismo criterio que el submit: `POST` a un sub-recurso, no `PATCH` del estado |
| D13 | Modelos de respuesta y de request para descuentos y observación |

---

## 4. Lo que bloquea el despliegue de lo ya escrito

```sql
create unique index UQ_sg_dpag_mes on secgen_db.dbo.sg_dpag (id_funprse, corr_fume)
```

La PK `(id_funprse, nro_cuota, corr_fume)` admite el mismo mes en dos cuotas. Los PA lo
verifican, pero esa guarda no sobrevive a dos envíos simultáneos ni a una corrección por SQL — y
los endpoints de cuota son justamente los que arman esa relación.

---

## 5. Orden sugerido

| | Bloque | Desbloquea |
| :-- | :--- | :--- |
| 1 | Índice único de `sg_dpag` | desplegar los 12 PA escritos |
| 2 | Desplegar `sg_fuc2`, `sg_epag`, `sg_ecuo` | la pantalla de detalle puede escribir |
| 3 | S1 · S2 · S3 — detalle, meses y montos | la pantalla de detalle puede leer |
| 4 | S5 · S6 · S7 — evidencia | el envío deja de estar incompleto |
| 5 | S8 — revalidación normativa | cierra V5 |
| 6 | D1 · D2 — permiso de DGDP | la segunda mitad del flujo |
| 7 | D3 a D13 — visación y cierre | flujo completo |

Los bloques **1 a 5** cierran el lado del solicitante: crear, editar, adjuntar y enviar una cuota
válida. Ahí la pantalla del jefe de proyecto queda operativa aunque DGDP todavía no pueda
responder.

---

## 6. Resumen

| | |
| :--- | :--- |
| Lado solicitante | **~70%** — falta detalle, evidencia y la revalidación del envío |
| Lado DGDP | **0%** |
| Decisiones abiertas que bloquean | espacio de `id_evidenc`, columnas de observación en `sg_epag` |
