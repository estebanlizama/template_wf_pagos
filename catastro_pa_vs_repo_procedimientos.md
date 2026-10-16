# Catastro — lo que el sistema invoca frente al repo de procedimientos

**Fecha:** 15-10-2026
**Método:** se extrajeron los PA que el backend ejecuta en `db-assets` para
`auth`, `service-provision-request`, `service-provision-payment`, `request` y
`cost-center`, y se cruzaron contra `sissolic-procedimientos/` y contra los
paquetes de cambio de `nuevo_workflow_fase_2/`.
**No se ejecutó SQL contra ninguna base.** Esto compara archivos, no lo instalado.

---

## 0. Sobre la release 1.3.2

No hay metadatos de versión en el repositorio: `1.3.2` solo aparece dentro de
`package-lock.json`, que es ruido de dependencias. No existe changelog, tag ni
manifiesto que diga qué PA entran en esa release.

Así que lo que sigue **no** es «lo que falta para 1.3.2», sino **lo que el
sistema invoca hoy y no está en el repo de procedimientos**, que es la pregunta
verificable con lo que hay.

---

## 1. El caso que disparó la revisión

`sg_usacsSecgen01` **sí está** en `sissolic-procedimientos/`. El repo no lo
perdió: lo que falta es **desplegarlo** en certificación.

Pero desplegar la copia del repo tampoco sirve:

| Copia | Líneas | Trae el rol revisor DGDP |
| :--- | ---: | :--- |
| `sissolic-procedimientos/` | 137 | no |
| `certificacion_03_09_2026/entrega/` | 136 | no |
| `template_wf_pagos/cambios_pa/sg_usacs/` | **168** | **sí** |

Son **40 líneas de diferencia real** entre la del repo y la nuestra. La de 168
agrega `es_revisor_pago`, resuelto por `sp_orde.cod_organi = 696` con contrato
vigente. Con cualquiera de las otras dos el login funciona y **la bandeja de
visación DGDP queda vacía, sin error visible**.

---

## 2. Los números

| | Cantidad |
| :--- | ---: |
| PA que el sistema invoca en el alcance revisado | 100 |
| PA en `sissolic-procedimientos/` | 86 |
| PA en nuestros paquetes de cambio | 145 |
| **Invocados que no están en el repo** | **45** |

Los 45 se parten en dos grupos muy distintos.

---

## 3. Grupo A — los entregamos y no están en el repo (32)

Viven solo en `nuevo_workflow_fase_2/`. Si el repo de procedimientos es la
fuente de despliegue, **estos no se despliegan nunca**.

Es prácticamente **todo el paquete de pagos**:

| Familia | PA |
| :--- | :--- |
| `sg_epag` | `dSecgen01` · `iSecgen01` · `sSecgen01` · `sSecgen02` · `sSecgen03` · `sSecgen04` · `uSecgen01` · `uSecgen02` · `uSecgen03` |
| `sg_fuc2` | `dSecgen01` · `iSecgen01` · `sSecgen01` · `sSecgen02` |
| `sg_fum2` | `sSecgen01` · `sSecgen02` |
| `sg_fume` | `sSecgen01` · `sSecgen02` · `uSecgen02` · `uSecgen03` |
| catálogos | `sg_efumsSecgen01` · `sg_efumsSecgen02` · `sg_ecuosSecgen01` · `sg_ecuosSecgen02` |
| otros | `sg_fupssSecgen01` · `sg_fupssSecgen18` · `sg_cctosSecgen06` · `sg_histsSecgen01` · `sg_prsesSecgen06` · `sg_prsesSecgen07` · `sg_prsesSecgen10` · `sp_as01sSecgen01` · `valida_saldo_cc_cs` |

---

## 4. Grupo B — ni en el repo ni en nuestros paquetes (13)

Legado que se asume ya instalado. **Si faltan en certificación no tenemos cómo
crearlos**, porque no hay fuente en ninguna parte del repositorio:

`bd_pri2sSecgen04` · `es_tfdosSecgen01` · `es_tfinsSecgen01` ·
`sf_deafsSecgen01` · `sg_ansosSecgen01` · `sg_apccuSecgen02` ·
`sg_cctosSecgen03` · `sg_mocisSecgen01` · `sg_mocisSecgen02` ·
`sg_solisSecgen04` · `sg_solisSecgen12` · `sg_soliuSecgen06` ·
`sp_perssSecgen01`

`sp_perssSecgen01` es el del login, y en el log de certificación **respondió
bien**, así que al menos ese está. Conviene confirmar los otros doce antes de
descubrirlos de a uno por un 500.

---

## 5. Los 86 que sí están en el repo están todos desactualizados

Ninguna de las 86 copias del repo coincide con nuestra última versión. La
mayoría difiere en una o dos líneas de encabezado, pero estos no:

| Diferencias reales | PA |
| ---: | :--- |
| 42 | `sg_fumeuSecgen01` |
| 40 | `sg_usacsSecgen01` |
| 36 | `sg_fupsuSecgen01` |
| 34 | `sg_fupsiSecgen01` |
| 25 | `sg_fupssSecgen17` |
| 24 | `sg_etasSecgen01` |
| 17 | `sg_cctosSecgen05` |
| 16 | `sg_fupssSecgen15` · `sg_apresSecgen01` |
| 15 | `sp_orcosSecgen01` |
| 14 | `sg_prseuSecgen01` · `sg_fupssSecgen14` · `sg_fupssSecgen12` · `sg_eta1sSecgen03` · `sg_apresSecgen02` |

«Diferencias reales» = líneas distintas ignorando comentarios, líneas vacías y
mayúsculas, así que el encabezado `Actualizacion:` no cuenta.

`sg_fumeuSecgen01` encabeza la lista y es el que escribe los meses de ejecución
del flujo de resolución: 42 líneas de diferencia no es un retoque.

---

## 6. Qué hacer con esto

1. **Verificar qué hay instalado**, en vez de ir descubriendo por error 500:

   ```sql
   select name from sysobjects where type = 'P'
    and (name like 'sg[_]%Secgen%' or name like 'sp[_]%Secgen%'
         or name like 'es[_]%Secgen%' or name = 'valida_saldo_cc_cs')
    order by name
   ```

   Esa lista cruzada contra las de §3 y §4 dice exactamente qué falta crear.

2. **Decidir qué es el repo de procedimientos.** Si es la fuente de despliegue,
   le faltan 32 PA y los 86 que tiene están atrasados. Si es un respaldo
   histórico, hace falta decir cuál es la fuente real, porque hoy la respuesta a
   «¿de dónde se despliega?» cambia según a quién se le pregunte.

3. **Para certificación ahora**, desplegar `sg_usacsSecgen01` desde
   `template_wf_pagos/cambios_pa/sg_usacs/`, no desde el repo ni desde la
   entrega de septiembre.
