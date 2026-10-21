# Propuesta: choques de agenda entre prestaciones, extensión, cuotas y tope

Respuestas de implementación a cuatro definiciones nuevas:

1. no permitir ejecuciones ni compensaciones en horarios de **otras prestaciones**
   del mismo funcionario;
2. **avisar** cuando la extensión evaluada difiere de la decretada;
3. **proponer cuotas** cuando la prestación es de monto fijo y extendida;
4. el tope en extendido no se conoce: un mes puede ir en **$0** y aun así debe
   poder seleccionarse.

Fecha: 20-10-2026. Propuesta, sin código escrito.

---

## 1. Las tres tablas de tiempo, y lo que cada una permite hoy

```sql
sg_fuho (id_funprse, cod_diasem, correlativ, hora_ini, hora_ter)
   -- horario de EJECUCION. Patron SEMANAL: no tiene fechas, se repite
   -- cada semana del periodo de la prestacion.

sg_fuco (id_funprse, fec_compro, hora_ini, hora_ter)
   -- compensacion COMPROMETIDA. PK (id_funprse, fec_compro):
   -- un solo tramo por dia y prestacion.

sg_fuc2 (id_funprse, nro_cuota, fec_comrea, hora_ini, hora_ter)
   -- compensacion REALIZADA. PK incluye nro_cuota, asi que la PK por si
   -- sola NO impide repetir la misma fecha en otra cuota; lo impide el
   -- control de solapamiento del PA, que no filtra por nro_cuota.
```

**El dato clave para implementar esto:** `sg_fuho` es un patrón por día de
semana, no una lista de fechas. Entonces **no hay que expandir nada**: dada una
fecha concreta se saca su día de semana y se compara contra las filas de
`sg_fuho` de las prestaciones vigentes en esa fecha. Es un `join`, no una
expansión de calendario — que en ASE 12.5 habría sido el problema caro.

> **A verificar antes de escribir el PA:** la numeración de
> `sg_fuho.cod_diasem`. El PA de compensación usa `@dia_ini between 0 and 4`
> para lunes a viernes, o sea base 0 con lunes = 0. Hay que confirmar que
> `cod_diasem` use la misma convención y no 1 = domingo; un desfase de un día
> haría que el control bloquee los días equivocados, que es peor que no tenerlo.

---

## 2. Qué debe chocar con qué

| Se está registrando | Choca con | ¿Bloquea? | ¿Hoy lo controla? |
| :--- | :--- | :---: | :--- |
| Compensación | Compensación de la **misma** prestación (cualquier cuota) | Sí | **Sí** |
| Compensación | Compensación de **otra** prestación del mismo RUT | Sí | **No** |
| Compensación | **Ejecución** de otra prestación del RUT, ese día de semana | Sí | **No** |
| Compensación | **Ejecución** de la propia prestación | Sí | **No** |
| Compensación | Jornada institucional 08:30–17:18 | Sí | **Sí** |
| Ejecución (al decretar) | Ejecución de otra prestación del RUT | Sí | **No** |

Las cuatro filas en **No** son el alcance de esta propuesta. La última es del WF
de resolución y conviene tratarla aparte: cambia el momento de la validación (al
decretar, no al pagar) y afecta a un flujo ya certificado.

**Compensar mientras se ejecuta la propia prestación tampoco debería poder.** Hoy
no se controla y es el caso más fácil de producir sin querer: el horario de
ejecución y el de compensación son de la misma persona y nadie los cruza.

---

## 3. Cómo se implementa

### 3.1 Un PA de lectura: la agenda del funcionario

```sql
sg_agensSecgen01 @rut_person, @fec_desde, @fec_hasta
```

Devuelve **todos** los bloques de tiempo del RUT en el rango, de todas sus
prestaciones, etiquetados por origen:

| Columna | |
| :--- | :--- |
| `origen` | `EJECUCION` · `COMP_COMPROMETIDA` · `COMP_REALIZADA` |
| `id_funprse`, `nro_solici` | de qué prestación viene |
| `cod_ccto`, `des_ccto` | de qué centro de costo |
| `fecha` | concreta para compensación; para ejecución, la fecha resuelta del patrón |
| `cod_diasem` | día de semana |
| `hora_ini`, `hora_ter` | |
| `es_propia` | `S` si es de la prestación que se está mirando |

Sirve para las dos cosas: alimenta la vista y documenta la regla en un solo
lugar.

### 3.2 El control en los PA de escritura

En `sg_fuc2iSecgen01` y `sg_fuc2iSecgen02`, además del control actual, dos
`exists` más. Primero el de compensación, subiendo de la prestación al RUT:

