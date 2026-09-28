# Verificación del diagrama contra el backend implementado

Contraste columna por columna entre `diagrama_pagos_actualizada.md` y lo que el backend ya
escribe, lee y decide.

---

## 1. `sg_fume` — alineado ✅

Las 20 columnas del diagrama calzan exactamente con lo que el código consume.

| Columna del diagrama | Escribe | Lee | Mapeo en el backend |
| :--- | :---: | :---: | :--- |
| `id_funprse` | resolución | ✓ | `staffProvisionId` |
| `corr_fume` | resolución | ✓ | `monthSequence` |
| `ano_prop` | resolución | ✓ | `proposedYear` |
| `mes_prop` | resolución | ✓ | `proposedMonth` |
| `cod_estfum` | resolución (=1) | ✓ | `monthStatusCode` |
| `ano_ejec` | pagos | ✓ | `executionYear` |
| `mes_ejec` | pagos | ✓ | `executionMonth` |
| `mto_apagar` | pagos | ✓ | `amountToPay` |
| `mto_realpa` | pagos | ✓ | `amountPaid` |
| `mto_deslic` | pagos | ✓ | `medicalLeaveDeduction` |
| `mto_dessg` | pagos | ✓ | `unpaidLeaveDeduction` |
| `id_evidenc` | pagos | ✓ | `evidenceId` |
| `val_licmed` | pagos | ✓ | `medicalLeaveFlag` |
| `val_inabili` | pagos | ✓ | `disablementFlag` |
| `val_singoce` | pagos | ✓ | `unpaidLeaveFlag` |
| `val_ciecc` | pagos | ✓ | `attendanceClosureFlag` |
| `fec_valida` | pagos | ✓ | `validatedAt` |
| `rut_autori` | pagos | ✓ | `authorizedBy` |
| `fec_autori` | pagos | ✓ | `authorizedAt` |
| `fec_envrem` | pagos | ✓ | `sentToPayrollAt` |

**PK `(id_funprse, corr_fume)`** — correcta. **FK `cod_estfum` → `sg_efum`** — declarada.

Verificación automática del contrato: de las **71 columnas** que el modelo de respuesta espera del
PA, **falta cero**. `des_estfum` llega por el join a `sg_efum`, no es columna de `sg_fume`.

---

## 2. El estado quedó bien resuelto ✅

| Pieza | Estado |
| :--- | :--- |
| Columna `cod_estfum` con FK a `sg_efum` | en el diagrama ✓ |
| Catálogo de 4 estados | cargado ✓ |
| Resolución escribe solo `PROPOSED` | `Du288MonthStatusCode.PROPOSED` ✓ |
| Lectura expone `monthStatusCode` + `monthStatus` | ✓ |
| Clasificación por código, no por texto | `isCommitted` / `isSentToPayment` / `isRejected` ✓ |
| CRUD del catálogo | 4 PA + modelo + controlador `/month-statuses` ✓ |
| Frontend consume los flags nuevos | ✓ |

El matching por substring (`includes('PAGAD')`) que decidía el cupo del numeral 6 está eliminado
en las tres capas.

---

## 3. 🔴 `sg_efum` no está definida en el diagrama

Aparece **sólo como destino de una FK**, nunca como `CREATE TABLE`:

```
tablas definidas:     sg_fume · sg_epag · sg_dpag · sg_fups · sg_prse · sg_apso
                      sg_fuho · sg_fuco · sg_efun · sg_his2 · sg_tpps
solo referenciadas:   sg_efum  ← falta su definición
```

Hay que agregarla, o el diagrama no es ejecutable de corrido:

```sql
CREATE TABLE secgen_db.dbo.sg_efum (
	cod_estfum tinyint NOT NULL,
	des_estfum varchar(60) NOT NULL,
	CONSTRAINT SG_EFUM_PK PRIMARY KEY (cod_estfum)
);
CREATE UNIQUE INDEX PK_sg_efum ON secgen_db.dbo.sg_efum (cod_estfum);
```

---

## 4. 🔴 Faltan `sg_fum2` y `sg_fuc2`

Ninguna de las dos está en el diagrama, y **las dos dependen de la llave que cambió**.

| Tabla | Problema | Necesita |
| :--- | :--- | :--- |
| `sg_fum2` | su FK apuntaba a `sg_fume(id_funprse, nro_cuota)` | `corr_fume`, `cod_estfum`, y los 3 montos nuevos para que el espejo capture lo que cambia |
| `sg_fuc2` | idem | `corr_fume` — **`sg_fupssSecgen17` ya la joinea por esa columna** |

El segundo es bloqueante: el PA de lectura hace
`fuc2.corr_fume = fume.corr_fume`. Si la columna no existe, el PA no compila.

---

## 5. 🟡 Los montos siguen en `int`

| Tabla | Columna | Tipo en el diagrama |
| :--- | :--- | :--- |
| `sg_fups` | `mto_total`, `monto_mes` | `decimal(19,2)` |
| `sg_fume` | `mto_apagar`, `mto_realpa`, `mto_deslic`, `mto_dessg` | **`int`** |
| `sg_epag` | `mto_realpa` | **`int`** |

Q-J13 pidió **sin redondeos**, y el descuento por licencia es proporcional a los días trabajados.
Con `int` se pierden los centavos de cada descuento y el error se acumula al sumar los meses de
una cuota contra un total que **sí** tiene decimales.

Conviene resolverlo en el mismo `ALTER`, no en otro despliegue.

---

## 6. 🟡 El archivo tiene bloques duplicados

`sg_fume` aparece **3 veces**, `sg_epag` **3 veces**, `sg_dpag` **2 veces**. Es un artefacto del
export. No afecta al modelo, pero impide ejecutar el archivo de corrido y hace fácil editar una
copia y no las otras.

---

## 7. Lo que ya no aplica de mis observaciones anteriores

| Observación previa | Estado |
| :--- | :--- |
| Las dos FK mal formadas de `sg_dpag` | sigue en el diagrama, pero **ya no bloquea**: los PA actualizados no referencian `sg_dpag` |
| Guarda de `sg_fumeuSecgen01` contra `sg_dpag` | **reemplazada** por la guarda sobre `sg_fuc2`. La protección real la da el estado `cod_estfum not in (1, 4)` |

---

## 8. Resumen

**El cambio de `sg_fume` y el tema de estado está correctamente implementado de punta a punta:**
diagrama, PA de escritura, PA de lectura, backend y frontend coinciden en las 20 columnas y en la
forma de clasificar el estado.

**Lo que falta en el diagrama, en orden de urgencia:**

| # | Falta | Bloquea |
| :-- | :--- | :---: |
| 1 | `sg_fuc2.corr_fume` | **sí** — `sg_fupssSecgen17` no compila |
| 2 | `CREATE TABLE sg_efum` | **sí** — la FK de `sg_fume` no resuelve |
| 3 | `sg_fum2` con las 5 columnas nuevas | no, pero el historial queda incompleto |
| 4 | Montos a `decimal(19,2)` | no, pero se pierden centavos |
| 5 | Limpiar los bloques duplicados | no |
