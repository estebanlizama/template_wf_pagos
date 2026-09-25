# PA de `sg_efum` — catálogo de estados del mes de ejecución

| PA | Operación | Backend |
| :--- | :--- | :--- |
| `sg_efumsSecgen01` | listar todos | `GET /requests/service-provision/month-statuses` |
| `sg_efumsSecgen02` | obtener por código | `GET .../month-statuses/{codEstfum}` |
| `sg_efumiSecgen01` | insertar | `POST .../month-statuses` |
| `sg_efumuSecgen01` | actualizar descripción | `PATCH .../month-statuses/{codEstfum}` |

Nomenclatura `<tabla><operación>Secgen<NN>`, igual que `sg_fucosSecgen01`, `sg_apreiSecgen01`,
`sg_soliuSecgen01`.

No hay `d` (delete): borrar una fila del catálogo rompería las FK de `sg_fume` y `sg_fum2`. Si un
estado deja de usarse se retira del diseño, no de la tabla.

---

## Contenido del catálogo

| cod | des_estfum | Lo escribe |
| :---: | :--- | :--- |
| 1 | Propuesta | resolución · y pagos al liberar por rechazo de cuota |
| 2 | Comprometida | pagos |
| 3 | Enviada a pago | pagos |
| 4 | Rechazada | pagos |

Carga inicial en `../../datos_base/02_sg_efum.sql`.

---

## Por qué catálogo propio y no `sg_ecuo`

`sg_ecuo` describe el ciclo de la **cuota de pago** (`sg_epag`): borrador, visación, observada,
aprobada, enviada, rechazada. `sg_efum` describe el ciclo del **mes** (`sg_fume`): propuesto,
comprometido, enviado, rechazado.

Son granos distintos y ciclos distintos. Mientras DGDP visa u observa la cuota, el mes no se
mueve — sigue comprometido. Compartir catálogo obligaría a que `sg_fume` aceptara estados que no
significan nada a nivel de mes.

> Los códigos **no coinciden** entre los dos catálogos. Un reporte que muestre encabezado y mes
> juntos necesita traducir.

---

## Estados que NO existen aquí, y por qué

| Concepto | Cómo se obtiene |
| :--- | :--- |
| **Validada** | `fec_valida` + los `val_*`. No es estado: las validaciones son dinámicas y se recalculan en cada transición — persistirlas sería cachear un resultado que caduca |
| **Disponible pago** | `cod_estfum = 1` y la ejecución ya pasó. Depende de la fecha actual, así que no se persiste |
| **Ejecutado** | columnas `ano_ejec` / `mes_ejec` |
| **En visación / Observada / Aprobada** | son trámite de la cuota, se leen de `sg_epag` |

---

## Regla de escritura

- Los valores **2, 3** y el retorno a **1** los escribe únicamente el PA que mueve el encabezado
  de pago.
- El valor **4** lo escribe el PA de validación de DGDP, mes a mes.
- **La aplicación nunca escribe `cod_estfum` directamente**, ni siquiera vía estos PA de
  catálogo: estos administran el catálogo, no el estado de una fila de `sg_fume`.

Es lo que impide que el mes se desincronice de su cuota.
