/*
===============================================================================
WF PAGOS DU288/DU09 - ROL Y PRIVILEGIOS
Motor  : Sybase ASE 12.5
Modulo : SG / SISSOLIC

Alcance:
  - el perfil de validador de pagos;
  - los privilegios del flujo de pago;
  - la matriz perfil/privilegio.

NO crea usuarios ni inscribe a nadie en bd_pri2. La pertenencia al rol se
resuelve de forma DINAMICA:

    Solicitante  -> perfil 6, otorgado por CONTRATO vigente (fuente existente
                    de sg_usacsSecgen01). Que sea el jefe de proyecto de ESA
                    prestacion se valida aparte, contra sg_prse.rut_jefpro.

    Validador    -> perfil nuevo, otorgado por DESIGNACION vigente en
                    sp_orde / sp_desg. Requiere la fuente nueva en
                    sg_usacsSecgen01 (ver seccion 5).

Sigue el patron de certificacion_03_09_2026/cargar_datos_base/
01_roles_permisos_du288.sql. Los IDs se conservan sin recalcular.

REQUISITO: confirmar contra el ambiente que los codigos elegidos esten libres
(ver seccion 0).
===============================================================================
*/

USE sistema_db
GO

SET NOCOUNT ON
GO

/* -------------------------------------------------------------------------
   0. VERIFICAR CODIGOS LIBRES -- correr ANTES del resto
   ------------------------------------------------------------------------- */

SELECT 'perfiles ocupados' AS control, cod_perfil, des_perfil
FROM sistema_db.dbo.bd_per1
WHERE cod_sistem = 'SG' AND cod_modulo = 'SISSOLIC'
  AND cod_perfil BETWEEN 30 AND 40
ORDER BY cod_perfil
GO

SELECT 'privilegios ocupados' AS control, cod_privil, nom_privil
FROM sistema_db.dbo.bd_prvg
WHERE cod_sistem = 'SG' AND cod_modulo = 'SISSOLIC'
  AND cod_privil BETWEEN 88 AND 105
ORDER BY cod_privil
GO

/* -------------------------------------------------------------------------
   1. PERFIL DEL VALIDADOR
   -------------------------------------------------------------------------
   Solo se agrega UNO. El solicitante de pago reutiliza el perfil 6, que ya
   existe y se otorga por contrato vigente.
   ------------------------------------------------------------------------- */

CREATE TABLE #roles_pago (
    cod_perfil smallint     NOT NULL,
    des_perfil varchar(60)  NOT NULL,
    des_perext varchar(100) NOT NULL
)

INSERT INTO #roles_pago VALUES (33, 'payment_validator', 'Validador de pagos DGDP')
GO

UPDATE sistema_db.dbo.bd_per1
SET des_perfil = r.des_perfil,
    des_perext = r.des_perext
FROM sistema_db.dbo.bd_per1 p, #roles_pago r
WHERE p.cod_sistem = 'SG'
  AND p.cod_modulo = 'SISSOLIC'
  AND p.cod_perfil = r.cod_perfil
GO

INSERT INTO sistema_db.dbo.bd_per1
    (cod_sistem, cod_modulo, cod_perfil, des_perfil, des_perext)
SELECT 'SG', 'SISSOLIC', r.cod_perfil, r.des_perfil, r.des_perext
FROM #roles_pago r
WHERE NOT EXISTS (
    SELECT 1 FROM sistema_db.dbo.bd_per1 p
    WHERE p.cod_sistem = 'SG' AND p.cod_modulo = 'SISSOLIC'
      AND p.cod_perfil = r.cod_perfil
)
GO

/* -------------------------------------------------------------------------
   2. PRIVILEGIOS DEL FLUJO DE PAGO
   -------------------------------------------------------------------------
   Derivados de las acciones del diagrama. Cada uno corresponde a un acto con
   consecuencia distinta, para poder separarlos despues sin migrar datos.

     92 create          armar, editar y enviar una cuota de pago
                        (A1..A11 + ENVIAR). Incluye el envio, igual que
                        provision-request-create en resolucion.

     93 read            ver cuotas de pago y su detalle

     94 read-waiting    ver la bandeja de cuotas esperando validacion (B1)

     95 approve         resolver la revision: aprobar, devolver o rechazar (B7)

     96 adjust          ajustar montos, aplicar descuentos y excluir meses
                        (B5, B6). SEPARADO de approve a proposito: cambia lo
                        que se va a pagar, no solo el resultado del tramite.

     97 submit          registrar la peticion de pago en Finanzas (C1..C3).
                        SEPARADO de approve: es el acto terminal que
                        compromete el dinero y no tiene vuelta atras.

     98 history-read    ver la bitacora de la cuota

     99 document-read   ver el respaldo documental de la cuota. Propio, no
                        reutiliza el de resolucion: quien ve un respaldo de
                        pago no necesariamente debe ver la resolucion.
   ------------------------------------------------------------------------- */

