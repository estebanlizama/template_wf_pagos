use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_fupssSecgen15')
   drop procedure Analisis2.sg_fupssSecgen15

go

/* Procedimiento : sg_fupssSecgen15

   Entrada :
   @rut_person          -> RUT de la persona. (Obligatorio)
   @id_contrato         -> Identificador del contrato. (Opcional)
   @fecha_eval          -> Fecha de evaluacion. (Opcional)
   @ext_cuotas          -> Extension de cuotas autorizada S/N. (Opcional)

   Objetivo : Obtener asignaciones/designaciones vigentes del funcionario y evaluar si alguna inhabilita DU288.

   Creacion: ELA 2026/07/10
   Actualizacion: ELA 2026/09/29
*/
create procedure Analisis2.sg_fupssSecgen15
    @rut_person  char(9),
    @id_contrato int = 0,
    @fecha_eval  datetime = null,
    @ext_cuotas  char(1) = 'N'
as
begin
    if @fecha_eval is null
        select @fecha_eval = getdate()

    select @ext_cuotas = upper(ltrim(rtrim(isnull(@ext_cuotas, 'N'))))
    if @ext_cuotas not in ('S', 'N')
        select @ext_cuotas = 'N'

    select
        orde.rut_person,
        @id_contrato as id_contrato,
        desg.cod_ficha,
        desg.cod_design,
        desg.cod_cargo,
        rtrim(carg.nom_cargo) as nom_cargo,
        carg.cod_tipcar,
        desg.cod_unidad,
        rtrim(unid.des_unidad) as des_unidad,
        desg.vigencia,
        desg.f_inicio as fecha_inicio,
        desg.f_termino as fecha_termino,
        desg.con_asign,
        desg.hora_dedid,
        rtrim(desg.observ) as observ,
        case
            when @ext_cuotas = 'S' and desg.cod_cargo = 3110 then 'S'
            when carg.cod_tipcar = '5' then 'N'
            when carg.cod_tipcar = '3'
             and (
                    upper(rtrim(carg.nom_cargo)) like '%DIRECTOR%'
                 or upper(rtrim(carg.nom_cargo)) like '%DIRECTORA%'
                 or upper(rtrim(carg.nom_cargo)) like '%RECTOR%'
                 or upper(rtrim(carg.nom_cargo)) like '%RECTORA%'
                 or upper(rtrim(carg.nom_cargo)) like '%DECANO%'
                 or upper(rtrim(carg.nom_cargo)) like '%DECANA%'
                 or upper(rtrim(carg.nom_cargo)) like '%VICERRECTOR%'
                 or upper(rtrim(carg.nom_cargo)) like '%VICERRECTORA%'
                 or upper(rtrim(carg.nom_cargo)) like '%SECRETARIO GENERAL%'
                 or upper(rtrim(carg.nom_cargo)) like '%SECRETARIA GENERAL%'
                ) then 'N'
            else 'S'
        end as habilitado_du288,
        case
            when @ext_cuotas = 'S' and desg.cod_cargo = 3110 then null
            when carg.cod_tipcar = '5' then 'Cargo directivo vigente'
            when carg.cod_tipcar = '3'
             and (
                    upper(rtrim(carg.nom_cargo)) like '%DIRECTOR%'
                 or upper(rtrim(carg.nom_cargo)) like '%DIRECTORA%'
                 or upper(rtrim(carg.nom_cargo)) like '%RECTOR%'
                 or upper(rtrim(carg.nom_cargo)) like '%RECTORA%'
                 or upper(rtrim(carg.nom_cargo)) like '%DECANO%'
                 or upper(rtrim(carg.nom_cargo)) like '%DECANA%'
                 or upper(rtrim(carg.nom_cargo)) like '%VICERRECTOR%'
                 or upper(rtrim(carg.nom_cargo)) like '%VICERRECTORA%'
                 or upper(rtrim(carg.nom_cargo)) like '%SECRETARIO GENERAL%'
                 or upper(rtrim(carg.nom_cargo)) like '%SECRETARIA GENERAL%'
                ) then 'Funcion directiva vigente'
            else null
        end as motivo_inhabilidad
    from sisper_db.dbo.sp_orde orde
    inner join sisper_db.dbo.sp_desg desg
        on desg.cod_design = orde.cod_design
    left join sisper_db.dbo.sp_carg carg
        on carg.cod_cargo = desg.cod_cargo
    left join ufro_db.dbo.es_unid unid
        on unid.cod_unidad = desg.cod_unidad
    where orde.rut_person = @rut_person
      and orde.vigente = 'S'
      and desg.vigencia in ('1', 'S')
      and desg.f_inicio <= @fecha_eval
      and (desg.f_termino is null or desg.f_termino >= @fecha_eval)
    order by desg.f_inicio desc, desg.cod_design
end
go

grant execute on Analisis2.sg_fupssSecgen15 to UsuaVrac
go
