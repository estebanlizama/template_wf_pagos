use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_fupssSecgen14')
   drop procedure Analisis2.sg_fupssSecgen14

go

/* Procedimiento : sg_fupssSecgen14

   Entrada :
   @rut_person          -> RUT de la persona. (Obligatorio)
   @id_contrato         -> Identificador del contrato. (Opcional)
   @cod_cargo           -> Codigo del cargo. (Opcional)
   @cod_unidad          -> Parametro de entrada. (Opcional)
   @cod_calida          -> Parametro de entrada. (Opcional)
   @ext_cuotas          -> Extension de cuotas autorizada S/N. (Opcional)

   Objetivo : Validar si el contrato evaluado para DU288 queda habilitado o no segun calidad juridica, cargo y contexto ANID/externo.

   Creacion: EL 2026/07/03
   Actualizacion: ELA 2026/09/29
*/
create procedure Analisis2.sg_fupssSecgen14
    @rut_person  char(9),
    @id_contrato int = 0,
    @cod_cargo   int = 0,
    @cod_unidad  varchar(8) = '',
    @cod_calida  varchar(2) = '',
    @ext_cuotas  char(1) = 'N'
as
begin
    declare @habilitado_du288 char(1)

    select @habilitado_du288 = 'S'

    select @ext_cuotas = upper(ltrim(rtrim(isnull(@ext_cuotas, 'N'))))
    if @ext_cuotas not in ('S', 'N')
        select @ext_cuotas = 'N'

    if ltrim(rtrim(isnull(@cod_calida, ''))) = '01'
    begin
        select @habilitado_du288 = 'N'
    end
    else if exists (
        select 1
          from sisper_db.dbo.sp_carg c
         where c.cod_cargo = @cod_cargo
           and c.cod_tipcar = '5'
           and c.vigente = '1'
    )
    begin
        select @habilitado_du288 = 'N'
    end

    if @ext_cuotas = 'S' and @cod_cargo = 3110
    begin
        select @habilitado_du288 = 'S'
    end

    select @habilitado_du288 as habilitado_du288
end
go

grant execute on Analisis2.sg_fupssSecgen14 to UsuaVrac
go
