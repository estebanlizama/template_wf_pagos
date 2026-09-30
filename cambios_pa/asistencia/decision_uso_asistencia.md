# Decisión — uso del registro de asistencia en el WF de pagos

**Fecha:** 2026-09-30
**Acordado con:** Alex, Jose Luis · informado a Jaime
**Estado:** cerrada

---

## Decisión

**El registro de asistencia no se usará para validar automáticamente la ejecución de una
prestación de servicios.**

Queda como **información adicional**, disponible para el revisor, que la pondera según su
criterio. No bloquea el envío de una solicitud de pago ni determina por sí solo si un mes es
pagable.

---

## Fundamento

El registro de asistencia **no contiene los identificadores necesarios** para atribuir el tiempo
trabajado a una prestación concreta:

| Falta | Consecuencia |
| :--- | :--- |
| Horario del prestador | No se puede saber qué tramo del día correspondía a la prestación |
| Tipo de ingreso | Una marca no distingue si el tiempo fue prestación, compensación o carga habitual |
| Vínculo con la prestación | `sp_as01` no tiene ninguna referencia a `sg_fups` ni a la actividad |

El caso que lo ilustra: el 08/01/2016 la salida fue a las 18:05 con turno hasta las 17:20. Esos
45 minutos existieron, pero el dato no dice a qué se dedicaron.

A eso se suma que el módulo aplica una **ventana de horario flexible**: entrar después de la hora
y salir más tarde puede no representar tiempo adicional, sino recuperación de la entrada tardía.
Sin conocer esa regla con precisión, cualquier cálculo de excedente es aproximado.

---

## Qué sí se hace con el dato

| Uso | Cómo |
| :--- | :--- |
| **Mostrar el detalle diario** al revisor | tabla con marca, turno, estado, ausencias, justificaciones y feriados |
| **Cruzar con lo propuesto en la resolución** | comparar los días comprometidos en `sg_fuho` contra los días con actividad registrada |
| **Comparar lado a lado** | una tabla con lo comprometido y lo registrado, para que el revisor lo pondere |
| **Aportar antecedentes de contexto** | licencias, permisos, feriados y receso del periodo |

La información que el PA ya entrega **es suficiente para estos usos**. No requiere identificadores
adicionales ni desarrollo nuevo en SISPER.

---

## Qué cambia respecto de lo documentado antes

| Antes | Ahora |
| :--- | :--- |
| `V2h` *¿cumplió el trabajo comprometido?* — compuerta **bloqueante** | **informativa**: se muestra, no detiene |
| `V2k` *¿la compensación quedó cumplida?* — impedía enviar | **informativa** |
| `HORAS_NO_ACREDITADAS` — severidad error | **advertencia** |
| `COMPENSACION_NO_ACREDITADA` — impedía enviar | **advertencia** |
| Q-I08 · *"si la compensación no se cumple no se puede enviar la solicitud"* | **superada** por esta decisión |
| Q-I04 · validar contra datos biométricos | se **consulta y muestra**, no se valida |
| Integración biométrica marcada ⚠️ como bloqueante | **resuelta**: existe y se usa como antecedente |

Los documentos que contienen esas marcas quedan desactualizados en ese punto:

- `diagramas/wf_pagos_sistema_completo.md` — §4 y el subproceso de ENVIAR
- `diagramas/wf_pagos_implementable.md` — semáforo de capacidades
- `diagramas/wf_pagos_completo_roles.md` — compuerta de validación del cumplimiento
- `cambios_pa/asistencia/validaciones_ejecucion_y_compensacion.md` — el planteamiento de
  validación automática

---

## Lo que sigue siendo automático

Esta decisión **no afecta** a las validaciones que no dependen de atribuir tiempo:

| Validación | Estado |
| :--- | :--- |
| Licencia médica en el periodo | automática — `sp_as21` grupo 2 |
| Permiso sin goce | automática — `sp_as21` grupo 1, cod 2 |
| Feriado y receso universitario | automática — `es_cfer` + `es_tfer` |
| Descuento proporcional por días de ausencia | automático, sobre el conteo de días |

La diferencia es clara: **una ausencia es un hecho del funcionario en una fecha**, y no necesita
atribuirse a la prestación. El tiempo trabajado sí, y por eso queda a criterio del revisor.

---

## Consecuencia para el diseño

La acreditación de que el trabajo se ejecutó descansa en:

1. **El PDF de respaldo** — evidencia documental de la actividad, obligatoria al enviar
2. **La declaración del jefe de proyecto** — que registra en la solicitud
3. **La revisión de DGDP** — con la asistencia a la vista como antecedente

El registro de asistencia es el tercer elemento, y su peso lo define el revisor caso a caso.
