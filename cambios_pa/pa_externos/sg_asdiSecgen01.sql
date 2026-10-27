use sisper_db
go

if exists (select 1
             from sysobjects a, sysusers b
            where a.uid = b.uid
              and a.type = 'P'
              and b.name = 'Analisis2'
              and a.name = 'sg_asdiSecgen01')
    drop procedure Analisis2.sg_asdiSecgen01
go

/* Procedimiento : sg_asdiSecgen01

   Entrada :
   @numero_resol      -> Numero de la resolucion. (Obligatorio)
   @codigo_decres     -> Tipo de documento; debe ser resolucion (2). (Obligatorio)
   @codigo_unidad     -> Unidad SISPER fija 05000000. (Obligatorio)
   @ano               -> Ano de la resolucion. (Obligatorio)
   @codigo_ficha      -> Codigo de ficha registrado en personal. (Obligatorio)
   @numero_cuenta     -> Numero de cuenta registrado en SISPER. (Opcional)
   @vigencia          -> Indicador de vigencia de la asignacion. (Obligatorio)
   @fec_inicio        -> Primer dia del mes de la cuota, formato dd/mm/aaaa. (Obligatorio)
   @fec_termino       -> Ultimo dia del mismo mes, formato dd/mm/aaaa. (Obligatorio)
   @observacion       -> Observacion de la asignacion, maximo 100 caracteres. (Opcional)
   @valor             -> Monto de la asignacion, mayor que cero. (Obligatorio)
   @permanente        -> Indicador de permanencia. (Opcional)
   @cuotas            -> Cantidad de cuotas autorizadas. (Opcional)
   @unidad_medida     -> Codigo de unidad de medida. (Opcional)

   Objetivo : Registrar una asignacion mensual para una persona y devolver
   su codigo de asignacion.

   Creacion: No registrada en el procedimiento original
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_asdiSecgen01
    @numero_resol varchar(10),
    @codigo_decres char(1),
    @codigo_unidad char(8),
    @ano char(4),
    @codigo_ficha varchar(10),
    @numero_cuenta varchar(10),
    @vigencia char(1),
    @fec_inicio char(10),
    @fec_termino char(10),
    @observacion varchar(100) = null,
    @valor decimal(9,2),
    @permanente char(1) = null,
    @cuotas varchar(5) = null,
    @unidad_medida char(1) = null
as

set nocount on

declare @dia int
declare @mes int
declare @ano_fecha int
declare @dias_mes int
declare @fecha_inicio datetime
declare @fecha_termino datetime
declare @max_asign int
declare @codigo_asignac varchar(5)
declare @error int

select @numero_resol = ltrim(rtrim(@numero_resol)),
       @codigo_unidad = ltrim(rtrim(@codigo_unidad)),
       @ano = ltrim(rtrim(@ano)),
       @codigo_ficha = ltrim(rtrim(@codigo_ficha)),
       @numero_cuenta = nullif(ltrim(rtrim(@numero_cuenta)), ''),
       @vigencia = ltrim(rtrim(@vigencia)),
       @fec_inicio = ltrim(rtrim(@fec_inicio)),
       @fec_termino = ltrim(rtrim(@fec_termino)),
       @observacion = nullif(ltrim(rtrim(@observacion)), ''),
       @permanente = nullif(ltrim(rtrim(@permanente)), ''),
       @cuotas = nullif(ltrim(rtrim(@cuotas)), ''),
       @unidad_medida = nullif(ltrim(rtrim(@unidad_medida)), '')

if @numero_resol is null or @numero_resol = ''
   or @codigo_ficha is null or @codigo_ficha = ''
begin
    select 'Faltan el numero de la resolucion o el codigo de ficha' as msg
    return
end

if @codigo_decres is null or @codigo_decres <> '2'
   or @codigo_unidad is null or @codigo_unidad <> '05000000'
begin
    select 'El tipo o la unidad de la resolucion no corresponden a la configuracion' as msg
    return
end

if @ano is null or len(@ano) <> 4 or patindex('%[^0-9]%', @ano) > 0
begin
    select 'El ano de la resolucion debe tener cuatro digitos' as msg
    return
end

if @vigencia is null or @vigencia = ''
begin
    select 'Falta el indicador de vigencia de la asignacion' as msg
    return
end

if @valor is null or @valor <= 0
begin
    select 'El monto de la asignacion debe ser mayor que cero' as msg
    return
end

if @cuotas is not null and
   (len(@cuotas) > 5 or patindex('%[^0-9]%', @cuotas) > 0)
begin
    select 'La cantidad de cuotas autorizadas no es valida' as msg
    return
end

if @cuotas is not null and
   (convert(int, @cuotas) < 1 or convert(int, @cuotas) > 32767)
begin
    select 'La cantidad de cuotas autorizadas no es valida' as msg
    return
end

if @fec_inicio is null or len(@fec_inicio) <> 10
   or substring(@fec_inicio, 3, 1) <> '/'
   or substring(@fec_inicio, 6, 1) <> '/'
   or patindex('%[^0-9]%', substring(@fec_inicio, 1, 2) +
                            substring(@fec_inicio, 4, 2) +
                            substring(@fec_inicio, 7, 4)) > 0
begin
    select 'La fecha de inicio debe usar el formato dd/mm/aaaa' as msg
    return
end

select @dia = convert(int, substring(@fec_inicio, 1, 2)),
       @mes = convert(int, substring(@fec_inicio, 4, 2)),
       @ano_fecha = convert(int, substring(@fec_inicio, 7, 4))

if @mes < 1 or @mes > 12 or @ano_fecha < 1753
begin
    select 'La fecha de inicio no es valida' as msg
    return
end

if @mes in (4, 6, 9, 11)
    select @dias_mes = 30
else if @mes = 2
begin
    select @dias_mes = 28
    if (@ano_fecha % 400 = 0) or
       ((@ano_fecha % 4 = 0) and (@ano_fecha % 100 <> 0))
        select @dias_mes = 29
end
else
    select @dias_mes = 31

if @dia <> 1 or @dia > @dias_mes
begin
    select 'La fecha de inicio debe ser el primer dia del mes de la cuota' as msg
    return
end

select @fecha_inicio = convert(datetime, @fec_inicio, 103)

if @fec_termino is null or len(@fec_termino) <> 10
   or substring(@fec_termino, 3, 1) <> '/'
   or substring(@fec_termino, 6, 1) <> '/'
   or patindex('%[^0-9]%', substring(@fec_termino, 1, 2) +
                            substring(@fec_termino, 4, 2) +
                            substring(@fec_termino, 7, 4)) > 0
begin
    select 'La fecha de termino debe usar el formato dd/mm/aaaa' as msg
    return
end

select @dia = convert(int, substring(@fec_termino, 1, 2)),
       @mes = convert(int, substring(@fec_termino, 4, 2)),
       @ano_fecha = convert(int, substring(@fec_termino, 7, 4))

if @mes < 1 or @mes > 12 or @ano_fecha < 1753
begin
    select 'La fecha de termino no es valida' as msg
    return
end

if @mes in (4, 6, 9, 11)
    select @dias_mes = 30
else if @mes = 2
begin
    select @dias_mes = 28
    if (@ano_fecha % 400 = 0) or
       ((@ano_fecha % 4 = 0) and (@ano_fecha % 100 <> 0))
        select @dias_mes = 29
end
else
    select @dias_mes = 31

if @dia <> @dias_mes or datepart(mm, @fecha_inicio) <> @mes
   or datepart(yy, @fecha_inicio) <> @ano_fecha
   or @ano_fecha <> convert(int, @ano)
begin
    select 'La fecha de termino debe cerrar el mismo mes de la cuota' as msg
    return
end

select @fecha_termino = convert(datetime, @fec_termino, 103)

if not exists (select 1
                 from sisper_db.dbo.sp_resl
                where num_resol = @numero_resol
                  and cod_ders = @codigo_decres
                  and cod_unidad = @codigo_unidad
                  and ano = @ano)
begin
    select 'La resolucion no existe para los antecedentes indicados' as msg
    return
end

if not exists (select 1
                 from sisper_db.dbo.sp_pers
                where cod_ficha = @codigo_ficha)
begin
    select 'La persona no se encuentra registrada en SISPER' as msg
    return
end

if exists (select 1
             from sisper_db.dbo.ss_asds
            where cod_ficha = @codigo_ficha
              and num_resol = @numero_resol
              and cod_ders = @codigo_decres
              and cod_unidad = @codigo_unidad
              and ano = @ano
              and f_inicio = @fecha_inicio
              and f_termino = @fecha_termino)
begin
    select 'Ya existe una asignacion para esa persona y ese mes de la resolucion' as msg
    return
end

begin tran

if exists (select 1
             from sisper_db.dbo.ss_asds
            where cod_ficha = @codigo_ficha
              and (ltrim(rtrim(cod_asign)) = ''
                   or patindex('%[^0-9]%', ltrim(rtrim(cod_asign))) > 0))
begin
    rollback tran
    select 'No es posible generar el correlativo de la asignacion' as msg
    return
end

select @max_asign = max(convert(int, cod_asign))
  from sisper_db.dbo.ss_asds
 where cod_ficha = @codigo_ficha

if @max_asign is null
    select @max_asign = 2
else
    select @max_asign = @max_asign + 1

if @max_asign > 99999
begin
    rollback tran
    select 'Se alcanzo el maximo de asignaciones para la persona' as msg
    return
end

select @codigo_asignac = convert(varchar(5), @max_asign)

insert into sisper_db.dbo.ss_asds
       (num_resol, cod_ders, cod_unidad, ano, cod_ficha, cod_asign,
        num_cuenta, vigencia, f_inicio, f_termino, observac, valor,
        permanente, cuotas, unidad_med, validar, f_ingreso)
values (@numero_resol, @codigo_decres, @codigo_unidad, @ano,
        @codigo_ficha, @codigo_asignac, @numero_cuenta, @vigencia,
        @fecha_inicio, @fecha_termino, @observacion, @valor,
        @permanente, convert(smallint, @cuotas), @unidad_medida,
        '1', getdate())

select @error = @@error

if @error <> 0 or @@transtate = 2 or @@transtate = 3
begin
    if @@transtate = 2
        rollback tran
    select 'No fue posible registrar la asignacion' as msg
    return
end

commit tran

select @error = @@error

if @error <> 0 or @@transtate = 2 or @@transtate = 3
begin
    if @@transtate = 2
        rollback tran
    select 'No fue posible confirmar el registro de la asignacion' as msg
    return
end

select 1 as status, 'OK' as code,
       'Asignacion registrada correctamente' as msg,
       @codigo_asignac as codigo_asignac
go

grant execute on Analisis2.sg_asdiSecgen01 to UsuaVrac
go
