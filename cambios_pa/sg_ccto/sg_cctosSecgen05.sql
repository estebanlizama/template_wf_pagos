use secgen_db
go

if exists (select 1
             from sysobjects a, sysusers b
            where a.uid = b.uid
              and a.type = 'P'
              and b.name = 'Analisis2'
              and a.name = 'sg_cctosSecgen05')
begin
    drop procedure Analisis2.sg_cctosSecgen05
end
go

/* Procedimiento : sg_cctosSecgen05

   Entrada :
   @rut                 -> RUT del usuario. (Opcional)
   @id_modprse          -> Modalidad de prestacion de servicios: 1 legacy,
                           2 DU288. (Opcional)

   Objetivo : Obtener lista de centros de costo disponibles para un rut

   Creacion: ELA 2026/08/24
   Actualizacion: ELA 2026/10/16
*/

create procedure Analisis2.sg_cctosSecgen05
    @rut        char(9)  = NULL,
    @id_modprse tinyint  = 1
as
begin
    if @rut is null
    begin
        select 'Falta el rut. Se aborta el procedimiento' as msg
        return
    end

    /* INTERRUPTOR-DU09 : punto 6, el unico fuera de sg_epag.

       CRITERIO DU288 -- interruptor de dos lineas que se cambian juntas.

       Conviven dos definiciones de "centro de costo afecto a DU288":

         cod_tfinan in (21, 44)  deducida del tipo de financiamiento.
         afec_du9 = 'S'          marca explicita del centro de costo.

       La marca explicita es la definitiva, pero hoy fin21_db..es_ccto la
       tiene nula en todos los centros vigentes. Con el filtro por afec_du9
       activo el PA devuelve cero filas para cualquier rut, sin error y en
       milisegundos, y eso apaga el flujo completo: de este PA se deriva el
       privilegio provision-payment-manage, asi que sin filas no aparece el
       menu de prestaciones por pagar, no se consulta la bandeja de gestion
       de pago y el formulario de solicitud no ofrece ningun centro de costo.

       Por eso queda activo el criterio por tipo de financiamiento y
       comentado el de la marca. Al instalar en produccion, donde afec_du9
       ya esta poblada, se invierten los dos pares rotulados CRITERIO DU288.

       Se enciende junto con los puntos 3 a 5 del interruptor, los tres PA
       de sg_epag: la misma columna vacia que bloquea crear una cuota deja
       sin privilegio al jefe de proyecto, y encender uno sin el otro deja
       el flujo a medias. Ver INTERRUPTOR-DU09.md y, antes de encenderlos,
       datos_base/06_marcas_du09_centro_costo.sql.

       Los dos juntos, no uno. Cambiar solo el where deja el indicador
       ind_financiamiento_du288 en 'N' para filas que el PA si devolvio, y la
       validacion normativa del formulario las rechaza por financiamiento
       incompatible. Cambiar solo el indicador deja entrar centros que no
       son DU288. */

    if @id_modprse = 2
    begin
        select
            ccto.cod_ccto,
            ccto.cod_unifin,
            ccto.cod_tfinan,
            ccto.cod_ftfn,
            ftfn.des_ftfn as fuente_financiamiento,
            ccto.cod_tcsald,
            ccto.f_creacion,
            ccto.nom_ccto,
            ccto.nom_ab_cct,
            ccto.cc_global,
            ccto.pry_global,
            ecct.rut as rut_person,
            ecct.rut as rut_jefe_proyecto,
            pers.nom_nombre,
            pers.nom_appate,
            pers.nom_apmate,
            (pers.nom_nombre + ' ' + pers.nom_appate + ' ' + pers.nom_apmate) as nombre_jefe_proyecto,
            tfin.des_tfinan as tipo_financiamiento,
            ufin.des_unifin as unidad_ejecutora,
            deaf.des_decafe as decreto_descripcion,
            ccto.decr_afect,
            ccto.vigente as vigente_ccto,
            ecct.vigente as vigente_responsable,
            ccto.afec_du9,
            ccto.con_topdu9,
            /* INTERRUPTOR-DU09 : CRITERIO DU288 (1 de 2) -- indicador */
            case when ccto.cod_tfinan in (21, 44) then 'S' else 'N' end as ind_financiamiento_du288,
         /* case when isnull(ccto.afec_du9, 'N') = 'S' then 'S' else 'N' end as ind_financiamiento_du288, */
            case when isnull(ccto.con_topdu9, 'S') = 'N' then 'S' else 'N' end as ind_anid,
            case when ccto.decr_afect is null then 'N' else 'S' end as ind_decreto_afecto,
            case when ccto.decr_afect = '1' then 'S' else 'N' end as ind_formacion_continua
        from fin21_db..es_ccto ccto
        inner join fin21_db..es_ecct ecct
                on ecct.cod_ccto = ccto.cod_ccto
               and ecct.cod_unifin = ccto.cod_unifin
        inner join fin21_db..es_tfin tfin
                on tfin.cod_tfinan = ccto.cod_tfinan
        inner join fin21_db..es_ufin ufin
                on ufin.cod_unifin = ccto.cod_unifin
        left join fin21_db..sf_ftfn ftfn
               on ftfn.cod_ftfn = ccto.cod_ftfn
        left join fin21_db..sf_deaf deaf
               on deaf.decr_afect = ccto.decr_afect
        left join sisper_db..sp_pers pers
               on pers.rut_person = ecct.rut
        where ecct.rut = @rut
          and ecct.vigente = 'S'
          and ccto.vigente = '1'
          /* INTERRUPTOR-DU09 : CRITERIO DU288 (2 de 2) -- filtro */
          and ccto.cod_tfinan in (21, 44)
       /* and ccto.afec_du9 = 'S' */
    end
    else
    begin
        declare @unidad_mayor char(8)

        select
            @unidad_mayor = substring(uni.cod_unidad, 1, 2) + '000000'
        from sisper_db..sp_pers pers
        inner join ufro_db..es_unid uni
                on uni.cod_unidad = pers.u_original
        where pers.rut_person = @rut
          and uni.vigente = 'S'

        select
            pers.rut_person,
            ccto.cod_ccto,
            ccto.cod_unifin,
            ccto.cod_tfinan,
            ccto.cod_ftfn,
            ftfn.des_ftfn as fuente_financiamiento,
            ccto.cod_tcsald,
            ccto.f_creacion,
            ecct.rut,
            ccto.nom_ccto,
            ccto.nom_ab_cct,
            pers.nom_nombre,
            pers.nom_appate,
            pers.nom_apmate
        from fin21_db..es_ccto ccto
        left join fin21_db..es_ecct ecct
               on ecct.cod_ccto = ccto.cod_ccto
              and ecct.cod_unifin = ccto.cod_unifin
        left join fin21_db..sf_ftfn ftfn
               on ftfn.cod_ftfn = ccto.cod_ftfn
        left join sisper_db..sp_pers pers
               on ecct.rut = pers.rut_person
        left join ufro_db..es_unid uni
               on uni.cod_unidad = pers.u_original
        where uni.cod_unidad like left(@unidad_mayor, 2) + '%'
          and ecct.vigente = 'S'
    end
end
go

grant execute on Analisis2.sg_cctosSecgen05 to UsuaVrac
go
