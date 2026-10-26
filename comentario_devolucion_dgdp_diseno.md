# Diseño: motivo de devolución DGDP sobre `sg_hist`

Camino elegido: **reutilizar `sg_hist` sin DDL**. Ni campos nuevos ni tabla
nueva. La alternativa de tabla propia queda documentada en
[comentario_devolucion_dgdp_tabla.md](comentario_devolucion_dgdp_tabla.md); el
análisis de por qué `sg_hist` es la única tabla candidata, en
[comentario_devolucion_dgdp.md](comentario_devolucion_dgdp.md).

Contrastado contra `maestros/diagrama_secgen_actualizado.md` (22-09-2026):
`sg_hist` **no cambió** respecto del diagrama anterior — mismas 13 columnas,
mismas 4 FK.

Fecha: 20-10-2026. Diseño, no implementación.

---

## 0. Por qué escribir en `sg_hist` es más seguro de lo que parecía

Tenías razón, y la razón está en el código. Antes dije que esto "modifica datos
del WF de resolución". Es literalmente cierto, pero el riesgo que eso implicaría
no existe, porque **el WF de resolución ya está cerrado cuando nace un pago**.

`sg_epagiSecgen01` no deja crear una cuota si la solicitud no está archivada:

```sql
and soli.cod_estsol = 11
and soli.nro_resolu is not null
...
select 'La prestacion no existe, no esta archivada o no esta a su cargo' as msg
```

`11` es `ARCHIVED`. Entonces, para cualquier solicitud que tenga una cuota de
pago:

- su resolución está **archivada** — estado terminal, no vuelve atrás;
- su última fila de `sg_hist` es la del archivo (`id_tipacc = 14`);
- **ningún PA de resolución va a volver a escribir** en `sg_hist` para ese
  `nro_solici`.

Las filas de pago se agregan a una línea de tiempo **ya cerrada**. No compiten
con nada, no cambian nada existente, y no hay escritura concurrente posible.

### Qué pasa con las dos lecturas de resolución

Siguen devolviendo más filas, eso no cambia. Pero verifiqué qué hacen con ellas:

| Lectura | Filtra | ¿Muestra las de pago? |
| :--- | :--- | :--- |
| `resolution-format-normative.vue:732` | `actionType === 4 \|\| 9` **y** `isPostDecreeingRole(perfil)` | **No**, por dos condiciones independientes |
| modal de flujo (`service-provision-request.controller.ts:719`) | `observation.startsWith('omision de etapa')` | **No** |

`isPostDecreeingRole` busca `secretario general`, `vicerrector`, `vraf`,
`legalidad`, `contralor`, `archivo universitario`. El perfil `33` es
`payment_validator` / *Validador de pagos DGDP*: no calza con ninguno. Y los
códigos nuevos (§2) no son 4 ni 9.

Queda un costo real, y hay que nombrarlo: **las filas de pago viajan en el
payload de dos endpoints de resolución**, y quedan excluidas por filtros que viven
en el frontend. Es aceptable para una línea de tiempo archivada, pero es lo que
se paga por no crear la tabla.

---

## 1. El único que comenta es DGDP — confirmado

Revisé los seis PA de `sg_epag`. Solo uno tiene parámetro de observación:

| PA | Quién lo usa | ¿Observación? |
| :--- | :--- | :--- |
| `sg_epagiSecgen01` crear | jefe de proyecto | no |
| `sg_epaguSecgen01` editar | jefe de proyecto | no |
| `sg_epagdSecgen01` eliminar borrador | jefe de proyecto | no |
| `sg_epaguSecgen02` enviar a visación | jefe de proyecto | no |
| `sg_epagsSecgen03/04` bandeja y detalle | DGDP | lectura |
| **`sg_epaguSecgen03`** resolver | **DGDP** | **`@observacion varchar(255)`** |

El solicitante no comenta: corrige y reenvía. Entonces el hilo es de **un solo
autor**, `rut_accion` es siempre un RUT de DGDP y `id_perfil` siempre `33`. Eso
simplifica tres cosas: no hay camino de respuesta que diseñar, el lector no tiene
que distinguir autores, y no hace falta más que un código de acción por decisión.

---

## 2. Qué va en cada columna

