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

## Pendiente 🔲

### Las transiciones de DGDP no tienen PA

El encabezado llega a `2 En visación` y ahí se detiene. Faltan los procedimientos que lo
muevan a `3 Observada`, `4 Aprobada`, `10 Rechazada` y `8 Enviada remuneraciones`, más el que
rechaza un mes puntual (`cod_estfum = 4`) y el que registra descuentos de licencia y sin goce.

Antes de escribirlos hay que resolver dos cosas:

- **`sg_epag` no tiene dónde guardar la observación** ni quién visó. Dos columnas:
  `observacion varchar(255)`, `rut_visa char(9)`, `fec_visa datetime`.
- **El permiso del rol 2 no existe.** Hay que crear `provision-payment-approve` y asignarlo al
  perfil DGDP en la tabla de permisos. A diferencia de `provision-payment-manage`, que es
  derivado de ser responsable del centro de costo, éste sí va asignado.

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

**12 desplegados · 3 sin cambios · las transiciones de DGDP pendientes.**

La decisión sobre la señal quedó cerrada: `ext_cuotas` es la única fuente. No
se deriva de `cod_tfinan = 44` ni se mantiene `ind_anid` como alias. El único PA
pendiente es **`sg_fupssSecgen18`** por la migración completa de estados de
`sg_fume`; la lectura de `ext_cuotas` dentro de ese PA ya quedó corregida.
