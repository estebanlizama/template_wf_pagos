# Limpieza del backend y transiciones de estado en resolución

---

## 1. ¿Resolución necesita actualizar el estado del mes?

El código actual **intenta** hacerlo en cuatro etapas, llamando a un método vacío. Vale la pena
evaluar cada intención antes de borrarla, porque puede haber una necesidad real escondida.

| Etapa de resolución | Transición que intenta hoy | ¿Aporta? |
| :--- | :--- | :--- |
| **Enviar** | inserta en 1 Propuesta | **Sí** — es el origen. Ya funciona |
| **Devolver a corrección** | → `RETURNED_TO_CORRECTION (3)` | **No.** El mes en 1 ya es editable; la guarda `cod_estfum not in (1, 4)` lo permite. Un estado extra no habilita nada nuevo |
| **Rechazar** | → `REJECTED (10)` | **No.** `sg_fupssSecgen17` filtra `soli.cod_estsol not in (4)`: las solicitudes rechazadas no entran al comparador. La exclusión ya está resuelta un nivel arriba |
| **Aprobar / archivar** | → `ENABLED (5)` | **No.** "El mes es pagable" = la resolución está archivada y la ejecución ya pasó. Ambas condiciones se leen de la cabecera y de las fechas |

### Conclusión

**Resolución no actualiza estados. Escribe 1 al enviar y nada más.**

El estado del mes solo se mueve en el WF de pagos. Y eso no es una limitación: es lo que hace que
la guarda de edición funcione. Mientras ningún pago exista, todos los meses están en 1 y la
resolución es libremente editable — que es exactamente el comportamiento esperado.

### El riesgo de implementar lo que el código muerto insinúa

Si alguien "arreglara" el stub y marcara los meses de una solicitud rechazada:

- la exclusión quedaría **duplicada** (por cabecera en el PA, y por mes en la fila),
- y las dos podrían desincronizarse: una solicitud reabierta dejaría meses marcados como
  rechazados aunque la cabecera ya no lo esté.

Por eso conviene borrarlo, no completarlo.

---

## 2. Qué se elimina

### 2.1 El stub y sus 7 llamadas

| Archivo | Líneas | Qué se quita |
| :--- | :--- | :--- |
| `repositories/storedProcedures/service-provision-request-procedures.repository.ts` | 3893-3908 | el método `updateInstallmentStatusesByRequest` |
| `services/service-provision-workflow.service.ts` | 1076-1089 | el `if` completo y su llamada |
| `controllers/service-provision/service-provision-request-approval.controller.ts` | 592, 666 | las dos llamadas y sus `if` |
| `repositories/service-provision-request-approval.repository.ts` | 239-245, 255-262 | las dos llamadas |
| `repositories/resolution-approval.repository.ts` | 509-515, 527-534 | las dos llamadas |
| `db-assets/.../service-provision-request.ts` | 382-388 | la query `updateInstallmentStatusesByRequest` |
| `constants/service-provision.constant.ts` | 37-43 | `ServiceProvisionInstallmentStatusCode` |

La constante solo la usan esas 7 llamadas. Sus códigos (`CREATED: 1, IN_REVIEW: 2,
RETURNED_TO_CORRECTION: 3, ENABLED: 5, REJECTED: 10`) son los viejos de `sg_ecuo`, y tres de
ellos no existen en `sg_efum`.

Al quitar el `if` de `workflow.service.ts:1076`, revisar que el import de la constante también
salga.

### 2.2 Tipos declarados sin consumidor

| Archivo | Línea | Qué |
| :--- | :--- | :--- |
| `models/service-provision/request-staff.model.ts` | 300-306 | `installments?: Array<{nroCuota, anoProp, mesProp, codEstcuo, desEstcuo}>` |
| `models/service-provision/request-service.model.ts` | 103 | `installmentStatusId?: number` |

Ninguno tiene lectura ni escritura en todo el backend. Son contratos declarados y abandonados,
con los nombres viejos. **Se eliminan**: si más adelante hace falta exponer los meses en el
payload de la solicitud, se agrega con el grano y los nombres correctos.

