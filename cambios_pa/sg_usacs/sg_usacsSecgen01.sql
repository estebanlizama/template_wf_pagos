use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
            where a.uid = b.uid
              and a.type = 'P'
              and b.name = 'Analisis2'
              and a.name = 'sg_usacsSecgen01')
    drop procedure Analisis2.sg_usacsSecgen01
go

/* Procedimiento : sg_usacsSecgen01

   Entrada :
   @rut                  -> RUT del funcionario. (Opcional)
   @cod_sistem           -> Codigo del sistema. (Opcional)
   @cod_modulo           -> Codigo del modulo. (Opcional)
   @fecha_eval           -> Fecha de evaluacion. (Opcional)

   Objetivo : Obtener perfiles y privilegios dinamicos de acceso a PDS.

   Creacion: ELA 2026/08/24
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_usacsSecgen01
    @rut         char(9) = null,
    @cod_sistem  char(2) = 'SG',
    @cod_modulo  varchar(8) = 'SISSOLIC',
    @fecha_eval  datetime = null
as

begin
    declare @fecha_val datetime
    select @fecha_val = isnull(@fecha_eval, getdate())

    if @rut is null or ltrim(rtrim(@rut)) = ''
    begin
        select
            convert(char(9), null) as rut,
            convert(char(2), null) as cod_sistem,
            convert(varchar(8), null) as cod_modulo,
            convert(smallint, null) as cod_perfil,
            convert(varchar(100), null) as des_perfil,
            convert(smallint, null) as cod_privil,
            convert(varchar(100), null) as des_privil,
            convert(varchar(100), null) as nom_privil,
            convert(char(1), 'N') as elegible_solicitante,
            convert(char(1), 'N') as tiene_tarea_pendiente,
            convert(char(1), 'N') as es_revisor_pago,
            convert(varchar(100), 'Falta RUT del usuario') as mensaje
        return
    end

    create table #perfiles (
        cod_perfil smallint not null,
        origen varchar(10) not null
    )

    if exists (
        select 1
        from sisper_db..sp_pers pers
        inner join sisper_db..sp_cont cont
            on cont.cod_ficha = pers.cod_ficha
        where pers.rut_person = @rut
          and cont.vigen_cont in ('0', '2')
          and cont.cod_calida <> '01'
          and isnull(cont.f_inicio_d, @fecha_val) <= @fecha_val
          and isnull(cont.f_termino, isnull(cont.f_termin_d, @fecha_val)) >= @fecha_val
    )
    begin
        insert into #perfiles (cod_perfil, origen)
        values (6, 'CONTRATO')
    end

    if exists (
        select 1
        from sisper_db..sp_pers pers
        inner join sisper_db..sp_cont cont on cont.cod_ficha = pers.cod_ficha
        where pers.rut_person = @rut
          and cont.vigen_cont in ('0', '2')
          and cont.cod_calida <> '01'
          and isnull(cont.f_inicio_d, @fecha_val) <= @fecha_val
          and isnull(cont.f_termino, isnull(cont.f_termin_d, @fecha_val)) >= @fecha_val
          and exists (
              select 1 from sisper_db.dbo.sp_orde orde
              where orde.cod_organi = 696
                and orde.rut_person = @rut
                and orde.vigente = 'S'
          )
    )
    begin
        insert into #perfiles (cod_perfil, origen)
        select 33, 'PAGO_DGDP'
        where not exists (select 1 from #perfiles where cod_perfil = 33)
    end

    insert into #perfiles (cod_perfil, origen)
    select distinct eta.cod_perfil, 'TAREA'
    from secgen_db..sg_apso apso
    inner join secgen_db..sg_prse prse
        on prse.nro_solici = apso.nro_solici
       and prse.cod_flusol = apso.cod_flusol
       and prse.cod_etapa = apso.cod_etapa
    inner join secgen_db..sg_eta1 eta
        on eta.cod_flusol = apso.cod_flusol
       and eta.cod_etapa = apso.cod_etapa
    where apso.cod_estapr = 4
      and apso.rut_usua = @rut
      and isnull(eta.vigente, 'S') = 'S'
      and not exists (
          select 1
          from #perfiles p
          where p.cod_perfil = eta.cod_perfil
      )

    select
        @rut as rut,
        per.cod_sistem,
        per.cod_modulo,
        per.cod_perfil,
        per.des_perfil,
        pri.cod_privil,
        pri.des_privil,
        pri.nom_privil,
        case
            when exists (
                select 1 from #perfiles p
                where p.cod_perfil = 6 and p.origen = 'CONTRATO'
            ) then 'S'
            else 'N'
        end as elegible_solicitante,
        case
            when exists (
                select 1 from #perfiles p
                where p.origen = 'TAREA'
            ) then 'S'
            else 'N'
        end as tiene_tarea_pendiente,
        case
            when exists (
                select 1 from #perfiles p
                where p.cod_perfil = 33 and p.origen = 'PAGO_DGDP'
            ) then 'S'
            else 'N'
        end as es_revisor_pago,
        convert(varchar(100), null) as mensaje
    from #perfiles ctx
    inner join sistema_db..bd_per1 per
        on per.cod_sistem = @cod_sistem
       and per.cod_modulo = @cod_modulo
       and per.cod_perfil = ctx.cod_perfil
    left join sistema_db..bd_pepr pep
        on pep.cod_sistem = per.cod_sistem
       and pep.cod_modulo = per.cod_modulo
       and pep.cod_perfil = per.cod_perfil
    left join sistema_db..bd_prvg pri
        on pri.cod_sistem = pep.cod_sistem
       and pri.cod_modulo = pep.cod_modulo
       and pri.cod_privil = pep.cod_privil
    order by per.cod_perfil, pri.cod_privil

    drop table #perfiles
end
go

grant execute on Analisis2.sg_usacsSecgen01 to UsuaVrac
go