| Columna | Qué se guarda | De dónde sale |
| :--- | :--- | :--- |
| `id_histor` | correlativo | lo asigna el PA desde `sg_parm` |
| `cod_tipsol` | `1` | `ServiceProvisionRequestTypeCode.SERVICE_PROVISION` |
| `nro_solici` | la solicitud de la prestación | `sg_epag.id_funprse → sg_fups.nro_solici` |
| `nro_resolu` / `ano_resolu` | la resolución archivada | `sg_soli.nro_resolu` / `ano_resolu` |
| `id_tipacc` | `31` devolver, `32` rechazar | **semilla nueva en `sg_tacc`** |
| **`cod_sistem`** | `'SG'` | constante — **marca de módulo** |
| **`cod_modulo`** | `'WFPAGOS'` | constante — **marca de módulo** |
| `observaci` | `#PRS1234-C2# <motivo>` | prefijo de cuota + texto de DGDP |
| `rut_accion` | RUT del revisor | `requireDni(currentUserProfile)` |
| `id_perfil` | `33` | `roleCode` del resumen de accesos que ya consulta `assertCanResolveDgdpPayment` |
| `f_creacion` / `f_ultmodif` | `getdate()` | el PA |

### `cod_sistem` + `cod_modulo`: el formato de identificación que pedías

No hay que inventar una marca. `sg_hist` **ya tiene** las dos columnas, y son uno
de los dos ejes de aislamiento que `impacto_13_apso_aislado_por_modulo.md` §1
identifica como ya existentes en el sistema:

| Eje | Dónde vive | Qué separa |
| :--- | :--- | :--- |
| `cod_flusol` | `sg_apso` · `sg_eta1` · `sg_prse` | el flujo: resolución vs pago |
| **`cod_sistem` + `cod_modulo`** | `sg_eta1` · `bd_pri2` · `bd_per1` · **`sg_hist`** | el módulo |

Dos hechos que las dejan libres, verificados en el diagrama actualizado y en los
PA:

1. **No tienen FK.** Las cuatro FK de `sg_hist` son a `sg_rslc`, `sg_soli`,
   `sg_tacc` y `sg_tsol`. `cod_sistem` y `cod_modulo` no están restringidas.
2. **Hoy nadie las escribe.** `sg_histiSecgen03` no las incluye en su `insert`
   (ni `Secgen01` ni `Secgen02`). Todas las filas existentes las tienen en
   `null`.

Entonces `cod_modulo = 'WFPAGOS'` (7 de 8 caracteres) identifica las filas de
pago **por columna, no por convención de texto**: `where cod_modulo = 'WFPAGOS'`
las trae todas, y `where isnull(cod_modulo,'') <> 'WFPAGOS'` las excluye de
cualquier lectura futura de resolución que quiera protegerse.

Es estrictamente mejor que el prefijo para la pregunta *"¿cuáles son de pagos?"*.
Lo que no resuelve es *"¿de qué cuota?"*.

### El prefijo, que sigue siendo necesario

`sg_hist` se indexa por solicitud, y una solicitud DU288 tiene varios
funcionarios (`sg_fups`, `nro_solici` repetido), cada uno con varias cuotas
(`sg_epag`, PK `id_funprse` + `nro_cuota`). Ninguna columna libre puede llevar
ese par, así que va en el texto:

```
#PRS<id_funprse>-C<nro_cuota># <motivo>
```

**Por qué no `[PRS:1234|C:2]`:** en Sybase `[` y `]` son metacaracteres de `like`
(clase de caracteres). `like '[PRS%'` no busca el literal `[PRS`, busca un
carácter de la clase `{P,R,S}`. Habría que escribir `like '[[]PRS%'`. `#` y `-`
no tienen significado en `like`; `_` y `%` sí, por eso tampoco van en el
delimitador.

**El `#` de cierre no es decorativo:** sin él, `like '#PRS1234-C2%'` también
calzaría con la cuota 21 de la misma prestación.

**Largo.** El PA acota a `varchar(250)` (la columna es `text`). El prefijo mide
hasta 21 caracteres (`#PRS` + 10 dígitos + `-C` + 3 dígitos + `#` + espacio).
Reservar 24 y acotar el texto del usuario a **220**. Ese 220 es el que tiene que
mostrar el contador del formulario (§8.1 del estándar visual) y el que debe
validar el repositorio — hoy valida 255, que no corresponde.

