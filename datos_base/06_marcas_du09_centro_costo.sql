/*
===============================================================================
VERIFICACION - marcas DU09 de los centros de costo
Motor : Sybase ASE 12.5

No modifica nada. Sirve para ver que centros de costo con prestaciones DU288
tienen sin cargar las marcas que el flujo de pago valida.

  afec_du9    pertenencia al flujo DU09   -> bloquea el pago si no es 'S'
  con_topdu9  afecto al tope de cuotas    -> informativo; 'N' es ANID
  vigente     centro de costo abierto     -> OJO: dominio '1'/'0', no 'S'/'N'

El dominio de es_ccto.vigente es '1'/'0'. El 'S'/'N' pertenece a es_ecct, que
es la relacion responsable-centro de costo. Son tablas distintas.
===============================================================================
*/

use secgen_db
go

set nocount on
go

/* -------------------------------------------------------------------------
   1. Centros de costo con prestaciones DU288 archivadas y sus marcas
   ------------------------------------------------------------------------- */

select distinct
    prse.cod_unifin,
    prse.cod_ccto,
    rtrim(isnull(ccto.nom_ab_cct, '')) as centro_de_costo,
    ccto.vigente                        as vigente_1_abierto,
    isnull(ccto.afec_du9,   'sin dato') as afec_du9,
    isnull(ccto.con_topdu9, 'sin dato') as con_topdu9
  from secgen_db.dbo.sg_prse prse,
       secgen_db.dbo.sg_soli soli,
       fin21_db..es_ccto ccto
 where soli.nro_solici = prse.nro_solici
   and ccto.cod_ccto   = prse.cod_ccto
   and ccto.cod_unifin = prse.cod_unifin
   and isnull(prse.cod_modprs, 1) = 2
   and soli.cod_estsol = 11
 order by prse.cod_unifin, prse.cod_ccto
go

/* -------------------------------------------------------------------------
   2. Los que quedarian bloqueados para pagar
   ------------------------------------------------------------------------- */

select
    count(*) as centros_que_no_podran_pagar
  from (select distinct prse.cod_unifin, prse.cod_ccto
          from secgen_db.dbo.sg_prse prse,
               secgen_db.dbo.sg_soli soli,
               fin21_db..es_ccto ccto
         where soli.nro_solici = prse.nro_solici
           and ccto.cod_ccto   = prse.cod_ccto
           and ccto.cod_unifin = prse.cod_unifin
           and isnull(prse.cod_modprs, 1) = 2
           and soli.cod_estsol = 11
           and (isnull(ccto.afec_du9, 'N') <> 'S'
                or isnull(ccto.vigente, '0') <> '1')) bloqueados
go

/* -------------------------------------------------------------------------
   3. Carga de la marca - NO ejecutar sin revisar el paso 1

   Un centro de costo que ya tiene una resolucion DU288 archivada pertenece al
   flujo por definicion: la resolucion no se habria podido decretar sobre el si
   no fuera asi. Aun asi, la marca se carga una por una y a conciencia, no en
   bloque: 'S' aqui habilita pagar con ese presupuesto.

update fin21_db..es_ccto
   set afec_du9 = 'S'
 where cod_unifin = @cod_unifin
   and cod_ccto   = @cod_ccto

   ------------------------------------------------------------------------- */
