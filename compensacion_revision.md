# Compensación realizada — revisión de validaciones y modelo visual

**Fecha:** 05-10-2026
**Motivo:** al implementar el CRUD apareció un 422 que no debía existir.

---

## 1. El error encontrado — corregido

```json
{ "statusCode": 422, "message": "Error: El tramo se superpone con una compensacion comprometida" }
```

**Era un error de diseño.** `sg_fuc2iSecgen01` rechazaba un tramo realizado que se solapara con uno
comprometido en `sg_fuco`.

Eso invierte el propósito de la tabla:

| | |
| :--- | :--- |
| `sg_fuco` | lo que el funcionario **se comprometió** a compensar — un plan |
| `sg_fuc2` | lo que **efectivamente** compensó — la ejecución de ese plan |

Si cumplió exactamente lo comprometido, el tramo realizado es **idéntico** al comprometido: misma
fecha, mismas horas. La validación rechazaba justo el caso más común y correcto.

El razonamiento al escribirla fue *"dos horas son dos horas"*, pero eso aplica a dos tramos
**realizados** —no se puede estar en dos lugares a la vez—, no a un realizado contra su propio
compromiso. Son el mismo tiempo: uno planificado, otro ejecutado.

**La validación fue eliminada.** El solape entre tramos realizados se mantiene, que sí es correcto.

---

## 2. Validaciones vigentes de `sg_fuc2iSecgen01`

| # | Valida | Correcta |
| :-- | :--- | :--- |
| 1 | Datos completos | sí |
| 2 | La prestación está a su cargo | sí |
| 3 | Modalidad DU288 | sí |
| 4 | `dentro_jor in ('S','D')` — requiere compensar | sí |
| 5 | El mes existe | sí |
| 6 | El mes admite cambios — estado 1, o 2 con cuota observada | sí |
| 7 | Horas de inicio y término distintas | sí |
| 8 | Dentro del período autorizado | sí |
| 9 | No es feriado nacional | sí |
| 10 | **Fuera** de la jornada institucional 08:30–17:18 | sí |
| 11 | Sin solape con otro tramo **realizado** de la persona | sí |
| ~~12~~ | ~~Sin solape con lo comprometido~~ | **eliminada** |

---

## 3. Incongruencia en los datos — las dos listas no son simétricas

La pantalla cruza comprometido contra realizado, pero las dos fuentes no entregan lo mismo.

| | Comprometida · `sg_fucosSecgen01` | Realizada · `sg_fuc2sSecgen01` |
| :--- | :--- | :--- |
| Identificador | `id_funprse` | `id_funprse` |
| **Mes** | **no tiene** | `corr_fume` · `ano_prop` · `mes_prop` |
| Fecha | `fec_compro` | `fec_comrea` |
| Horas | `hora_ini` · `hora_ter` | `hora_ini` · `hora_ter` |
| Estado del mes | — | `cod_estfum` |

**`sg_fuco` no tiene dimensión de mes.** La compensación comprometida pertenece a la prestación
completa, no a un mes: así quedó en resolución y no se toca.

### Qué implica para la pantalla

Para mostrar *"comprometido de septiembre"* hay que **derivar el mes desde `fec_compro`**, porque el
dato no viene. Dos consecuencias:

1. El filtro por mes de lo comprometido se hace **en el cliente**, no en el servidor.
2. Un tramo comprometido que cruza medianoche de fin de mes —empieza el 30 y termina el 1— pertenece
   a dos meses. Hay que decidir a cuál se imputa: propongo **el mes de inicio**, que es el criterio
   que ya usa el PA al guardar (`fec_compro` lleva la hora de inicio incrustada).

### Lo que el backend ya normaliza

`selectCommittedCompensations` renombra `fec_compro` a `fec_comrea` antes de mapear, de modo que
ambas listas llegan al frontend con el campo `compensationDate`. **La forma es la misma; el
contenido no.** En las comprometidas, `monthSequence` viene vacío.

---

## 4. Modelo visual — orden y secciones

### El contraste, lado a lado

```
Comprometido 8 h        Informado 8 h        Diferencia 0 h

┌── Comprometido en la resolución ──┐  ┌── Realizado ──────────────────┐
│  Lu 07/09   09:00 – 11:00   2 h   │  │  Lu 07/09   09:00 – 11:00  2h │
│  Mi 09/09   09:00 – 12:00   3 h   │  │  Mi 09/09   08:30 – 11:30  3h │
│  Vi 11/09   15:00 – 18:00   3 h   │  │  Ju 10/09   15:00 – 18:00  3h │
└───────────────────────────────────┘  └───────────────────────────────┘
```

