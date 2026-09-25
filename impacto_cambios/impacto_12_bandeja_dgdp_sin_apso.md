# Bandeja DGDP sin `sg_apso` — qué hace falta realmente

Flujo definitivo: **crear encabezado → DGDP valida → enviar por PA a Finanzas.** Una sola etapa
revisora, sin devolución desde Finanzas, sin visaciones intermedias.

---

## 1. Primero: la bandeja no necesita tabla de asignación

Ese era el temor, y no existe.

`sg_apso` en resolución resuelve un problema que el pago **no tiene**: varias etapas encadenadas,
cada una con su perfil, con escalamiento, omisiones y subrogancia. Ahí sí hace falta persistir
*"a quién le toca ahora"*, porque depende de una escalera de responsables.

En el pago hay **una sola etapa y bandeja común** (Q-E: cualquier DGDP la toma). Entonces la
bandeja es una consulta, no una asignación:

```
bandeja DGDP = encabezados con cod_estcuo = 6 (Solicitada pago)
tomadas      = encabezados con cod_estcuo = 2 (En visación)
```

No hay a quién asignar: le toca a quien la tome. El estado **es** la bandeja.

---

## 2. Por qué `sg_apso` además incomoda

No es que no se pueda — es que tiene un costo:

| Problema | Detalle |
| :--- | :--- |
| `nro_solici` es `NOT NULL` y apunta a `sg_soli` | Habría que usar el número **de la resolución** |
| Auditoría mezclada | Consultar *"aprobaciones de la solicitud 205"* devolvería las visaciones de la resolución **y** las del pago. Todo query tendría que filtrar por `cod_flusol` |
| Motor de sobra | Traería escalamiento, omisiones y perfiles por etapa para un flujo de una sola etapa |
| No sabe de cuotas | No puede distinguir la aprobación de la cuota 1 de la de la cuota 2 |

Para un flujo lineal de una etapa, el motor configurable es más maquinaria de la que el problema
pide.

---

## 3. Lo que sí falta persistir

Con la bandeja resuelta por estado, quedan **tres datos sin dónde ir**:

| Dato | ¿Existe hoy? | Por qué hace falta |
| :--- | :---: | :--- |
| Quién de DGDP resolvió | ❌ | Trazabilidad: `sg_epag` sólo guarda quién **solicitó** |
| Cuándo resolvió | ❌ | Idem |
| **El comentario** al devolver o rechazar | ❌ | Sin esto el solicitante no sabe qué corregir |

El comentario es el bloqueante real. Los otros dos se podrían improvisar; sin el comentario, la
devolución a corrección no sirve.

### Lo que sí existe y no hay que duplicar

| Dato | Dónde |
| :--- | :--- |
| Quién autorizó cada mes | `sg_fume.rut_autori` · `fec_autori` |
| Cuándo se validó cada mes | `sg_fume.fec_valida` |
| Qué se detectó en cada mes | `sg_fume.val_licmed` · `val_singoce` · `val_inabili` · `val_ciecc` |
| Descuentos aplicados | `sg_fume.mto_deslic` · `mto_dessg` |
| Cuándo se envió a Finanzas | `sg_epag.fec_pago` |
| Historial de cambios por mes | `sg_fum2` |

`sg_fume.rut_autori` cubre el caso **aprobado**: si DGDP aprueba, todos los meses quedan con su
RUT. Lo que no cubre es **devuelto** o **rechazado**, donde ningún mes se autoriza pero alguien
igual tomó la decisión.

---

## 4. Las dos salidas

### A · Tres columnas en `sg_epag`

```sql
ALTER TABLE secgen_db.dbo.sg_epag ADD rut_valida char(9)     NULL
ALTER TABLE secgen_db.dbo.sg_epag ADD fec_valida datetime    NULL
ALTER TABLE secgen_db.dbo.sg_epag ADD observacio varchar(255) NULL
```

- Grano correcto: son datos del encabezado de pago, no del flujo de resolución.
- Espeja lo que `sg_fume` ya tiene a nivel de mes (`rut_autori`, `fec_valida`).
- La auditoría de la resolución queda intacta.
- Costo: 3 columnas de DDL.

### B · Reutilizar `sg_apso`

- Sin DDL.
- Costo: mezcla la auditoría, arrastra un motor de etapas que no se usa, y sigue sin poder
  distinguir cuotas.

> **Recomendación: A.** El flujo es lineal y de una etapa; no justifica el motor configurable. Y
> tres columnas nullable en una tabla nueva son más baratas que filtrar `cod_flusol` en cada
> consulta de auditoría de resolución para siempre.

---

## 5. Confirmación: el pago no toca nada de la resolución

| Tabla | Qué hace el pago |
| :--- | :--- |
| `sg_soli` | **nada** — la resolución queda archivada |
| `sg_prse` | **nada** — incluidos `cod_flusol` y `cod_etapa` |
| `sg_apso` | **nada** (con la opción A) |
| `sg_fups` | **nada** *(salvo `ext_cuotas`, que es de resolución)* |
| `sg_fume` | escribe montos, validaciones y estado del mes |
| `sg_epag` · `sg_dpag` | crea y mantiene la cuota |

