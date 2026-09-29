use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_fupsiSecgen01')
   drop procedure Analisis2.sg_fupsiSecgen01

go

/* Procedimiento : sg_fupsiSecgen01

   Entrada :
   @nro_solici          -> Numero de solicitud. (Opcional)
   @rut                 -> RUT del funcionario. (Opcional)
   @cod_cargo           -> Codigo del cargo. (Opcional)
   @cod_sitm            -> Parametro de entrada. (Opcional)
   @itm_global          -> Parametro de entrada. (Opcional)
   @motivo              -> Parametro de entrada. (Opcional)
   @periodos            -> Parametro de entrada. (Opcional)
   @monto_mes           -> Parametro de entrada. (Opcional)
   @mto_total           -> Parametro de entrada. (Opcional)
   @cod_moneda          -> Parametro de entrada. (Opcional)
   @cod_tpps            -> Parametro de entrada. (Opcional)
   @f_inicio            -> Parametro de entrada. (Opcional)
   @f_termino           -> Parametro de entrada. (Opcional)
   @cod_modprs          -> Parametro de entrada. (Opcional)
   @dentro_jor          -> Parametro de entrada. (Opcional)
   @cod_contra          -> Parametro de entrada. (Opcional)
   @mes_haber           -> Parametro de entrada. (Opcional)
   @ano_haber           -> Parametro de entrada. (Opcional)
   @mto_haber           -> Parametro de entrada. (Opcional)
   @mto_tope            -> Parametro de entrada. (Opcional)
   @f_cal_tope          -> Parametro de entrada. (Opcional)
   @tot_cuotas          -> Parametro de entrada. (Opcional)
   @ext_cuotas          -> Extension de cuotas autorizada S/N. (Opcional)
   @cod_estfun          -> Parametro de entrada. (Opcional)

   Objetivo : Registrar un funcionario asociado a una prestacion de servicios,
              compatible con DU288 y el flujo legado.

   Creacion: ELA 2026/08/24
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_fupsiSecgen01
    @nro_solici int = null,
    @rut char(9) = null,
    @cod_cargo smallint = null,
    @cod_sitm varchar(5) = null,
    @itm_global varchar(15) = null,
    @motivo varchar(255) = null,
    @periodos tinyint = null,
    @monto_mes decimal(19,2) = null,
    @mto_total decimal(19,2) = null,
    @cod_moneda tinyint = null,
    @cod_tpps smallint = null,
    @f_inicio datetime = null,
    @f_termino datetime = null,
    @cod_modprs tinyint = null,
    @dentro_jor char(1) = null,
    @cod_contra int = null,
    @mes_haber tinyint = null,
    @ano_haber smallint = null,
    @mto_haber int = null,
    @mto_tope int = null,
    @f_cal_tope datetime = null,
    @tot_cuotas tinyint = null,
    @ext_cuotas char(1) = null,
    @cod_estfun tinyint = null
as
begin
    set nocount on

    declare @resolved_modprs tinyint
    declare @meses_ejec int
    select @resolved_modprs = cod_modprs
    from secgen_db.dbo.sg_prse
    where nro_solici = @nro_solici

    if @resolved_modprs is not null
        select @cod_modprs = @resolved_modprs
    else if @cod_modprs is null
        select @cod_modprs = 1

    if @nro_solici is null
    begin
        select 0 as status, 'INVALID_REQUEST' as code, 'Falta campo Numero Solicitud' as msg
        return
    end

    if @rut is null
    begin
        select 0 as status, 'INVALID_STAFF' as code, 'Falta campo RUT' as msg
        return
    end

    if @cod_cargo is null
    begin
        select 0 as status, 'INVALID_STAFF' as code, 'Falta campo Codigo Cargo' as msg
        return
    end

    if @cod_sitm is null
    begin
        select 0 as status, 'INVALID_STAFF' as code, 'Falta campo Codigo Situacion M' as msg
        return
    end

    if @itm_global is null
    begin
        select 0 as status, 'INVALID_STAFF' as code, 'Falta campo Itm Global' as msg
        return
    end

    if @motivo is null
    begin
        select 0 as status, 'INVALID_ACTIVITY' as code, 'Falta campo Motivo' as msg
        return
    end

    if @cod_modprs = 2 and len(ltrim(rtrim(@motivo))) < 10
    begin
        select 0 as status, 'DU288_INVALID_ACTIVITY' as code, 'La actividad del funcionario debe tener al menos 10 caracteres' as msg
        return
    end

    if @cod_modprs <> 2 and @periodos is null
    begin
        select 0 as status, 'INVALID_STAFF' as code, 'Falta campo Periodos' as msg
        return
    end

    if @cod_modprs <> 2 and @monto_mes is null
    begin
        select 0 as status, 'INVALID_STAFF' as code, 'Falta campo Monto Mensual' as msg
        return
    end

    if @mto_total is null
    begin
        select 0 as status, 'INVALID_STAFF' as code, 'Falta campo Monto Total' as msg
        return
    end

    if @cod_moneda is null
    begin
        select 0 as status, 'INVALID_STAFF' as code, 'Falta campo Codigo Moneda' as msg
        return
    end

    if @cod_tpps is null
    begin
        select 0 as status, 'INVALID_STAFF' as code, 'Falta campo tipo de periodo' as msg
        return
    end

    if @f_inicio is null
    begin
        select 0 as status, 'INVALID_STAFF' as code, 'Falta campo fecha de inicio' as msg
        return
    end

    if @f_termino is null
    begin
        select 0 as status, 'INVALID_STAFF' as code, 'Falta campo fecha de trmino' as msg
        return
    end

    if @f_inicio > @f_termino
    begin
        select 0 as status, 'INVALID_PERIOD' as code, 'La fecha de inicio no puede ser posterior a la fecha de trmino' as msg
        return
    end

    if @cod_modprs = 2
    begin
        if @periodos is null
            select @periodos = 1
        select @meses_ejec = datediff(month, @f_inicio, @f_termino) + 1
        if @meses_ejec is null or @meses_ejec < 1
            select @meses_ejec = 1
        select @monto_mes = @mto_total / @meses_ejec
        if @tot_cuotas is null
            select @tot_cuotas = 1

        select @ext_cuotas = upper(ltrim(rtrim(isnull(@ext_cuotas, 'N'))))
        if @ext_cuotas not in ('S', 'N')
        begin
            select 0 as status, 'DU288_INVALID_INSTALLMENT_EXTENSION' as code, 'La extension de cuotas debe ser S o N' as msg
            return
        end

        if @tot_cuotas < 1
        begin
            select 0 as status, 'DU288_INVALID_INSTALLMENT_COUNT' as code, 'La cantidad de cuotas debe ser mayor que cero' as msg
            return
        end

        if @ext_cuotas = 'S' and @tot_cuotas > 12
        begin
            select 0 as status, 'DU288_INSTALLMENT_LIMIT_EXCEEDED' as code, 'Con extension autorizada la cantidad de cuotas no puede superar 12' as msg
            return
        end

        if @ext_cuotas = 'N' and @tot_cuotas > 2
        begin
            select 0 as status, 'DU288_INSTALLMENT_LIMIT_EXCEEDED' as code, 'Sin extension autorizada la cantidad de cuotas no puede superar 2' as msg
            return
        end

        if @tot_cuotas > @meses_ejec
        begin
            select 0 as status, 'DU288_INSTALLMENT_LIMIT_EXCEEDED' as code, 'La cantidad de cuotas no puede superar los meses de ejecucion' as msg
            return
        end

        if @cod_estfun is null
            select @cod_estfun = 1

        if not exists (select 1 from secgen_db.dbo.sg_efun where cod_estfun = @cod_estfun)
        begin
            select 0 as status, 'INVALID_STAFF_STATUS' as code, 'El estado especificado no existe en el catlogo de estados' as msg
            return
        end

    end
    else
    begin
        select @cod_estfun = null
    end

    declare @id_funprse int

    begin tran

    select @id_funprse = max(ultimo_id)
    from secgen_db..sg_parm holdlock
    where nom_tabla like 'sg_fups'

    if @cod_modprs = 2 and exists (
        select 1
        from secgen_db.dbo.sg_fups
        where nro_solici = @nro_solici
    )
    begin
        rollback tran
        select 0 as status,
               'DU288_STAFF_LIMIT' as code,
               'La solicitud DU288 ya posee un funcionario. Debe actualizar el registro existente.' as msg
        return
    end

    select @id_funprse = isnull(@id_funprse, 0) + 1

    update secgen_db..sg_parm
    set ultimo_id = @id_funprse
    where nom_tabla like 'sg_fups'

    if @@error <> 0 or @@transtate = 2 or @@transtate = 3
    begin
        select 0 as status, 'CORRELATIVE_ERROR' as code, 'Error al actualizar correlativo. Se aborta el procedimiento' as msg
        if @@transtate <> 0
            rollback tran
        return
    end

    if @cod_modprs = 2
    begin
        insert into sg_fups (
            id_funprse,
            nro_solici,
            rut,
            cod_cargo,
            cod_sitm,
            itm_global,
            motivo,
            periodos,
            monto_mes,
            mto_total,
            cod_moneda,
            cod_tpps,
            f_inicio,
            f_termino,
            cod_estfun,
            dentro_jor,
            cod_contra,
            mes_haber,
            ano_haber,
            mto_haber,
            mto_tope,
            f_cal_tope,
            tot_cuotas,
            ext_cuotas
        ) values (
            @id_funprse,
            @nro_solici,
            @rut,
            @cod_cargo,
            @cod_sitm,
            @itm_global,
            @motivo,
            @periodos,
            @monto_mes,
            @mto_total,
            @cod_moneda,
            @cod_tpps,
            @f_inicio,
            @f_termino,
            @cod_estfun,
            @dentro_jor,
            @cod_contra,
            @mes_haber,
            @ano_haber,
            @mto_haber,
            @mto_tope,
            @f_cal_tope,
            @tot_cuotas,
            @ext_cuotas
        )
    end
    else
    begin
        insert into sg_fups (
            id_funprse,
            nro_solici,
            rut,
            cod_cargo,
            cod_sitm,
            itm_global,
            motivo,
            periodos,
            monto_mes,
            mto_total,
            cod_moneda,
            cod_tpps,
            f_inicio,
            f_termino
        ) values (
            @id_funprse,
            @nro_solici,
            @rut,
            @cod_cargo,
            @cod_sitm,
            @itm_global,
            @motivo,
            @periodos,
            @monto_mes,
            @mto_total,
            @cod_moneda,
            @cod_tpps,
            @f_inicio,
            @f_termino
        )
    end

    if @@error <> 0 or @@transtate = 2 or @@transtate = 3
    begin
        select 0 as status, 'STAFF_INSERT_ERROR' as code, 'Error al actualizar informaci3n de validaci3n de proceso. Se aborta el procedimiento' as msg
        if @@transtate <> 0
            rollback tran
        return
    end

    if @cod_modprs = 2
    begin
        update secgen_db.dbo.sg_prse
        set actividad = @motivo
        where nro_solici = @nro_solici

        if @@error <> 0 or @@rowcount <> 1 or @@transtate = 2 or @@transtate = 3
        begin
            select 0 as status, 'DU288_ACTIVITY_SYNC_ERROR' as code, 'No fue posible sincronizar la actividad de la prestacion' as msg
            if @@transtate <> 0
                rollback tran
            return
        end
    end

    commit tran
    select 1 as status, 'OK' as code, 'Funcionario insertado correctamente' as msg, @id_funprse as id_funprse
end
go

grant execute on Analisis2.sg_fupsiSecgen01 to UsuaVrac
go
