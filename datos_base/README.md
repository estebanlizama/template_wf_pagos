# Datos base — WF de Pagos DU288/DU09

Un archivo por tabla, en orden de ejecución.

| # | Archivo | Tabla | Qué hace |
| :-- | :--- | :--- | :--- |
| 1 | `01_sg_ecuo.sql` | `sg_ecuo` | Depura el catálogo del **encabezado** de pago (`sg_epag.cod_estcuo`) y deja los 7 vigentes |
| 2 | `02_sg_efum.sql` | `sg_efum` | Carga el catálogo del **mes** de ejecución (`sg_fume.cod_estfum`) |
| 3 | `03_migracion_sg_fume.sql` | `sg_fume` | Convierte las filas existentes de `cod_estcuo` a `cod_estfum` |

El DDL (crear `sg_efum`, agregar `cod_estfum` a `sg_fume` y `sg_fum2`) va aparte, en el modelo.

---

## Los dos catálogos

### `sg_ecuo` — encabezado `sg_epag` · conserva sus códigos

| cod | Estado | |
| :---: | :--- | :--- |
| 1 | Propuesta | borrador; no compromete cupo ni saldo |
| 6 | Solicitada pago | ENVIAR — nace el flujo formal |
| 2 | En visación | DGDP la tomó |
| 3 | Observada | devuelta a corrección; **no libera nada** |
| 4 | Aprobada | validaciones conformes |
| 8 | Enviada remuneraciones | terminal, sin acuse |
| 10 | Rechazada | terminal; libera cupo, saldo y meses |

Se quitan **5, 7, 9, 11, 12**. No se renumera: `sg_esol` conserva sus códigos y agrega al
final, y `sg_ecuo` sigue el mismo criterio para que el mapa de S0-004 siga siendo válido.

### `sg_efum` — mes `sg_fume` · numeración propia contigua

| cod | Estado | Tipo | Flujo que lo escribe |
| :---: | :--- | :--- | :--- |
| 1 | Propuesta | hecho | **resolución** · y pagos al liberar por rechazo |
| 2 | Comprometida | hecho | pagos |
| 3 | Enviada a pago | hecho | pagos |
| 4 | Rechazada | decisión | pagos |

**Resolución escribe solo el 1 y lee los 4.** Todo el movimiento ocurre en pagos.

> **Principio: el estado guarda hechos y decisiones, nunca resultados de validación.**
> Las validaciones (licencia, sin goce, inhabilidad, contrato, saldo) son dinámicas y se
> recalculan en cada transición, sin caché. Un estado tipo *Validada* sería cachear un resultado
> que caduca: el mes quedaría marcado como aprobado y nadie lo volvería a evaluar.
>
> Por eso `val_licmed`, `val_singoce`, `val_inabili`, `val_ciecc`, `fec_valida`, `rut_autori` y
> `fec_autori` se conservan como **registro de auditoría** — lo que DGDP vio y decidió ese día —
> y no como permiso vigente.

Mientras DGDP visa, observa o aprueba la cuota, el mes **no cambia**: sigue en 2. El avance del
trámite vive en `sg_epag`.

> Los códigos de `sg_efum` **no** coinciden con los de `sg_ecuo`. Un reporte que muestre los dos
> niveles juntos necesita traducir.

---

## Los dos rechazos no son el mismo

| Rechazo | Efecto sobre los meses |
| :--- | :--- |
| **Del encabezado** (`sg_epag` → 10) | Los meses vuelven a **1 Propuesta** y liberan cupo y saldo, para poder rehacer la solicitud (S0-004) |
| **Del mes** (`sg_fume` → 4) | DGDP descarta un mes puntual mientras el resto de la cuota sigue. No vuelve a ofrecerse |

Colapsarlos en uno solo costaría, o la capacidad de rehacer una solicitud rechazada, o que un
mes con licencia reaparezca como disponible.

---

## Cómo los lee el comparador

```sql
consume cupo, reversible     cod_estfum = 2
consume cupo, irreversible   cod_estfum = 3
no consume cupo              cod_estfum in (1, 4)
disponible para una cuota    cod_estfum = 1
                             AND ((ano_prop*100 + mes_prop) < @mes_actual
                                  OR f_termino < getdate())
```

Reemplaza el matching por texto que usa hoy el backend
(`includes('PAGO')`, `includes('REMUN')`), que clasifica mal *Disponible pago* y *Aprobada*.

---

## Lo que no se persiste

| Concepto | Cómo se obtiene |
| :--- | :--- |
| Mes **validado** | `fec_valida` + los `val_*`. Y de todos modos se recalcula en cada transición |
| Mes disponible | `cod_estfum = 1` + la ejecución ya pasó — depende de la fecha actual |
| Mes ejecutado | columnas `ano_ejec` / `mes_ejec` |
| Pago parcial de la prestación | se deriva mirando sus cuotas (S0-004) |

---

## Reglas de escritura

- Los valores **2, 3** y el retorno a **1** los escribe únicamente el PA que mueve el
  encabezado.
- El valor **4** lo escribe el PA de validación de DGDP, mes a mes.
- La aplicación **nunca** escribe `cod_estfum` directamente.

Es lo que impide que el mes se desincronice de su cuota.

---

## Cambios que arrastra en el código

| Punto | Cambio |
| :--- | :--- |
| `sg_fumeuSecgen01:30` | `@cod_estcuo int = 1` → `@cod_estfum int = 1` — el valor no cambia |
| `sg_fumeuSecgen01:68` | `cod_estcuo not in (1, 3)` → `cod_estfum not in (1, 4)` |
| `sg_fumeuSecgen01:258` | columna `cod_estcuo` → `cod_estfum` en el `INSERT` |
| `repository.ts:3561` | `cod_estcuo: 1` → `cod_estfum: 1` |
| `service-provision-request.ts:162` | `@cod_estcuo` → `@cod_estfum` |
| `sg_fupssSecgen17` | join a `sg_efum`, salida `des_estfum` |
| `sg_fupssSecgen18` | reescritura completa: hoy cuenta meses y los reporta como cuotas |

---

## Pendiente

Si DGDP descarta un mes (→ 4) de una cuota que ya consumió cupo del numeral 6, falta decidir si
ese cupo se devuelve o se pierde.
