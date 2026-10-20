# Comentario de devolución DGDP → solicitante

Análisis de dónde guardar el motivo que DGDP escribe al devolver una cuota,
**sin modificar la BDD** y mostrando solo el motivo vigente (no el hilo).

Fecha: 20-10-2026. Solo análisis: no hay código escrito.

El diseño concreto del camino recomendado (qué va en cada columna, ejemplos
de filas y de invocaciones) está en [comentario_devolucion_dgdp_diseno.md](comentario_devolucion_dgdp_diseno.md).

La salida finalmente elegida —tabla y PA propios de pagos— está en [comentario_devolucion_dgdp_tabla.md](comentario_devolucion_dgdp_tabla.md), que además deja constancia de que impacto_12 ya había aprobado una solución para esto.

---

## 1. Lo que ya existe (y se está perdiendo)

El parámetro está cableado de punta a punta **y el PA lo descarta**:

| Capa | Estado |
| :--- | :--- |
| Botones de decisión (`_installmentNumber.vue:155-180`) | aprobar / observar / rechazar. **Sin campo de texto** |
| `resolve()` (`_installmentNumber.vue:1315`) | despacha solo `decision`, nunca `observation` |
| Store (`service-provision-payments.js:211`) | **sí** acepta y envía `observation` |
| Endpoint `POST …/installments/{n}/decision` | **sí** lo recibe en `Du288PaymentReviewDecisionRequest` |
| Repositorio (`…payment-procedures.repository.ts:852`) | **sí** lo valida (≤255), escapa comillas y lo pasa al PA |
| `sg_epaguSecgen03` | declara `@observacion varchar(255)` … **y no lo escribe en ninguna parte** |

Hoy un cliente de API puede mandar el motivo, recibir 200, y el texto desaparece
sin error. Eso es peor que no tener el campo, porque no falla.

**Ninguna tabla de pagos tiene dónde guardarlo:**

| Tabla | Columnas | ¿Texto libre? |
| :--- | :--- | :--- |
| `sg_epag` | `id_funprse`, `nro_cuota`, `cod_estcuo`, `rut_solici`, `fec_solici`, `id_evidenc`, `ano_pago`, `mes_pago`, `mto_realpa`, `fec_pago` | no |
| `sg_fume` | montos, estado, validaciones, `id_evidenc`, fechas | no |
| `sg_dpag` | `id_funprse`, `nro_cuota`, `corr_fume` | no (es puente) |

`id_evidenc` no sirve de atajo: es un `int` sin FK y el almacén de documentos
todavía no está implementado (`backend_lo_que_falta.md:54`).

---

## 2. Todas las columnas de texto libre que hay en `secgen_db`

Son cinco en todo el esquema. Cuatro quedan fuera por su FK o su dominio:

| Columna | Tabla | Grano / FK | ¿Sirve? |
| :--- | :--- | :--- | :--- |
| `sg_hist.observaci` (`text`) | historial funcional | `nro_solici` → `sg_soli`, `id_tipacc` → `sg_tacc` | **la única candidata** |
| `sg_apso.comentario` | pasos de aprobación de la solicitud | `nro_solici` + visador + `cod_estapr` | no — es la tabla de **pasos**, descartada por el equipo |
| `sg_apre.observacio` | aprobación de la **resolución** | FK a `sg_rslc` (año + número) | no — su grano es la resolución firmada, no una cuota de pago |
| `sg_bccm.comentario` | comentarios de **bases de concurso** | FK a `sg_baco` | no — otro dominio; la FK rechaza una solicitud de PDS |
| `sg_appc.comentario` | aprobación de **perfil de cargo** | FK a `sg_fopc` | no — ídem |

Las tres últimas no son "feas pero posibles": su FK **impide** insertar una fila
que hable de una cuota de pago.

### Por qué `sg_hist` es la correcta

Trae todo lo que un motivo de devolución necesita: texto (`observaci text`),
autor (`rut_accion`), perfil (`id_perfil`), fecha (`f_creacion`) y tipo de acción
(`id_tipacc`). Y ya hay PA hechos:

| PA | Para qué | ¿Con texto? |
| :--- | :--- | :--- |
| `sg_histiSecgen03` | inserta con `@observaci varchar(250)` | **sí** |
| `sg_histsSecgen02` | hilo completo de una solicitud: nombre, perfil, acción, fecha, observación | lectura |
| `sg_histsSecgen05` | **última devolución a observación** (`id_tipacc = 4`) de una solicitud | lectura |

`sg_histsSecgen05` es el precedente exacto de lo que se pidió: "solo el motivo
vigente" **ya está modelado** así en el flujo de solicitud — se lee `sg_hist`
filtrado por tipo de acción y se toma el más reciente. En bases de licitación se
usa igual como hilo de comentarios (`insertRequestHistoryComment` +
`getCommentBasisRequest`, que filtra por `@id_tipacc`).

---

## 3. El problema que no desaparece sin tocar la BDD

**`sg_hist` no sabe de qué cuota se habla.** Su grano es la solicitud. Y en
DU288:

- una solicitud tiene **varios funcionarios** (`sg_fups`: PK `id_funprse`,
  `nro_solici` repetido);