```sql
/* Compensacion de CUALQUIER prestacion del mismo funcionario */
if exists (
    select 1
      from secgen_db.dbo.sg_fuc2 fc
     inner join secgen_db.dbo.sg_fups fu on fu.id_funprse = fc.id_funprse
     where fu.rut = @rut_funcionario          /* <-- antes: fc.id_funprse = @id_funprse */
       and fc.fec_comrea = @fecha
       and <mismo solapamiento horario que ya existe>
)
begin
    select 'Error: Ya existe compensacion registrada en ese horario en otra prestacion del funcionario' as msg
    return
end
```

Y el de ejecución, que es el nuevo:

```sql
/* Horario de EJECUCION de cualquier prestacion vigente del funcionario */
if exists (
    select 1
      from secgen_db.dbo.sg_fuho ho
     inner join secgen_db.dbo.sg_fups fu on fu.id_funprse = ho.id_funprse
     where fu.rut = @rut_funcionario
       and @fecha between fu.f_inicio and isnull(fu.f_termino, @fecha)
       and ho.cod_diasem = @dia_semana        /* derivado de @fecha */
       and <solapamiento horario>
)
begin
    select 'Error: El horario choca con la ejecucion comprometida de una prestacion del funcionario' as msg
    return
end
```

`@rut_funcionario` sale de `select rut from sg_fups where id_funprse = @id_funprse`.

**Los mensajes tienen que decir de qué prestación y centro de costo viene el
choque.** Un "ya existe compensación" sin decir dónde deja al jefe de proyecto
sin nada que hacer: no ve esa otra prestación en su pantalla.

### 3.3 La vista

En el modal de compensación, una franja de solo lectura: *"Ocupado por otras
prestaciones"*, con los bloques de la agenda que no son propios, y en el
calendario los días con choque marcados y no seleccionables. Sale de
`sg_agensSecgen01`, no hace falta dato nuevo.

### 3.4 Orden

El PA primero: cierra el agujero y protege el dato aunque la vista no esté. La
agenda en la vista después, porque un bloqueo sin explicación es peor que el bug
para quien lo sufre. Y antes de desplegar, contar los choques que ya existen —la
consulta está en `revision_compensacion_y_cuotas_2026-10-20.md` §5.

---

## 4. Extensión: avisar el cambio, no elegir en silencio

La definición nueva cambia el planteo. No alcanza con unificar la fuente: hay que
**comparar y avisar**.

| Valor | De dónde | Qué significa |
| :--- | :--- | :--- |
| **Decretado** | `sg_fups.ext_cuotas` | lo que la resolución autorizó |
| **Evaluado** | lo que el flujo de pago calcula hoy | con lo que se va a trabajar |

Si coinciden, se muestra el valor y nada más. Si difieren, una alerta visible:

> La resolución autorizó **extensión de cuotas** (hasta 12). El flujo de pago la
> está evaluando **sin extensión** (máximo 4). Revise antes de continuar.

Y además hay que decidir **con cuál se opera**. Mi recomendación: con el
decretado, porque es el acto administrativo; lo evaluado es una derivación. Si en
algún caso lo evaluado debe ganar, ese caso tiene que estar escrito.

El aviso va donde se decide, no solo en la tarjeta de contexto: junto al máximo
de cuotas, que es el número que cambia.

**Y sacar `con_topdu9` de la condición.** Mezclar *con tope DU09* con *extensión
autorizada* es parte de por qué hoy los dos bloques no coinciden.

---

## 5. Proponer cuotas en monto fijo + extendido

En monto fijo cada mes aporta `monto_mes`, que ya está decretado. Con la
extensión se conoce el máximo de cuotas. Entonces la propuesta es aritmética y se
puede calcular **entera en el frontend**, sin PA nuevo: solo pre-selecciona meses
y montos, y el usuario confirma.

Tres presets, no uno:

| Preset | Qué arma | Cuándo conviene |
| :--- | :--- | :--- |
| **Una cuota por mes** | tantas cuotas como meses, cada una con su monto decretado | pago mensual; usa todo el cupo de cuotas |
| **Agrupar por trimestre** | una cuota cada tres meses | menos trámite, montos mayores |
| **Todo en una** | una sola cuota con todos los meses disponibles | cierre, o período corto |

Reglas que la propuesta debe respetar, y mostrar si alguna la limita:

- no superar el **máximo de cuotas** autorizado;
- no superar el **tope mensual** cuando exista (ver §6);
- no incluir meses cuya ejecución no haya terminado — es la regla que ya aplica
  `availabilityOf`;
- la suma de todas las cuotas propuestas = total decretado.

