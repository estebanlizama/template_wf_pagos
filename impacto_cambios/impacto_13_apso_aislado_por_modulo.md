# Usar `sg_apso` para pagos sin contaminar resolución

Pregunta: agregado el rol de DGDP a `sg_perf`, ¿se puede trabajar con `sg_apso` sin modificar el
flujo de resolución ni confundir los roles?

**Sí. El sistema ya trae dos mecanismos de aislamiento, y los PA existentes los usan.**

---

## 1. Los dos ejes de aislamiento que ya existen

| Eje | Dónde vive | Qué separa |
| :--- | :--- | :--- |
| `cod_flusol` | `sg_apso` · `sg_eta1` · `sg_prse` | el **flujo**: resolución vs pago |
| `cod_modulo` + `cod_sistem` | `sg_eta1` · `sistema_db..bd_pri2` · `bd_per1` | el **módulo**: qué roles pertenecen a qué pantalla |

`sg_eta1` los lleva **los dos**:

```sql
CREATE TABLE sg_eta1 (
    cod_flusol tinyint NOT NULL,
    cod_etapa  tinyint NOT NULL,
    des_etapa  varchar(100) NOT NULL,
    cod_sistem char(2) NOT NULL,      -- <- aislamiento por sistema
    cod_modulo varchar(8) NOT NULL,   -- <- aislamiento por módulo
    cod_perfil smallint NOT NULL,     -- <- el rol que resuelve la etapa
    ...
)
```

No hay que inventar nada: el motor fue diseñado para convivir con varios flujos y módulos.

---

## 2. Cómo se comporta cada PA de `sg_apso` hoy

### ✅ `sg_apsosSecgen03` — historial de aprobación · **ya aislado**

```sql
inner join sg_prse prse
    on prse.cod_flusol = apso.cod_flusol
   and prse.cod_etapa  = apso.cod_etapa
where apso.cod_estapr = @cod_estapr
  and apso.nro_solici = @nro_solici
```

El join exige que el `cod_flusol` de la fila coincida con el que `sg_prse` tiene guardado —
que es el de la **resolución**. Las filas del flujo de pago no calzan y **quedan fuera solas**.

### ✅ `sg_apsosSecgen05` — tareas pendientes · **ya aislado**

Mismo join a `sg_prse` por `cod_flusol` + `cod_etapa`. Mismo efecto.

### ✅ `sg_apsosSecgen02` — aprobadores · **se aísla por módulo**

```sql
inner join sistema_db..bd_pri2 pri2 on pri2.rut = apso.rut_usua
inner join sistema_db..bd_per1 per1 on per1.cod_perfil = pri2.cod_perfil
                                   and per1.cod_sistem = 'SG'
                                   and per1.cod_modulo = 'SISSOLIC'
where soli.nro_solici = @nro_solici
```

No filtra `cod_flusol`, **pero** el `inner join` exige que el aprobador tenga perfil en el módulo
`SISSOLIC`. Si el rol de DGDP-pagos se registra con un **`cod_modulo` propio**, esas filas no
calzan y quedan fuera.

> Si en cambio el rol se registra bajo `SISSOLIC`, **sí se mezclan**. Ahí está la confusión de
> roles que hay que evitar.

### ⚠️ `sg_apsosSecgen01` — comentarios · **el único que se mezcla**

```sql
left join sistema_db..bd_pri2 ...
where apso.nro_solici = @nro_solici
  and apso.comentario like '%'
```

Filtra sólo por `nro_solici`, y el join al perfil es `left`. Los comentarios del pago
**aparecerían** en el historial de comentarios de la resolución, con el perfil en blanco.

---

## 3. El resumen

| PA | ¿Se contamina? | Por qué |
| :--- | :---: | :--- |
| `sg_apsosSecgen03` | No | join a `sg_prse.cod_flusol` |
| `sg_apsosSecgen05` | No | join a `sg_prse.cod_flusol` |
| `sg_apsosSecgen02` | No, **si el rol tiene módulo propio** | `inner join` a `bd_per1` por `cod_modulo` |
| `sg_apsosSecgen01` | **Sí** | filtra sólo por `nro_solici` |

