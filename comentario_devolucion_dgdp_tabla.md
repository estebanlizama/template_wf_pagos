# Tabla y PA propios para el comentario de DGDP

Restricción: **no se modifica ninguna tabla existente** — ni `sg_hist` ni
`sg_epag` ni ninguna otra reciben campos nuevos — y el impacto sobre lo ya
desarrollado tiene que ser el mínimo.

Reemplaza el camino sobre `sg_hist` de
[comentario_devolucion_dgdp_diseno.md](comentario_devolucion_dgdp_diseno.md).

Fecha: 20-10-2026. Diseño, no implementación.

> **Alternativa no elegida.** Se optó por reutilizar `sg_hist` sin DDL: ver
> [comentario_devolucion_dgdp_diseno.md](comentario_devolucion_dgdp_diseno.md). El
> argumento que lo permitió es que `sg_epagiSecgen01` exige `soli.cod_estsol = 11`,
> así que la línea de tiempo de resolución ya está cerrada cuando nace un pago.
> Este documento queda como el diseño de la tabla propia, por si se retoma.

---

## 0. Esto ya estaba decidido en este proyecto

`impacto_cambios/impacto_12_bandeja_dgdp_sin_apso.md` §4 analizó exactamente esta
pregunta, descartó `sg_apso` por las mismas razones, y recomendó la **opción A**:

```sql
ALTER TABLE secgen_db.dbo.sg_epag ADD rut_valida char(9)      NULL
ALTER TABLE secgen_db.dbo.sg_epag ADD fec_valida datetime     NULL
ALTER TABLE secgen_db.dbo.sg_epag ADD observacio varchar(255) NULL
```

Su §6 lo deja en el mapa del flujo: paso **5a Devolver → `sg_epag` 2→3 ·
`observacio`**.

**Nada de eso se implementó.** Las tres columnas no existen hoy, y `grep` de
`rut_valida` / `observacio` sobre `cambios_pa/` y el backend no devuelve una sola
escritura. Lo que quedó es el muñón: `sg_epaguSecgen03` declara `@observacion
varchar(255)` — **el mismo largo exacto** — y lo descarta. El PA se escribió
esperando esas columnas.

**Y la opción A queda descartada por la restricción nueva:** son tres campos
nuevos en una tabla existente. Hay que anotarlo en `impacto_12`, o alguien las
agrega después por inercia.

---

## 1. Por qué `sg_hist` sí afecta a resolución — verificado

El camino sin DDL (escribir en `sg_hist` con códigos nuevos de `sg_tacc`) **no
cumple** "sin afectar lo ya desarrollado". No es una opinión; está en el código:

| Lectura | Filtro por `id_tipacc` | Quién la usa |
| :--- | :--- | :--- |
| `sg_histsSecgen02` | **ninguno** — devuelve el hilo completo de la solicitud | `getRequestAndResolutionHistoricals`, que la vista de resolución PDS llama en `resolution-format-normative.vue:726` |
| `selectByNroResolutionAndRequestId` | **ninguno** — `where nro_solici = X or nro_resolu = Y` | el modal de flujo de la solicitud PDS (`service-provision-request.controller.ts:719`) |

Las dos leen **todo** lo que haya con ese `nro_solici`. Una devolución de cuota
de pago entraría en las dos respuestas.

No se rompería nada hoy: la vista de resolución filtra después, en el frontend,
con `actionType === 4 || actionType === 9`, y 31/32 no calzan. Pero eso significa
que **el aislamiento quedaría dependiendo de un filtro del frontend que alguien
tiene que recordar**, con los datos de pago viajando igual en el payload de un
endpoint de resolución. Es exactamente la clase de acoplamiento que se quiere
evitar.

Lo mismo, dicho por `impacto_12` cuando descartó `sg_apso`:

> Consultar *"aprobaciones de la solicitud 205"* devolvería las visaciones de la
> resolución **y** las del pago. Todo query tendría que filtrar por `cod_flusol`.

---

## 2. Qué hacemos entonces: una tabla propia, y nada más

Una tabla nueva **no modifica nada existente**: cumple la restricción al pie de
la letra. Y el aislamiento sale gratis, igual que ya lo tienen `sg_epag` y
`sg_dpag` — `impacto_12` §5 lo tabuló: el pago no escribe en `sg_soli`, ni en
`sg_prse`, ni en `sg_apso`.

