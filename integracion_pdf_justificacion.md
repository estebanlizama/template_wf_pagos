# PDF de justificación de la cuota — cómo integrarlo

**Fecha:** 05-10-2026
**Decisión de negocio:** el jefe de proyecto adjunta un PDF de justificación a la solicitud de pago.
El identificador del documento se guarda en la cuota.
**Estado:** análisis previo a implementar. Hay **una decisión pendiente** (§3).

Sustituye el TODO de [`evidencia_de_la_cuota.md`](evidencia_de_la_cuota.md), que quedó parado
justamente en este punto.

---

## 1. Cómo guarda archivos el sistema hoy

Los binarios no viven en Sybase sino en **MySQL**, en tablas particionadas por año. Sybase solo
conserva el identificador.

| Tabla | Qué guarda | Clave |
| :--- | :--- | :--- |
| `MySecGen.sg_doju_<año>` | documento de justificación de una **solicitud** | `id_docum` = `nro_solici` |
| `MySecGen.sg_apdo_<año>` | documento de cargo | `id_docum` |
| `MySecGen.sg_baar_<año>` | bases de licitación | `id_docum` |
| `MySecGen.sg_rslc_<año>` | resolución firmada | `ano_resolu` · `nro_resolu` · `correlativ` |

Dos cosas importantes:

1. **`id_docum` no es autoincremental.** Lo provee quien inserta. `uploadRequestDocument` hace
   *upsert*: si ya existe esa fila, **la reemplaza**.
2. **La convención es una tabla por tipo de documento.** Y `sg_rslc` demuestra que una tabla de esta
   familia no está obligada a tener un `id_docum` único: puede llevar la clave de negocio que
   identifique naturalmente al documento.

---

## 2. El problema de usar `sg_doju` tal cual

No es la colisión que anticipaba el análisis anterior. Es más simple y más grave:

```
una solicitud  →  hasta 12 cuotas  →  12 PDF
sg_doju        →  una fila por id_docum
```

Con `id_docum = nro_solici` **solo cabe un documento por solicitud**, y aquí hace falta uno por
cuota. Además esa fila es la del documento de la propia solicitud: escribirla la sobrescribiría,
porque el método existente actualiza cuando la fila ya está.

Y el espacio de `nro_solici` es **compartido**: `sg_doju` ya lo usan devolución de saldos e
incentivo a la productividad científica con el mismo correlativo. No es un espacio libre que
podamos repartir.

Conclusión: para guardar en `sg_doju` hay que usar un `id_docum` **distinto del número de
solicitud**, que no pueda chocar con ninguno.

---

## 3. La decisión pendiente: de dónde sale el `id_docum`

Tres caminos reales. Los tres dejan el binario en MySQL y el identificador en `sg_epag.id_evidenc`,
que ya existe y los endpoints ya aceptan.

### Opción A — Tabla propia de la misma familia *(recomendada)*

```sql
CREATE TABLE MySecGen.sg_evpa_<año> (
  id_docum int NOT NULL,       -- id_funprse * 100 + nro_cuota
  archivo  longblob,
  PRIMARY KEY (id_docum)
);
```

| | |
| :--- | :--- |
| A favor | sigue la convención del sistema; espacio propio, sin colisión posible; el id se deriva de la cuota y no necesita correlativo ni secuencia |
| En contra | requiere crear la tabla por año, como las demás |

Es lo mismo que ya se hizo para cada tipo de documento. `sg_rslc` incluso usa clave compuesta; aquí
basta derivarla.

### Opción B — `sg_doju` con identificador negativo

`id_docum = -(id_funprse * 100 + nro_cuota)`. Los `nro_solici` son positivos, así que nunca chocan.

| | |
| :--- | :--- |
| A favor | no se crea nada; usa la carpeta `doju` literalmente |
| En contra | la tabla pasa a guardar dos tipos de documento distinguidos por el **signo**, algo que nadie deduce leyendo el esquema; depende de que la columna sea `int` con signo |

Funciona, es barato y es reversible. Pero es un namespace escondido en un bit.

### Opción C — `sg_doju` con rango reservado

`id_docum = 9_000_000 + (id_funprse * 100 + nro_cuota)`, por ejemplo.

| | |
| :--- | :--- |
| A favor | no se crea nada |
| En contra | frágil: el día que `nro_solici` alcance el rango, choca en silencio y sobrescribe un documento |

**No recomendada.** Es la que el análisis previo ya había descartado.

> **Qué hace falta de ti:** elegir entre A y B. El resto (§4 a §7) es idéntico en ambos casos;
> solo cambia la tabla y cómo se arma el `id_docum`.

