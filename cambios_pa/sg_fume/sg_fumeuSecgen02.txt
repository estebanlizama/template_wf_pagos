use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_fumeuSecgen02')
   drop procedure Analisis2.sg_fumeuSecgen02

go

/* Procedimiento : sg_fumeuSecgen02

   Entrada :
   @id_funprse          -> Prestacion del funcionario. (Obligatorio)
   @corr_fume           -> Correlativo del mes. (Obligatorio)
   @rut_person          -> RUT del responsable vigente del centro de costo. (Obligatorio)
   @mto_apagar          -> Monto que la cuota pagara por este mes. (Obligatorio)
   @ano_ejec            -> Ano de ejecucion real. (Opcional)
   @mes_ejec            -> Mes de ejecucion real. (Opcional)

   Objetivo : Fijar el monto a pagar y la ejecucion real de un mes de
   ejecucion.

   Creacion: ELA 2026/10/01
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_fumeuSecgen02
    @id_funprse int = null,
    @corr_fume tinyint = null,
    @rut_person char(9) = null,
    @mto_apagar int = null,
    @ano_ejec smallint = null,
    @mes_ejec tinyint = null
as
if @id_funprse is null or @id_funprse <= 0
begin
    select 'Falta la prestacion. Se aborta el procedimiento' msg return
end

if @corr_fume is null or @corr_fume <= 0
begin
    select 'Falta el correlativo del mes. Se aborta el procedimiento' msg return
end

if @rut_person is null or ltrim(rtrim(@rut_person)) = ''
begin
    select 'Falta el rut del jefe de proyecto. Se aborta el procedimiento' msg return
end

if @mto_apagar is null or @mto_apagar <= 0
begin
    select 'Error: El monto a pagar debe ser mayor que cero' msg return
end

if @ano_ejec is not null and (@ano_ejec < 2000 or @ano_ejec > 2100)
begin
    select 'Error: Ano de ejecucion fuera de rango' msg return
end

if @mes_ejec is not null and (@mes_ejec < 1 or @mes_ejec > 12)
begin
    select 'Error: Mes de ejecucion fuera de rango' msg return
end

select @rut_person = right('000000000' + ltrim(rtrim(@rut_person)), 9)

declare @cod_estfum tinyint
declare @cod_estcuo tinyint

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

select @cod_estfum = cod_estfum
  from secgen_db.dbo.sg_fume
 where id_funprse = @id_funprse
   and corr_fume  = @corr_fume

if @cod_estfum is null
begin
    select 'El mes indicado no existe' msg return
end

select @cod_estcuo = epag.cod_estcuo
  from secgen_db.dbo.sg_dpag dpag,
       secgen_db.dbo.sg_epag epag
 where dpag.id_funprse = @id_funprse
   and dpag.corr_fume  = @corr_fume
   and epag.id_funprse = dpag.id_funprse
   and epag.nro_cuota  = dpag.nro_cuota

if @cod_estfum <> 1 and isnull(@cod_estcuo, 0) <> 3
begin
    select 'Error: El mes ya no admite cambios de monto' msg return
end

update secgen_db.dbo.sg_fume
   set mto_apagar = @mto_apagar,
       ano_ejec   = isnull(@ano_ejec, ano_ejec),
       mes_ejec   = isnull(@mes_ejec, mes_ejec)
 where id_funprse = @id_funprse
   and corr_fume  = @corr_fume

if @@error <> 0
begin
    select 'Error al actualizar el monto del mes' msg return
end

select 1 as status, 'OK' as code, 'Monto del mes actualizado correctamente' as msg
go

grant execute on Analisis2.sg_fumeuSecgen02 to UsuaVrac
go
