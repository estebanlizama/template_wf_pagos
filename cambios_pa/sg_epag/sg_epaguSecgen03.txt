use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
            where a.uid = b.uid
              and a.type = 'P'
              and b.name = 'Analisis2'
              and a.name = 'sg_epaguSecgen03')
    drop procedure Analisis2.sg_epaguSecgen03
go

/* Procedimiento : sg_epaguSecgen03

   Entrada :
   @rut_person          -> RUT del revisor DGDP. (Obligatorio)
   @id_funprse          -> Prestacion del funcionario. (Obligatorio)
   @nro_cuota           -> Correlativo de la cuota. (Obligatorio)
   @cod_estcuo          -> Estado de destino: 3, 4 o 10. (Obligatorio)
   @observacion         -> Motivo de observacion o rechazo. (Condicional)

   Objetivo : Registrar la decision DGDP de una cuota en visacion.

   Creacion: ELA 2026/10/06
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_epaguSecgen03
    @rut_person char(9) = null,
    @id_funprse int = null,
    @nro_cuota tinyint = null,
    @cod_estcuo tinyint = null,
    @observacion varchar(255) = null
as

if @rut_person is null or ltrim(rtrim(@rut_person)) = '' or isnull(@id_funprse, 0) <= 0 or isnull(@nro_cuota, 0) <= 0
begin
    select 'Faltan antecedentes para resolver la cuota.' as msg
    return
end
if @cod_estcuo is null or @cod_estcuo not in (3, 4, 10)
begin
    select 'La resolucion indicada no es valida.' as msg
    return
end
if @cod_estcuo in (3, 10) and ltrim(rtrim(isnull(@observacion, ''))) = ''
begin
    select 'Ingrese el motivo de la observacion o rechazo.' as msg
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

begin transaction
if not exists (
    select 1
      from dbo.sg_epag holdlock
     where id_funprse = @id_funprse
       and nro_cuota = @nro_cuota
       and cod_estcuo = 2
)
begin
    rollback transaction
    select 'La cuota ya no esta en visacion.' as msg
    return
end

if @cod_estcuo = 10
begin
    update dbo.sg_fume
       set cod_estfum = 1
      from dbo.sg_fume fume,
           dbo.sg_dpag dpag
     where dpag.id_funprse = fume.id_funprse
       and dpag.corr_fume = fume.corr_fume
       and dpag.id_funprse = @id_funprse
       and dpag.nro_cuota = @nro_cuota
       and fume.cod_estfum = 2

    delete dbo.sg_dpag
     where id_funprse = @id_funprse and nro_cuota = @nro_cuota
end

update dbo.sg_epag
   set cod_estcuo = @cod_estcuo
 where id_funprse = @id_funprse
   and nro_cuota = @nro_cuota
   and cod_estcuo = 2

if @@rowcount <> 1
begin
    rollback transaction
    select 'La cuota ya no esta en visacion.' as msg
    return
end
commit transaction
select 1 as status, 'OK' as code, 'La resolucion DGDP se registro correctamente.' as msg
go

grant execute on Analisis2.sg_epaguSecgen03 to UsuaVrac
go
