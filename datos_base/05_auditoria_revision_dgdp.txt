/* Propuesta opcional. No aplicar contra el esquema vigente del diagrama sin
   aprobar previamente la extension de auditoria DGDP. */
use secgen_db
go

/* Auditoria de la ultima resolucion DGDP por cuota. */
if not exists (select 1 from syscolumns where id = object_id('dbo.sg_epag') and name = 'observacion')
    alter table dbo.sg_epag add observacion varchar(255) null
go
if not exists (select 1 from syscolumns where id = object_id('dbo.sg_epag') and name = 'rut_visa')
    alter table dbo.sg_epag add rut_visa char(9) null
go
if not exists (select 1 from syscolumns where id = object_id('dbo.sg_epag') and name = 'fec_visa')
    alter table dbo.sg_epag add fec_visa datetime null
go
