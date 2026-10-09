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
   ejecucion. Valida que la cuota no quede sobre el tope y versiona en
   sg_fum2 el estado anterior del mes cuando el monto cambia.

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
declare @nro_cuota  int
declare @ext_cuotas char(1)
declare @mto_tope   int
declare @mto_otros  int
declare @mto_actual int
declare @correlativ int

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

select @cod_estcuo = epag.cod_estcuo,
       @nro_cuota  = epag.nro_cuota
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

select @ext_cuotas = isnull(ext_cuotas, 'N'),
       @mto_tope   = isnull(mto_tope, 0)
  from secgen_db.dbo.sg_fups
 where id_funprse = @id_funprse

if @nro_cuota is not null and @ext_cuotas <> 'S' and @mto_tope > 0
begin
    select @mto_otros = isnull(sum(fume.mto_apagar), 0)
      from secgen_db.dbo.sg_dpag dpag,
           secgen_db.dbo.sg_fume fume
     where dpag.id_funprse = @id_funprse
       and dpag.nro_cuota  = @nro_cuota
       and dpag.corr_fume <> @corr_fume
       and fume.id_funprse = dpag.id_funprse
       and fume.corr_fume  = dpag.corr_fume

    if @mto_otros + @mto_apagar > @mto_tope
    begin
        select 'Error: El monto deja la cuota sobre el tope autorizado' msg return
    end
end

select @mto_actual = isnull(mto_apagar, 0)
  from secgen_db.dbo.sg_fume
 where id_funprse = @id_funprse
   and corr_fume  = @corr_fume

begin tran

if @mto_actual <> @mto_apagar
begin
    select @correlativ = isnull(max(correlativ), 0) + 1
      from secgen_db.dbo.sg_fum2 holdlock
     where id_funprse = @id_funprse
       and corr_fume  = @corr_fume

    if @correlativ > 255
    begin
        select 'Error: Se alcanzo el maximo de versiones del mes' msg
        if @@transtate = 2
            rollback tran
        return
    end

    insert into secgen_db.dbo.sg_fum2 (
        id_funprse,
        corr_fume,
        correlativ,
        ano_prop,
        mes_prop,
        cod_estcuo,
        ano_ejec,
        mes_ejec,
        mto_apagar,
        id_evidenc,
        val_licmed,
        val_inabili,
        val_singoce,
        val_ciecc,
        fec_valida,
        rut_autori,
        fec_autori,
        fec_envrem
    )
    select
        id_funprse,
        corr_fume,
        @correlativ,
        ano_prop,
        mes_prop,
        cod_estfum,
        ano_ejec,
        mes_ejec,
        mto_apagar,
        id_evidenc,
        val_licmed,
        val_inabili,
        val_singoce,
        val_ciecc,
        fec_valida,
        rut_autori,
        fec_autori,
        fec_envrem
      from secgen_db.dbo.sg_fume
     where id_funprse = @id_funprse
       and corr_fume  = @corr_fume

    if @@error <> 0
    begin
        select 'Error al versionar el mes antes de cambiar el monto' msg
        if @@transtate = 2
            rollback tran
        return
    end
end

update secgen_db.dbo.sg_fume
   set mto_apagar = @mto_apagar,
       ano_ejec   = isnull(@ano_ejec, ano_ejec),
       mes_ejec   = isnull(@mes_ejec, mes_ejec)
 where id_funprse = @id_funprse
   and corr_fume  = @corr_fume

if @@error <> 0
begin
    select 'Error al actualizar el monto del mes' msg
    if @@transtate = 2
        rollback tran
    return
end

commit tran

select 1 as status, 'OK' as code, 'Monto del mes actualizado correctamente' as msg
go

grant execute on Analisis2.sg_fumeuSecgen02 to UsuaVrac
go
