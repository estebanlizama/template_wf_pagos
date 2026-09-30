# `sisper_db..sp_as31` — justificaciones del día

Detalle de `sp_as01`. Registra por qué un atraso, una salida anticipada o un marcaje faltante
quedó justificado.

---

## Estructura

| Columna | Qué es |
| :--- | :--- |
| `cod_asist` | FK al registro del día en `sp_as01` |
| `cod_catjus` | categoría → `sp_cjus` |
| `cod_tipjus` | tipo → `sp_tjus` |
| `cod_tipmar` | **marca a la que aplica la justificación** |

---

## Ejemplo real

```
cod_asist|cod_catjus|cod_tipjus|cod_tipmar|
   887969|         1|        11|         1|
```

Que se lee: el día `887969` tuvo una justificación **Laboral** (cat 1) del tipo **Error en
Biométrico** (tipo 11), aplicada a la marca **1**.

En el resultado del PA aparece como `"Error en  Biometrico/Laboral"`.

---

## `cod_tipmar` — una dimensión que faltaba

El script original ignoraba esta columna. Distingue **a cuál marca** se refiere la
justificación: entrada, salida, o las intermedias de colación.

Importa porque un día puede tener justificada la entrada pero no la salida. Sin esa columna, las
justificaciones se mezclan y no se sabe qué quedó cubierto.

> Los valores de `cod_tipmar` no están documentados todavía. Hay que revisar si existe un
> catálogo o si son constantes del módulo.

---

## Cardinalidad

En los datos revisados aparece **una fila por `cod_asist`**, pero nada en el modelo lo garantiza:
la tabla no tiene PK declarada sobre `cod_asist` solo, y un día con dos marcas justificadas
necesitaría dos filas.

El PA de asistencia las agrupa con cursor por precaución. El script original usaba
`UPDATE...FROM`, que con varias coincidencias aplica una arbitraria y descarta el resto.

---

## Uso en el WF de pagos

Un atraso justificado no es lo mismo que un atraso sin más. Para acreditar ejecución:

| Situación | Lectura |
| :--- | :--- |
| Atraso con justificación laboral | el tiempo se explica por trabajo |
| Atraso con justificación personal | el tiempo no se trabajó, pero está autorizado |
| Marcaje faltante justificado por *Error en Biométrico* o *Sin Acceso a Reloj* | **el día sí se trabajó**, falló el registro |

El último caso es el más relevante: tres de los tipos de `sp_tjus` —*Error en Biométrico*,
*Sin Acceso a Reloj*, *Olvida Marcar*— indican que **el problema fue el registro, no la
asistencia**. Sin considerarlos, el WF penalizaría días efectivamente trabajados.

---

## Relaciones

```
sp_as01 ◄──── cod_asist ──── sp_as31 ──── cod_tipjus ────► sp_tjus
                                     ──── cod_catjus ────► sp_cjus
                                     ──── cod_tipmar ────► (sin catalogo identificado)
```