```sql
create table secgen_db.dbo.sg_vpag (
    id_funprse int          not null,   /* cuota: prestacion…      */
    nro_cuota  tinyint      not null,   /* …y correlativo de cuota */
    nro_linea  tinyint      not null,   /* 1, 2, 3… por cuota      */
    cod_estcuo tinyint      not null,   /* la decision: 3, 4 o 10  */
    rut_valida char(9)      not null,   /* quien de DGDP resolvio  */
    id_perfil  smallint         null,   /* con que perfil lo hizo  */
    observacio varchar(255)     null,   /* el motivo               */
    f_creacion datetime     not null,
    constraint SG_VPAG_PK primary key (id_funprse, nro_cuota, nro_linea),
    constraint FK_sg_vpag_sg_epag foreign key (id_funprse, nro_cuota)
        references secgen_db.dbo.sg_epag (id_funprse, nro_cuota)
        on delete restrict on update restrict,
    constraint FK_sg_vpag_sg_ecuo foreign key (cod_estcuo)
        references secgen_db.dbo.sg_ecuo (cod_estcuo)
        on delete restrict on update restrict
)

create unique index PK_sg_vpag on secgen_db.dbo.sg_vpag (id_funprse, nro_cuota, nro_linea)
```

### Lo que hace que el impacto sea realmente mínimo: no hay `sg_parm`

La versión anterior de este diseño usaba un `id_vispag` correlativo sacado de
`sg_parm`, como hace `sg_hist`. Eso obligaba a **insertar una fila en `sg_parm`**,
que es una tabla existente, y arrastraba ~15 líneas de PA para mover el
correlativo con su manejo de error.

Con `nro_linea` correlativo **dentro de la cuota** eso desaparece. No es un
invento: es el patrón que ya usan cuatro tablas del mismo esquema —

| Tabla | PK |
| :--- | :--- |
| `sg_drec` | `(nro_solici, nro_linea)` |
| `sg_apcc` | `(nro_solici, nro_linea)` |
| `sg_cicc` | `(nro_solici, nro_linea)` |
| `sg_bcre` | `(nro_solici, correlativ)` |

Resultado: **cero escrituras en cualquier tabla existente**. La tabla nueva es el
único objeto de datos que se toca.

### El resto de las decisiones del modelo

- **`id_funprse` + `nro_cuota`, no un id de cuota.** `sg_epag` no tiene clave
  subrogada: su PK **es** ese par. La FK compuesta es la única forma de amarrarlo.
- **`cod_estcuo` con FK a `sg_ecuo`.** La decisión se guarda con el mismo catálogo
  que ya usa `sg_epag.cod_estcuo`, así que 3 / 4 / 10 significan lo mismo en las
  dos tablas y no hay nada que traducir. *(A diferencia de `sg_ecuo` vs `sg_efum`,
  que el README de `datos_base` advierte que no coinciden.)*
- **`id_perfil` nulable.** El perfil se deriva hoy (`33`, Validador de pagos
  DGDP), pero una persona puede perderlo después. Una tabla de auditoría guarda
  la autoridad **con la que se actuó**, no la vigente. Es el criterio de `sg_hist`.
- **`observacio` nulable.** Aprobar no exige motivo; devolver y rechazar sí, y eso
  lo valida el PA.
- **`varchar(255)`**, igual que la opción A de `impacto_12` y que el parámetro que
  ya existe en `sg_epaguSecgen03`.

### El "formato para identificar los de pago" es la FK

No hace falta columna de origen, ni rango de códigos reservado, ni prefijo en un
texto. La tabla cuelga de `sg_epag(id_funprse, nro_cuota)`, que es la llave de una
cuota de pago: **una fila que no sea de pagos no se puede insertar** — la
restricción la rechaza. Nada que un `where` pueda olvidar, y nada que haya que
documentar para que el próximo no lo rompa.

Tampoco hace falta `sg_tacc`, ni `sg_eta1`, ni `sg_tfls`, ni registrar un
`cod_flusol` de pagos — que es justo lo que `impacto_12` §7 celebra que este
diseño evita.

---

## 3. Ejemplo

**Escenario.** Solicitud 4821, resolución 1570/2026. Pérez (`id_funprse` 1234) y
Soto (1235). DGDP (RUT 152421516, perfil 33) devuelve la cuota 2 de Pérez; Pérez
corrige y reenvía; DGDP la aprueba. Y rechaza la cuota 1 de Soto.

