/*
===============================================================================
sg_ecuo - ESTADOS DEL ENCABEZADO DE LA SOLICITUD DE PAGO
Motor : Sybase ASE 12.5
Tabla que lo usa: sg_epag.cod_estcuo

sg_epag es la cabecera de la solicitud de pago: lleva el ciclo de trabajo
completo y la trazabilidad (quien la creo, cuando la envio, quien la reviso,
como termino).

Se CONSERVAN los codigos actuales -- no se renumera. Solo se quitan los que
salen de alcance, igual que sg_esol conserva los suyos y agrega al final
(S0-004).

  ESTADOS VIGENTES
     1  Propuesta               borrador. No compromete cupo ni saldo y es
                                eliminable mientras nunca se haya enviado.
     6  Solicitada pago         ENVIAR. Nace el flujo formal y se consume
                                cupo y saldo.
     2  En visacion             DGDP la tomo de la bandeja comun.
     3  Observada               DGDP la devolvio a correccion. NO libera nada.
     4  Aprobada                validaciones conformes y descuentos revisados.
     8  Enviada remuneraciones  se registro en Finanzas. TERMINAL, sin acuse.
    10  Rechazada               TERMINAL. Libera cupo, saldo y meses: los
                                meses de esa cuota vuelven a sg_efum = 1.

  ESTADOS QUE SE QUITAN
     5  Disponible pago      derivado por fecha, no se persiste
     7  Autorizada pago      era el acto de Finanzas; DGDP aprueba (4) y
                             envia (8), no hay acto intermedio
     9  Pagada               el pago ocurre fuera; SecGen no se entera
    11  Devuelta Finanzas    no hay retorno desde Finanzas
    12  Bloqueada            el bloqueo es del mes (sg_efum = 5), no del
                             encabezado
===============================================================================
*/

USE secgen_db
GO

SET NOCOUNT ON
GO

/* --- 1. Quitar los estados fuera de alcance ------------------------------ */

/* IMPORTANTE: mientras sg_fume.cod_estcuo siga existiendo, TAMBIEN apunta a
   sg_ecuo. Si alguna fila de sg_fume usa uno de los codigos a borrar, el
   DELETE falla por la FK. Por eso este script se ejecuta DESPUES de
   03_migracion_sg_fume.sql y del DROP de sg_fume.cod_estcuo. El guard
   verifica las dos tablas para fallar con un mensaje claro en vez de con un
   error de integridad. */

IF EXISTS (SELECT 1 FROM secgen_db.dbo.sg_epag
            WHERE cod_estcuo IN (5, 7, 9, 11, 12))
    SELECT 'Aviso: hay encabezados (sg_epag) usando estados fuera de alcance. Migrelos primero.' AS msg
ELSE IF EXISTS (SELECT 1 FROM syscolumns c, sysobjects o
                 WHERE o.name = 'sg_fume' AND c.id = o.id
                   AND c.name = 'cod_estcuo')
    SELECT 'Aviso: sg_fume todavia tiene cod_estcuo. Ejecute 03_migracion_sg_fume.sql y elimine esa columna antes de depurar sg_ecuo.' AS msg
ELSE
BEGIN
    DELETE FROM secgen_db.dbo.sg_ecuo WHERE cod_estcuo IN (5, 7, 9, 11, 12)
    SELECT 'sg_ecuo depurado' AS msg
END
GO

/* --- 2. Asegurar los 7 vigentes ------------------------------------------ */

CREATE TABLE #ecuo (
    cod_estcuo tinyint     NOT NULL,
    des_estcuo varchar(60) NOT NULL
)
GO

INSERT INTO #ecuo VALUES ( 1, 'Propuesta')
INSERT INTO #ecuo VALUES ( 2, 'En visación')
INSERT INTO #ecuo VALUES ( 3, 'Observada')
INSERT INTO #ecuo VALUES ( 4, 'Aprobada')
INSERT INTO #ecuo VALUES ( 6, 'Solicitada pago')
INSERT INTO #ecuo VALUES ( 8, 'Enviada remuneraciones')
INSERT INTO #ecuo VALUES (10, 'Rechazada')
GO

UPDATE secgen_db.dbo.sg_ecuo
SET des_estcuo = x.des_estcuo
FROM secgen_db.dbo.sg_ecuo e, #ecuo x
WHERE e.cod_estcuo = x.cod_estcuo
GO

INSERT INTO secgen_db.dbo.sg_ecuo (cod_estcuo, des_estcuo)
SELECT x.cod_estcuo, x.des_estcuo
FROM #ecuo x
WHERE NOT EXISTS (
    SELECT 1 FROM secgen_db.dbo.sg_ecuo e WHERE e.cod_estcuo = x.cod_estcuo
)
GO

DROP TABLE #ecuo
GO

/* --- 3. Verificacion ----------------------------------------------------- */

SELECT cod_estcuo, des_estcuo
FROM secgen_db.dbo.sg_ecuo
ORDER BY cod_estcuo
GO