**Siempre propuesta, nunca guardado automático.** Deja los meses marcados y los
montos cargados en el formulario, el usuario revisa y guarda. Si una regla
impide completar el preset, se muestra hasta dónde llegó y por qué.

---

## 6. Tope y meses en $0

Tu definición: en extendido no se sabe cómo se pagará, un mes puede ir en **$0**
porque no se ejecutó, y **el mes igual debe poder seleccionarse**.

Eso obliga a tres cambios, y uno de ellos es conceptual.

### 6.1 `tope = 0` significa "sin tope", no "tope cero"

Hoy se muestra `$0` y cualquier validación que compare contra él bloquea todo.
Hay que distinguir **0** de **no definido**: si no hay tope, la ficha dice
*"Sin tope definido"* y ninguna validación lo usa. Nunca mostrar `$0` como si
fuera un límite.

### 6.2 Un mes en $0 es válido y seleccionable

El monto del mes debe aceptar 0 sin desmarcar el mes ni invalidar la cuota. Es un
cambio chico, pero hay que revisar que ninguna regla asuma `monto > 0` para
considerar el mes incluido.

### 6.3 Lo conceptual: hoy faltan dos de los tres motivos

Cuando un mes no aporta su monto decretado, hay **tres** motivos distintos y el
sistema solo entiende uno:

| Motivo | Qué significa | Qué debe hacer la regla de pérdida |
| :--- | :--- | :--- |
| **No ejecutado** | el funcionario no prestó servicios ese mes | **nada** — no hay plata que recuperar, no debe exigir redistribuir |
| **Pospuesto** | el mes va en una cuota posterior | nada ahora; avisar que queda pendiente |
| **Recortado** | se paga menos de lo decretado y no hay dónde recuperarlo | **exigir** redistribución o confirmación explícita |

Hoy los tres se calculan igual y se nombran "pérdida". Por eso el panel dice
*"Quedan sin pagar $10.024.252"* y dos líneas más abajo *"9 meses quedan para la
cuota siguiente"*: está describiendo un pospuesto con el vocabulario de un
recorte.

**Propuesta:** un estado explícito por mes, que el usuario marca cuando pone $0 —
*no ejecutado* o *pospuesto*— y que el cálculo de pérdida respeta. "No ejecutado"
sale del total recuperable; "pospuesto" no bloquea pero queda listado.

Lo ideal sería derivar *no ejecutado* de los datos de ejecución en vez de
preguntarlo, pero eso depende de que la ejecución mensual esté registrada con esa
fidelidad. Mientras no lo esté, preguntarlo es más honesto que suponerlo.

---

## 7. Lo que falta definir

1. **Numeración de `sg_fuho.cod_diasem`** — §1. Es un dato, no una decisión, pero
   sin él el control de ejecución bloquea los días equivocados.
2. **¿La compensación comprometida (`sg_fuco`) de otra prestación también
   bloquea**, o solo la realizada (`sg_fuc2`)? Lo comprometido es un plan, no un
   hecho; bloquear por plan es más estricto y puede trabar casos legítimos.
3. **¿Con cuál se opera cuando la extensión difiere** — decretado o evaluado?
   (§4). Mi recomendación: decretado.
4. **¿"No ejecutado" se pregunta o se deriva?** (§6.3).
5. **Choques de ejecución entre prestaciones al decretar** — es del WF de
   resolución, flujo ya certificado. Decidir si entra en este alcance o va aparte.

---

## 8. Qué prestaciones y qué cuotas deben contar para el choque

La pregunta tiene **tres** respuestas, porque son tres orígenes distintos y cada
uno cuelga de algo distinto.

### 8.1 Estado de la SOLICITUD — aplica a los tres orígenes

`sg_fuho` y `sg_fuco` cuelgan de la prestación; `sg_fuc2` también, vía la cuota.
En todos los casos hay que preguntarse si esa solicitud representa un compromiso
real del funcionario.

| `cod_estsol` | | ¿Cuenta para el choque? |
| ---: | :--- | :--- |
| 5 | Borrador | **No** — no compromete a nadie |
| 1, 2, 3 | Enviada a validación · En revisión · En resolución | **No** para pagos (ver abajo) |
| 6 | Devuelta a corrección | **No** |
| 4 | Rechazada | **No** |
| 7 | Enviada a firma | **No** para pagos (ver abajo) |
| 8 | Resolución firmada | **Sí** |
| 9 | Resolución ingresada | **Sí** |
| 10 | Resolución pre-ingresada | **Sí** |
| 11 | **Archivada** | **Sí** |
| 12 | Agrupada | **A confirmar** — depende de qué conserva la agrupación |

