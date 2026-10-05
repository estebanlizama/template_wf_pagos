# Qué se guarda, dónde y con qué estado

**Fecha:** 05-10-2026
**Verificado:** trazando cada `insert`/`update`/`delete` de los PA y contrastándolo con lo que quedó
en la base tras crear la cuota 1 de la prestación 7.

---

## 1. Las cuatro tablas que escribe el jefe de proyecto

| Tabla | Grano | Qué guarda |
| :--- | :--- | :--- |
| `sg_fume` | un mes de ejecución | el monto que se cobrará por ese mes |
| `sg_epag` | una cuota | el encabezado: quién la pidió, cuándo y en qué mes se paga |
| `sg_dpag` | puente | qué meses componen qué cuota |
| `sg_fuc2` | un tramo | la compensación efectivamente realizada |

`sg_fuco` (compensación comprometida) **no se toca**: pertenece a resolución.

---

## 2. Acción por acción

### Guardar el monto de un mes · `sg_fumeuSecgen02`

```sql
update sg_fume
   set mto_apagar = @mto_apagar,
       ano_ejec   = isnull(@ano_ejec, ano_ejec),
       mes_ejec   = isnull(@mes_ejec, mes_ejec)
```

Solo tres columnas. **No cambia `cod_estfum`**: fijar un monto no es una decisión de flujo.

`ano_ejec`/`mes_ejec` solo se escriben si llegan con valor; si no, conservan lo que tenían. La
pantalla los manda vacíos cuando el mes no tiene ejecución real distinta de la propuesta.

> Se dispara también en modalidad **Fija**, donde el monto lo calcula el sistema. Es obligatorio:
> `sg_epagsSecgen01` arma el monto de la cuota como `sum(sg_fume.mto_apagar)`, así que sin persistir
> queda en $0.

### Crear una cuota · `sg_epagiSecgen01`

Una transacción con dos inserts:

```sql
insert into sg_epag (id_funprse, nro_cuota, cod_estcuo, rut_solici,
                     fec_solici, id_evidenc, ano_pago, mes_pago)
values (@id_funprse, @nro_cuota, 1, @rut_person, getdate(), ...)

insert into sg_dpag (id_funprse, nro_cuota, corr_fume)
select @id_funprse, @nro_cuota, corr_fume from #corr
```

| Columna | De dónde sale |
| :--- | :--- |
| `nro_cuota` | correlativo calculado, no lo elige el usuario |
| `cod_estcuo` | **1 · Propuesta**, fijo |
| `rut_solici` · `fec_solici` | el jefe autenticado y la hora del servidor, no del cliente |
| `ano_pago` · `mes_pago` | lo único que el usuario escribe del encabezado |

**Los meses no cambian de estado al crear la cuota.** Siguen en `cod_estfum = 1`.

### Editar una cuota · `sg_epaguSecgen01`

Actualiza `ano_pago`, `mes_pago`, `id_evidenc`, y **rehace `sg_dpag` entero** (borra e inserta).
No toca `cod_estcuo` ni `cod_estfum`.

Admite estados **1 y 3**, pero con un límite:

```sql
if @cod_estcuo = 3 and (@pedidos <> @actuales or @comunes <> @actuales)
    'Error: Una cuota observada no puede cambiar los meses que abarca'
```

Eso evita que un mes quede huérfano: en estado 3 los meses ya están en `cod_estfum = 2`, y sacarlos
de la cuota los dejaría comprometidos sin cuota y fuera de `disponible`.

### Eliminar una cuota · `sg_epagdSecgen01`

Borra `sg_dpag` y luego `sg_epag`, en transacción. **Solo en estado 1.** Por eso no necesita
devolver ningún mes a `cod_estfum = 1`: en estado 1 nunca salieron de ahí.

### Enviar a visación · `sg_epaguSecgen02`

El único PA que mueve estados, y mueve dos:

```sql
update sg_epag set cod_estcuo = 2, rut_solici = @rut_person, fec_solici = getdate()

if @cod_estcuo = 1            -- solo en el primer envío
    update sg_fume set cod_estfum = 2
      ... join sg_dpag por (id_funprse, nro_cuota)
```

| | De | A |
| :--- | :-- | :-- |
| La cuota | 1 Propuesta · 3 Observada | **2 En visación** |
| Sus meses | 1 Propuesta | **2 Comprometida** |

El `if @cod_estcuo = 1` importa: al reenviar una cuota **observada** los meses ya están en 2 y no se
vuelven a tocar.

