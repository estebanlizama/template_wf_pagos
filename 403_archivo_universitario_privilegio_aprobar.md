# 403 al firmar: al perfil 18 le falta `provision-request-approve`

Síntoma: `GET /requests/service-provision/resolution-approval/sign/208` →
**403** *"El usuario no posee el privilegio para aprobar solicitudes PDS."*
Solo le pasa al rol **Jefe de archivo Universitario** (perfil 18).

Fecha: 20-10-2026. Contrastado contra los 21 privilegios que el perfil 18 tiene
hoy en el ambiente.

---

## 1. La cadena, de la vista al dato

| Paso | Qué hace |
| :-- | :--- |
| `resolution-approval.controller.ts:105` | `getResolutionToSign` llama `assertCanApprove(dni)` — sin `workflowProfileId`, así que el **único** chequeo es el privilegio |
| `service-provision-authorization.service.ts:181` | `if (!access.permissions.includes('provision-request-approve')) → 403` |
| `sg_usacsSecgen01` | arma los perfiles del RUT y los cruza con `bd_pepr` → `bd_prvg` |
| `bd_pepr` | **acá falta la fila** |

Los 21 privilegios actuales del perfil 18 confirman el diagnóstico: de PDS tiene
`provision-request-document-read`, `-history-read`, `-read`,
`-resolution-document-archive` y `-read-waiting`. **No tiene
`provision-request-approve`.**

---

## 2. El patrón de la casa: el perfil 18 nunca aprueba

Mirando sus 21 filas por módulo, el patrón es consistente:

| Módulo | Lo que tiene el perfil 18 |
| :--- | :--- |
| baco | `resolution-document-archive`, `resolution-document-read` |
| balances-return | `resolution-archive`, `document-read`, `read-waiting` |
| cicc | `resolution-document-archive`, `document-read`, `read-history`, `read-waiting` |
| cost-center | `archive-resolution`, `opening-document-read`, `read-history`, `read-waiting` |
| incentivos | `resolution-document-archive`, `document-read` |
| **provision (PDS)** | **`resolution-document-archive`**, `document-read`, `history-read`, `read`, `read-waiting` |

En **ningún** módulo tiene un `*-approve`. Siempre `*-archive` + lecturas. PDS
sigue el mismo patrón.

O sea: la carga de datos **no está incompleta por descuido** — está coherente con
el resto. Lo que se sale de la norma es que en PDS el paso de archivo se
custodia con `provision-request-approve` en vez de con el
`provision-request-resolution-document-archive` que el perfil ya tiene.

---

## 3. Radio de impacto de otorgar el 65

`provision-request-approve` custodia **nueve** endpoints:

| Endpoint | 2ª compuerta | ¿Le da poder nuevo al perfil 18? |
| :--- | :--- | :--- |
| `GET …/resolution-approval/approvers/{id}` | — | lectura |
| `GET …/resolution-approval/sign/{id}` | — | lectura — **es el que necesita** |
| `PATCH …/{id}/resolution-approval/sign-resolution` | validación interna de `signResolution` | **sí — es el que necesita** |
| `POST …/resolution-approval/asignation` | **ninguna** | **sí — asignar firmantes de la resolución** |
| `GET …/{id}/available-actions` | — | lectura |
| `GET …/{id}/approval-preview` | — | lectura |
| `GET …/{id}/return-preview` | — | lectura |
| `GET …/{id}/resolution-signers-preview` | — | lectura |
| `PATCH /requests/service-provision/approval` | **`assertPendingTaskForUser`** | **no** |

Dos cosas importantes:

**El `PATCH …/approval` no se abre.** Es la visación de la solicitud —aprobar,
rechazar, devolver— y tiene una segunda compuerta explícita
(`service-provision-request-approval.controller.ts:415`):

```ts
// Control 4: Bloqueo por tarea activa en sg_apso y validación de perfil contra bd_pepr
const pendingApproval = await this.authorizationService.assertPendingTaskForUser(
  request.requestNumber!, dni,
);
```

