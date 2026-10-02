use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_ecuosSecgen01')
   drop procedure Analisis2.sg_ecuosSecgen01

go

/* Procedimiento : sg_ecuosSecgen01

   Objetivo : Listar los estados del encabezado de la cuota de pago.
   Catalogo de sg_epag.cod_estcuo, distinto del catalogo del mes (sg_efum).

   Creacion: ELA 2026/10/01
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_ecuosSecgen01
as
begin
    select
        cod_estcuo,
        des_estcuo
    from secgen_db.dbo.sg_ecuo
    order by cod_estcuo
end
go

grant execute on Analisis2.sg_ecuosSecgen01 to UsuaVrac
go
