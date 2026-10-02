# Plan de implementación — pantallas del jefe de proyecto

**Fecha:** 02-10-2026
**Alcance:** desde la bandeja hasta enviar una cuota a visación.
**Backend:** los 16 endpoints están implementados. Esto es solo frontend.

Ventana por ventana, con el endpoint que consume cada una y el componente que reutiliza.

---

## Mapa de ventanas

```
V1  Bandeja                    ✅ existe
      │ clic en una fila
      ▼
V2  Detalle de la resolución   ⬜ nueva
      ├── pestaña Gestión de pago
      │     ├── V3  Meses de ejecución        ⬜ bloque
      │     ├── V4  Compensación realizada    ⬜ modal
      │     └── V5  Cuotas                    ⬜ bloque
      │           └── V6  Formulario de cuota ⬜ modal
      └── pestaña Antecedentes
            ├── detalle de la resolución
            └── documento del archivo
```

---

## V1 · Bandeja — ya existe

Solo falta **hacer navegable la fila**. Hoy la tabla no tiene acción.

| | |
| :--- | :--- |
| Archivo | `pages/services-provision/payments/index.vue` |
| Cambio | columna de acción con `:to` a `/pagos/:nroSolici?funcionario=:idFunprse` |
| Datos | ya los trae: `requestId` y `staffProvisionId` |

El anclaje por `funcionario` importa: la bandeja lista por persona y el detalle es por resolución, así
que al entrar hay que seleccionar al funcionario del que se venía.

**Estimado:** media jornada.

---

## V2 · Detalle de la resolución — el contenedor

| | |
| :--- | :--- |
| Ruta | `/prestacion-de-servicios/pagos/:nroSolici` |
| `meta.module` | `service-provision-payments` |
| `meta.guardian.privilege` | `provision-payment-manage` |
| Archivo | `pages/services-provision/payments/_nroSolici/index.vue` |

### Qué carga al entrar

| Dato | Endpoint |
| :--- | :--- |
| Funcionarios y marco autorizado | `GET /requests/service-provision/{id}/staff` |
| Cabecera de la solicitud | `GET /requests/service-provision/{id}` |
| Meses de todos los funcionarios | `GET /payments/{requestId}/months` |
| Cuotas | `GET /payments/{requestId}/installments` |
| Catálogo de estados de cuota | `GET /payments/installment-statuses` |

Cinco llamadas en paralelo al montar. El catálogo se cachea en el store: no cambia.

### Estructura

Dos pestañas. La de antecedentes es **solo lectura por norma**, no por comodidad: el flujo de pagos
no escribe nada de resolución.

Orden obligatorio de §4 del estándar visual: encabezado → estado → resumen de validaciones →
secciones → acciones.

### Store nuevo

`store/service-provision-payment-detail.js` — separado del de la bandeja, que es una lista y este
es un agregado por resolución.

```
state     request · staff · months · installments · statuses · activeStaffId
getters   funcionario activo · sus meses · sus cuotas · meses disponibles
actions   fetchDetail · refreshMonths · refreshInstallments
```

**Estimado:** 2 jornadas.

---

## V3 · Bloque de meses de ejecución

```
Mes          Estado        Monto      Compensación      Cuota
──────────────────────────────────────────────────────────────────
Sep 2026     Propuesta     $141.111   8 h de 8 h  ✓     —      [Editar]
Oct 2026     En ejecución  —          —                 —
```

| | |
| :--- | :--- |
| Datos | `months` del store, filtrados por funcionario activo |
| Derivados que ya vienen del backend | `isAvailable` · `isProposed` · `isAssigned` · `period` |
| Acción | `PUT /payments/provisions/{id}/months/{seq}/amount` |

**No recalcular `isAvailable` en el frontend.** Lo deriva el PA con la fecha del servidor; hacerlo
de nuevo en el cliente abre la puerta a que difieran por zona horaria.

La columna **Monto** es editable solo si `amountType = 2` (Variable). En Fija muestra el reparto
comprometido.

**Estimado:** 1 jornada.

---

## V4 · Compensación realizada — modal

Se abre desde `[Editar]` de un mes. Solo si `dentro_jor` es `S` o `D`.

| | |
| :--- | :--- |
| Componente | **`StaffCompensationSection`**, acotado a un mes |
| Comprometido | `GET /payments/{requestId}/committed-compensations` |
| Realizado | `GET /payments/{requestId}/executed-compensations?staffProvisionId&monthSequence` |
| Agregar tramo | `POST /payments/provisions/{id}/months/{seq}/compensations` |
| Quitar | `DELETE` del mismo recurso, con `?compensationDate` |