Sin una tarea pendiente en `sg_apso` para ese RUT **en esa solicitud**, responde
409. El privilegio por sí solo no decide nada del WF de resolución.

**El `POST …/asignation` sí se abre**, y es el único. Solo tiene
`assertCanApprove(dni)` en el controlador (`resolution-approval.controller.ts:99`),
sin compuerta de tarea. Con el 65, el perfil 18 podría llamar
`acceptResolutionAndAssignApprovers`. Es el costo real de esta opción.

---

## 4. Lo que hay que agregar

### El SELECT de verificación, antes

```sql
select pep.cod_perfil,
       per.des_perfil,
       pri.cod_privil,
       pri.nom_privil
  from sistema_db.dbo.bd_pepr pep
 inner join sistema_db.dbo.bd_per1 per
    on per.cod_sistem = pep.cod_sistem
   and per.cod_modulo = pep.cod_modulo
   and per.cod_perfil = pep.cod_perfil
 inner join sistema_db.dbo.bd_prvg pri
    on pri.cod_sistem = pep.cod_sistem
   and pri.cod_modulo = pep.cod_modulo
   and pri.cod_privil = pep.cod_privil
 where pep.cod_sistem = 'SG'
   and pep.cod_modulo = 'SISSOLIC'
   and pep.cod_perfil = 18
   and pri.nom_privil like 'provision-%'
 order by pri.nom_privil
```

Acotado a `provision-%` a propósito: así se ve que los otros módulos no se
movieron.

### El INSERT

Una sola fila, idempotente, y **busca el código por nombre** en vez de
hardcodear el 65 — el `65` es el que define la semilla, pero el `cod_privil`
real del ambiente es el que manda (es lo mismo que hace
`carga_privilegios_aprobacion_du288.sql`):

```sql
insert into sistema_db.dbo.bd_pepr
    (cod_sistem, cod_modulo, cod_perfil, cod_privil)
select 'SG', 'SISSOLIC', 18, pri.cod_privil
  from sistema_db.dbo.bd_prvg pri
 where pri.cod_sistem = 'SG'
   and pri.cod_modulo = 'SISSOLIC'
   and pri.nom_privil = 'provision-request-approve'
   and not exists (
       select 1
         from sistema_db.dbo.bd_pepr pep
        where pep.cod_sistem = 'SG'
          and pep.cod_modulo = 'SISSOLIC'
          and pep.cod_perfil = 18
          and pep.cod_privil = pri.cod_privil
   )
```

Afecta **una fila**, de **un perfil**, en **un módulo**. No toca `bd_prvg`, no
toca otros perfiles, no toca `sg_eta1`/`sg_eta2`/`sg_apso`, y no cambia ninguna
decisión ya tomada.

### Y confirmar que solo se movió eso

```sql
select pep.cod_perfil, per.des_perfil
  from sistema_db.dbo.bd_pepr pep
 inner join sistema_db.dbo.bd_per1 per
    on per.cod_sistem = pep.cod_sistem
   and per.cod_modulo = pep.cod_modulo
   and per.cod_perfil = pep.cod_perfil
 inner join sistema_db.dbo.bd_prvg pri
    on pri.cod_sistem = pep.cod_sistem
   and pri.cod_modulo = pep.cod_modulo
   and pri.cod_privil = pep.cod_privil
 where pep.cod_sistem = 'SG'
   and pep.cod_modulo = 'SISSOLIC'
   and pri.nom_privil = 'provision-request-approve'
 order by pep.cod_perfil
```

Debe quedar la lista de la semilla —
`7 8 9 10 13 15 16 17 22 23 24 25 26 27 28 29 30 31 32` — **más el 18**.

### Para que un ambiente nuevo no nazca igual

En `cargar_datos_base/01_roles_permisos_du288.sql`, junto a las líneas 212-216:

```sql
INSERT INTO #perfil_privilegio_du288 VALUES (18, 65)
```