### La semilla en `sg_tacc`

```sql
insert into secgen_db..sg_tacc (id_tipacc, des_accion)
values (31, 'DGDP devolvio a correccion la cuota de pago')
insert into secgen_db..sg_tacc (id_tipacc, des_accion)
values (32, 'DGDP rechazo la cuota de pago')
```

El catálogo llega al 30 y `id_tipacc` es `tinyint` (hasta 255). Reflejarlos en
`src/constants/history-action-type.constant.ts`:

```ts
  /** DGDP devolvió a corrección una cuota de pago DU288. */
  PAYMENT_INSTALLMENT_RETURNED: 31,
  /** DGDP rechazó una cuota de pago DU288. */
  PAYMENT_INSTALLMENT_REJECTED: 32,
```

**No reusar `id_tipacc = 4`.** Ese código lo escribe el flujo de solicitud
(`service-provision-request-approval.controller.ts:565`) y lo lee
`sg_histsSecgen05` (`service-provision-request.ts:282`) como "última devolución
de la solicitud". Una devolución de cuota se haría pasar por una de la solicitud,
y además pasaría el filtro `actionType === 4` de la vista de resolución — que es
justo lo que los códigos nuevos evitan.

---

## 3. Ejemplo

**Escenario.** Solicitud 4821 (archivada, `cod_estsol = 11`), resolución
1570/2026. Pérez (`id_funprse` 1234) y Soto (1235). DGDP (RUT 152421516, perfil
33) devuelve la cuota 2 de Pérez y rechaza la cuota 1 de Soto.

### Lo que se ejecuta

```sql
execute secgen_db.Analisis2.sg_histiSecgen04
    @cod_tipsol = 1,
    @nro_solici = 4821,
    @nro_resolu = 1570,
    @ano_resolu = 2026,
    @id_tipacc  = 31,
    @cod_sistem = 'SG',
    @cod_modulo = 'WFPAGOS',
    @observaci  = '#PRS1234-C2# Abril quedo con 74.074 y el mes solo tiene 3 dias ejecutados. Corregir el monto o sacar el mes de la cuota.',
    @rut_accion = '152421516',
    @id_perfil  = 33
```

```sql
execute secgen_db.Analisis2.sg_histiSecgen04
    @cod_tipsol = 1,
    @nro_solici = 4821,
    @nro_resolu = 1570,
    @ano_resolu = 2026,
    @id_tipacc  = 32,
    @cod_sistem = 'SG',
    @cod_modulo = 'WFPAGOS',
    @observaci  = '#PRS1235-C1# La prestacion no tiene resolucion vigente para el periodo que se cobra.',
    @rut_accion = '152421516',
    @id_perfil  = 33
```

### Lo que queda en la tabla

| `id_histor` | `nro_solici` | `nro_resolu` | `id_tipacc` | `cod_modulo` | `observaci` | `rut_accion` | `id_perfil` | `f_creacion` |
| ---: | ---: | ---: | ---: | :--- | :--- | :--- | ---: | :--- |
| 90 139 | 4821 | 1570 | 14 | `null` | *(archivo de la resolución)* | 101234567 | 18 | 2026-09-30 16:10 |
| 90 141 | 4821 | 1570 | 31 | WFPAGOS | `#PRS1234-C2# Abril quedo con 74.074 y…` | 152421516 | 33 | 2026-10-20 11:42 |
| 90 142 | 4821 | 1570 | 32 | WFPAGOS | `#PRS1235-C1# La prestacion no tiene…` | 152421516 | 33 | 2026-10-20 11:47 |

La primera fila es la del archivo: la última que escribió resolución. Las de pago
vienen después, con su módulo marcado. Si Pérez corrige, reenvía y DGDP vuelve a
devolver, se agrega una cuarta fila con el mismo `#PRS1234-C2#` y fecha posterior.
**No se actualiza ni se borra nada.**

---

## 4. Los dos PA nuevos

### `sg_histiSecgen04` — insertar con marca de módulo

