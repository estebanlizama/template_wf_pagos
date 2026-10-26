# Datos base — WF de Pagos DU288/DU09

Un archivo por tabla, en orden de ejecución.

| # | Archivo | Tabla | Qué hace |
| :-- | :--- | :--- | :--- |
| 0 | `00_ddl_pagos.sql` | tablas nuevas + `sg_fume` / `sg_fum2` / `sg_fuc2` | Crea `sg_efum`, `sg_epag`, `sg_dpag` y `sg_com1`, agrega las columnas que faltan y renombra las que cambiaron |
| 1 | `01_sg_ecuo.sql` | `sg_ecuo` | Depura el catálogo del **encabezado** de pago (`sg_epag.cod_estcuo`) y deja los 7 vigentes |
| 2 | `02_sg_efum.sql` | `sg_efum` | Carga el catálogo del **mes** de ejecución (`sg_fume.cod_estfum`) |
| 3 | `03_migracion_sg_fume.sql` | `sg_fume` | Convierte las filas existentes de `cod_estcuo` a `cod_estfum` |
| 4 | `04_roles_privilegios_pagos.sql` | `bd_per1` / `bd_prvg` | Configura el rol 33 de revisor DGDP y sus privilegios |
| 5 | `05_sg_tacc_acciones_pago.sql` | `sg_tacc` | Registra los tipos de acción 32 (devolución) y 33 (rechazo) de cuotas DGDP para trazabilidad en `sg_hist` |
| 6 | `06_marcas_du09_centro_costo.sql` | `sg_ccto` | Carga marcas de afectación DU09 en centros de costo |

El DDL está en `00_ddl_pagos.sql`. Hasta el 26-10-2026 no existía como script: el modelo
describía el destino y `orden_de_despliegue.md` lo narraba en pasos, pero nada lo aplicaba, así
que ningún PA del flujo de pagos se podía instalar. El script es idempotente y **no borra nada**:
los `DROP` siguen siendo el paso 9 del orden de despliegue.

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
| 10 | Rechazada | terminal; **bloquea** cupo, saldo y meses (26-10-2026) |

Se quitan **5, 7, 9, 11, 12**. No se renumera: `sg_esol` conserva sus códigos y agrega al
final, y `sg_ecuo` sigue el mismo criterio para que el mapa de S0-004 siga siendo válido.

### `sg_efum` — mes `sg_fume` · numeración propia contigua

| cod | Estado | Tipo | Flujo que lo escribe |
| :---: | :--- | :--- | :--- |
| 1 | Propuesta | hecho | **solo resolución** · pagos ya no devuelve meses al 1 |
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
| **Del encabezado** (`sg_epag` → 10) | Los meses quedan en **4 Rechazada** y conservan su fila en `sg_dpag`: la cuota mantiene lo que solicitó, el monto se descuenta del total y el cupo se consume |
| **Del mes** (`sg_fume` → 4) | DGDP descarta un mes puntual mientras el resto de la cuota sigue. No vuelve a ofrecerse |

Los dos llegan al mismo estado del mes, pero por caminos distintos: uno arrastra la cuota
completa y el otro descarta un mes dentro de una cuota que sigue viva. Ninguno devuelve el mes
al 1.

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

- Los valores **2** y **3** los escribe únicamente el PA que mueve el encabezado.
- El valor **4** lo escribe el PA de validación de DGDP mes a mes, y también el PA que rechaza
  la cuota completa: arrastra todos sus meses.
- **Nadie devuelve un mes al 1.** Pagos ya no escribe ese valor; es solo de resolución.
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

## Decidido el 26-10-2026 — el cupo se pierde

Quedaba pendiente qué pasa con el cupo cuando DGDP descarta: **se pierde**. El rechazo bloquea
los meses en `sg_efum = 4`, conserva las filas de `sg_dpag` y descuenta el monto del total
decretado. La cuota consume su cupo igual que una aprobada.

Con dos cuotas autorizadas, dos rechazos agotan la prestación. Es deliberado: el criterio
anterior permitía reintentar sin límite sobre una resolución que autoriza dos.