**No alcanza con archivadas.** Si solo se mirara el 11, se podría compensar sobre
horas de una prestación ya **decretada y firmada** cuyo trámite administrativo
todavía no cerró. El compromiso nace con la firma, no con el archivo: el archivo
es el paso que habilita el **pago**, no el que crea la obligación horaria.

**Y el momento de validar importa más que el estado.** Son dos preguntas
distintas:

| Flujo | Qué se está evitando | Qué mirar |
| :--- | :--- | :--- |
| **Pagos** (compensar) | registrar horas que chocan con un compromiso vigente | solo 8-11 |
| **Resolución** (decretar) | *crear* el conflicto | 8-11 bloquea; 1, 2, 3, 7 **advierte** |

En pagos, una solicitud en trámite no le quita horas a nadie todavía: si se
rechaza, el bloqueo habría sido injusto. Al decretar sí conviene avisar, porque
ahí es donde el conflicto se origina y todavía se puede evitar.

**Y siempre con el filtro de período**, que ya está en §3.2: una prestación
archivada cuyo período terminó no bloquea fechas posteriores.

### 8.2 Estado de la CUOTA — solo para `sg_fuc2`

Esto no estaba en la pregunta y es donde está el problema real.

**`sg_epaguSecgen03` no toca `sg_fuc2` al rechazar una cuota.** Verificado: libera
los meses (`sg_fume.cod_estfum = 1`) y borra `sg_dpag`, pero las filas de
compensación quedan colgadas de `(id_funprse, nro_cuota)`.

Con el control nuevo por RUT, esas filas huérfanas **bloquearían las horas del
funcionario para siempre**, a nombre de una cuota rechazada que ya no existe en
ningún otro sentido. Hoy no se nota porque el control es por prestación y nadie
mira esas horas; en cuanto suba al RUT, se nota.

Entonces el control tiene que filtrar también por el estado de la cuota:

```sql
from secgen_db.dbo.sg_fuc2 fc
inner join secgen_db.dbo.sg_fups fu on fu.id_funprse = fc.id_funprse
inner join secgen_db.dbo.sg_epag ep on ep.id_funprse = fc.id_funprse
                                   and ep.nro_cuota  = fc.nro_cuota
where fu.rut = @rut_funcionario
  and ep.cod_estcuo <> 10          /* la rechazada no reserva horas */
  and ...
```

`cod_estcuo <> 10` es el mismo criterio que ya usa `sg_fupssSecgen18` para contar
cuotas creadas, así que no se inventa una regla nueva.

**Filtrar, no borrar.** Se podría limpiar `sg_fuc2` en `sg_epaguSecgen03` como se
hace con `sg_dpag`, pero esas filas son la evidencia de lo que el funcionario
informó y la revisión DGDP puede necesitarla. Mejor dejarlas y excluirlas del
cálculo. Eso sí: el filtro hay que aplicarlo **en todos los lugares donde se
cuentan horas compensadas**, no solo acá, o van a aparecer totales que no cuadran.

### 8.3 Resumen

| Origen | Filtro de solicitud | Filtro de cuota | Filtro de período |
| :--- | :--- | :--- | :--- |
| `sg_fuho` ejecución | 8-11 | — | sí |
| `sg_fuco` comprometida | 8-11 | — | sí |
| `sg_fuc2` realizada | 8-11 | `cod_estcuo <> 10` | sí |

### 8.4 Lo que falta definir

1. **`cod_estsol = 12` (Agrupada)**: ¿la prestación agrupada conserva su horario
   y su compromiso, o se traslada a la agrupadora?
2. **¿La cuota en estado 1 (Propuesta) reserva horas?** Es un borrador de cuota,
   pero la compensación informada en ella es un hecho declarado por el
   funcionario. Mi recomendación: que sí reserve —solo se excluye la rechazada—
   porque si no, dos borradores podrían declarar las mismas horas.
3. **Las filas huérfanas que ya existen**: conviene contar cuántas hay de cuotas
   rechazadas antes de activar el control, por el mismo motivo del §5.

---

## 9. Corrección de rumbo: se bloquea el compromiso, no el hecho

Las secciones 2, 3 y 8 plantean bloquear la compensación **realizada** cuando
choca con compromisos de otras prestaciones. Eso está mal orientado, y conviene
dejar escrito por qué.

**En la etapa de pago la compensación es trabajo ya realizado.** Se está
registrando un hecho, retrospectivamente. Bloquearlo porque otra prestación tiene
un compromiso en ese horario no evita nada: el funcionario ya trabajó esas horas.
Lo único que se consigue es impedirle declarar lo que hizo, y el dato queda peor
que antes — sin registrar.

**El conflicto se crea aguas arriba**, cuando se decreta una prestación cuyo
horario pisa el de otra vigente. Ése es el punto donde bloquear sirve, porque
todavía no ocurrió nada y se puede corregir.

