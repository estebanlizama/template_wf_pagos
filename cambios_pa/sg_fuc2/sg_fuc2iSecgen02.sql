use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_fuc2iSecgen02')
   drop procedure Analisis2.sg_fuc2iSecgen02

go

/* Procedimiento : sg_fuc2iSecgen02

   Entrada :
   @id_funprse          -> Identificador del funcionario. (Obligatorio)
   @rut_person          -> RUT del revisor DGDP. (Obligatorio)
   @corr_fume           -> Correlativo del mes de ejecucion. (Obligatorio)
   @fec_comrea          -> Fecha de la compensacion realizada. (Obligatorio)
   @hora_ini            -> Hora de inicio del tramo. (Obligatorio)
   @hora_ter            -> Hora de termino del tramo. (Obligatorio)

   Objetivo : Registrar un tramo de compensacion efectivamente realizado por un
   funcionario, sin superar el total comprometido para ese mes.

   Creacion: ELA 2026/10/19
   Actualizacion: ELA 2026/10/21
*/
create procedure Analisis2.sg_fuc2iSecgen02
    @id_funprse int = null,
    @rut_person char(9) = null,
    @corr_fume tinyint = null,
    @fec_comrea datetime = null,
    @hora_ini time = null,
    @hora_ter time = null
as

declare @cod_modprs tinyint
declare @dentro_jor char(1)
declare @f_inicio datetime
declare @f_termino datetime
declare @cod_estfum tinyint
declare @cod_estcuo tinyint
declare @rut_funcion char(9)
declare @fecha_base datetime
declare @inicio_dt datetime
declare @termino_dt datetime
declare @min_ini int
declare @min_ter int
declare @dia_ini int
declare @dia_ter int
declare @jor_ini int
declare @jor_ter int
declare @ano_prop smallint
declare @mes_prop tinyint
declare @min_compro int
declare @min_infor int
declare @min_nuevo int
declare @min_saldo int
declare @msg varchar(255)

if @id_funprse is null or @corr_fume is null or @fec_comrea is null
   or @hora_ini is null or @hora_ter is null
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

/* Acceso DGDP, no del jefe de proyecto: mismo criterio que sg_fumesSecgen03
   y sg_fumeuSecgen03 -- contrato vigente no honorario mas asignacion vigente
   a la unidad 696. El revisor no es responsable del centro de costo, asi que
   el filtro por es_ecct de la version Secgen01 lo dejaba siempre fuera y la
   llamada moria con "La prestacion no esta a su cargo". */
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

select
    @cod_modprs = isnull(prse.cod_modprs, 1),
    @dentro_jor = isnull(fu.dentro_jor, 'N'),
    @rut_funcion = fu.rut,
    @f_inicio = fu.f_inicio,
    @f_termino = fu.f_termino
from secgen_db.dbo.sg_prse prse,
     secgen_db.dbo.sg_fups fu
where prse.nro_solici = fu.nro_solici
  and fu.id_funprse = @id_funprse

if @cod_modprs is null or @cod_modprs <> 2
begin
    select 'Error: El funcionario no corresponde a la modalidad DU288' as msg
    return
end

if @dentro_jor not in ('S', 'D')
begin
    select 'Error: El funcionario no requiere compensacion horaria' as msg
    return
end

select @cod_estfum = cod_estfum,
       @ano_prop   = ano_prop,
       @mes_prop   = mes_prop
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

/* DGDP corrige mientras visa, no antes ni despues: mismo corte que aplica
   sg_fumeuSecgen03 a los descuentos del mes. */
if isnull(@cod_estcuo, 0) <> 2
begin
    select 'Solo se puede corregir la compensacion mientras la cuota esta en visacion' as msg
    return
end

if @hora_ter = @hora_ini
begin
    select 'Error: Las horas de inicio y termino deben ser distintas' as msg
    return
end

select @fecha_base = dateadd(
    day,
    datediff(day, convert(datetime, '19000101'), @fec_comrea),
    convert(datetime, '19000101')
)
select @min_ini = datepart(hh, @hora_ini) * 60 + datepart(mi, @hora_ini)
select @min_ter = datepart(hh, @hora_ter) * 60 + datepart(mi, @hora_ter)
select @inicio_dt = dateadd(minute, @min_ini, @fecha_base)
select @termino_dt = dateadd(minute, @min_ter, @fecha_base)

if @hora_ter < @hora_ini
    select @termino_dt = dateadd(day, 1, @termino_dt)

if @f_inicio is null or @f_termino is null
   or datediff(day, @f_inicio, @inicio_dt) < 0
   or datediff(day, @termino_dt, @f_termino) < 0
begin
    select 'Error: La compensacion esta fuera del periodo autorizado' as msg
    return
end

if exists (
    select 1
    from ufro_db.dbo.es_cfer c
    where c.cod_tipfer = 1
      and (
          datediff(day, c.f_feriado, @inicio_dt) = 0
          or (
              datediff(day, @inicio_dt, @termino_dt) > 0
              and @min_ter > 0
              and datediff(day, c.f_feriado, @termino_dt) = 0
          )
      )
)
begin
    select 'Error: La fecha seleccionada corresponde a un feriado nacional y no admite compensacion' as msg
    return
end

select @jor_ini = 8 * 60 + 30
select @jor_ter = 17 * 60 + 18
select @dia_ini = datediff(day, convert(datetime, '19000101'), @inicio_dt) % 7
select @dia_ter = datediff(day, convert(datetime, '19000101'), @termino_dt) % 7