- cada funcionario tiene **varias cuotas** (`sg_epag`: PK `id_funprse` +
  `nro_cuota`).

La ida se resuelve (`sg_epag.id_funprse → sg_fups.nro_solici → sg_soli.nro_resolu`),
pero **la vuelta no**: desde una fila de `sg_hist` no hay cómo decir "esto era de
la cuota 2 de Pérez".

Tres caminos que **no** funcionan, para cerrarlos:

- **Por fecha.** `sg_epag` no guarda cuándo cambió de estado — tiene `fec_solici`
  (creación) y `fec_pago`, nada del paso a 3. No se puede correlacionar la fila
  del historial con el cambio de estado.
- **Por `cod_modulo`.** Es el código de módulo del sistema (`varchar(8)`), y
  `sg_histiSecgen03` no lo escribe. Meter ahí un id sería mentir sobre la
  columna, y 8 caracteres no alcanzan para `id_funprse` + `nro_cuota`.
- **Reusando `id_tipacc = 4`** ("Devolvió a corrección la solicitud"). Es cero
  cambios, y **rompe algo que funciona**: ese código lo escribe hoy el flujo de
  solicitud (`service-provision-request-approval.controller.ts:565`) y lo lee
  `sg_histsSecgen05` (`service-provision-request.ts:282`). Una devolución de
  cuota aparecería como la última devolución *de la solicitud*.

---

## 4. Lo que sí se puede hacer sin DDL

### Nota previa: una fila en `sg_tacc` no es DDL

`sg_tacc` es un catálogo (`id_tipacc tinyint`, `des_accion varchar(50)`), llega
hasta el 30 y la columna admite hasta 255. Agregar códigos es **semilla**, de la
misma clase que `datos_base/01_sg_ecuo.sql`, que ya se despliega así en este
mismo proyecto. Las dos opciones de abajo asumen que eso está permitido; si no lo
está, no hay opción viable (§3 cierra la de reusar el 4).

### (Z1) `sg_hist` con la cuota en un prefijo del propio texto

`observaci` guarda `[PRS:1234|C:2] <motivo>` y el lector lo filtra y lo limpia.

- **Cambios:** 1 fila en `sg_tacc` (+ la de rechazo), `sg_epaguSecgen03` llama a
  `sg_histiSecgen03` dentro de su transacción, y un lector nuevo
  (`sg_histsSecgen06`) que trae el último motivo de una cuota.
- **A favor:** cero DDL de verdad, y el motivo **sí** queda atribuido a la cuota.
- **Precio honesto:** la llave vive en texto libre. No es indexable (hay que
  recorrer con `like`), no hay constraint que la proteja, y si alguien edita el
  texto por fuera la fila queda huérfana. El volumen lo tolera — una fila por
  decisión, no por mes — pero es una **convención, no una restricción**.

### (Z2) `sg_hist` al grano de la solicitud, asumiendo la ambigüedad

Mismo insert, sin prefijo. El solicitante ve "DGDP devolvió, motivo: …" a nivel
de solicitud.

- **Cambios:** 1 fila en `sg_tacc` y la llamada. Nada más.
- **A favor:** es el mínimo posible y no inventa ninguna convención.
- **Precio:** correcto solo cuando la solicitud tiene **un** funcionario con
  **una** cuota en juego. Con varios, el solicitante lee el motivo pero no sabe
  qué corregir — que es justo el problema que el comentario venía a resolver.

**Recomiendo Z1.** Z2 es más limpia en el modelo pero no cumple el objetivo en el
caso normal de DU288, que es varios funcionarios por resolución.

**Vale decirlo igual:** con dos columnas nulables en `sg_hist`
(`id_funprse int null`, `nro_cuota tinyint null`) el mismo diseño queda con llave
real, indexable, sin migración y sin tocar ningún PA ni lectura existente — las
filas viejas quedan en `null`. Es el camino que descartamos por la restricción de
no modificar la BDD, no por técnica. Si la restricción es "no tablas nuevas" y no
"no `alter table`", conviene revisarlo.

---

## 5. Lo que falta por confirmar

- **¿La restricción incluye `sg_tacc`?** Si ni la semilla del catálogo entra, no
  hay dónde guardar el motivo y el campo `@observacion` debería **sacarse** del
  PA y del backend, en vez de seguir aceptando algo que se descarta.
- **¿Cuántos funcionarios por resolución en la práctica?** Si en la operación
  real es casi siempre uno, Z2 alcanza y no hace falta la convención de Z1.
- **Rechazo y devolución, ¿mismo código?** Son dos acciones distintas
  (`cod_estcuo` 3 y 10) y conviene un `id_tipacc` para cada una, para poder leer
  solo las devolubles.
- **Largo del texto.** `sg_histiSecgen03` declara `varchar(250)` aunque la columna
  es `text`; el backend de pagos valida 255. Hay que unificar en 250 — y si se usa
  el prefijo de Z1, descontarlo del largo visible al usuario (§8.1 del estándar
  visual).
- **¿Exigir el motivo?** Devolver o rechazar sin decir por qué es el hueco que
  esto cierra. Debería ser obligatorio para `cod_estcuo in (3, 10)`, validado en
  el PA y no solo en el formulario.
