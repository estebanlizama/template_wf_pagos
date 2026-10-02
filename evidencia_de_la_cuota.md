# Respaldo documental de la cuota — `id_evidenc`

> [!WARNING]
> **TODO — no se implementa hasta que se aclare dónde se guarda el archivo.**
>
> La columna `sg_epag.id_evidenc` existe y los endpoints de cuota la aceptan, pero **no hay
> subida ni descarga**. El envío tampoco la exige: `sg_epaguSecgen02` no verifica que esté
> presente, de modo que el flujo del solicitante funciona completo sin ella.
>
> Cuando se decida, lo que falta es: la tabla MySQL y el espacio de `id_evidenc` (§4), el `POST`
> de subida, el `GET` de descarga, y agregar al envío la verificación de PAG-11.
>
> Lo de abajo es el análisis hecho, no un plan en curso.

**Fecha:** 01-10-2026
**Definición del negocio:** un documento por cuota —PDF u otro— que contiene **toda** la evidencia
de esa solicitud de pago. Lo sube el **jefe de proyecto**.

---

## 1. Dónde calza

`sg_epag.id_evidenc int NULL` — una columna, un documento, por cuota. Coincide exactamente con la
definición.

---

## 2. Lo que hay que saber antes de construirlo

### 2.1 El binario no vive en Sybase

El sistema guarda los archivos en **MySQL**, y Sybase solo conserva el identificador:

| Uso | Dónde | Clave |
| :--- | :--- | :--- |
| Adjunto de una solicitud | `MySecGen.sg_doju_<año>` | `id_docum` = número de solicitud |
| Documento del archivo universitario | `MyArchivo.<tabla>` | `id_docum`, con la tabla como parámetro |

La tabla está **particionada por año**, así que recuperar un archivo exige conocer el año además
del identificador. Por eso `ServiceProvisionRequestFile` lleva un campo `tab_mysql`.

### 2.2 Hay un diseño previo más complejo, nunca construido

En la fase DU09 se planificó un modelo de evidencias **por mes**, con catálogo de tipos:

```
sg_tevi  ──< sg_fuev >── sg_fume
tipos de     evidencias    mes
evidencia    (cod_tievi)   (id_funmes)
```

Existe el modelo TypeScript `ServiceProvisionRequestFile` con esa forma —`id_file`, `id_solicit`,
`id_funmes`, `cod_tievi`, `comentario`, `rut_creaci`, `tip_archiv`, `tab_mysql`— y existe su
repositorio `ServiceProvisionRequestFileRepository`.

**El repositorio está vacío.** Sus cinco métodos son `//TODO: run query`. Las tablas `sg_fuev` y
`sg_tevi` tampoco existen en la base.

### 2.3 `sg_fume.id_evidenc` sobra

La columna existe también en el mes. Con un documento por cuota, no tiene uso: la evidencia
pertenece a la solicitud de pago completa, no a cada mes que abarca.

Conviene dejarla sin escribir y documentarlo, o quitarla cuando se toque `sg_fume` por el desfase
de `sg_fum2`, que ya está pendiente.

---

## 3. Lo que la definición simplifica

| Del diseño previo | Con un documento por cuota |
| :--- | :--- |
| `sg_fuev` — tabla de evidencias | **No hace falta.** `sg_epag.id_evidenc` basta |
| `sg_tevi` — catálogo de tipos | **No hace falta.** Un solo documento, sin tipificar |
| Vínculo por mes (`id_funmes`) | Reemplazado por el vínculo a la cuota |
| Varias evidencias por mes | Una por cuota |

Queda un `int` apuntando a un registro en MySQL. Nada más.

---

## 4. Lo que falta construir

| # | Qué | Nota |
| :-- | :--- | :--- |
| 1 | Decidir el espacio de `id_evidenc` | No puede colisionar con `id_docum` de solicitudes si comparte tabla |
| 2 | Tabla MySQL o reutilizar `sg_doju_<año>` | Si se reutiliza, (1) es obligatorio |
| 3 | `POST` de subida | Multipart, hex a MySQL, devuelve el `id_evidenc` |
| 4 | `GET` de descarga | Autorizado por responsable del centro de costo, como el resto del módulo |
| 5 | Reemplazo del archivo | Mientras la cuota esté en estado 1 o 3 |

El punto **1** es el que hay que resolver primero. Si el PDF de la cuota se guarda en
`sg_doju_<año>` con `id_docum = id_evidenc`, y ese espacio ya lo usan los números de solicitud,
dos registros distintos pueden chocar. Las salidas:

- una **tabla MySQL propia** para evidencias de pago, con su propio correlativo;
- o un **rango reservado** dentro de `sg_doju_<año>`, que es frágil.

La primera es más limpia y no toca nada existente.

---

## 5. Reglas del documento

| | |
| :--- | :--- |
| Quién lo sube | Jefe de proyecto, responsable vigente del centro de costo |
| Cuándo | Mientras la cuota esté en **1 Propuesta** o **3 Observada** |
| Obligatorio | **Al enviar**, no al guardar el borrador |
| Cuántos | Uno por cuota. Subir otro reemplaza al anterior |
| Quién lo ve | El jefe de proyecto y DGDP durante la visación |
| Después del envío | Solo lectura |
