/*
===============================================================================
DU288 - CATALOGOS Y ESTADOS SECGEN PARA CERTIFICACION
Motor : Sybase ASE 12.5

Contiene exclusivamente maestros SECGEN requeridos por la solicitud DU288.
Actualiza los codigos existentes e inserta los faltantes. Conserva todos los
IDs definidos; no agrega estados de cuotas ni catalogos de otros modulos.
===============================================================================
*/

USE secgen_db
GO

SET NOCOUNT ON
GO

/* -------------------------------------------------------------------------
   1. TIPO Y MODALIDAD DE SOLICITUD DU288
   ------------------------------------------------------------------------- */

UPDATE secgen_db.dbo.sg_tsol
SET des_tipsol = 'Prestación de Servicios', nro_orden = 1, vigente = 'S'
WHERE cod_tipsol = 1

IF @@rowcount = 0
    INSERT INTO secgen_db.dbo.sg_tsol
        (cod_tipsol, des_tipsol, nro_orden, vigente)
    VALUES (1, 'Prestación de Servicios', 1, 'S')
GO

UPDATE secgen_db.dbo.sg_tmod
SET des_modprs = 'DU288-D09/2026'
WHERE cod_modprs = 2

IF @@rowcount = 0
    INSERT INTO secgen_db.dbo.sg_tmod (cod_modprs, des_modprs)
    VALUES (2, 'DU288-D09/2026')
GO

/* -------------------------------------------------------------------------
   2. PERIODICIDAD DE LA PRESTACION
   ------------------------------------------------------------------------- */

CREATE TABLE #tpps_du288 (
    cod_tpps int NOT NULL,
    des_tpps varchar(10) NOT NULL
)

-- DU288: cod_tpps se usa como señal de tipo de monto -- 1 = pago fijo
-- (mensual, parejo entre los meses de ejecucion), 2 = pago variable
-- (diario, el monto real de cada mes se define recien al pago).
INSERT INTO #tpps_du288 VALUES (1, 'Fijo')
INSERT INTO #tpps_du288 VALUES (2, 'Variable')
GO

UPDATE secgen_db.dbo.sg_tpps
SET des_tpps = x.des_tpps
FROM secgen_db.dbo.sg_tpps t, #tpps_du288 x
WHERE t.cod_tpps = x.cod_tpps
GO

INSERT INTO secgen_db.dbo.sg_tpps (cod_tpps, des_tpps)
SELECT x.cod_tpps, x.des_tpps
FROM #tpps_du288 x
WHERE NOT EXISTS (
    SELECT 1 FROM secgen_db.dbo.sg_tpps t
    WHERE t.cod_tpps = x.cod_tpps
)
GO

/* -------------------------------------------------------------------------
   3. ESTADOS GENERALES DE SOLICITUD
   ------------------------------------------------------------------------- */

CREATE TABLE #esol_du288 (
    cod_estsol tinyint NOT NULL,
    des_estsol varchar(30) NOT NULL
)

INSERT INTO #esol_du288 VALUES (1,  'En proceso')
INSERT INTO #esol_du288 VALUES (2,  'En revisión')
INSERT INTO #esol_du288 VALUES (3,  'Aprobada')
INSERT INTO #esol_du288 VALUES (4,  'Rechazada')
INSERT INTO #esol_du288 VALUES (5,  'Borrador')
INSERT INTO #esol_du288 VALUES (6,  'Devuelto a correción')
INSERT INTO #esol_du288 VALUES (7,  'Enviada a firma')
INSERT INTO #esol_du288 VALUES (8,  'Resolución Firmada')
INSERT INTO #esol_du288 VALUES (9,  'Resolución Ingresada')
INSERT INTO #esol_du288 VALUES (10, 'Resolución Pre-Ingresada')
INSERT INTO #esol_du288 VALUES (11, 'Resolución Archivada')
GO

UPDATE secgen_db.dbo.sg_esol
SET des_estsol = x.des_estsol
FROM secgen_db.dbo.sg_esol e, #esol_du288 x
WHERE e.cod_estsol = x.cod_estsol
GO

