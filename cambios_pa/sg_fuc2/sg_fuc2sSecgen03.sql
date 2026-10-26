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
   @fec_desde           -> Fecha inicial del rango a listar. (Obligatorio)
   @fec_hasta           -> Fecha final del rango a listar. (Obligatorio)

   Objetivo : Listar las compensaciones ya realizadas por el MISMO funcionario
   en OTRAS prestaciones, dentro del rango indicado, de modo de poder
   impedir que las mismas horas justifiquen dos prestaciones distintas.

   Incluye los tramos de cuotas rechazadas: la hora quedo trabajada igual,
   y el mes rechazado no vuelve a estar disponible.

   Aplica los mismos filtros que el control de escritura de sg_fuc2iSecgen01
   y sg_fuc2iSecgen02. Si filtraran distinto, se mostrarian menos dias
   ocupados de los que el registro rechaza, que es peor que no mostrarlos.

   Creacion: ELA 2026/10/21
   Actualizacion: ELA 2026/10/26 (El rechazo ya no libera el horario)
*/
create procedure Analisis2.sg_fuc2sSecgen03
    @id_funprse int = null,
    @rut_person char(9) = null,
    @fec_desde datetime = null,
    @fec_hasta datetime = null
as

declare @rut_funcion char(9)

if isnull(@id_funprse, 0) <= 0 or @fec_desde is null or @fec_hasta is null
   or @fec_desde > @fec_hasta
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

select @rut_funcion = fu.rut
from secgen_db.dbo.sg_fups fu,
     secgen_db.dbo.sg_prse prse
where fu.id_funprse = @id_funprse
  and prse.nro_solici = fu.nro_solici
  and isnull(prse.cod_modprs, 1) = 2

if @rut_funcion is null
begin
    select 'La prestacion no existe' as msg
    return
end

if not exists (
    select 1
      from secgen_db.dbo.sg_fups fu,
           secgen_db.dbo.sg_prse prse,
           fin21_db..es_ecct ecct
     where fu.id_funprse   = @id_funprse
       and prse.nro_solici = fu.nro_solici
       and ecct.cod_ccto   = prse.cod_ccto
       and ecct.cod_unifin = prse.cod_unifin
       and ecct.vigente    = 'S'
       and ecct.rut        = @rut_person
)
   and not exists (
    select 1
      from sisper_db.dbo.sp_orde orde
     where orde.cod_organi = 696
       and orde.rut_person = @rut_person
       and orde.vigente    = 'S'
)
begin
    select 'No tiene acceso a las compensaciones de esta prestacion' as msg
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
    fc.rut_regist,
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
  and fc.fec_comrea >= @fec_desde
  and fc.fec_comrea <= @fec_hasta
order by fc.fec_comrea, fc.hora_ini, fc.id_funprse
go

grant execute on Analisis2.sg_fuc2sSecgen03 to UsuaVrac
go
