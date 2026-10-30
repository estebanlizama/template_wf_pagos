# PA externos para prestaciones

Estos procedimientos usan los nombres del workflow y conservan los PA externos originales en
`pa_externos_no_crear`. Incluyen validaciones de entrada y respuestas de error controladas,
aplicadas sobre el esquema SISPER disponible en el repositorio.

## Procedimientos y tablas

| PA | Operacion | Tabla(s) que consulta | Tabla donde inserta |
| :--- | :--- | :--- | :--- |
| `sg_resliSecgen01` | Inserta la resolucion y confirma el resultado | `sp_resl` | `sp_resl` |
| `sg_asdiSecgen01` | Inserta la asignacion y devuelve `codigo_asignac` | `sp_resl`, `sp_pers`, `sp_para`, `ss_asds` | `ss_asds` |
| `sg_ccaiSecgen01` | Inserta el centro de costo y devuelve `codigo_cecoscon` | `ss_asds`, `ss_ccas` | `ss_ccas` |

Los nuevos objetos usan el esquema `Analisis2` y nombres del patron del workflow. El nombre legacy de cada procedimiento queda en `pa_externos_no_crear`; quien los invoque desde el workflow debe usar los nombres de esta carpeta.

El orden funcional es `sg_resliSecgen01`, `sg_asdiSecgen01`, `sg_ccaiSecgen01`. Las asignaciones
referencian la resolucion y el centro de costo referencia la asignacion.

**El control de transaccion no es igual en los tres.** `sg_asdiSecgen01` y `sg_ccaiSecgen01`
confirman o revierten su propia insercion, y no hay una transaccion comun que revierta PA anteriores
si uno posterior falla. `sg_resliSecgen01` **no abre transaccion**: la gobierna el llamador, por el
motivo que explica la seccion siguiente.

## Validaciones incorporadas

- `sg_resliSecgen01`: exige tipo de documento `2`, unidad `05000000`, motivo, fecha real en formato
  `dd/mm/aaaa`, coincidencia entre fecha y año, textos dentro de los largos de `sp_resl` y una clave
  de resolución no registrada previamente.
- `sg_asdiSecgen01`: confirma que existan la resolución y la persona; `@numero_cuenta` sigue
  siendo opcional, y desde el 29-10-2026, cuando viene informado, se valida contra
  `sisper_db.dbo.sp_para.num_cuenta` — el catálogo de cuentas de remuneración. Un código
  inexistente deja de insertarse como una fila mal pagada y devuelve un mensaje. La cuenta del
  flujo es `2417`, «D.U. 288, Asig. de Prest. de Servicios» según `sp_para`;
  exige monto positivo y un período que abarque desde el primer hasta el último día del mismo mes.
  **No rechaza repetir el período** para la misma persona y resolución: desde el 30-10-2026 se
  retiró esa comprobación. El PA original `sspasd1` no la tiene, `ss_asds` identifica cada fila por
  `cod_asign` —correlativo por ficha— y no por el período, y las prestaciones necesitan una
  asignación por cuota: dos cuotas atrasadas pagadas en el mismo mes son el caso normal y la
  comprobación impedía registrar la segunda. Protegerse de un doble ingreso de la *misma* cuota no
  puede hacerse acá: el PA no recibe la cuota y no hay nada en `ss_asds` que la nombre, así que esa
  idempotencia le toca al flujo que invoca. **El período no tiene que caer
  dentro del año de la resolución**: `@ano` identifica la resolución en `sp_resl` y no es el año del
  mes que se paga. Una cuota decretada en diciembre y pagada en enero del año siguiente es el caso
  normal del atraso del pago, y hasta el 29-10-2026 la validación de fechas la rechazaba.
- `sg_ccaiSecgen01`: confirma la asignación, permite asociarle distribuciones de centro de costo,
  valida monto positivo cuando se informa y valida formato y orden de fechas.
- Los errores entregan solo `msg`. El éxito usa `status`, `code` y `msg`; los dos últimos PA incluyen
  además `codigo_asignac` o `codigo_cecoscon` en la misma fila.
- Se mantienen los permisos `execute` para `UsuaVrac`.
- Cada `.txt` desplegable es identico al `.sql` fuente.

## Limites heredados que requieren verificacion

