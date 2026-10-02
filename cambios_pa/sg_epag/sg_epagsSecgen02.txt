use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_epagsSecgen02')
   drop procedure Analisis2.sg_epagsSecgen02

go

/* Procedimiento : sg_epagsSecgen02

   Entrada :
   @id_funprse          -> Prestacion del funcionario. (Obligatorio)
   @nro_cuota           -> Numero de cuota. (Obligatorio)
   @rut_person          -> RUT del responsable vigente del centro de costo. (Obligatorio)

   Objetivo : Obtener los meses de ejecucion que abarca una cuota, con el monto
   y los descuentos de cada uno.

   Creacion: ELA 2026/10/02
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_epagsSecgen02
    @id_funprse int = null,
    @nro_cuota tinyint = null,
    @rut_person char(9) = null
as

if @id_funprse is null or @id_funprse <= 0
begin
    select 'Falta la prestacion. Se aborta el procedimiento' as msg
    return
end

if @nro_cuota is null or @nro_cuota <= 0
begin
    select 'Falta el numero de cuota. Se aborta el procedimiento' as msg
    return
end

if @rut_person is null or ltrim(rtrim(@rut_person)) = ''
begin
    select 'Falta el rut del jefe de proyecto. Se aborta el procedimiento' as msg
    return
end

select @rut_person = right('000000000' + ltrim(rtrim(@rut_person)), 9)

if not exists (select 1
                 from secgen_db.dbo.sg_fups fu,
                      secgen_db.dbo.sg_prse prse,
                      fin21_db..es_ecct ecct
                where fu.id_funprse = @id_funprse
                  and prse.nro_solici = fu.nro_solici
                  and ecct.cod_ccto   = prse.cod_ccto
                  and ecct.cod_unifin = prse.cod_unifin
                  and ecct.vigente    = 'S'
                  and ecct.rut        = @rut_person)
begin
    select 'La prestacion no existe o no esta a su cargo' as msg
    return
end

if not exists (select 1
                 from secgen_db.dbo.sg_epag
                where id_funprse = @id_funprse
                  and nro_cuota  = @nro_cuota)
begin
    select 'La cuota indicada no existe' as msg
    return
end

select
    dpag.id_funprse,
    dpag.nro_cuota,
    dpag.corr_fume,
    fume.ano_prop,
    fume.mes_prop,
    fume.cod_estfum,
    rtrim(isnull(efum.des_estfum, '')) as des_estfum,
    fume.ano_ejec,
    fume.mes_ejec,
    fume.mto_apagar,
    fume.mto_realpa,
    fume.mto_deslic,
    fume.mto_dessg,
    fume.val_licmed,
    fume.val_inabili,
    fume.val_singoce,
    fume.val_ciecc,
    fume.fec_valida,
    fume.rut_autori,
    fume.fec_autori,
    fume.fec_envrem,
    (select count(*)
       from secgen_db.dbo.sg_fuc2 c2
      where c2.id_funprse = fume.id_funprse
        and c2.corr_fume  = fume.corr_fume) as cant_compens
from
    secgen_db.dbo.sg_dpag dpag
inner join
    secgen_db.dbo.sg_fume fume
    on fume.id_funprse = dpag.id_funprse
    and fume.corr_fume = dpag.corr_fume
left join
    secgen_db.dbo.sg_efum efum
    on efum.cod_estfum = fume.cod_estfum
where
    dpag.id_funprse = @id_funprse
and
    dpag.nro_cuota = @nro_cuota
order by
    fume.ano_prop, fume.mes_prop
go

grant execute on Analisis2.sg_epagsSecgen02 to UsuaVrac
go
