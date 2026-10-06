# PA del encabezado de cuota — `sg_epag` / `sg_dpag`

Gestión de cuotas del **jefe de proyecto** y revisión de **DGDP**. Los PA existentes del jefe de
proyecto autorizan contra `fin21_db..es_ecct`; los PA `sg_epagsSecgen03/04` y
`sg_epaguSecgen03` verifican contrato activo más `sp_orde.cod_organi = 696`, RUT autenticado
coincidente y `vigente = 'S'`. El RUT llega del token.

| PA | Qué hace | Estados que admite |
| :--- | :--- | :--- |
| `sg_epagsSecgen01` | Lista las cuotas de una resolución con su total y período, usando columnas de `sg_epag` definidas en la BDD | — lectura |
| `sg_epagiSecgen01` | Crea el encabezado en **1 Propuesta** y le asocia meses | — |
| `sg_epaguSecgen01` | Edita mes de pago, respaldo y el conjunto de meses | 1, 3 |
| `sg_epagdSecgen01` | Elimina el borrador y libera sus meses | 1 |
| `sg_epaguSecgen02` | **Envía** a visación: `→ 2` y compromete los meses | 1, 3 |
| `sg_epagsSecgen03` | Bandeja DGDP: cuotas en visación | 2 |
| `sg_epagsSecgen04` | Detalle DGDP: meses de una cuota en revisión | 2 |
| `sg_epaguSecgen03` | Aprobar, observar o rechazar y actualizar el estado de la cuota | 2 |

---

## Qué mueve cada estado

```
      sg_epag.cod_estcuo              sg_fume.cod_estfum
 ──────────────────────────────────────────────────────────
  crear      →  1 Propuesta            sin cambio (sigue 1)
  enviar     →  2 En visación          1 → 2 Comprometida
  observar   →  3 Observada            sin cambio (sigue 2)
  reenviar   →  2 En visación          sin cambio (ya está 2)
  rechazar   → 10 Rechazada            2 → 1 Propuesta
  aprobar    →  4 Aprobada             sin cambio
  enviar rem →  8 Enviada remun.       2 → 3 Enviada a pago
```

Las transiciones DGDP se limitan a aprobar, observar o rechazar desde estado 2. El envío a
remuneraciones (estado 8) sigue sin PA.

**Crear no compromete.** El borrador deja los meses en `cod_estfum = 1`. Si crear ya los
comprometiera, un borrador abandonado bloquearía meses y consumiría cupo sin que nadie haya pedido
nada — mismo criterio que usa resolución para no escribir `sg_fume` desde un borrador.

**Observar no libera.** Por eso `sg_epaguSecgen01` no deja cambiar los meses de una cuota en 3:
siguen comprometidos, y cambiar el conjunto exigiría liberar unos y tomar otros en el mismo acto.
Cambiar los meses de una cuota ya enviada es rechazarla y rehacerla.

---

## Los tres montos de una cuota

| | Dónde vive | Quién lo escribe |
| :--- | :--- | :--- |
| **Solicitado** | derivado: `sum(sg_fume.mto_apagar)` | el solicitante, mes a mes |
| **Descuentos** | `sg_fume.mto_deslic` + `sg_fume.mto_dessg` | DGDP en la visación |
| **Monto de la cuota** | `sg_epag.mto_realpa` | el **cierre**, tras aplicar los descuentos |

`mto_realpa` es el monto de la cuota: lo que se registra para Finanzas. Es el único que se
persiste en el encabezado, y viene nulo mientras la cuota está en trámite — hasta entonces lo que
vale es lo solicitado.

El per-mes `sg_fume.mto_realpa` guarda la misma cifra desglosada, de modo que
`sg_epag.mto_realpa = sum(sg_fume.mto_realpa)` de los meses de la cuota. Está denormalizado a
propósito, para no tener que recorrer los meses en cada reporte; el PA de cierre tiene que
mantener las dos consistentes.

