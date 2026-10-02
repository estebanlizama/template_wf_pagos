# PA que el flujo de pagos reutiliza sin modificar

**Fecha:** 02-10-2026

Todos estos ya existen, están desplegados y los invoca el flujo de resolución. **Pagos los usa tal
cual**: no se tocan, no se copian y no se les agrega un parámetro. Si alguno necesitara cambiar,
deja de ser reutilización y pasa a ser una modificación con impacto en resolución.

---

## 1. Panel normativo — se revalida completo antes del envío

El envío repite las validaciones con datos frescos porque entre el decreto y el pago pueden haber
cambiado el contrato, el cargo, el saldo o la vigencia del responsable.

| PA | Qué entrega | Endpoint que ya lo expone |
| :--- | :--- | :--- |
| `sg_fupssSecgen12` | Perfil institucional del funcionario | `/normative/staff-profile/{rut}` |
| `sg_fupssSecgen13` | Tope calculado y haberes | `/normative/calculated-cap/{rut}` |
| `sg_fupssSecgen14` | Validación de contrato, con `@ext_cuotas` | `/normative/staff-profile` · interno |
| `sg_fupssSecgen15` | Asignaciones inhabilitantes | `/normative/staff-assignments/{rut}` |
| `sg_fupssSecgen16` | Tope por cargo | `/normative/staff-position-cap` |
| `sg_fupssSecgen17` | Prestaciones previas del funcionario | `/normative/staff-previous-provisions/{rut}` |
| `sg_cctosSecgen06` | Saldo del centro de costo | `/cost-center-balance/{unifin}/{ccto}` |
| `es_cfersSecgen01` | Calendario institucional y feriados | `/normative/institutional-calendar` |

**Ninguno necesita cambio.** El servicio que orquesta el envío los llama en el mismo orden que el
formulario de resolución y aborta si alguno bloquea.

---

## 2. Antecedentes que la pantalla muestra

| PA | Qué entrega | Dónde se usa en pagos |
| :--- | :--- | :--- |
| `sg_cctosSecgen05` | Centros de costo del responsable vigente | Define quién es jefe de proyecto; ya lo usa la bandeja |
| `sg_fucosSecgen01` | **Compensación comprometida** en la resolución | Contraste de la realizada; ya está cableado |
| `sg_fuhosSecgen01` | Horario semanal comprometido | Pestaña de antecedentes |
| `sg_prsesSecgen01` | Cabecera de la solicitud | Encabezado del detalle |
| `sg_fupssSecgen01` | Funcionarios de la solicitud | Detalle por funcionario |
| `sg_fupssSecgen02` | Snapshot de la prestación | Marco autorizado |
| `sg_histsSecgen01` | Historial de la solicitud | Pestaña de antecedentes |

`sg_fucosSecgen01` merece una nota: lista por `@nro_solici` y **no filtra por mes**, porque
`sg_fuco` no tiene esa dimensión. El filtro por mes lo aplica quien consume. Eso es correcto y no
hay que cambiarlo.

---

## 3. Documento decretado

| Ruta | Qué entrega |
| :--- | :--- |
| `/resolution/file/{ano}/{nroResolu}/{correlativo}` | El PDF. Correlativo **2** es el cargado y firmado, **1** el generado por el sistema |

Solo lectura. El flujo de pagos no crea, actualiza ni elimina información de resolución.

---

## 4. Lo que NO se reutiliza y hay que escribir

| Tabla | Por qué |
| :--- | :--- |
| `sg_epag` · `sg_dpag` | No existían. 6 PA propios |
| `sg_ecuo` | El catálogo existía; su CRUD no. 4 PA |
| `sg_fuc2` | La tabla existía vacía; sin PA, sin modelo, sin pantalla. 3 PA |
| `sg_fume` | Existe y se usa, pero sus PA de lectura y de monto quedaron desfasados. Ver `sg_fume/README.md` |

---

## 5. Un caso límite: `sg_fumesSecgen01`

Está **en la base y roto**: lee `nro_cuota` y `cod_estcuo`, columnas que la migración renombró a
`corr_fume` y `cod_estfum`.

No es reutilizable en su forma actual, pero tampoco se puede ignorar: el nombre está tomado y el
backend lo declara como `selectStaffMonths` en su mapa de consultas, aunque ninguna línea lo
invoque. Corresponde **migrarlo**, no crear otro con nombre distinto.