Clon de `sg_histiSecgen03` con `@cod_sistem` y `@cod_modulo` agregados al
`insert`. **PA nuevo, no modificado**: `Secgen03` lo usan bases de licitación
(`tendering-rules-basis.repository.ts:223`) y perfil de cargo, y no se toca.

Cambios respecto de `Secgen03`:

```sql
create procedure Analisis2.sg_histiSecgen04
    @cod_tipsol tinyint      = null,
    @nro_solici int          = null,
    @nro_resolu int          = null,
    @ano_resolu smallint     = null,
    @id_tipacc  tinyint      = null,
    @cod_sistem char(2)      = null,
    @cod_modulo varchar(8)   = null,
    @observaci  varchar(250) = null,
    @rut_accion char(9)      = null,
    @id_perfil  smallint     = null
as
```

…y las dos columnas en el `insert into secgen_db.dbo.sg_hist (…)`. Todo lo demás
—validaciones, correlativo de `sg_parm`, transacción, `select` de salida— queda
igual.

### `sg_histsSecgen06` — leer el motivo vigente de una cuota

Patrón de `sg_histsSecgen05`: ordena descendente y devuelve; el llamador toma la
primera fila. Devuelve el texto **ya limpio**, para que el prefijo no salga del PA.

```sql
create procedure Analisis2.sg_histsSecgen06
    @id_funprse int     = null,
    @nro_cuota  tinyint = null
as

if isnull(@id_funprse, 0) <= 0 or isnull(@nro_cuota, 0) <= 0
begin
    select 'Faltan antecedentes para consultar el motivo de la cuota.' as msg
    return
end

declare @nro_solici int
declare @marca      varchar(24)

select @nro_solici = nro_solici
  from secgen_db.dbo.sg_fups
 where id_funprse = @id_funprse

select @marca = '#PRS' + convert(varchar(10), @id_funprse)
              + '-C'   + convert(varchar(3),  @nro_cuota) + '#'

select
    hist.id_tipacc,
    tacc.des_accion,
    hist.f_creacion,
    pers.nom_nombre + ' ' + pers.nom_appate + ' ' + pers.nom_apmate as nombre,
    per1.des_perfil,
    /* El prefijo es llave, no contenido: se queda en el PA. */
    ltrim(substring(convert(varchar(255), hist.observaci),
                    charindex('# ', convert(varchar(255), hist.observaci)) + 2,
                    255)) as observaci
  from secgen_db..sg_hist hist
  left join secgen_db..sg_tacc tacc on tacc.id_tipacc  = hist.id_tipacc
  left join sisper_db..sp_pers pers on pers.rut_person = hist.rut_accion
  left join sistema_db..bd_per1 per1
         on per1.cod_perfil = hist.id_perfil
        and per1.cod_sistem = 'SG'
        and per1.cod_modulo = 'SISSOLIC'
 where hist.cod_tipsol = 1
   and hist.nro_solici = @nro_solici
   and hist.cod_modulo = 'WFPAGOS'
   and hist.id_tipacc in (31, 32)
   and convert(varchar(255), hist.observaci) like @marca + '%'
 order by hist.f_creacion desc, hist.id_histor desc
go

grant execute on Analisis2.sg_histsSecgen06 to UsuaVrac
go
```

El `convert(varchar(255), …)` sobre `observaci` no es adorno: la columna es
`text`, y así `like`, `charindex` y `substring` trabajan sobre `varchar` sin
depender de las funciones de texto de ASE. Es seguro porque el PA de inserción
acota a 250.

El `where` lleva **tres** filtros redundantes a propósito — módulo, tipo de
acción y prefijo. Cualquiera de los tres solo bastaría; juntos, un error en uno
no devuelve filas ajenas.

**Para la cuota 2 de Pérez devuelve:**

| `id_tipacc` | `des_accion` | `f_creacion` | `nombre` | `des_perfil` | `observaci` |
| ---: | :--- | :--- | :--- | :--- | :--- |
| 31 | DGDP devolvio a correccion la cuota de pago | 2026-10-20 11:42 | Ana Rivas Soto | payment_validator | Abril quedo con 74.074 y el mes solo tiene 3 dias ejecutados. Corregir el monto o sacar el mes de la cuota. |

---

## 5. Cómo se enchufa: el historial va **primero**

