use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sp_as01sSecgen01')
   drop procedure Analisis2.sp_as01sSecgen01

go

/* Procedimiento : sp_as01sSecgen01

   Entrada :
   @rut                 -> RUT del funcionario. (Obligatorio)
   @cod_periodo         -> Periodo de evaluacion que define el rango. (Opcional)
   @f_inicio            -> Fecha inicial del rango, formato YYYYMMDD. (Opcional)
   @f_termino           -> Fecha final del rango, formato YYYYMMDD. (Opcional)

   Objetivo : Entregar el registro de asistencia diario de un funcionario, con
   marca real, horario de turno, estado, ausencias, justificaciones y feriados.

   Creacion: ELA 2026/09/29
   Actualizacion: Sin registro
*/
create procedure Analisis2.sp_as01sSecgen01
    @rut char(9) = null,
    @cod_periodo smallint = null,
    @f_inicio char(8) = null,
    @f_termino char(8) = null
as

begin
    set nocount on

    declare @inicio     datetime
    declare @termino    datetime
    declare @tol_entrad int
    declare @tol_salida int

    if @rut is null
    begin
        select 'Error: Falta el RUT del funcionario' as msg
        return
    end

    if @cod_periodo is null and (@f_inicio is null or @f_termino is null)
    begin
        select 'Error: Indique un periodo o un rango de fechas completo' as msg
        return
    end

    if not exists (select 1 from sisper_db..sp_pers where rut_person = @rut)
    begin
        select 'Error: El funcionario no se encuentra registrado en personal' as msg
        return
    end

    if not exists (select 1 from ufro_db..sp_pers where rut = @rut)
    begin
        select 'Error: El funcionario no se encuentra en el maestro institucional' as msg
        return
    end

    if @cod_periodo is not null
    begin
        if not exists (select 1 from sisper_db..sp_prdo where cod_periodo = @cod_periodo)
        begin
            select 'Error: El periodo de evaluacion no existe' as msg
            return
        end

        select @inicio  = f_inicio,
               @termino = f_termino
        from sisper_db..sp_prdo
        where cod_periodo = @cod_periodo

        if (@inicio is null and @termino is null)
           or (@inicio = '19000101' and @termino = '19000101')
        begin
            select @inicio  = dateadd(dd, -8, getdate())
            select @termino = dateadd(dd,  7, getdate())
        end

        if @inicio is null
            select @inicio = dateadd(dd, -14, @termino)

        if @termino is null
            select @termino = dateadd(dd, 14, @inicio)
    end
    else
    begin
        if char_length(@f_inicio) <> 8
           or char_length(@f_termino) <> 8
           or patindex('%[^0-9]%', @f_inicio) > 0
           or patindex('%[^0-9]%', @f_termino) > 0
        begin
            select 'Error: Formato de fecha invalido. Use YYYYMMDD' as msg
            return
        end

        if convert(int, substring(@f_inicio, 5, 2)) not between 1 and 12
           or convert(int, substring(@f_termino, 5, 2)) not between 1 and 12
           or convert(int, substring(@f_inicio, 7, 2)) not between 1 and 31
           or convert(int, substring(@f_termino, 7, 2)) not between 1 and 31
        begin
            select 'Error: Mes o dia fuera de rango' as msg
            return
        end

        select @inicio  = convert(datetime, @f_inicio, 112)
        select @termino = convert(datetime, @f_termino, 112)
    end

    if @termino < @inicio
    begin
        select 'Error: La fecha de termino es anterior a la de inicio' as msg
        return
    end

    select @termino = dateadd(ss, 86399,
                              convert(datetime, convert(char(8), @termino, 112), 112))

    select @tol_entrad = isnull(tol_entrad, 0),
           @tol_salida = isnull(tol_salida, 0)
    from sisper_db..sp_pasi

    create table #ausencias (
        cod_asist   int          not null,
        res_ausen   varchar(255) null,
        tie_licmed  char(1)      null,
        tie_singoce char(1)      null
    )

    declare @c_asist int
    declare @c_ant   int
    declare @motivo  varchar(60)
    declare @acum    varchar(255)
    declare @tipgru  tinyint
    declare @codgru  tinyint
    declare @licmed  char(1)
    declare @singoce char(1)

    declare cur_ausen cursor for
        select a.cod_asist, f.des_ausen, e.tip_agraus, e.cod_agraus
        from sisper_db..sp_as01 a
        inner join sisper_db..sp_as21 e
            on e.cod_asist = a.cod_asist
        inner join sisper_db..sp_eaus f
            on f.tip_agraus = e.tip_agraus
           and f.cod_agraus = e.cod_agraus
        where a.rut = @rut
          and a.f_ent_o between @inicio and @termino
        order by a.cod_asist
    for read only

    open cur_ausen
    fetch cur_ausen into @c_asist, @motivo, @tipgru, @codgru

    while @@sqlstatus = 0
    begin
        select @c_ant = @c_asist
        select @acum   = null
        select @licmed = 'N'
        select @singoce = 'N'

        while @@sqlstatus = 0 and @c_asist = @c_ant
        begin
            if @acum is null
                select @acum = @motivo
            else
                select @acum = @acum + ' | ' + @motivo

            if @tipgru = 2
                select @licmed = 'S'

            if @tipgru = 1 and @codgru = 2
                select @singoce = 'S'

            fetch cur_ausen into @c_asist, @motivo, @tipgru, @codgru
        end

        insert into #ausencias (cod_asist, res_ausen, tie_licmed, tie_singoce)
        values (@c_ant, @acum, @licmed, @singoce)
    end

    close cur_ausen
    deallocate cursor cur_ausen

    create table #justif (
        cod_asist  int          not null,
        excusa     varchar(255) null
    )

    declare @j_asist int
    declare @j_ant   int
    declare @detalle varchar(120)
    declare @acumjus varchar(255)

    declare cur_justif cursor for
        select b.cod_asist,
               rtrim(x.des_tipjus) + '/' + rtrim(y.des_catjus)
        from sisper_db..sp_as01 a
        inner join sisper_db..sp_as31 b
            on b.cod_asist = a.cod_asist
        inner join sisper_db..sp_tjus x
            on x.cod_tipjus = b.cod_tipjus
        inner join sisper_db..sp_cjus y
            on y.cod_catjus = b.cod_catjus
        where a.rut = @rut
          and a.f_ent_o between @inicio and @termino
        order by b.cod_asist
    for read only

    open cur_justif
    fetch cur_justif into @j_asist, @detalle

    while @@sqlstatus = 0
    begin
        select @j_ant   = @j_asist
        select @acumjus = null

        while @@sqlstatus = 0 and @j_asist = @j_ant
        begin
            if @acumjus is null
                select @acumjus = @detalle
            else
                select @acumjus = @acumjus + ' | ' + @detalle

            fetch cur_justif into @j_asist, @detalle
        end

        insert into #justif (cod_asist, excusa) values (@j_ant, @acumjus)
    end

    close cur_justif
    deallocate cursor cur_justif

    select
        a.cod_asist                                   as cod_asist,
        convert(char(8), a.f_ent_o, 112)              as fecha,
        a.f_ent_o                                     as fec_asist,
        convert(tinyint, (datediff(dd, '19000101', a.f_ent_o) % 7) + 1)
                                                      as cod_diasem,
        case (datediff(dd, '19000101', a.f_ent_o) % 7) + 1
             when 1 then 'Lunes'
             when 2 then 'Martes'
             when 3 then 'Miercoles'
             when 4 then 'Jueves'
             when 5 then 'Viernes'
             when 6 then 'Sabado'
             when 7 then 'Domingo'
        end                                           as des_diasem,
        convert(char(5), a.f_entrada, 108)            as hora_marca_ent,
        convert(char(5), a.f_salida, 108)             as hora_marca_sal,
        convert(char(5), a.hora_ent_o, 108)           as hora_turno_ent,
        convert(char(5), a.hora_sal_o, 108)           as hora_turno_sal,
        case
            when a.f_entrada is null or a.f_salida is null then null
            when datediff(mi, a.f_entrada, a.f_salida) < 0
                then datediff(mi, a.f_entrada, a.f_salida) + 1440
            else datediff(mi, a.f_entrada, a.f_salida)
        end                                           as min_marcados,
        case
            when a.hora_ent_o is null or a.hora_sal_o is null then null
            when datediff(mi, a.hora_ent_o, a.hora_sal_o) < 0
                then datediff(mi, a.hora_ent_o, a.hora_sal_o) + 1440
            else datediff(mi, a.hora_ent_o, a.hora_sal_o)
        end                                           as min_turno,
        a.cod_turno                                   as cod_turno,
        isnull(t.ver_hora, 'N')                       as ver_hora,
        a.cod_estasi                                  as cod_estasi,
        b.des_estasi                                  as des_estasi,
        case when au.cod_asist is null then 'N' else 'S' end as tie_ausenc,
        au.res_ausen                                  as res_ausen,
        isnull(au.tie_licmed, 'N')                    as tie_licmed,
        isnull(au.tie_singoce, 'N')                   as tie_singoce,
        case when ju.cod_asist is null then 'N' else 'S' end as tie_justif,
        ju.excusa                                     as excusa,
        case when fe.cod_tipfer is null then 'N' else 'S' end as es_feriado,
        fe.cod_tipfer                                 as cod_tipfer,
        tf.des_tipfer                                 as des_tipfer,
        case
            when a.f_entrada is null or a.hora_ent_o is null then null
            when datediff(mi, a.hora_ent_o, a.f_entrada) <= @tol_entrad then 0
            else datediff(mi, a.hora_ent_o, a.f_entrada) - @tol_entrad
        end                                           as min_atraso,
        case
            when a.f_salida is null or a.hora_sal_o is null then null
            when datediff(mi, a.f_salida, a.hora_sal_o) <= @tol_salida then 0
            else datediff(mi, a.f_salida, a.hora_sal_o) - @tol_salida
        end                                           as min_anticip,
        @tol_entrad                                   as tol_entrad,
        @tol_salida                                   as tol_salida
    from sisper_db..sp_as01 a
    inner join sisper_db..sp_easi b
        on b.cod_estasi = a.cod_estasi
    left join sisper_db..sp_turn t
        on t.cod_turno = a.cod_turno
    left join #ausencias au
        on au.cod_asist = a.cod_asist
    left join #justif ju
        on ju.cod_asist = a.cod_asist
    left join ufro_db..es_cfer fe
        on convert(char(8), fe.f_feriado, 112) = convert(char(8), a.f_ent_o, 112)
    left join ufro_db..es_tfer tf
        on tf.cod_tipfer = fe.cod_tipfer
    where a.rut = @rut
      and a.f_ent_o between @inicio and @termino
    order by a.f_ent_o

    drop table #ausencias
    drop table #justif
end
go

grant execute on Analisis2.sp_as01sSecgen01 to UsuaVrac
go
