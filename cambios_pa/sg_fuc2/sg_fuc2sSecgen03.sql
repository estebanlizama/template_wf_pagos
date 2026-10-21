use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_fuc2sSecgen03')
   drop procedure Analisis2.sg_fuc2sSecgen03

go

/* Procedimiento : sg_fuc2sSecgen03

   Entrada :
   @id_funprse          -> Prestacion que se esta compensando. (Obligatorio)
   @rut_person          -> RUT del responsable vigente del centro de costo. (Obligatorio)
   @ano                 -> Ano de las compensaciones a listar. (Obligatorio)
   @mes                 -> Mes de las compensaciones a listar. (Obligatorio)

   Objetivo : Listar las compensaciones ya realizadas por el MISMO funcionario
   en OTRAS prestaciones, dentro del mes indicado, de modo de poder
   impedir que las mismas horas justifiquen dos prestaciones distintas.

   Aplica los mismos filtros que el control de escritura de sg_fuc2iSecgen01
   y sg_fuc2iSecgen02. Si filtraran distinto, se mostrarian menos dias
   ocupados de los que el registro rechaza, que es peor que no mostrarlos.

   Creacion: ELA 2026/10/21
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_fuc2sSecgen03
    @id_funprse int = null,
    @rut_person char(9) = null,
    @ano smallint = null,
    @mes tinyint = null
as

declare @rut_funcion char(9)

if isnull(@id_funprse, 0) <= 0 or isnull(@ano, 0) <= 0
   or @mes is null or @mes not between 1 and 12
begin
    select 'Faltan antecedentes para listar las compensaciones del funcionario' as msg
    return
end

if @rut_person is null or ltrim(rtrim(@rut_person)) = ''
begin
    select 'Falta el rut del jefe de proyecto' as msg
    return
end

select @rut_person = right('000000000' + ltrim(rtrim(@rut_person)), 9)

/* El responsable consulta desde una prestacion a su cargo. Lo que se devuelve
   son tramos de otras prestaciones del mismo funcionario, y el permiso para
   verlos nace de estar gestionando la suya. */
select @rut_funcion = fu.rut
from secgen_db.dbo.sg_fups fu,
     secgen_db.dbo.sg_prse prse
where fu.id_funprse = @id_funprse
  and prse.nro_solici = fu.nro_solici
  and isnull(prse.cod_modprs, 1) = 2
  and exists (select 1
                from fin21_db..es_ecct ecct
               where ecct.cod_ccto   = prse.cod_ccto
                 and ecct.cod_unifin = prse.cod_unifin
                 and ecct.vigente    = 'S'
                 and ecct.rut        = @rut_person)

if @rut_funcion is null
begin
    select 'La prestacion no existe o no esta a su cargo' as msg
    return
end

select
    fc.id_funprse,
    fu.nro_solici,
    dateadd(
        day,
        datediff(day, convert(datetime, '19000101'), fc.fec_comrea),
        convert(datetime, '19000101')
    ) as fec_comrea,
    fc.hora_ini,
    fc.hora_ter,
    prse.cod_ccto,
    prse.cod_unifin,
    soli.cod_estsol
from secgen_db.dbo.sg_fuc2 fc
inner join secgen_db.dbo.sg_fups fu
    on fu.id_funprse = fc.id_funprse
inner join secgen_db.dbo.sg_prse prse
    on prse.nro_solici = fu.nro_solici
inner join secgen_db.dbo.sg_soli soli
    on soli.nro_solici = fu.nro_solici
where fu.rut = @rut_funcion
  and fc.id_funprse <> @id_funprse
  and soli.cod_estsol in (8, 9, 10, 11)
  /* La cuota rechazada no reserva horas; el mes que aun no tiene cuota si. */
  and not exists (
      select 1
      from secgen_db.dbo.sg_dpag dp,
           secgen_db.dbo.sg_epag ep
      where dp.id_funprse = fc.id_funprse
        and dp.corr_fume  = fc.corr_fume
        and ep.id_funprse = dp.id_funprse
        and ep.nro_cuota  = dp.nro_cuota
        and ep.cod_estcuo = 10
  )
  and datepart(yy, fc.fec_comrea) = @ano
  and datepart(mm, fc.fec_comrea) = @mes
order by fc.fec_comrea, fc.hora_ini, fc.id_funprse
go

grant execute on Analisis2.sg_fuc2sSecgen03 to UsuaVrac
go