---

## 4. Dónde se guarda el identificador

`sg_epag.id_evidenc int NULL` — **ya existe** y ya lo escriben los PA:

| PA | Qué hace con él |
| :--- | :--- |
| `sg_epagiSecgen01` | lo inserta al crear la cuota |
| `sg_epaguSecgen01` | lo actualiza al editarla |

Es decir, la columna y su escritura **ya están resueltas**. Lo que falta es quién produce el valor.

`sg_fume.id_evidenc` queda sin uso: con un documento por cuota, la evidencia pertenece a la
solicitud de pago completa, no a cada mes.

---

## 5. Lo que hay que construir

### 5.1 Backend

| | Endpoint | Nota |
| :-- | :--- | :--- |
| 1 | `POST /payments/provisions/{id}/installments/{nro}/evidence` | multipart; convierte a hex, inserta o reemplaza, devuelve `id_evidenc` y lo persiste en la cuota |
| 2 | `GET /payments/provisions/{id}/installments/{nro}/evidence` | devuelve el binario con su `Content-Type`; `?action=download` fuerza descarga |
| 3 | `DELETE` del mismo recurso | solo mientras la cuota esté en estado 1 o 3 |

Los tres reutilizan el patrón que ya existe en `request.controller.ts`: `buffer.toString('hex')`,
prefijo `0x`, y el servicio MySQL aparte del de Sybase.

**Autorización:** el mismo guardia del módulo, `requireProjectManager`. La descarga la necesita
además DGDP cuando exista su lado, así que conviene que el guardia de lectura sea más amplio que el
de escritura desde el principio.

### 5.2 Procedimientos

Ninguno nuevo para guardar: `sg_epagiSecgen01` y `sg_epaguSecgen01` ya reciben `@id_evidenc`.

Sí hace falta **una línea en `sg_epaguSecgen02`** para la regla PAG-11, que hoy no se verifica:

```sql
if @id_evidenc is null
begin
    select 'Error: Debe adjuntar el documento de justificacion antes de enviar' msg
    return
end
```

Obligatorio **al enviar**, no al guardar el borrador. Es coherente con el estándar §6.3: *«Guardar
borrador solo valida integridad mínima de persistencia. Enviar valida reglas completas.»*

### 5.3 Frontend

El compositor de cuota ya tiene su sitio: el campo estaba previsto y quedó oculto. Entra en el
compositor, no en una sección aparte, porque pertenece a la cuota que se está armando.

| Estado | Qué muestra |
| :--- | :--- |
| Sin documento, cuota editable | zona de carga + *«Obligatorio para enviar»* |
| Con documento, cuota editable | nombre, tamaño, ver, descargar, reemplazar, eliminar |
| Con documento, cuota enviada | ver y descargar, sin acciones de cambio |
| Subiendo | barra o spinner, control deshabilitado |

El modal de envío (§10 de `cuota_registro_revision.md`) debe sumar una línea con el documento
adjunto: hoy resume meses, montos y destinatario, y el respaldo es parte de lo que se envía.

El pie de **Enviar a validación** suma este bloqueo a los que ya muestra, con su motivo.

---

## 6. Reglas del documento

| | |
| :--- | :--- |
| Quién lo sube | jefe de proyecto, responsable vigente del centro de costo |
| Cuándo | mientras la cuota esté en **1 Propuesta** o **3 Observada** |
| Obligatorio | **al enviar**, no al guardar borrador |
| Cuántos | uno por cuota; subir otro reemplaza al anterior |
| Quién lo ve | jefe de proyecto y DGDP en la visación |
| Después del envío | solo lectura |

---

## 7. Qué falta definir, aparte de §3

| | Pregunta | Por qué importa |
| :-- | :--- | :--- |
| 1 | ¿Solo PDF, o se aceptan otros formatos? | el sistema no valida tipo hoy; conviene fijarlo y verificarlo en el servidor, no solo con `accept` |
| 2 | ¿Tamaño máximo? | el `longblob` aguanta, pero la carga y el retorno no deberían ser ilimitados |
| 3 | ¿Qué año particiona la tabla? | `uploadRequestDocument` usa `getLastAnoProcess()`, no el año de la solicitud. Conviene usar el mismo criterio para no inventar uno nuevo |
| 4 | Al eliminar una cuota en borrador, ¿se borra su archivo? | hoy `sg_epagdSecgen01` borra `sg_dpag` y `sg_epag`; el binario quedaría huérfano en MySQL |

La **4** conviene resolverla junto con la implementación: es la única que deja basura si se omite.
