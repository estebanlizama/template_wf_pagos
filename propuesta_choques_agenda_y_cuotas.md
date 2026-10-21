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
