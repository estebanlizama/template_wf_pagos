use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_fuc2dSecgen01')
   drop procedure Analisis2.sg_fuc2dSecgen01

go

/* Procedimiento : sg_fuc2dSecgen01

   Entrada :
   @id_funprse          -> Identificador del funcionario. (Obligatorio)
   @rut_person          -> RUT del responsable vigente del centro de costo. (Obligatorio)
   @corr_fume           -> Correlativo del mes de ejecucion. (Obligatorio)
   @fec_comrea          -> Fecha del tramo a eliminar. (Opcional)

   Objetivo : Eliminar las compensaciones realizadas de un mes de ejecucion, o
   un tramo puntual si se indica su fecha.

   Creacion: ELA 2026/10/01
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_fuc2dSecgen01
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
    select 'Falta el rut del jefe de proyecto' as msg
    return
end

select @rut_person = right('000000000' + ltrim(rtrim(@rut_person)), 9)

if not exists (select 1
                 from secgen_db.dbo.sg_fups fu,
                      secgen_db.dbo.sg_prse prse,
                      fin21_db..es_ecct ecct
                where fu.id_funprse = @id_funprse
                  and prse.nro_solici = fu.nro_solici
                  and ecct.cod_ccto   = prse.cod_ccto
                  and ecct.cod_unifin = prse.cod_unifin
                  and ecct.vigente    = 'S'
                  and ecct.rut        = @rut_person)
begin
    select 'Error: La prestacion no esta a su cargo' as msg
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

if @cod_estfum <> 1 and isnull(@cod_estcuo, 0) <> 3
begin
    select 'Error: El mes de ejecucion ya no admite cambios' as msg
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

select 'OK' as msg
go

grant execute on Analisis2.sg_fuc2dSecgen01 to UsuaVrac
go