CREATE TABLE #privilegios_pago (
    cod_privil smallint     NOT NULL,
    nom_privil varchar(100) NOT NULL
)

INSERT INTO #privilegios_pago VALUES (92, 'provision-payment-create')
INSERT INTO #privilegios_pago VALUES (93, 'provision-payment-read')
INSERT INTO #privilegios_pago VALUES (94, 'provision-payment-read-waiting')
INSERT INTO #privilegios_pago VALUES (95, 'provision-payment-approve')
INSERT INTO #privilegios_pago VALUES (96, 'provision-payment-adjust')
INSERT INTO #privilegios_pago VALUES (97, 'provision-payment-submit')
INSERT INTO #privilegios_pago VALUES (98, 'provision-payment-history-read')
INSERT INTO #privilegios_pago VALUES (99, 'provision-payment-document-read')
GO

UPDATE sistema_db.dbo.bd_prvg
SET des_privil = v.nom_privil,
    nom_privil = v.nom_privil
FROM sistema_db.dbo.bd_prvg p, #privilegios_pago v
WHERE p.cod_sistem = 'SG'
  AND p.cod_modulo = 'SISSOLIC'
  AND p.cod_privil = v.cod_privil
GO

INSERT INTO sistema_db.dbo.bd_prvg
    (cod_sistem, cod_modulo, cod_privil, des_privil, nom_privil)
SELECT 'SG', 'SISSOLIC', v.cod_privil, v.nom_privil, v.nom_privil
FROM #privilegios_pago v
WHERE NOT EXISTS (
    SELECT 1 FROM sistema_db.dbo.bd_prvg p
    WHERE p.cod_sistem = 'SG' AND p.cod_modulo = 'SISSOLIC'
      AND p.cod_privil = v.cod_privil
)
GO

/* -------------------------------------------------------------------------
   3. MATRIZ PERFIL / PRIVILEGIO
   -------------------------------------------------------------------------
   Perfil 6  Solicitante PDS -- arma y envia la cuota, ve la suya
   Perfil 33 Validador DGDP  -- revisa, ajusta, resuelve y registra

   El validador NO tiene 'create': no arma solicitudes de pago.
   El solicitante NO tiene 'read-waiting': la bandeja de revision no es suya.
   ------------------------------------------------------------------------- */

CREATE TABLE #perfil_privilegio_pago (
    cod_perfil smallint NOT NULL,
    cod_privil smallint NOT NULL
)

/* Solicitante de pago -- jefe de proyecto. */
INSERT INTO #perfil_privilegio_pago VALUES (6, 92)   /* create */
INSERT INTO #perfil_privilegio_pago VALUES (6, 93)   /* read */
INSERT INTO #perfil_privilegio_pago VALUES (6, 98)   /* history-read */
INSERT INTO #perfil_privilegio_pago VALUES (6, 99)   /* document-read */

/* Validador de pagos DGDP. */
INSERT INTO #perfil_privilegio_pago VALUES (33, 93)  /* read */
INSERT INTO #perfil_privilegio_pago VALUES (33, 94)  /* read-waiting */
INSERT INTO #perfil_privilegio_pago VALUES (33, 95)  /* approve */
INSERT INTO #perfil_privilegio_pago VALUES (33, 96)  /* adjust */
INSERT INTO #perfil_privilegio_pago VALUES (33, 97)  /* submit */
INSERT INTO #perfil_privilegio_pago VALUES (33, 98)  /* history-read */
INSERT INTO #perfil_privilegio_pago VALUES (33, 99)  /* document-read */
GO

INSERT INTO sistema_db.dbo.bd_pepr
    (cod_sistem, cod_modulo, cod_perfil, cod_privil)
