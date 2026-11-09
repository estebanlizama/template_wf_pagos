use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
            where a.uid = b.uid
              and a.type = 'P'
              and b.name = 'Analisis2'
              and a.name = 'sg_epagsSecgen06')
    drop procedure Analisis2.sg_epagsSecgen06
go

/* Procedimiento : sg_epagsSecgen06

   Entrada :
   @rut_person           -> RUT del revisor DGDP. (Obligatorio)
   @installments_csv     -> Claves id_funprse-nro_cuota separadas por coma.
                           (Obligatorio)

   Objetivo : Entregar, por cada cuota, si su asignacion ya existe en sisper_db..ss_asds y los
   datos con que ingresarla. Una fila por cuota, este o no registrada.

   Creacion: ELA 2026/11/02
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_epagsSecgen06
    @rut_person char(9) = null,
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
   or @installments_csv is null
   or ltrim(rtrim(@installments_csv)) = ''
begin
    select 'Faltan antecedentes para consultar el registro en SISPER.' as msg
    return
end

select @rut_person = right('000000000' + ltrim(rtrim(@rut_person)), 9),
       @ids = ltrim(rtrim(@installments_csv))

if patindex('%[^0-9,-]%', @ids) > 0
begin
    select 'La lista de prestaciones contiene un identificador no valido.' as msg
    return
end

create table #cuotas_consulta (
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
    if not exists (select 1 from #cuotas_consulta where id_funprse = @id_funprse and nro_cuota = @nro_cuota)
        insert into #cuotas_consulta (id_funprse, nro_cuota) values (@id_funprse, @nro_cuota)

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
if not exists (select 1 from #cuotas_consulta where id_funprse = @id_funprse and nro_cuota = @nro_cuota)
    insert into #cuotas_consulta (id_funprse, nro_cuota) values (@id_funprse, @nro_cuota)

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
  into #montos_consulta
  from secgen_db.dbo.sg_dpag d
  inner join #cuotas_consulta ids
          on ids.id_funprse = d.id_funprse
         and ids.nro_cuota = d.nro_cuota
  inner join secgen_db.dbo.sg_fume f
          on f.id_funprse = d.id_funprse
         and f.corr_fume = d.corr_fume
 group by d.id_funprse, d.nro_cuota

select ids.id_funprse,
       ids.nro_cuota,
       pers.cod_ficha,
       rslc.num_resolu as num_resolu_ext,
       rslc.ano_resolu,
       convert(char(8), rslc.f_resolucio, 112) as f_resolucio,
       convert(char(8), convert(datetime,
           convert(char(4), epag.ano_pago)
           + right('0' + convert(varchar(2), epag.mes_pago), 2) + '01', 112), 112) as fec_inicio,
       convert(char(8), dateadd(dd, -1, dateadd(mm, 1, convert(datetime,
           convert(char(4), epag.ano_pago)
           + right('0' + convert(varchar(2), epag.mes_pago), 2) + '01', 112))), 112) as fec_termino,
       'PRESTACION ' + convert(varchar(10), ids.id_funprse)
           + ' CUOTA ' + convert(varchar(3), ids.nro_cuota) as marcador,
       isnull(monto.neto, 0) as neto,
       prse.cod_unifin,
       prse.cod_ccto,
       fu.cod_sitm,
       (select count(distinct si.cod_sitm)
          from fin21_db..pt_sitm si
         where convert(varchar(5), si.item_antig) = ltrim(rtrim(isnull(fu.cod_sitm, '')))
           and si.vigencia = '1') as cant_subitem,
       (select min(si.cod_sitm)
          from fin21_db..pt_sitm si
         where convert(varchar(5), si.item_antig) = ltrim(rtrim(isnull(fu.cod_sitm, '')))
           and si.vigencia = '1') as cod_sitm_vigente
  into #claves_consulta
  from #cuotas_consulta ids
  inner join secgen_db.dbo.sg_epag epag
          on epag.id_funprse = ids.id_funprse
         and epag.nro_cuota = ids.nro_cuota
  inner join secgen_db.dbo.sg_fups fu on fu.id_funprse = epag.id_funprse
  inner join secgen_db.dbo.sg_soli soli on soli.nro_solici = fu.nro_solici
  inner join secgen_db.dbo.sg_prse prse on prse.nro_solici = fu.nro_solici
  inner join secgen_db.dbo.sg_rslc rslc
          on rslc.nro_resolu = soli.nro_resolu
         and rslc.ano_resolu = soli.ano_resolu
  inner join sisper_db..sp_pers pers on pers.rut_person = fu.rut
  left join #montos_consulta monto
         on monto.id_funprse = ids.id_funprse
        and monto.nro_cuota = ids.nro_cuota

select cla.id_funprse,
       cla.nro_cuota,
       cla.cod_ficha,
       asds.cod_asign,
       asds.valor,
       asds.num_cuenta,
       asds.vigencia,
       asds.observac,
       case when ltrim(rtrim(isnull(asds.observac, ''))) = cla.marcador
            then 1 else 0 end as es_marcada
  into #asignaciones_consulta
  from #claves_consulta cla
  inner join sisper_db..ss_asds asds
          on asds.cod_ficha = cla.cod_ficha
         and right('0000000000' + ltrim(rtrim(asds.num_resol)), 10)
             = right('0000000000' + convert(varchar(10), cla.num_resolu_ext), 10)
         and asds.cod_ders = '2'
         and asds.cod_unidad = '05000000'
         and asds.ano = convert(char(4), cla.ano_resolu)
         and convert(char(8), asds.f_inicio, 112) = cla.fec_inicio
         and convert(char(8), asds.f_termino, 112) = cla.fec_termino

select cla.id_funprse,
       cla.nro_cuota,
       cla.marcador,
       cla.cod_ficha,
       cla.num_resolu_ext,
       cla.ano_resolu,
       cla.f_resolucio,
       cla.fec_inicio,
       cla.fec_termino,
       cla.neto,
       cla.cod_unifin,
       cla.cod_ccto,
       cla.cod_sitm,
       cla.cant_subitem,
       cla.cod_sitm_vigente,
       (select count(*)
          from sisper_db..sp_resl res
         where right('0000000000' + ltrim(rtrim(res.num_resol)), 10)
               = right('0000000000' + convert(varchar(10), cla.num_resolu_ext), 10)
           and res.cod_ders = '2'
           and res.cod_unidad = '05000000'
           and res.ano = convert(char(4), cla.ano_resolu)) as cant_resoluciones,
       (select count(*)
          from #asignaciones_consulta a
         where a.id_funprse = cla.id_funprse
           and a.nro_cuota = cla.nro_cuota) as cant_asignaciones,
       (select count(*)
          from #asignaciones_consulta a
         where a.id_funprse = cla.id_funprse
           and a.nro_cuota = cla.nro_cuota
           and a.es_marcada = 1) as cant_marcadas,
       (select min(a.cod_asign)
          from #asignaciones_consulta a
         where a.id_funprse = cla.id_funprse
           and a.nro_cuota = cla.nro_cuota
           and a.es_marcada = 1) as cod_asign_marcada,
       (select min(a.cod_asign)
          from #asignaciones_consulta a
         where a.id_funprse = cla.id_funprse
           and a.nro_cuota = cla.nro_cuota) as cod_asign,
       (select sum(a.valor)
          from #asignaciones_consulta a
         where a.id_funprse = cla.id_funprse
           and a.nro_cuota = cla.nro_cuota) as valor_sisper,
       (select count(*)
          from sisper_db..ss_ccas ccas
         where ccas.cod_ficha = cla.cod_ficha
           and exists (select 1
                         from #asignaciones_consulta a
                        where a.id_funprse = cla.id_funprse
                          and a.nro_cuota = cla.nro_cuota
                          and a.cod_asign = ccas.cod_asign)) as cant_centros_costo,
       (select sum(a.valor)
          from #asignaciones_consulta a
         where a.id_funprse = cla.id_funprse
           and a.nro_cuota = cla.nro_cuota
           and a.es_marcada = 1) as valor_marcado,
       (select count(*)
          from #asignaciones_consulta a
         where a.id_funprse = cla.id_funprse
           and a.nro_cuota = cla.nro_cuota
           and a.es_marcada = 1
           and ltrim(rtrim(a.num_cuenta)) = '2417') as cant_haber_correcto,
       (select min(a.vigencia)
          from #asignaciones_consulta a
         where a.id_funprse = cla.id_funprse
           and a.nro_cuota = cla.nro_cuota
           and a.es_marcada = 1) as vigencia_marcada,
       (select count(*)
          from sisper_db..ss_ccas cc
          inner join #asignaciones_consulta a
                  on a.cod_ficha = cc.cod_ficha
                 and a.cod_asign = cc.cod_asign
         where a.id_funprse = cla.id_funprse
           and a.nro_cuota = cla.nro_cuota
           and a.es_marcada = 1) as cant_cc_marcados,
       (select count(*)
          from sisper_db..ss_ccas cc
          inner join #asignaciones_consulta a
                  on a.cod_ficha = cc.cod_ficha
                 and a.cod_asign = cc.cod_asign
         where a.id_funprse = cla.id_funprse
           and a.nro_cuota = cla.nro_cuota
           and a.es_marcada = 1
           and cla.cant_subitem = 1
           and cc.cod_unifin = cla.cod_unifin
           and cc.cod_ccto = cla.cod_ccto
           and ltrim(rtrim(cc.cod_item)) = ltrim(rtrim(cla.cod_sitm_vigente))
           and cc.valor_asig = cla.neto
           and convert(char(8), cc.f_inicio, 112) = cla.fec_inicio
           and convert(char(8), cc.f_termino, 112) = cla.fec_termino) as cant_cc_correctos
  from #claves_consulta cla
 order by cla.id_funprse, cla.nro_cuota
go

grant execute on Analisis2.sg_epagsSecgen06 to UsuaVrac
go
