# `sg_fume` en resolución — qué se guarda hoy, en qué etapa, y qué hay que cambiar

---

## 1. En qué etapa se escribe `sg_fume`

**Solo al ENVIAR. Nunca en borrador.**

[service-provision-workflow.service.ts:216](../../../sg-solicitudes-backend/src/services/service-provision-workflow.service.ts:216)
y [:409](../../../sg-solicitudes-backend/src/services/service-provision-workflow.service.ts:409):

```ts
if (isSubmitted) {
  await this.requestProcedures.syncNormativeRequestStaffMonths(created);
}
```

donde `isSubmitted` = `requestStatusId === SENT_TO_VALIDATION`.

El comentario del código explica el porqué, y es la misma lógica que aplicamos al WF de pagos:

> *"Si un borrador las escribiera, estaría bloqueando meses y consumiendo cupo de otras
> solicitudes sin que nadie haya aprobado nada — y un borrador abandonado dejaría el mes
> inutilizable."*

| Etapa de la resolución | ¿Escribe `sg_fume`? |
| :--- | :---: |
| Guardar borrador | **No** |
| **Enviar a validación** | **Sí** — `DELETE` + `INSERT` diferencial |
| Devuelta a corrección → reenviar | **Sí** — vuelve a sincronizar |
| Visaciones, aprobación, resolución, archivado | No |
| Rechazo | No (ver §3) |

El borrador no pierde información: los meses se derivan de `f_inicio`/`f_termino`, que sí quedan
persistidos en `sg_fups`.

---

## 2. Cómo se escribe

`sg_fumeuSecgen01` es una **sincronización diferencial**, no un update:

1. `DELETE` de los meses que salieron de la propuesta
2. `INSERT` de los meses que entraron, con `corr_fume = max(corr_fume) + n`
3. Los que siguen, **no se tocan**

Los meses los deriva el servidor desde `f_inicio`/`f_termino` (`deriveExecutionMonths`), no los
manda el cliente. Y se escriben **5 columnas**: `id_funprse`, `corr_fume`, `ano_prop`,
`mes_prop`, `cod_estfum = 1`.

No hay un solo `UPDATE` sobre `sg_fume` en todo el flujo de resolución.

---

## 3. Hallazgo: el rechazo llama a un stub, pero no importa

[service-provision-workflow.service.ts:1076-1088](../../../sg-solicitudes-backend/src/services/service-provision-workflow.service.ts:1076):

```ts
if (requestStatusCode === REJECTED || requestStatusCode === RETURNED_TO_CORRECTION) {
  await this.requestProcedures.updateInstallmentStatusesByRequest(...);
}
```

Ese método es un **stub vacío** (`void nroSolici; void codEstcuo;`). O sea: al rechazar una
resolución, los meses quedan en estado 1 para siempre.

**Pero no es un bug**, porque la exclusión ya ocurre un nivel más arriba. En
[sg_fupssSecgen17.txt:164](../../../sissolic-procedimientos/sg_fupssSecgen17.txt:164):

```sql
where fu.rut = @rut_person
  and (@nro_solici_excluir is null or fu.nro_solici <> @nro_solici_excluir)
  and soli.cod_estsol not in (4)          -- <- excluye solicitudes rechazadas
```

Las solicitudes rechazadas no entran al comparador, así que sus meses no consumen cupo aunque
sigan en estado 1. El filtro es por **estado de la cabecera**, no por estado del mes.

> **Acción:** eliminar la llamada y el stub. Es código muerto cuya intención ya está cubierta, y
> mantenerlo invita a alguien a "arreglarlo" implementando una doble exclusión.

---

## 4. Cambios obligatorios en `sg_fumeuSecgen01`

| Línea | Hoy | Queda |
| :--- | :--- | :--- |
| 30 | `@cod_estcuo int = 1` | `@cod_estfum int = 1` — el valor no cambia |
| 68 | `cod_estcuo not in (1, 3)` | `cod_estfum not in (1, 4)` |
| 160 | `#cuotas_salen (nro_cuota tinyint)` | `#meses_salen (corr_fume tinyint)` |
| 168 | `select f.nro_cuota from sg_fume f` | `select f.corr_fume from sg_fume f` |
| 219 | `delete ... where nro_cuota in (...)` | `where corr_fume in (...)` |
| 247 | `select @max_cuota = max(nro_cuota)` | `max(corr_fume)` |
| 253 | columnas `nro_cuota`, `cod_estcuo` | `corr_fume`, `cod_estfum` |

### 4.1 La guarda cambia de significado

`(1, 3)` era *Propuesta u Observada* del catálogo de **cuota**. Ahora es *Propuesta o Rechazada*
del catálogo del **mes**: se puede editar el periodo mientras ningún mes esté tomado por una
cuota de pago.

