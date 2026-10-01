# Plan — vista de detalle y creación de cuota del jefe de proyecto

**Fecha:** 01-10-2026
**Ruta:** `/prestacion-de-servicios/pagos/:nroSolici`
**Permiso:** `provision-payment-manage` (derivado: responsable vigente de un CC DU288)
**Módulo:** `service-provision-payments`
**Alcance de esta etapa:** solo frontend, consumiendo lo que ya existe.

Se entra desde la bandeja «Prestaciones por pagar». La bandeja lista por funcionario; el enlace
lleva a la **resolución** y ancla en esa fila, porque el saldo y el tope que hay que validar son
del centro de costo y no de cada funcionario por separado.

---

## 1. Estructura de pestañas

```
SOLICITUD DE PAGO — Resolución Exenta N° 45 · ADMINISTRACION BUS (9010-36)

┌──────────────────────┬──────────────────────┐
│  Gestión de pago  ●  │  Antecedentes        │
└──────────────────────┴──────────────────────┘

  Pestaña 1 — Gestión de pago        editable
    · Funcionario y marco autorizado
    · Meses de ejecución
    · Compensación realizada
    · Cuotas: crear, editar, eliminar, enviar
    · Panel de validaciones

  Pestaña 2 — Antecedentes           solo lectura
    ┌─────────────────────┬────────────────────────────────┐
    │  Detalle resolución │  Documento archivo universitario│
    └─────────────────────┴────────────────────────────────┘
```

La pestaña 2 es **solo lectura por norma**, no por conveniencia: el modelo de datos declara que
este flujo no crea, actualiza ni elimina información de resolución. Mostrarla no autoriza a
modificarla, y la interfaz no debe ofrecer ningún control que lo sugiera.

---

## 2. Pestaña 1 — Gestión de pago

### 2.1 Bloques, en el orden obligatorio de §4 del estándar visual

| # | Bloque | Contenido |
| :-- | :--- | :--- |
| 1 | Encabezado de página | Título, resolución, centro de costo, actividad, período general |
| 2 | Estado | Badge de la cuota en curso, si existe |
| 3 | Validaciones normativas vigentes | Siempre visibles como tags, con la misma semántica de la resolución |
| 4 | Funcionario | Selector si hay más de uno + marco autorizado, solo lectura |
| 5 | Meses de ejecución | Tabla: mes, estado, monto, compensación, cuota |
| 6 | Compensación realizada | Aparece al elegir un mes; calendario y contraste |
| 7 | Cuotas | Lista de encabezados + formulario de la que se edita |
| 8 | Acciones | Guardar borrador · Enviar a visación |

### 2.2 Bloque 4 — Funcionario

Solo lectura. Sale del detalle de la solicitud.

```
JEANETTE DEL PILAR POZA ARAVENA · 87.962.717

Tipo de pago    Fija (meses)        Total autorizado   $141.111
Tope mensual    $155.254            Cuotas             1 de 1 autorizadas
Jornada         Dentro              Saldo              $141.111
Cargo           …                   Extensión          No
```

`Extensión` refleja `ext_cuotas`. Cuando es `S`, el contador de cuotas no muestra tope: el
numeral 6 no limita la cantidad.

### 2.3 Bloque 5 — Meses de ejecución

```
Mes          Estado        Monto      Compensación      Cuota
─────────────────────────────────────────────────────────────────
Sep 2026     Propuesta     $141.111   8 h de 8 h  ✓     —      [Editar]
Oct 2026     En ejecución  —          —                 —
```

- **Estado** viene de `sg_efum`: Propuesta · Comprometida · Enviada a pago · Rechazada.
- **En ejecución** no es un estado persistido: es `cod_estfum = 1` con la ejecución sin terminar.
  Se deriva en pantalla, nunca se guarda.
- **Compensación** solo aparece si `dentro_jor` es `S` o `D`.
- Solo las filas con el mes disponible ofrecen `Editar`.

### 2.4 Bloque 6 — Compensación realizada

```
Comprometido 8 h    Informado 8 h    Diferencia 0 h

┌── Comprometido en la resolución ──┐  ┌── Realizado ──────────────────┐
│  Lu 07/09   09:00 – 11:00   2 h   │  │  Lu 07/09   09:00 – 11:00  2h │
│  Mi 09/09   09:00 – 12:00   3 h   │  │  Mi 09/09   08:30 – 11:30  3h │
│  Vi 11/09   15:00 – 18:00   3 h   │  │  Ju 10/09   15:00 – 18:00  3h │
└───────────────────────────────────┘  └───────────────────────────────┘

[ Calendario del mes: clic en un día para agregar o quitar tramos ]
```

Dos columnas lado a lado y no una lista precargada: lo que se audita es la **diferencia**. Una
sola lista editable con los valores ya puestos invita a confirmar sin mirar, que es lo contrario
de para qué existe el registro.

