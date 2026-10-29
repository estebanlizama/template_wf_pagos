use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
            where a.uid = b.uid
              and a.type = 'P'
              and b.name = 'Analisis2'
              and a.name = 'sg_epaguSecgen04')
    drop procedure Analisis2.sg_epaguSecgen04
go

/* Procedimiento : sg_epaguSecgen04

   Entrada :
   @rut_person          -> RUT del revisor DGDP. (Obligatorio)
   @id_funprse          -> Prestacion del funcionario. (Obligatorio)
   @nro_cuota           -> Correlativo de la cuota. (Obligatorio)

   Objetivo : Registrar que una cuota aprobada se subio a Finanzas. Mueve el
   encabezado de 4 Aprobada a 8 Enviada remuneraciones y sus meses de
   2 Comprometida a 3 Enviada a pago, con fec_envrem. Exige cod_estcuo = 4, de
   modo que no reenvia una cuota ya enviada. Es el PA de cierre: deja
   sg_epag.mto_realpa con la suma de los meses enviados y completa
   sg_fume.mto_realpa solo donde sg_fumeuSecgen03 no lo dejo.

   Creacion: ELA 2026/10/28
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_epaguSecgen04
    @rut_person char(9) = null,
    @id_funprse int = null,
    @nro_cuota tinyint = null
as

if @rut_person is null or ltrim(rtrim(@rut_person)) = '' or isnull(@id_funprse, 0) <= 0 or isnull(@nro_cuota, 0) <= 0
begin
    select 'Faltan antecedentes para registrar el envio a Finanzas.' as msg
    return
end

select @rut_person = right('000000000' + ltrim(rtrim(@rut_person)), 9)

if not exists (
    select 1 from sisper_db..sp_pers pers
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

declare @corr_fume tinyint
declare @correlativ tinyint
declare @mto_cuota int

begin transaction

if not exists (
    select 1
      from dbo.sg_epag holdlock
     where id_funprse = @id_funprse
       and nro_cuota = @nro_cuota
       and cod_estcuo = 4
)
begin
    select 'La cuota no esta aprobada o ya se envio a Finanzas.' as msg
    if @@transtate = 2 rollback transaction
    return
end

if not exists (
    select 1
      from dbo.sg_dpag dpag,
           dbo.sg_fume fume
     where dpag.id_funprse = fume.id_funprse
       and dpag.corr_fume = fume.corr_fume
       and dpag.id_funprse = @id_funprse
       and dpag.nro_cuota = @nro_cuota
       and fume.cod_estfum = 2
)
begin
    select 'La cuota no tiene meses comprometidos que enviar a Finanzas.' as msg
    if @@transtate = 2 rollback transaction
    return
end

select @corr_fume = min(dpag.corr_fume)
  from dbo.sg_dpag dpag,
       dbo.sg_fume fume
 where dpag.id_funprse = fume.id_funprse
   and dpag.corr_fume = fume.corr_fume
   and dpag.id_funprse = @id_funprse
   and dpag.nro_cuota = @nro_cuota
   and fume.cod_estfum = 2

while @corr_fume is not null
begin
    select @correlativ = isnull(max(correlativ), 0) + 1
      from dbo.sg_fum2 holdlock
     where id_funprse = @id_funprse
       and corr_fume = @corr_fume

    if @correlativ > 255
    begin
        select 'Se alcanzo el maximo de versiones de un mes de la cuota.' as msg
        if @@transtate = 2 rollback transaction
        return
    end

    insert into dbo.sg_fum2 (
        id_funprse,
        corr_fume,
        correlativ,
        ano_prop,
        mes_prop,
        cod_estfum,
        ano_ejec,
        mes_ejec,
        mto_apagar,
        id_evidenc,
        val_licmed,
        val_inabili,
        val_singoce,
        val_ciecc,
        fec_valida,
        rut_autori,
        fec_autori,
        fec_envrem,
        mto_realpa,
        mto_deslic,
        mto_dessg,
        rut_regist,
        f_regist
    )
    select
        id_funprse,
        corr_fume,
        @correlativ,
        ano_prop,
        mes_prop,
        cod_estfum,
        ano_ejec,
        mes_ejec,
        mto_apagar,
        id_evidenc,
        val_licmed,
        val_inabili,
        val_singoce,
        val_ciecc,
        fec_valida,
        rut_autori,
        fec_autori,
        fec_envrem,
        mto_realpa,
        mto_deslic,
        mto_dessg,
        @rut_person,
        getdate()
      from dbo.sg_fume
     where id_funprse = @id_funprse
       and corr_fume = @corr_fume

    if @@error <> 0
    begin
        select 'No fue posible versionar los meses de la cuota enviada.' as msg
        if @@transtate = 2 rollback transaction
        return
    end

    select @corr_fume = min(dpag.corr_fume)
      from dbo.sg_dpag dpag,
           dbo.sg_fume fume
     where dpag.id_funprse = fume.id_funprse
       and dpag.corr_fume = fume.corr_fume
       and dpag.id_funprse = @id_funprse
       and dpag.nro_cuota = @nro_cuota
       and fume.cod_estfum = 2
       and dpag.corr_fume > @corr_fume
end

update dbo.sg_fume
   set cod_estfum = 3,
       fec_envrem = getdate(),
       mto_realpa = isnull(fume.mto_realpa,
                           isnull(fume.mto_apagar, 0)
                           - isnull(fume.mto_deslic, 0)
                           - isnull(fume.mto_dessg, 0))
  from dbo.sg_fume fume,
       dbo.sg_dpag dpag
 where dpag.id_funprse = fume.id_funprse
   and dpag.corr_fume = fume.corr_fume
   and dpag.id_funprse = @id_funprse
   and dpag.nro_cuota = @nro_cuota
   and fume.cod_estfum = 2

if @@error <> 0
begin
    select 'No fue posible marcar los meses como enviados a pago.' as msg
    if @@transtate = 2 rollback transaction
    return
end

select @mto_cuota = isnull(sum(fume.mto_realpa), 0)
  from dbo.sg_dpag dpag,
       dbo.sg_fume fume
 where dpag.id_funprse = fume.id_funprse
   and dpag.corr_fume = fume.corr_fume
   and dpag.id_funprse = @id_funprse
   and dpag.nro_cuota = @nro_cuota
   and fume.cod_estfum = 3

update dbo.sg_epag
   set cod_estcuo = 8,
       mto_realpa = @mto_cuota
 where id_funprse = @id_funprse
   and nro_cuota = @nro_cuota
   and cod_estcuo = 4

if @@rowcount <> 1
begin
    select 'La cuota no esta aprobada o ya se envio a Finanzas.' as msg
    if @@transtate = 2 rollback transaction
    return
end

commit transaction
select 1 as status, 'OK' as code, 'La cuota se registro como enviada a Finanzas.' as msg
go

grant execute on Analisis2.sg_epaguSecgen04 to UsuaVrac
go
