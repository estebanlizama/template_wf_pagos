# Impacto 25 — Simplificación de Filtros y UX en Bandeja de Finanzas

**Fecha de contraste con código:** 30-10-2026. Reemplaza la descripción visual anterior.
**Módulo:** Pagos DU288 / Frontend — Cuotas para Finanzas  
**Archivos impactados:**
- **Frontend:**
  - `pages/services-provision/payments/finance/index.vue`
  - `utils/servicesProvisionDgdpReviewFilter.js`
  - `schemes/tables/services-provision-dgdp-installments-table-scheme.js`
  - `lang/es/pds.js`
  - `utils/__tests__/servicesProvisionDgdpReviewFilter.test.cjs`

---

## 1. Contexto y Motivo del Cambio

En la versión inicial de la bandeja de Finanzas existía una tarjeta superior titulada **«Mes de remuneración en proceso»** (`processMonth`). Dicho control no filtraba la tabla de cuotas, sino que servía únicamente para contrastar la fecha de pago y calcular una columna llamada *«Oportunidad del pago»* (chips de atraso vs del período).

Esto causaba confusión operativa entre los usuarios de Finanzas y DGDP, ya que:
1. El usuario seleccionaba un mes arriba esperando ver solo las cuotas de ese mes, pero la tabla seguía mostrando todo el rango definido en los filtros inferiores.
2. Existían filtros de fecha de envío (`Enviada desde` y `Enviada hasta`) que no correspondían a ninguna columna visible en la tabla.
3. No existía un filtro para buscar por la **Actividad** de la resolución, que sí es una columna destacada en la tabla.

---

## 2. Decisiones de Diseño y Cambios Aplicados

### 2.1 Eliminación del Bloque «Mes de Remuneración en Proceso»
- Se removió por completo la sección superior `<section class="pds-ui-section">` con `processMonth`.
- La página actual conserva la columna y el filtro de oportunidad: atrasada / del período / todas. Se calculan con `paymentArrears.js` contra `processPeriod`, derivado de «Pago hasta», sin una segunda entrada de mes de proceso.
- El rango inicial tiene «Pago desde» vacío y «Pago hasta» en el mes actual, para incluir pendientes de períodos anteriores. No equivale a mostrar solo el mes actual.

### 2.2 Alineación Estricta Filtros ↔ Columnas de Tabla
Los filtros de la bandeja se acotaron para reflejar **estrictamente** las columnas visibles de la tabla de cuotas:

| Filtro en Interfaz | Columna Visible en la Tabla | Tipo de Búsqueda |
| :--- | :--- | :--- |
| **Pago desde** / **Pago hasta** | Fechas de pago | Rango de período mensual (`AAAA-MM`) |
| **Oportunidad** | Oportunidad del pago | Todas / atrasadas / del período |
| **Estado** | (Control de bandeja) | `Por enviar a Finanzas` (4) / `Ya enviadas a Finanzas` (8) |
| **Resolución** | Resolución | Búsqueda por N° o texto de resolución |
| **Funcionario** | Funcionario (Nombre) | Texto libre (insensible a tildes/mayúsculas) |
| **RUT** | Funcionario (RUT) | Búsqueda con o sin puntos y guion |
| **Centro de costo** | Centro de costo | Código o nombre del CC |
| **Solicitud** | Cuota | Número de solicitud de origen |
| **N° de cuota** | Cuota | Número ordinal de cuota |
| **Actividad** | Sin columna actual | Retirada de esta vista; no afirmar que es un filtro vigente |

**Filtros retirados:** fechas de envío y actividad. Las columnas de la tabla se construyen con las 13 del Excel, más selección, cuota, oportunidad y acceso al detalle. No se usa aquí el esquema genérico para ocultar oportunidad.

---

## 3. Grilla Responsiva DU288 (12 Columnas)

El formulario de filtros se reorganizó en una rejilla compacta de 12 columnas:

```
Fila 1 (12 cols): [Estado] [Oportunidad] [Pago desde] [Pago hasta]
Fila 2 (12 cols): [Funcionario: 4] [RUT: 4] [Centro de costo: 4]
Fila 3 (12 cols): [Resolución] [Solicitud] [N° de cuota]
```

### 3.1 Preservación de Estado en Navegación
`detailRoute` conserva estado, rango de pago, solicitud, cuota, funcionario, RUT, CC y resolución junto con `origen: 'finanzas'`. El filtro de oportunidad no está incluido en esa URL: no dar por verificada su restauración completa.

## 4. Selección y descarga

La cabecera permite seleccionar o desmarcar los resultados filtrados, y cada fila mantiene una casilla propia. El límite visual de descarga es 300 cuotas. Se genera una fila por cuota desde SG con `projectFinanceExcelRows`, sin exigir previamente una asignación SISPER. El aviso de mismo mes de pago se calcula sobre la selección; actualmente no deshabilita la descarga por ese motivo.

La descarga y el estado 8 no equivalen a pago efectivo. El detalle compartido permite devolver una aprobada a DGDP; la página de Finanzas actual no contiene un botón de ingreso directo a SISPER.
