# PA de `sg_fume` — versiones actualizadas

| Archivo | Qué es |
| :--- | :--- |
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
| guarda de `sg_fuc2` por `nro_cuota` | por `corr_fume`; se conserva la guarda de compensación registrada |
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

Confirmar que certificación tenga el esquema vigente de meses y completar, por separado,
la conversión de filas históricas si parte del esquema anterior. Aplicar el [catálogo
de meses](../../datos_base/README.md). Instalar `sg_fumeuSecgen01.sql` y
`sg_fupssSecgen17.sql` en la misma ventana que el backend: el backend ya envía
`@cod_estfum`.

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

## Estructura observada en desarrollo

- `sg_fuc2` se relaciona con el mes por `(id_funprse, corr_fume)`.
- Los montos de `sg_fume` y `sg_fum2` son `int`.
- `sg_dpag` tiene claves foráneas compuestas hacia la cuota y hacia el mes.
