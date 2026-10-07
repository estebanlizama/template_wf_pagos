use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_fuc2sSecgen02')
   drop procedure Analisis2.sg_fuc2sSecgen02

go

/* Procedimiento : sg_fuc2sSecgen02

   Entrada :
   @rut_person          -> RUT del revisor DGDP. (Obligatorio)
   @id_funprse          -> Prestacion del funcionario. (Obligatorio)
   @nro_cuota           -> Correlativo de la cuota. (Obligatorio)

   Objetivo : Listar las compensaciones realizadas de los meses de una cuota
   enviada, para la revision DGDP.

   Creacion: ELA 2026/10/07
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_fuc2sSecgen02
    @rut_person char(9) = null,
    @id_funprse int     = null,
    @nro_cuota  tinyint = null
as

if @rut_person is null or ltrim(rtrim(@rut_person)) = '' or isnull(@id_funprse, 0) <= 0 or isnull(@nro_cuota, 0) <= 0
begin
    select 'Faltan antecedentes para consultar la compensacion de la cuota.' as msg
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
       and cod_estcuo in (2, 3, 4, 8, 10, 11)
)
begin
    select 'La cuota no existe o no esta disponible para revision DGDP.' as msg
    return
end

select
    fc.id_funprse,
    fc.corr_fume,
    dateadd(
        day,
        datediff(day, convert(datetime, '19000101'), fc.fec_comrea),
        convert(datetime, '19000101')
    ) as fec_comrea,
    fc.hora_ini,
    fc.hora_ter,
    fm.ano_prop,
    fm.mes_prop,
    fm.cod_estfum
from secgen_db.dbo.sg_fuc2 fc
inner join secgen_db.dbo.sg_dpag dpag
    on dpag.id_funprse = fc.id_funprse
   and dpag.corr_fume  = fc.corr_fume
inner join secgen_db.dbo.sg_fume fm
    on fm.id_funprse = fc.id_funprse
   and fm.corr_fume  = fc.corr_fume
where dpag.id_funprse = @id_funprse
  and dpag.nro_cuota  = @nro_cuota
order by fc.id_funprse, fc.corr_fume, fc.fec_comrea, fc.hora_ini
go

grant execute on Analisis2.sg_fuc2sSecgen02 to UsuaVrac
go
