# PA externos para prestaciones

Estos procedimientos usan los nombres del workflow y conservan los PA externos originales en
`pa_externos_no_crear`. Incluyen validaciones de entrada, transacciones por insercion y respuestas
de error controladas, aplicadas sobre el esquema SISPER disponible en el repositorio.

## Procedimientos y tablas

| PA | Operacion | Tabla(s) que consulta | Tabla donde inserta |
| :--- | :--- | :--- | :--- |
| `sg_resliSecgen01` | Inserta la resolucion y confirma el resultado | `sp_resl` | `sp_resl` |
| `sg_asdiSecgen01` | Inserta la asignacion y devuelve `codigo_asignac` | `sp_resl`, `sp_pers`, `sp_para`, `ss_asds` | `ss_asds` |
| `sg_ccaiSecgen01` | Inserta el centro de costo y devuelve `codigo_cecoscon` | `ss_asds`, `ss_ccas` | `ss_ccas` |

Los nuevos objetos usan el esquema `Analisis2` y nombres del patron del workflow. El nombre legacy de cada procedimiento queda en `pa_externos_no_crear`; quien los invoque desde el workflow debe usar los nombres de esta carpeta.

El orden funcional es `sg_resliSecgen01`, `sg_asdiSecgen01`, `sg_ccaiSecgen01`. Las asignaciones
referencian la resolucion y el centro de costo referencia la asignacion. Cada PA confirma o revierte
su propia insercion; no hay una transaccion comun que revierta PA anteriores si uno posterior falla.

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