if @dia_ini >= 5 or (@hora_ter < @hora_ini and @dia_ter >= 5)
begin
    select 'Error: La compensacion solo puede registrarse de lunes a viernes' as msg
    return
end

if @dia_ini between 0 and 4
   and @min_ini < @jor_ter
   and (case when @hora_ter < @hora_ini then 1440 else @min_ter end) > @jor_ini
begin
    select 'Error: La compensacion no puede realizarse dentro de la jornada institucional' as msg
    return
end

if @hora_ter < @hora_ini
   and @dia_ter between 0 and 4
   and @min_ter > @jor_ini
begin
    select 'Error: La compensacion no puede realizarse dentro de la jornada institucional' as msg
    return
end

if exists (
    select 1
    from secgen_db.dbo.sg_fuc2 fc
    where fc.id_funprse = @id_funprse
      and @inicio_dt < dateadd(
            day,
            case when fc.hora_ter < fc.hora_ini then 1 else 0 end,
            dateadd(
                minute,
                datepart(hh, fc.hora_ter) * 60 + datepart(mi, fc.hora_ter),
                dateadd(
                    day,
                    datediff(day, convert(datetime, '19000101'), fc.fec_comrea),
                    convert(datetime, '19000101')
                )
            )
          )
      and dateadd(
            minute,
            datepart(hh, fc.hora_ini) * 60 + datepart(mi, fc.hora_ini),
            dateadd(
                day,
                datediff(day, convert(datetime, '19000101'), fc.fec_comrea),
                convert(datetime, '19000101')
            )
          ) < @termino_dt
)
begin
    select 'Error: El tramo de compensacion esta duplicado o superpuesto' as msg
    return
end

/* Compensacion realizada por el mismo funcionario en otra prestacion. */
if exists (
    select 1
    from secgen_db.dbo.sg_fuc2 fc,
         secgen_db.dbo.sg_fups fu,
         secgen_db.dbo.sg_soli soli
    where fc.id_funprse <> @id_funprse
      and fu.id_funprse = fc.id_funprse
      and soli.nro_solici = fu.nro_solici
      and fu.rut = @rut_funcion
      and soli.cod_estsol in (8, 9, 10, 11)
      and not exists (
          select 1
          from secgen_db.dbo.sg_dpag dp,
               secgen_db.dbo.sg_epag ep
          where dp.id_funprse = fc.id_funprse
            and dp.corr_fume  = fc.corr_fume
            and ep.id_funprse = dp.id_funprse
            and ep.nro_cuota  = dp.nro_cuota
            and ep.cod_estcuo = 10
      )
      and @inicio_dt < dateadd(
            day,
            case when fc.hora_ter < fc.hora_ini then 1 else 0 end,
            dateadd(
                minute,
                datepart(hh, fc.hora_ter) * 60 + datepart(mi, fc.hora_ter),
                dateadd(
                    day,
                    datediff(day, convert(datetime, '19000101'), fc.fec_comrea),
                    convert(datetime, '19000101')
                )
            )
          )
      and dateadd(
            minute,
            datepart(hh, fc.hora_ini) * 60 + datepart(mi, fc.hora_ini),
            dateadd(
                day,
                datediff(day, convert(datetime, '19000101'), fc.fec_comrea),
                convert(datetime, '19000101')
            )
          ) < @termino_dt
)
begin
    select 'Error: El funcionario ya tiene compensacion realizada en ese horario en otra prestacion' as msg
    return
end

select @min_compro = isnull(sum(
    datepart(hh, fc.hora_ter) * 60 + datepart(mi, fc.hora_ter)
  - datepart(hh, fc.hora_ini) * 60 - datepart(mi, fc.hora_ini)
  + case when fc.hora_ter < fc.hora_ini then 1440 else 0 end), 0)
from secgen_db.dbo.sg_fuco fc
where fc.id_funprse = @id_funprse
  and datepart(yy, fc.fec_compro) = @ano_prop
  and datepart(mm, fc.fec_compro) = @mes_prop

select @min_infor = isnull(sum(
    datepart(hh, fc.hora_ter) * 60 + datepart(mi, fc.hora_ter)
  - datepart(hh, fc.hora_ini) * 60 - datepart(mi, fc.hora_ini)
  + case when fc.hora_ter < fc.hora_ini then 1440 else 0 end), 0)
from secgen_db.dbo.sg_fuc2 fc
where fc.id_funprse = @id_funprse
  and fc.corr_fume = @corr_fume

select @min_nuevo = @min_ter - @min_ini
                  + case when @hora_ter < @hora_ini then 1440 else 0 end
select @min_saldo = @min_compro - @min_infor

if @min_saldo <= 0
begin
    select 'Error: El mes ya tiene informadas todas las horas comprometidas' as msg
    return
end

if @min_nuevo > @min_saldo
begin
    select @msg = 'Error: Supera las horas comprometidas del mes. Quedan '
                + convert(varchar(10), @min_saldo / 60) + ' h '
                + convert(varchar(10), @min_saldo % 60) + ' min por informar'
    select @msg as msg
    return
end

insert into secgen_db.dbo.sg_fuc2
    (id_funprse, corr_fume, fec_comrea, hora_ini, hora_ter)
values
    (@id_funprse, @corr_fume, @inicio_dt, @hora_ini, @hora_ter)

if @@error <> 0
begin
    select 'Error: No fue posible guardar el tramo de compensacion' as msg
    return
end

select 1 as status, 'OK' as code, 'Tramo de compensacion registrado correctamente' as msg
go

grant execute on Analisis2.sg_fuc2iSecgen02 to UsuaVrac
go
