# Orden de despliegue — ¿se cae resolución?

Sí, si el orden es incorrecto. Hay **tres ventanas** donde el WF de resolución deja de funcionar,
y las tres se evitan con el orden y con desplegar PA y backend juntos.

---

## Primero: hoy los datos NO están mal guardados

`sg_fume.cod_estcuo = 1` con FK a `sg_ecuo`, donde 1 = *Propuesta*. Es **coherente**: el valor
existe, significa lo que dice y la FK lo respalda.

Lo que está mal no es el dato, es el **modelo**: `sg_fume` apunta a un catálogo de 12 estados de
los cuales sólo uno le aplica. Los otros 11 describen el trámite de una cuota, que `sg_fume` no
es. Es un olor de diseño, no corrupción.

Y hay una consecuencia práctica: **el valor 1 no cambia**. `sg_efum` también usa 1 = *Propuesta*.
La migración no reescribe el dato de resolución — le cambia la columna y el catálogo al que
apunta.

---

## Las tres ventanas de caída

### 🔴 Ventana 1 — `DROP` de `sg_fume.cod_estcuo` antes de recompilar `sg_fumeuSecgen01`

`sg_fumeuSecgen01` es el **único** PA de escritura de resolución. Referencia `cod_estcuo` en
cuatro puntos (firma, guarda, `INSERT`, `SELECT`). Si la columna desaparece antes de recompilar,
**guardar cualquier solicitud DU288 falla**.

> Impacto: el solicitante no puede guardar ni editar una prestación.

### 🔴 Ventana 2 — PA recompilado con `@cod_estfum` pero backend enviando `@cod_estcuo`

El template de la query pasa el parámetro por nombre:

```
EXECUTE secgen_db.Analisis2.sg_fumeuSecgen01
    @id_funprse = {{ id_funprse }},
    @meses_csv  = '{{ meses_csv }}',
    @cod_estcuo = {{ cod_estcuo }}     <-- service-provision-request.ts:162
```

Sybase responde *"Procedure expects parameter @cod_estfum"*. **PA y backend tienen que
desplegarse en la misma ventana**, no uno antes que otro.

> Impacto: el mismo que la ventana 1, y además no se detecta en compilación — falla en runtime.

### 🔴 Ventana 3 — `sg_fupssSecgen17` sin actualizar

Selecciona `fume.cod_estcuo` y hace `join sg_ecuo on ecuo.cod_estcuo = fume.cod_estcuo`. Al
eliminar la columna, el PA falla.

Ese PA alimenta el **modal de prestaciones previas**, que es parte del flujo de resolución: sin
él, el comparador DGDP y el cupo del numeral 6 se quedan sin datos.

> Impacto: no se cae el guardado, pero el formulario pierde la validación de cupo y el modal
> queda vacío.

---

## 🟡 Un cuarto riesgo: el orden entre los scripts de catálogo

`01_sg_ecuo.sql` borra los códigos 5, 7, 9, 11 y 12. Mientras `sg_fume.cod_estcuo` siga
existiendo, **también apunta a `sg_ecuo`**: si alguna fila lo usa, el `DELETE` falla por
integridad referencial.

Por eso `01_sg_ecuo.sql` va **al final**, no al principio de la numeración. El script ya trae un
guard que lo detecta y avisa en vez de reventar con un error de FK.

---

## Orden correcto

| Paso | Qué | ¿Resolución funciona? |
| :--: | :--- | :---: |
| 1 | `CREATE TABLE sg_efum` | ✅ |
| 2 | `02_sg_efum.sql` — cargar los 4 estados | ✅ |
| 3 | `ALTER TABLE sg_fume ADD cod_estfum tinyint NULL` | ✅ |
| 4 | `03_migracion_sg_fume.sql` — poblar la columna nueva | ✅ |
| 5 | `ALTER` a `NOT NULL` + FK a `sg_efum` | ✅ |
| 6 | Lo mismo (3-5) en `sg_fum2` | ✅ |
| 7 | **Recompilar `sg_fumeuSecgen01` y `sg_fupssSecgen17`** leyendo `cod_estfum` | ✅ |
| 8 | **Desplegar backend** con `@cod_estfum` — *junto con el paso 7* | ✅ |
| 9 | `DROP` de `sg_fume.cod_estcuo` y `sg_fum2.cod_estcuo` | ✅ |
| 10 | `01_sg_ecuo.sql` — depurar el catálogo de cuota | ✅ |

**La clave son los pasos 3 a 9:** durante todo ese tramo conviven las dos columnas. Los PA
siguen escribiendo `cod_estcuo` hasta el paso 7, y para entonces `cod_estfum` ya está poblada y
validada. El `DROP` recién ocurre cuando nada la referencia.

**Los pasos 7 y 8 son un solo despliegue.** Si se separan, cae en la ventana 2.

---

## Cómo verificar antes de empezar

```sql
-- 1. Qué estados hay realmente en sg_fume.
--    En un sistema sin datos de pago debería salir sólo el 1.
SELECT cod_estcuo, count(*) FROM secgen_db.dbo.sg_fume GROUP BY cod_estcuo

-- 2. Lo mismo en el espejo histórico.
SELECT cod_estcuo, count(*) FROM secgen_db.dbo.sg_fum2 GROUP BY cod_estcuo

-- 3. Quién más apunta a sg_ecuo, por si hay una FK que no está en el diagrama.
SELECT o.name AS tabla, c.name AS columna
FROM sysobjects o, syscolumns c
WHERE c.id = o.id AND o.type = 'U' AND c.name = 'cod_estcuo'
```

Si el paso 1 devuelve algo distinto de `1`, revisar el mapa de `03_migracion_sg_fume.sql` antes
de aplicarlo: esas filas vinieron de inserts manuales de prueba, no del sistema.

---

## Verificar después

```sql
-- No debe quedar ninguna fila sin convertir.
SELECT count(*) FROM secgen_db.dbo.sg_fume WHERE cod_estfum IS NULL

-- Resolución sigue escribiendo sólo el 1.
SELECT cod_estfum, count(*) FROM secgen_db.dbo.sg_fume GROUP BY cod_estfum
```

Y una prueba funcional corta, que cubre las tres ventanas:

1. Crear una solicitud DU288 con 3 meses → debe guardar y dejar 3 filas en `cod_estfum = 1`.
2. Editar el periodo a 2 meses → debe borrar una fila.
3. Abrir el modal de prestaciones previas de ese funcionario → debe traer datos.
