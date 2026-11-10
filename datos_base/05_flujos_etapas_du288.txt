/*
===============================================================================
DU288 - FLUJOS Y ETAPAS PARA CERTIFICACION
Motor : Sybase ASE 12.5

Carga completa definida para:
  - sg_tfls: 8 ramas DU288;
  - sg_eta1: 99 etapas con sus perfiles e IDs aprobados.

Los actores dinamicos (perfiles 6, 25 y 26) y las autoridades dependientes de
unidad conservan cod_organi NULL. Las autoridades institucionales fijas usan
los codigos definidos en la configuracion vigente.
===============================================================================
*/

USE secgen_db
GO

SET NOCOUNT ON
GO

/* -------------------------------------------------------------------------
   1. RAMAS DU288
   ------------------------------------------------------------------------- */

CREATE TABLE #flujos_du288 (
    cod_flusol tinyint NOT NULL,
    des_flusol varchar(60) NOT NULL,
    abr_flusol varchar(10) NOT NULL
)

INSERT INTO #flujos_du288 VALUES (1, 'Facultad',      'FAC')
INSERT INTO #flujos_du288 VALUES (2, 'Investigación', 'INV')
INSERT INTO #flujos_du288 VALUES (3, 'DITT',          'DITT')
INSERT INTO #flujos_du288 VALUES (4, 'Instituto',     'INST')
INSERT INTO #flujos_du288 VALUES (5, 'VRAF',          'VRAF')
INSERT INTO #flujos_du288 VALUES (6, 'VRAC',          'VRAC')
INSERT INTO #flujos_du288 VALUES (7, 'VIPRE',         'VIPRE')
INSERT INTO #flujos_du288 VALUES (8, 'VRIP',          'VRIP')
GO

UPDATE secgen_db.dbo.sg_tfls
SET des_flusol = x.des_flusol,
    abr_flusol = x.abr_flusol,
    vigente = 'S',
    f_ultmodif = GETDATE()
FROM secgen_db.dbo.sg_tfls f, #flujos_du288 x
WHERE f.cod_flusol = x.cod_flusol
GO

INSERT INTO secgen_db.dbo.sg_tfls
    (cod_flusol, des_flusol, abr_flusol, vigente, f_creacion, f_ultmodif)
SELECT x.cod_flusol, x.des_flusol, x.abr_flusol, 'S', GETDATE(), NULL
FROM #flujos_du288 x
WHERE NOT EXISTS (
    SELECT 1
    FROM secgen_db.dbo.sg_tfls f
    WHERE f.cod_flusol = x.cod_flusol
)
GO

/* -------------------------------------------------------------------------
   2. ETAPAS DU288
   ------------------------------------------------------------------------- */

CREATE TABLE #etapas_du288 (
    cod_flusol tinyint NOT NULL,
    cod_etapa tinyint NOT NULL,
    des_etapa varchar(100) NOT NULL,
    cod_perfil smallint NOT NULL,
    est_final char(1) NOT NULL,
    vigente char(1) NOT NULL,
    cod_organi int NULL
)

