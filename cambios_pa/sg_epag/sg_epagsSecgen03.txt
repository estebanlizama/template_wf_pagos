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
   @cod_estcuo          -> Estado de cuota a listar. 0 lista todas las
                           enviadas. Sin valor lista las que estan en
                           visacion. (Opcional)

   Objetivo : Listar las cuotas enviadas por el jefe de proyecto que la
   revision DGDP puede ver, con sus montos, descuentos informados, meses
   cubiertos y compensaciones registradas. mto_rechazado permite que el
   saldo que ve DGDP descuente lo que un rechazo dejo bloqueado.

   Creacion: ELA 2026/10/06
   Actualizacion: ELA 2026/10/27
   Actualizacion: ELA 2026/10/30 - Devuelve el item presupuestario de la
   solicitud y su subitem vigente. La bandeja ya tenia unido sg_fups sin
   devolver cod_sitm, que va en el archivo de Finanzas y en la asignacion de
   SISPER. Ese codigo es el item ANTIGUO de tres (306) y ss_ccas.cod_item
   espera el subitem vigente de cinco (30600): pt_sitm conserva el antiguo en
   item_antig, asi que la relacion es directa y no pasa por el centro de
   costo: 300 -> 30000, 303 -> 30300, 306 -> 30600. Se devuelve la cuenta de
   subitems vigentes y el menor de ellos: con uno solo la resolucion es
   inequivoca, y con varios quien lee decide, porque elegir entre ellos no le
   toca al sistema.
*/
create procedure Analisis2.sg_epagsSecgen03
    @rut_person char(9)  = null,
    @cod_estcuo tinyint  = null
as

if @rut_person is null or ltrim(rtrim(@rut_person)) = ''
begin
    select 'Falta el RUT del revisor DGDP.' as msg
    return
end

if @cod_estcuo is not null and @cod_estcuo not in (0, 2, 3, 4, 8, 10, 11)
begin
    select 'El estado de cuota solicitado no corresponde a la bandeja DGDP.' as msg
    return
end

if @cod_estcuo is null
    select @cod_estcuo = 2

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
    datediff(dd, epag.fec_solici, getdate()) as dias_espera,
    epag.id_evidenc,
    fu.rut as rut_funcionario,
    case when len(isnull(pers.nom_dest, '')) <= 1 then pers.nom_nombre else pers.nom_dest end as nom_nombre,
    pers.nom_appate,
    pers.nom_apmate,
    prse.actividad,
    prse.cod_unifin,
    prse.cod_ccto,
    rtrim(isnull(ccto.nom_ab_cct, '')) as nom_ab_cct,
    ccto.afec_du9,
    ccto.con_topdu9,
    soli.nro_resolu,
    soli.ano_resolu,
    rslc.num_resolu as num_resolu_ext,
    fu.mto_total,
    fu.mto_tope,
    fu.tot_cuotas,
    fu.ext_cuotas,
    fu.cod_tpps,
    fu.cod_sitm,
    (select count(distinct si.cod_sitm)
       from fin21_db..pt_sitm si
      where convert(varchar(5), si.item_antig) = ltrim(rtrim(isnull(fu.cod_sitm, '')))
        and si.vigencia = '1') as cant_subitm,
    (select min(si.cod_sitm)
       from fin21_db..pt_sitm si
      where convert(varchar(5), si.item_antig) = ltrim(rtrim(isnull(fu.cod_sitm, '')))
        and si.vigencia = '1') as cod_subitm,
    epag.ano_pago,
    epag.mes_pago,
    count(dpag.corr_fume) as cant_meses,
    isnull(sum(fume.mto_apagar), 0) as mto_cuota,
    isnull(sum(fume.mto_deslic), 0) as mto_deslic,
    isnull(sum(fume.mto_dessg), 0) as mto_dessg,
    min(fume.ano_prop * 100 + fume.mes_prop) as mes_prop_min,
    max(fume.ano_prop * 100 + fume.mes_prop) as mes_prop_max,
    (select count(*)
       from secgen_db.dbo.sg_dpag d2,
            secgen_db.dbo.sg_fuc2 c2
      where d2.id_funprse = epag.id_funprse
        and d2.nro_cuota  = epag.nro_cuota
        and c2.id_funprse = d2.id_funprse
        and c2.corr_fume  = d2.corr_fume) as cant_compens,
    (select isnull(sum(f4.mto_realpa), 0)
       from secgen_db.dbo.sg_fume f4
      where f4.id_funprse = epag.id_funprse
        and f4.cod_estfum = 3) as mto_pagado,
    (select isnull(sum(f5.mto_apagar), 0)
       from secgen_db.dbo.sg_fume f5
      where f5.id_funprse = epag.id_funprse
        and f5.cod_estfum = 2) as mto_gestion,
    (select isnull(sum(f6.mto_apagar), 0)
       from secgen_db.dbo.sg_fume f6
      where f6.id_funprse = epag.id_funprse
        and (f6.cod_estfum = 4
             or exists (select 1
                          from secgen_db.dbo.sg_dpag dp6,
                               secgen_db.dbo.sg_epag ep6
                         where dp6.id_funprse = f6.id_funprse
                           and dp6.corr_fume  = f6.corr_fume
                           and ep6.id_funprse = dp6.id_funprse
                           and ep6.nro_cuota  = dp6.nro_cuota
                           and ep6.cod_estcuo = 10))) as mto_rechazado,
    fu.dentro_jor,
    case when isnull(fu.dentro_jor, 'N') not in ('S', 'D')
         then 0
         else (select count(*)
                 from secgen_db.dbo.sg_dpag d3,
                      secgen_db.dbo.sg_fume f3
                where d3.id_funprse = epag.id_funprse
                  and d3.nro_cuota  = epag.nro_cuota
                  and f3.id_funprse = d3.id_funprse
                  and f3.corr_fume  = d3.corr_fume
                  and exists (select 1
                                from secgen_db.dbo.sg_fuco fc
                               where fc.id_funprse = d3.id_funprse
                                 and datepart(yy, fc.fec_compro) = f3.ano_prop
                                 and datepart(mm, fc.fec_compro) = f3.mes_prop)
                  and not exists (select 1
                                    from secgen_db.dbo.sg_fuc2 c3
                                   where c3.id_funprse = d3.id_funprse
                                     and c3.corr_fume  = d3.corr_fume))
    end as cant_sincomp
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
where epag.cod_estcuo <> 1
  and (@cod_estcuo = 0 or epag.cod_estcuo = @cod_estcuo)
  and isnull(prse.cod_modprs, 1) = 2
  and soli.cod_estsol = 11
  and soli.nro_resolu is not null
group by fu.nro_solici, epag.id_funprse, epag.nro_cuota, epag.cod_estcuo,
    ecuo.des_estcuo, epag.rut_solici, epag.fec_solici, epag.id_evidenc,
    fu.rut, pers.nom_dest, pers.nom_nombre, pers.nom_appate, pers.nom_apmate,
    prse.actividad, prse.cod_unifin, prse.cod_ccto, ccto.nom_ab_cct,
    ccto.afec_du9, ccto.con_topdu9,
    soli.nro_resolu, soli.ano_resolu, rslc.num_resolu, fu.mto_total,
    fu.mto_tope, fu.tot_cuotas, fu.ext_cuotas, fu.cod_tpps, fu.cod_sitm, fu.dentro_jor,
    epag.ano_pago, epag.mes_pago
order by epag.fec_solici, fu.nro_solici, epag.id_funprse, epag.nro_cuota
go

grant execute on Analisis2.sg_epagsSecgen03 to UsuaVrac
go
