# Impacto 29 — Resumen por cuota en revisión DGDP y Finanzas

**Corte:** 30-10-2026. Implementado en el código local; sin confirmar despliegue ni revisión visual en este corte.

## Pantallas y alcance

La página `sg-solicitudes-frontend/pages/services-provision/payments/review/_staffProvisionId/_installmentNumber.vue` se abre desde la bandeja DGDP y desde Finanzas. Ambas entradas comparten el detalle y la nueva pestaña, sin duplicar la página.

Orden de pestañas: **Cuota → Resumen de cuotas → Documento de respaldo → Documento de resolución**.

El componente nuevo es `components/services-provision/payments/Du288PaymentProvisionSummaryTab.vue`. Consume la consulta existente `GET .../dgdp/provisions/{staffProvisionId}/installments/{installmentNumber}/provision-months`, conectada a `sg_fumesSecgen03`, y la lectura de los meses de la cuota actual. No agrega tablas, columnas ni escrituras.

## Qué ve el usuario

- Resumen general: total decretado, enviado a pago, en trámite, rechazado, saldo por gestionar, total de esta cuota cuando es atribuible, cuotas autorizadas y cantidad de meses únicos.
- Secciones por número de cuota; al final, meses sin cuota.
- Meses ordenados por año/mes dentro de cada cuota.
- Tarjeta de mes con estado, cuota, mes de pago, solicitado, descuentos y monto resultante.
- Cuando el mismo mes tiene varias relaciones, aparece en cada cuota e identifica las cuotas relacionadas.
- Aviso y reintento si falla la consulta de todos los meses. No se convierte el fallo en un resumen vacío como si no hubiera datos.

## Identidad y colores

La clave visual es **mes + cuota**, no solamente `corr_fume`. Al actualizar los datos de la cuota actual se reemplaza solo esa relación; se conservan las de otras cuotas. El contador general cuenta meses únicos para no duplicar ejecución.

| Caso | Presentación |
| --- | --- |
| Cuota rechazada, estado 10 | Rojo; monto excluido del pago |
| Cuota que se está revisando | Azul; etiqueta «Esta cuota» y su estado real |
| Otra cuota aprobada o enviada, estados 4/8 | Verde; distingue Aprobado de Enviado a pago |
| Otra cuota en trámite | Amarillo |
| Mes pendiente disponible | Neutro |
| Mes sin cuota y no habilitado por la fuente | Gris con candado y borde discontinuo |

La cuota actual mantiene su resaltado azul aunque esté aprobada; un rechazo de cuota tiene prioridad y se muestra rojo. El color no reemplaza el texto ni el ícono. «Enviado» no se etiqueta como pago efectivo.

## Meses compartidos y límites de importes

`sg_dpag` conserva la relación `(id_funprse, nro_cuota, corr_fume)`, pero no tiene monto asignado a esa relación. Los importes y descuentos vigentes pertenecen a `sg_fume`.

Por ello, si un mes aparece en varias cuotas:

1. Se conservan todas las relaciones para consulta.
2. Las tarjetas muestran el importe vigente completo del mes y una aclaración.
3. No se presenta una suma por cuota como si fuera un reparto respaldado por datos.
4. El total de la cuota actual se muestra sin información si la relación compartida impide atribuirlo con seguridad.
5. Los totales generales siguen viniendo de la prestación; no se suman las apariciones repetidas.

Este cambio no habilita pagar parcialmente un mismo mes desde varias cuotas, ni modifica las guardas de creación/envío. La regla vigente de escritura y la nueva necesidad de meses compartidos requieren una definición de importes por relación si se quiere habilitar ese pago, más allá de su consulta histórica.

## Criterios para certificación

- Misma pestaña desde revisión y desde aprobadas de Finanzas.
- Mes relacionado con cuota rechazada y cuota actual: ambas visibles, colores independientes.
- Varias cuotas y meses sin cuota: orden estable y sin relaciones descartadas.
- Montos editados de la cuota actual actualizan esa relación sin modificar otras en memoria.
- Contador de meses únicos; no sumar dos veces el mes compartido.
- Estados de carga/error/reintento y tarjetas legibles en móvil.
- Comprobar que el PA instalado devuelve todas las relaciones y que el estado coincide con el catálogo del ambiente.

## Trazabilidad

Impactos relacionados: 20 (edición DGDP), 22 (límites de atributos), 23 (estados) y 30 (matriz para ClickUp). La evidencia de esta actualización es lectura del componente, del modelo de meses y del PA fuente; no una ejecución nueva en ASE.
