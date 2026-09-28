# Verificación del contrato end to end

¿Se guardan y se leen bien los datos? ¿Se rompe algo de lo ya desarrollado?

---

## 1. Estado actual: el código está adelantado respecto de la BDD

| Capa | Contrato |
| :--- | :---: |
| Frontend | **nuevo** ✅ |
| Backend (modelo, repository, queries) | **nuevo** ✅ |
| Procedimientos almacenados | **viejo** ❌ |
| Tabla `sg_fume` | **viejo** ❌ |

Mientras esos dos últimos no se migren, el sistema **no opera**. No es un bug del cambio: es
que la migración es atómica y falta su mitad.

---

## 2. Traza de ESCRITURA

```
Formulario (sólo fechas del funcionario)
  └─ store → POST/PUT /requests/service-provision
      └─ workflow.service.ts:216/409      if (isSubmitted)
          └─ repository.syncStaffMonths
                {id_funprse, meses_csv, cod_estfum: PROPOSED}   ✅ nuevo
              └─ query 'updateStaffMonths'
                    @cod_estfum = {{ cod_estfum }}              ✅ nuevo
                  └─ PA sg_fumeuSecgen01
                        @cod_estcuo int = 1                     ❌ viejo
```

**Qué pasa hoy:** Sybase rechaza la llamada porque el parámetro no coincide.
→ **Guardar o enviar una solicitud DU288 falla.**

**Qué pasa después de migrar:** idéntico a antes. Mismas 5 columnas, mismo valor, mismos meses
derivados de `f_inicio`/`f_termino`. Lo único que cambia es el nombre del parámetro y de dos
columnas.

---

## 3. Traza de LECTURA

```
PA sg_fupssSecgen17
    nro_cuota · cod_estcuo · des_estcuo · fec_pago · ano_pago · mes_pago   ❌ viejo
  └─ repository.selectStaffPreviousProvisions
      └─ modelo espera
            corr_fume · cod_estfum · des_estfum · mto_realpa · …           ✅ nuevo
          └─ GET /staff-previous-provisions/{rut}
              └─ textSimilarityUtil.js  →  cupo, severidad, conflictos
              └─ modal comparador DGDP
```

**Qué pasa hoy — y esto es lo peligroso:** no falla. El modelo lee `row.monthSequence`, que llega
`undefined`, y la guarda `if (!monthSequence) return` **descarta la fila en silencio**.

Resultado: `installments: []` en todas las prestaciones previas. Consecuencias:

| Función | Efecto |
| :--- | :--- |
| Cupo del numeral 6 | cuenta **0 meses comprometidos** → deja declarar cuotas que no corresponden |
| Comparador DGDP | tabla vacía, sin señales de conflicto |
| Advertencia de doble pago | no se dispara |

**Un fallo silencioso que relaja una validación normativa.** Por eso la migración no admite
despliegue parcial.

---

## 4. Lo que NO cambia después de migrar

| Aspecto | Antes | Después |
| :--- | :--- | :--- |
| Columnas que escribe resolución | 5 | **las mismas 5** |
| Valor del estado inicial | `1` | **`1`** (ahora vía constante) |
| Cómo se derivan los meses | `f_inicio`/`f_termino` en el servidor | **igual** |
| Cuándo se escribe | sólo al enviar | **igual** |
| Sincronización | `DELETE` + `INSERT` diferencial | **igual** |
| Cupo del numeral 6 | claves `año-mes` | **igual** |
| Tope por cuota | `mto_total`, `cod_tpps`, `tot_cuotas` | **igual** — no toca `sg_fume` |
| Traslapes, duplicidad, horarios | fechas e identificadores | **igual** |

**Ninguna regla de negocio cambió.** Cambiaron dos nombres de columna, el catálogo al que apunta
el estado, y la forma de clasificar ese estado (código en vez de texto).

---

## 5. Lo que sí cambia visiblemente

| Antes | Después | Por qué |
| :--- | :--- | :--- |
| Columna *Pago efectivo* en el modal | eliminada | la fecha se fue al encabezado de pago |
| Badge *Pagada* | *Enviada a pago* | el sistema no recibe acuse de Finanzas |
| `isPaid` en la API | `isSentToPayment` | mismo motivo |
| *"Disponible pago"* contaba como comprometido | ya no | era un bug del matching por texto |
| *"Aprobada"* contaba como libre | ya no | mismo bug |

Los dos últimos son **correcciones**, no regresiones.

---

## 6. Lo que falta para que opere

| # | Paso | Estado |
| :-- | :--- | :---: |
| 1 | `CREATE TABLE sg_efum` + carga de los 4 estados | script listo |
| 2 | `ALTER sg_fume ADD cod_estfum` + migración + FK + `DROP cod_estcuo` | script listo |
| 3 | Lo mismo en `sg_fum2` | por definir |
| 4 | **`sg_fumeuSecgen01`** → `corr_fume` / `cod_estfum` | **pendiente** |
| 5 | **`sg_fupssSecgen17`** → columnas nuevas, join a `sg_efum`, sin campos de pago | **pendiente** |
| 6 | `sg_fupssSecgen18` → adaptación mínima | **pendiente, decisión abierta** |

Los pasos 4 y 5 son los únicos que quedan entre el estado actual y un sistema que opera.

---

## 7. Cómo verificar después de migrar

```sql
-- 1. Todos los meses deben quedar en 1 y ninguno sin estado.
SELECT cod_estfum, count(*) FROM secgen_db.dbo.sg_fume GROUP BY cod_estfum
SELECT count(*) FROM secgen_db.dbo.sg_fume WHERE cod_estfum IS NULL
```

Prueba funcional mínima, que cubre las dos trazas:

1. Crear una solicitud DU288 con 3 meses y **enviarla** → deben quedar 3 filas en estado 1.
2. Devolverla a corrección, acortar el periodo a 2 meses y reenviar → debe quedar 1 fila menos.
3. Abrir el modal de prestaciones previas de ese funcionario desde **otra** solicitud → debe
   traer los meses, no una tabla vacía.
4. Con el cupo del año agotado, el selector de cuotas debe quedarse sin opciones.

El punto 3 es el que detecta el fallo silencioso; el 4, que el cupo sigue contando bien.