En la práctica, durante todo el flujo de resolución **todos los meses están en 1**, así que la
guarda nunca bloquea. Solo empieza a hacerlo cuando pagos comprometió meses.

### 4.2 Las guardas de `sg_fuc2` y `sg_fum2` hay que rehacerlas

```sql
-- hoy, líneas 186 y 198
where c.id_funprse = @id_funprse and c.nro_cuota in (select nro_cuota from #cuotas_salen)
```

`sg_fuc2` se repunta a `sg_epag` (la compensación efectiva es **por cuota**, Q-G04), así que esa
guarda deja de tener sentido por `corr_fume`. Y `sg_fum2` pasa a comparar por `corr_fume`.

### 4.3 Guarda nueva contra el puente

Es la que realmente protege el modelo:

```sql
if exists (select 1 from secgen_db.dbo.sg_dpag d
            where d.id_funprse = @id_funprse
              and d.corr_fume in (select corr_fume from #meses_salen))
begin
    select 'Error: No se puede quitar un mes ya asignado a una cuota de pago' as msg
    return
end
```

---

## 5. Cambio en `sg_fupssSecgen17` que no es por el catálogo

Además del renombre de columnas y el join a `sg_efum`, hay un bug latente en el `order by`
([línea 166](../../../sissolic-procedimientos/sg_fupssSecgen17.txt:166)):

```sql
order by soli.f_solicit desc, fu.id_funprse, fume.nro_cuota, fuc2.fec_comrea
```

`corr_fume` **no es cronológico** después de una edición: el PA asigna
`max(corr_fume) + n`, así que un mes agregado después queda con correlativo más alto aunque sea
anterior en el calendario. El modal mostraría enero después de mayo.

Debe ordenar por `fume.ano_prop, fume.mes_prop`.

---

## 6. Lo nuevo que resolución **sí** tiene que empezar a guardar

`sg_fups.ext_cuotas` es la única columna nueva del modelo que pertenece al grano de resolución, y
**hoy no la escribe nadie** — no existe una sola referencia en backend, frontend ni PA.

| | |
| :--- | :--- |
| Qué es | Libera el límite de cuotas del numeral 6 (ANID y otras extensiones) |
| Dónde vive | `sg_fups`, por funcionario-prestación |
| Quién la determina | El tipo de centro de costo (Q-G13: *"mediante el tipo de centro de costo se va a identificar si necesita algún tipo de extensión"*) |
| Quién la escribe | **Resolución**, al guardar el funcionario |

El frontend ya calcula la condición: `isSelectedCostCenterAnid()`, que alimenta
`getMaxDeclarableInstallments({ isCapExempt })`. Hoy se **recalcula** en cada consulta; con
`ext_cuotas` queda **congelada** al momento de la resolución, que es lo correcto: si el centro de
costo deja de ser ANID después, la prestación ya autorizada no debería perder su excepción.

**Falta definir:**
- si es `'S'/'N'` o un código que distinga ANID de otras causales,
- si DGDP puede modificarla después de archivada.

Y hay que agregarla al `INSERT`/`UPDATE` de `sg_fups`, que hoy no la incluye
([repository.ts:2087](../../../sg-solicitudes-backend/src/repositories/storedProcedures/service-provision-request-procedures.repository.ts:2087) escribe `tot_cuotas` pero no `ext_cuotas`).

---

## 7. Checklist

| # | Cambio | Dónde | Tipo |
| :-- | :--- | :--- | :--- |
| 1 | `@cod_estcuo` → `@cod_estfum` | `sg_fumeuSecgen01` | renombre |
| 2 | Guarda `not in (1, 3)` → `not in (1, 4)` | `sg_fumeuSecgen01` | semántica |
| 3 | `nro_cuota` → `corr_fume` en temporales, delete, max e insert | `sg_fumeuSecgen01` | renombre |
| 4 | Rehacer guardas de `sg_fuc2` y `sg_fum2` | `sg_fumeuSecgen01` | lógica |
| 5 | **Guarda nueva contra `sg_dpag`** | `sg_fumeuSecgen01` | nuevo |
| 6 | `@cod_estcuo` → `@cod_estfum` en el template | `service-provision-request.ts:162` | renombre |
| 7 | `cod_estcuo: 1` → `cod_estfum: 1` | `repository.ts:3561` | renombre |
| 8 | Join a `sg_efum`, salida `des_estfum` | `sg_fupssSecgen17` | renombre |
| 9 | **`order by ano_prop, mes_prop`** | `sg_fupssSecgen17` | bug |
| 10 | **Eliminar `updateInstallmentStatusesByRequest` y su llamada** | service + repository + query | código muerto |
| 11 | **Escribir `ext_cuotas` al guardar el funcionario** | PA de `sg_fups` + repository | nuevo |

Los marcados en negrita no son renombres: son cambios de comportamiento que hay que probar.