El repositorio es la única capa que llama PA, y la precedencia del proyecto son
**dos llamadas seguidas**: así lo hace bases de licitación
(`tendering-rules-basis.repository.ts:223`) y la aprobación de solicitud PDS
(`service-provision-request-approval.repository.ts:245`).

Llamar al PA de historial desde dentro de `sg_epaguSecgen03` sería peor: abre su
propia transacción y **emite su propio `select` de estado**, que contaminaría el
resultado que hoy lee `assertMutationResult`.

Sin transacción común, el orden importa:

1. `sg_histiSecgen04` — inserta el motivo.
2. `sg_epaguSecgen03` — mueve `cod_estcuo` a 3 o 10.

Si falla (2), queda una fila de historial sin su cambio de estado. Es inocua: la
vista solo muestra el motivo cuando la cuota está en 3 o 10, así que una fila
huérfana no se ve, y un reintento exitoso agrega una fila posterior que gana por
fecha. **Al revés sería un bug visible**: la cuota devuelta sin decir por qué, que
es el hueco que esto cierra.

### La regla que hace innecesario un tercer código

El motivo se muestra **solo mientras `cod_estcuo in (3, 10)`**. Cuando el
solicitante corrige y reenvía, la cuota vuelve a 2 y el motivo deja de verse sin
que haya que marcar nada. Por eso no hace falta un `id_tipacc` de "reenvió
corregida" para que "el motivo vigente" sea inequívoco.

### Capas a tocar

| Capa | Cambio |
| :--- | :--- |
| `sg_tacc` | semilla 31 y 32 |
| `sg_histiSecgen04` · `sg_histsSecgen06` | PA nuevos |
| `sg_epaguSecgen03` | **exigir** `@observacion` cuando `@cod_estcuo in (3, 10)`. Hoy lo declara y lo descarta |
| `history-action-type.constant.ts` | los dos códigos nuevos |
| `…payment-procedures.repository.ts` | armar el prefijo, bajar el tope de 255 a 220, insertar historial **antes** de resolver, y un método de lectura |
| `service-provision-payment.controller.ts` | exponer el motivo en el detalle de la cuota |
| `Du288PaymentReviewDecisionRequest` | `observation` obligatorio para `observe` y `reject` |
| Vista DGDP (`_installmentNumber.vue`) | `b-form-textarea` en el bloque de decisión, contador a 220, obligatorio para devolver y rechazar |
| Vista solicitante | el motivo vigente, visible solo en estado 3 o 10 |
| `lang/es/pds.js` | textos nuevos (§15) |

**Cero DDL.** No se toca ninguna tabla existente ni se crea ninguna.

---

## 6. Lo que este camino cuesta, dicho claro

- **La llave de la cuota vive en texto libre.** No es indexable (hay que recorrer
  con `like` sobre `text`) y ningún constraint la protege: si alguien edita
  `observaci` por fuera, la fila queda huérfana. El volumen lo tolera — una fila
  por decisión, no por mes.
- **Las filas de pago entran en el payload de dos endpoints de resolución**
  (§0), excluidas por filtros de frontend. Para una solicitud archivada es
  aceptable, pero es acoplamiento real: si alguien agrega mañana una lectura de
  `sg_hist` sin filtrar `cod_modulo`, verá comentarios de pago.
- **`sg_tacc` es compartido.** Los códigos 31 y 32 quedan en el catálogo de todo
  SISSOLIC. Es una fila de datos, no esquema, pero es global.
- **El tope de 250** viene de `sg_histiSecgen03`, no de la columna (`text`). El
  PA nuevo puede declarar más, pero conviene mantener el mismo largo para no
  tener dos reglas.
- **Lo que se evita:** crear `sg_vpag`, su índice y su orden de despliegue — y la
  ventana en que el PA referencia una tabla que todavía no existe.

---

## 7. Estado real al 23-10-2026: esto **ya está implementado**

Revisión pedida sobre si existe `sg_hist2` y en qué etapas debería escribirse.

### 7.1 `sg_hist2` no existe, y no estaba diseñado

