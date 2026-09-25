# Los montos: `sg_fups` vs `sg_fume`

Dos tablas, dos roles distintos.

- **`sg_fups`** guarda el **marco autorizado** por la resolución: cuánto se puede pagar en total
  y cuánto como máximo en un mes. Es un antecedente congelado.
- **`sg_fume`** guarda **lo que ocurre mes a mes** al pagar: cuánto se pide, cuánto se descuenta
  y cuánto termina yendo a Finanzas.

---

## 1. `sg_fups` — el marco (resolución)

| Columna | Tipo | Qué es |
| :--- | :--- | :--- |
| `mto_haber` | `int` | Haberes del funcionario en el mes de referencia (`mes_haber` / `ano_haber`). Es la base del cálculo, no un monto pagable |
| `mto_tope` | `int` | **Tope mensual aplicable** = 50 % de `mto_haber` (numeral 2). Congelado a `f_cal_tope`. Q-J12: no se recalcula al pagar |
| `mto_total` | `decimal(19,2)` | **Monto total autorizado** por la resolución para toda la prestación. Es el techo absoluto |
| `monto_mes` | `decimal(19,2)` | Promedio mensual real = `mto_total / meses de ejecución`. **Derivado**, lo recalcula siempre el PA (ADR-011). No es un compromiso por mes |

Ninguno de los cuatro cambia durante el flujo de pago.

---

## 2. `sg_fume` — lo que pasa mes a mes (pago)

| Columna | Qué es | Quién lo escribe |
| :--- | :--- | :--- |
| `mto_apagar` | Monto **solicitado** para ese mes dentro de la cuota | Fija: lo propone el sistema · Variable: lo ingresa el jefe de proyecto (Q-J07) |
| `mto_deslic` | Descuento por **licencia médica** en ese mes | DGDP |
| `mto_dessg` | Descuento por **permiso sin goce** en ese mes | DGDP |
| `mto_realpa` | Monto **real a pagar**: lo que viaja a Finanzas | el PA, al subir la cuota |

### La relación entre los cuatro

```
mto_realpa = mto_apagar − mto_deslic − mto_dessg
```

`mto_realpa` no es un dato que alguien teclee: es el resultado. Se persiste igual porque es lo
que se le informó a Finanzas, y ese hecho no puede depender de recalcularlo después.

---

## 3. Cómo se relacionan las dos tablas

```
sg_fups.mto_tope   ──── limita ────►  Σ mto_apagar de los meses de UNA cuota
                                       (cada cuota dispone del tope completo,
                                        no acumulativo, sin arrastre — T-01/T-03)

sg_fups.mto_total  ──── limita ────►  Σ de todos los meses de la prestación
```

### El saldo de la prestación

```
saldo = mto_total
        − Σ mto_realpa  de los meses en estado 3 (enviados a pago)
        − Σ mto_apagar  de los meses en estado 2 (comprometidos)
```

Lo enviado consume el **monto real**; lo comprometido consume el **solicitado**, porque todavía
no se sabe cuánto se descontará.

### El ciclo de vida de la plata

| Momento | Qué se escribe | Qué consume del saldo |
| :--- | :--- | :--- |
| Resolución | `mto_total`, `mto_tope` en `sg_fups` | — |
| ENVIAR | `mto_apagar` por mes | compromete `mto_apagar` |
| DGDP revisa | `mto_deslic`, `mto_dessg` | libera la diferencia descontada |
| Subir a pago | `mto_realpa` | consume `mto_realpa` definitivo |

**El descuento devuelve saldo.** Un mes con licencia no se ganó ese dinero, así que la
diferencia vuelve a estar disponible para otra cuota de la misma prestación.

---

## 4. Por qué el tope se valida sobre `mto_apagar` y no sobre `mto_realpa`

El tope limita **lo que se puede autorizar**, no lo que finalmente se transfiere. Si se validara
contra `mto_realpa`, un mes con descuento dejaría espacio para pedir más en otro mes de la misma
cuota, y eso convertiría el descuento en un premio.

Además, al ENVIAR los descuentos todavía no existen: DGDP los aplica después. La validación
autoritativa del tope corre en ese momento, así que sólo puede mirar `mto_apagar`.

---

## 5. 🔴 Problema de tipos

| Tabla | Columnas | Tipo |
| :--- | :--- | :--- |
| `sg_fups` | `mto_total`, `monto_mes` | `decimal(19,2)` |
| `sg_fups` | `mto_haber`, `mto_tope` | `int` |
| `sg_fume` | `mto_apagar`, `mto_realpa`, `mto_deslic`, `mto_dessg` | `int` |

Q-J13 pidió **sin redondeos**, y el descuento por licencia es proporcional a los días
efectivamente trabajados — que casi nunca da un entero. Con `int`:

- se pierden los centavos de cada descuento,
- y al sumar los meses de una cuota, el error se acumula contra `mto_total`, que **sí** tiene
  decimales.

Las cuatro columnas de `sg_fume` deberían ser `decimal(19,2)`. `mto_tope` también, por
consistencia con el 50 % de un haber que puede no ser par.

---

## 6. Resumen

| | `sg_fups` | `sg_fume` |
| :--- | :--- | :--- |
| Rol | marco autorizado | ejecución mes a mes |
| Lo escribe | resolución | pago |
| Cambia durante el pago | no | sí |
| Grano | la prestación completa | un mes |
| Pregunta que responde | *¿cuánto se puede pagar?* | *¿cuánto se pagó, y por qué menos?* |

Y la regla corta que conecta las dos:

```
Σ mto_realpa (prestación)  ≤  mto_total
Σ mto_apagar (una cuota)   ≤  mto_tope
mto_realpa                 =  mto_apagar − mto_deslic − mto_dessg
```