| `id_funprse` | `nro_cuota` | `nro_linea` | `cod_estcuo` | `rut_valida` | `id_perfil` | `observacio` | `f_creacion` |
| ---: | ---: | ---: | ---: | :--- | ---: | :--- | :--- |
| 1234 | 2 | 1 | 3 | 152421516 | 33 | Abril quedo con 74.074 y el mes solo tiene 3 dias ejecutados. Corregir el monto o sacar el mes de la cuota. | 2026-10-20 11:42 |
| 1234 | 2 | 2 | 4 | 152421516 | 33 | `null` | 2026-10-22 09:15 |
| 1235 | 1 | 1 | 10 | 152421516 | 33 | La prestacion no tiene resolucion vigente para el periodo que se cobra. | 2026-10-20 11:47 |

Lo que se lee de ahí:

- cuota 2 de Pérez, hoy en estado 4: su última línea no tiene motivo, así que no
  se muestra nada, y **la línea 1 queda como traza**, no como mensaje vivo;
- cuota 1 de Soto, en 10: muestra el motivo de su línea 1;
- y queda registrado que la misma persona devolvió y después aprobó la misma
  cuota — que es lo que tres columnas sobre `sg_epag` **no** pueden contar, porque
  la segunda decisión sobreescribe la primera.

---

## 4. Los PA

### El insert va **inline** en `sg_epaguSecgen03`

Es la ventaja grande de tener tabla propia, y la razón por la que el impacto es
chico: el `insert` entra **dentro de la transacción que ya existe**, junto al
`update cod_estcuo`. El motivo y el estado quedan atómicos: no hay forma de dejar
una cuota devuelta sin decir por qué.

Con `sg_hist` esto no se podía: habría que llamar a `sg_histiSecgen03`, que abre
su propia transacción y **emite su propio `select` de estado**, que contaminaría el
resultado que hoy lee `assertMutationResult`.

Lo que se agrega a `sg_epaguSecgen03`, después de sus guardias y antes del
`update` del estado:

```sql
/* Devolver o rechazar sin decir por que es el hueco que esto cierra. */
if @cod_estcuo in (3, 10)
   and (@observacion is null or ltrim(rtrim(@observacion)) = '')
begin
    rollback transaction
    select 'Debe indicar el motivo para devolver o rechazar la cuota.' as msg
    return
end

declare @nro_linea tinyint

select @nro_linea = isnull(max(nro_linea), 0) + 1
  from secgen_db.dbo.sg_vpag holdlock
 where id_funprse = @id_funprse
   and nro_cuota  = @nro_cuota

insert into secgen_db.dbo.sg_vpag (
    id_funprse, nro_cuota, nro_linea, cod_estcuo,
    rut_valida, id_perfil, observacio, f_creacion
) values (
    @id_funprse, @nro_cuota, @nro_linea, @cod_estcuo,
    @rut_person, @id_perfil, @observacion, getdate()
)

if @@error <> 0 or @@rowcount <> 1
begin
    rollback transaction
    select 'Error al registrar la visacion de la cuota.' as msg
    return
end
```

Eso es todo el cambio de escritura: un `declare`, un `select max`, un `insert` y
su control de error. El `holdlock` sobre el `select max` es el que impide que dos
revisores saquen el mismo `nro_linea`; va dentro de la transacción que el PA ya
tiene abierta, así que no hay transacción nueva que manejar.

`sg_epaguSecgen03` gana un parámetro: `@id_perfil smallint = null`.

### `sg_vpagsSecgen01` — leer el motivo vigente

Mismo patrón de `sg_histsSecgen05`: ordena descendente y devuelve; el llamador
toma la primera fila.

```sql
/* Procedimiento : sg_vpagsSecgen01

   Entrada :
   @id_funprse          -> Prestacion del funcionario. (Obligatorio)
   @nro_cuota           -> Correlativo de la cuota. (Obligatorio)

   Objetivo : Listar las visaciones DGDP de una cuota de pago, de la mas
   reciente a la mas antigua. La primera fila es el motivo vigente.

   Creacion: ELA 2026/10/20
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_vpagsSecgen01
    @id_funprse int     = null,
    @nro_cuota  tinyint = null
as

if isnull(@id_funprse, 0) <= 0 or isnull(@nro_cuota, 0) <= 0
begin
    select 'Faltan antecedentes para consultar las visaciones.' as msg
    return
end

select
    vpag.nro_linea,
    vpag.cod_estcuo,
    ecuo.des_estcuo,
    vpag.observacio,
    vpag.f_creacion,
    vpag.rut_valida,
    pers.nom_nombre + ' ' + pers.nom_appate + ' ' + pers.nom_apmate as nombre,
    per1.des_perfil
  from secgen_db.dbo.sg_vpag vpag
  left join secgen_db.dbo.sg_ecuo ecuo on ecuo.cod_estcuo = vpag.cod_estcuo
  left join sisper_db..sp_pers   pers on pers.rut_person  = vpag.rut_valida
  left join sistema_db..bd_per1  per1 on per1.cod_perfil  = vpag.id_perfil
                                     and per1.cod_sistem  = 'SG'
                                     and per1.cod_modulo  = 'SISSOLIC'
 where vpag.id_funprse = @id_funprse
   and vpag.nro_cuota  = @nro_cuota
 order by vpag.nro_linea desc
go

grant execute on Analisis2.sg_vpagsSecgen01 to UsuaVrac
go
```