INSERT INTO #etapas_du288 VALUES (1, 10, 'Solicitante', 6, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (1, 20, 'Jefe de Proyecto', 25, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (1, 30, 'Jefe Directo Funcionario', 26, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (1, 40, 'Director o Encargado Facultad', 8, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (1, 50, 'Decano', 27, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (1, 60, 'Director DGDP', 13, 'N', 'S', 50)
INSERT INTO #etapas_du288 VALUES (1, 70, 'Director Finanzas', 10, 'N', 'S', 41)
INSERT INTO #etapas_du288 VALUES (1, 80, 'Jefe Decretacion', 12, 'N', 'S', 449)
INSERT INTO #etapas_du288 VALUES (1, 90, 'Secretario General', 14, 'N', 'S', 73)
INSERT INTO #etapas_du288 VALUES (1, 100, 'VRAF', 23, 'N', 'S', 39)
INSERT INTO #etapas_du288 VALUES (1, 110, 'Director Legalidad', 16, 'N', 'S', 612)
INSERT INTO #etapas_du288 VALUES (1, 120, 'Contralor Universitario', 17, 'N', 'S', 68)
INSERT INTO #etapas_du288 VALUES (1, 130, 'Jefe Archivo Universitario', 18, 'S', 'S', 77)
INSERT INTO #etapas_du288 VALUES (2, 10, 'Solicitante', 6, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (2, 20, 'Jefe de Proyecto', 25, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (2, 30, 'Jefe Directo Funcionario', 26, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (2, 40, 'Director Investigacion', 32, 'N', 'S', 301)
INSERT INTO #etapas_du288 VALUES (2, 50, 'VRIP', 7, 'N', 'S', 299)
INSERT INTO #etapas_du288 VALUES (2, 60, 'Director DGDP', 13, 'N', 'S', 50)
INSERT INTO #etapas_du288 VALUES (2, 70, 'Director Finanzas', 10, 'N', 'S', 41)
INSERT INTO #etapas_du288 VALUES (2, 80, 'Jefe Decretacion', 12, 'N', 'S', 449)
INSERT INTO #etapas_du288 VALUES (2, 90, 'Secretario General', 14, 'N', 'S', 73)
INSERT INTO #etapas_du288 VALUES (2, 100, 'VRAF', 23, 'N', 'S', 39)
INSERT INTO #etapas_du288 VALUES (2, 110, 'Director Legalidad', 16, 'N', 'S', 612)
INSERT INTO #etapas_du288 VALUES (2, 120, 'Contralor Universitario', 17, 'N', 'S', 68)
INSERT INTO #etapas_du288 VALUES (2, 130, 'Jefe Archivo Universitario', 18, 'S', 'S', 77)
INSERT INTO #etapas_du288 VALUES (3, 10, 'Solicitante', 6, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (3, 20, 'Jefe de Proyecto', 25, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (3, 30, 'Jefe Directo Funcionario', 26, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (3, 40, 'Director DITT', 30, 'N', 'S', 303)
INSERT INTO #etapas_du288 VALUES (3, 50, 'VRIP', 7, 'N', 'S', 299)
INSERT INTO #etapas_du288 VALUES (3, 60, 'Director DGDP', 13, 'N', 'S', 50)
INSERT INTO #etapas_du288 VALUES (3, 70, 'Director Finanzas', 10, 'N', 'S', 41)
INSERT INTO #etapas_du288 VALUES (3, 80, 'Jefe Decretacion', 12, 'N', 'S', 449)
INSERT INTO #etapas_du288 VALUES (3, 90, 'Secretario General', 14, 'N', 'S', 73)
INSERT INTO #etapas_du288 VALUES (3, 100, 'VRAF', 23, 'N', 'S', 39)
INSERT INTO #etapas_du288 VALUES (3, 110, 'Director Legalidad', 16, 'N', 'S', 612)
INSERT INTO #etapas_du288 VALUES (3, 120, 'Contralor Universitario', 17, 'N', 'S', 68)
INSERT INTO #etapas_du288 VALUES (3, 130, 'Jefe Archivo Universitario', 18, 'S', 'S', 77)
INSERT INTO #etapas_du288 VALUES (4, 10, 'Solicitante', 6, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (4, 20, 'Jefe de Proyecto', 25, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (4, 30, 'Jefe Directo Funcionario', 26, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (4, 40, 'Director Instituto', 31, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (4, 50, 'VRIP', 7, 'N', 'S', 299)
INSERT INTO #etapas_du288 VALUES (4, 60, 'Director DGDP', 13, 'N', 'S', 50)
INSERT INTO #etapas_du288 VALUES (4, 70, 'Director Finanzas', 10, 'N', 'S', 41)
INSERT INTO #etapas_du288 VALUES (4, 80, 'Jefe Decretacion', 12, 'N', 'S', 449)
INSERT INTO #etapas_du288 VALUES (4, 90, 'Secretario General', 14, 'N', 'S', 73)
INSERT INTO #etapas_du288 VALUES (4, 100, 'VRAF', 23, 'N', 'S', 39)
INSERT INTO #etapas_du288 VALUES (4, 110, 'Director Legalidad', 16, 'N', 'S', 612)
INSERT INTO #etapas_du288 VALUES (4, 120, 'Contralor Universitario', 17, 'N', 'S', 68)
INSERT INTO #etapas_du288 VALUES (4, 130, 'Jefe Archivo Universitario', 18, 'S', 'S', 77)
INSERT INTO #etapas_du288 VALUES (5, 10, 'Solicitante', 6, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (5, 20, 'Jefe de Proyecto', 25, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (5, 30, 'Jefe Directo Funcionario', 26, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (5, 40, 'Director DGDP', 13, 'N', 'S', 50)
INSERT INTO #etapas_du288 VALUES (5, 50, 'Director Finanzas', 10, 'N', 'S', 41)
INSERT INTO #etapas_du288 VALUES (5, 60, 'Jefe Decretacion', 12, 'N', 'S', 449)
INSERT INTO #etapas_du288 VALUES (5, 70, 'Secretario General', 14, 'N', 'S', 73)
INSERT INTO #etapas_du288 VALUES (5, 80, 'VRAF', 23, 'N', 'S', 39)
INSERT INTO #etapas_du288 VALUES (5, 90, 'Director Legalidad', 16, 'N', 'S', 612)
INSERT INTO #etapas_du288 VALUES (5, 100, 'Contralor Universitario', 17, 'N', 'S', 68)
INSERT INTO #etapas_du288 VALUES (5, 110, 'Jefe Archivo Universitario', 18, 'S', 'S', 77)
INSERT INTO #etapas_du288 VALUES (6, 10, 'Solicitante', 6, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (6, 20, 'Jefe de Proyecto', 25, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (6, 30, 'Jefe Directo Funcionario', 26, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (6, 40, 'VRAC', 22, 'N', 'S', 17)
INSERT INTO #etapas_du288 VALUES (6, 50, 'Director DGDP', 13, 'N', 'S', 50)
INSERT INTO #etapas_du288 VALUES (6, 60, 'Director Finanzas', 10, 'N', 'S', 41)
INSERT INTO #etapas_du288 VALUES (6, 70, 'Jefe Decretacion', 12, 'N', 'S', 449)
INSERT INTO #etapas_du288 VALUES (6, 80, 'Secretario General', 14, 'N', 'S', 73)
INSERT INTO #etapas_du288 VALUES (6, 90, 'VRAF', 23, 'N', 'S', 39)
INSERT INTO #etapas_du288 VALUES (6, 100, 'Director Legalidad', 16, 'N', 'S', 612)
INSERT INTO #etapas_du288 VALUES (6, 110, 'Contralor Universitario', 17, 'N', 'S', 68)
INSERT INTO #etapas_du288 VALUES (6, 120, 'Jefe Archivo Universitario', 18, 'S', 'S', 77)
INSERT INTO #etapas_du288 VALUES (7, 10, 'Solicitante', 6, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (7, 20, 'Jefe de Proyecto', 25, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (7, 30, 'Jefe Directo Funcionario', 26, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (7, 40, 'VIPRE', 29, 'N', 'S', 704)
INSERT INTO #etapas_du288 VALUES (7, 50, 'Director DGDP', 13, 'N', 'S', 50)
INSERT INTO #etapas_du288 VALUES (7, 60, 'Director Finanzas', 10, 'N', 'S', 41)
INSERT INTO #etapas_du288 VALUES (7, 70, 'Jefe Decretacion', 12, 'N', 'S', 449)
INSERT INTO #etapas_du288 VALUES (7, 80, 'Secretario General', 14, 'N', 'S', 73)
INSERT INTO #etapas_du288 VALUES (7, 90, 'VRAF', 23, 'N', 'S', 39)
INSERT INTO #etapas_du288 VALUES (7, 100, 'Director Legalidad', 16, 'N', 'S', 612)
INSERT INTO #etapas_du288 VALUES (7, 110, 'Contralor Universitario', 17, 'N', 'S', 68)
INSERT INTO #etapas_du288 VALUES (7, 120, 'Jefe Archivo Universitario', 18, 'S', 'S', 77)
INSERT INTO #etapas_du288 VALUES (8, 10, 'Solicitante', 6, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (8, 20, 'Jefe de Proyecto', 25, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (8, 30, 'Jefe Directo Funcionario', 26, 'N', 'S', NULL)
INSERT INTO #etapas_du288 VALUES (8, 40, 'VRIP', 7, 'N', 'S', 299)
INSERT INTO #etapas_du288 VALUES (8, 50, 'Director DGDP', 13, 'N', 'S', 50)
INSERT INTO #etapas_du288 VALUES (8, 60, 'Director Finanzas', 10, 'N', 'S', 41)
INSERT INTO #etapas_du288 VALUES (8, 70, 'Jefe Decretacion', 12, 'N', 'S', 449)
INSERT INTO #etapas_du288 VALUES (8, 80, 'Secretario General', 14, 'N', 'S', 73)
INSERT INTO #etapas_du288 VALUES (8, 90, 'VRAF', 23, 'N', 'S', 39)
INSERT INTO #etapas_du288 VALUES (8, 100, 'Director Legalidad', 16, 'N', 'S', 612)
INSERT INTO #etapas_du288 VALUES (8, 110, 'Contralor Universitario', 17, 'N', 'S', 68)
INSERT INTO #etapas_du288 VALUES (8, 120, 'Jefe Archivo Universitario', 18, 'S', 'S', 77)
GO

UPDATE secgen_db.dbo.sg_eta1
SET des_etapa = x.des_etapa,
    cod_sistem = 'SG',
    cod_modulo = 'SISSOLIC',
    cod_perfil = x.cod_perfil,
    est_final = x.est_final,
    vigente = x.vigente,
    cod_organi = x.cod_organi
FROM secgen_db.dbo.sg_eta1 e, #etapas_du288 x
WHERE e.cod_flusol = x.cod_flusol
  AND e.cod_etapa = x.cod_etapa
GO

INSERT INTO secgen_db.dbo.sg_eta1
    (cod_flusol, cod_etapa, des_etapa, cod_sistem, cod_modulo,
     cod_perfil, est_final, vigente, cod_organi)
SELECT x.cod_flusol, x.cod_etapa, x.des_etapa, 'SG', 'SISSOLIC',
       x.cod_perfil, x.est_final, x.vigente, x.cod_organi
FROM #etapas_du288 x
WHERE NOT EXISTS (
    SELECT 1
    FROM secgen_db.dbo.sg_eta1 e
    WHERE e.cod_flusol = x.cod_flusol
      AND e.cod_etapa = x.cod_etapa
)
GO

DROP TABLE #etapas_du288
DROP TABLE #flujos_du288
GO

