# PA de `sg_fume` — versiones actualizadas

| Archivo | Qué es |
| :--- | :--- |
| `00_ddl_prerequisitos.sql` | Estructuras que los PA necesitan para compilar |
| `sg_fumeuSecgen01.sql` | **Escritura.** Sincroniza los meses de ejecución |
| `sg_fupssSecgen17.sql` | **Lectura.** Historial de prestaciones previas del funcionario |

---

## `sg_fumeuSecgen01` — qué cambió

| Antes | Ahora |
| :--- | :--- |
| `@cod_estcuo int = 1` | `@cod_estfum int = 1` — el valor no cambia |
| `cod_estcuo not in (1, 3)` | `cod_estfum not in (1, 4)` |
| `#cuotas_salen (nro_cuota)` | `#meses_salen (corr_fume)` |
| `max(nro_cuota)` | `max(corr_fume)` |
| columnas del `INSERT` | `corr_fume`, `cod_estfum` |
| guarda de `sg_fuc2` por `nro_cuota` | **reemplazada** por la guarda contra `sg_dpag` |
| guarda de `sg_fum2` por `nro_cuota` | por `corr_fume` |

### La guarda cambia de significado

`(1, 3)` era *Propuesta u Observada* del catálogo de **cuota** — y el 3 nunca se escribía, así
que era una guarda muerta. Ahora es *Propuesta o Rechazada* del catálogo del **mes**: el periodo
se puede editar mientras ningún mes esté tomado por una cuota de pago.

Durante todo el flujo de resolución los meses están en 1, así que la guarda **no bloquea nada
nuevo**. Empieza a bloquear cuando el WF de pagos comprometa meses.

### La guarda nueva contra el puente

```sql
if exists (select 1 from sg_dpag d
            where d.id_funprse = @id_funprse
              and d.corr_fume in (select corr_fume from #meses_salen))
```

La guarda de estado ya cubre el caso; esta la respalda contra la relación real, para el caso en
que un estado quedara desincronizado. Reemplaza a la vieja guarda de `sg_fuc2`, que preguntaba lo
mismo por un camino que ya no existe.

---

## `sg_fupssSecgen17` — qué cambió

| Antes | Ahora |
| :--- | :--- |
| `fume.nro_cuota` | `fume.corr_fume` |
| `fume.cod_estcuo` | `fume.cod_estfum` |
| `join sg_ecuo` → `des_estcuo` | `join sg_efum` → `des_estfum` |
| `fec_pago`, `ano_pago`, `mes_pago` | **eliminados** — viven en el encabezado de pago |
| — | **+ `mto_realpa`, `mto_deslic`, `mto_dessg`** |
| `fuc2.nro_cuota = fume.nro_cuota` | `fuc2.corr_fume = fume.corr_fume` |
| `order by ... fume.nro_cuota` | `order by ... fume.ano_prop, fume.mes_prop` |

### El `order by` era un bug latente

`corr_fume` se asigna como `max + n`, así que **no es cronológico después de una edición**: si la
prestación se guardó con marzo–mayo (1, 2, 3) y luego se agrega enero, enero queda con
correlativo 4. El modal mostraba enero después de mayo.

---

## Orden de ejecución

```
1. 00_ddl_prerequisitos.sql
2. datos_base/02_sg_efum.sql            cargar los 4 estados
3. datos_base/03_migracion_sg_fume.sql  poblar cod_estfum
4. NOT NULL + PK nueva + FK             (ver §8 del DDL — ventana de mantención)
5. DROP de las columnas viejas
6. sg_fumeuSecgen01.sql  +  sg_fupssSecgen17.sql
7. Desplegar backend                    ← MISMA ventana que el paso 6
8. datos_base/01_sg_ecuo.sql            depurar el catálogo de cuota
```

**Los pasos 6 y 7 son un solo despliegue.** El backend ya espera `@cod_estfum`; si se separan,
guardar una solicitud falla con *"Procedure expects parameter"*.

---

## Prueba funcional mínima

1. Crear una solicitud DU288 con 3 meses y **enviarla** → 3 filas en `cod_estfum = 1`.
2. Devolverla a corrección, acortar a 2 meses y reenviar → 1 fila menos.
3. Abrir el modal de prestaciones previas de ese funcionario desde **otra** solicitud → debe
   traer los meses. Si llega vacío, el contrato PA ↔ backend no calza.
4. Con el cupo del año agotado, el selector de cuotas debe quedarse sin opciones.

El punto 3 detecta el fallo silencioso: el modelo descarta las filas cuyo `corr_fume` no llega, y
eso hace que el cupo del numeral 6 cuente cero.

---

## Decisiones que el DDL deja anotadas

1. **`sg_fuc2`** se repunta a `corr_fume` ahora. En el WF la compensación efectiva quedó definida
   **por cuota** (Q-G04), así que a futuro debería colgar del encabezado de pago. Se hace así
   porque la tabla está vacía y la migración posterior no arrastra datos.
2. **Los montos pasan a `decimal(19,2)`.** Estaban en `int` mientras `sg_fups.mto_total` es
   decimal, y el descuento por licencia es proporcional a los días trabajados.
3. **La FK del puente estaba mal formada** en el modelo: traía dos FK de una columna hacia una PK
   de dos. El DDL la corrige como una sola FK compuesta.
