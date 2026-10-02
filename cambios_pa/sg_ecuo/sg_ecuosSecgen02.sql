use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_ecuosSecgen02')
   drop procedure Analisis2.sg_ecuosSecgen02

go

/* Procedimiento : sg_ecuosSecgen02

   Entrada :
   @cod_estcuo          -> Codigo del estado de la cuota de pago. (Obligatorio)

   Objetivo : Obtener un estado de la cuota de pago por su codigo.

   Creacion: ELA 2026/10/01
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_ecuosSecgen02
    @cod_estcuo tinyint = null
as
begin
    if @cod_estcuo is null
    begin
        select 'Falta campo Codigo de Estado' as msg
        return
    end

    select
        cod_estcuo,
        des_estcuo
    from secgen_db.dbo.sg_ecuo
    where cod_estcuo = @cod_estcuo
end
go

grant execute on Analisis2.sg_ecuosSecgen02 to UsuaVrac
go
