use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_fuc2sSecgen01')
   drop procedure Analisis2.sg_fuc2sSecgen01

go

/* Procedimiento : sg_fuc2sSecgen01

   Entrada :
   @nro_solici          -> Numero de solicitud. (Obligatorio)
   @rut_person          -> RUT del responsable vigente del centro de costo. (Obligatorio)
   @id_funprse          -> Identificador del funcionario. (Opcional)
   @corr_fume           -> Correlativo del mes de ejecucion. (Opcional)

   Objetivo : Listar las compensaciones realizadas por los funcionarios de una
   solicitud, por mes de ejecucion.

   Creacion: ELA 2026/10/01
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_fuc2sSecgen01
    @nro_solici int = null,
    @rut_person char(9) = null,
    @id_funprse int = null,
    @corr_fume tinyint = null
as

if @nro_solici is null
begin
    select 'Falta numero de solicitud' as msg
    return
end

if @rut_person is null or ltrim(rtrim(@rut_person)) = ''
begin
    select 'Falta el rut del jefe de proyecto' as msg
    return
end

select @rut_person = right('000000000' + ltrim(rtrim(@rut_person)), 9)

select
    fc.id_funprse,
    fc.corr_fume,
    dateadd(
        day,
        datediff(day, convert(datetime, '19000101'), fc.fec_comrea),
        convert(datetime, '19000101')
    ) as fec_comrea,
    fc.hora_ini,
    fc.hora_ter,
    fm.ano_prop,
    fm.mes_prop,
    fm.cod_estfum
from secgen_db.dbo.sg_fuc2 fc
inner join secgen_db.dbo.sg_fume fm
    on fm.id_funprse = fc.id_funprse
   and fm.corr_fume = fc.corr_fume
inner join secgen_db.dbo.sg_fups fu
    on fu.id_funprse = fc.id_funprse
inner join secgen_db.dbo.sg_prse prse
    on prse.nro_solici = fu.nro_solici
where fu.nro_solici = @nro_solici
  and isnull(prse.cod_modprs, 1) = 2
  and exists (select 1
                from fin21_db..es_ecct ecct
               where ecct.cod_ccto   = prse.cod_ccto
                 and ecct.cod_unifin = prse.cod_unifin
                 and ecct.vigente    = 'S'
                 and ecct.rut        = @rut_person)
  and (@id_funprse is null or fc.id_funprse = @id_funprse)
  and (@corr_fume is null or fc.corr_fume = @corr_fume)
order by fc.id_funprse, fc.corr_fume, fc.fec_comrea, fc.hora_ini
go

grant execute on Analisis2.sg_fuc2sSecgen01 to UsuaVrac
go
