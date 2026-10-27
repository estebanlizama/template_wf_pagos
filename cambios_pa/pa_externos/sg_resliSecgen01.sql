use sisper_db
go

if exists (select 1
             from sysobjects a, sysusers b
            where a.uid = b.uid
              and a.type = 'P'
              and b.name = 'Analisis2'
              and a.name = 'sg_resliSecgen01')
    drop procedure Analisis2.sg_resliSecgen01
go

/* Procedimiento : sg_resliSecgen01

   Entrada :
   @num_resoluc       -> Numero de la resolucion. (Obligatorio)
   @cod_tipo_rs       -> Tipo de documento; debe ser resolucion (2). (Obligatorio)
   @codigo_unid       -> Unidad SISPER fija 05000000. (Obligatorio)
   @ano               -> Ano de la resolucion. (Obligatorio)
   @fec_resol         -> Fecha de la resolucion en formato dd/mm/aaaa. (Obligatorio)
   @motivo            -> Motivo de la resolucion, maximo 100 caracteres. (Obligatorio)
   @vistos            -> Texto de vistos, maximo 100 caracteres. (Opcional)
   @considera         -> Texto de considerandos, maximo 100 caracteres. (Opcional)
   @resuelvo          -> Texto resolutivo, maximo 100 caracteres. (Opcional)
   @num_doc_ant       -> Numero del documento antecedente. (Opcional)

   Objetivo : Registrar en SISPER la resolucion que respalda las asignaciones
   de prestaciones de servicios del workflow.

   Creacion: No registrada en el procedimiento original
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_resliSecgen01
    @num_resoluc varchar(10),
    @cod_tipo_rs char(1),
    @codigo_unid char(8),
    @ano char(4),
    @fec_resol char(10),
    @motivo varchar(250),
    @vistos varchar(250) = null,
    @considera varchar(250) = null,
    @resuelvo varchar(250) = null,
    @num_doc_ant varchar(10) = null
as

set nocount on

declare @dia int
declare @mes int
declare @ano_fecha int
declare @dias_mes int
declare @fecha_resol datetime
declare @error int

select @num_resoluc = ltrim(rtrim(@num_resoluc)),
       @codigo_unid = ltrim(rtrim(@codigo_unid)),
       @ano = ltrim(rtrim(@ano)),
       @fec_resol = ltrim(rtrim(@fec_resol)),
       @motivo = ltrim(rtrim(@motivo)),
       @vistos = nullif(ltrim(rtrim(@vistos)), ''),
       @considera = nullif(ltrim(rtrim(@considera)), ''),
       @resuelvo = nullif(ltrim(rtrim(@resuelvo)), ''),
       @num_doc_ant = nullif(ltrim(rtrim(@num_doc_ant)), '')

if @num_resoluc is null or @num_resoluc = ''
begin
    select 'Falta el numero de la resolucion' as msg
    return
end

if @cod_tipo_rs is null or @cod_tipo_rs <> '2'
begin
    select 'El tipo de documento debe corresponder a una resolucion' as msg
    return
end

if @codigo_unid is null or @codigo_unid <> '05000000'
begin
    select 'La unidad de la resolucion no corresponde a la unidad configurada' as msg
    return
end

if @ano is null or len(@ano) <> 4 or patindex('%[^0-9]%', @ano) > 0
begin
    select 'El ano de la resolucion debe tener cuatro digitos' as msg
    return
end

if @motivo is null or @motivo = ''
begin
    select 'Falta el motivo de la resolucion' as msg
    return
end

if len(@motivo) > 100 or len(@vistos) > 100 or len(@considera) > 100
   or len(@resuelvo) > 100 or len(@num_doc_ant) > 10
begin
    select 'Uno de los textos excede el largo permitido para la resolucion' as msg
    return
end

if @fec_resol is null or len(@fec_resol) <> 10
   or substring(@fec_resol, 3, 1) <> '/'
   or substring(@fec_resol, 6, 1) <> '/'
   or patindex('%[^0-9]%', substring(@fec_resol, 1, 2) +
                            substring(@fec_resol, 4, 2) +
                            substring(@fec_resol, 7, 4)) > 0
begin
    select 'La fecha de la resolucion debe usar el formato dd/mm/aaaa' as msg
    return
end

select @dia = convert(int, substring(@fec_resol, 1, 2)),
       @mes = convert(int, substring(@fec_resol, 4, 2)),
       @ano_fecha = convert(int, substring(@fec_resol, 7, 4))

if @mes < 1 or @mes > 12 or @ano_fecha < 1753
begin
    select 'La fecha de la resolucion no es valida' as msg
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

if @dia < 1 or @dia > @dias_mes or @ano_fecha <> convert(int, @ano)
begin
    select 'La fecha de la resolucion no es valida o no coincide con el ano' as msg
    return
end

select @fecha_resol = convert(datetime, @fec_resol, 103)

if exists (select 1
             from sisper_db.dbo.sp_resl
            where num_resol = @num_resoluc
              and cod_ders = @cod_tipo_rs
              and cod_unidad = @codigo_unid
              and ano = @ano)
begin
    select 'La resolucion ya se encuentra registrada' as msg
    return
end

begin tran

insert into sisper_db.dbo.sp_resl
       (num_resol, cod_ders, cod_unidad, ano, f_resoluc, motivo,
        vistos, consider, resuelvo, num_docant, f_ingreso)
values (@num_resoluc, @cod_tipo_rs, @codigo_unid, @ano, @fecha_resol,
        @motivo, @vistos, @considera, @resuelvo, @num_doc_ant, getdate())

select @error = @@error

if @error <> 0 or @@transtate = 2 or @@transtate = 3
begin
    if @@transtate = 2
        rollback tran
    select 'No fue posible registrar la resolucion' as msg
    return
end

commit tran

select @error = @@error

if @error <> 0 or @@transtate = 2 or @@transtate = 3
begin
    if @@transtate = 2
        rollback tran
    select 'No fue posible confirmar el registro de la resolucion' as msg
    return
end

select 1 as status, 'OK' as code, 'Resolucion registrada correctamente' as msg
go

grant execute on Analisis2.sg_resliSecgen01 to UsuaVrac
go