### Compensación · `sg_fuc2iSecgen01` / `sg_fuc2dSecgen01`

Insertan y borran filas de `sg_fuc2`. **No tocan ningún estado.** La compensación es un hecho
registrado, no una transición.

---

## 3. Lo que ningún PA escribe

| Columna | Quién la llena |
| :--- | :--- |
| `mto_deslic` · `mto_dessg` | DGDP al visar — hoy **nadie**, el lado DGDP no existe |
| `mto_realpa` | al cerrar la cuota |
| `val_licmed` · `val_inabili` · `val_singoce` · `val_ciecc` · `fec_valida` | la visación |
| `rut_autori` · `fec_autori` · `fec_envrem` | la autorización y el envío a remuneraciones |
| `id_evidenc` | el respaldo, parqueado |

Todas se **leen** en los PA de consulta. Es el lado que falta construir.

---

## 4. Comprobación sobre la base

Tras crear la cuota con septiembre 2026:

```
sg_epag   nro_cuota 1 · cod_estcuo 1 Propuesta · rut_solici 056024069
          fec_solici 2026-10-05 · ano_pago 2026 · mes_pago 10
sg_dpag   (7, 1, 1)
sg_fume   corr_fume 1 · mto_apagar 141.111 · cod_estfum 1 Propuesta
```

Coincide con el mapa: la cuota nace en 1, el mes conserva su estado y solo recibe el monto.

---

## 5. Dos desalineaciones corregidas en la pantalla

El backend deriva `isEditable` de `EDITABLE_STATUS = [1, 3]`, y la pantalla usaba ese único booleano
para habilitar **todas** las acciones. Los PA son más finos:

| Acción | Lo que acepta el PA | Lo que ofrecía la pantalla |
| :--- | :--- | :--- |
| Cambiar los meses | solo estado 1 | también en 3 → el PA rechazaba |
| Eliminar | solo estado 1 | también en 3 → el PA rechazaba |

Ahora en una cuota observada las casillas de mes quedan bloqueadas con el motivo, y el botón
**Eliminar** no aparece. Editar el mes de pago y reenviar sigue disponible, que es justamente lo que
una observación pide corregir.

---

## 5.1 Agregar la cuota bloqueaba la compensación

El caso más dañino de lo anterior, y por el mismo motivo. El bloque de meses decidía así:

```js
canManage(item) { return item.isAvailable && !item.isAssigned }
```

Es decir: apenas el mes entra en una cuota —aunque esté en borrador— se apagaba el botón de
compensación. Los PA no dicen eso. `sg_fuc2iSecgen01` y `sg_fumeuSecgen02` usan los dos la misma
condición:

```sql
if @cod_estfum <> 1 and isnull(@cod_estcuo, 0) <> 3
    'El mes de ejecucion ya no admite cambios'
```

**Admite cambios mientras el mes esté propuesto, o cuando su cuota volvió observada.** Pertenecer
a una cuota en borrador no entra en la regla: los meses recién pasan a `cod_estfum = 2` al
*enviar*.

Comprobado contra la base: con el mes 1 dentro de la cuota 1, el alta de un tramo devolvió
`{success: true}`. El backend aceptaba lo que la pantalla impedía.

Y el orden quedaba al revés: la compensación completa es requisito **para enviar** la cuota. Si
armarla cerraba la compensación, no había manera de terminarla — había que borrar la cuota,
compensar y rehacerla.

`isAvailable` tampoco correspondía ahí: significa *se puede meter en una cuota*, e incluye que el
mes ya haya pasado. Compensar ocurre **durante** la ejecución, no después.

Las dos puertas —compensar y editar el monto— quedaron como los PA:

```js
acceptsChanges(item) {
  return Boolean(item.isProposed) || Number(item.installmentStatusCode || 0) === 3
}
```

---

## 6. Un dato que no se puede usar solo

`disponible` en `sg_fumesSecgen02` se calcula así:

```sql
case when fm.cod_estfum = 1
      and ((fm.ano_prop * 100 + fm.mes_prop) < @mes_actual or fu.f_termino < getdate())
     then 'S' else 'N' end
```

**No mira `sg_dpag`.** Comprobado en la base: el mes de la cuota 1 vuelve con
`isAvailable: true` **y** `isAssigned: true` a la vez.

Quien decida si un mes se puede incluir debe mirar las dos cosas. El formulario revisa primero
`installmentNumber` y por eso no ofrece un mes ya tomado; `canManage` en el bloque de meses hace lo
mismo con `isAvailable && !isAssigned`.