- Las firmas mantienen los tipos y orden de parámetros legacy. `sp_resl` limita sus textos a 100
  caracteres, por lo que `sg_resliSecgen01` rechaza entradas que excedan ese largo.
- Los correlativos conservan el comportamiento de los PA externos: asignaciones numéricas por
  persona y centros de costo con correlativo `S` cuando la tabla ya contiene registros. Cuando la
  tabla de destino esta vacia, el correlativo conserva el resultado inicial legacy `2`.
- La validación de cuenta, ficha, resolución y asignación usa las claves foráneas identificadas en
  el diagrama local; las reglas adicionales de vigencia institucional o financiamiento no se derivan
  del esquema y no se agregan aquí.
- Los nombres nuevos son objetos distintos de los originales. El workflow debe invocar los nombres
  `Analisis2.sg_*Secgen01` de esta carpeta.
- La base de datos objetivo se explicita como `sisper_db`, segun el esquema de `sp_resl`.

La fecha de creacion no figura en los procedimientos originales. La fecha indicada en cada
cabecera corresponde a esta estandarizacion, no a la creacion historica del PA.

Estos procedimientos apuntan a SISPER y son externos al conjunto de PA propios del workflow.
Confirmar ambiente, usuario ejecutor y autorizacion de despliegue antes de instalarlos.

## Pendiente de certificacion (29-10-2026)

`sg_asdiSecgen01` cambio tres veces. El par SQL/TXT esta actualizado y es identico, en ASCII y
CRLF, pero **no se ejecuto contra ASE**.

> El 30-10-2026 el `.sql` y el `.txt` estaban desincronizados: el `.txt` tenia el cambio 2 y el
> `.sql` no, porque se regenero desde una version anterior y lo perdio. Se tomo el `.txt` como
> contenido correcto. Vale revisar el par antes de cada entrega, no solo despues de editarlo.

1. Valida `@numero_cuenta` contra `sp_para`. Al certificar hay que comprobar que el PA compile, que
   con `@numero_cuenta = '2417'` la insercion siga pasando, que un codigo inexistente devuelva el
   mensaje sin insertar, y que `@numero_cuenta` nulo siga siendo aceptado como antes.
2. El periodo dejo de exigirse dentro del ano de `@ano`. Al certificar hay que comprobar que con
   `@ano = '2026'` y periodo `01/01/2027` a `31/01/2027` la insercion **pase** --antes era
   rechazada--, que un periodo que no cierra su mes (`01/01/2027` a `30/01/2027`) siga siendo
   rechazado, que un periodo que cruza dos meses (`01/01/2027` a `28/02/2027`) siga siendo
   rechazado, y que la fila quede con `ano = '2026'`, porque de eso depende el join de
   `sg_epagsSecgen05` (`asds.ano = rslc.ano_resolu`).
3. Se retiro el rechazo por periodo repetido. Al certificar hay que comprobar que dos inserciones
   con la misma ficha, resolucion, tipo, unidad, ano y periodo **pasen las dos**, que cada una
   devuelva su propio `codigo_asignac` y que el segundo sea el primero mas uno, y que en `ss_asds`
   queden las dos filas. Es el caso de dos cuotas atrasadas pagadas en el mismo mes.


---

## `sg_resliSecgen01`: cuando se ejecuta y por que no abre transaccion

**Momento: la aprobacion del Contralor Universitario**, perfil `17`, penultima etapa de los ocho
flujos DU288. Al aprobar, la solicitud pasa a Jefe Archivo Universitario, que es terminal. Se
reconoce por **perfil y no por `cod_etapa`**, porque el codigo de la etapa cambia entre flujos
(120 en los flujos 1 a 4, 100 en el 5, 110 en el 6, 7 y 8), ni por nombre de etapa.

Es el momento correcto porque ahi los datos estan garantizados, no supuestos: desde la etapa de
Secretario General el workflow ya rechaza la aprobacion si el documento oficial no esta generado y
el firmado no esta cargado, y esa validacion se apoya en que `sg_rslc.num_resolu` --el exento-- sea
mayor que cero. Tres etapas despues, el numero, el ano y la fecha existen.

**El registro es condicion para continuar.** La llamada va **dentro** de la transaccion de la
aprobacion: si SISPER rechaza, la etapa no avanza. La alternativa --registrar despues del commit--
deja pasar el caso en que la solicitud llega a Archivo sin resolucion en `sp_resl`, y eso no se
descubre hasta el ingreso de pagos, cuando `sg_asdiSecgen01` responde que la resolucion no existe y
ya no hay a quien devolverle la tarea.

