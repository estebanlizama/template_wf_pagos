use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_fuc2dSecgen02')
   drop procedure Analisis2.sg_fuc2dSecgen02

go

/* Procedimiento : sg_fuc2dSecgen02

   Entrada :
   @id_funprse          -> Identificador del funcionario. (Obligatorio)
   @rut_person          -> RUT del revisor DGDP. (Obligatorio)
   @corr_fume           -> Correlativo del mes de ejecucion. (Obligatorio)
   @fec_comrea          -> Fecha del tramo a eliminar. (Opcional)

   Objetivo : Eliminar las compensaciones realizadas de un mes de ejecucion, o
   un tramo puntual si se indica su fecha.

   Creacion: ELA 2026/10/19
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_fuc2dSecgen02
    @id_funprse int = null,
    @rut_person char(9) = null,
    @corr_fume tinyint = null,
    @fec_comrea datetime = null
as

declare @cod_estfum tinyint
declare @cod_estcuo tinyint
declare @desde datetime
declare @hasta datetime

if @id_funprse is null or @corr_fume is null
begin
    select 'Error: Datos de compensacion incompletos' as msg
    return
end

if @rut_person is null or ltrim(rtrim(@rut_person)) = ''
begin
    select 'Falta el rut del revisor' as msg
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

if not exists (select 1
                 from secgen_db.dbo.sg_fups fu
                where fu.id_funprse = @id_funprse)
begin
    select 'Error: La prestacion indicada no existe' as msg
    return
end

select @cod_estfum = cod_estfum
from secgen_db.dbo.sg_fume
where id_funprse = @id_funprse
  and corr_fume = @corr_fume

if @cod_estfum is null
begin
    select 'Error: El mes de ejecucion indicado no existe' as msg
    return
end

select @cod_estcuo = ep.cod_estcuo
from secgen_db.dbo.sg_dpag dp,
     secgen_db.dbo.sg_epag ep
where dp.id_funprse = @id_funprse
  and dp.corr_fume = @corr_fume
  and ep.id_funprse = dp.id_funprse
  and ep.nro_cuota = dp.nro_cuota

if isnull(@cod_estcuo, 0) <> 2
begin
    select 'Solo se puede corregir la compensacion mientras la cuota esta en visacion' as msg
    return
end

if @fec_comrea is null
begin
    delete from secgen_db.dbo.sg_fuc2
    where id_funprse = @id_funprse
      and corr_fume = @corr_fume
end
else
begin
    select @desde = dateadd(
        day,
        datediff(day, convert(datetime, '19000101'), @fec_comrea),
        convert(datetime, '19000101')
    )
    select @hasta = dateadd(day, 1, @desde)

    delete from secgen_db.dbo.sg_fuc2
    where id_funprse = @id_funprse
      and corr_fume = @corr_fume
      and fec_comrea >= @desde
      and fec_comrea < @hasta
end

if @@error <> 0
begin
    select 'Error: No fue posible eliminar las compensaciones indicadas' as msg
    return
end

select 1 as status, 'OK' as code, 'Compensaciones eliminadas correctamente' as msg
go

grant execute on Analisis2.sg_fuc2dSecgen02 to UsuaVrac
go
