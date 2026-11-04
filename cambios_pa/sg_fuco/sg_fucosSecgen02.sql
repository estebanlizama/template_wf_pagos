use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_fucosSecgen02')
   drop procedure Analisis2.sg_fucosSecgen02

go

/* Procedimiento : sg_fucosSecgen02

   Entrada :
   @rut_person          -> RUT de la persona. (Obligatorio)
   @nro_solici_excluir  -> Solicitud que no se lista. (Opcional)

   Objetivo : Listar las compensaciones propuestas (sg_fuco) de todas las
              prestaciones previas de un funcionario, con los mismos
              filtros que sg_fupssSecgen17, para contrastarlas en una sola
              lectura con las realizadas y con la solicitud en revision.

   Creacion: ELA 2026/11/04
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_fucosSecgen02
    @rut_person         char(9) = null,
    @nro_solici_excluir int     = null
as
begin
    if @rut_person is null or ltrim(rtrim(@rut_person)) = ''
    begin
        select 'Falta campo RUT del funcionario' as msg
        return
    end

    select
        fc.id_funprse,
        fu.nro_solici,
        dateadd(
            day,
            datediff(day, convert(datetime, '19000101'), fc.fec_compro),
            convert(datetime, '19000101')
        ) as fec_compro,
        fc.hora_ini,
        fc.hora_ter
    from secgen_db.dbo.sg_fuco fc
    inner join secgen_db.dbo.sg_fups fu
        on fu.id_funprse = fc.id_funprse
    inner join secgen_db.dbo.sg_soli soli
        on soli.nro_solici = fu.nro_solici
    where fu.rut = @rut_person
      and (@nro_solici_excluir is null or fu.nro_solici <> @nro_solici_excluir)
      and soli.cod_estsol not in (4)
    order by fc.id_funprse, fc.fec_compro, fc.hora_ini
end
go

grant execute on Analisis2.sg_fucosSecgen02 to UsuaVrac
go
