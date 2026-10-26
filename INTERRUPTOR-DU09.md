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

## Los seis puntos

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
| 6 | `cambios_pa/sg_ccto/sg_cctosSecgen05.sql` | invertir los **dos** pares rotulados `CRITERIO DU288` |

Los puntos **1 y 2 se encienden juntos**: el saldo bloquea en dos capas, y
dejar una encendida y la otra apagada deja la pantalla en verde y el envío
fallando con un 422.

Los puntos **3 a 6** exigen redesplegar esos PA, y además sincronizar el `.txt`
con el `.sql` (son idénticos, en CRLF y ASCII de 7 bits).

### El punto 6, el único fuera de `sg_epag`

`sg_cctosSecgen05` es de donde se deriva el privilegio
`provision-payment-manage`, así que conviven dos definiciones de «centro de
costo afecto a DU288»:

| | Definición |
| :--- | :--- |
| activa hoy | `cod_tfinan in (21, 44)` — deducida del tipo de financiamiento |
| comentada | `afec_du9 = 'S'` — la marca explícita del centro de costo |

La marca explícita es la definitiva, pero hoy `fin21_db..es_ccto` la tiene nula
en todos los centros vigentes. Con el filtro por `afec_du9` activo el PA devuelve
cero filas para cualquier rut —sin error y en milisegundos—, y eso apaga el flujo
completo: no aparece el menú de prestaciones por pagar, no se consulta la bandeja
de gestión de pago y el formulario no ofrece ningún centro de costo.

**Los dos pares juntos, no uno.** Cambiar solo el `where` deja el indicador
`ind_financiamiento_du288` en `'N'` para filas que el PA sí devolvió, y la
validación normativa del formulario las rechaza por financiamiento incompatible.
Cambiar solo el indicador deja entrar centros que no son DU288.

Y va junto con los puntos 3 a 5: la misma columna vacía que bloquea crear una
cuota deja sin privilegio al jefe de proyecto, así que encender uno sin el otro
deja el flujo a medias.

---

## Antes de encender el 3, 4, 5 y 6

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
