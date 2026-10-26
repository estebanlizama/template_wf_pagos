use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
            where a.uid = b.uid
              and a.type = 'P'
              and b.name = 'Analisis2'
              and a.name = 'sg_com1sSecgen02')
    drop procedure Analisis2.sg_com1sSecgen02
go

/* Procedimiento : sg_com1sSecgen02

   Entrada :
   @id_funprse          -> Prestacion del funcionario. (Obligatorio)
   @rut_person          -> RUT del jefe de proyecto. (Obligatorio)

   Objetivo : Entregar el comentario vigente de cada cuota de una prestacion
   para el jefe de proyecto responsable del centro de costo.

   Creacion: ELA 2026/10/26
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_com1sSecgen02
    @id_funprse int = null,
    @rut_person char(9) = null
as

if @id_funprse is null or @id_funprse <= 0
begin
    select 'Falta la prestacion. Se aborta el procedimiento' as msg
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

select com.id_funprse,
       com.nro_cuota,
       com.f_observa,
       com.id_tipacc,
       rtrim(isnull(tacc.des_accion, '')) as des_accion,
       com.rut_accion,
       com.observaci
from secgen_db.dbo.sg_com1 com
left join secgen_db.dbo.sg_tacc tacc on tacc.id_tipacc = com.id_tipacc
where com.id_funprse = @id_funprse
  and com.f_observa = (select max(ult.f_observa)
                         from secgen_db.dbo.sg_com1 ult
                        where ult.id_funprse = com.id_funprse
                          and ult.nro_cuota = com.nro_cuota)
order by com.nro_cuota
go

grant execute on Analisis2.sg_com1sSecgen02 to UsuaVrac
go
