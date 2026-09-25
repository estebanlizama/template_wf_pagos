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
   @rut                 -> RUT del funcionario a consultar. (Obligatorio)
   @cod_periodo         -> Codigo del periodo de evaluacion en sp_prdo. (Obligatorio)

   Objetivo : Consulta de asistencia, ausencias, turnos, justificaciones y feriados de un funcionario.

   Creacion: ELA 2026/09/25
   Actualizacion: Sin registro
*/
create procedure Analisis2.sp_as01sSecgen01
    @rut char(9) = null,
    @cod_periodo smallint = null
as
begin
    set nocount on

    declare @n_dias_jus int
    declare @fecha_hoy datetime
    declare @inicio datetime
    declare @termino datetime

    select @n_dias_jus = n_dias_jus from sisper_db..sp_pasi
    select @fecha_hoy = getdate()

    if @rut is null or @cod_periodo is null
    begin
        select 'Error en parametros de la consulta.' as msg
        return
    end

    if not exists (select 1 from sisper_db..sp_pers where rut_person = @rut)
    begin
        select 'El funcionario RUT ' + @rut + ' no se encuentra registrado.' as msg
        return
    end

    if not exists (select 1 from sisper_db..sp_prdo where cod_periodo = @cod_periodo)
    begin
        select 'El Periodo de Evaluacion ingresado no existe.' as msg
        return
    end

    select @inicio = f_inicio,
           @termino = f_termino
      from sisper_db..sp_prdo
     where cod_periodo = @cod_periodo

    if (@inicio is null and @termino is null) or (@inicio = '1900/01/01' and @termino = '1900/01/01')
    begin
        select @inicio = dateadd(dd, -8, getdate())
        select @termino = dateadd(dd, 7, getdate())
    end

    if @inicio is null
    begin
        select @inicio = dateadd(dd, -14, @termino)
    end

    if @termino is null
    begin
        select @termino = dateadd(dd, 14, @inicio)
    end

    create table #ausencias (
        cod_asist int null,
        res_ausen varchar(255) null
    )

    create table #asist (
        cod_asist  int not null,
        ndia       tinyint not null,
        fecha      char(10) not null,
        hora_e     char(5) not null,
        hora_s     char(5) not null,
        m_ent      char(5) null,
        m_sal      char(5) null,
        cod_estasi tinyint not null,
        des_estasi varchar(20) not null,
        res_ausen  varchar(255) null,
        f_ent_o    datetime not null,
        diasem     varchar(10) null,
        excusa     varchar(320) null,
        feriado    varchar(60) null
    )

    declare @cod_asist int,
            @res_ausen varchar(30),
            @cod_asist2 int,
            @tot_ausen varchar(255)

    declare ausencia cursor for
        select a.cod_asist, f.res_ausen
          from sisper_db..sp_as01 a,
               sisper_db..sp_as21 e,
               sisper_db..sp_eaus f
         where a.rut = @rut
           and a.f_ent_o between @inicio and @termino
           and a.cod_asist = e.cod_asist
           and f.tip_agraus = e.tip_agraus
           and f.cod_agraus = e.cod_agraus

    open ausencia
    fetch ausencia into @cod_asist, @res_ausen
    while @@sqlstatus <> 2
    begin
        select @cod_asist2 = @cod_asist
        select @tot_ausen = null
        while @cod_asist2 = @cod_asist and @@sqlstatus <> 2
        begin
            if @tot_ausen is not null
                select @tot_ausen = @tot_ausen + '<br>' + @res_ausen
            else
                select @tot_ausen = @res_ausen
            fetch ausencia into @cod_asist, @res_ausen
        end
        insert #ausencias values (@cod_asist2, @tot_ausen)
    end
    close ausencia
    deallocate cursor ausencia

    insert into #asist (
        cod_asist, ndia, fecha, hora_e, hora_s, m_ent, m_sal,
        cod_estasi, des_estasi, res_ausen, f_ent_o, diasem, excusa, feriado
    )
    select a.cod_asist,
           datepart(cdw, a.f_ent_o) as dia,
           convert(varchar(10), a.f_ent_o, 103) as fecha,
           case f.ver_hora
               when 'S' then convert(varchar(5), a.hora_ent_o, 108)
               else 'T.S.H.'
           end as hora_e,
           case f.ver_hora
               when 'S' then convert(varchar(5), a.hora_sal_o, 108)
               else 'T.S.H.'
           end as hora_s,
           convert(varchar(5), a.f_entrada, 108) as m_ent,
           convert(varchar(5), a.f_salida, 108) as m_sal,
           a.cod_estasi,
           b.des_estasi,
           e.res_ausen,
           a.f_ent_o,
           null, null, null
      from sisper_db..sp_as01 a
     inner join sisper_db..sp_easi b on a.cod_estasi = b.cod_estasi
     inner join ufro_db..sp_pers d on d.rut = a.rut
     inner join sisper_db..sp_turn f on f.cod_turno = a.cod_turno
      left join #ausencias e on e.cod_asist = a.cod_asist
      left join sisper_db..sp_as31 g on g.cod_asist = a.cod_asist
     where a.rut = @rut
       and a.f_ent_o between @inicio and @termino
     order by a.f_ent_o

    update #asist
       set excusa = rtrim(x.des_tipjus) + '/' + rtrim(y.des_catjus)
      from #asist a,
           sisper_db..sp_as31 b,
           sisper_db..sp_cjus y,
           sisper_db..sp_tjus x
     where b.cod_asist = a.cod_asist
       and b.cod_catjus = y.cod_catjus
       and b.cod_tipjus = x.cod_tipjus

    update #asist set diasem = 'Lunes'     where ndia = 1
    update #asist set diasem = 'Martes'    where ndia = 2
    update #asist set diasem = 'Miercoles' where ndia = 3
    update #asist set diasem = 'Jueves'    where ndia = 4
    update #asist set diasem = 'Viernes'   where ndia = 5
    update #asist set diasem = 'Sabado'    where ndia = 6
    update #asist set diasem = 'Domingo'   where ndia = 7

    update #asist
       set feriado = b.des_tipfer
      from #asist z,
           ufro_db..es_cfer a,
           ufro_db..es_tfer b
     where a.cod_tipfer = b.cod_tipfer
       and z.f_ent_o = a.f_feriado

    select diasem, feriado, fecha, hora_e, hora_s, m_ent, m_sal,
           res_ausen, excusa, cod_estasi, des_estasi
      from #asist
     order by f_ent_o

    drop table #asist
    drop table #ausencias
end
go

grant execute on Analisis2.sp_as01sSecgen01 to UsuaVrac
go
