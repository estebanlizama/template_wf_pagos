use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
            where a.uid = b.uid
              and a.type = 'P'
              and b.name = 'Analisis2'
              and a.name = 'sg_fupssSecgen19')
    drop procedure Analisis2.sg_fupssSecgen19
go

/* Procedimiento : sg_fupssSecgen19

   Entrada :
   @rut_person           -> RUT del funcionario. (Obligatorio)

   Objetivo : Listar los rechazos y devoluciones de las prestaciones de un funcionario, de la
   solicitud, de sus meses y de sus cuotas, solo para informar.

   Creacion: ELA 2026/11/04
   Actualizacion: Sin registro
*/
create procedure Analisis2.sg_fupssSecgen19
    @rut_person char(9) = null
as

if @rut_person is null or ltrim(rtrim(@rut_person)) = ''
begin
    select 'Falta campo RUT del funcionario' as msg
    return
end

select 'SOL' as tipo,
       fu.nro_solici,
       fu.id_funprse,
       prse.cod_unifin,
       prse.cod_ccto,
       rtrim(isnull(ccto.nom_ab_cct, '')) as nom_ab_cct,
       prse.per_desde,
       prse.per_hasta,
       soli.cod_estsol,
       rtrim(isnull(esol.des_estsol, '')) as des_estsol,
       convert(smallint, null) as ano_mes,
       convert(tinyint, null) as mes_mes,
       convert(tinyint, null) as nro_cuota,
       convert(tinyint, null) as cod_estcuo,
       convert(numeric(14, 0), null) as mto_cuota,
       hist.id_tipacc,
       rtrim(isnull(tacc.des_accion, '')) as des_accion,
       hist.f_creacion as f_evento,
       convert(varchar(1000), hist.observaci) as observaci,
       convert(char(1), null) as val_licmed,
       convert(char(1), null) as val_inabili,
       convert(char(1), null) as val_singoce,
       convert(char(1), null) as val_ciecc
from secgen_db.dbo.sg_fups fu
inner join secgen_db.dbo.sg_prse prse on prse.nro_solici = fu.nro_solici
inner join secgen_db.dbo.sg_soli soli on soli.nro_solici = fu.nro_solici
inner join secgen_db.dbo.sg_hist hist on hist.nro_solici = fu.nro_solici
left join secgen_db.dbo.sg_esol esol on esol.cod_estsol = soli.cod_estsol
left join secgen_db.dbo.sg_tacc tacc on tacc.id_tipacc = hist.id_tipacc
left join fin21_db..es_ccto ccto
    on ccto.cod_ccto = prse.cod_ccto
   and ccto.cod_unifin = prse.cod_unifin
where fu.rut = @rut_person
  and hist.id_tipacc in (3, 4, 8, 9)

union all

select 'SOL' as tipo,
       fu.nro_solici,
       fu.id_funprse,
       prse.cod_unifin,
       prse.cod_ccto,
       rtrim(isnull(ccto.nom_ab_cct, '')) as nom_ab_cct,
       prse.per_desde,
       prse.per_hasta,
       soli.cod_estsol,
       rtrim(isnull(esol.des_estsol, '')) as des_estsol,
       convert(smallint, null) as ano_mes,
       convert(tinyint, null) as mes_mes,
       convert(tinyint, null) as nro_cuota,
       convert(tinyint, null) as cod_estcuo,
       convert(numeric(14, 0), null) as mto_cuota,
       convert(int, null) as id_tipacc,
       '' as des_accion,
       soli.f_solicit as f_evento,
       convert(varchar(1000), null) as observaci,
       convert(char(1), null) as val_licmed,
       convert(char(1), null) as val_inabili,
       convert(char(1), null) as val_singoce,
       convert(char(1), null) as val_ciecc
from secgen_db.dbo.sg_fups fu
inner join secgen_db.dbo.sg_prse prse on prse.nro_solici = fu.nro_solici
inner join secgen_db.dbo.sg_soli soli on soli.nro_solici = fu.nro_solici
left join secgen_db.dbo.sg_esol esol on esol.cod_estsol = soli.cod_estsol
left join fin21_db..es_ccto ccto
    on ccto.cod_ccto = prse.cod_ccto
   and ccto.cod_unifin = prse.cod_unifin
where fu.rut = @rut_person
  and soli.cod_estsol = 4
  and not exists (select 1
                    from secgen_db.dbo.sg_hist hrec
                   where hrec.nro_solici = fu.nro_solici
                     and hrec.id_tipacc in (3, 8))