### Que pasa cuando falla

**El Contralor no tiene que verificar nada, y no puede aprobar dos veces.** Todo ocurre en una sola
transaccion, asi que hay exactamente dos resultados posibles:

| | Que ve el Contralor | En que estado queda |
| :--- | :--- | :--- |
| Registro correcto | la aprobacion se aplica | la solicitud pasa a Archivo Universitario y `sp_resl` tiene la fila |
| Registro fallido | un error que nombra el motivo y dice que **no se aplico** | la solicitud sigue en su bandeja, con su tarea pendiente intacta |

No existe un estado intermedio: no puede quedar aprobada sin resolucion en SISPER, ni la resolucion
en SISPER con la solicitud sin avanzar. Por eso tampoco hay un segundo ingreso que hacer a mano ni
una pantalla donde revisar si quedo o no.

**La salida cuando el dato esta mal.** El mensaje dirige a devolver la solicitud a Decretacion, que
es la transicion que la propia etapa del Contralor permite (`id_tipacc = 4`) y la unica pantalla
donde los datos de la resolucion se corrigen. Si el fallo no es de datos --SISPER caido, por
ejemplo-- el mensaje lo dice y el reintento es simplemente volver a aprobar.

**Y por eso «ya registrada» no es un fallo.** Una resolucion cubre **varias solicitudes**: al generar
el numero se escribe `nro_resolu` en cada `sg_soli`. Cada una de esas solicitudes recorre su propio
flujo y pasa por su propio Contralor, de modo que la primera inserta la fila y de la segunda en
adelante la fila ya esta. Si eso se tratara como error, **esas solicitudes no podrian aprobarse
nunca**: quedarian atascadas en la ultima etapa sin forma de salir. El PA responde `status = 1` con
`code = EXISTS` y la aprobacion continua, porque lo que se pide es que la resolucion exista en
`sp_resl`, no insertarla.

**Donde se evalua que ya este registrada.** Dentro del PA, con un `if exists` sobre la clave
completa de `sp_resl` --`num_resol` + `cod_ders` + `cod_unidad` + `ano`--, antes de intentar el
`insert`; el backend no consulta la tabla, solo lee la respuesta. La consulta se repite si el
`insert` falla, porque la garantia real no es el `if exists` sino el indice unico `pk_sp_resl`
sobre esa misma clave: dos Contralores que aprueben en el mismo instante solicitudes de una misma
resolucion pueden pasar los dos el `if exists`, y entonces el segundo `insert` choca con el indice
--jamas se duplica la fila-- y la segunda consulta reconoce que quedo registrada. Si el puente JDBC
entrega ese error antes del resultado del PA, la aprobacion falla y rueda atras completa, y el
reintento del Contralor la encuentra ya registrada por el primer `if exists`. En ninguno de los dos
caminos queda algo a medias.

**Y de ahi que el PA no abra transaccion propia.** En ASE un `rollback tran` anidado vuelve al
`begin` mas externo, no al propio: un `begin tran` dentro del PA haria que un fallo suyo deshiciera
la aprobacion completa de forma silenciosa. El `insert` es una sola sentencia y es atomico por si
mismo, asi que el control de transaccion no aportaba nada y si podia hacer dano. Se verifica el
resultado con `@@error` y `@@rowcount` leidos en la misma sentencia.

### Los datos y de donde salen

| Parametro | Origen |
| :--- | :--- |
| `@num_resoluc` | `sg_rslc.num_resolu`, el exento digitado en Decretacion |
| `@cod_tipo_rs` | constante `2` |
| `@codigo_unid` | constante `05000000` |
| `@ano` | `sg_rslc.ano_resolu` |
| `@fec_resol` | `sg_rslc.f_resolucio`, normalizada a `dd/mm/aaaa` |
| `@motivo` | texto fijo: `DISPONE PAGO DE ASIGNACION DE PRESTACION DE SERVICIOS A LAS PERSONAS QUE INDICA.` |
| `@vistos`, `@considera`, `@resuelvo`, `@num_doc_ant` | nulos |