El único `hist2` del repositorio es un **alias** de `sg_hist` en el self-join de
`sg_histsSecgen03.sql` (líneas 40-41), el PA que lee el historial de todas las
solicitudes de una resolución. No es una tabla, y nunca se propuso crearla. La
tabla propia que sí se diseñó se llama `sg_vpag`, está en
[comentario_devolucion_dgdp_tabla.md](comentario_devolucion_dgdp_tabla.md) y
quedó **descartada**.

### 7.2 Lo que se implementó, y en qué se desvió del diseño

| Pieza del diseño | Estado | Desvío |
| :--- | :--- | :--- |
| Escribir el motivo en `sg_hist` | **implementado** | — |
| `sg_histiSecgen04` (PA nuevo con `cod_sistem`/`cod_modulo`) | **no se creó** | se usa el PA existente `sg_histiSecgen03` |
| `cod_sistem = 'SG'` · `cod_modulo = 'WFPAGOS'` | **no se escriben** | `Secgen03` no tiene esos parámetros |
| `id_tipacc` 31 / 32 | **32 / 33** | 31 ya estaba ocupado por `GROUPED_REQUEST` |
| `sg_histsSecgen06` (leer el motivo vigente) | **no se creó** | se lee `sg_histsSecgen02` completo y se filtra en el backend |
| Prefijo `#PRS{id}-C{n}#` como llave | **implementado** | — |
| Historial **antes** del cambio de estado | **implementado** | `recordInstallmentHistory` corre antes de `resolveDgdpInstallment` |
| `@observacion` obligatorio en `sg_epaguSecgen03` | **no** | el PA sigue declarándolo y descartándolo |

Dónde vive:

- escritura: `service-provision-payment-procedures.repository.ts` ·
  `recordInstallmentHistory`, con `insertInstallmentHistory` en
  `db-assets/.../service-provision-payment.ts`;
- lectura: `attachReviewObservations` (solicitante) y
  `attachDgdpReviewObservations` (bandeja DGDP), filtrando `id_tipacc in (32, 33)`
  y el prefijo;
- vista: `Du288InstallmentFormSection.vue` y `Du288InstallmentsSection.vue`,
  sobre `installment.reviewObservation`.

**La consecuencia del desvío:** sin `cod_sistem`/`cod_modulo`, el aislamiento
frente a resolución descansa entero en el filtro por `id_tipacc` + prefijo que
hace el backend. Es el acoplamiento que §6 ya anotaba como costo, pero una capa
más arriba de lo previsto: ahora ni la BDD ni el PA distinguen una fila de pago,
solo el código que la lee.

### 7.3 ¿En qué etapas del WF de pagos debería escribirse historial?

El historial **no hace falta para registrar qué pasó** —cada transición ya deja
su rastro en `sg_epag`— sino para registrar **por qué**, que es lo que ninguna
columna guarda.

| Etapa | PA | Transición | ¿Historial? |
| :--- | :--- | :--- | :--- |
| Crear cuota | `sg_epagiSecgen01` | — → 1 | no: borrador del propio solicitante, se puede eliminar |
| Editar cuota | `sg_epaguSecgen01` | 1→1 · 3→1 | no: mismo motivo |
| Eliminar cuota | `sg_epagdSecgen01` | 1 → borrada | no |
| Enviar a visación | `sg_epaguSecgen02` | 1→2 · 3→2 | **a evaluar**: ver 7.4 |
| **DGDP devuelve** | `sg_epaguSecgen03` | 2→3 | **sí** — implementado, `id_tipacc` 32 |
| **DGDP rechaza** | `sg_epaguSecgen03` | 2→10 | **sí** — implementado, `id_tipacc` 33 |
| DGDP aprueba | `sg_epaguSecgen03` | 2→4 | no hace falta: no hay texto que guardar y `fec_valida` lo fecha |
| Autorizar · enviar a remuneraciones | — | 4→8 | la etapa no existe todavía (`rut_autori`, `fec_envrem` no los escribe nadie) |

### 7.4 Lo único que falta decidir: el reenvío

`sg_epag` guarda **la última** ocurrencia de cada dato, no la secuencia:
`rut_solici` y `fec_solici` se sobrescriben en cada envío. En el ciclo
*enviar → devolver → corregir → reenviar*, al terminar queda registrado el
último envío y el último motivo, y **los intermedios se pierden**.

