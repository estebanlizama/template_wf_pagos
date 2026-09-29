use secgen_db
go

if exists (select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = 'P'
                and b.name = 'Analisis2'
                and a.name = 'sg_fupssSecgen02')
   drop procedure Analisis2.sg_fupssSecgen02

go

/* Procedimiento : sg_fupssSecgen02

   Entrada :
   @nro_solici          -> Numero de solicitud. (Opcional)

   Objetivo : Listar los funcionarios asociados a una solicitud, incluyendo la
              informacion requerida por DU288 y el flujo legado.

   Creacion: ELA 2026/08/24
   Actualizacion: ELA 2026/09/28
*/
create procedure Analisis2.sg_fupssSecgen02
    @nro_solici int = null
as
begin
    if @nro_solici is null
    begin
        select 'Falta campo Id Funcionarios prestacion de servicios' as msg
        return
    end

    select
        fu.id_funprse,
        fu.nro_solici,
        fu.rut,
        fu.cod_cargo,
        fu.cod_sitm,
        fu.itm_global,
        fu.motivo,
        fu.periodos,
        fu.monto_mes,
        fu.mto_total,
        fu.cod_moneda,
        fu.cod_tpps,
        fu.f_inicio,
        fu.f_termino,
        fu.cod_estfun,
        isnull(rtrim(efun.des_estfun), '') as des_estfun,
        fu.dentro_jor,
        fu.cod_contra,
        fu.mes_haber,
        fu.ano_haber,
        fu.mto_haber,
        fu.mto_tope,
        fu.f_cal_tope,
        fu.tot_cuotas,
        fu.ext_cuotas,
        
        (pers.nom_nombre + ' ' + pers.nom_appate + ' ' + pers.nom_apmate) as nombre,
        pers.uni_ctadi,
        
        isnull(cont.principal, '0') as principal,
        cont.cod_unidad,
        rtrim(unid.des_unidad) as des_unidad,
        cont.cod_cargo as cod_cargo_contrato,
        rtrim(carg.nom_cargo) as nom_cargo,
        cont.cod_estame,
        rtrim(estm.des_estame) as des_estame,
        cont.cod_calida,
        rtrim(cali.des_calida) as des_calida,
        cont.cod_jerpla,
        rtrim(jpfu.des_jerpla) as des_jerpla,
        cont.cod_niv_gr,
        rtrim(nigr.des_niv_gr) as des_niv_gr,
        cont.cod_jornad,
        rtrim(jorn.des_jornad) as des_jornad,
        isnull(cont.num_horas, 0) as num_horas,
        cont.f_inicio_d,
        cont.f_termin_d,
        cont.vigen_cont,
        rtrim(vigc.des_vigen) as des_vigen
    from
        sg_fups fu
        left join secgen_db.dbo.sg_efun efun
            on (efun.cod_estfun = fu.cod_estfun)
        left join sisper_db..sp_pers pers
            on (pers.rut_person = fu.rut)
        left join sisper_db.dbo.sp_cont cont
            on (cont.cod_contra = fu.cod_contra)
        left join sisper_db.dbo.sp_carg carg
            on (carg.cod_cargo = cont.cod_cargo)
        left join sisper_db.dbo.sp_cali cali
            on (cali.cod_calida = cont.cod_calida)
        left join ufro_db.dbo.es_unid unid
            on (unid.cod_unidad = cont.cod_unidad)
        left join sisper_db.dbo.sp_jpfu jpfu
            on (jpfu.cod_jerpla = cont.cod_jerpla)
        left join sisper_db.dbo.sp_nigr nigr
            on (nigr.cod_jerpla = cont.cod_jerpla
           and nigr.cod_niv_gr = cont.cod_niv_gr)
        left join sisper_db.dbo.sp_jorn jorn
            on (jorn.cod_jornad = cont.cod_jornad)
        left join sisper_db.dbo.sp_estm estm
            on (estm.cod_estame = cont.cod_estame)
        left join sisper_db.dbo.sp_vigc vigc
            on (vigc.vigen_cont = cont.vigen_cont)
    where
        fu.nro_solici = @nro_solici
end
go

grant execute on Analisis2.sg_fupssSecgen02 to UsuaVrac
go
