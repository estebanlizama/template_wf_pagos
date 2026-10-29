use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
            where a.uid = b.uid
              and a.type = 'P'
              and b.name = 'Analisis2'
              and a.name = 'sg_epagsSecgen05')
    drop procedure Analisis2.sg_epagsSecgen05
go

/* Procedimiento : sg_epagsSecgen05

   Entrada :
   @rut_person          -> RUT del revisor DGDP. (Obligatorio)
   @cod_estcuo          -> Estado de cuota 4 o 8. (Obligatorio)
   @installments_csv    -> Claves id_funprse-nro_cuota separadas por coma.
                           (Obligatorio)

   Objetivo : Entregar en una lectura las cuotas seleccionadas para el archivo
   de Finanzas, con un registro por mes de pago/asignacion SISPER y centro de
   costo. El neto aprobado de la cuota se distribuye segun el porcentaje CC.

   Creacion: ELA 2026/10/28
   Actualizacion: 2026/10/29 - Agregados con columnas locales para ASE.
*/
create procedure Analisis2.sg_epagsSecgen05
    @rut_person char(9) = null,
    @cod_estcuo tinyint = null,
    @installments_csv varchar(4000) = null
as

declare @ids varchar(4000),
        @coma int,
        @guion int,
        @token varchar(40),
        @id_texto varchar(20),
        @id_funprse int,
        @cuota_texto varchar(5),
        @nro_cuota tinyint

if @rut_person is null or ltrim(rtrim(@rut_person)) = ''
   or @cod_estcuo is null or @cod_estcuo not in (4, 8)
   or @installments_csv is null
   or ltrim(rtrim(@installments_csv)) = ''
begin
    select 'Faltan antecedentes para preparar el archivo de Finanzas.' as msg
    return
end

select @rut_person = right('000000000' + ltrim(rtrim(@rut_person)), 9),
       @ids = ltrim(rtrim(@installments_csv))

if patindex('%[^0-9,-]%', @ids) > 0
begin
    select 'La lista de prestaciones contiene un identificador no valido.' as msg
    return
end

create table #cuotas_finanzas (
    id_funprse int not null,
    nro_cuota tinyint not null,
    primary key (id_funprse, nro_cuota)
)

