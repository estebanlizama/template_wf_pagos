use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_efumsSecgen01')
   drop procedure Analisis2.sg_efumsSecgen01

go

/* Procedimiento : sg_efumsSecgen01

   Objetivo : Listar los estados del mes de ejecucion de una prestacion de
   servicios. Catalogo de sg_fume.cod_estfum, distinto del catalogo de la
   cuota de pago (sg_ecuo).

   Creacion: ELA 2026/09/25
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_efumsSecgen01
as
begin
    select
        cod_estfum,
        des_estfum
    from secgen_db.dbo.sg_efum
    order by cod_estfum
end
go

grant execute on Analisis2.sg_efumsSecgen01 to UsuaVrac
go