Hoy eso no estorba, porque el motivo se muestra solo mientras la cuota está en 3
o 10 y el que importa es el vigente. Estorbaría si se quisiera responder *"¿cuántas
veces se devolvió esta cuota y por qué cada vez?"* — las filas de devolución sí
se acumulan en `sg_hist`, pero no hay con qué emparejarlas al reenvío que las
respondió.

Si se quiere ese hilo completo, el agregado es **una** etapa: historial en el
envío a visación (`sg_epaguSecgen02`), con un `id_tipacc` nuevo y sin texto
obligatorio. Es la decisión pendiente; no es necesaria para lo que la pantalla
muestra hoy.

### 7.5 `sg_his2` — existe, ya se escribe, y no sirve para esto

La tabla de la BDD de prueba se llama **`sg_his2`** (no `sg_hist2`):

```sql
create table secgen_db.dbo.sg_his2 (
    id_funprse int      not null,
    f_visacion datetime not null,
    rut_visado char(9)  not null,
    cod_estact tinyint  not null,
    cod_estnue tinyint  not null,
    constraint SG_HIS2_PK primary key (id_funprse, f_visacion)
)
-- FK: id_funprse -> sg_fups
```

**No es una tabla pendiente: ya está en uso.** `sg_fupsuSecgen01` —incluida la
copia de `cambios_pa/sg_fups/`— inserta una fila cada vez que llega un
`@cod_estfun` distinto del actual, en la **misma transacción** del `update` a
`sg_fups`. Si el insert falla devuelve `STAFF_HISTORY_ERROR` y hace rollback: el
historial es obligatorio, no best-effort.

```sql
if @cod_estfun is not null and (isnull(@current_estfun, 0) <> @cod_estfun)
begin
    insert into sg_his2 (id_funprse, f_visacion, rut_visado, cod_estact, cod_estnue)
    values (@id_funprse, getdate(), isnull(@rut_visado, 'SYSTEM'),
            isnull(@current_estfun, 1), @cod_estfun)
    ...
end
```

#### De qué historial se trata

De la **visación del funcionario dentro de la solicitud**, no del pago. Los
estados son los de `sg_efun`:

| `cod_estfun` | |
| :-- | :--- |
| 1 | Pendiente de revisión |
| 2 | Observado |
| 3 | Aprobado |
| 4 | Rechazado |
| 5 | Excluido |

Son los estados que mueven los visadores en el WF de resolución al revisar la
nómina de funcionarios. El WF de pagos no los toca: ahí lo que cambia de estado
es la **cuota**, en `sg_epag.cod_estcuo` con el catálogo `sg_ecuo` (1 Propuesta,
2 En visación, 3 Devuelta, 4 Aprobada, 8 Enviada a remuneraciones, 10 Rechazada).

#### Por qué no sirve para el comentario de devolución

1. **No tiene columna de texto.** Ni `observaci` ni `comentario`. Guarda *quién,
   cuándo, de qué estado a cuál*: el **qué**, nunca el **por qué**. El motivo de
   devolución DGDP es exactamente el por qué.
2. **Su grano es la prestación, no la cuota.** La PK es
   `(id_funprse, f_visacion)`. Una prestación tiene hasta 12 cuotas y cada una se
   devuelve por separado; con esa llave no hay dónde decir *"cuota 3"*.

Por eso el motivo quedó en `sg_hist` (§7.2) y no acá. No es una elección que
convenga revisar: no es que `sg_his2` sea peor, es que no tiene dónde guardar el
dato.

#### Para qué sí podría servir en pagos

Para una cosa distinta, y solo si se decide que **la prestación** cambia de
estado al pagarse. Hoy `cod_estfun` queda en 3 Aprobado cuando se archiva la
resolución, y el WF de pagos nunca lo mueve. Si alguna vez se quiere un estado
*En pago* / *Pagada* a nivel de prestación, `sg_his2` ya es el lugar correcto y
**no hay que crear ni modificar nada**: basta que la capa de pagos pase
`@cod_estfun` y `@rut_visado` a `sg_fupsuSecgen01`, más las dos semillas en
`sg_efun`. Es una decisión de negocio, no una necesidad técnica de lo que hay hoy.

#### Dos detalles del esquema, para tenerlos anotados

