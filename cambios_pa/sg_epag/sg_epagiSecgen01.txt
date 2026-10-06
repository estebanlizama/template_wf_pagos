use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
            where a.uid = b.uid
              and a.type = 'P'
              and b.name = 'Analisis2'
              and a.name = 'sg_epagiSecgen01')
    drop procedure Analisis2.sg_epagiSecgen01
go

/* Procedimiento : sg_epagiSecgen01

   Entrada :
   @id_funprse          -> Prestacion del funcionario. (Obligatorio)
   @rut_person          -> RUT del responsable vigente del centro de costo. (Obligatorio)
   @meses_csv           -> Correlativos de sg_fume separados por punto y coma. (Obligatorio)
   @ano_pago            -> Ano en que se paga la cuota. (Obligatorio)
   @mes_pago            -> Mes en que se paga la cuota. (Obligatorio)
   @id_evidenc          -> Identificador del respaldo adjunto. (Opcional)

   Objetivo : Crear un encabezado de cuota en estado 1 (Propuesta) y asociarle
   los meses de ejecucion indicados en sg_dpag.

   Creacion: ELA 2026/10/01
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_epagiSecgen01
    @id_funprse int          = null,
    @rut_person char(9)      = null,
    @meses_csv  varchar(500) = null,
    @ano_pago   smallint     = null,
    @mes_pago   tinyint      = null,
    @id_evidenc int          = null
as

if @id_funprse is null or @id_funprse <= 0
begin
    select 'Falta la prestacion. Se aborta el procedimiento' as msg
    return
end

if @rut_person is null or ltrim(rtrim(@rut_person)) = ''
begin
    select 'Falta el rut del jefe de proyecto. Se aborta el procedimiento' as msg
    return
end

if @meses_csv is null or ltrim(rtrim(@meses_csv)) = ''
begin
    select 'Error: Debe indicar al menos un mes para la cuota' as msg
    return
end

if @ano_pago is null or @ano_pago < 2000 or @ano_pago > 2100
begin
    select 'Error: Ano de pago fuera de rango' as msg
    return
end

if @mes_pago is null or @mes_pago < 1 or @mes_pago > 12
begin
    select 'Error: Mes de pago fuera de rango' as msg
    return
end

select @rut_person = right('000000000' + ltrim(rtrim(@rut_person)), 9)

declare @mes_actual  int
declare @tot_cuotas  tinyint
declare @cuotas_hoy  int
declare @nro_cuota   int
declare @pos         int
declare @chunk       varchar(20)
declare @pedidos     int
declare @validos     int

select @mes_actual = datepart(yy, getdate()) * 100 + datepart(mm, getdate())

if not exists (select 1
                 from secgen_db.dbo.sg_fups fu,
                      secgen_db.dbo.sg_prse prse,
                      secgen_db.dbo.sg_soli soli,
                      fin21_db..es_ecct ecct
                where fu.id_funprse = @id_funprse
                  and prse.nro_solici = fu.nro_solici
                  and soli.nro_solici = fu.nro_solici
                  and ecct.cod_ccto   = prse.cod_ccto
                  and ecct.cod_unifin = prse.cod_unifin
                  and ecct.vigente    = 'S'
                  and ecct.rut        = @rut_person
                  and isnull(prse.cod_modprs, 1) = 2
                  and soli.cod_estsol = 11
                  and soli.nro_resolu is not null)
begin
    select 'La prestacion no existe, no esta archivada o no esta a su cargo' as msg
    return
end

select @tot_cuotas = tot_cuotas
  from secgen_db.dbo.sg_fups
 where id_funprse = @id_funprse

if isnull(@tot_cuotas, 0) <= 0
begin
    select 'Error: La resolucion no tiene cuotas autorizadas para este funcionario' as msg
    return
end

select @cuotas_hoy = count(*)
  from secgen_db.dbo.sg_epag
 where id_funprse = @id_funprse
   and cod_estcuo <> 10

if @cuotas_hoy >= @tot_cuotas
begin
    select 'Error: La resolucion no autoriza mas cuotas para este funcionario' as msg
    return
end

create table #corr (
    corr_fume tinyint not null
)

select @meses_csv = ltrim(rtrim(@meses_csv)) + ';'

while charindex(';', @meses_csv) > 0
begin
    select @pos = charindex(';', @meses_csv)
    select @chunk = ltrim(rtrim(substring(@meses_csv, 1, @pos - 1)))
    select @meses_csv = substring(
        @meses_csv,
        @pos + 1,
        char_length(@meses_csv) - @pos
    )

    if @chunk <> ''
    begin
        if patindex('%[^0-9]%', @chunk) > 0
        begin
            select 'Error: Correlativo de mes no numerico' as msg
            return
        end

        if convert(int, @chunk) < 1 or convert(int, @chunk) > 255
        begin
            select 'Error: Correlativo de mes fuera de rango' as msg
            return
        end

        if exists (select 1 from #corr where corr_fume = convert(tinyint, @chunk))
        begin
            select 'Error: Mes repetido en la cuota' as msg
            return
        end

        insert into #corr (corr_fume) values (convert(tinyint, @chunk))
    end
end

select @pedidos = count(*) from #corr

if @pedidos = 0
begin
    select 'Error: Debe indicar al menos un mes para la cuota' as msg
    return
end

select @validos = count(*)
  from #corr c,
       secgen_db.dbo.sg_fume fume,
       secgen_db.dbo.sg_fups fu
 where fume.id_funprse = @id_funprse
   and fume.corr_fume  = c.corr_fume
   and fu.id_funprse   = fume.id_funprse
   and fume.cod_estfum = 1
   and ((fume.ano_prop * 100 + fume.mes_prop) < @mes_actual
        or fu.f_termino < getdate())

if @validos <> @pedidos
begin
    select 'Error: Algun mes no existe, no esta propuesto o su ejecucion no ha terminado' as msg
    return
end

if exists (select 1
             from #corr c,
                  secgen_db.dbo.sg_dpag dpag
            where dpag.id_funprse = @id_funprse
              and dpag.corr_fume  = c.corr_fume)
begin
    select 'Error: Algun mes ya esta asignado a otra cuota' as msg
    return
end

begin tran

select @cuotas_hoy = count(*)
  from secgen_db.dbo.sg_epag holdlock
 where id_funprse = @id_funprse
   and cod_estcuo <> 10

if @cuotas_hoy >= @tot_cuotas
begin
    select 'Error: La resolucion no autoriza mas cuotas para este funcionario' as msg
    if @@transtate = 2
        rollback tran
    return
end

select @nro_cuota = isnull(max(nro_cuota), 0) + 1
  from secgen_db.dbo.sg_epag holdlock
 where id_funprse = @id_funprse

if @nro_cuota > 255
begin
    select 'Error: Se alcanzo el maximo de cuotas registrables' as msg
    if @@transtate = 2
        rollback tran
    return
end

if exists (
    select 1
      from #corr c,
           secgen_db.dbo.sg_dpag dpag holdlock
     where dpag.id_funprse = @id_funprse
       and dpag.corr_fume  = c.corr_fume
)
begin
    select 'Error: Algun mes fue tomado por otra cuota mientras se guardaba' as msg
    if @@transtate = 2
        rollback tran
    return
end

insert into secgen_db.dbo.sg_epag (
    id_funprse,
    nro_cuota,
    cod_estcuo,
    rut_solici,
    fec_solici,
    id_evidenc,
    ano_pago,
    mes_pago
)
values (
    @id_funprse,
    convert(tinyint, @nro_cuota),
    1,
    @rut_person,
    getdate(),
    @id_evidenc,
    @ano_pago,
    @mes_pago
)

if @@error <> 0
begin
    select 'Error al crear el encabezado de la cuota' as msg
    if @@transtate = 2
        rollback tran
    return
end

insert into secgen_db.dbo.sg_dpag (id_funprse, nro_cuota, corr_fume)
select @id_funprse, convert(tinyint, @nro_cuota), corr_fume
  from #corr

if @@error <> 0
begin
    select 'Error al asociar los meses a la cuota' as msg
    if @@transtate = 2
        rollback tran
    return
end

commit tran

select 1 as status, 'OK' as code, 'Cuota creada correctamente' as msg,
       @nro_cuota as nro_cuota
go

grant execute on Analisis2.sg_epagiSecgen01 to UsuaVrac
go
