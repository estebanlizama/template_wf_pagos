/*
===============================================================================
sg_tacc - ACCIONES DE HISTORIAL PARA EL WORKFLOW DE PAGOS DU288
Motor : Sybase ASE 12.5
Tabla que lo usa: secgen_db..sg_hist.id_tipacc

Alcance:
  - id_tipacc = 32 : 'DGDP devolvio a correccion la cuota de pago'
  - id_tipacc = 33 : 'DGDP rechazo la cuota de pago'

Nota:
  El código 31 ya se encuentra ocupado en la base de datos por:
  'Agrupo la solicitud'. Por tanto, se toman los siguientes libres: 32 y 33.

Objetivo:
  Permite registrar la trazabilidad de devoluciones y rechazos de cuotas
  de pago emitidas por el revisor DGDP en la tabla secgen_db..sg_hist,
  sin alterar ninguna de las acciones preexistentes (1 a 31).
===============================================================================
*/

USE secgen_db
GO

SET NOCOUNT ON
GO

/* -------------------------------------------------------------------------
   1. REGISTRO DE NUEVAS ACCIONES EN secgen_db..sg_tacc
   ------------------------------------------------------------------------- */

INSERT INTO secgen_db.dbo.sg_tacc (id_tipacc, des_accion)
VALUES (32, 'DGDP devolvio a correccion la cuota de pago')
GO

INSERT INTO secgen_db.dbo.sg_tacc (id_tipacc, des_accion)
VALUES (33, 'DGDP rechazo la cuota de pago')
GO

/* -------------------------------------------------------------------------
   2. VERIFICACION
   ------------------------------------------------------------------------- */
SELECT id_tipacc, des_accion
  FROM secgen_db.dbo.sg_tacc
 WHERE id_tipacc IN (32, 33)
GO