Dos columnas y no una lista precargada: lo que se audita es la **diferencia**. Una sola lista
editable con los valores ya puestos invita a confirmar sin mirar.

### Orden de los bloques

| | Bloque | Por qué ahí |
| :-- | :--- | :--- |
| 1 | Totales — comprometido · informado · diferencia | el resumen antes del detalle; es lo que decide si se puede enviar |
| 2 | Las dos listas | el detalle que explica el total |
| 3 | Calendario del mes | la herramienta de edición, al final |

La **diferencia** va arriba a propósito. Es el único número que cambia la decisión del usuario.

### Estados que la sección debe cubrir

§8 del estándar exige los seis. Faltan de definir tres:

| Estado | Qué muestra |
| :--- | :--- |
| Cargando | esqueleto de las dos columnas |
| **Vacío sin compromiso** | *"Esta prestación no comprometió compensación para este mes"* — no es error |
| **Vacío sin informar** | *"Aún no se informa compensación realizada"* + acción disponible |
| Cargado | el contraste |
| **Diferencia negativa** | informado < comprometido → advertencia, no bloquea acá |
| Solo lectura | el mes ya no admite cambios |

El segundo y el tercero se confunden fácil y significan cosas opuestas: uno dice *no corresponde*,
el otro *falta hacerlo*.

### Dónde no aparece la sección

Si `dentro_jor` no es `S` ni `D`, la sección **no se dibuja**. No es un vacío: es que no aplica.
Mostrarla deshabilitada sugeriría que falta algo.

---

## 5. Lo que queda por decidir

| | Pregunta | Afecta |
| :-- | :--- | :--- |
| 1 | ¿A qué mes se imputa un tramo comprometido que cruza fin de mes? | el filtro del cliente |
| 2 | ¿Compensar **de más** también se marca como diferencia? | el color del total |
| 3 | ¿El bloqueo del envío es por mes o por cuota? | el mensaje y qué puede sacar el usuario |

La **1** la propongo resuelta por mes de inicio. Las otras dos siguen abiertas desde antes.

---

## 6. Qué revisar en la implementación en curso

- [ ] Redesplegar `sg_fuc2iSecgen01` sin la validación eliminada
- [ ] Probar el caso *"cumplió exactamente lo comprometido"* — era el que fallaba
- [ ] Verificar que el filtro por mes de lo comprometido se haga en el cliente
- [ ] Distinguir los dos estados vacíos
- [ ] Ocultar la sección completa cuando `dentro_jor` no lo requiere

---

## 7. Revisión sobre la vista en ejecución — 05-10-2026

Hallazgos al recorrer `/pagos/211?funcionario=7` con la sección ya implementada.

### 7.1 La compensación es de lunes a viernes — el PA estaba más suelto

El frontend restringe la compensación a días hábiles desde resolución, y no por omisión:

| Dónde | Qué hace |
| :--- | :--- |
| `isCompensationDateAllowed` | `if (dayOfWeek === 0 \|\| dayOfWeek === 6) return false` |
| `isCompensationIntervalValid` | exige que **todo** segmento caiga en día hábil |
| `weekendExecutionSchedule.test.cjs` | *"compensation is still rejected on Saturday and Sunday"* |

El último es una prueba de regresión explícita, y contrasta a propósito con la **ejecución**, que sí
admite fin de semana. Son reglas distintas y el proyecto ya las distingue.

`sg_fuc2iSecgen01` sólo comprobaba el solape con la jornada 08:30–17:18 de lunes a viernes, de modo
que **aceptaba un sábado**: ningún tramo de fin de semana cae dentro de esa ventana. El PA era más
permisivo que la pantalla.

**Se alineó el PA**, no la vista: la regla del frontend es la desplegada y la que está cubierta por
pruebas. En la codificación del PA `0` es lunes, así que `5` y `6` son sábado y domingo.

```sql
if @dia_ini >= 5 or (@hora_ter < @hora_ini and @dia_ter >= 5)
```

La segunda condición cubre el tramo que cruza medianoche desde un viernes, que el frontend también
rechaza por el requisito de "todo segmento hábil".

### 7.2 Tres variables CSS que no existen

