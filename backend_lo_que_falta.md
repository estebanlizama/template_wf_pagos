# Backend de pagos — estado y lo que falta

**Fecha:** 02-10-2026
**Rama:** `bandeja_pagos`
**Base:** esquema desplegado, sin DDL.

---

## 1. Lo que está hecho

**16 endpoints**, 14 de ellos con guard de jefe de proyecto. `tsc` limpio, 199 tests, `eslint` sin
hallazgos en lo tocado.

| Bloque | Endpoints |
| :--- | :--- |
| Bandeja | `payable-provisions` · `access-summary` |
| Compensación realizada | leer realizadas · leer comprometidas · registrar tramo · borrar |
| Meses | de una resolución · de una cuota · fijar monto y ejecución real |
| Cuotas | listar · crear · editar · eliminar · **enviar** |
| Catálogo de estados | listar · por código (solo lectura) |

**15 PA**, todos conformes al estándar: ASCII 7-bit, CRLF, estructura canónica, contrato
`status / code / msg` en los de mutación y filtro por `es_ecct` en los 11 de pago.

**Autorización en dos capas.** `assertIsProjectManager` en el servicio centralizado —Control 8,
junto a los otros siete— más el filtro dentro de cada PA.

---

## 2. Lo que falta — lado solicitante

### 2.1 Revalidación normativa antes del envío

`sg_epaguSecgen02` valida lo estructural y los saldos dentro de la transacción. Pero V5 exige
revalidar el panel completo con datos frescos, y **nadie lo orquesta**.

Los ocho PA ya existen y los usa resolución —`sg_fupssSecgen12` a `17`, `sg_cctosSecgen06`,
`es_cfersSecgen01`—. Falta el servicio que los invoque antes del submit y aborte si alguno
bloquea.

**Es la pieza que más pesa del lado solicitante.** Hoy una cuota se envía con un contrato vencido
o un cargo cambiado sin que nada la detenga.

### 2.2 Pruebas de la capa de repositorio

Los 15 tests nuevos cubren los modelos. Falta probar los helpers del repositorio: `toMonthCsv`,
`assertPaymentPeriod` y `assertMutationResult`. Son funciones puras y el último decide si una
operación se da por buena.

---

### 2.3 Evidencia — **TODO, parqueado**

`id_evidenc` existe en el modelo y los endpoints la aceptan, pero **no se implementa hasta que se
aclare dónde se guarda el archivo**. El envío no la exige, así que el flujo del solicitante
funciona completo sin ella.

Ver el aviso en [`evidencia_de_la_cuota.md`](evidencia_de_la_cuota.md).

---

## 3. Lo que falta — lado DGDP

**Nada de esto existe.** Es la mitad del flujo.

### 3.1 El permiso

`provision-payment-approve` no está en `permissions-const.ts`. A diferencia de
`provision-payment-manage`, que es derivado de ser responsable del centro de costo, éste **se
asigna** en la tabla de permisos al perfil DGDP.

Y necesita su propio guard en el servicio centralizado, equivalente a `assertIsProjectManager`.

### 3.2 Auditoría de decisión — no está en el esquema vigente

La definición actual de `sg_epag` no contiene columnas para observación, RUT revisor ni fecha.
Los PA se ajustaron para persistir solo el estado y no seleccionar ni actualizar esas columnas.
El archivo `datos_base/05_auditoria_revision_dgdp.sql` queda como extensión opcional; no
aplicarlo contra el esquema vigente. Persistir el motivo requerirá aprobar una extensión de BDD
o un mecanismo de historial separado.

### 3.3 Los PA de las transiciones

| PA | Transición | Efecto en los meses |
| :--- | :--- | :--- |
| bandeja de visación | lista cuotas en estado 2 | — |
| observar | 2 → 3 | ninguno |
| aprobar | 2 → 4 | ninguno |
| rechazar | 2 · 4 → 10 | 2 → 1, libera cupo y saldo |
| cerrar y enviar a Finanzas | 4 → 8 | 2 → 3, escribe `mto_realpa` |
| registrar devolución de Finanzas | 8 → 11 | 3 → 2 |
| aplicar descuentos de un mes | — | escribe `mto_deslic`, `mto_dessg` |
| excluir un mes no pagable | — | ese mes → 4 |

**Ocho PA.** El de cierre tiene una obligación extra: `sg_epag.mto_realpa` y `sg_fume.mto_realpa`
guardan la misma cifra, agregada y por mes, y deben escribirse en la misma transacción.

### 3.4 Endpoints y modelos

La bandeja y las decisiones DGDP están implementadas en la integración; el motivo se valida para
observar/rechazar, pero la BDD vigente no lo persiste. Los PA para envío a Finanzas, devolución,
descuentos y exclusión individual de meses siguen fuera de esta entrega.

---

## 4. Orden sugerido

| | Bloque | Depende de |
| :-- | :--- | :--- |
| 1 | Desplegar los 15 PA en desarrollo | — |
| 2 | Servicio de revalidación normativa | — |
| 3 | Tests del repositorio | — |
| 4 | Permiso `provision-payment-approve` + guard | asignación en la tabla de permisos |
| 5 | `ALTER` de `sg_epag` | **ventana de DDL** |
| 6 | Los ocho PA de DGDP y sus endpoints | 4 y 5 |
| — | Evidencia | **parqueado** hasta aclarar dónde se guarda |

Los bloques **1 a 3** cierran el lado del solicitante y no dependen de nadie más. Con eso la
pantalla del jefe de proyecto queda operativa de punta a punta, aunque DGDP todavía no pueda
responder y la cuota viaje sin respaldo adjunto.

---

## 5. Resumen

| | |
| :--- | :--- |
| Lado solicitante | **~90%** — falta la revalidación del envío |
| Lado DGDP | **0%** — y condicionado a una ventana de DDL |
| Parqueado | evidencia, hasta aclarar dónde se guarda el archivo |
| Bloqueantes externos | permiso de DGDP · `ALTER` de `sg_epag` |
