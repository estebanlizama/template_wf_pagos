use sisper_db
go

if exists (select 1
             from sysobjects a, sysusers b
            where a.uid = b.uid
              and a.type = 'P'
              and b.name = 'Analisis2'
              and a.name = 'sg_ccaiSecgen01')
    drop procedure Analisis2.sg_ccaiSecgen01
go

/* Procedimiento : sg_ccaiSecgen01

   Entrada :
   @codigo_ficha      -> Codigo de ficha de la persona. (Obligatorio)
   @codigo_asignac    -> Codigo de asignacion registrado en SISPER. (Obligatorio)
   @unid_finan        -> Codigo de unidad financiera. (Opcional)
   @financiamiento    -> Codigo de financiamiento. (Opcional)
   @valor_asignado    -> Monto positivo asignado al centro de costo. (Opcional)
   @cod_sitm          -> Codigo de item presupuestario. (Opcional)
   @centro_costo      -> Codigo del centro de costo. (Opcional)
   @f_inicio          -> Fecha de inicio, formato dd/mm/aaaa. (Opcional)
   @f_termino         -> Fecha de termino, formato dd/mm/aaaa. (Opcional)

   Objetivo : Registrar el centro de costo asociado a una asignacion y
   devolver su codigo.

   Creacion: No registrada en el procedimiento original
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_ccaiSecgen01
    @codigo_ficha varchar(10),
    @codigo_asignac varchar(5),
    @unid_finan smallint = null,
    @financiamiento smallint = null,
    @valor_asignado varchar(10) = null,
    @cod_sitm varchar(5) = null,
    @centro_costo smallint = null,
    @f_inicio char(10) = null,
    @f_termino char(10) = null
as

set nocount on

declare @dia int
declare @mes int
declare @ano_fecha int
declare @dias_mes int
declare @fecha_inicio datetime
declare @fecha_termino datetime
declare @pos_punto int
declare @parte_entera varchar(10)
declare @parte_decimal varchar(10)
declare @valor decimal(9,2)
declare @max_ccas int
declare @codigo_cecoscon varchar(5)
declare @error int

select @codigo_ficha = ltrim(rtrim(@codigo_ficha)),
       @codigo_asignac = ltrim(rtrim(@codigo_asignac)),
       @valor_asignado = nullif(ltrim(rtrim(@valor_asignado)), ''),
       @cod_sitm = nullif(ltrim(rtrim(@cod_sitm)), ''),
       @f_inicio = nullif(ltrim(rtrim(@f_inicio)), ''),
       @f_termino = nullif(ltrim(rtrim(@f_termino)), '')

if @codigo_ficha is null or @codigo_ficha = ''
   or @codigo_asignac is null or @codigo_asignac = ''
begin
    select 'Faltan el codigo de ficha o el codigo de asignacion' as msg
    return
end

if @f_inicio = '__/__/____'
    select @f_inicio = null

if @f_termino = '__/__/____'
    select @f_termino = null

if @valor_asignado is not null
begin
    if patindex('%[^0-9.]%', @valor_asignado) > 0
    begin
        select 'El monto asignado debe ser numerico y positivo' as msg
        return
    end

    select @pos_punto = charindex('.', @valor_asignado)

    if @pos_punto = 0
    begin
        select @parte_entera = @valor_asignado,
               @parte_decimal = ''
    end
    else
    begin
        select @parte_entera = substring(@valor_asignado, 1, @pos_punto - 1),
               @parte_decimal = substring(@valor_asignado, @pos_punto + 1, 10)

        if charindex('.', @parte_decimal) > 0
        begin
            select 'El monto asignado debe tener un formato numerico valido' as msg
            return
        end
    end

    if @parte_entera = '' or len(@parte_entera) > 7
       or len(@parte_decimal) > 2
    begin
        select 'El monto asignado excede el rango permitido' as msg
        return
    end

    select @valor = convert(decimal(9,2), @valor_asignado)

    if @valor <= 0
    begin
        select 'El monto asignado debe ser mayor que cero' as msg
        return
    end
end

if @f_inicio is not null
begin
    if len(@f_inicio) <> 10 or substring(@f_inicio, 3, 1) <> '/'
       or substring(@f_inicio, 6, 1) <> '/'
       or patindex('%[^0-9]%', substring(@f_inicio, 1, 2) +
                                substring(@f_inicio, 4, 2) +
                                substring(@f_inicio, 7, 4)) > 0
    begin
        select 'La fecha de inicio debe usar el formato dd/mm/aaaa' as msg
        return
    end

    select @dia = convert(int, substring(@f_inicio, 1, 2)),
           @mes = convert(int, substring(@f_inicio, 4, 2)),
           @ano_fecha = convert(int, substring(@f_inicio, 7, 4))

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

    if @dia < 1 or @dia > @dias_mes
    begin
        select 'La fecha de inicio no es valida' as msg
        return
    end

    select @fecha_inicio = convert(datetime, @f_inicio, 103)
end

if @f_termino is not null
begin
    if len(@f_termino) <> 10 or substring(@f_termino, 3, 1) <> '/'
       or substring(@f_termino, 6, 1) <> '/'
       or patindex('%[^0-9]%', substring(@f_termino, 1, 2) +
                                substring(@f_termino, 4, 2) +
                                substring(@f_termino, 7, 4)) > 0
    begin
        select 'La fecha de termino debe usar el formato dd/mm/aaaa' as msg
        return
    end

    select @dia = convert(int, substring(@f_termino, 1, 2)),
           @mes = convert(int, substring(@f_termino, 4, 2)),
           @ano_fecha = convert(int, substring(@f_termino, 7, 4))

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

    if @dia < 1 or @dia > @dias_mes
    begin
        select 'La fecha de termino no es valida' as msg
        return
    end

    select @fecha_termino = convert(datetime, @f_termino, 103)
end

if @fecha_inicio is not null and @fecha_termino is not null
   and @fecha_termino < @fecha_inicio
begin
    select 'La fecha de termino no puede ser anterior a la fecha de inicio' as msg
    return
end

if not exists (select 1
                 from sisper_db.dbo.ss_asds
                where cod_ficha = @codigo_ficha
                  and cod_asign = @codigo_asignac)
begin
    select 'La asignacion indicada no existe para la persona' as msg
    return
end

begin tran

if exists (select 1
             from sisper_db.dbo.ss_ccas
            where ltrim(rtrim(cod_ccasig)) = 'S'
               or (substring(ltrim(rtrim(cod_ccasig)), 1, 1) = 'S'
                   and patindex('%[^0-9]%',
                       substring(ltrim(rtrim(cod_ccasig)), 2, 4)) > 0))
begin
    rollback tran
    select 'No es posible generar el correlativo del centro de costo' as msg
    return
end

select @max_ccas = max(convert(int, substring(cod_ccasig, 2, 4)))
  from sisper_db.dbo.ss_ccas
 where substring(cod_ccasig, 1, 1) = 'S'

if not exists (select 1 from sisper_db.dbo.ss_ccas)
    select @codigo_cecoscon = '2'
else
begin
    if @max_ccas is null
        select @max_ccas = 0

    if @max_ccas >= 9999
    begin
        rollback tran
        select 'Se alcanzo el maximo de centros de costo asignables' as msg
        return
    end

    select @codigo_cecoscon = 'S' + convert(varchar(4), @max_ccas + 1)
end

insert into sisper_db.dbo.ss_ccas
       (cod_ficha, cod_asign, cod_ccasig, cod_unifin, cod_tfinan,
        valor_asig, cod_item, cod_ccto, f_inicio, f_termino)
values (@codigo_ficha, @codigo_asignac, @codigo_cecoscon, @unid_finan,
        @financiamiento, @valor, @cod_sitm, @centro_costo,
        @fecha_inicio, @fecha_termino)

select @error = @@error

if @error <> 0 or @@transtate = 2 or @@transtate = 3
begin
    if @@transtate = 2
        rollback tran
    select 'No fue posible registrar el centro de costo' as msg
    return
end

commit tran

select @error = @@error

if @error <> 0 or @@transtate = 2 or @@transtate = 3
begin
    if @@transtate = 2
        rollback tran
    select 'No fue posible confirmar el registro del centro de costo' as msg
    return
end

select 1 as status, 'OK' as code,
       'Centro de costo registrado correctamente' as msg,
       @codigo_cecoscon as codigo_cecoscon
go

grant execute on Analisis2.sg_ccaiSecgen01 to UsuaVrac
go