### 9.1 Matriz corregida

| Se registra | Choca con | Acción | Por qué |
| :--- | :--- | :--- | :--- |
| Compensación **realizada** | Otra compensación **realizada** del RUT | **Bloquear** | dos hechos que se contradicen: nadie compensa la misma hora dos veces |
| Compensación **realizada** | Horario de ejecución de otra prestación | **Advertir** | el hecho ya ocurrió; el aviso es para que DGDP lo mire |
| Compensación **realizada** | Compensación **comprometida** de otra | **Advertir** | lo comprometido es un plan, no un hecho |
| Compensación **realizada** | Jornada institucional | **Bloquear** (ya existe) | regla normativa, no de agenda |
| **Al decretar** (resolución) | Compromisos vigentes de otras prestaciones | **Bloquear** | acá nace el conflicto y acá se evita |

Lo que queda bloqueado en pagos es solo **realizada contra realizada**. Todo lo
demás, en pagos, es advertencia visible y registrada: le da a DGDP el antecedente
para resolver, que es su trabajo.

### 9.2 ¿Hace falta el PA de agenda?

**Para bloquear, no.** El control de *realizada contra realizada* se resuelve con
el `exists` del §3.2 dentro del PA de escritura que ya existe — subir
`fc.id_funprse = @id_funprse` a `fu.rut = @rut_funcionario`, más el filtro
`cod_estcuo <> 10` del §8.2. Cero objetos nuevos.

**Para mostrar y advertir, sí**, pero es diferible. La alternativa sería que el
backend recorra las prestaciones del RUT llamando los PA existentes
(`sg_fuhosSecgen01`, `sg_fucosSecgen01`, `sg_fuc2sSecgen01`), que están acotados a
una solicitud cada uno: eso es un N+1 contra Sybase y escala mal.

Entonces el orden cambia:

1. **Ahora:** `exists` por RUT en el PA de escritura, solo realizada vs realizada.
   Sin PA nuevo.
2. **Después:** `sg_agensSecgen01` para la advertencia y la franja "ocupado por
   otras prestaciones" en el modal.
3. **Aparte:** el bloqueo al decretar, en el WF de resolución. Es el que de
   verdad evita el conflicto, y es un alcance distinto sobre un flujo ya
   certificado.

### 9.3 Otros casos que pueden afectar

Además de los choques de agenda, hay seis situaciones que hoy no se cruzan con la
fecha compensada:

| Caso | Hoy | Comentario |
| :--- | :--- | :--- |
| **Licencia médica / sin goce / inhabilidad** en la fecha compensada | No se cruza | `sg_fume` ya guarda `val_licmed`, `val_singoce`, `val_inabili` **por mes**; la compensación es por **día**. Compensar un día cubierto por licencia es contradictorio y hoy nada lo impide |
| **Feriado o receso institucional** | No se cruza | El calendario institucional ya existe en la vista; el PA no lo consulta |
| **Fecha fuera del período** de la prestación | A verificar | Debe caer entre `sg_fups.f_inicio` y `f_termino` |
| **Contrato vencido** a la fecha compensada | No se cruza | La persona puede haber terminado contrato antes de la fecha que declara |
| **Jornada institucional fija 08:30–17:18** | Hardcodeada | Si hay jornadas parciales o distintas, la regla no les aplica bien |
| **Cambio del horario decretado** después de informar | No se detecta | Si la resolución se modifica, la compensación informada deja de corresponder y nadie avisa |

Las dos primeras son las que más conviene mirar: son contradicciones de fondo —el
funcionario declara haber compensado un día en que estaba con licencia o en que
la Universidad no funcionaba— y el dato para detectarlas ya está en el sistema.

**Ninguna debería bloquear en pagos**, por el mismo criterio del §9: son hechos ya
ocurridos. Van como advertencia en la revisión DGDP, que es quien decide.

---

## 10. Licencias y feriados: ya hay decisión cerrada, y acota el §9.3

`cambios_pa/asistencia/decision_uso_asistencia.md` (30-09-2026, **estado: cerrada**,
acordada con Alex y José Luis, informada a Jaime) resuelve buena parte de esto.
Conviene leerla antes de proponer nada acá.

### 10.1 Lo que la decisión ya zanjó

**El registro de asistencia no valida automáticamente la ejecución.** Queda como
antecedente para el revisor. El fundamento es sólido: `sp_as01` no tiene cómo
atribuir el tiempo a una prestación concreta —no guarda el horario del prestador,
ni el tipo de ingreso, ni vínculo con `sg_fups`— y además el módulo aplica una
ventana de horario flexible que hace aproximado cualquier cálculo de excedente.