INSERT INTO secgen_db.dbo.sg_esol (cod_estsol, des_estsol)
SELECT x.cod_estsol, x.des_estsol
FROM #esol_du288 x
WHERE NOT EXISTS (
    SELECT 1 FROM secgen_db.dbo.sg_esol e
    WHERE e.cod_estsol = x.cod_estsol
)
GO

/* -------------------------------------------------------------------------
   4. ESTADOS DE TAREA, APROBACION Y FIRMA
   ------------------------------------------------------------------------- */

CREATE TABLE #eapr_du288 (
    cod_estapr tinyint NOT NULL,
    des_estapr varchar(30) NOT NULL
)

INSERT INTO #eapr_du288 VALUES (1,  'APROBADO')
INSERT INTO #eapr_du288 VALUES (2,  'RECHAZADO')
INSERT INTO #eapr_du288 VALUES (3,  'DEVOLVER A CORRECCIÓN')
INSERT INTO #eapr_du288 VALUES (4,  'PENDIENTE')
INSERT INTO #eapr_du288 VALUES (5,  'ESPERANDO ASIGNACIÓN')
INSERT INTO #eapr_du288 VALUES (6,  'ENVIADO A FIRMA')
INSERT INTO #eapr_du288 VALUES (7,  'ARCHIVADA')
INSERT INTO #eapr_du288 VALUES (8,  'PRE-INGRESADA')
INSERT INTO #eapr_du288 VALUES (9,  'INGRESADA')
INSERT INTO #eapr_du288 VALUES (10, 'POR FIRMAR')
INSERT INTO #eapr_du288 VALUES (11, 'CANCELADA POR CIERRE ETAPA')
GO

UPDATE secgen_db.dbo.sg_eapr
SET des_estapr = x.des_estapr
FROM secgen_db.dbo.sg_eapr e, #eapr_du288 x
WHERE e.cod_estapr = x.cod_estapr
GO

INSERT INTO secgen_db.dbo.sg_eapr (cod_estapr, des_estapr)
SELECT x.cod_estapr, x.des_estapr
FROM #eapr_du288 x
WHERE NOT EXISTS (
    SELECT 1 FROM secgen_db.dbo.sg_eapr e
    WHERE e.cod_estapr = x.cod_estapr
)
GO

/* -------------------------------------------------------------------------
   5. ESTADOS INDIVIDUALES DEL FUNCIONARIO EN LA PDS
   ------------------------------------------------------------------------- */

CREATE TABLE #efun_du288 (
    cod_estfun tinyint NOT NULL,
    des_estfun varchar(60) NOT NULL
)

INSERT INTO #efun_du288 VALUES (1, 'Pendiente de revisión')
INSERT INTO #efun_du288 VALUES (2, 'Observado')
INSERT INTO #efun_du288 VALUES (3, 'Aprobado')
INSERT INTO #efun_du288 VALUES (4, 'Rechazado')
INSERT INTO #efun_du288 VALUES (5, 'Excluido')
GO

UPDATE secgen_db.dbo.sg_efun
SET des_estfun = x.des_estfun
FROM secgen_db.dbo.sg_efun e, #efun_du288 x
WHERE e.cod_estfun = x.cod_estfun
GO

INSERT INTO secgen_db.dbo.sg_efun (cod_estfun, des_estfun)
SELECT x.cod_estfun, x.des_estfun
FROM #efun_du288 x
WHERE NOT EXISTS (
    SELECT 1 FROM secgen_db.dbo.sg_efun e
    WHERE e.cod_estfun = x.cod_estfun
)
GO

/* -------------------------------------------------------------------------
   6. ESTADOS DE RESOLUCION
   El codigo 4 no se crea porque no existe en el catalogo vigente definido.
   ------------------------------------------------------------------------- */

CREATE TABLE #ersl_du288 (
    cod_estres tinyint NOT NULL,
    des_estres varchar(100) NOT NULL
)

