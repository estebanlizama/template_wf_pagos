use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_epagdSecgen01')
   drop procedure Analisis2.sg_epagdSecgen01

go

/* Procedimiento : sg_epagdSecgen01

   Entrada :
   @id_funprse          -> Prestacion del funcionario. (Obligatorio)
   @nro_cuota           -> Numero de cuota a eliminar. (Obligatorio)
   @rut_person          -> RUT del responsable vigente del centro de costo. (Obligatorio)

   Objetivo : Eliminar una cuota en borrador y liberar los meses de
   ejecucion que tenia asociados.

   Creacion: ELA 2026/10/01
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_epagdSecgen01
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

declare @cod_estcuo tinyint

if not exists (select 1
                 from secgen_db.dbo.sg_fups fu,
                      secgen_db.dbo.sg_prse prse,
                      fin21_db..es_ecct ecct
                where fu.id_funprse = @id_funprse
                  and prse.nro_solici = fu.nro_solici
                  and ecct.cod_ccto   = prse.cod_ccto
                  and ecct.cod_unifin = prse.cod_unifin
                  and ecct.vigente    = 'S'
                  and ecct.rut        = @rut_person)
begin
    select 'La prestacion no existe o no esta a su cargo' msg return
end

select @cod_estcuo = cod_estcuo
  from secgen_db.dbo.sg_epag
 where id_funprse = @id_funprse
   and nro_cuota  = @nro_cuota

if @cod_estcuo is null
begin
    select 'La cuota indicada no existe' msg return
end

if @cod_estcuo <> 1
begin
    select 'Error: Solo se puede eliminar una cuota en borrador' msg return
end

begin tran

delete secgen_db.dbo.sg_dpag
 where id_funprse = @id_funprse
   and nro_cuota  = @nro_cuota

if @@error <> 0
begin
    select 'Error al desasociar los meses de la cuota' msg
    if @@transtate = 2 rollback tran
    return
end

delete secgen_db.dbo.sg_epag
 where id_funprse = @id_funprse
   and nro_cuota  = @nro_cuota

if @@error <> 0
begin
    select 'Error al eliminar el encabezado de la cuota' msg
    if @@transtate = 2 rollback tran
    return
end

commit tran

select 1 as status, 'OK' as code, 'Cuota eliminada correctamente' as msg
go

grant execute on Analisis2.sg_epagdSecgen01 to UsuaVrac
go
