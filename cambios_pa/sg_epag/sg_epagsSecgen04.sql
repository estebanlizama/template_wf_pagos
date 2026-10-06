use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
            where a.uid = b.uid
              and a.type = 'P'
              and b.name = 'Analisis2'
              and a.name = 'sg_epagsSecgen04')
    drop procedure Analisis2.sg_epagsSecgen04
go

/* Procedimiento : sg_epagsSecgen04

   Entrada :
   @rut_person          -> RUT del revisor DGDP. (Obligatorio)
   @id_funprse          -> Prestacion del funcionario. (Obligatorio)
   @nro_cuota           -> Correlativo de la cuota. (Obligatorio)

   Objetivo : Consultar los meses asociados a una cuota en visacion DGDP.

   Creacion: ELA 2026/10/06
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_epagsSecgen04
    @rut_person char(9) = null,
    @id_funprse int = null,
    @nro_cuota tinyint = null
as

if @rut_person is null or ltrim(rtrim(@rut_person)) = '' or isnull(@id_funprse, 0) <= 0 or isnull(@nro_cuota, 0) <= 0
begin
    select 'Faltan antecedentes para consultar el detalle de la cuota.' as msg
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
       and cod_estcuo = 2
)
begin
    select 'La cuota no existe o ya no esta en visacion.' as msg
    return
end

select dpag.id_funprse,
       dpag.nro_cuota,
       dpag.corr_fume,
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
       fume.val_licmed,
       fume.val_inabili,
       fume.val_singoce,
       fume.val_ciecc,
       fume.fec_valida,
       fume.rut_autori,
       fume.fec_autori,
       fume.fec_envrem,
       (select count(*)
          from secgen_db.dbo.sg_fuc2 c2
         where c2.id_funprse = fume.id_funprse
           and c2.corr_fume = fume.corr_fume) as cant_compens
from secgen_db.dbo.sg_dpag dpag
inner join secgen_db.dbo.sg_fume fume
        on fume.id_funprse = dpag.id_funprse
       and fume.corr_fume = dpag.corr_fume
left join secgen_db.dbo.sg_efum efum on efum.cod_estfum = fume.cod_estfum
where dpag.id_funprse = @id_funprse
  and dpag.nro_cuota = @nro_cuota
order by fume.ano_prop, fume.mes_prop
go

grant execute on Analisis2.sg_epagsSecgen04 to UsuaVrac
go