El componente ya navega por mes, lleva totales requerido/compensado/saldo, pinta feriados
institucionales y bloquea días tomados por otra PDS. Hay que **acotarlo a un mes** en vez de
dejarlo navegar.

Las dos listas llegan con la **misma forma** —el backend renombra `fec_compro` a `fec_comrea`— así
que la comparación no traduce nada.

**La diferencia se muestra y no bloquea.** Lo que frena es el envío.

**Estimado:** 2 jornadas — el grueso es acotar el componente sin romper su uso en resolución.

---

## V5 · Bloque de cuotas

```
Cuota 1   Propuesta   Sep 2026   $141.111   Pago: Oct 2026   [Editar] [Eliminar]
                                                              [+ Nueva cuota]
```

| | |
| :--- | :--- |
| Datos | `installments` del store |
| Derivados del backend | `isEditable` · `hasExtension` · `deductionTotal` · `netAmount` |
| Eliminar | `DELETE /payments/provisions/{id}/installments/{nro}` |
| Enviar | `POST /payments/provisions/{id}/installments/{nro}/submit` |

`isEditable` ya decide si se muestran los botones: **no replicar la regla de estados en el
frontend**.

`[+ Nueva cuota]` se deshabilita cuando se agotó el cupo, salvo `hasExtension`.

**Estimado:** 1 jornada.

---

## V6 · Formulario de cuota — modal

El núcleo de la pantalla.

### Al abrir

| Caso | Qué carga |
| :--- | :--- |
| Nueva | meses disponibles del funcionario, nada marcado |
| Editar | `GET /payments/provisions/{id}/installments/{nro}/months` → precarga los marcados |

Ese segundo endpoint es el que hace posible editar: sin él no se sabe qué meses tiene la cuota.

### Campos

| Campo | Regla |
| :--- | :--- |
| Meses | solo los `isAvailable`, más los que la cuota ya tiene. Un mes en una sola cuota |
| Mes de pago | deriva *corriente* o *atrasada* en vivo |
| Monto por mes | editable solo en Variable |
| Respaldo | **oculto por ahora** — la subida está parqueada |

### Guardar

```
POST  /payments/provisions/{id}/installments            nueva
PUT   /payments/provisions/{id}/installments/{nro}      existente
```

La respuesta del `POST` trae `installmentNumber`. Tras guardar, refrescar meses y cuotas: el estado
de los meses no cambia al guardar, pero su asignación a cuota sí.

### Errores

El backend devuelve **422 con el mensaje del PA**, ya redactado para el usuario y sin nombres de
tabla. Mostrarlo tal cual; no traducir ni mapear códigos.

**Estimado:** 3 jornadas.

---

## Pestaña de antecedentes

| Sub-pestaña | Fuente |
| :--- | :--- |
| Detalle de la resolución | `GET /requests/service-provision/resolution-details/{id}` |
| Documento | `GET /resolution/file/{año}/{nroResolu}/{correlativo}` — el **2** es el firmado |

Sin acciones: ni firmar, ni aprobar, ni archivar.

**Estimado:** 1 jornada.

---

## Transversales

| | |
| :--- | :--- |
| Textos | todos a `lang/es/pds.js` — §15 del estándar |
| Scope | `.pds-du288-scope` en la raíz de cada página |
| Responsive | 1366 · 1024 · 768 · 375 |
| Lint | agregar las páginas nuevas a `utils/validateDu288Ui.js` |

**Estimado:** 1 jornada.

---

## Orden y total

| | Ventana | Jornadas | Desbloquea |
| :-- | :--- | :-- | :--- |
| 1 | V2 contenedor + store | 2 | todo lo demás |
| 2 | V1 navegación desde la bandeja | 0,5 | poder entrar |
| 3 | V3 meses | 1 | ver qué se puede pagar |
| 4 | V5 cuotas | 1 | ver lo que existe |
| 5 | V6 formulario | 3 | **crear y editar** |
| 6 | V4 compensación | 2 | informar lo realizado |
| 7 | Antecedentes | 1 | contexto |
| 8 | Transversales | 1 | cierre |

**11,5 jornadas.** Al terminar el paso 5 el jefe de proyecto ya crea, edita y envía cuotas; los
pasos 6 y 7 agregan el registro de compensación y el contexto documental.

---

## Lo que esta pantalla no podrá hacer todavía

| | Por qué |
| :--- | :--- |
| Adjuntar el respaldo | parqueado hasta decidir dónde se guarda el PDF |
| Ver el panel normativo revalidado | el servicio que orquesta los ocho PA no está |
| Seguir la cuota después de enviarla | el lado DGDP no existe: queda en *En visación* y ahí se detiene |

El tercero conviene decirlo en la pantalla, no dejar que el usuario lo descubra: una cuota enviada
se queda quieta hasta que exista la bandeja de DGDP.
