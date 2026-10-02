use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_fumesSecgen02')
   drop procedure Analisis2.sg_fumesSecgen02

go

/* Procedimiento : sg_fumesSecgen02

   Entrada :
   @rut_person          -> RUT del responsable vigente del centro de costo. (Obligatorio)
   @nro_solici          -> Numero de solicitud. (Opcional si viene id_funprse)
   @id_funprse          -> Identificador del funcionario. (Opcional)
   @nro_cuota           -> Limita a los meses de una cuota. (Opcional)

   Objetivo : Listar los meses de ejecucion para el flujo de pagos, con su
   estado, montos, descuentos y la cuota que los contiene.

   Creacion: ELA 2026/10/02
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_fumesSecgen02
    @rut_person char(9) = null,
    @nro_solici int = null,
    @id_funprse int = null,
    @nro_cuota tinyint = null
as

declare @mes_actual int

if @rut_person is null or ltrim(rtrim(@rut_person)) = ''
begin
    select 'Error: Falta el rut del jefe de proyecto' as msg
    return
end

if @nro_solici is null and @id_funprse is null
begin
    select 'Error: Indique la solicitud o el funcionario' as msg
    return
end

select @rut_person = right('000000000' + ltrim(rtrim(@rut_person)), 9)
select @mes_actual = datepart(yy, getdate()) * 100 + datepart(mm, getdate())

select
    fm.id_funprse,
    fm.corr_fume,
    fm.ano_prop,
    fm.mes_prop,
    fm.cod_estfum,
    rtrim(isnull(e.des_estfum, '')) as des_estfum,
    fm.ano_ejec,
    fm.mes_ejec,
    fm.mto_apagar,
    fm.mto_realpa,
    fm.mto_deslic,
    fm.mto_dessg,
    fm.id_evidenc,
    fm.val_licmed,
    fm.val_inabili,
    fm.val_singoce,
    fm.val_ciecc,
    fm.fec_valida,
    fm.rut_autori,
    fm.fec_autori,
    fm.fec_envrem,
    dp.nro_cuota,
    ep.cod_estcuo,
    rtrim(isnull(ec.des_estcuo, '')) as des_estcuo,
    ep.ano_pago,
    ep.mes_pago,
    case when fm.cod_estfum = 1
          and ((fm.ano_prop * 100 + fm.mes_prop) < @mes_actual
               or fu.f_termino < getdate())
         then 'S' else 'N' end as disponible,
    (select count(*)
       from secgen_db.dbo.sg_fuc2 c2
      where c2.id_funprse = fm.id_funprse
        and c2.corr_fume  = fm.corr_fume) as cant_compens
from secgen_db.dbo.sg_fume fm
inner join secgen_db.dbo.sg_fups fu on fm.id_funprse = fu.id_funprse
inner join secgen_db.dbo.sg_prse prse on prse.nro_solici = fu.nro_solici
left join secgen_db.dbo.sg_efum e on e.cod_estfum = fm.cod_estfum
left join secgen_db.dbo.sg_dpag dp
    on dp.id_funprse = fm.id_funprse
   and dp.corr_fume = fm.corr_fume
left join secgen_db.dbo.sg_epag ep
    on ep.id_funprse = dp.id_funprse
   and ep.nro_cuota = dp.nro_cuota
left join secgen_db.dbo.sg_ecuo ec on ec.cod_estcuo = ep.cod_estcuo
where isnull(prse.cod_modprs, 1) = 2
  and exists (select 1
                from fin21_db..es_ecct ecct
               where ecct.cod_ccto   = prse.cod_ccto
                 and ecct.cod_unifin = prse.cod_unifin
                 and ecct.vigente    = 'S'
                 and ecct.rut        = @rut_person)
  and (@nro_solici is null or fu.nro_solici = @nro_solici)
  and (@id_funprse is null or fm.id_funprse = @id_funprse)
  and (@nro_cuota is null or dp.nro_cuota = @nro_cuota)
order by fm.id_funprse, fm.ano_prop, fm.mes_prop
go

grant execute on Analisis2.sg_fumesSecgen02 to UsuaVrac
go