### 2.3 Lo que NO se elimina

`installment-status.controller.ts` y `sg-ecuo.model.ts` siguen válidos: `sg_ecuo` no desaparece,
pasa a ser el catálogo del encabezado de pago.

> ⚠️ Pero conviene verificar algo: los PA que ese controlador invoca —`sg_ecuossSecgen01`,
> `sg_ecuossSecgen02`, `sg_ecuosiSecgen01`, `sg_ecuouSecgen01`— **no están en
> `sissolic-procedimientos/`**. O el controlador está llamando a procedimientos inexistentes, o
> el repositorio de PA desplegados está incompleto. Hay que confirmarlo contra el ambiente antes
> de tomarlo como referencia para los de `sg_efum`.

---

## 3. Qué se crea

### 3.1 PA de `sg_efum`

En `cambios_pa/sg_efum/`: `sg_efumsSecgen01` (listar), `sg_efumsSecgen02` (por código),
`sg_efumiSecgen01` (insertar), `sg_efumuSecgen01` (actualizar descripción).

Sin `delete`: borrar una fila rompería las FK de `sg_fume` y `sg_fum2`.

### 3.2 Backend — espejo del de `sg_ecuo`

| Pieza | Archivo |
| :--- | :--- |
| Modelo | `models/service-provision/sg-efum.model.ts` — `codEstfum`, `desEstfum` |
| Queries | 4 entradas en `db-assets/.../service-provision-request.ts` |
| Controlador | `controllers/service-provision/month-status.controller.ts` |

Rutas sugeridas, en paralelo a las de `installment-statuses`:

```
GET    /requests/service-provision/month-statuses
GET    /requests/service-provision/month-statuses/{codEstfum}
POST   /requests/service-provision/month-statuses
PATCH  /requests/service-provision/month-statuses/{codEstfum}
```

### 3.3 Frontend — mostrar el estado del mes

Hoy el estado llega embebido en cada fila del historial (`des_estcuo` → `installmentStatus`) y el
frontend lo usa para el matching por texto. Con el cambio:

1. `des_estfum` sigue viajando en cada fila — para **mostrar** la etiqueta no hace falta consultar
   el catálogo aparte.
2. `cod_estfum` es lo que se usa para **decidir** (cupo, badges, severidad), reemplazando el
   matching por substring.
3. El endpoint de catálogo se consulta solo si hace falta un **filtro** por estado en la bandeja
   o el comparador — un selector "mostrar solo meses comprometidos".

> Es decir: el catálogo no es necesario para pintar el historial, pero sí para filtrarlo. Y evita
> hardcodear las etiquetas en el frontend.

---

## 4. Orden de trabajo

| # | Paso | Depende de |
| :-- | :--- | :--- |
| 1 | Eliminar el stub, las 7 llamadas, la query y la constante | — |
| 2 | Eliminar los dos tipos sin consumidor | — |
| 3 | Desplegar los 4 PA de `sg_efum` | tabla creada |
| 4 | Modelo + queries + controlador de `sg_efum` en backend | 3 |
| 5 | `sg_fumeuSecgen01` y `sg_fupssSecgen17` a `corr_fume`/`cod_estfum` | migración de BDD |
| 6 | Backend: repository, template y modelo de respuesta | 5, mismo despliegue |
| 7 | Frontend: clasificación por código y etiquetas | 6 |

Los pasos 1 y 2 son independientes del resto y se pueden hacer primero: quitan ruido antes de
tocar lo que sí importa.

---

## 5. Lo que queda por confirmar

1. **¿Existen los PA de `sg_ecuo` en el ambiente?** Si no, ese controlador está muerto también y
   entra en la limpieza.
2. **¿Se renombra `installments` → `months` en la API?** Sigue abierto desde `impacto_08`.
3. **`sg_fupssSecgen18`** — adaptación mínima a `cod_estfum` para que la bandeja de pagos no se
   caiga.