INSERT INTO #ersl_du288 VALUES (1,  'En proceso')
INSERT INTO #ersl_du288 VALUES (2,  'En revision')
INSERT INTO #ersl_du288 VALUES (3,  'Archivado')
INSERT INTO #ersl_du288 VALUES (5,  'Enviada a firma')
INSERT INTO #ersl_du288 VALUES (6,  'Devuelta a corrección')
INSERT INTO #ersl_du288 VALUES (7,  'PRE-INGRESADA')
INSERT INTO #ersl_du288 VALUES (8,  'INGRESADA')
INSERT INTO #ersl_du288 VALUES (9,  'APROBADA')
INSERT INTO #ersl_du288 VALUES (10, 'RECHAZADA')
INSERT INTO #ersl_du288 VALUES (11, 'Resolución Archivada')
INSERT INTO #ersl_du288 VALUES (12, 'Resolución Ingresada')
GO

UPDATE secgen_db.dbo.sg_ersl
SET des_estres = x.des_estres
FROM secgen_db.dbo.sg_ersl e, #ersl_du288 x
WHERE e.cod_estres = x.cod_estres
GO

INSERT INTO secgen_db.dbo.sg_ersl (cod_estres, des_estres)
SELECT x.cod_estres, x.des_estres
FROM #ersl_du288 x
WHERE NOT EXISTS (
    SELECT 1 FROM secgen_db.dbo.sg_ersl e
    WHERE e.cod_estres = x.cod_estres
)
GO

/* -------------------------------------------------------------------------
   7. ACCIONES DE WORKFLOW E HISTORIAL UTILIZADAS POR DU288
   ------------------------------------------------------------------------- */

CREATE TABLE #tacc_du288 (
    id_tipacc tinyint NOT NULL,
    des_accion varchar(50) NOT NULL
)

INSERT INTO #tacc_du288 VALUES (1,  'Creó la solicitud')
INSERT INTO #tacc_du288 VALUES (2,  'Aprobó solicitud')
INSERT INTO #tacc_du288 VALUES (3,  'Rechazó solicitud')
INSERT INTO #tacc_du288 VALUES (4,  'Devolvió a corrección la solicitud')
INSERT INTO #tacc_du288 VALUES (5,  'Creó la resolución')
INSERT INTO #tacc_du288 VALUES (6,  'Editó la resolución')
INSERT INTO #tacc_du288 VALUES (7,  'Envió a firma la resolución')
INSERT INTO #tacc_du288 VALUES (8,  'Devolvió a corrección la resolución')
INSERT INTO #tacc_du288 VALUES (9,  'Rechazó la resolución')
INSERT INTO #tacc_du288 VALUES (10, 'Cargó la firma a la resolución')
INSERT INTO #tacc_du288 VALUES (11, 'Firmó la resolución')
INSERT INTO #tacc_du288 VALUES (12, 'Firmó con alcance la resolución')
INSERT INTO #tacc_du288 VALUES (13, 'Archivó la resolución')
INSERT INTO #tacc_du288 VALUES (14, 'Marcó como ingresada la resolución')
INSERT INTO #tacc_du288 VALUES (15, 'Editó la solicitud')
INSERT INTO #tacc_du288 VALUES (28, 'Corrigió la solicitud')
INSERT INTO #tacc_du288 VALUES (29, 'Creó Borrador de la Solicitud')
GO

UPDATE secgen_db.dbo.sg_tacc
SET des_accion = x.des_accion
FROM secgen_db.dbo.sg_tacc a, #tacc_du288 x
WHERE a.id_tipacc = x.id_tipacc
GO

INSERT INTO secgen_db.dbo.sg_tacc (id_tipacc, des_accion)
SELECT x.id_tipacc, x.des_accion
FROM #tacc_du288 x
WHERE NOT EXISTS (
    SELECT 1 FROM secgen_db.dbo.sg_tacc a
    WHERE a.id_tipacc = x.id_tipacc
)
GO

DROP TABLE #tacc_du288
DROP TABLE #ersl_du288
DROP TABLE #efun_du288
DROP TABLE #eapr_du288
DROP TABLE #esol_du288
DROP TABLE #tpps_du288
GO
