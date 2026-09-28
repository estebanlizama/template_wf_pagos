use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_fumeuSecgen01')
   drop procedure Analisis2.sg_fumeuSecgen01

go

/* Procedimiento : sg_fumeuSecgen01

   Entrada :
   @id_funprse          -> Identificador de la funcion/prestacion. (Opcional)
   @meses_csv           -> Lista de meses propuestos, formato ano:mes separados por punto y coma. (Opcional)
   @cod_estfum          -> Estado inicial del mes; usa 1 (Propuesta) si no se envia. (Opcional)

   Objetivo : Sincronizar de forma diferencial los meses de ejecucion de un funcionario: borra
   solo los que salen de la propuesta, inserta solo los que entran y conserva el corr_fume de
   los que siguen.

   Creacion: ELA 2026/08/24
   Actualizacion: ELA 2026/09/25
*/
create procedure Analisis2.sg_fumeuSecgen01
    @id_funprse int = null,
    @meses_csv varchar(500) = null,
    @cod_estfum int = 1
as
begin
    set nocount on

    if @id_funprse is null
    begin
        select 'Error: Falta ID del funcionario' as msg
        return
    end

    if not exists (
        select 1
        from secgen_db.dbo.sg_fups
        where id_funprse = @id_funprse
    )
    begin
        select 'Error: El funcionario especificado no existe' as msg
        return
    end

    if not exists (
        select 1
        from secgen_db.dbo.sg_fups fu
        inner join secgen_db.dbo.sg_prse prse
            on prse.nro_solici = fu.nro_solici
        where fu.id_funprse = @id_funprse
          and isnull(prse.cod_modprs, 1) = 2
    )
    begin
        select 'Error: El funcionario no corresponde a la modalidad DU288' as msg
        return
    end

    if exists (
        select 1
        from secgen_db.dbo.sg_fume
        where id_funprse = @id_funprse
          and cod_estfum not in (1, 4)
    )
    begin
        select 'Error: No se pueden modificar los meses de ejecucion porque ya estan asignados a un pago' as msg
        return
    end

    create table #meses_raw (
        anio smallint not null,
        nro_mes tinyint not null
    )

    if @meses_csv is not null and ltrim(rtrim(@meses_csv)) <> ''
    begin
        declare @pos int
        declare @chunk varchar(50)
        declare @col_pos int
        declare @anio varchar(10)
        declare @nro_mes varchar(10)

        select @meses_csv = @meses_csv + ';'

        while charindex(';', @meses_csv) > 0
        begin
            select @pos = charindex(';', @meses_csv)
            select @chunk = ltrim(rtrim(substring(@meses_csv, 1, @pos - 1)))
            select @meses_csv = substring(
                @meses_csv,
                @pos + 1,
                char_length(@meses_csv) - @pos
            )

            if @chunk <> ''
            begin
                select @col_pos = charindex(':', @chunk)

                if @col_pos <= 1 or @col_pos = char_length(@chunk)
                begin
                    select 'Error: Formato de mes invalido. Use anio:mes' as msg
                    return
                end

                select @anio = ltrim(rtrim(substring(@chunk, 1, @col_pos - 1)))
                select @nro_mes = ltrim(rtrim(substring(
                    @chunk,
                    @col_pos + 1,
                    char_length(@chunk) - @col_pos
                )))

                if @anio = ''
                   or @nro_mes = ''
                   or patindex('%[^0-9]%', @anio) > 0
                   or patindex('%[^0-9]%', @nro_mes) > 0
                begin
                    select 'Error: Anio o mes no numerico' as msg
                    return
                end

                if convert(int, @anio) < 2000 or convert(int, @anio) > 2100
                begin
                    select 'Error: Anio fuera de rango' as msg
                    return
                end

                if convert(int, @nro_mes) < 1 or convert(int, @nro_mes) > 12
                begin
                    select 'Error: Mes fuera de rango' as msg
                    return
                end

                if exists (
                    select 1
                    from #meses_raw
                    where anio = convert(smallint, @anio)
                      and nro_mes = convert(tinyint, @nro_mes)
                )
                begin
                    select 'Error: Mes de ejecucion duplicado' as msg
                    return
                end

                insert into #meses_raw (anio, nro_mes)
                values (convert(smallint, @anio), convert(tinyint, @nro_mes))
            end
        end
    end

    create table #meses (
        orden numeric(4,0) identity,
        anio smallint not null,
        nro_mes tinyint not null
    )

    insert into #meses (anio, nro_mes)
    select anio, nro_mes
    from #meses_raw
    order by anio, nro_mes

    create table #meses_nuevos (
        correlativ numeric(4,0) identity,
        anio smallint not null,
        nro_mes tinyint not null
    )

    create table #meses_salen (
        corr_fume tinyint not null
    )

    declare @max_corr int

    insert into #meses_salen (corr_fume)
    select f.corr_fume
    from secgen_db.dbo.sg_fume f
    where f.id_funprse = @id_funprse
      and not exists (
          select 1
          from #meses m
          where m.anio = f.ano_prop
            and m.nro_mes = f.mes_prop
      )

    if @@error <> 0
    begin
        select 'Error al determinar los meses de ejecucion que se retiran' as msg
        return
    end

    if exists (
        select 1
        from secgen_db.dbo.sg_fuc2 c
        where c.id_funprse = @id_funprse
          and c.corr_fume in (select corr_fume from #meses_salen)
    )
    begin
        select 'Error: No se puede quitar un mes de ejecucion con compensacion ya realizada' as msg
        return
    end

    if exists (
        select 1
        from secgen_db.dbo.sg_fum2 h
        where h.id_funprse = @id_funprse
          and h.corr_fume in (select corr_fume from #meses_salen)
    )
    begin
        select 'Error: No se puede quitar un mes de ejecucion con historial registrado' as msg
        return
    end

    begin tran

    delete from secgen_db.dbo.sg_fume
    where id_funprse = @id_funprse
      and corr_fume in (select corr_fume from #meses_salen)

    if @@error <> 0
    begin
        select 'Error al limpiar meses de ejecucion anteriores' as msg
        if @@transtate = 2 rollback tran
        return
    end

    insert into #meses_nuevos (anio, nro_mes)
    select m.anio, m.nro_mes
    from #meses m
    where not exists (
        select 1
        from secgen_db.dbo.sg_fume f
        where f.id_funprse = @id_funprse
          and f.ano_prop = m.anio
          and f.mes_prop = m.nro_mes
    )
    order by m.anio, m.nro_mes

    if @@error <> 0
    begin
        select 'Error al determinar los meses de ejecucion nuevos' as msg
        if @@transtate = 2 rollback tran
        return
    end

    select @max_corr = isnull(max(corr_fume), 0)
    from secgen_db.dbo.sg_fume
    where id_funprse = @id_funprse

    insert into secgen_db.dbo.sg_fume (
        id_funprse,
        corr_fume,
        ano_prop,
        mes_prop,
        cod_estfum
    )
    select
        @id_funprse,
        @max_corr + correlativ,
        anio,
        nro_mes,
        @cod_estfum
    from #meses_nuevos

    if @@error <> 0
    begin
        select 'Error al insertar meses de ejecucion' as msg
        if @@transtate = 2 rollback tran
        return
    end

    commit tran
    select 'Meses de ejecucion actualizados correctamente' as msg
end
go

grant execute on Analisis2.sg_fumeuSecgen01 to UsuaVrac
go
