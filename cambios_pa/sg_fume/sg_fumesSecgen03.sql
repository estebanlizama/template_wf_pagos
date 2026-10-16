use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_fumesSecgen03')
   drop procedure Analisis2.sg_fumesSecgen03

go

/* Procedimiento : sg_fumesSecgen03

   Entrada :
   @rut_person          -> RUT del revisor DGDP. (Obligatorio)
   @id_funprse          -> Prestacion del funcionario. (Obligatorio)
   @nro_cuota           -> Cuota en revision, para validar el acceso. (Obligatorio)

   Objetivo : Listar TODOS los meses de ejecucion de la prestacion para la
   revision DGDP, con su estado, montos, descuentos y la cuota que los
   contiene. Existe aparte de sg_fumesSecgen02 porque aquel acota por el
   responsable del centro de costo y el revisor no lo es. La revision
   necesita los meses que quedaron fuera de la cuota para saber si lo no
   pagado tiene donde ir.

   Creacion: ELA 2026/10/15
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_fumesSecgen03
    @rut_person char(9) = null,
    @id_funprse int     = null,
    @nro_cuota  tinyint = null
as

declare @mes_actual int

if @rut_person is null or ltrim(rtrim(@rut_person)) = '' or isnull(@id_funprse, 0) <= 0 or isnull(@nro_cuota, 0) <= 0
begin
    select 'Faltan antecedentes para consultar los meses de la prestacion.' as msg
    return
end

select @rut_person = right('000000000' + ltrim(rtrim(@rut_person)), 9)
select @mes_actual = datepart(yy, getdate()) * 100 + datepart(mm, getdate())

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
          select 1
            from sisper_db.dbo.sp_orde orde
           where orde.cod_organi = 696
             and orde.rut_person = @rut_person
             and orde.vigente = 'S'
      )
)
begin
    select 'El usuario no tiene asignacion vigente para revisar cuotas DGDP.' as msg
    return
end

if not exists (
    select 1
      from secgen_db.dbo.sg_epag
     where id_funprse = @id_funprse
       and nro_cuota = @nro_cuota
       and cod_estcuo in (2, 3, 4, 8, 10, 11)
)
begin
    select 'La cuota no existe o no esta disponible para revision DGDP.' as msg
    return
end

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
  and fm.id_funprse = @id_funprse
order by fm.ano_prop, fm.mes_prop
go

grant execute on Analisis2.sg_fumesSecgen03 to UsuaVrac
go