**Tres de cuatro se aíslan solos.** El único que hay que tocar es uno, y con una línea:

```sql
-- sg_apsosSecgen01, agregar al where
and apso.cod_flusol = (select cod_flusol from sg_prse where nro_solici = @nro_solici)
```

O, más explícito y sin subconsulta, un parámetro opcional `@cod_flusol` que por defecto tome el
de la resolución.

---

## 4. Qué hay que registrar, y dónde

| Tabla | Qué | ¿DDL? |
| :--- | :--- | :---: |
| `sistema_db..bd_per1` | el perfil **DGDP-pagos**, con `cod_sistem = 'SG'` y un `cod_modulo` propio | No |
| `sistema_db..bd_pri2` | las personas designadas a ese perfil | No |
| `sg_perf` / `sg_uspe` | el mismo perfil en el lado SecGen, para permisos de pantalla | No |
| `sg_tfls` | el flujo de pago (`cod_flusol` nuevo) | No |
| `sg_eta1` | su etapa de validación DGDP, con el `cod_modulo` y `cod_perfil` propios | No |

Todo es **dato**. El único cambio de código es la línea de `sg_apsosSecgen01`.

> **El `cod_modulo` propio es la pieza clave.** Es lo que hace que un DGDP de pagos no aparezca
> como aprobador de resoluciones ni al revés, sin tocar ninguna consulta.

---

## 5. Las tres opciones, ahora con costo real

| | Aislamiento | Costo |
| :--- | :--- | :--- |
| **A · `sg_apso` con flujo y módulo propios** | 3 de 4 PA solos + 1 línea | 1 línea en un PA de resolución · datos de flujo, etapa y perfil |
| **B · `sg_apso` con `nro_solici` propio** | total | crea una `sg_soli` de pago — contradice *"no se genera una solicitud nueva"* |
| **C · 3 columnas en `sg_epag`** | total | 3 columnas de DDL · sin motor de etapas |

### Recomendación

**A**, y cambio mi recomendación anterior. Dos razones concretas que no tenía antes:

1. El aislamiento **no había que construirlo**: `cod_flusol` y `cod_modulo` ya están en el modelo
   y los PA existentes ya los usan. Tres de cuatro consultas se separan sin tocarlas.
2. `sg_apso` da gratis lo que en la opción C hay que agregar a mano —`rut_usua`, `comentario`
   (`text`, no `varchar(255)`), `rut_autori` para subrogancia, `f_aprobac`, `f_creacion`,
   `f_ultmodif`— **y además** el historial completo de idas y vueltas, no sólo el último estado.

La opción C guarda el último revisor y el último comentario. `sg_apso` guarda **todas** las
revisiones, que es lo que una auditoría necesita cuando una cuota se devolvió tres veces.

---

## 6. Lo que sigue faltando con la opción A

`sg_apso` no tiene `nro_cuota`. Si dos cuotas de la misma prestación están en trámite a la vez,
habría dos filas abiertas sobre el mismo `id_funprse` sin forma de distinguirlas.

| Salida | Costo |
| :--- | :--- |
| Restringir a **un envío vivo** por prestación | sin DDL; coherente con que las cuotas de un envío transicionan juntas |
| Agregar `nro_cuota tinyint NULL` a `sg_apso` | una columna que sólo usa el flujo de pago |

Con la opción A la columna es barata y resuelve el caso general. Pero conviene confirmar primero
si el negocio realmente necesita envíos paralelos.

---

## 7. Por confirmar

1. **¿`cod_modulo` propio para pagos, o el mismo `SISSOLIC`?** Es lo que define si los roles se
   mezclan en `sg_apsosSecgen02`.
2. **¿El encargado de DGDP que valida pagos es el mismo que valida resoluciones?** Si es el
   mismo, un módulo propio igual sirve: la persona tendría los dos perfiles.
3. **¿Se agrega `nro_cuota` a `sg_apso`**, o se restringe a un envío vivo por prestación?
4. **Cuántas etapas** tiene el flujo de pago. Con Finanzas fuera, el mínimo es una.