SELECT 'SG', 'SISSOLIC', m.cod_perfil, m.cod_privil
FROM #perfil_privilegio_pago m
WHERE NOT EXISTS (
    SELECT 1 FROM sistema_db.dbo.bd_pepr p
    WHERE p.cod_sistem = 'SG' AND p.cod_modulo = 'SISSOLIC'
      AND p.cod_perfil = m.cod_perfil
      AND p.cod_privil = m.cod_privil
)
GO

DROP TABLE #roles_pago
DROP TABLE #privilegios_pago
DROP TABLE #perfil_privilegio_pago
GO

/* -------------------------------------------------------------------------
   4. LO QUE ESTE SCRIPT NO HACE
   -------------------------------------------------------------------------
   - NO inscribe a nadie en bd_pri2. Ninguna persona queda asignada al perfil
     33 por este script.
   - NO crea flujo ni etapas: el pago no usa el motor de transiciones.
   - NO toca los privilegios de resolucion (65..91).
   ------------------------------------------------------------------------- */

/* -------------------------------------------------------------------------
   5. LO QUE FALTA PARA QUE ALGUIEN TENGA EL PERFIL 33
   -------------------------------------------------------------------------
   El perfil existe pero nadie lo tiene todavia. Hace falta la fuente nueva
   en sg_usacsSecgen01, con el mismo patron que sg_fupssSecgen15 ya usa para
   leer designaciones:

       insert into #perfiles (cod_perfil, origen)
       select distinct 33, 'DESIGNA'
       from sisper_db.dbo.sp_orde orde
       inner join sisper_db.dbo.sp_desg desg
           on desg.cod_design = orde.cod_design
       where orde.rut_person = @rut
         and orde.cod_design = <cod_design del validador>
         and orde.vigente = 'S'
         and desg.vigencia in ('1', 'S')
         and desg.f_inicio <= @fecha_val
         and (desg.f_termino is null or desg.f_termino >= @fecha_val)
         and not exists (select 1 from #perfiles p where p.cod_perfil = 33)

   Antes de escribirla hay que confirmar el cod_design:

       SELECT cod_design, cod_cargo, cod_unidad, vigencia, f_inicio, f_termino,
              observ
       FROM sisper_db.dbo.sp_desg
       WHERE cod_design = 696

       SELECT orde.rut_person, orde.vigente, desg.f_inicio, desg.f_termino
       FROM sisper_db.dbo.sp_orde orde
       INNER JOIN sisper_db.dbo.sp_desg desg ON desg.cod_design = orde.cod_design
       WHERE orde.cod_design = 696 AND orde.vigente = 'S'

   La segunda consulta es la que decide: si la lista de personas con esa
   designacion vigente coincide con quienes deben validar pagos, el camino
   esta cerrado.
   ------------------------------------------------------------------------- */

/* -------------------------------------------------------------------------
   6. CAMBIO EN EL BACKEND
   -------------------------------------------------------------------------
   service-provision-authorization.service.ts:174 tiene el privilegio fijo:

       if (!access.permissions.includes('provision-request-approve'))

   Para que las pantallas de pago validen contra su propio privilegio hay que
   parametrizarlo:

       async assertCanApprove(
           dni: string,
           workflowProfileId?: number,
           privilege = 'provision-request-approve',
       )

   Y los controladores de pago lo llaman con 'provision-payment-approve'.
   Un parametro con default: no cambia ninguna llamada existente.
   ------------------------------------------------------------------------- */

/* -------------------------------------------------------------------------
   7. VERIFICACION
   ------------------------------------------------------------------------- */

SELECT per.cod_perfil, per.des_perfil, pri.cod_privil, pri.nom_privil
FROM sistema_db.dbo.bd_per1 per
INNER JOIN sistema_db.dbo.bd_pepr pep
    ON pep.cod_sistem = per.cod_sistem
   AND pep.cod_modulo = per.cod_modulo
   AND pep.cod_perfil = per.cod_perfil
INNER JOIN sistema_db.dbo.bd_prvg pri
    ON pri.cod_sistem = pep.cod_sistem
   AND pri.cod_modulo = pep.cod_modulo
   AND pri.cod_privil = pep.cod_privil
WHERE per.cod_sistem = 'SG'
  AND per.cod_modulo = 'SISSOLIC'
  AND pri.nom_privil LIKE 'provision-payment-%'
ORDER BY per.cod_perfil, pri.cod_privil
GO
