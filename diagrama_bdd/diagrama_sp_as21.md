# `sisper_db..sp_as21` — ausencias del día

Detalle de `sp_as01`. Registra qué ausencias afectaron a un día concreto.

---

## Estructura

| Columna | Qué es |
| :--- | :--- |
| `cod_asist` | FK al registro del día en `sp_as01` |
| `tip_agraus` | grupo de ausencia → `sp_eaus` |
| `cod_agraus` | código dentro del grupo → `sp_eaus` |
| `correlativ` | referencia al documento que autoriza la ausencia |

---

## La relación es 1:N, y está confirmado

```
cod_asist|tip_agraus|cod_agraus|correlativ|
     6241|         1|5         |109803    |   <- Vacaciones
     6241|         1|1         |1117      |   <- Permiso Administrativo
     6242|         1|5         |109803    |
     6242|         1|5         |01117     |
```

**Un mismo día puede tener varias ausencias de distinto tipo.** Cualquier consulta que asuma una
sola fila por `cod_asist` pierde información.

Es la razón por la que el PA de asistencia agrupa con cursor en vez de usar `UPDATE...FROM`.

---

## `correlativ` agrupa periodos

Las ausencias largas comparten `correlativ`: es el documento que las autoriza.

```
cod_asist 6070 a 6088   tip 1 / cod 5   correlativ 105999
```

Diecinueve días consecutivos de **Vacaciones** bajo la misma resolución. Para el WF de pagos eso
permite reconstruir el periodo completo sin recorrer día a día.

> Los valores no están normalizados: aparece `1117` y `01117` como si fueran distintos. No se
> puede usar como llave sin limpiar.

---

## Uso en el WF de pagos

Es la fuente de las dos validaciones que S0-013 daba por sin definir:

| Validación | Filtro |
| :--- | :--- |
| Licencia médica en el periodo | `tip_agraus = 2` |
| Permiso sin goce | `tip_agraus = 1 and cod_agraus = 2` |

El cruce es por `cod_asist`, o sea **por día**, que es exactamente la granularidad que la regla
necesita: un mes con licencia parcial se puede prorratear por días.

---

## Relaciones

```
sp_as01 ◄──── cod_asist ──── sp_as21 ──── (tip_agraus, cod_agraus) ────► sp_eaus
```