Por eso `V2h`, `V2k`, `HORAS_NO_ACREDITADAS` y `COMPENSACION_NO_ACREDITADA`
pasaron de bloqueantes a **informativas**, y la pregunta Q-I08 quedó superada.

**Pero la misma decisión separa un caso y lo deja automático:**

> **Lo que sigue siendo automático** — esta decisión no afecta a las validaciones
> que no dependen de atribuir tiempo:
> licencia médica (`sp_as21` grupo 2), permiso sin goce (`sp_as21` grupo 1 cod 2),
> feriado y receso universitario (`es_cfer` + `es_tfer`), descuento proporcional
> por días de ausencia.
>
> **Una ausencia es un hecho del funcionario en una fecha**, y no necesita
> atribuirse a la prestación. El tiempo trabajado sí, y por eso queda a criterio
> del revisor.

Ese párrafo es exactamente el argumento para cruzar la **fecha compensada** con
licencias y feriados: la compensación es por día, y una ausencia también.

### 10.2 El dato ya existe, con el grano correcto

`sp_as01sSecgen01 @rut, @f_inicio, @f_termino` devuelve, **por día y por RUT**:

| Columna | |
| :--- | :--- |
| `tie_licmed` | licencia médica ese día |
| `tie_singoce` | permiso sin goce |
| `tie_ausenc`, `res_ausen` | ausencia y su resolución |
| `tie_justif`, `excusa` | justificación |
| `es_feriado`, `cod_tipfer`, `des_tipfer` | feriado y su tipo |

No hace falta desarrollo nuevo en SISPER: la decisión lo dice explícitamente.

**El desajuste de grano es lo que falta cerrar.** Hoy el WF de pagos guarda esas
marcas en `sg_fume.val_licmed` / `val_singoce` / `val_inabili`, que son **por
mes**. La compensación es **por día**. Un mes marcado con licencia no dice qué
días, y un mes sin marca no garantiza que el día compensado estuviera limpio.

### 10.3 Lo que la decisión NO resuelve

La decisión trata la validación de la **ejecución** y el cálculo de
**descuentos**. No dice nada sobre si se puede **compensar** en un día en que el
funcionario estaba ausente. Es un caso adyacente a una decisión cerrada, no
cubierto por ella.

Y acá mi recomendación del §9.3 —*"ninguna debería bloquear en pagos"*— queda
**demasiado amplia**. Hay que separar dos cosas que no son iguales:

| Caso | Qué es | Propuesta |
| :--- | :--- | :--- |
| Compensar un día con **licencia médica** o **sin goce** | contradicción de hecho: el funcionario no estaba | **Bloquear**, por el mismo criterio de la decisión: es un hecho en una fecha, no requiere atribuir tiempo |
| Compensar un día **feriado o de receso** | la Universidad no funcionaba | **Advertir**: puede haber casos legítimos (trabajo remoto, recesos parciales) y el tipo de feriado importa |
| Compensar un día que **choca con ejecución** de otra prestación | atribución de tiempo | **Advertir** — es justo lo que la decisión dejó a criterio del revisor |

La tercera fila es la que la decisión cubre de forma directa, y confirma el §9:
el choque con horarios comprometidos **no** debe bloquear.

### 10.4 Lo que falta definir

1. **¿Compensar con licencia médica se bloquea o se advierte?** Mi recomendación
   es bloquear, pero es una regla nueva y no está en la decisión cerrada.
2. **¿Qué tipos de feriado importan?** `cod_tipfer` distingue; no es lo mismo un
   feriado legal que un receso universitario.
3. **¿Dónde se consulta?** `sp_as01sSecgen01` es de SISPER y el PA de
   compensación es de `secgen_db`. Hay que ver el costo de llamarlo en cada
   inserción, o si conviene traer el rango del mes una vez y validar en el
   backend.
4. **Actualizar `validaciones_ejecucion_y_compensacion.md`**, que la propia
   decisión marca como desactualizado en el punto de la validación automática.

---

## 11. Desglose: qué evalúa hoy la compensación y qué falta

### 11.1 Los cinco controles que existen

| # | Control | Alcance | Qué rechaza |
| :-- | :--- | :--- | :--- |
| 1 | Estado del mes / cuota | la prestación | si el mes no está en Propuesta y la cuota no está Devuelta |
| 2 | Jornada institucional | el día, 08:30–17:18 | compensar dentro de la jornada, lunes a viernes |
| 3 | Solapamiento **propio** | la prestación, todas sus cuotas | pisar un tramo ya informado en la misma prestación |
| 4 | Solapamiento **entre prestaciones** | el **RUT**, `cod_estcuo <> 10` | pisar un tramo informado en otra prestación *(aplicado 21-10)* |
| 5 | Tope mensual de horas | la prestación, ese mes | informar más de lo comprometido |

