use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
            where a.uid = b.uid
              and a.type = 'P'
              and b.name = 'Analisis2'
              and a.name = 'sg_epaguSecgen03')
    drop procedure Analisis2.sg_epaguSecgen03
go

/* Procedimiento : sg_epaguSecgen03

   Entrada :
   @rut_person          -> RUT del revisor DGDP. (Obligatorio)
   @id_funprse          -> Prestacion del funcionario. (Obligatorio)
   @nro_cuota           -> Correlativo de la cuota. (Obligatorio)
   @cod_estcuo          -> Estado de destino: 3, 4 o 10. (Obligatorio)
   @observacion         -> Motivo de observacion o rechazo. (Obligatorio en 3 y 10)

   Objetivo : Registrar la decision DGDP de una cuota en visacion y dejar el
   motivo cuando la devuelve o la rechaza. El rechazo bloquea los meses en
   sg_efum = 4 y conserva sg_dpag, asi que la cuota mantiene lo que solicito y
   el monto queda descontado del total de la prestacion.

   Creacion: ELA 2026/10/06
   Actualizacion: ELA 2026/10/26
*/
create procedure Analisis2.sg_epaguSecgen03
    @rut_person char(9) = null,
    @id_funprse int = null,
    @nro_cuota tinyint = null,
    @cod_estcuo tinyint = null,
    @observacion varchar(255) = null
as

if @rut_person is null or ltrim(rtrim(@rut_person)) = '' or isnull(@id_funprse, 0) <= 0 or isnull(@nro_cuota, 0) <= 0
begin
    select 'Faltan antecedentes para resolver la cuota.' as msg
    return
end
if @cod_estcuo is null or @cod_estcuo not in (3, 4, 10)
begin
    select 'La resolucion indicada no es valida.' as msg
    return
end

if @cod_estcuo in (3, 10) and (@observacion is null or ltrim(rtrim(@observacion)) = '')
begin
    select 'Indique el motivo de la devolucion o del rechazo.' as msg
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

begin transaction
if not exists (
    select 1
      from dbo.sg_epag holdlock
     where id_funprse = @id_funprse
       and nro_cuota = @nro_cuota
       and cod_estcuo = 2
)
begin
    select 'La cuota ya no esta en visacion.' as msg
    if @@transtate = 2 rollback transaction
    return
end

if @cod_estcuo = 10
begin
    select @corr_fume = min(dpag.corr_fume)
      from dbo.sg_dpag dpag
     where dpag.id_funprse = @id_funprse
       and dpag.nro_cuota = @nro_cuota

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
            select 'No fue posible versionar los meses de la cuota rechazada.' as msg
            if @@transtate = 2 rollback transaction
            return
        end

        select @corr_fume = min(dpag.corr_fume)
          from dbo.sg_dpag dpag
         where dpag.id_funprse = @id_funprse
           and dpag.nro_cuota = @nro_cuota
           and dpag.corr_fume > @corr_fume
    end

    update dbo.sg_fume
       set cod_estfum = 4
      from dbo.sg_fume fume,
           dbo.sg_dpag dpag
     where dpag.id_funprse = fume.id_funprse
       and dpag.corr_fume = fume.corr_fume
       and dpag.id_funprse = @id_funprse
       and dpag.nro_cuota = @nro_cuota
       and fume.cod_estfum = 2

    if @@error <> 0
    begin
        select 'No fue posible bloquear los meses de la cuota rechazada.' as msg
        if @@transtate = 2 rollback transaction
        return
    end
end

update dbo.sg_epag
   set cod_estcuo = @cod_estcuo
 where id_funprse = @id_funprse
   and nro_cuota = @nro_cuota
   and cod_estcuo = 2

if @@rowcount <> 1
begin
    select 'La cuota ya no esta en visacion.' as msg
    if @@transtate = 2 rollback transaction
    return
end

if @cod_estcuo in (3, 10)
begin
    declare @id_tipacc tinyint

    select @id_tipacc = case @cod_estcuo when 3 then 32 else 33 end

    insert into dbo.sg_com1 (
        id_funprse,
        nro_cuota,
        f_observa,
        id_tipacc,
        rut_accion,
        observaci
    ) values (
        @id_funprse,
        @nro_cuota,
        getdate(),
        @id_tipacc,
        @rut_person,
        @observacion
    )

    if @@error <> 0
    begin
        select 'No fue posible registrar el motivo de la decision.' as msg
        if @@transtate = 2 rollback transaction
        return
    end
end

commit transaction
select 1 as status, 'OK' as code, 'La resolucion DGDP se registro correctamente.' as msg
go

grant execute on Analisis2.sg_epaguSecgen03 to UsuaVrac
go
