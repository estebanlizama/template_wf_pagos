use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_ecuouSecgen01')
   drop procedure Analisis2.sg_ecuouSecgen01

go

/* Procedimiento : sg_ecuouSecgen01

   Entrada :
   @cod_estcuo          -> Codigo del estado de la cuota de pago. (Obligatorio)
   @des_estcuo          -> Nueva descripcion del estado. (Obligatorio)

   Objetivo : Actualizar la descripcion de un estado de la cuota de pago.
   El codigo no se modifica: es la llave que referencia sg_epag.

   Creacion: ELA 2026/10/01
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_ecuouSecgen01
    @cod_estcuo tinyint = null,
    @des_estcuo varchar(60) = null
as

if @cod_estcuo is null
begin
    select 'Falta campo Codigo de Estado' as msg
    return
end

if @des_estcuo is null or ltrim(rtrim(@des_estcuo)) = ''
begin
    select 'Falta campo Descripcion de Estado' as msg
    return
end

if not exists (select 1 from secgen_db.dbo.sg_ecuo where cod_estcuo = @cod_estcuo)
begin
    select 'El estado indicado no se encuentra registrado' as msg
    return
end

begin tran

update secgen_db.dbo.sg_ecuo
   set des_estcuo = ltrim(rtrim(@des_estcuo))
 where cod_estcuo = @cod_estcuo

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

grant execute on Analisis2.sg_ecuouSecgen01 to UsuaVrac
go
