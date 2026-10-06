USE secgen_db
GO

IF EXISTS (
    SELECT 1 FROM sysobjects a, sysusers b
    WHERE a.uid = b.uid AND a.type = 'P'
      AND b.name = 'Analisis2' AND a.name = 'sg_usacsSecgen01'
)
    DROP PROCEDURE Analisis2.sg_usacsSecgen01
GO

/* Procedimiento : Analisis2.sg_usacsSecgen01

   Entrada :
   @rut                 -> RUT del funcionario. (Opcional)
   @cod_sistem          -> Codigo del sistema. (Opcional)
   @cod_modulo          -> Codigo del modulo. (Opcional)
   @fecha_eval          -> Fecha de evaluacion. (Opcional)

   Objetivo : Obtener perfiles y privilegios dinamicos de acceso a PDS.

   Creacion: ELA 2026/08/24
   Actualizacion: Sin registro
*/
CREATE PROCEDURE Analisis2.sg_usacsSecgen01
    @rut         char(9) = NULL,
    @cod_sistem  char(2) = 'SG',
    @cod_modulo  varchar(8) = 'SISSOLIC',
    @fecha_eval  datetime = NULL
AS
BEGIN
    DECLARE @fecha_val datetime
    SELECT @fecha_val = isnull(@fecha_eval, getdate())

    IF @rut IS NULL OR ltrim(rtrim(@rut)) = ''
    BEGIN
        SELECT
            convert(char(9), NULL) AS rut,
            convert(char(2), NULL) AS cod_sistem,
            convert(varchar(8), NULL) AS cod_modulo,
            convert(smallint, NULL) AS cod_perfil,
            convert(varchar(100), NULL) AS des_perfil,
            convert(smallint, NULL) AS cod_privil,
            convert(varchar(100), NULL) AS des_privil,
            convert(varchar(100), NULL) AS nom_privil,
            convert(char(1), 'N') AS elegible_solicitante,
            convert(char(1), 'N') AS tiene_tarea_pendiente,
            convert(char(1), 'N') AS es_revisor_pago,
            convert(varchar(100), 'Falta RUT del usuario') AS mensaje
        RETURN
    END

    CREATE TABLE #perfiles (
        cod_perfil smallint not null,
        origen varchar(10) not null
    )

    IF EXISTS (
        SELECT 1
        FROM sisper_db..sp_pers pers
        INNER JOIN sisper_db..sp_cont cont
            ON cont.cod_ficha = pers.cod_ficha
        WHERE pers.rut_person = @rut
          AND cont.vigen_cont in ('0', '2')
          AND cont.cod_calida <> '01'
          AND isnull(cont.f_inicio_d, @fecha_val) <= @fecha_val
          AND isnull(cont.f_termino, isnull(cont.f_termin_d, @fecha_val)) >= @fecha_val
    )
    BEGIN
        INSERT INTO #perfiles (cod_perfil, origen)
        VALUES (6, 'CONTRATO')
    END

    /* El rol revisor usa cod_organi 696 en sp_orde, RUT autenticado y
       contrato activo. No es cod_design ni usa eta/apso. */
    IF EXISTS (
        SELECT 1
        FROM sisper_db..sp_pers pers
        INNER JOIN sisper_db..sp_cont cont ON cont.cod_ficha = pers.cod_ficha
        WHERE pers.rut_person = @rut
          AND cont.vigen_cont in ('0', '2')
          AND cont.cod_calida <> '01'
          AND isnull(cont.f_inicio_d, @fecha_val) <= @fecha_val
          AND isnull(cont.f_termino, isnull(cont.f_termin_d, @fecha_val)) >= @fecha_val
          AND EXISTS (
              SELECT 1 FROM sisper_db.dbo.sp_orde orde
              WHERE orde.cod_organi = 696
                AND orde.rut_person = @rut
                AND orde.vigente = 'S'
          )
    )
    BEGIN
        INSERT INTO #perfiles (cod_perfil, origen)
        SELECT 33, 'PAGO_DGDP'
        WHERE NOT EXISTS (SELECT 1 FROM #perfiles WHERE cod_perfil = 33)
    END

    INSERT INTO #perfiles (cod_perfil, origen)
    SELECT DISTINCT eta.cod_perfil, 'TAREA'
    FROM secgen_db..sg_apso apso
    INNER JOIN secgen_db..sg_prse prse
        ON prse.nro_solici = apso.nro_solici
       AND prse.cod_flusol = apso.cod_flusol
       AND prse.cod_etapa = apso.cod_etapa
    INNER JOIN secgen_db..sg_eta1 eta
        ON eta.cod_flusol = apso.cod_flusol
       AND eta.cod_etapa = apso.cod_etapa
    WHERE apso.cod_estapr = 4
      AND apso.rut_usua = @rut
      AND isnull(eta.vigente, 'S') = 'S'
      AND NOT EXISTS (
          SELECT 1
          FROM #perfiles p
          WHERE p.cod_perfil = eta.cod_perfil
      )

    SELECT
        @rut AS rut,
        per.cod_sistem,
        per.cod_modulo,
        per.cod_perfil,
        per.des_perfil,
        pri.cod_privil,
        pri.des_privil,
        pri.nom_privil,
        CASE
            WHEN EXISTS (
                SELECT 1 FROM #perfiles p
                WHERE p.cod_perfil = 6 AND p.origen = 'CONTRATO'
            ) THEN 'S'
            ELSE 'N'
        END AS elegible_solicitante,
        CASE
            WHEN EXISTS (
                SELECT 1 FROM #perfiles p
                WHERE p.origen = 'TAREA'
            ) THEN 'S'
            ELSE 'N'
        END AS tiene_tarea_pendiente,
        CASE
            WHEN EXISTS (
                SELECT 1 FROM #perfiles p
                WHERE p.cod_perfil = 33 AND p.origen = 'PAGO_DGDP'
            ) THEN 'S'
            ELSE 'N'
        END AS es_revisor_pago,
        convert(varchar(100), NULL) AS mensaje
    FROM #perfiles ctx
    INNER JOIN sistema_db..bd_per1 per
        ON per.cod_sistem = @cod_sistem
       AND per.cod_modulo = @cod_modulo
       AND per.cod_perfil = ctx.cod_perfil
    LEFT JOIN sistema_db..bd_pepr pep
        ON pep.cod_sistem = per.cod_sistem
       AND pep.cod_modulo = per.cod_modulo
       AND pep.cod_perfil = per.cod_perfil
    LEFT JOIN sistema_db..bd_prvg pri
        ON pri.cod_sistem = pep.cod_sistem
       AND pri.cod_modulo = pep.cod_modulo
       AND pri.cod_privil = pep.cod_privil
    ORDER BY per.cod_perfil, pri.cod_privil

    DROP TABLE #perfiles
END
GO

GRANT EXECUTE ON Analisis2.sg_usacsSecgen01 TO UsuaVrac
GO
