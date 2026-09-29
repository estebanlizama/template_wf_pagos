use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_fupssSecgen17')
   drop procedure Analisis2.sg_fupssSecgen17

go

/* Procedimiento : sg_fupssSecgen17

   Entrada :
   @rut_person          -> RUT de la persona. (Opcional)
   @nro_solici_excluir  -> Parametro de entrada. (Opcional)

   Objetivo : Listar las prestaciones de servicio previas de un funcionario
              para apoyar la revision normativa de una solicitud.

   Creacion: ELA 2026/08/19
   Actualizacion: ELA 2026/09/25
*/
create procedure Analisis2.sg_fupssSecgen17
    @rut_person         char(9) = null,
    @nro_solici_excluir int     = null
as
begin
    if @rut_person is null or ltrim(rtrim(@rut_person)) = ''
    begin
        select 'Falta campo RUT del funcionario' as msg
        return
    end

    select
        fu.id_funprse,
        fu.nro_solici,
        prse.actividad,
        fu.motivo as motivo_funcionario,
        prse.per_desde,
        prse.per_hasta,
        fu.f_inicio,
        fu.f_termino,
        prse.cod_unifin,
        prse.cod_ccto,
        ccto.cod_ftfn,
        rtrim(isnull(ftfn.des_ftfn, '')) as des_ftfn,
        rtrim(isnull(ccto.nom_ab_cct, '')) as nom_ab_cct,
        fu.mto_total,
        fu.monto_mes,
        fu.tot_cuotas,
        fu.ext_cuotas,
        fu.cod_tpps,
        fu.periodos,
        fu.cod_sitm,
        fu.itm_global,
        fu.cod_cargo,
        rtrim(isnull(carg.nom_cargo, '')) as nom_cargo,
        fu.cod_estfun,
        rtrim(isnull(efun.des_estfun, '')) as des_estfun,
        fu.dentro_jor,
        fu.cod_contra,
        fu.mes_haber,
        fu.ano_haber,
        fu.mto_haber,
        fu.mto_tope,
        fu.f_cal_tope,
        soli.nro_resolu,
        soli.ano_resolu,
        soli.cod_estsol,
        rtrim(isnull(esol.des_estsol, '')) as des_estsol,
        soli.f_solicit,
        soli.ano_proces,
        prse.cod_etapa as cod_etapa_act,
        rtrim(isnull(etapaAct.des_etapa, '')) as des_etapa_act,
        rslc.num_resolu as num_resolu_ext,
        rslc.id_docum,

        fume.corr_fume,
        fume.ano_prop,
        fume.mes_prop,
        fume.cod_estfum,
        rtrim(isnull(efum.des_estfum, '')) as des_estfum,
        fume.ano_ejec,
        fume.mes_ejec,
        fume.mto_apagar,
        fume.mto_realpa,
        fume.mto_deslic,
        fume.mto_dessg,
        fume.id_evidenc,
        fume.val_licmed,
        fume.val_inabili,
        fume.val_singoce,
        fume.val_ciecc,
        fume.fec_valida,
        fume.rut_autori,
        fume.fec_autori,
        fume.fec_envrem,

        fuc2.fec_comrea,
        fuc2.hora_ini as hora_ini_comrea,
        fuc2.hora_ter as hora_ter_comrea,

        isnull(fuho.cant_horarios, 0) as cant_horarios,
        fuho.hora_ini_min as hora_ejec_ini,
        fuho.hora_ter_max as hora_ejec_ter,
        isnull(fuco.cant_compensa, 0) as cant_compensa_plan,
        fuco.fec_compro_min,
        fuco.fec_compro_max,
        fuco.hora_ini_min as hora_comp_ini,
        fuco.hora_ter_max as hora_comp_ter
    from secgen_db.dbo.sg_fups fu
    inner join secgen_db.dbo.sg_prse prse
        on prse.nro_solici = fu.nro_solici
    inner join secgen_db.dbo.sg_soli soli
        on soli.nro_solici = fu.nro_solici
    left join secgen_db.dbo.sg_esol esol
        on esol.cod_estsol = soli.cod_estsol
    left join fin21_db..es_ccto ccto
        on ccto.cod_ccto = prse.cod_ccto
       and ccto.cod_unifin = prse.cod_unifin
    left join fin21_db..sf_ftfn ftfn
        on ftfn.cod_ftfn = ccto.cod_ftfn
    left join sisper_db.dbo.sp_carg carg
        on carg.cod_cargo = fu.cod_cargo
    left join secgen_db.dbo.sg_efun efun
        on efun.cod_estfun = fu.cod_estfun
    left join secgen_db.dbo.sg_eta1 etapaAct
        on etapaAct.cod_flusol = prse.cod_flusol
       and etapaAct.cod_etapa = prse.cod_etapa
       and isnull(etapaAct.vigente, 'S') = 'S'
    left join secgen_db.dbo.sg_rslc rslc
        on rslc.nro_resolu = soli.nro_resolu
    left join secgen_db.dbo.sg_fume fume
        on fume.id_funprse = fu.id_funprse
    left join secgen_db.dbo.sg_efum efum
        on efum.cod_estfum = fume.cod_estfum
    left join secgen_db.dbo.sg_fuc2 fuc2
        on fuc2.id_funprse = fume.id_funprse
       and fuc2.corr_fume = fume.corr_fume
    left join (
        select
            id_funprse,
            count(*) as cant_horarios,
            min(hora_ini) as hora_ini_min,
            max(hora_ter) as hora_ter_max
        from secgen_db.dbo.sg_fuho
        group by id_funprse
    ) fuho
        on fuho.id_funprse = fu.id_funprse
    left join (
        select
            id_funprse,
            count(*) as cant_compensa,
            min(fec_compro) as fec_compro_min,
            max(fec_compro) as fec_compro_max,
            min(hora_ini) as hora_ini_min,
            max(hora_ter) as hora_ter_max
        from secgen_db.dbo.sg_fuco
        group by id_funprse
    ) fuco
        on fuco.id_funprse = fu.id_funprse
    where fu.rut = @rut_person
      and (@nro_solici_excluir is null or fu.nro_solici <> @nro_solici_excluir)
      and soli.cod_estsol not in (4)
    order by soli.f_solicit desc, fu.id_funprse, fume.ano_prop, fume.mes_prop, fuc2.fec_comrea
end
go

grant execute on Analisis2.sg_fupssSecgen17 to UsuaVrac
go