**El motivo es fijo y en mayusculas sin tildes** por dos razones. Una, es el estilo de `sp_resl`:
los registros reales dicen `OTORGA ASIG. AL GRADO` o `ENCOMENDACION DE FUNCIONES DIRECTIVAS`. Dos,
el driver de Sybase devuelve los acentos partidos --un apellido con enie llega como `ZU?IGA`--, asi
que escribir «asignacion» con tilde dejaria el texto roto dentro de SISPER. Mide 80 caracteres y
`sp_resl.motivo` admite 100; hay una prueba unitaria que lo comprueba y que rechaza cualquier
caracter fuera de ASCII imprimible.

**Los cuatro opcionales van nulos** porque en las resoluciones reales de `sp_resl` vienen vacios,
incluido `num_docant`, el numero de documento antecedente.

**La fecha se normaliza, no se confia.** `f_resolucio` es `datetime` y nullable, y el guardado de la
resolucion acepta mas de un formato segun la pantalla: omite su propia validacion de ano cuando no
reconoce el formato. La normalizacion desambigua por el ano --cuatro digitos al principio es
`aaaa/mm/dd`, cuatro al final es `dd/mm/aaaa`--, valida dias por mes con anos bisiestos, y si no
puede leer la fecha devuelve vacio en vez de inventarla. La aprobacion se corta con el motivo
concreto antes de abrir la transaccion.

### Como comprobarlo a mano

La consulta parte de la solicitud, porque el exento no esta en `sg_soli` sino en la resolucion que
esa solicitud apunta. Es solo lectura, resuelve por el indice unico de cada tabla y se puede correr
cuantas veces se quiera sin afectar nada:

```sql
select s.nro_solici,
       r.ano_resolu,
       r.num_resolu as exento,
       r.f_resolucio,
       case when p.num_resol is null then 'NO registrada' else 'registrada' end as sisper,
       p.f_resoluc,
       p.f_ingreso,
       p.motivo
  from secgen_db.dbo.sg_soli s
  join secgen_db.dbo.sg_rslc r
    on r.ano_resolu = s.ano_resolu
   and r.nro_resolu = s.nro_resolu
  left join sisper_db.dbo.sp_resl p
    on p.num_resol = convert(varchar(10), r.num_resolu)
   and p.cod_ders = '2'
   and p.cod_unidad = '05000000'
   and p.ano = convert(varchar(4), r.ano_resolu)
 where s.nro_solici = 0 -- numero de la solicitud
```

Si `num_resolu` viene nulo la resolucion aun no tiene exento asignado y la aprobacion del Contralor
se va a cortar antes de llegar al PA. Si `sisper` dice `NO registrada` con exento presente, la
siguiente aprobacion la inserta; si dice `registrada`, cualquier aprobacion posterior responde
`EXISTS` y avanza igual.

### Al certificar

1. Una resolucion con exento, ano y fecha coherentes se registra, y `sp_resl` queda con la clave
   `num_resol` + `cod_ders = 2` + `cod_unidad = 05000000` + `ano`.
2. **Dos solicitudes de la misma resolucion se aprueban las dos.** La primera inserta en `sp_resl`;
   la segunda recibe `status = 1` con `code = EXISTS`, **avanza igual** y no inserta una segunda
   fila. Es el caso que hay que probar con mas intencion, porque es el normal --una resolucion cubre
   varias solicitudes-- y porque si se rompe deja solicitudes atascadas en la ultima etapa.
3. Un rechazo del PA **deja la solicitud en la etapa del Contralor**, sin avanzar a Archivo y sin
   tarea consumida. Es el punto que hay que probar con intencion, porque es el que justifica que la
   llamada vaya dentro de la transaccion.
4. Una resolucion sin fecha, o con fecha de otro ano que `ano_resolu`, corta la aprobacion con un
   mensaje que nombra los dos valores, antes de escribir nada.
5. Las etapas que no son del perfil `17` no ejecutan el PA: aprobar en Decretacion, Secretario
   General, VRAF o Legalidad no debe tocar `sp_resl`.
6. Devolver desde la etapa del Contralor --a correccion o a Decretacion-- tampoco lo ejecuta.
7. `sp_resl` conserva el indice unico `pk_sp_resl` sobre `num_resol` + `cod_ders` + `cod_unidad` +
   `ano`. Es lo que impide la fila duplicada si dos aprobaciones de la misma resolucion coinciden,
   asi que conviene confirmarlo en el ambiente antes de dar el PA por certificado.
