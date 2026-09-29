use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_fupsuSecgen01')
   drop procedure Analisis2.sg_fupsuSecgen01

go

/* Procedimiento : sg_fupsuSecgen01

   Entrada :
   @id_funprse          -> Identificador de la funcion/prestacion. (Opcional)
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
   @rut_visado          -> Parametro de entrada. (Opcional)

   Objetivo : Actualizar un funcionario asociado a una prestacion de servicios,
              compatible con DU288 y el flujo legado.

   Creacion: ELA 2026/08/24
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_fupsuSecgen01
    @id_funprse int = null,
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
    @dentro_jor char(1) = null,
    @cod_contra int = null,
    @mes_haber tinyint = null,
    @ano_haber smallint = null,
    @mto_haber int = null,
    @mto_tope int = null,
    @f_cal_tope datetime = null,
    @tot_cuotas tinyint = null,
    @ext_cuotas char(1) = null,
    @cod_estfun tinyint = null,
    @rut_visado char(9) = null
as
begin
    set nocount on

    declare @cod_modprs tinyint
    declare @nro_solici int
    declare @rows_updated int
    declare @err int
    declare @current_estfun tinyint
    declare @current_ext_cuotas char(1)
    declare @meses_ejec int

    select @cod_modprs = isnull(prse.cod_modprs, 1),
           @nro_solici = fu.nro_solici,
           @current_estfun = fu.cod_estfun,
           @current_ext_cuotas = fu.ext_cuotas
    from secgen_db.dbo.sg_prse prse
    join sg_fups fu on prse.nro_solici = fu.nro_solici
    where fu.id_funprse = @id_funprse

    if @cod_modprs is null
        select @cod_modprs = 1

    if @id_funprse is null
    begin
        select 0 as status, 'INVALID_STAFF' as code, 'Falta campo Id Funcionarios prestaci3n de servicios' as msg
        return
    end

    if not exists (select 1 from secgen_db.dbo.sg_fups where id_funprse = @id_funprse)
    begin
        select 0 as status, 'STAFF_NOT_FOUND' as code, 'El funcionario especificado no existe' as msg
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

    if @f_inicio is not null and @f_termino is not null and @f_inicio > @f_termino
    begin
        select 0 as status, 'INVALID_PERIOD' as code, 'La fecha de inicio no puede ser posterior a la fecha de trmino' as msg
        return
    end

    if @cod_modprs = 2 and (
        select count(*)
        from secgen_db.dbo.sg_fups
        where nro_solici = @nro_solici
    ) <> 1
    begin
        select 0 as status,
               'DU288_CARDINALITY_INCONSISTENT' as code,
               'La solicitud DU288 no posee exactamente un funcionario y no puede actualizarse.' as msg
        return
    end

    if @cod_modprs = 2
    begin
        select @ext_cuotas = upper(ltrim(rtrim(isnull(@ext_cuotas, isnull(@current_ext_cuotas, 'N')))))
        if @ext_cuotas not in ('S', 'N')
        begin
            select 0 as status, 'DU288_INVALID_INSTALLMENT_EXTENSION' as code, 'La extension de cuotas debe ser S o N' as msg
            return
        end
    end

    begin tran

    if @cod_modprs = 2 and @cod_estfun is not null
    begin
        if not exists (select 1 from secgen_db.dbo.sg_efun where cod_estfun = @cod_estfun)
        begin
            select 0 as status, 'INVALID_STAFF_STATUS' as code, 'El estado especificado no existe en el catlogo de estados' as msg
            if @@transtate <> 0
                rollback tran
            return
        end
    end

    if @cod_modprs = 2
    begin
        if @periodos is null
            select @periodos = 1
        select @meses_ejec = datediff(
                month,
                isnull(@f_inicio, f_inicio),
                isnull(@f_termino, f_termino)
            ) + 1
        from secgen_db.dbo.sg_fups
        where id_funprse = @id_funprse
        if @meses_ejec is null or @meses_ejec < 1
            select @meses_ejec = 1
        select @monto_mes = @mto_total / @meses_ejec
        if @tot_cuotas is null
            select @tot_cuotas = 1

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

        update sg_fups
        set
            rut = @rut,
            cod_cargo = @cod_cargo,
            cod_sitm = @cod_sitm,
            itm_global = @itm_global,
            motivo = @motivo,
            periodos = @periodos,
            monto_mes = @monto_mes,
            mto_total = @mto_total,
            cod_moneda = @cod_moneda,
            cod_tpps = @cod_tpps,
            f_inicio = @f_inicio,
            f_termino = @f_termino,
            dentro_jor = @dentro_jor,
            cod_contra = @cod_contra,
            mes_haber = @mes_haber,
            ano_haber = @ano_haber,
            mto_haber = @mto_haber,
            mto_tope = @mto_tope,
            f_cal_tope = @f_cal_tope,
            tot_cuotas = @tot_cuotas,
            ext_cuotas = @ext_cuotas,
            cod_estfun = isnull(@cod_estfun, cod_estfun)
        where
            id_funprse = @id_funprse

        select @err = @@error, @rows_updated = @@rowcount

        if @err <> 0
        begin
            select 0 as status, 'STAFF_UPDATE_ERROR' as code, 'Error al actualizar registro DU288' as msg
            if @@transtate <> 0
                rollback tran
            return
        end

        if @cod_estfun is not null and (isnull(@current_estfun, 0) <> @cod_estfun)
        begin
            insert into sg_his2 (
                id_funprse,
                f_visacion,
                rut_visado,
                cod_estact,
                cod_estnue
            ) values (
                @id_funprse,
                getdate(),
                isnull(@rut_visado, 'SYSTEM'),
                isnull(@current_estfun, 1),
                @cod_estfun
            )

            if @@error <> 0
            begin
                select 0 as status, 'STAFF_HISTORY_ERROR' as code, 'Error al registrar historial de visacion del funcionario' as msg
                if @@transtate <> 0
                    rollback tran
                return
            end
        end

update secgen_db.dbo.sg_prse
        set actividad = @motivo
        where nro_solici = @nro_solici

        if @@error <> 0 or @@rowcount <> 1
        begin
            select 0 as status, 'DU288_ACTIVITY_SYNC_ERROR' as code, 'No fue posible sincronizar la actividad de la prestacion' as msg
            if @@transtate <> 0
                rollback tran
            return
        end
    end
    else
    begin
        update sg_fups
        set
            rut = @rut,
            cod_cargo = @cod_cargo,
            cod_sitm = @cod_sitm,
            itm_global = @itm_global,
            motivo = @motivo,
            periodos = @periodos,
            monto_mes = @monto_mes,
            mto_total = @mto_total,
            cod_moneda = @cod_moneda,
            cod_tpps = @cod_tpps,
            f_inicio = @f_inicio,
            f_termino = @f_termino
        where
            id_funprse = @id_funprse

        select @err = @@error, @rows_updated = @@rowcount

        if @err <> 0
        begin
            select 0 as status, 'STAFF_UPDATE_ERROR' as code, 'Error al actualizar registro Legacy' as msg
            if @@transtate <> 0
                rollback tran
            return
        end
    end

    if @rows_updated = 0
    begin
        select 0 as status, 'STAFF_NOT_UPDATED' as code, 'No se actualiz3 ningon registro o no hubo cambios' as msg
        if @@transtate <> 0
            rollback tran
        return
    end

    if @@transtate = 2 or @@transtate = 3
    begin
        select 0 as status, 'STAFF_UPDATE_ERROR' as code, 'Error al actualizar informaci3n de validaci3n de proceso. Se aborta el procedimiento' as msg
        if @@transtate <> 0
            rollback tran
        return
    end

    commit tran
    select 1 as status, 'OK' as code, 'Funcionario actualizado correctamente' as msg, @id_funprse as id_funprse
end
go

grant execute on Analisis2.sg_fupsuSecgen01 to UsuaVrac
go