while charindex(',', @ids) > 0
begin
    select @coma = charindex(',', @ids),
           @token = ltrim(rtrim(substring(@ids, 1, charindex(',', @ids) - 1)))

    select @guion = charindex('-', @token)
    if @guion <= 1 or @guion >= len(@token)
    begin
        select 'La lista de cuotas contiene una clave no valida.' as msg
        return
    end

    select @id_texto = substring(@token, 1, @guion - 1),
           @cuota_texto = substring(@token, @guion + 1, 5)

    if @id_texto = '' or @cuota_texto = ''
       or patindex('%[^0-9]%', @id_texto) > 0
       or patindex('%[^0-9]%', @cuota_texto) > 0
       or len(@id_texto) > 10 or len(@cuota_texto) > 3
    begin
        select 'La lista de cuotas contiene una clave no valida.' as msg
        return
    end
    if convert(decimal(20,0), @id_texto) > 2147483647
       or convert(int, @cuota_texto) > 255
    begin
        select 'La lista de cuotas contiene una clave no valida.' as msg
        return
    end

    select @id_funprse = convert(int, @id_texto),
           @nro_cuota = convert(tinyint, @cuota_texto)
    if isnull(@id_funprse, 0) <= 0 or isnull(@nro_cuota, 0) <= 0
    begin
        select 'La lista de cuotas contiene una clave no valida.' as msg
        return
    end
    if not exists (select 1 from #cuotas_finanzas where id_funprse = @id_funprse and nro_cuota = @nro_cuota)
        insert into #cuotas_finanzas (id_funprse, nro_cuota) values (@id_funprse, @nro_cuota)

    select @ids = substring(@ids, @coma + 1, 4000)
end

if ltrim(rtrim(@ids)) = ''
begin
    select 'La lista de cuotas contiene una clave no valida.' as msg
    return
end

select @token = ltrim(rtrim(@ids)),
       @guion = charindex('-', ltrim(rtrim(@ids)))
if @guion <= 1 or @guion >= len(ltrim(rtrim(@ids)))
begin
    select 'La lista de cuotas contiene una clave no valida.' as msg
    return
end
select @id_texto = substring(@token, 1, @guion - 1),
       @cuota_texto = substring(@token, @guion + 1, 5)
if @id_texto = '' or @cuota_texto = ''
   or patindex('%[^0-9]%', @id_texto) > 0
   or patindex('%[^0-9]%', @cuota_texto) > 0
   or len(@id_texto) > 10 or len(@cuota_texto) > 3
begin
    select 'La lista de cuotas contiene una clave no valida.' as msg
    return
end
if convert(decimal(20,0), @id_texto) > 2147483647
   or convert(int, @cuota_texto) > 255
begin
    select 'La lista de cuotas contiene una clave no valida.' as msg
    return
end
select @id_funprse = convert(int, @id_texto),
       @nro_cuota = convert(tinyint, @cuota_texto)
if isnull(@id_funprse, 0) <= 0 or isnull(@nro_cuota, 0) <= 0
begin
    select 'La lista de cuotas contiene una clave no valida.' as msg
    return
end
if not exists (select 1 from #cuotas_finanzas where id_funprse = @id_funprse and nro_cuota = @nro_cuota)
    insert into #cuotas_finanzas (id_funprse, nro_cuota) values (@id_funprse, @nro_cuota)

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
          select 1 from sisper_db.dbo.sp_orde orde
          where orde.cod_organi = 696
            and orde.rut_person = @rut_person
            and orde.vigente = 'S'
      )
)
begin
    select 'El usuario no tiene asignacion vigente para revisar cuotas DGDP.' as msg
    return
end

select d.id_funprse,
       d.nro_cuota,
       sum(isnull(f.mto_apagar, 0) - isnull(f.mto_deslic, 0)
           - isnull(f.mto_dessg, 0)) as neto
  into #montos_cuota_finanzas
  from secgen_db.dbo.sg_dpag d
  inner join #cuotas_finanzas ids
          on ids.id_funprse = d.id_funprse
         and ids.nro_cuota = d.nro_cuota
  inner join secgen_db.dbo.sg_fume f
          on f.id_funprse = d.id_funprse
         and f.corr_fume = d.corr_fume
 group by d.id_funprse, d.nro_cuota

