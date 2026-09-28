use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_efumuSecgen01')
   drop procedure Analisis2.sg_efumuSecgen01

go

/* Procedimiento : sg_efumuSecgen01

   Entrada :
   @cod_estfum          -> Codigo del estado del mes de ejecucion. (Obligatorio)
   @des_estfum          -> Nueva descripcion del estado. (Obligatorio)

   Objetivo : Actualizar la descripcion de un estado del mes de ejecucion.
   El codigo no se modifica: es la llave que referencia sg_fume.

   Creacion: ELA 2026/09/25
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_efumuSecgen01
    @cod_estfum tinyint = null,
    @des_estfum varchar(60) = null
as

if @cod_estfum is null
begin
    select 'Falta campo Codigo de Estado' as msg
    return
end

if @des_estfum is null or ltrim(rtrim(@des_estfum)) = ''
begin
    select 'Falta campo Descripcion de Estado' as msg
    return
end

if not exists (select 1 from secgen_db.dbo.sg_efum where cod_estfum = @cod_estfum)
begin
    select 'El estado indicado no se encuentra registrado' as msg
    return
end

begin tran

update secgen_db.dbo.sg_efum
   set des_estfum = ltrim(rtrim(@des_estfum))
 where cod_estfum = @cod_estfum

if @@transtate = 2 or @@transtate = 3
begin
    select 'Error al actualizar el estado. Se aborta el procedimiento' as msg
    if @@transtate = 2
        rollback tran
    return
end

commit tran

select 'Estado actualizado correctamente' as msg
go

grant execute on Analisis2.sg_efumuSecgen01 to UsuaVrac
go