Los datos de la resolución se **leen** como antecedente: monto total, tope, contrato, horario y
compensación comprometidos. Ninguno se modifica.

---

## 6. Cómo queda el flujo, sin motor de etapas

| Paso | Acción | Qué se escribe |
| :-- | :--- | :--- |
| 1 | Crear encabezado y agrupar meses | `sg_epag` estado **1** · `sg_dpag` |
| 2 | Asignar montos, mes de pago y respaldo | `sg_fume.mto_apagar` · `sg_epag.ano_pago`, `mes_pago`, `id_evidenc` |
| 3 | **Enviar** | `sg_epag` **1→6** · `sg_fume` **1→2** · consume cupo y saldo |
| 4 | DGDP toma de la bandeja | `sg_epag` **6→2** · `rut_valida`, `fec_valida` |
| 5a | Devolver | `sg_epag` **2→3** · `observacio` · meses **sin cambio** |
| 5b | Rechazar | `sg_epag` **2→10** · `observacio` · meses **2→1** |
| 5c | Aprobar | `sg_epag` **2→4** · `sg_fume.rut_autori`, `fec_autori` |
| 6 | Enviar por PA a Finanzas | `sg_epag` **4→8**, `fec_pago`, `mto_realpa` · `sg_fume` **2→3**, `fec_envrem` |

Sin `sg_eta1`, sin `sg_tfls`, sin escalera de responsables. El estado del encabezado **es** el
flujo.

---

## 7. Lo que esto simplifica respecto de lo anterior

- No hay que registrar un `cod_flusol` nuevo ni sus etapas en `datos_base`.
- No hay que definir perfiles por etapa ni cuál es terminal.
- Desaparece la pregunta de *"¿un envío vivo o varios?"*: sin tabla de asignación no hay
  ambigüedad. El estado de cada encabezado es independiente, así que **dos cuotas pueden estar
  en trámite a la vez** sin problema.

Esa última consecuencia es la más útil: la restricción que iba a recomendar por culpa de
`sg_apso` deja de ser necesaria.

---

## 8. El rol de DGDP ya está resuelto: `sg_uspe`

La duda de fondo era: *si nadie asigna la solicitud, ¿cómo sé que quien entra es DGDP?*

Eso no es asignación, es **autorización**, y el sistema ya la tiene resuelta en una tabla
independiente del workflow:

```
sg_uspe (rut, id_perfil)   PK (rut, id_perfil)   FK -> sg_perf
```

Una persona tiene uno o más perfiles. El encargado de DGDP es un `rut` con el perfil de DGDP.
El backend ya lo consulta en
[user-permissions.ts](../../../sg-solicitudes-backend/src/db-assets/mysql-assets/queries/permissions/user-permissions.ts),
que es el mismo mecanismo que gobierna todos los módulos.

### Son dos preguntas distintas, y ninguna necesita `sg_apso`

| Pregunta | Se responde con |
| :--- | :--- |
| ¿Puedo entrar a la bandeja de pagos? | `sg_uspe` — tengo el perfil de DGDP |
| ¿Qué hay en la bandeja? | `sg_epag` en estado 6 |
| ¿Puedo resolver **esta** solicitud? | las dos anteriores: tengo el perfil y está en estado 6 o 2 |

`sg_apso` sirve para *"a esta solicitud específica le toca esta persona específica"*. El flujo de
pago no lo necesita porque **le toca a cualquiera con el perfil**.

### Lo que hay que agregar es dato, no esquema

| Tabla | Qué |
| :--- | :--- |
| `sg_perf` | el perfil de DGDP-pagos, **o** reutilizar el de DGDP que ya existe en resolución |
| `sg_uspe` | las personas designadas a ese perfil |
| permisos del módulo | acceso a las pantallas de pago para ese perfil |

Sigue el patrón de
`certificacion_03_09_2026/datos_base/01_roles_permisos_du288.sql`.

### Subrogancia

Q-E08: *"la subrogancia aquí aplica como ya se calcula para cada rol asociado."* Con este diseño
se resuelve sola: el subrogante **también tiene el perfil en `sg_uspe`**, así que ve la misma
bandeja. No hace falta una escalera de reemplazo como en resolución, porque no hay una persona
designada a la que reemplazar.

---

## 9. Lo que queda por confirmar

1. **`observacio varchar(255)`** — ¿alcanza, o el comentario de DGDP necesita `text` como en
   `sg_apso.comentario`?
2. **¿Se registra quién tomó la solicitud** al pasar a estado 2, o sólo quién la resolvió?
   Escribir `rut_valida` al tomarla permite mostrar *"en revisión por X"* en la bandeja.
3. **¿Puede otro DGDP retomar** una solicitud que alguien ya tomó, o queda bloqueada para ese
   usuario?
4. **¿Perfil nuevo o el de DGDP que ya existe?** Si el mismo encargado que valida resoluciones
   valida pagos, se reutiliza. Si son personas distintas, conviene un perfil propio.
