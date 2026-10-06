use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
            where a.uid = b.uid
              and a.type = 'P'
              and b.name = 'Analisis2'
              and a.name = 'sg_epagsSecgen03')
    drop procedure Analisis2.sg_epagsSecgen03
go

/* Procedimiento : sg_epagsSecgen03

   Entrada :
   @rut_person          -> RUT del revisor DGDP. (Obligatorio)

   Objetivo : Listar las cuotas en visacion disponibles para el revisor DGDP.

   Creacion: ELA 2026/10/06
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_epagsSecgen03
    @rut_person char(9) = null
as

if @rut_person is null or ltrim(rtrim(@rut_person)) = ''
begin
    select 'Falta el RUT del revisor DGDP.' as msg
    return
end

select @rut_person = right('000000000' + ltrim(rtrim(@rut_person)), 9)

if not exists (
    select 1
    from sisper_db..sp_pers pers
    inner join sisper_db..sp_cont cont on cont.cod_ficha = pers.cod_ficha
    where pers.rut_person = @rut_person
      and cont.vigen_cont in ('0', '2')
      and cont.cod_calida <> '01'
      and isnull(cont.f_inicio_d, getdate()) <= getdate()
      and isnull(cont.f_termino, isnull(cont.f_termin_d, getdate())) >= getdate()
      and exists (
          select 1 from sisper_db.dbo.sp_orde orde
          where orde.cod_organi = 696
            and orde.rut_person = @rut_person
            and orde.vigente = 'S'
      )
)
begin
    select 'El usuario no tiene asignacion vigente para revisar cuotas DGDP.' as msg
    return
end

select
    fu.nro_solici,
    epag.id_funprse,
    epag.nro_cuota,
    epag.cod_estcuo,
    rtrim(isnull(ecuo.des_estcuo, '')) as des_estcuo,
    epag.rut_solici,
    epag.fec_solici,
    epag.id_evidenc,
    fu.rut as rut_funcionario,
    case when len(isnull(pers.nom_dest, '')) <= 1 then pers.nom_nombre else pers.nom_dest end as nom_nombre,
    pers.nom_appate,
    pers.nom_apmate,
    prse.actividad,
    prse.cod_unifin,
    prse.cod_ccto,
    rtrim(isnull(ccto.nom_ab_cct, '')) as nom_ab_cct,
    soli.nro_resolu,
    soli.ano_resolu,
    rslc.num_resolu as num_resolu_ext,
    fu.mto_total,
    fu.mto_tope,
    fu.cod_tpps,
    epag.ano_pago,
    epag.mes_pago,
    count(dpag.corr_fume) as cant_meses,
    isnull(sum(fume.mto_apagar), 0) as mto_cuota,
    min(fume.ano_prop * 100 + fume.mes_prop) as mes_prop_min,
    max(fume.ano_prop * 100 + fume.mes_prop) as mes_prop_max
from secgen_db.dbo.sg_epag epag
inner join secgen_db.dbo.sg_fups fu on fu.id_funprse = epag.id_funprse
inner join secgen_db.dbo.sg_prse prse on prse.nro_solici = fu.nro_solici
inner join secgen_db.dbo.sg_soli soli on soli.nro_solici = fu.nro_solici
left join secgen_db.dbo.sg_ecuo ecuo on ecuo.cod_estcuo = epag.cod_estcuo
left join secgen_db.dbo.sg_dpag dpag on dpag.id_funprse = epag.id_funprse and dpag.nro_cuota = epag.nro_cuota
left join secgen_db.dbo.sg_fume fume on fume.id_funprse = dpag.id_funprse and fume.corr_fume = dpag.corr_fume
left join sisper_db..sp_pers pers on pers.rut_person = fu.rut
left join fin21_db..es_ccto ccto on ccto.cod_ccto = prse.cod_ccto and ccto.cod_unifin = prse.cod_unifin
left join secgen_db.dbo.sg_rslc rslc on rslc.nro_resolu = soli.nro_resolu
where epag.cod_estcuo = 2
  and isnull(prse.cod_modprs, 1) = 2
  and soli.cod_estsol = 11
  and soli.nro_resolu is not null
group by fu.nro_solici, epag.id_funprse, epag.nro_cuota, epag.cod_estcuo,
    ecuo.des_estcuo, epag.rut_solici, epag.fec_solici, epag.id_evidenc,
    fu.rut, pers.nom_dest, pers.nom_nombre, pers.nom_appate, pers.nom_apmate,
    prse.actividad, prse.cod_unifin, prse.cod_ccto, ccto.nom_ab_cct,
    soli.nro_resolu, soli.ano_resolu, rslc.num_resolu, fu.mto_total,
    fu.mto_tope, fu.cod_tpps, epag.ano_pago, epag.mes_pago
order by epag.fec_solici, fu.nro_solici, epag.id_funprse, epag.nro_cuota
go

grant execute on Analisis2.sg_epagsSecgen03 to UsuaVrac
go
