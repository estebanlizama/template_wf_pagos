use secgen_db
go

if exists (select 1
             from sysobjects a, sysusers b
            where a.uid = b.uid
              and a.type = 'P'
              and b.name = 'Analisis2'
              and a.name = 'sg_fupssSecgen18')
begin
    drop procedure Analisis2.sg_fupssSecgen18
end
go

/* Procedimiento : sg_fupssSecgen18

   Entrada :
   @rut_person          -> RUT del responsable vigente del centro de costo. (Opcional)
   @ano                 -> Ano de ejecucion. Usa el actual si no se envia. (Opcional)
   @mes                 -> Mes de corte, trae las cuotas hasta @ano/@mes inclusive. (Opcional)

   Objetivo : Prestaciones DU288 con resolucion archivada de los centros de
   costo que la persona tiene a cargo, con el avance de pago de sus cuotas

   Creacion: ELA 2026/09/22
   Actualizacion: Sin registro
*/

create procedure Analisis2.sg_fupssSecgen18
    @rut_person char(9)  = NULL,
    @ano        smallint = NULL,
    @mes        tinyint  = NULL
as
if @rut_person is null or ltrim(rtrim(@rut_person)) = ''
begin
    select 'Falta el rut del jefe de proyecto. Se aborta el procedimiento' msg return
end

select @rut_person = right('000000000' + ltrim(rtrim(@rut_person)), 9)

declare @mes_actual int

if @ano is null
    select @ano = datepart(yy, getdate())

select @mes_actual = datepart(yy, getdate()) * 100 + datepart(mm, getdate())

SELECT
    fu.id_funprse,
    fu.nro_solici,
    fu.rut,
    case when len(isnull(pers.nom_dest, '')) <= 1 then pers.nom_nombre else pers.nom_dest end AS nom_nombre,
    pers.nom_appate,
    pers.nom_apmate,
    prse.actividad,
    prse.cod_unifin,
    prse.cod_ccto,
    rtrim(isnull(ccto.nom_ab_cct, '')) AS nom_ab_cct,
    prse.cc_global,
    prse.pry_global,
    prse.rut_jefpro,
    fu.f_inicio,
    fu.f_termino,
    fu.mto_total,
    fu.mto_tope,
    fu.tot_cuotas,
    fu.cod_tpps,
    soli.nro_resolu,
    soli.ano_resolu,
    rslc.num_resolu AS num_resolu_ext,
    soli.f_solicit,
    count(fume.nro_cuota)                                       AS cant_cuotas,
    sum(case when fume.cod_estcuo = 1        then 1 else 0 end) AS cant_cuotas_pend,
    sum(case when fume.cod_estcuo in (6,7,8) then 1 else 0 end) AS cant_cuotas_gest,
    sum(case when fume.cod_estcuo = 9        then 1 else 0 end) AS cant_cuotas_paga,
    sum(case when fume.cod_estcuo = 10       then 1 else 0 end) AS cant_cuotas_rech,
    sum(case when fume.cod_estcuo = 1
              and ((fume.ano_prop * 100 + fume.mes_prop) < @mes_actual
                   or fu.f_termino < getdate())
             then 1 else 0 end)                                 AS cant_cuotas_disp,
    isnull(sum(case when fume.cod_estcuo = 9        then fume.mto_apagar end), 0) AS mto_pagado,
    isnull(sum(case when fume.cod_estcuo in (6,7,8) then fume.mto_apagar end), 0) AS mto_gestion,
    fu.mto_total
      - isnull(sum(case when fume.cod_estcuo = 9        then fume.mto_apagar end), 0)
      - isnull(sum(case when fume.cod_estcuo in (6,7,8) then fume.mto_apagar end), 0) AS mto_saldo,
    max(fume.fec_valida)                                        AS fec_ultgest,
    min(case when fume.cod_estcuo = 1 then fume.ano_prop * 100 + fume.mes_prop end) AS per_pendiente_min,
    case
        when count(fume.nro_cuota) = 0 then 0
        when sum(case when fume.cod_estcuo = 9  then 1 else 0 end) = count(fume.nro_cuota) then 4
        when sum(case when fume.cod_estcuo = 10 then 1 else 0 end) > 0 then 5
        when sum(case when fume.cod_estcuo = 9  then 1 else 0 end) > 0 then 3
        when sum(case when fume.cod_estcuo in (6,7,8) then 1 else 0 end) > 0 then 2
        else 1
    end                                                         AS cod_estpag
FROM
    secgen_db.dbo.sg_fups fu
INNER JOIN
    secgen_db.dbo.sg_prse prse
    ON prse.nro_solici = fu.nro_solici
INNER JOIN
    secgen_db.dbo.sg_soli soli
    ON soli.nro_solici = fu.nro_solici
LEFT JOIN
    sisper_db..sp_pers pers
    ON pers.rut_person = fu.rut
LEFT JOIN
    fin21_db..es_ccto ccto
    ON ccto.cod_ccto = prse.cod_ccto
    AND ccto.cod_unifin = prse.cod_unifin
LEFT JOIN
    secgen_db.dbo.sg_rslc rslc
    ON rslc.nro_resolu = soli.nro_resolu
LEFT JOIN
    secgen_db.dbo.sg_fume fume
    ON fume.id_funprse = fu.id_funprse
WHERE
    exists (select 1
              from fin21_db..es_ecct ecct
             where ecct.cod_ccto   = prse.cod_ccto
               and ecct.cod_unifin = prse.cod_unifin
               and ecct.vigente    = 'S'
               and ecct.rut        = @rut_person)
AND
    isnull(prse.cod_modprs, 1) = 2
AND
    soli.cod_estsol = 11
AND
    soli.nro_resolu is not null
AND
    datepart(yy, fu.f_inicio) in (@ano, @ano - 1)
GROUP BY
    fu.id_funprse, fu.nro_solici, fu.rut,
    pers.nom_dest, pers.nom_nombre, pers.nom_appate, pers.nom_apmate,
    prse.actividad, prse.cod_unifin, prse.cod_ccto, ccto.nom_ab_cct,
    prse.cc_global, prse.pry_global, prse.rut_jefpro,
    fu.f_inicio, fu.f_termino,
    fu.mto_total, fu.mto_tope, fu.tot_cuotas, fu.cod_tpps,
    soli.nro_resolu, soli.ano_resolu, rslc.num_resolu, soli.f_solicit
HAVING
    @mes is null
    or sum(case when (fume.ano_prop * 100 + fume.mes_prop) <= (@ano * 100 + @mes) then 1 else 0 end) > 0
ORDER BY
    soli.f_solicit DESC, fu.id_funprse
go

grant execute on Analisis2.sg_fupssSecgen18 to UsuaVrac
go
