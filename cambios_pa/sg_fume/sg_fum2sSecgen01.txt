use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_fum2sSecgen01')
   drop procedure Analisis2.sg_fum2sSecgen01

go

/* Procedimiento : sg_fum2sSecgen01

   Entrada :
   @rut_person          -> RUT del responsable vigente del centro de costo. (Obligatorio)
   @id_funprse          -> Identificador del funcionario. (Obligatorio)
   @corr_fume           -> Limita a un mes de ejecucion. (Opcional)

   Objetivo : Listar las versiones guardadas de un mes de ejecucion. Cada fila
   es el estado que tenia el mes antes de un cambio de monto; la version
   vigente esta en sg_fume, no aqui, y viaja como mto_vigente y fec_vigente.
   fec_valida es la fecha de la ultima gestion de cada version.

   Creacion: ELA 2026/10/13
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_fum2sSecgen01
    @rut_person char(9) = null,
    @id_funprse int = null,
    @corr_fume tinyint = null
as

if @rut_person is null or ltrim(rtrim(@rut_person)) = ''
begin
    select 'Error: Falta el rut del jefe de proyecto' as msg
    return
end

if @id_funprse is null or @id_funprse <= 0
begin
    select 'Error: Falta la prestacion del funcionario' as msg
    return
end

select @rut_person = right('000000000' + ltrim(rtrim(@rut_person)), 9)

select
    h.id_funprse,
    h.corr_fume,
    h.correlativ,
    h.ano_prop,
    h.mes_prop,
    h.cod_estcuo,
    rtrim(isnull(e.des_estfum, '')) as des_estfum,
    h.ano_ejec,
    h.mes_ejec,
    h.mto_apagar,
    h.id_evidenc,
    h.val_licmed,
    h.val_inabili,
    h.val_singoce,
    h.val_ciecc,
    h.fec_valida,
    h.rut_autori,
    h.fec_autori,
    h.fec_envrem,
    fm.mto_apagar as mto_vigente,
    fm.fec_valida as fec_vigente
from secgen_db.dbo.sg_fum2 h
inner join secgen_db.dbo.sg_fume fm
    on fm.id_funprse = h.id_funprse
   and fm.corr_fume  = h.corr_fume
inner join secgen_db.dbo.sg_fups fu on fu.id_funprse = h.id_funprse
inner join secgen_db.dbo.sg_prse prse on prse.nro_solici = fu.nro_solici
left join secgen_db.dbo.sg_efum e on e.cod_estfum = h.cod_estcuo
where isnull(prse.cod_modprs, 1) = 2
  and exists (select 1
                from fin21_db..es_ecct ecct
               where ecct.cod_ccto   = prse.cod_ccto
                 and ecct.cod_unifin = prse.cod_unifin
                 and ecct.vigente    = 'S'
                 and ecct.rut        = @rut_person)
  and h.id_funprse = @id_funprse
  and (@corr_fume is null or h.corr_fume = @corr_fume)
order by h.corr_fume, h.correlativ
go

grant execute on Analisis2.sg_fum2sSecgen01 to UsuaVrac
go
