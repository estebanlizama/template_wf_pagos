# Inventario de PA a actualizar

Dos cambios concurrentes obligan a tocar procedimientos:

- **A.** `sg_fume` pasa a `corr_fume` / `cod_estfum` con catálogo propio `sg_efum`
- **B.** `ext_cuotas` como marca de extensión, asignada en el formulario y persistida

---

## Listo ✅

| PA | Motivo | Dónde está |
| :--- | :--- | :--- |
| `sg_fumeuSecgen01` | A — escritura de meses | `cambios_pa/sg_fume/` |
| `sg_efumsSecgen01` | A — listar catálogo | `cambios_pa/sg_efum/` |
| `sg_efumsSecgen02` | A — obtener por código | `cambios_pa/sg_efum/` |
| `sg_efumiSecgen01` | A — insertar | `cambios_pa/sg_efum/` |
| `sg_efumuSecgen01` | A — actualizar | `cambios_pa/sg_efum/` |
| `sg_fupsiSecgen01` | B — persiste `ext_cuotas` al crear | `cambios_pa/sg_fups/` |
| `sg_fupsuSecgen01` | B — persiste `ext_cuotas` al editar | `cambios_pa/sg_fups/` |
| `sg_fupssSecgen02` | B — recupera el snapshot al editar | `cambios_pa/sg_fups/` |
| `sg_fupssSecgen14` | B — valida contrato con `@ext_cuotas` | `cambios_pa/sg_fups/` |
| `sg_fupssSecgen15` | B — valida asignaciones con `@ext_cuotas` | `cambios_pa/sg_fups/` |
| `sg_fupssSecgen17` | A+B — historial con meses nuevos y snapshot crudo | `cambios_pa/sg_fume/` |
| `sg_fupssSecgen18` | A — bandeja de pagos migrada a `cod_estfum` | `cambios_pa/` · **desplegado** |

---

## Gestión de cuotas DGDP

El flujo de revisión de cuotas ya tiene PA de consulta y decisión en
`cambios_pa/sg_epag/`:

| PA | Función |
| :--- | :--- |
| `sg_epagsSecgen03` | Bandeja de cuotas en estado `2` para revisión DGDP |
| `sg_epagsSecgen04` | Detalle de meses de una cuota en revisión |
| `sg_epaguSecgen03` | Registrar decisión: `3` Observada, `4` Aprobada o `10` Rechazada |

La autorización se valida dentro de estos PA con el RUT autenticado, contrato activo y
asignación vigente en `sisper_db..sp_orde` con `cod_organi = 696`. No corresponde usar
la etapa/rol del flujo de resolución ni el permiso del director DGDP. Según la definición
vigente de `sg_epag`, la decisión persiste el estado; el rechazo libera los meses y devuelve
sus estados a propuesta. La observación se exige en la solicitud de observar/rechazar, pero
no se guarda en la BDD actual. `../datos_base/05_auditoria_revision_dgdp.sql` es una propuesta
opcional de extensión, no parte del despliegue compatible con el diagrama. El cambio de estado
`8 Enviada remuneraciones`, el rechazo individual de meses (`cod_estfum = 4`) y el registro de
descuentos siguen fuera de este paquete de revisión.

### Pendiente 🔲

- Desplegar y validar en Sybase los tres PA DGDP contra el esquema actual.
- Definir si se requiere persistir el motivo y los datos del revisor; eso requiere extender la BDD.
- Definir los PA restantes fuera de la decisión sobre cuotas: envío a remuneraciones,
  rechazo individual de meses y registro de descuentos.

### Histórico — `sg_fupssSecgen18` adaptado a `cod_estfum`

Alimenta la bandeja de pagos, que está en producción. Referencia columnas que dejan de existir:

```sql
count(fume.nro_cuota)                          as cant_cuotas
sum(case when fume.cod_estcuo = 1  ...)        as cant_cuotas_pend
sum(case when fume.cod_estcuo in (6,7,8) ...)  as cant_cuotas_gest
sum(case when fume.cod_estcuo = 9  ...)        as cant_cuotas_paga
sum(case when fume.cod_estcuo = 10 ...)        as cant_cuotas_rech
```

Más el `CASE` que arma `cod_estpag`. **Si no se toca, la bandeja de pagos deja de funcionar.**

Mapeo: `1→1`, `(6,7,8)→2`, `9→3`, `10→4`. Y lo pagado debería sumar `mto_realpa`, no
`mto_apagar`.

> El PA cuenta **meses** y los reporta como **cuotas**. Sigue pendiente decidir
> entre la adaptación mínima de códigos o renombrar las salidas a *meses*.

---

## Sin cambios ✅

| PA | Por qué |
| :--- | :--- |
| `sg_solidSecgen01` | Toca `sg_fume` pero solo con `if exists`, sin referenciar columnas. Compila igual. *(Cuando exista el encabezado de pago, la guarda debe mirar ahí y no los meses propuestos)* |
| `sg_fupssSecgen13` | Haberes y tope. La exención cambia cómo se **compara** el tope, no cómo se obtiene |
| `sg_fucoiSecgen01`, `sg_fuhosiSecgen01` | Compensación y horario comprometidos; no tocan meses ni estados |

---

## Orden de despliegue

```
1. DDL:  sg_efum · ALTER sg_fume · sg_fum2 · sg_fuc2 · migración · FK
2. PA:   sg_efum (los 4)
3. PA:   sg_fumeuSecgen01
4. PA:   sg_fupssSecgen17  ← fusionado
5. PA:   sg_fupssSecgen02
6. PA:   sg_fupsiSecgen01 · sg_fupsuSecgen01
7. PA:   sg_fupssSecgen14 · sg_fupssSecgen15
8. Backend  ← MISMA ventana que 3-7
9. PA:   sg_fupssSecgen18
```

Los pasos **3 a 7 van juntos**: el backend ya espera `@cod_estfum` y `corr_fume`. Si se separan,
guardar una solicitud falla con *"Procedure expects parameter"* y el historial de prestaciones
previas llega vacío.

---

## Resumen

**12 PA migrados/desplegados en el flujo de resolución · 3 sin cambios · los tres PA de revisión de cuotas DGDP están en archivos y pendientes de despliegue Sybase.**

La decisión sobre la señal quedó cerrada: `ext_cuotas` es la única fuente. No
se deriva de `cod_tfinan = 44` ni se mantiene `ind_anid` como alias. En la
migración A/B, el único PA que aún requiere completar el despliegue por el cambio
de estados de `sg_fume` es **`sg_fupssSecgen18`**; la lectura de `ext_cuotas`
dentro de ese PA ya quedó corregida.