Sin `like`, sin `substring`, sin prefijo que parsear: el `where` es la llave. Y el
`order by nro_linea desc` usa el índice de la PK, sin depender de la resolución
del `datetime`.

### ¿Hace falta un PA de inserción aparte?

Solo si DGDP tiene que poder dejar un comentario **sin** mover el estado — una
nota mientras revisa. Si el comentario siempre acompaña una decisión, el inline
basta y `sg_vpagiSecgen01` no se escribe. Queda por confirmar (§6.2).

---

## 5. El impacto, contado

| | Objetos nuevos | Tablas existentes modificadas | PA existentes modificados | Resolución |
| :--- | :--- | :--- | :--- | :--- |
| **`sg_vpag`** | 1 tabla + 1 índice + 1 PA de lectura | **ninguna** | `sg_epaguSecgen03` (de pagos) | **nada** |
| 3 columnas en `sg_epag` | — | **1** (`sg_epag`, 3 campos) | `sg_epaguSecgen03` | nada |
| `sg_hist` con prefijo | 2 filas en `sg_tacc` + 1 PA de lectura | `sg_tacc` (datos), `sg_hist` (filas de pago) | `sg_epaguSecgen03` | **cambia lo que devuelven 2 lecturas** (§1) |

`sg_vpag` es la única de las tres que no agrega campos a nada existente **y** deja
a resolución intacta. Las capas de aplicación a tocar son las mismas en los tres
casos.

### Capas a tocar

| Capa | Cambio |
| :--- | :--- |
| DDL | `create table sg_vpag` + su índice único |
| `sg_epaguSecgen03` | **usar** `@observacion`: el bloque de §4, más `@id_perfil` |
| `sg_vpagsSecgen01` | PA nuevo (lectura) |
| `…payment-procedures.repository.ts` | pasar `id_perfil`, y un método de lectura del motivo |
| `service-provision-payment.controller.ts` | exponer el motivo en el detalle de la cuota |
| `Du288PaymentReviewDecisionRequest` | `observation` obligatorio para `observe` y `reject` |
| Vista DGDP (`_installmentNumber.vue`) | `b-form-textarea` en el bloque de decisión, contador a 255, obligatorio para devolver y rechazar |
| Vista solicitante | el motivo vigente, visible solo en estado 3 o 10 |
| `lang/es/pds.js` | textos nuevos (§15) |
| `datos_base/` + `orden_de_despliegue.md` | el DDL, en su orden |

El DDL va aparte del `datos_base`, como ya dice su README: *"El DDL … va aparte,
en el modelo."* Y no hay semilla que cargar.

### Orden de despliegue

`sg_vpag` tiene que existir **antes** de recompilar `sg_epaguSecgen03`: el PA
referencia la tabla en su `insert`, y sin ella DGDP no puede resolver ninguna
cuota. Es la misma clase de ventana que `orden_de_despliegue.md` documenta para
`sg_fume.cod_estcuo`, y se evita igual: tabla primero, después PA y backend
juntos.

---

## 6. Qué confirmar antes de implementar

1. **Cerrar la opción A en `impacto_12`.** Está aprobada y sin implementar. Si se
   va con `sg_vpag`, anotarlo ahí para que las tres columnas no se agreguen
   después.
2. **¿El comentario puede ir solo**, sin decisión? Decide si hace falta
   `sg_vpagiSecgen01` o basta el inline.
3. **`varchar(255)` o `text`?** Pregunta abierta desde `impacto_12` §9.1. Si se
   cambia, hay que mover a la vez el parámetro del PA y el tope del repositorio
   (hoy valida 255).
4. **¿Se registra quién *tomó* la cuota** (6→2), o solo quién la resolvió?
   `impacto_12` §9.2. Con `sg_vpag` se resuelve agregando el 2 a los `cod_estcuo`
   admitidos.
5. **¿El solicitante puede responder?** Hoy no está en el alcance. `sg_vpag` lo
   admite con una línea de otro `rut_valida`, pero habría que relajar el guardia
   DGDP — y ahí conviene un PA aparte, no relajar `sg_epaguSecgen03`.