El calendario reutiliza `StaffCompensationSection`, acotado a un mes en vez de navegar entre
varios. Ya trae totales, feriados institucionales y bloqueo de días tomados por otra PDS.

**Se puede guardar incompleto.** La diferencia no impide registrar; impide **enviar**.

### 2.5 Bloque 7 — Cuotas

```
Cuota 1   Propuesta   Sep 2026        $141.111   Pago: Oct 2026   [Editar] [Eliminar]
                                                                  [+ Nueva cuota]
```

Formulario de la cuota en edición:

| Campo | Regla |
| :--- | :--- |
| Meses que abarca | Solo los disponibles. Un mes en una sola cuota |
| Mes de pago | Define corriente vs atrasado: `mes_prop = mes_pago − 1` es corriente |
| Monto por mes | Editable **solo si `cod_tpps = 2`** (Variable). En Fija viene del reparto comprometido |
| Respaldo | Adjunto. Obligatorio al enviar, no al guardar |

Editable mientras `cod_estcuo` sea **1 Propuesta** o **3 Observada**. Desde *2 En visación* en
adelante, solo lectura.

---

## 3. Pestaña 2 — Antecedentes

### 3.1 Sub-pestaña «Detalle de la resolución»

Vista de la solicitud tal como quedó decretada: encabezado, funcionarios, períodos, montos,
distribución horaria comprometida y compensación comprometida. Reutiliza los componentes de
lectura que ya usa el detalle de resolución, sin ningún control editable.

### 3.2 Sub-pestaña «Documento — archivo universitario»

El PDF decretado, embebido. Se obtiene de
`/resolution/file/{resolutionYear}/{resolutionNumber}/{correlative}`, donde el correlativo **2** es
el documento cargado y firmado y el **1** el generado por el sistema.

Sin acciones: ni firmar, ni aprobar, ni archivar. Esas pertenecen al flujo de resolución y su
permiso.

---

## 4. Validaciones replicadas

El panel normativo se **vuelve a correr completo** en esta vista. No se confía en que la
resolución ya validó: entre el decreto y el pago pueden haber cambiado el contrato, el cargo, el
saldo o la vigencia del responsable. Se consulta al abrir el detalle y se vuelve a consultar antes
de enviar la cuota; no se reutiliza como resultado vigente el snapshot guardado por resolución.

### 4.1 Qué se revalida y con qué endpoint existente

| Control | Endpoint |
| :--- | :--- |
| Perfil y contratos vigentes del funcionario | `/normative/staff-profile/{rutPerson}` |
| Inhabilidad consolidada del contrato/cargo | `POST /normative/disablement-staff` |
| Asignaciones inhabilitantes | `/normative/staff-assignments/{rutPerson}` |
| Parentesco | `/normative/check-relationship` |
| Tope por cargo | `/normative/staff-position-cap` |
| PDS previas del funcionario | `/staff-previous-provisions/{rutPerson}` |
| Saldo del centro de costo | `/cost-center-balance/{codUnifin}/{codCcto}` |
| Validación de saldo | `/normative/cost-center-balance-validation` |
| Calendario institucional | `/normative/institutional-calendar` |

**Ninguno es nuevo.** El endpoint `/normative/calculated-cap/{rutPerson}` no se consulta aparte:
en el backend actual es un alias temporal de `staff-profile` y repetirlo duplicaría la misma
lectura. Para el jefe de proyecto se usa `/staff-previous-provisions/{rutPerson}`; la variante
`/normative/staff-previous-provisions/{rutPerson}` exige rol DGDP.

### 4.2 Dónde se muestran

En el bloque 3, siempre visibles y con el patrón de tags `.pds-check` que utiliza el resumen de
funcionarios de la resolución. No se usa un aviso agregado ni `Du288ValidationSummary` para los
resultados normativos normales; ese componente queda reservado para errores de formulario al
intentar guardar o enviar.

Tags mínimos por funcionario:

- Contrato vigente.
- Cargo habilitado.
- Asignaciones habilitadas.
- Sin parentesco / Parentesco.
- Tope validado / pendiente / excedido.
- Jornada dentro del máximo semanal, considerando PDS previas.
- Saldo disponible / insuficiente.
- Calendario institucional consultado / no disponible.

Cada tag conserva los estados y colores de resolución: verde confirma, amarillo advierte, rojo
bloquea y gris indica pendiente o fuente no disponible. El texto y el icono siempre acompañan al
color. Si una validación falla, cambia **ese tag** y su tooltip explica la causa; no aparece un
banner global sustituyendo los resultados individuales. Un error o una validación pendiente que
sea obligatoria deshabilita «Enviar a visación», pero no «Guardar borrador».

### 4.3 Lo que esta vista valida y resolución no