*(Alternativa: correr `maestros/carga_privilegios_aprobacion_du288.sql`, que lo
deriva de `sg_eta1`/`sg_eta2` y es idempotente. Incluye al perfil 18 porque la
etapa final tiene su transición de archivo en
`06_transiciones_flujo_du288.sql:61` — `(1, 130, 130, 2, 11)`. Pero ese script
recalcula **todos** los perfiles, así que puede agregar filas de más; el INSERT
puntual de arriba es el que no sorprende.)*

---

## 5. La opción más limpia, que no es de datos

Si lo que molesta es abrir el `POST …/asignation`, el arreglo conceptualmente
correcto es el otro: que los dos endpoints de firma acepten también
**`provision-request-resolution-document-archive`**, que el perfil 18 **ya
tiene**.

| | Otorgar el 65 (datos) | Aceptar el 70 en el guard (código) |
| :--- | :--- | :--- |
| Qué se cambia | 1 fila en `bd_pepr` | `assertCanApprove` o un guard nuevo en 2 endpoints |
| Abre `POST …/asignation` | **sí** | no |
| Respeta el patrón de la casa | no | **sí** |
| Toca código del WF de resolución | **no** | **sí** |
| Reversible | borrar la fila | revertir el commit |

Dijiste que no querías tocar lo del WF de resolución, y la columna que importa es
la penúltima. **Por eso recomiendo el INSERT**: es dato, es una fila, es
reversible en un `delete`, y lo único que abre de verdad es un endpoint de
asignación de firmantes al que solo llegan usuarios autenticados con rol de
workflow. Si más adelante se quiere cerrar ese hueco, el arreglo es agregarle su
propia compuerta de tarea pendiente, no quitarle el privilegio.

---

## 6. Dos cosas de tu listado que conviene mirar aparte

### `provision-payment-approve` en el perfil 18

Aparece en tus 21 filas. Ese es el privilegio que custodia la **resolución de
cuotas DGDP** (`service-provision-authorization.service.ts:312`,
`assertCanResolveDgdpPayment`), y debería ser del perfil **33** (Validador de
pagos DGDP), no de Archivo Universitario.

Hoy no se puede explotar: el PA `sg_epaguSecgen03` exige además
`sp_orde.cod_organi = 696` para resolver, así que la defensa en profundidad lo
tapa. Pero el guard del controlador **sí** lo deja pasar, y es exactamente la
clase de filtración entre módulos que se quiere evitar. Si no se otorgó a
propósito para una prueba, conviene sacarlo:

```sql
delete from sistema_db.dbo.bd_pepr
 where cod_sistem = 'SG'
   and cod_modulo = 'SISSOLIC'
   and cod_perfil = 18
   and cod_privil = (
       select cod_privil from sistema_db.dbo.bd_prvg
        where cod_sistem = 'SG' and cod_modulo = 'SISSOLIC'
          and nom_privil = 'provision-payment-approve'
   )
```

### La resolución 205 no tiene firmantes

El log muestra `sg_apresSecgen01 @nro_resolu = 205 → rows:0` y
`sg_apresSecgen03 @nro_resolu = 205 → rows:0`, mientras `sg_apso` sí tiene las
tareas de la solicitud (`sg_apsosSecgen01 @nro_solici = 208` → 16 filas).

`sg_apso` son las visaciones de la **solicitud**; `sg_apre` son los firmantes de
la **resolución**, y se crean con `POST …/resolution-approval/asignation`. Con
`sg_apre` vacío, `getResolutionToSign` va a devolver una lista vacía **aunque el
403 ya esté resuelto**. Hay que revisar si esa asignación se hizo:

```sql
select * from secgen_db.dbo.sg_apre where nro_resolu = 205
```

---

## 7. Relación con la precondición de pagos

Esto explica por qué el archivado puede no llegar nunca, y conecta con
[precondicion_archivada_archivo_universitario.md](precondicion_archivada_archivo_universitario.md):
si el perfil 18 no puede firmar, la solicitud **no llega a `cod_estsol = 11`**, y
sin eso `sg_epagiSecgen01` rechaza crear cualquier cuota con *"no esta
archivada"*. El 403 de hoy es, aguas arriba, el mismo bloqueo del WF de pagos.