El componente usaba `--pds-du288-surface`, `--pds-du288-primary-soft` y `--pds-du288-radius-sm`.
**Ninguna está definida**: el catálogo tiene `--pds-du288-radius`, `--pds-du288-info-soft` y no tiene
un token de superficie. Sin definición ni valor de respaldo, `border-radius` caía a 0 y los fondos
quedaban transparentes, así que el calendario se veía cuadrado y sin panel.

Afectaba también a `Du288InstallmentFormSection` y `Du288PaymentAntecedentsTab`.

### 7.3 Dos "saldos" distintos en la misma pantalla

| Rótulo | Sujeto |
| :--- | :--- |
| Saldo por gestionar · $141.111 | lo que resta pagar de **la prestación** |
| Saldo insuficiente | fondos del **centro de costo** |

El dato era correcto —el backend devuelve `isValid: false`, `saldo: 0`— pero leído junto se
contradecía. Las fichas ahora nombran su sujeto: **Centro de costo sin saldo**.

### 7.4 Lo demás que se corrigió

| | Antes | Ahora |
| :--- | :--- | :--- |
| Columna Mes | `202609` | `period` es numérico y sirve para ordenar; se muestra con `getMonthYearLabel` |
| Conteos | `0 tramo(s) registrado(s)` | concordancia de número, igual que en la bandeja |
| Diferencia | número rojo **y** barra amarilla | un estado, un color |
| Duración | reimplementada, devolvía 0 al cruzar medianoche | `getCompensationDuration`, que ya lo resuelve |
| Día inicial | el 1 del mes | el primer día con compromiso pendiente |
| Jornada | el 422 lo explicaba después | se avisa en el formulario y se bloquea antes de llamar |
| Error del PA | aparecía fuera de pantalla | se desplaza a la vista |
| Contraste | sólo "Realizada" | las dos listas, como pedía §4 |

### 7.5 La regla de cierre: por totales, no por pareo

Decidido el 05-10-2026. Un tramo informado **no tiene por qué coincidir** con el comprometido que lo
origina: puede ir otro día y otro horario. Por eso no se intenta parear tramo a tramo, que además no
es posible: `sg_fuc2` no guarda a qué tramo de `sg_fuco` corresponde cada registro.

Lo que se compara son las **sumas del mes**:

```
informado <= comprometido        la diferencia baja hasta 0 y ahí se detiene
```

| | |
| :--- | :--- |
| Comprometido del mes | suma de `sg_fuco` cuyo `fec_compro` cae en `ano_prop`/`mes_prop` |
| Informado del mes | suma de `sg_fuc2` del mismo `corr_fume` |
| Saldo | la resta; cuando llega a 0 no se admiten más tramos |

El tramo comprometido que cruza fin de mes se imputa al mes de inicio, igual que en §3, porque
`datepart` sobre `fec_compro` conserva el día.

**Dónde vive.** El tope es del PA (`sg_fuc2iSecgen01`): dos sumas, el saldo y el rechazo con las
horas que faltan. La pantalla deshabilita el botón y dice el motivo, pero quien manda es el PA.

Lo que esto elimina: el marcador *"Registrado"* sobre un tramo comprometido comparaba fecha y hora
exactas, es decir, un pareo. Con horario libre esa igualdad no significa nada y se quitó. Los atajos
quedaron atados al saldo, no a la coincidencia:

| Atajo | Cuándo aparece |
| :--- | :--- |
| Confirmar como realizado | mientras ese tramo quepa en el saldo |
| Cargar todo lo comprometido | solo con 0 h informadas, así cuadra exacto |

Comprobado en vivo con 4 h comprometidas en un solo tramo:

```
Comprometida   Mié 09/09  17:18 – 21:18   4 h
Realizada      Jue 10/09  18:00 – 20:00   2 h
               Vie 11/09  18:00 – 20:00   2 h
Diferencia     0 h · Al día
```

Distinto día, distinto horario, y la compensación queda cerrada. Intentar un tercer tramo se rechaza.

### 7.6 Sigue pendiente

- [ ] **Redesplegar `sg_fuc2iSecgen01`.** La versión en base ya acepta el caso que fallaba, pero
      todavía le faltan la regla de días hábiles (§7.1) y el tope por totales (§7.5). Hasta
      desplegarlo, ese tope solo lo aplica la pantalla.
- [x] ~~Decidir si compensar **de más** se marca.~~ Ya no ocurre: se impide pasar de 0.
- [ ] Decidir si el bloqueo del envío es por mes o por cuota.