select
    fu.id_funprse,
    epag.nro_cuota,
    epag.ano_pago * 100 + epag.mes_pago as payment_period,
    asds.cod_asign,
    ccas.cod_ccasig,
    case when len(isnull(pers.nom_dest, '')) <= 1
         then pers.nom_nombre else pers.nom_dest end as nombre,
    pers.nom_appate,
    pers.nom_apmate,
    fu.rut as rut_funcionario,
    asds.num_cuenta as codigo_haber,
    case when isnull(asds.valor, 0) = 0 or ccas.valor_asig is null then null
         when ccas.cod_ccasig = (
             select max(ccas_ult.cod_ccasig)
               from sisper_db..ss_ccas ccas_ult
              where ccas_ult.cod_ficha = asds.cod_ficha
                and ccas_ult.cod_asign = asds.cod_asign)
         then monto_cuota.neto - isnull((
             select sum(convert(decimal(19,0), round(
                        monto_ant.neto * convert(decimal(19,6), ccas_ant.valor_asig)
                        / nullif(convert(decimal(19,6), asds_ant.valor), 0), 0)))
               from sisper_db..ss_ccas ccas_ant
               inner join sisper_db..ss_asds asds_ant
                       on asds_ant.cod_ficha = ccas_ant.cod_ficha
                      and asds_ant.cod_asign = ccas_ant.cod_asign
               inner join #montos_cuota_finanzas monto_ant
                       on monto_ant.id_funprse = epag.id_funprse
                      and monto_ant.nro_cuota = epag.nro_cuota
              where ccas_ant.cod_ficha = asds.cod_ficha
                and ccas_ant.cod_asign = asds.cod_asign
                and ccas_ant.cod_ccasig < ccas.cod_ccasig), 0)
         else convert(decimal(19,0), round(
             monto_cuota.neto * convert(decimal(19,6), ccas.valor_asig)
             / nullif(convert(decimal(19,6), asds.valor), 0), 0)) end as monto_neto,
    convert(char(8), asds.f_inicio, 112) as fec_inicio,
    convert(char(8), asds.f_termino, 112) as fec_termino,
    convert(varchar(6), ccas.cod_unifin) + '.' + convert(varchar(6), ccas.cod_ccto) as centro_costo,
    fu.cod_sitm as item_solicitud,
    ccas.cod_item as item_sisper,
    case when isnull(ltrim(rtrim(fu.cod_sitm)), '') = isnull(ltrim(rtrim(ccas.cod_item)), '')
         then 1 else 0 end as item_coincide,
    case when isnull(asds.valor, 0) = 0 then null
         else convert(decimal(9,2),
             convert(decimal(19,6), ccas.valor_asig)
             / nullif(convert(decimal(19,6), asds.valor), 0) * 100) end as porcentaje_cc,
    case when isnull(asds.valor, 0) > 0
           and (select sum(ccas_tot.valor_asig)
                  from sisper_db..ss_ccas ccas_tot
                 where ccas_tot.cod_ficha = asds.cod_ficha
                   and ccas_tot.cod_asign = asds.cod_asign) = asds.valor
         then 1 else 0 end as porcentajes_suman_100,
    rslc.num_resolu as numero_resolucion_exenta,
    '05000000' as codigo_unidad_resolucion,
    rslc.ano_resolu as ano_resolucion
from #cuotas_finanzas ids
inner join secgen_db.dbo.sg_epag epag
        on epag.id_funprse = ids.id_funprse
       and epag.nro_cuota = ids.nro_cuota
       and epag.cod_estcuo = @cod_estcuo
inner join secgen_db.dbo.sg_fups fu on fu.id_funprse = epag.id_funprse
inner join secgen_db.dbo.sg_soli soli on soli.nro_solici = fu.nro_solici
inner join secgen_db.dbo.sg_rslc rslc
        on rslc.nro_resolu = soli.nro_resolu
       and rslc.ano_resolu = soli.ano_resolu
inner join sisper_db..sp_pers pers on pers.rut_person = fu.rut
inner join sisper_db..ss_asds asds
        on asds.cod_ficha = pers.cod_ficha
       and right('0000000000' + ltrim(rtrim(asds.num_resol)), 10)
           = right('0000000000' + convert(varchar(10), rslc.num_resolu), 10)
       and asds.cod_ders = '2'
       and asds.cod_unidad = '05000000'
       and asds.ano = convert(char(4), rslc.ano_resolu)
       and convert(char(8), asds.f_inicio, 112)
           = convert(char(8), convert(datetime,
               convert(char(4), epag.ano_pago)
               + right('0' + convert(varchar(2), epag.mes_pago), 2) + '01', 112), 112)
       and convert(char(8), asds.f_termino, 112)
           = convert(char(8), dateadd(dd, -1, dateadd(mm, 1, convert(datetime,
               convert(char(4), epag.ano_pago)
               + right('0' + convert(varchar(2), epag.mes_pago), 2) + '01', 112))), 112)
left join sisper_db..ss_ccas ccas
       on ccas.cod_ficha = asds.cod_ficha
      and ccas.cod_asign = asds.cod_asign
inner join #montos_cuota_finanzas monto_cuota
        on monto_cuota.id_funprse = epag.id_funprse
       and monto_cuota.nro_cuota = epag.nro_cuota
where epag.cod_estcuo = @cod_estcuo
order by fu.id_funprse, epag.ano_pago, epag.mes_pago, epag.nro_cuota,
         asds.cod_asign, ccas.cod_ccasig
go

grant execute on Analisis2.sg_epagsSecgen05 to UsuaVrac
go