El tope (5) funciona así:

```sql
@min_compro = sum(minutos de sg_fuco)   -- comprometido, por ano_prop + mes_prop
@min_infor  = sum(minutos de sg_fuc2)   -- informado, por corr_fume
@min_saldo  = @min_compro - @min_infor  -- si <= 0, rechaza
```

> **A verificar:** los dos sumandos usan grano distinto. `@min_compro` filtra por
> **año y mes de `fec_compro`**; `@min_infor` filtra por **`corr_fume`**, el
> identificador del mes de ejecución. Si se admite compensar en un mes distinto
> al ejecutado —ejecutar en abril y compensar en mayo— los dos filtros dejan de
> hablar del mismo conjunto. Hay que confirmar si eso está permitido.

### 11.2 Lo que el control nuevo sí cierra, y lo que no

El caso *"justificar dos prestaciones con la misma compensación"* tiene **dos
formas**, y el control 4 cubre solo una:

| Forma | Ejemplo | ¿Cubierto? |
| :--- | :--- | :---: |
| **Mismas horas** | miércoles 17:18–23:59 informado en la prestación A y en la B | **Sí** |
| **Horas distintas, volumen imposible** | A: miércoles 17:00–23:00; B: miércoles 23:00–05:00 | **No** |

La segunda no se solapa, así que pasa los cinco controles. Son 12 horas de
compensación en un día, encima de la jornada institucional. Es físicamente
posible y laboralmente inverosímil, y hoy nada lo mira.

**La distinción de fondo: hoy se controla el *solape*, no el *volumen*.** El tope
que existe (5) es por prestación y por mes; no hay ningún máximo de horas **de la
persona** por día, por semana ni por mes. Dos prestaciones pueden sumar lo que
sea mientras no se pisen.

### 11.3 Qué se puede evaluar con lo que ya hay

Sin datos nuevos, con `sg_fuc2` + `sg_fups` + `sg_epag`:

| Evaluación | Cómo |
| :--- | :--- |
| Horas compensadas por el RUT en un día | suma de `sg_fuc2` de todas sus prestaciones, misma `fec_comrea` |
| Horas compensadas por el RUT en un mes | ídem, agrupando por año-mes |
| De qué prestación y centro de costo viene cada tramo | join a `sg_fups` → `sg_prse` → centro de costo |
| Si la prestación de origen está archivada o ejecutada | `sg_soli.cod_estsol` (8-11, §8.1) |

O sea: **el listado que pedís —las compensaciones de otros centros de costo para
ese funcionario— se puede construir hoy**, sin tocar el modelo. Lo que falta es
el PA de lectura por RUT (`sg_agensSecgen01`), porque todos los PA existentes
están acotados a una solicitud y recorrerlos desde el backend sería un N+1.

**Un máximo diario de horas sí requiere una definición nueva**: cuántas horas de
compensación puede acumular una persona en un día. No es un dato del sistema, es
una regla.

### 11.4 ¿Corresponde con lo planteado?

| Planteado | Estado |
| :--- | :--- |
| No justificar dos prestaciones con la misma compensación | **Cubierto** para horas idénticas o solapadas (control 4) |
| Mostrar las compensaciones de otros centros de costo | **Falta** — necesita `sg_agensSecgen01` |
| Acotarlo a prestaciones archivadas o ejecutadas | **Pendiente de aplicar**: el control 4 filtra por cuota (`cod_estcuo <> 10`) pero **no** por estado de la solicitud. Falta el filtro `cod_estsol in (8,9,10,11)` del §8.1 |
| Topes de compensación | Existe uno **por prestación y mes**; no hay ninguno por persona |

**El punto 3 es una omisión concreta del cambio que ya aplicamos.** Hoy el
control cruza contra compensaciones de cualquier prestación del RUT, sin mirar si
esa solicitud llegó a firmarse. Una prestación en borrador o rechazada no debería
reservar horas, y hoy las reservaría.

### 11.5 Lo que falta definir

1. **¿Hay un máximo de horas de compensación por día o por semana para una
   persona?** Sin eso, el caso de volumen (§11.2) no se puede controlar.
2. **¿Se puede compensar en un mes distinto al ejecutado?** Define si el grano
   mixto del tope (§11.1) es un bug o es intencional.
3. **¿El listado de otras prestaciones se muestra siempre, o solo cuando hay
   choque?** Siempre da contexto; solo-cuando-choca es menos ruidoso.

---

## 12. Mostrar el choque en el calendario e impedir el ingreso