union all

select 'MES' as tipo,
       fu.nro_solici,
       fu.id_funprse,
       prse.cod_unifin,
       prse.cod_ccto,
       rtrim(isnull(ccto.nom_ab_cct, '')) as nom_ab_cct,
       prse.per_desde,
       prse.per_hasta,
       soli.cod_estsol,
       rtrim(isnull(esol.des_estsol, '')) as des_estsol,
       convert(smallint, isnull(fume.ano_ejec, fume.ano_prop)) as ano_mes,
       convert(tinyint, isnull(fume.mes_ejec, fume.mes_prop)) as mes_mes,
       convert(tinyint, null) as nro_cuota,
       convert(tinyint, null) as cod_estcuo,
       convert(numeric(14, 0), fume.mto_apagar) as mto_cuota,
       convert(int, null) as id_tipacc,
       rtrim(isnull(efum.des_estfum, '')) as des_accion,
       fume.fec_valida as f_evento,
       convert(varchar(1000), null) as observaci,
       fume.val_licmed,
       fume.val_inabili,
       fume.val_singoce,
       fume.val_ciecc
from secgen_db.dbo.sg_fups fu
inner join secgen_db.dbo.sg_prse prse on prse.nro_solici = fu.nro_solici
inner join secgen_db.dbo.sg_soli soli on soli.nro_solici = fu.nro_solici
inner join secgen_db.dbo.sg_fume fume on fume.id_funprse = fu.id_funprse
left join secgen_db.dbo.sg_efum efum on efum.cod_estfum = fume.cod_estfum
left join secgen_db.dbo.sg_esol esol on esol.cod_estsol = soli.cod_estsol
left join fin21_db..es_ccto ccto
    on ccto.cod_ccto = prse.cod_ccto
   and ccto.cod_unifin = prse.cod_unifin
where fu.rut = @rut_person
  and fume.cod_estfum = 4

union all

select 'CUO' as tipo,
       fu.nro_solici,
       fu.id_funprse,
       prse.cod_unifin,
       prse.cod_ccto,
       rtrim(isnull(ccto.nom_ab_cct, '')) as nom_ab_cct,
       prse.per_desde,
       prse.per_hasta,
       soli.cod_estsol,
       rtrim(isnull(esol.des_estsol, '')) as des_estsol,
       convert(smallint, epag.ano_pago) as ano_mes,
       convert(tinyint, epag.mes_pago) as mes_mes,
       epag.nro_cuota,
       epag.cod_estcuo,
       convert(numeric(14, 0), (select sum(isnull(fmto.mto_apagar, 0))
                                  from secgen_db.dbo.sg_dpag dmto
                                 inner join secgen_db.dbo.sg_fume fmto
                                    on fmto.id_funprse = dmto.id_funprse
                                   and fmto.corr_fume = dmto.corr_fume
                                 where dmto.id_funprse = epag.id_funprse
                                   and dmto.nro_cuota = epag.nro_cuota)) as mto_cuota,
       com.id_tipacc,
       rtrim(isnull(tacc.des_accion, '')) as des_accion,
       com.f_observa as f_evento,
       convert(varchar(1000), com.observaci) as observaci,
       convert(char(1), null) as val_licmed,
       convert(char(1), null) as val_inabili,
       convert(char(1), null) as val_singoce,
       convert(char(1), null) as val_ciecc
from secgen_db.dbo.sg_fups fu
inner join secgen_db.dbo.sg_prse prse on prse.nro_solici = fu.nro_solici
inner join secgen_db.dbo.sg_soli soli on soli.nro_solici = fu.nro_solici
inner join secgen_db.dbo.sg_epag epag on epag.id_funprse = fu.id_funprse
inner join secgen_db.dbo.sg_com1 com
    on com.id_funprse = epag.id_funprse
   and com.nro_cuota = epag.nro_cuota
left join secgen_db.dbo.sg_tacc tacc on tacc.id_tipacc = com.id_tipacc
left join secgen_db.dbo.sg_esol esol on esol.cod_estsol = soli.cod_estsol
left join fin21_db..es_ccto ccto
    on ccto.cod_ccto = prse.cod_ccto
   and ccto.cod_unifin = prse.cod_unifin
where fu.rut = @rut_person
  and com.id_tipacc in (32, 33)

order by f_evento desc
go

grant execute on Analisis2.sg_fupssSecgen19 to UsuaVrac
go
