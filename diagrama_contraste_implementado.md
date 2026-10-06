# El diagrama contra lo implementado

**Fecha:** 05-10-2026
**Método:** cada nodo contrastado con el PA o el componente que lo ejecuta, no con el diseño.

Resumen: **tres nodos cambian** por lo construido en esta sesión, y **cinco afirman validaciones que
hoy no existen en ningún procedimiento**. Lo segundo no lo introdujimos nosotros, pero el diagrama
las presenta como parte del flujo.

---

## 1. Lo que cambia por lo implementado

### V4 dejó de ser informativo

```
Antes:  V4 · Contraste informativo
        informado vs comprometido
        la diferencia se muestra y se guarda
```

`sg_fuc2iSecgen01` ahora **rechaza** el tramo que haga `informado + nuevo > comprometido`. La
diferencia solo puede cerrarse hasta 0; no se puede pasar. Pasó de contraste a tope, y el momento en
que actúa es el **registro del tramo**, no el envío.

Además *«se guarda»* no es exacto: la diferencia se deriva de dos sumas, no se persiste en ninguna
columna.

```
Ahora:  V4 · ¿Cabe en lo comprometido?
        informado + nuevo ≤ comprometido del mes
        la diferencia se muestra y solo puede cerrarse hasta 0
```

> Pendiente: la versión con este tope aún no está desplegada. Hoy el límite solo lo aplica la
> pantalla.

### V3 necesita la regla de días hábiles

El diagrama lista *«FUERA de jornada 08:30–17:18»* pero no dice de qué días. La regla del sistema
—`isCompensationDateAllowed`, con prueba de regresión propia— rechaza sábado y domingo, y el PA se
alineó a ella en esta sesión.

```
Ahora:  V3 · ...
        de lunes a viernes y FUERA de jornada 08:30–17:18
```

Contrasta a propósito con la **ejecución**, que sí admite fin de semana. Son reglas distintas.

### A8 — el respaldo ya tiene análisis, falta una decisión

Sigue parqueado y el diagrama acierta al marcarlo. Lo que cambió es que ya está resuelto dónde
guardarlo salvo una elección entre dos opciones; ver
[`integracion_pdf_justificacion.md`](integracion_pdf_justificacion.md). Cuando se implemente, **ENV
suma el bloqueo** que hoy figura como `⏸`.

---

## 2. Lo que el diagrama afirma y ningún procedimiento hace

### ENV promete revalidar V0 a V6; valida otras ocho cosas

Lo que `sg_epaguSecgen02` verifica de verdad:

| | |
| :--- | :--- |
| ✅ | parámetros presentes |
| ✅ | prestación existe, archivada y a su cargo |
| ✅ | la cuota existe y está en estado 1 o 3 |
| ✅ | la cuota tiene meses |
| ✅ | todos los meses tienen monto |
| ✅ | ningún mes dejó de estar disponible — anticoncurrencia |
| ✅ | la suma no excede el monto autorizado de la prestación |

Lo que el subproceso declara y **no** verifica:

| | |
| :--- | :--- |
| ❌ | *la compensación informada cubre la comprometida* |
| ❌ | *si es la última cuota, la ejecución terminó* |
| ❌ | *sin licencia ni permiso sin goce en el periodo* |
| ❌ | *revalida V0 a V6* — ninguna validación normativa corre dentro del PA |

El frontend sí vuelve a consultar los tags normativos y bloquea el botón, pero eso es el cliente:
una llamada directa a la API pasa igual. Ya estaba anotado en
[`backend_lo_que_falta.md`](backend_lo_que_falta.md) §2.1.

### V5 no existe en ningún PA

| Afirmación | Dónde vive realmente |
| :--- | :--- |
| cabe en el tope COMPLETO de la cuota | solo en la pantalla (`capExceeded`, agregado hoy) |
| suma ≤ monto autorizado disponible | ✅ sí, en `sg_epaguSecgen02` al enviar |
| suma ≤ saldo del centro de costo | **en ninguna parte** — y contradice a `SAL` |
| cada monto mayor que cero | ✅ `sg_fumeuSecgen02` y `sg_epaguSecgen02` |
| el contrato cubre los meses | solo como tag normativo en la pantalla |

**`SAL` y `V5` se contradicen entre sí.** `SAL` dice *informativo*; `V5` lo pone como bloqueo. Lo
implementado es informativo: la ficha es *«Centro de costo sin saldo · TODO»* y no bloquea, que es
además lo que fija el plan UX §15. Hay que sacarlo de V5.

### V6 no existe en ninguna parte

| Afirmación | Realidad |
| :--- | :--- |
| posterior al último mes ejecutado | no se valida |
| planilla todavía abierta | no se valida |
| 2ª cuota el mismo mes: avisa y pide causal | no existe |

`sg_epagiSecgen01` solo comprueba que el año esté entre 2000 y 2100 y el mes entre 1 y 12. La
pantalla deriva *Pago corriente / Pago atrasado*, pero es una etiqueta, no un bloqueo.

### V2 — «mismo año de ejecución» no se valida

La comprobación de meses exige estado 1 y ejecución terminada. **No hay restricción de año**: nada
impide una cuota con meses de dos años distintos.

### ACOM — «bitácora» no se escribe

Nada registra quién hizo la transición. `sg_apso` con un `cod_flusol` propio del flujo de pagos está
propuesto pero no existe (ver `diagrama_pagos_actualizada.md` §8.3).

---

## 3. Lo que el diagrama acierta y conviene no tocar

- **`A5a` → `A6`**: en modalidad Fija el monto no es editable **pero igual se persiste**. Es
  obligatorio: `sg_epagsSecgen01` calcula el monto de la cuota como `sum(sg_fume.mto_apagar)`.
- **`RV` → `A6`** saltándose la selección de meses: correcto. `sg_epaguSecgen01` rechaza cambiar los
  meses de una cuota observada, y los montos sí se pueden tocar en estado 3.
- **`A9`**: *«los meses NO se comprometen»* al guardar. Verificado en base.
- **`ACOM`**: cuota 1 → 2 y meses 1 → 2, con el detalle correcto de que al reenviar una observada
  los meses ya están en 2 y no se vuelven a tocar.
- **`A10` Confirmar el resumen**: ahora es real — el modal de envío muestra meses, montos,
  funcionario y destinatario (DGDP).
- **`V0`, `V1`**: son tags normativos de la pantalla; el diagrama no afirma que vivan en un PA.

---

## 4. Propuesta de ajuste al diagrama

Dos opciones, según para qué sirva el diagrama.

**Si documenta el flujo objetivo**, basta corregir V3 y V4 (§1) y marcar V5, V6, la revalidación de
ENV y la bitácora con el mismo `⏸` que ya lleva `A8`. Así se distingue lo construido de lo decidido
pero pendiente.

**Si documenta lo que hoy corre**, hay que quitar V6 entero, recortar V5 a sus dos reglas reales,
sacar de ENV las cuatro líneas que no verifica y eliminar «bitácora» de ACOM.

Recomiendo la primera: el diagrama vale como contrato de lo que debe existir, y marcar lo pendiente
es más útil que borrarlo. Pero conviene que el `⏸` aparezca, porque hoy se lee como si todo eso ya
estuviera operando.
