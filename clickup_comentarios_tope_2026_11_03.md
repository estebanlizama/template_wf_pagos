# Comentarios para ClickUp — tope por centro de costo (03-11-2026)

No se pudieron publicar automáticamente. Copiar cada bloque como comentario en
su tarjeta.

---

## [S0-003] Definir agregado de pago mensual

https://app.clickup.com/t/86e2kw6f6

**Decisión 03-11-2026 — el tope es por centro de costo y se aplica por cuota**

Precisa el comentario del 02-10 («saldo y tope deben evaluarse por centro de
costo»):

* **Tope por centro de costo.** Cada actividad (centro de costo) tiene su propio
  tope. Una prestación de otro centro de costo no lo consume.
* **Por cuota.** Cada cuota es individual para su mes de pago y dispone del tope
  completo (T-01, T-02, T-03).
* **Mes bloqueado.** En el mismo centro de costo, un mes queda tomado por esa
  cuota (C-09, Regla 11; en pago, `sg_epagiSecgen01`). En centros de costo
  distintos el mismo mes sí puede pagarse, cada uno con su tope, sin sumarlos.
  Con esto **T-05 no aplica entre centros de costo**.
* **Tope congelado** al hacer la solicitud en WF resolución (`sg_fups.mto_tope`);
  el pago mide cada cuota contra ese valor.

**Estado:** WF pagos ya lo aplicaba. En WF resolución se ajustaron la Regla 3
(tope mensual) y el cupo de 2 meses de pago para contar solo el mismo centro de
costo, en pantalla y servidor. Las 56 h, los choques de horario y la
compensación duplicada siguen cruzando todos los centros de costo, porque son
límites de la persona.

---

## [S0-013] Cuestionario maestro de requerimientos — WF de Pagos

https://app.clickup.com/t/86e2zrkh4

**Respuestas cerradas el 03-11-2026**

* **Q-C07 / Q-C08** — Dos cuotas en el mismo mes: en el **mismo** centro de
  costo no, el mes queda bloqueado para esa cuota. En centros de costo
  **distintos** sí, cada una con su propio tope, sin sumarse. El tope es por
  centro de costo, no por funcionario.
* **Q-C13 / Q-C14** — El tope lo fija la **solicitud en WF resolución** y queda
  congelado en `sg_fups.mto_tope`. El pago no lo recalcula.

Reemplaza la respuesta preliminar del 26-08 («cupo disponible del mes = tope −
pagos del funcionario en ese mes»): el cupo es del centro de costo, no del
funcionario.

Implementado en WF resolución y WF pagos; detalle en
`reglas_pagos/01_reglas_montos_por_tipo_de_flujo.md` §9.1.
