/*
===============================================================================
MIGRACION - sg_fume.cod_estcuo  ->  sg_fume.cod_estfum
Motor : Sybase ASE 12.5

Convierte las filas que hoy apuntan al catalogo de cuota (sg_ecuo) al catalogo
propio del mes (sg_efum), con su numeracion contigua.

ORDEN OBLIGATORIO
  a) ALTER TABLE sg_fume ADD cod_estfum tinyint NULL
  b) este script
  c) ALTER TABLE sg_fume ... cod_estfum NOT NULL  +  FK a sg_efum
  d) DROP de la columna vieja sg_fume.cod_estcuo
  e) repetir a-d sobre sg_fum2 (espejo historico)

ANTES DE EMPEZAR, revisar que hay realmente en la tabla:
    SELECT cod_estcuo, count(*) FROM secgen_db.dbo.sg_fume GROUP BY cod_estcuo

En un sistema sin datos de pago solo deberia aparecer el 1: el WF de
resolucion es el unico que escribe hoy, y siempre inserta 1.
===============================================================================
*/

USE secgen_db
GO

SET NOCOUNT ON
GO

/* -------------------------------------------------------------------------
   MAPA
   -------------------------------------------------------------------------
    viejo (sg_ecuo)            nuevo (sg_efum)
    -----------------------------------------------------------------
     1 Propuesta            ->  1 Propuesta
     5 Disponible pago      ->  1 Propuesta     pasa a derivarse por fecha
    10 Rechazada            ->  1 Propuesta     el rechazo de cuota libera
     2 En visacion          ->  2 Comprometida  la cuota tramita
     3 Observada            ->  2 Comprometida  devolver no libera
     4 Aprobada             ->  2 Comprometida
     6 Solicitada pago      ->  2 Comprometida
     7 Autorizada pago      ->  2 Comprometida
    11 Devuelta Finanzas    ->  2 Comprometida
     8 Enviada remunerac.   ->  3 Enviada a pago
     9 Pagada               ->  3 Enviada a pago  el terminal es "enviada"
    12 Bloqueada            ->  4 Rechazada
   ------------------------------------------------------------------------- */

CREATE TABLE #mapa (
    cod_viejo tinyint NOT NULL,
    cod_nuevo tinyint NOT NULL
)
GO

INSERT INTO #mapa VALUES ( 1, 1)
INSERT INTO #mapa VALUES ( 5, 1)
INSERT INTO #mapa VALUES (10, 1)
INSERT INTO #mapa VALUES ( 2, 2)
INSERT INTO #mapa VALUES ( 3, 2)
INSERT INTO #mapa VALUES ( 4, 2)
INSERT INTO #mapa VALUES ( 6, 2)
INSERT INTO #mapa VALUES ( 7, 2)
INSERT INTO #mapa VALUES (11, 2)
INSERT INTO #mapa VALUES ( 8, 3)
INSERT INTO #mapa VALUES ( 9, 3)
INSERT INTO #mapa VALUES (12, 4)
GO

UPDATE secgen_db.dbo.sg_fume
SET cod_estfum = m.cod_nuevo
FROM secgen_db.dbo.sg_fume f, #mapa m
WHERE f.cod_estcuo = m.cod_viejo
GO

/* Espejo historico. Descomentar una vez que sg_fum2 tenga la columna.

UPDATE secgen_db.dbo.sg_fum2
SET cod_estfum = m.cod_nuevo
FROM secgen_db.dbo.sg_fum2 h, #mapa m
WHERE h.cod_estcuo = m.cod_viejo
GO

*/

DROP TABLE #mapa
GO

/* -------------------------------------------------------------------------
   VERIFICACION - no debe quedar ninguna fila sin convertir
   ------------------------------------------------------------------------- */

SELECT cod_estcuo AS cod_viejo, cod_estfum AS cod_nuevo, count(*) AS filas
FROM secgen_db.dbo.sg_fume
GROUP BY cod_estcuo, cod_estfum
ORDER BY cod_estcuo
GO

SELECT count(*) AS sin_convertir
FROM secgen_db.dbo.sg_fume
WHERE cod_estfum IS NULL
GO
