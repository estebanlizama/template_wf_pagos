use secgen_db
go

if exists (select 1
             from sysobjects a, sysusers b
            where a.uid = b.uid
              and a.type = 'P'
              and b.name = 'Analisis2'
              and a.name = 'sg_epaguSecgen01')
begin
    drop procedure Analisis2.sg_epaguSecgen01
end
go

/* Procedimiento : sg_epaguSecgen01

   Entrada :
   @id_funprse          -> Prestacion del funcionario. (Obligatorio)
   @nro_cuota           -> Numero de cuota a modificar. (Obligatorio)
   @rut_person          -> RUT del responsable vigente del centro de costo. (Obligatorio)
   @meses_csv           -> Correlativos de sg_fume separados por punto y coma. (Obligatorio)
   @ano_pago            -> Ano en que se paga la cuota. (Obligatorio)
   @mes_pago            -> Mes en que se paga la cuota. (Obligatorio)
   @id_evidenc          -> Identificador del respaldo adjunto. (Opcional)

   Objetivo : Modifica un encabezado de cuota y el conjunto de meses que
   abarca, mientras siga siendo editable.

   Editable es cod_estcuo 1 (Propuesta) o 3 (Observada). La 3 se incluye a
   proposito: devolver una cuota para que la corrijan y dejarla de solo lectura
   seria devolverla a ninguna parte.

   Los meses se reemplazan completos en vez de aplicar diferencias: el conjunto
   es chico y una sustitucion no puede dejar una asociacion huerfana si el
   cliente manda una lista incompleta.

   En estado 1 ningun mes de la cuota esta comprometido, asi que el reemplazo
   no toca cod_estfum. En estado 3 los meses siguen comprometidos porque
   observar no libera, de modo que se exige que la lista nueva sea del mismo
   conjunto: cambiar los meses de una cuota ya enviada es rechazarla y rehacerla.

   Creacion: ELA 2026/10/01
*/

create procedure Analisis2.sg_epaguSecgen01
    @id_funprse int          = NULL,
    @nro_cuota  tinyint      = NULL,
    @rut_person char(9)      = NULL,
    @meses_csv  varchar(500) = NULL,
    @ano_pago   smallint     = NULL,
    @mes_pago   tinyint      = NULL,
    @id_evidenc int          = NULL
as
if @id_funprse is null or @id_funprse <= 0
begin
    select 'Falta la prestacion. Se aborta el procedimiento' msg return
end

if @nro_cuota is null or @nro_cuota <= 0
begin
    select 'Falta el numero de cuota. Se aborta el procedimiento' msg return
end

if @rut_person is null or ltrim(rtrim(@rut_person)) = ''
begin
    select 'Falta el rut del jefe de proyecto. Se aborta el procedimiento' msg return
end

if @meses_csv is null or ltrim(rtrim(@meses_csv)) = ''
begin
    select 'Error: Debe indicar al menos un mes para la cuota' msg return
end

if @ano_pago is null or @ano_pago < 2000 or @ano_pago > 2100
begin
    select 'Error: Ano de pago fuera de rango' msg return
end

if @mes_pago is null or @mes_pago < 1 or @mes_pago > 12
begin
    select 'Error: Mes de pago fuera de rango' msg return
end

select @rut_person = right('000000000' + ltrim(rtrim(@rut_person)), 9)

declare @mes_actual int
declare @cod_estcuo tinyint
declare @pos        int
declare @chunk      varchar(20)
declare @pedidos    int
declare @validos    int
declare @actuales   int
declare @comunes    int

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
                  and soli.cod_estsol = 11)
begin
    select 'La prestacion no existe, no esta archivada o no esta a su cargo' msg return
end

select @cod_estcuo = cod_estcuo
  from secgen_db.dbo.sg_epag
 where id_funprse = @id_funprse
   and nro_cuota  = @nro_cuota

if @cod_estcuo is null
begin
    select 'La cuota indicada no existe' msg return
end

if @cod_estcuo not in (1, 3)
begin
    select 'Error: La cuota ya no es editable' msg return
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
            select 'Error: Correlativo de mes no numerico' msg return
        end

        if convert(int, @chunk) < 1 or convert(int, @chunk) > 255
        begin
            select 'Error: Correlativo de mes fuera de rango' msg return
        end

        if exists (select 1 from #corr where corr_fume = convert(tinyint, @chunk))
        begin
            select 'Error: Mes repetido en la cuota' msg return
        end

        insert into #corr (corr_fume) values (convert(tinyint, @chunk))
    end
end

select @pedidos = count(*) from #corr

if @pedidos = 0
begin
    select 'Error: Debe indicar al menos un mes para la cuota' msg return
end

select @actuales = count(*)
  from secgen_db.dbo.sg_dpag
 where id_funprse = @id_funprse
   and nro_cuota  = @nro_cuota

select @comunes = count(*)
  from #corr c,
       secgen_db.dbo.sg_dpag dpag
 where dpag.id_funprse = @id_funprse
   and dpag.nro_cuota  = @nro_cuota
   and dpag.corr_fume  = c.corr_fume

if @cod_estcuo = 3 and (@pedidos <> @actuales or @comunes <> @actuales)
begin
    select 'Error: Una cuota observada no puede cambiar los meses que abarca' msg return
end

select @validos = count(*)
  from #corr c,
       secgen_db.dbo.sg_fume fume,
       secgen_db.dbo.sg_fups fu
 where fume.id_funprse = @id_funprse
   and fume.corr_fume  = c.corr_fume
   and fu.id_funprse   = fume.id_funprse
   and ((fume.cod_estfum = 1
         and ((fume.ano_prop * 100 + fume.mes_prop) < @mes_actual
              or fu.f_termino < getdate()))
        or exists (select 1
                     from secgen_db.dbo.sg_dpag d2
                    where d2.id_funprse = @id_funprse
                      and d2.nro_cuota  = @nro_cuota
                      and d2.corr_fume  = c.corr_fume))

if @validos <> @pedidos
begin
    select 'Error: Algun mes no existe, no esta propuesto o su ejecucion no ha terminado' msg return
end

if exists (select 1
             from #corr c,
                  secgen_db.dbo.sg_dpag dpag
            where dpag.id_funprse = @id_funprse
              and dpag.corr_fume  = c.corr_fume
              and dpag.nro_cuota <> @nro_cuota)
begin
    select 'Error: Algun mes ya esta asignado a otra cuota' msg return
end

begin tran

update secgen_db.dbo.sg_epag
   set ano_pago   = @ano_pago,
       mes_pago   = @mes_pago,
       id_evidenc = @id_evidenc
 where id_funprse = @id_funprse
   and nro_cuota  = @nro_cuota

if @@error <> 0
begin
    select 'Error al actualizar el encabezado de la cuota' msg
    if @@transtate = 2 rollback tran
    return
end

delete secgen_db.dbo.sg_dpag
 where id_funprse = @id_funprse
   and nro_cuota  = @nro_cuota

if @@error <> 0
begin
    select 'Error al desasociar los meses de la cuota' msg
    if @@transtate = 2 rollback tran
    return
end

insert into secgen_db.dbo.sg_dpag (id_funprse, nro_cuota, corr_fume)
select @id_funprse, @nro_cuota, corr_fume
  from #corr

if @@error <> 0
begin
    select 'Error al asociar los meses a la cuota' msg
    if @@transtate = 2 rollback tran
    return
end

commit tran

select 'Cuota actualizada correctamente' msg
go

grant execute on Analisis2.sg_epaguSecgen01 to UsuaVrac
go
