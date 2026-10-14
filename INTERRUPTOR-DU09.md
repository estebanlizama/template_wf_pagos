# INTERRUPTOR-DU09 — quitar antes de producción

> **Esto es temporal.** Se encendió el **14-10-2026** para poder probar el envío
> a DGDP de punta a punta mientras los centros de costo de prueba no tienen
> cargadas sus marcas presupuestarias. **No puede llegar a producción así.**

---

## Qué está apagado

Dos validaciones **se siguen mostrando** y **dejaron de impedir el envío**:

| Validación | Qué se ve | Qué hace hoy |
| :--- | :--- | :--- |
| Saldo del centro de costo | chip *Centro de costo sin saldo*, en rojo | no bloquea |
| Pertenencia a DU09 (`afec_du9`) | chip *Flujo DU09 sin informar*, advertencia | no bloquea |

**Lo que se apagó es el bloqueo, no el diagnóstico.** Los chips quedan a la
vista a propósito: si además se ocultaran, al volver a encenderlos aparecerían
problemas que llevaban semanas ahí sin que nadie los viera.

## Qué sigue bloqueando

Todo lo demás, sin cambios: contrato habilitado, cargo habilitado, asignaciones,
tope de la cuota, **centro de costo cerrado**, evidencia obligatoria, mes de pago
de la última cuota, saldo del monto total autorizado y los meses ya tomados por
otra cuota.

---

## Los cinco puntos

```bash
grep -rn "INTERRUPTOR-DU09" .
```

| # | Archivo | Qué hay que hacer |
| :-: | :--- | :--- |
| 1 | `sg-solicitudes-frontend/store/service-provision-payment-detail.js` | `BALANCE_VALIDATION_BLOCKS_SUBMISSION = true` |
| 2 | `sg-solicitudes-backend/src/controllers/service-provision/service-provision-payment.controller.ts` | `BALANCE_BLOCKS_SUBMISSION = true` |
| 3 | `cambios_pa/sg_epag/sg_epagiSecgen01.sql` | borrar las dos líneas del comentario que envuelve la guarda de `afec_du9` |
| 4 | `cambios_pa/sg_epag/sg_epaguSecgen01.sql` | lo mismo |
| 5 | `cambios_pa/sg_epag/sg_epaguSecgen02.sql` | lo mismo |

Los puntos **1 y 2 se encienden juntos**: el saldo bloquea en dos capas, y
dejar una encendida y la otra apagada deja la pantalla en verde y el envío
fallando con un 422.

Los puntos **3 a 5** exigen redesplegar los tres PA, y además sincronizar el
`.txt` con el `.sql` (son idénticos, en CRLF y ASCII de 7 bits).

---

## Antes de encender el 3, 4 y 5

Correr `datos_base/06_marcas_du09_centro_costo.sql`, que **no modifica nada**:
lista los centros de costo con prestaciones DU288 archivadas junto a sus marcas
y cuenta cuántos quedarían sin poder pagar.

Cargar `afec_du9 = 'S'` donde falte, **revisando caso a caso**: esa marca
habilita pagar con ese presupuesto. Encender la guarda con la columna vacía
vuelve a dejar esos centros de costo bloqueados, que es justo el problema que el
interruptor vino a esquivar.

---

## Cómo se delata solo

Mientras el punto 1 esté apagado, la sección de validaciones muestra un aviso
amarillo con la fecha y la instrucción de buscar `INTERRUPTOR-DU09`. Desaparece
solo al poner la constante en `true`: no hay nada que acordarse de borrar en la
plantilla.

---

## Verificación al encender

1. El aviso amarillo desaparece de la pantalla.
2. Con un centro de costo sin saldo, el botón de enviar queda deshabilitado y el
   chip *Centro de costo sin saldo* vuelve a contarse entre los bloqueantes.
3. Un `POST` directo a
   `/requests/service-provision/payments/provisions/{id}/installments/{n}/submit`
   devuelve 422 con el motivo del saldo.
4. Con `afec_du9` vacío, los tres PA rechazan con
   *«El centro de costo no pertenece al flujo DU09»*.
