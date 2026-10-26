use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
            where a.uid = b.uid
              and a.type = 'P'
              and b.name = 'Analisis2'
              and a.name = 'sg_com1sSecgen01')
    drop procedure Analisis2.sg_com1sSecgen01
go

/* Procedimiento : sg_com1sSecgen01

   Entrada :
   @rut_person          -> RUT del revisor DGDP. (Obligatorio)
   @id_funprse          -> Prestacion del funcionario. (Obligatorio)
   @nro_cuota           -> Correlativo de la cuota. (Opcional)

   Objetivo : Consultar los comentarios registrados sobre una cuota, o sobre
   todas las cuotas de la prestacion si no se indica una.

   Creacion: ELA 2026/10/26
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_com1sSecgen01
    @rut_person char(9) = null,
    @id_funprse int = null,
    @nro_cuota tinyint = null
as

if @rut_person is null or ltrim(rtrim(@rut_person)) = '' or isnull(@id_funprse, 0) <= 0
begin
    select 'Faltan antecedentes para consultar los comentarios de la cuota.' as msg
    return
end

select @rut_person = right('000000000' + ltrim(rtrim(@rut_person)), 9)

if not exists (
    select 1
    from sisper_db..sp_pers pers
    inner join sisper_db..sp_cont cont on cont.cod_ficha = pers.cod_ficha
    where pers.rut_person = @rut_person
      and cont.vigen_cont in ('0', '2')
      and cont.cod_calida <> '01'
      and isnull(cont.f_inicio_d, getdate()) <= getdate()
      and isnull(cont.f_termino, isnull(cont.f_termin_d, getdate())) >= getdate()
      and exists (
          select 1
            from sisper_db.dbo.sp_orde orde
           where orde.cod_organi = 696
             and orde.rut_person = @rut_person
             and orde.vigente = 'S'
      )
)
begin
    select 'El usuario no tiene asignacion vigente para revisar cuotas DGDP.' as msg
    return
end

select com.id_funprse,
       com.nro_cuota,
       com.f_observa,
       com.id_tipacc,
       rtrim(isnull(tacc.des_accion, '')) as des_accion,
       com.rut_accion,
       rtrim(isnull(pers.nom_appate, '')) + ' ' +
       rtrim(isnull(pers.nom_apmate, '')) + ' ' +
       rtrim(isnull(pers.nom_nombre, '')) as nom_accion,
       com.observaci
from secgen_db.dbo.sg_com1 com
left join secgen_db.dbo.sg_tacc tacc on tacc.id_tipacc = com.id_tipacc
left join sisper_db..sp_pers pers on pers.rut_person = com.rut_accion
where com.id_funprse = @id_funprse
  and (@nro_cuota is null or com.nro_cuota = @nro_cuota)
order by com.nro_cuota, com.f_observa desc
go

grant execute on Analisis2.sg_com1sSecgen01 to UsuaVrac
go