| Control | Momento |
| :--- | :--- |
| El mes está disponible: propuesto y con la ejecución terminada | al armar la cuota |
| El mes no está en otra cuota | al armar la cuota |
| Máximo 2 cuotas al año, salvo `ext_cuotas` | al crear la cuota |
| La compensación informada cubre la comprometida | **solo al enviar** |
| La última cuota solo con la ejecución terminada | al enviar |
| Respaldo adjunto | al enviar |

La compuerta de envío completa, con los IDs del catálogo, está en
[`vista_detalle_pago.md` §7](vista_detalle_pago.md).

---

## 5. Qué se puede construir hoy

### 5.1 Disponible — se consume sin tocar la base

| Dato | Endpoint | Pestaña |
| :--- | :--- | :--- |
| Cabecera de la solicitud | `/requests/service-provision/{id}` | 1 y 2.1 |
| Detalle completo | `/requests/service-provision/{id}/detail-information` | 2.1 |
| Funcionarios y marco | `/requests/service-provision/{id}/staff` | 1 |
| Horario comprometido (FUHO) | `/requests/service-provision/{id}/staff-schedules` | 2.1 |
| **Compensación comprometida** | `/payments/{requestId}/committed-compensations` | 1 |
| **Compensación realizada** | `/payments/{requestId}/executed-compensations` | 1 |
| Registrar un tramo | `POST /payments/provisions/{id}/months/{seq}/compensations` | 1 |
| Eliminar tramos | `DELETE` del mismo recurso | 1 |
| Resumen de avance por funcionario | `/payments/payable-provisions` | 1 |
| Detalle de la resolución | `/requests/service-provision/resolution-details/{id}` | 2.1 |
| Documento decretado | `/resolution/file/{year}/{res}/{corr}` | 2.2 |
| Las nueve validaciones de §4.1 | `/normative/*` | 1 |

### 5.2 No disponible todavía

| Falta | Por qué | Bloquea |
| :--- | :--- | :--- |
| Lista de **meses con estado** | `sg_fumesSecgen01` existe pero lee `nro_cuota` y `cod_estcuo`, columnas que la migración renombró. Está roto y nadie lo llama | Bloque 5 |
| Lista de **cuotas** | `sg_epagsSecgen01` no existe | Bloque 7 |
| Crear, editar, eliminar y enviar cuota | Los PA de `sg_epag` no existen | Bloques 7 y 8 |
| Índice único de `sg_dpag` | No desplegado | Envío seguro |

El resumen de la bandeja da **conteos agregados** por funcionario — meses propuestos,
comprometidos, enviados, disponibles — pero no el detalle mes a mes.

---

## 6. Plan por etapas

### Etapa 1 — Esqueleto y antecedentes · *construible hoy*

1. Página con la ruta y las dos pestañas; `meta.module` y `meta.guardian.privilege`
2. Store `service-provision-payment-detail`: cabecera, funcionarios, validaciones
3. Pestaña 2 completa: detalle de resolución y documento embebido
4. Pestaña 1, bloques 1, 2 y 4: encabezado, estado y marco del funcionario
5. Bloque 3: panel de validaciones con los nueve endpoints

Al final de la etapa el jefe de proyecto ya **entra y consulta**, aunque todavía no gestione.

### Etapa 2 — Compensación realizada · *construible hoy*

6. Bloque 6 con `StaffCompensationSection` acotado a un mes
7. Contraste comprometido / informado / diferencia
8. Alta y baja de tramos contra los endpoints nuevos
9. La diferencia se muestra, no bloquea

Depende de desplegar los tres PA de `sg_fuc2`, que ya están escritos.

### Etapa 3 — Meses y cuotas · *bloqueada*

10. Reparar o reemplazar `sg_fumesSecgen01` → bloque 5
11. PA de `sg_epag` y `sg_dpag` + índice único → bloques 7 y 8
12. Compuerta de envío con la revalidación completa

### Etapa 4 — Cierre

13. Responsive en 1366, 1024, 768 y 375
14. `npm run lint:du288-ui` y sumar la página a `validateDu288Ui.js`
15. Textos al catálogo `lang/es/pds.js`

---

## 7. Decisiones abiertas que afectan la pantalla

| # | Decisión | Qué cambia |
| :-- | :--- | :--- |
| 1 | ¿Compensar **de más** también bloquea? | Si no, el mensaje y el botón solo reaccionan a `informado < comprometido` |
| 2 | ¿El bloqueo es por mes o por cuota? | Si es por mes, el usuario puede sacar el mes incompleto y enviar el resto |
| 3 | ¿El tramo puede caer fuera del mes de su `corr_fume`? | Hoy el PA lo permite; si se restringe, el calendario debe deshabilitar esos días |
| 4 | PAG-18: ¿se recomprometen los tramos faltantes? | Necesita una columna en `sg_fuc2` que distinga realizado de recomprometido |
| 5 | ¿`cuotas` se renombra a `meses` en la API? | Afecta modelo, esquema de tabla y textos |

Ninguna bloquea las etapas 1 y 2.
