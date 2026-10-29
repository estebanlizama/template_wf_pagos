use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
            where a.uid = b.uid
              and a.type = 'P'
              and b.name = 'Analisis2'
              and a.name = 'sg_epaguSecgen05')
    drop procedure Analisis2.sg_epaguSecgen05
go

/* Procedimiento : sg_epaguSecgen05

   Entrada :
   @rut_person          -> RUT del revisor DGDP. (Obligatorio)
   @id_funprse          -> Prestacion del funcionario. (Obligatorio)
   @nro_cuota           -> Correlativo de la cuota aprobada. (Obligatorio)
   @observacion         -> Motivo para reabrir la cuota. (Obligatorio)

   Objetivo : Devolver una cuota aprobada (4) a visacion DGDP (2), para que el
   equipo DGDP pueda revisar y ajustar nuevamente sus montos y antecedentes.
   Los meses permanecen comprometidos (sg_fume.cod_estfum = 2). El motivo queda
   en sg_com1 dentro de la misma transaccion.

   Creacion: ELA 2026/10/28
   Actualizacion: 2026/10/29 - Validar accion 34 antes de modificar la cuota.
*/
create procedure Analisis2.sg_epaguSecgen05
    @rut_person char(9) = null,
    @id_funprse int = null,
    @nro_cuota tinyint = null,
    @observacion varchar(255) = null
as

if @rut_person is null or ltrim(rtrim(@rut_person)) = ''
   or isnull(@id_funprse, 0) <= 0 or isnull(@nro_cuota, 0) <= 0
begin
    select 'Faltan antecedentes para reabrir la cuota.' as msg
    return
end

if @observacion is null or ltrim(rtrim(@observacion)) = ''
begin
    select 'Indique el motivo para devolver la cuota a visacion DGDP.' as msg
    return
end

if len(ltrim(rtrim(@observacion))) > 255
begin
    select 'El motivo no puede superar 255 caracteres.' as msg
    return
end

select @rut_person = right('000000000' + ltrim(rtrim(@rut_person)), 9)

if not exists (
    select 1 from sisper_db..sp_pers pers
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

if not exists (select 1 from dbo.sg_tacc where id_tipacc = 34)
begin
    select 'Falta configurar la accion 34 de devolucion de cuota aprobada en sg_tacc.' as msg
    return
end

begin transaction

if not exists (
    select 1
      from dbo.sg_epag holdlock
     where id_funprse = @id_funprse
       and nro_cuota = @nro_cuota
       and cod_estcuo = 4
)
begin
    select 'La cuota ya no esta aprobada o ya fue enviada a Finanzas.' as msg
    if @@transtate = 2 rollback transaction
    return
end

if not exists (
    select 1
      from dbo.sg_dpag dpag
      inner join dbo.sg_fume fume
        on fume.id_funprse = dpag.id_funprse
       and fume.corr_fume = dpag.corr_fume
     where dpag.id_funprse = @id_funprse
       and dpag.nro_cuota = @nro_cuota
       and fume.cod_estfum = 2
)
begin
    select 'La cuota no tiene meses comprometidos para volver a visacion.' as msg
    if @@transtate = 2 rollback transaction
    return
end

if exists (
    select 1
      from dbo.sg_dpag dpag
      inner join dbo.sg_fume fume
        on fume.id_funprse = dpag.id_funprse
       and fume.corr_fume = dpag.corr_fume
     where dpag.id_funprse = @id_funprse
       and dpag.nro_cuota = @nro_cuota
       and fume.cod_estfum <> 2
)
begin
    select 'Los meses asociados a la cuota ya no estan todos comprometidos.' as msg
    if @@transtate = 2 rollback transaction
    return
end

update dbo.sg_epag
   set cod_estcuo = 2
 where id_funprse = @id_funprse
   and nro_cuota = @nro_cuota
   and cod_estcuo = 4

if @@rowcount <> 1
begin
    select 'La cuota ya no esta aprobada o ya fue enviada a Finanzas.' as msg
    if @@transtate = 2 rollback transaction
    return
end

insert into dbo.sg_com1 (
    id_funprse,
    nro_cuota,
    f_observa,
    id_tipacc,
    rut_accion,
    observaci
) values (
    @id_funprse,
    @nro_cuota,
    getdate(),
    34,
    @rut_person,
    @observacion
)

if @@error <> 0
begin
    select 'No fue posible registrar el motivo para reabrir la cuota.' as msg
    if @@transtate = 2 rollback transaction
    return
end

commit transaction
select 1 as status, 'OK' as code, 'La cuota volvio a visacion DGDP.' as msg
go

grant execute on Analisis2.sg_epaguSecgen05 to UsuaVrac
go
