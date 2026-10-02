use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_epaguSecgen02')
   drop procedure Analisis2.sg_epaguSecgen02

go

/* Procedimiento : sg_epaguSecgen02

   Entrada :
   @id_funprse          -> Prestacion del funcionario. (Obligatorio)
   @nro_cuota           -> Numero de cuota a enviar. (Obligatorio)
   @rut_person          -> RUT del responsable vigente del centro de costo. (Obligatorio)

   Objetivo : Enviar una cuota a visacion de DGDP, comprometiendo sus meses
   de ejecucion en la misma transaccion.

   Creacion: ELA 2026/10/01
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_epaguSecgen02
    @id_funprse int = null,
    @nro_cuota tinyint = null,
    @rut_person char(9) = null
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

select @rut_person = right('000000000' + ltrim(rtrim(@rut_person)), 9)

declare @mes_actual int
declare @cod_estcuo tinyint
declare @cant_meses int
declare @sin_monto  int
declare @mal_estado int
declare @mto_cuota  int
declare @mto_total  decimal(19,2)
declare @mto_usado  int

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
    select 'Error: La cuota no esta en un estado que permita enviarla' msg return
end

select @cant_meses = count(*)
  from secgen_db.dbo.sg_dpag
 where id_funprse = @id_funprse
   and nro_cuota  = @nro_cuota

if @cant_meses = 0
begin
    select 'Error: La cuota no tiene meses asociados' msg return
end

select @sin_monto = count(*)
  from secgen_db.dbo.sg_dpag dpag,
       secgen_db.dbo.sg_fume fume
 where dpag.id_funprse = @id_funprse
   and dpag.nro_cuota  = @nro_cuota
   and fume.id_funprse = dpag.id_funprse
   and fume.corr_fume  = dpag.corr_fume
   and isnull(fume.mto_apagar, 0) <= 0

if @sin_monto > 0
begin
    select 'Error: Hay meses de la cuota sin monto a pagar' msg return
end

if @cod_estcuo = 1
begin
    select @mal_estado = count(*)
      from secgen_db.dbo.sg_dpag dpag,
           secgen_db.dbo.sg_fume fume,
           secgen_db.dbo.sg_fups fu
     where dpag.id_funprse = @id_funprse
       and dpag.nro_cuota  = @nro_cuota
       and fume.id_funprse = dpag.id_funprse
       and fume.corr_fume  = dpag.corr_fume
       and fu.id_funprse   = fume.id_funprse
       and (fume.cod_estfum <> 1
            or ((fume.ano_prop * 100 + fume.mes_prop) >= @mes_actual
                and fu.f_termino >= getdate()))

    if @mal_estado > 0
    begin
        select 'Error: Algun mes dejo de estar disponible. Revise la cuota' msg return
    end
end

select @mto_cuota = isnull(sum(fume.mto_apagar), 0)
  from secgen_db.dbo.sg_dpag dpag,
       secgen_db.dbo.sg_fume fume
 where dpag.id_funprse = @id_funprse
   and dpag.nro_cuota  = @nro_cuota
   and fume.id_funprse = dpag.id_funprse
   and fume.corr_fume  = dpag.corr_fume

select @mto_total = mto_total
  from secgen_db.dbo.sg_fups
 where id_funprse = @id_funprse

select @mto_usado = isnull(sum(case when fume.cod_estfum = 3 then fume.mto_realpa else 0 end), 0)
                  + isnull(sum(case when fume.cod_estfum = 2
                                     and not exists (select 1
                                                       from secgen_db.dbo.sg_dpag d2
                                                      where d2.id_funprse = fume.id_funprse
                                                        and d2.corr_fume  = fume.corr_fume
                                                        and d2.nro_cuota  = @nro_cuota)
                                    then fume.mto_apagar else 0 end), 0)
  from secgen_db.dbo.sg_fume fume
 where fume.id_funprse = @id_funprse

if @mto_usado + @mto_cuota > @mto_total
begin
    select 'Error: El monto de la cuota excede el total autorizado de la prestacion' msg return
end

begin tran

update secgen_db.dbo.sg_epag
   set cod_estcuo = 2,
       rut_solici = @rut_person,
       fec_solici = getdate()
 where id_funprse = @id_funprse
   and nro_cuota  = @nro_cuota

if @@error <> 0
begin
    select 'Error al enviar la cuota a visacion' msg
    if @@transtate = 2 rollback tran
    return
end

if @cod_estcuo = 1
begin
    update secgen_db.dbo.sg_fume
       set cod_estfum = 2
      from secgen_db.dbo.sg_fume fume,
           secgen_db.dbo.sg_dpag dpag
     where dpag.id_funprse = @id_funprse
       and dpag.nro_cuota  = @nro_cuota
       and fume.id_funprse = dpag.id_funprse
       and fume.corr_fume  = dpag.corr_fume

    if @@error <> 0
    begin
        select 'Error al comprometer los meses de la cuota' msg
        if @@transtate = 2 rollback tran
        return
    end
end

commit tran

select 1 as status, 'OK' as code, 'Cuota enviada a visacion correctamente' as msg,
       @mto_cuota as mto_cuota
go

grant execute on Analisis2.sg_epaguSecgen02 to UsuaVrac
go