Requisito: que al compensar se **vea** en el calendario qué días están ocupados
por otras prestaciones del funcionario, y que **no se pueda** ingresar ahí — en
la vista y en el PA.

El PA ya bloquea (control 4, §11.1). Falta la mitad visual, y para eso sí hace
falta leer por RUT.

### 12.1 Un PA acotado, no la agenda completa

El §3.1 proponía `sg_agensSecgen01`: toda la agenda del funcionario —ejecución,
comprometida y realizada— en un rango. Para **este** requisito alcanza con mucho
menos: solo las **realizadas de otras prestaciones**, del mes que se está
compensando.

```sql
sg_fuc2sSecgen03 @rut_person, @id_funprse, @ano, @mes
```

| Devuelve | |
| :--- | :--- |
| `fec_comrea`, `hora_ini`, `hora_ter` | el tramo ocupado |
| `id_funprse`, `nro_solici` | de qué prestación |
| `cod_ccto`, `des_ccto` | de qué centro de costo |
| `cod_estsol` | estado de esa solicitud |

Con los mismos filtros que el control de escritura, para que vista y PA no se
contradigan:

```sql
where fu.rut = @rut_person
  and fc.id_funprse <> @id_funprse      /* las propias ya se muestran */
  and ep.cod_estcuo <> 10               /* cuota rechazada no reserva */
  and soli.cod_estsol in (8, 9, 10, 11) /* firmada en adelante -- §8.1 */
  and datepart(yy, fc.fec_comrea) = @ano
  and datepart(mm, fc.fec_comrea) = @mes
```

Es un `select` sobre tablas que ya se cruzan en otros PA del módulo. No necesita
expandir calendarios ni tocar `sg_fuho`.

> **Y cierra la omisión del §11.4:** el `exists` que aplicamos el 21-10 filtra
> por `cod_estcuo` pero **no** por `cod_estsol`. Hay que agregarle el mismo
> `in (8, 9, 10, 11)`, o la vista va a mostrar menos días ocupados de los que el
> PA rechaza — que es la peor combinación posible.

### 12.2 Qué cambia en la vista

**En el calendario**, un estado nuevo por día:

| Estado | Hoy | Nuevo |
| :--- | :--- | :--- |
| `has-executed` | badge relleno con las horas | sin cambio |
| `has-committed` | badge contorneado | sin cambio |
| `is-fulfilled` | el ✓ | sin cambio |
| **`has-external`** | — | **día ocupado por otra prestación**: marca propia, distinta de las dos anteriores, y día no seleccionable |

El §14 del estándar visual pide que el color no sea el único indicador, así que
la marca lleva también icono y el `title` del día dice de qué prestación y centro
de costo viene.

**En el panel del día**, una franja de solo lectura *"Ocupado por otras
prestaciones"* con los tramos, su horario y su origen. Sin eso el bloqueo es
incomprensible: el usuario ve su día vacío y el sistema le dice que no.

**En el formulario**, dos guardas más en `formBlockReason`, que hoy solo mira
compromiso, saldo, jornada y exceso:

1. solape contra lo ya informado **en esta** prestación — reusa el
   `overlapsExecuted` que ya existe para el botón, cero código nuevo;
2. solape contra los tramos externos que trae el PA.

Así el ingreso manual se bloquea **antes** de viajar al backend, en vez de fallar
al volver.

### 12.3 Orden y capas

| # | Capa | Qué |
| :-- | :--- | :--- |
| 1 | PA | `sg_fuc2sSecgen03` + agregar `cod_estsol` al `exists` de escritura |
| 2 | Backend | query, método de repositorio y endpoint del mes |
| 3 | Store | acción y estado del mes consultado |
| 4 | Componente | prop `externalCompensations`, mapa por día, estado `has-external`, franja y guardas |
| 5 | Textos | `lang/es/pds.js` (§15) |

El 1 y el 2 se pueden desplegar sin el resto: no cambian nada visible. El 4 sin
el 1 no tiene datos, así que ése es el orden.

### 12.4 Lo que falta definir

1. **¿El día ocupado se deshabilita o se deja clicable con aviso?** Deshabilitarlo
   es más claro, pero impide ver el detalle de por qué. Mi recomendación: clicable,
   con la franja explicando, y el bloqueo en el formulario.
2. **¿Se muestra el centro de costo de la otra prestación?** Es información de
   otra unidad; hay que confirmar que el jefe de proyecto puede verla.
3. **Si el choque es parcial** —solo algunas horas del día— el día no está
   "ocupado" entero. La marca debería distinguir *día con tramos externos* de
   *día sin espacio*, o el usuario va a creer que no puede compensar nada.
