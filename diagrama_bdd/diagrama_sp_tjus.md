# `sisper_db..sp_tjus` — tipos de justificación

Catálogo. El **motivo concreto** por el que un atraso, salida anticipada o marcaje faltante
quedó justificado.

---

## Estructura

| Columna | Qué es |
| :--- | :--- |
| `cod_tipjus` | PK |
| `des_tipjus` | descripción |

---

## Contenido

| cod | Descripción | Naturaleza |
| :---: | :--- | :--- |
| 1 | Tramites Bancarios | ausencia personal |
| 2 | Tramites Isapres | ausencia personal |
| 3 | Tramites AFP | ausencia personal |
| 4 | Tramite  Contraloria | ausencia personal |
| 5 | Tramite Medico | ausencia personal |
| 6 | Tramite Personal | ausencia personal |
| 7 | Reunion de trabajo | **estuvo trabajando** |
| 8 | Demora en trayecto | ausencia justificada |
| 9 | Problemas de Saludl | ausencia justificada |
| 10 | Capacitacion Externa | **estuvo trabajando** |
| **11** | **Error en  Biometrico** | **falló el registro** |
| 12 | Eventos UFRO | **estuvo trabajando** |
| **13** | **Sin Acceso a Reloj** | **falló el registro** |
| 14 | Autorizado por Jefatura | autorización genérica |
| **15** | **Olvida Marcar** | **falló el registro** |
| 16 | Comisión de Servicio | **estuvo trabajando** |

> Los textos vienen con erratas de origen: doble espacio en *"Tramite  Contraloria"* y
> *"Error en  Biometrico"*, y *"Problemas de Saludl"* con una ele de más. Se dejan tal cual: son
> el dato real.

---

## Tres familias, y sólo una es evidente

El catálogo mezcla situaciones que para el WF de pagos significan cosas distintas:

### Falló el registro, no la asistencia — 11, 13, 15

*Error en Biométrico*, *Sin Acceso a Reloj* y *Olvida Marcar* indican que **la persona sí
estuvo**: lo que falló fue el reloj o el marcaje.

Si el WF descarta esos días por no tener marca, **penaliza trabajo efectivamente realizado**.
Son el caso que obliga a no tratar la ausencia de marca como ausencia de trabajo.

### Estuvo trabajando, en otra parte — 7, 10, 12, 16

*Reunión de trabajo*, *Capacitación Externa*, *Eventos UFRO* y *Comisión de Servicio*: la
persona no estaba en su puesto pero sí cumpliendo funciones.

Para una prestación de servicios esto necesita decisión: el compromiso era ejecutar una
actividad específica, no estar en el edificio.

### Ausencia justificada — el resto

Trámites, demoras, problemas de salud. La persona no trabajó, pero la ausencia está autorizada.

---

## Lo que hay que definir

El decreto no distingue estos matices. Para el WF de pagos hay que decidir, por familia:

| Familia | ¿Acredita ejecución? |
| :--- | :--- |
| Falló el registro (11, 13, 15) | debería **sí** |
| Trabajando en otra parte (7, 10, 12, 16) | **por definir** |
| Ausencia justificada (1-6, 8, 9) | probablemente **no** |
| Autorizado por Jefatura (14) | **ambiguo** — no dice el motivo |

El 14 es el más incómodo: es un comodín sin causal, y no permite clasificar el día.

---

## Relación

```
sp_as31 ──── cod_tipjus ────► sp_tjus
```

Se combina con `sp_cjus` para formar el texto `"<tipo>/<categoria>"`.
