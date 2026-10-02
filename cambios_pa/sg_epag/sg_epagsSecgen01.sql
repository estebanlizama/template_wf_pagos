use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_epagsSecgen01')
   drop procedure Analisis2.sg_epagsSecgen01

go

/* Procedimiento : sg_epagsSecgen01

   Entrada :
   @nro_solici          -> Numero de la solicitud de prestacion. (Obligatorio)
   @rut_person          -> RUT del responsable vigente del centro de costo. (Obligatorio)
   @id_funprse          -> Limita a un funcionario de la solicitud. (Opcional)

   Objetivo : Listar las cuotas de pago de una resolucion con sus montos y
   el periodo de ejecucion que cubren.

   Creacion: ELA 2026/10/01
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_epagsSecgen01
    @nro_solici int = null,
    @rut_person char(9) = null,
    @id_funprse int = null
as
if @nro_solici is null or @nro_solici <= 0
begin
    select 'Falta el numero de solicitud. Se aborta el procedimiento' msg return
end

if @rut_person is null or ltrim(rtrim(@rut_person)) = ''
begin
    select 'Falta el rut del jefe de proyecto. Se aborta el procedimiento' msg return
end

select @rut_person = right('000000000' + ltrim(rtrim(@rut_person)), 9)

if not exists (select 1
                 from secgen_db.dbo.sg_prse prse,
                      secgen_db.dbo.sg_soli soli,
                      fin21_db..es_ecct ecct
                where prse.nro_solici = @nro_solici
                  and soli.nro_solici = prse.nro_solici
                  and ecct.cod_ccto   = prse.cod_ccto
                  and ecct.cod_unifin = prse.cod_unifin
                  and ecct.vigente    = 'S'
                  and ecct.rut        = @rut_person
                  and isnull(prse.cod_modprs, 1) = 2
                  and soli.cod_estsol = 11
                  and soli.nro_resolu is not null)
begin
    select 'La resolucion no existe, no esta archivada o no esta a su cargo' msg return
end

select
    epag.id_funprse,
    epag.nro_cuota,
    epag.cod_estcuo,
    rtrim(isnull(ecuo.des_estcuo, '')) as des_estcuo,
    epag.rut_solici,
    epag.fec_solici,
    epag.id_evidenc,
    epag.fec_pago,
    epag.ano_pago,
    epag.mes_pago,
    epag.mto_realpa,
    fu.rut,
    case when len(isnull(pers.nom_dest, '')) <= 1 then pers.nom_nombre else pers.nom_dest end as nom_nombre,
    pers.nom_appate,
    pers.nom_apmate,
    fu.cod_tpps,
    fu.mto_total,
    fu.mto_tope,
    fu.tot_cuotas,
    fu.ext_cuotas,
    count(dpag.corr_fume)                            as cant_meses,
    isnull(sum(fume.mto_apagar), 0)                  as mto_cuota,
    isnull(sum(fume.mto_deslic), 0)                  as mto_deslic,
    isnull(sum(fume.mto_dessg), 0)                   as mto_dessg,
    min(fume.ano_prop * 100 + fume.mes_prop)         as mes_prop_min,
    max(fume.ano_prop * 100 + fume.mes_prop)         as mes_prop_max,
    sum(case when fume.cod_estfum = 4 then 1 else 0 end) as cant_meses_rech
from
    secgen_db.dbo.sg_epag epag
inner join
    secgen_db.dbo.sg_fups fu
    on fu.id_funprse = epag.id_funprse
left join
    sisper_db..sp_pers pers
    on pers.rut_person = fu.rut
left join
    secgen_db.dbo.sg_ecuo ecuo
    on ecuo.cod_estcuo = epag.cod_estcuo
left join
    secgen_db.dbo.sg_dpag dpag
    on dpag.id_funprse = epag.id_funprse
    and dpag.nro_cuota = epag.nro_cuota
left join
    secgen_db.dbo.sg_fume fume
    on fume.id_funprse = dpag.id_funprse
    and fume.corr_fume = dpag.corr_fume
where
    fu.nro_solici = @nro_solici
and
    (@id_funprse is null or epag.id_funprse = @id_funprse)
group by
    epag.id_funprse, epag.nro_cuota, epag.cod_estcuo, ecuo.des_estcuo,
    epag.rut_solici, epag.fec_solici, epag.id_evidenc,
    epag.fec_pago, epag.ano_pago, epag.mes_pago, epag.mto_realpa,
    fu.rut, pers.nom_dest, pers.nom_nombre, pers.nom_appate, pers.nom_apmate,
    fu.cod_tpps, fu.mto_total, fu.mto_tope, fu.tot_cuotas, fu.ext_cuotas
order by
    epag.id_funprse, epag.nro_cuota
go

grant execute on Analisis2.sg_epagsSecgen01 to UsuaVrac
go
