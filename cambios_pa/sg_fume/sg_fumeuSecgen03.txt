use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_fumeuSecgen03')
   drop procedure Analisis2.sg_fumeuSecgen03

go

/* Procedimiento : sg_fumeuSecgen03

   Entrada :
   @rut_person          -> RUT del revisor DGDP. (Obligatorio)
   @id_funprse          -> Prestacion del funcionario. (Obligatorio)
   @corr_fume           -> Correlativo del mes. (Obligatorio)
   @mto_deslic          -> Descuento por licencia medica. (Obligatorio)
   @mto_dessg           -> Descuento por permiso sin goce. (Obligatorio)

   Objetivo : Registrar los descuentos de un mes durante la visacion DGDP y
   dejar el monto resultante en mto_realpa.

   Creacion: ELA 2026/10/07
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_fumeuSecgen03
    @rut_person char(9) = null,
    @id_funprse int     = null,
    @corr_fume  tinyint = null,
    @mto_deslic int     = null,
    @mto_dessg  int     = null
as

if @rut_person is null or ltrim(rtrim(@rut_person)) = '' or isnull(@id_funprse, 0) <= 0 or isnull(@corr_fume, 0) <= 0
begin
    select 'Faltan antecedentes para registrar los descuentos' as msg
    return
end

if isnull(@mto_deslic, -1) < 0 or isnull(@mto_dessg, -1) < 0
begin
    select 'Error: Los descuentos no pueden ser negativos' as msg
    return
end

select @rut_person = right('000000000' + ltrim(rtrim(@rut_person)), 9)

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

declare @mto_apagar int
declare @cod_estcuo tinyint

select @mto_apagar = mto_apagar
  from secgen_db.dbo.sg_fume
 where id_funprse = @id_funprse
   and corr_fume  = @corr_fume

if @mto_apagar is null
begin
    select 'El mes indicado no existe en la prestacion' as msg
    return
end

select @cod_estcuo = epag.cod_estcuo
  from secgen_db.dbo.sg_dpag dpag,
       secgen_db.dbo.sg_epag epag
 where dpag.id_funprse = @id_funprse
   and dpag.corr_fume  = @corr_fume
   and epag.id_funprse = dpag.id_funprse
   and epag.nro_cuota  = dpag.nro_cuota

if isnull(@cod_estcuo, 0) <> 2
begin
    select 'Solo se pueden registrar descuentos mientras la cuota esta en visacion' as msg
    return
end

if @mto_deslic + @mto_dessg > @mto_apagar
begin
    select 'Error: Los descuentos no pueden superar el monto solicitado del mes' as msg
    return
end

begin tran

update secgen_db.dbo.sg_fume
   set mto_deslic  = @mto_deslic,
       mto_dessg   = @mto_dessg,
       mto_realpa  = @mto_apagar - @mto_deslic - @mto_dessg,
       val_licmed  = case when @mto_deslic > 0 then 'S' else 'N' end,
       val_singoce = case when @mto_dessg  > 0 then 'S' else 'N' end,
       fec_valida  = getdate()
 where id_funprse = @id_funprse
   and corr_fume  = @corr_fume

if @@error <> 0 or @@rowcount <> 1
begin
    select 'Error al registrar los descuentos del mes' as msg
    if @@transtate = 2
        rollback tran
    return
end

commit tran

select 1 as status, 'OK' as code, 'Descuentos registrados correctamente' as msg,
       @mto_apagar - @mto_deslic - @mto_dessg as mto_realpa
go

grant execute on Analisis2.sg_fumeuSecgen03 to UsuaVrac
go