Lo solicitado no se persiste en el encabezado porque **`sg_dpag` no tiene columna de monto**: un
mes aporta su `mto_apagar` completo a una sola cuota y no puede repartirse entre dos. Lo calcula
`sg_epagsSecgen01` y lo revalida `sg_epaguSecgen02`.

Quien escribe `mto_apagar` es **`sg_fumeuSecgen02`**, no estos PA. Y no toca `cod_estfum`: el estado
lo mueve el procedimiento que mueve el encabezado, nunca una edición de datos.

---

## Qué valida el envío y qué no

`sg_epaguSecgen02` valida lo **estructural**:

- la cuota existe y está en 1 o 3;
- tiene al menos un mes;
- cada mes tiene `mto_apagar > 0`;
- desde el estado 1, cada mes sigue propuesto y con ejecución terminada;
- la suma no excede `sg_fups.mto_total` descontando lo ya comprometido y lo ya enviado.

El **panel normativo** —tope, inhabilidad, parentesco, saldo del centro de costo— lo revalida la
aplicación con los PA de resolución (`sg_fupssSecgen12` a `15`, `sg_cctosSecgen06`) antes de
llamar a este procedimiento. Duplicar esas reglas en SQL crearía una segunda versión que se
desincroniza de la que ya usa resolución.

---

## Cómo se evita que un mes caiga en dos cuotas

La PK de `sg_dpag` es `(id_funprse, nro_cuota, corr_fume)`, así que admite `(3,1,1)` y `(3,2,1)`:
el mismo mes en dos cuotas. No se agrega índice único; la aprobación/rechazo usa las PAs
transaccionales del módulo. El motivo de observación/rechazo no queda persistido: la definición
vigente de `sg_epag` no incluye una columna para guardarlo.

La guarda vive entonces en los procedimientos, en dos capas:

1. **Antes de la transacción**, `sg_epagiSecgen01` y `sg_epaguSecgen01` verifican que ninguno de
   los meses pedidos esté ya en `sg_dpag`. Esto atrapa el caso normal y devuelve un mensaje claro.
2. **Dentro de la transacción**, la misma verificación se repite con `holdlock` justo después del
   `begin tran`. El bloqueo compartido se mantiene hasta el commit, de modo que dos llamadas
   simultáneas se serializan: la segunda espera, encuentra el mes tomado y aborta con rollback.

Sin la segunda capa, dos envíos concurrentes pasarían ambos la verificación previa y ambos
insertarían.

**Lo que queda sin cubrir** es una corrección hecha directamente por SQL, que ningún procedimiento
puede impedir. Es un riesgo asumido al no agregar el índice.

Conviene confirmar también que la FK compuesta hacia `sg_fume` está en el catálogo:

```sql
sp_helpconstraint 'secgen_db.dbo.sg_dpag'
```

---

## Orden de despliegue

```
1. sg_ecuo/sg_ecuosSecgen01 · sg_ecuosSecgen02   catálogo, solo lectura
2. sg_fume/sg_fumesSecgen01   lectura de meses
3. sg_fume/sg_fumeuSecgen02   monto y ejecución real del mes
4. sg_fuc2/los tres              compensación realizada
5. sg_epag/sg_epagsSecgen01 · sg_epagsSecgen02   lectura de cuotas
6. sg_epag/sg_epagiSecgen01 · sg_epaguSecgen01 · sg_epagdSecgen01
7. sg_epag/sg_epaguSecgen02   envío
8. Backend y frontend
9. `datos_base/04_roles_privilegios_pagos.sql`
10. `sg_usacs/sg_usacsSecgen01` y actualizar `sg_epagsSecgen01`
11. `sg_epagsSecgen03/04` y `sg_epaguSecgen03`
12. Backend y frontend DGDP
```

Todos los PA usan las columnas declaradas para `sg_epag` en el diagrama vigente. La decisión
actualiza el estado y el rechazo libera los meses; el motivo, RUT revisor y fecha no se persisten
porque esa tabla no contiene campos para auditoría. El SQL `datos_base/05_auditoria_revision_dgdp`
queda como propuesta opcional de extensión y no forma parte de este orden de despliegue.
