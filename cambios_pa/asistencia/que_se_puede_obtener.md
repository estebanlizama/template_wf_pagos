# Qué se puede obtener del PA de asistencia

Inventario de lo que los datos permiten responder, para el WF de pagos.

---

## 1. Por día — lo que sale directo

| Pregunta | Columnas |
| :--- | :--- |
| ¿Existe el día? | siempre — `sp_as01` tiene una fila por día calendario |
| ¿Le correspondía trabajar? | `hora_ent_o` / `hora_sal_o` + `es_feriado` |
| ¿Trabajó? | `cod_estasi` = 2 Completo |
| ¿A qué hora llegó y salió? | `f_entrada` / `f_salida` |
| ¿Se atrasó, y cuánto? | `min_atraso` |
| ¿Salió antes, y cuánto? | `min_adelan` |
| ¿Trabajó de más? | `min_extras` |
| ¿Tomó colación? | `f_sal_int` / `f_ent_int` |
| ¿Por qué reloj marcó? | `id_lect_e` / `id_lect_s` |
| ¿Tiene marcaje exigible? | `ver_hora` |
| ¿Faltó, y por qué? | `sp_as21` → `sp_eaus` |
| ¿Estaba justificado? | `sp_as31` → `sp_tjus` + `sp_cjus` |
| ¿Era feriado o receso? | `es_feriado` + `cod_tipfer` |

**Trece dimensiones por día.** Ninguna requiere integración nueva.

---

## 2. Los cuatro motivos de ausencia que el decreto necesita

`sp_eaus` los separa por grupo, y cada uno tiene una consecuencia distinta:

| Situación | Filtro | Consecuencia en el pago |
| :--- | :--- | :--- |
| **Licencia médica** | `tip_agraus = 2` | el día no se paga — 7 tipos distintos |
| **Permiso sin goce** | `tip_agraus = 1, cod_agraus = 2` | el día no se paga |
| **Vacaciones** | `tip_agraus = 1, cod_agraus = 5` | por definir |
| **Comisión de servicio** | `tip_agraus = 3` | trabajó, en otro lugar |

Y el detalle es **por día**, no por mes. Eso permite prorratear: un mes con 10 días de licencia
descuenta 10/30, no el mes completo.

---

## 3. El día se trabajó aunque no haya marca

Tres tipos de justificación dicen que **falló el registro, no la asistencia**:

```
sp_tjus  11  Error en  Biometrico
         13  Sin Acceso a Reloj
         15  Olvida Marcar
```

Sin considerarlos, el WF penalizaría días efectivamente trabajados. Es la diferencia entre
*"no hay marca"* y *"no trabajó"*.

Y otros cuatro dicen que trabajó en otra parte: *Reunión de trabajo*, *Capacitación Externa*,
*Eventos UFRO*, *Comisión de Servicio*.

---

## 4. Trabajo en receso — acreditable

```
es_feriado = 'S'  and  cod_tipfer = 2  and  cod_estasi = 2
```

Un solo predicado responde *"¿trabajó durante el receso universitario?"*. En los datos reales
aparecen tanto los bloques de receso como días feriados con marca completa.

Es la evidencia que el decreto pide para pagar receso, y **está disponible hoy**.

> `cod_tipfer = 3` (Suspensión de Actividades Lectivas) es distinto: no hay clases pero la
> universidad funciona. No debería bloquear el pago.

---

## 5. Agregados del mes — sobre el mismo detalle

```
dias habiles          es_feriado = 'N' and cod_diasem between 1 and 5
dias trabajados       cod_estasi = 2
dias incompletos      cod_estasi = 3
dias sin marca        cod_estasi = 0 and es_feriado = 'N'
minutos trabajados    sum(min_marcados) - colacion
minutos de atraso     sum(min_atraso)
minutos extra         sum(min_extras)
dias de licencia      tie_ausenc = 'S' and tip_agraus = 2
dias en receso        es_feriado = 'S' and cod_tipfer = 2 and cod_estasi = 2
```

Con eso se arma el contraste contra el horario comprometido en la resolución.

---

## 6. La validación de cumplimiento, completa

```
por cada dia comprometido en la resolucion:

   ¿es feriado?
      tipo 2 receso  → solo cuenta si cod_estasi = 2      → trabajo en receso
      tipo 1 o 3     → no era exigible
   ¿hay ausencia?
      grupo 2        → licencia      → descuenta el dia
      grupo 1 cod 2  → sin goce      → descuenta el dia
      grupo 1 cod 5  → vacaciones    → por definir
      grupo 3        → comision      → por definir
   ¿hay justificacion de registro fallido? (11, 13, 15)
      si             → el dia cuenta como trabajado
   ¿cod_estasi?
      2 Completo     → comparar min_marcados vs lo comprometido
      3 Incompleto   → ambiguo
      0              → no trabajo
      1 Editado      → revisar
      4 Error        → dato invalido
```

---

## 7. Lo que **no** se puede obtener

| No responde | Por qué |
| :--- | :--- |
| **¿Trabajó en la actividad comprometida?** | El reloj registra presencia, no qué hizo. La prestación compromete una actividad específica |
| **¿Estuvo en el lugar de la prestación?** | `id_lect_e` / `id_lect_s` identifican el reloj — podría aproximarse si los lectores están asociados a una ubicación, pero eso no está verificado |
| **¿Cuánto estuvo un día Incompleto?** | Sólo hay una marca. No es deducible |
| **¿Cuál registro vale cuando hay dos?** | Se encontraron 11 días con dos filas. El dato no dice cuál prima |
| **¿El día Editado es confiable?** | Fue corregido a mano; no viene del reloj |

La primera es la limitación de fondo: **la asistencia acredita que estuvo, no que hizo lo
comprometido**. El PDF de respaldo sigue siendo necesario.

---

## 8. Lo que hay que decidir antes de escribir la regla

| # | Decisión |
| :-- | :--- |
| 1 | **Días duplicados** — ¿cuál registro prima? |
| 2 | **Estado 3 Incompleto** — ¿acredita, no acredita, o va a criterio de DGDP? |
| 3 | **Estado 1 Editado** — ¿sirve como evidencia objetiva? |
| 4 | **Vacaciones** — ¿interrumpen la ejecución de la prestación? |
| 5 | **Comisiones** — trabajó, pero no en lo comprometido |
| 6 | **Feriado tipo 3** — no debería bloquear, hay que dejarlo escrito |
| 7 | **Justificaciones de registro fallido** — deberían acreditar el día |

Las tres primeras son las que impiden cerrar la regla de acreditación.
