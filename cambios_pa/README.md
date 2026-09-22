# PA del Workflow de Pagos DU288

Procedimientos del flujo de pago de prestaciones. Trabajan sobre el esquema
vigente (`diagrama_secgen_actualizado.md`) sin cambios de DDL: la cuota es la
fila de `sg_fume`, y su ciclo de pago avanza por `cod_estcuo`.

Formato según `template-du09/cambios_pa_solicitud_wf/reglas_estandarizacion_pa.md`.

## sg_fupssSecgen18 — listado de prestaciones pagables

Alimenta la bandeja del jefe de proyecto: prestaciones DU288 con resolucion
archivada de las que es responsable, con el avance de pago de sus cuotas.

### Por que filtra por `sg_prse.rut_jefpro`

El jefe de proyecto queda registrado en la propia prestacion al crearse la
resolucion, asi que el filtro es directo y no necesita cruzar a `fin21_db`.
Tiene una consecuencia abierta: si esa persona cambia de rol, las resoluciones
viejas le siguen apareciendo a ella y no al responsable vigente del centro de
costo. S0-001 define al solicitante como "jefe de proyecto del centro de costo"
(apunta al vigente) y Q-E03 como "supervisor de dicha actividad" (apunta al
declarado). Pendiente de cerrar antes de que existan datos reales.

### Normalizacion del RUT

El parametro es `char(9)`. Si el llamador envia menos caracteres, el motor
completa con espacios a la derecha y la comparacion falla en silencio. El PA
rellena con ceros a la izquierda para tolerar ambas formas.

### `@mes` es un corte, no un mes exacto

Trae las cuotas hasta `@ano`/`@mes` inclusive. Con mes exacto, una cuota
atrasada de agosto desaparecia al filtrar septiembre, que es justo lo que mas
urge gestionar.

### `cant_cuotas_disp` — cuotas sobre las que hoy se puede pedir pago

Cuenta las cuotas sin gestionar cuya ejecucion ya termino: su mes es anterior
al mes en curso, o la prestacion completa cerro antes de hoy. El segundo caso
cubre una prestacion corta dentro del mes actual, que de otro modo habria que
esperar al mes siguiente para cobrar. Responde a Q-A02: solo se paga trabajo
ya realizado.

### `per_pendiente_min` — atraso real

Mes mas antiguo sin gestionar, como entero `aaaamm`. Permite ordenar por
antiguedad y mostrar el atraso. La diferencia en meses debe calcularse como
`ano * 12 + mes`, no restando los enteros: `202601 - 202512` no es 1.

### `cod_estpag` — estado de pago derivado

Se calcula en el PA para que exista una sola definicion. La etiqueta de cada
codigo vive en el lang del frontend, igual que `paymentStatusLabel` en el modal
de prestaciones previas.

| Codigo | Estado | Condicion |
| :---: | :--- | :--- |
| 0 | Sin cuotas | La prestacion no tiene filas en `sg_fume` |
| 1 | Sin gestionar | Todas las cuotas en estado 1 |
| 2 | En tramite | Alguna cuota en 6, 7 u 8 |
| 3 | Pago parcial | Alguna cuota pagada y otras no |
| 4 | Pagada | Todas las cuotas en 9 |
| 5 | Con rechazo | Alguna cuota en 10 |

### Lo que el PA no resuelve

Devuelve conteos, no las cuotas una por una. Los chips de meses de la vista de
detalle se cargan con el PA de detalle, no con este.
