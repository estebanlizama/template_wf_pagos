use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_efumsSecgen02')
   drop procedure Analisis2.sg_efumsSecgen02

go

/* Procedimiento : sg_efumsSecgen02

   Entrada :
   @cod_estfum          -> Codigo del estado del mes de ejecucion. (Obligatorio)

   Objetivo : Obtener un estado del mes de ejecucion por su codigo.

   Creacion: ELA 2026/09/25
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_efumsSecgen02
    @cod_estfum tinyint = null
as
begin
    if @cod_estfum is null
    begin
        select 'Falta campo Codigo de Estado' as msg
        return
    end

    select
        cod_estfum,
        des_estfum
    from secgen_db.dbo.sg_efum
    where cod_estfum = @cod_estfum
end
go

grant execute on Analisis2.sg_efumsSecgen02 to UsuaVrac
go