- **`cod_estact` y `cod_estnue` no tienen FK a `sg_efun`**, aunque el catastro de
  certificación declara la relación. La validación vive en el PA
  (`if not exists (select 1 from sg_efun where cod_estfun = @cod_estfun)`), no en
  el esquema: cualquier insert que no pase por `sg_fupsuSecgen01` puede meter un
  código inexistente.
- **La PK usa `getdate()`**, así que dos cambios de estado de la **misma**
  prestación dentro del mismo tick de `datetime` (≈1/300 s en ASE) chocan por
  llave duplicada. Desde la pantalla es improbable; en una carga masiva o un
  reproceso automático, no tanto.

### 7.6 Auditoría del CRUD de `sg_his2`: la escritura existe y nunca ocurre

| Operación | Camino | Estado |
| :--- | :--- | :--- |
| **C** insertar | `sg_fupsuSecgen01` — tres copias, todas con el bloque (`cambios_pa/sg_fups/` es la normalizada, la que además agrega `@ext_cuotas`) | existe, **no se dispara** |
| **R** leer | **ninguno**: cero PA lee `sg_his2`, cero referencia en el backend | **falta** |
| **U** actualizar | ninguno | correcto: es un log de solo-agregar |
| **D** borrar | `sg_solidSecgen01` en cascada al borrar la solicitud (está en `certificacion_next` y `solicitante`, no en `certificacion_03_09_2026`), más `limpia_datos_pds_desarrollo.sql` | existe |

#### Por qué el insert nunca se dispara

La condición del PA es:

```sql
if @cod_estfun is not null and (isnull(@current_estfun, 0) <> @cod_estfun)
```

Y la cadena que la alimenta no la cumple nunca:

1. `PdsDu288RequestForm.vue:5170` manda `codEstfun` **null al crear** y, al editar,
   el valor que ya tenía (`resolveEditingWorkerCodEstfun` lo preserva).
2. El repositorio lo copia tal cual al parámetro
   (`service-provision-request-procedures.repository.ts:2165`).
3. **Ninguna acción de la aplicación mueve `cod_estfun`.** No existe el gesto de
   "observar / rechazar / excluir funcionario" en el flujo de visación: lo que se
   visa es la solicitud completa, y el estado individual del funcionario quedó
   como catálogo sin flujo que lo use.

Resultado: al crear no hay fila (el insert vive solo en el PA de *update*), y al
editar el estado entra igual al que ya estaba. **La tabla se queda vacía**, aunque
el código para llenarla esté escrito y probado.

#### Dos cosas más que aparecieron al revisar

**`@rut_visado` no se pasa.** El template `updateStaff` del backend
(`db-assets/.../service-provision-request.ts:87`) manda 22 parámetros y ese no
está. Si el insert se disparara, cada fila quedaría con
`rut_visado = 'SYSTEM'` por el `isnull` del PA — perdiendo exactamente el dato que
hace útil un historial de visación.

**`updateStaffStatus` salta el PA entero.** Es un `update` crudo sobre la tabla:

```sql
UPDATE secgen_db.dbo.sg_fups
SET cod_estfun = {{ cod_estfun }}
WHERE id_funprse = {{ id_funprse }}
```

Hoy **nadie lo llama** —el método existe en el repositorio (línea 4779) y no
tiene consumidores—, así que no está haciendo daño. Pero salta las dos cosas que
protegen el dato: la validación contra `sg_efun` y el insert en `sg_his2`. Si
alguien implementa la visación del funcionario y toma ese atajo, la tabla no se
llena y nadie lo nota.

#### Qué falta si se decide usarla

En orden, porque el tercero manda sobre los dos primeros:

1. **Decidir qué acción mueve `cod_estfun`.** Sin eso, lo demás no sirve de nada.
   Para el WF de pagos sería un estado de la prestación (*En pago* / *Pagada*),
   con sus semillas en `sg_efun`.
2. **Pasar `@rut_visado`** en el template `updateStaff` — una línea.
3. **Crear el PA de lectura** (`sg_his2sSecgen01 @id_funprse`), que no existe:
   hoy la tabla no se puede consultar desde la aplicación.
4. **Eliminar `updateStaffStatus`** o dejarlo delegando en el PA, para que no
   quede un camino que esquiva el historial.
