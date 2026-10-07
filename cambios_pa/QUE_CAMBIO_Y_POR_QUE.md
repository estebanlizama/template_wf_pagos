# Qué cambió en cada PA y por qué

**Fecha:** 02-10-2026
**Base:** el esquema nuevo (`diagrama_bdd/diagrama_pagos_actualizada.md`). No se modifica el
esquema desplegado.

Hay **dos categorías** y conviene no mezclarlas, porque la regla que aplica a cada una es
distinta.

---

## A. PA nuevos — los crea y los mantiene pagos

Ninguno existía. No tocan nada de resolución.

| PA | Qué hace |
| :--- | :--- |
| `sg_epagsSecgen01` | lista las cuotas de una resolución |
| `sg_epagsSecgen02` | los meses que abarca **una** cuota |
| `sg_epagiSecgen01` | crea el encabezado en estado 1 y asocia meses |
| `sg_epaguSecgen01` | edita mes de pago, respaldo y meses · estados 1 y 3 |
| `sg_epagdSecgen01` | elimina el borrador · solo estado 1 |
| `sg_epaguSecgen02` | **envía** a visación · 1\|3 → 2; exige que la cuota tenga `id_evidenc` antes de comprometer sus meses |
| `sg_fuc2sSecgen01` | lista compensaciones realizadas |
| `sg_fuc2iSecgen01` | registra un tramo |
| `sg_fuc2dSecgen01` | borra los tramos de un mes |
| `sg_ecuosSecgen01` | lista el catálogo de estados de cuota |
| `sg_ecuosSecgen02` | un estado por código |
| `sg_fumesSecgen02` | meses de una resolución, con montos y cuota |
| `sg_fumeuSecgen02` | fija `mto_apagar` y la ejecución real de un mes |
| `sg_epagsSecgen03` | bandeja DGDP de cuotas en visación |
| `sg_epagsSecgen04` | detalle de meses de una cuota en visación |
| `sg_epaguSecgen03` | decide una cuota: observada, aprobada o rechazada |

**Dieciséis PA nuevos**, incluyendo los tres de revisión DGDP.

Los dos últimos leen y escriben `sg_fume`, que es una tabla de resolución — pero son
**procedimientos nuevos**, no modificaciones. Crear un PA que consulta una tabla ajena no afecta a
quien ya la consulta.

---

## B. PA de resolución migrados — obligados por el cambio de esquema

Estos ya existían y **tuvieron que cambiar o dejaban de compilar**. No es una decisión de pagos:
`sg_fume.nro_cuota` y `sg_fume.cod_estcuo` se renombraron a `corr_fume` y `cod_estfum`, y estos
PA las leían.

| PA | Qué cambió |
| :--- | :--- |
| `sg_fumeuSecgen01` | `@cod_estcuo` → `@cod_estfum`; inserta `corr_fume` |
| `sg_fupssSecgen17` | lee `corr_fume` / `cod_estfum` y une contra `sg_efum` |
| `sg_fupssSecgen02` · `sg_fupsiSecgen01` · `sg_fupsuSecgen01` | persisten y recuperan `ext_cuotas` |
| `sg_fupssSecgen14` · `sg_fupssSecgen15` | reciben `@ext_cuotas` para evaluar el régimen de extensión |

**Siete PA migrados.** Los cambios son del flujo de resolución y le afectan a él, no a pagos.

### Un caso que quedó fuera

`sg_fumesSecgen01` está desplegado y **roto**: lee `nro_cuota` y `cod_estcuo`, que ya no existen.
**Pagos no lo toca.** Nadie lo invoca —su entrada en el mapa de consultas del backend estaba
muerta y se eliminó—, así que su estado no afecta a nadie. Repararlo es decisión del flujo de
resolución, no de este alcance.

---

## C. PA reutilizados sin modificar

Dieciséis, listados en [`pa_reutilizados.md`](pa_reutilizados.md). El caso más visible es
`sg_fucosSecgen01`, que entrega la compensación comprometida y se consume tal cual.

---

## Ajustes transversales aplicados a los nuevos

Los dieciséis de la categoría A pasaron por tres ajustes después de escritos. Conviene saberlos
porque explican por qué el archivo no se parece al primer borrador.

### 1. Estructura canónica

Los seis PA iniciales de `sg_epag` se escribieron antes de revisar
`reglas_estandarizacion_pa.md`. En esta revisión se alinearon las cabeceras, el bloque `drop`,
el espacio después de `as`, los alias/retornos de error y los finales de línea. También se
retiraron comentarios de desarrollo del cuerpo. Los tres PA DGDP incorporan la cabecera
canónica completa. El estándar pide un `Objetivo` breve y prohíbe comentarios informales dentro
del código fuente.

### 2. Contrato de retorno

Había tres convenciones conviviendo en lo desplegado. Se unificó a la que pide §6 del estándar:

```sql
-- éxito
select 1 as status, 'OK' as code, '<texto>' as msg [, columnas extra]

-- error
select '<texto>' as msg
```

El backend prueba `status = 1`. Antes distinguía éxito de error con una expresión regular sobre el
texto del mensaje, que se rompía con cualquier cambio de redacción.

### 3. Autorización dentro del PA

Los PA de gestión del solicitante reciben `@rut_person` y filtran contra `fin21_db..es_ecct`:
solo operan sobre prestaciones de centros de costo donde esa persona es responsable vigente.

La revisión DGDP usa un criterio distinto: RUT autenticado con contrato activo y asignación
vigente `sp_orde.cod_organi = 696`. No valida el rol/etapa de resolución ni el cargo de
director DGDP. Los tres PA de revisión comprueban esa asignación en base de datos.

---

## Un ajuste propio del esquema sin índice

Como no se agrega el índice único sobre `sg_dpag`, `sg_epagiSecgen01` y `sg_epaguSecgen01`
verifican **dos veces** que un mes no esté en otra cuota: antes de la transacción, y de nuevo con
`holdlock` justo después del `begin tran`.

El bloqueo se mantiene hasta el commit, así que dos llamadas simultáneas se serializan. Sin esa
segunda verificación, ambas pasarían la primera y ambas insertarían.

---

## Lo que se descartó en el camino

| Qué | Por qué |
| :--- | :--- |
| `sg_ecuoiSecgen01` · `sg_ecuouSecgen01` | Los estados son contrato: el catálogo es solo lectura desde la API |
| Extender `sg_fumesSecgen01` con parámetros de pago | Convertía un PA de resolución en compartido |
| Índice único sobre `sg_dpag` | El alcance no incluye DDL |
| `sg_fupssSecgen19` | Detalle de la resolución: queda para cuando se construya esa pantalla |

## Estandarización vigente

La lista de comprobación está en `reglas_bdd_pa/reglas_estandarizacion_pa.md` y en su copia
`template-du09/cambios_pa_solicitud_wf/reglas_estandarizacion_pa.md`. Para los nueve PA de
`sg_epag` se revisaron los cinco bloques requeridos, el uso de minúsculas en SQL, la cabecera
ASCII, la ausencia de comentarios de desarrollo, el retorno estándar (`status = 1` y
`code = 'OK'` al éxito; solo `msg` en error) y la paridad ASCII/CRLF de cada `.txt` con su `.sql`.
