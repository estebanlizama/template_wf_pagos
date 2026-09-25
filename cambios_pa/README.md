# PA del Workflow de Pagos DU288

Procedimientos del flujo de pago de prestaciones. Trabajan sobre el esquema
vigente (`diagrama_secgen_actualizado.md`) sin cambios de DDL: la cuota es la
fila de `sg_fume`, y su ciclo de pago avanza por `cod_estcuo`.

Formato según `template-du09/cambios_pa_solicitud_wf/reglas_estandarizacion_pa.md`.

## sg_fupssSecgen18 — listado de prestaciones pagables

Alimenta la bandeja del jefe de proyecto: prestaciones DU288 con resolucion
archivada de las que es responsable, con el avance de pago de sus cuotas.

### Por que filtra por el responsable vigente y no por `sg_prse.rut_jefpro`

Gestiona el pago quien esta a cargo del centro de costo hoy, no quien quedo
declarado en la resolucion. Filtrar por `rut_jefpro` dejaba las cuotas
impagables al cambiar el jefe de proyecto: el saliente perdia el acceso y el
entrante no recibia ninguna fila, porque el RUT congelado en la prestacion ya
no correspondia a nadie con el rol. Cerrando asi el conflicto entre S0-001
("jefe de proyecto del centro de costo", apunta al vigente) y Q-E03
("supervisor de dicha actividad", apunta al declarado): manda el vigente, y
`rut_jefpro` se devuelve igual como dato informativo para que el nuevo
responsable sepa a quien preguntar por la actividad.

Va como `exists` y no como `inner join` a proposito. Si un centro de costo
tuviera dos responsables vigentes, el join multiplicaria las filas y **todos
los `sum()` quedarian inflados** -- montos pagados y saldos al doble.

Con este filtro la autorizacion queda dentro del PA: quien no es responsable
vigente de ningun centro de costo recibe cero filas, sin necesitar una guarda
de rol aparte en el backend.

Queda un borde: un centro de costo sin responsable vigente deja sus
prestaciones invisibles para todos. Es poco probable, pero las cuotas se
pierden en silencio, asi que conviene una vista de DGDP sin el filtro o un
conteo de huerfanas.

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

### Activacion del menu de pagos

El menu se activa cuando la persona tiene al menos una prestacion en proceso,
es decir `cod_estpag` distinto de 4 (pagada) y de 0 (sin cuotas). Lo resuelve
`GET /requests/service-provision/payments/access-summary`, que el frontend
consulta una vez por sesion y cachea: no es un chequeo por render.

Ese resumen devuelve `isProjectManager` aparte, tomado de `sg_cctosSecgen05`
con `@id_modprse = 2` -- la misma definicion de jefe de proyecto que ya usa el
lado solicitante. Se mantiene separado porque sin el, cero prestaciones no
distingue "no tienes el rol" de "no tienes nada pendiente", y el estado vacio
no podria explicar por que la tabla esta vacia.

### Lo que el PA no resuelve

Devuelve conteos, no las cuotas una por una. Los chips de meses de la vista de
detalle se cargan con el PA de detalle, no con este.

---

## sp_as01sSecgen01 — consulta de asistencia, ausencias y justificaciones

Alimenta la validación de DGDP (Dependencia D3 / Sección H / PAG-33) para verificar si un
funcionario presenta licencias médicas, permisos sin goce o ausencias durante el periodo
de ejecución de una cuota de prestación DU288.

### Entradas
- `@rut char(9)`: RUT del funcionario a consultar.
- `@cod_periodo smallint`: Código de período de evaluación en `sisper_db..sp_prdo`.

### Salida
Devuelve el detalle diario ordenado cronológicamente con:
`diasem`, `feriado`, `fecha`, `hora_e`, `hora_s`, `m_ent`, `m_sal`, `res_ausen`, `excusa`, `cod_estasi`, `des_estasi`.

