/*
===============================================================================
DU288 - TOPES 2026 PARA CARGO 3120
Motor : Sybase ASE 12.5

Actualiza los seis registros definidos para DU288 e inserta los faltantes.
Respeta la PK: cod_cargo + cod_unidad + f_inicio.
===============================================================================
*/

USE secgen_db
GO

SET NOCOUNT ON
GO

CREATE TABLE #topes_du288 (
    cod_cargo smallint NOT NULL,
    cod_unidad char(8) NOT NULL,
    f_inicio datetime NOT NULL,
    mto_tope int NOT NULL
)

INSERT INTO #topes_du288 VALUES (3120, '16100000', '20260101', 2566751)
INSERT INTO #topes_du288 VALUES (3120, '16110000', '20260101', 2397930)
INSERT INTO #topes_du288 VALUES (3120, '16120000', '20260101', 2645633)
INSERT INTO #topes_du288 VALUES (3120, '16130000', '20260101', 2471469)
INSERT INTO #topes_du288 VALUES (3120, '16140000', '20260101', 2554357)
INSERT INTO #topes_du288 VALUES (3120, '16150000', '20260101', 1851943)
GO

UPDATE secgen_db.dbo.sg_toca
SET f_termino = NULL,
    mto_tope = x.mto_tope,
    vigente = 'S'
FROM secgen_db.dbo.sg_toca t, #topes_du288 x
WHERE t.cod_cargo = x.cod_cargo
  AND t.cod_unidad = x.cod_unidad
  AND t.f_inicio = x.f_inicio
GO

INSERT INTO secgen_db.dbo.sg_toca
    (cod_cargo, cod_unidad, f_inicio, f_termino, mto_tope, vigente)
SELECT x.cod_cargo, x.cod_unidad, x.f_inicio, NULL, x.mto_tope, 'S'
FROM #topes_du288 x
WHERE NOT EXISTS (
    SELECT 1
    FROM secgen_db.dbo.sg_toca t
    WHERE t.cod_cargo = x.cod_cargo
      AND t.cod_unidad = x.cod_unidad
      AND t.f_inicio = x.f_inicio
)
GO

DROP TABLE #topes_du288
GO

