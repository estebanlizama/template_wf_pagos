/* Estados vigentes de la cuota. Conserva los codigos anteriores para su revision. */
use secgen_db
go

set nocount on
go

create table #estados (
    codigo tinyint not null,
    descripcion varchar(60) not null
)
insert into #estados values (1, 'Borrador')
insert into #estados values (2, 'En revisión DGDP')
insert into #estados values (3, 'Devuelta para corrección')
insert into #estados values (4, 'Aprobada por DGDP')
insert into #estados values (8, 'Enviada a remuneraciones')
insert into #estados values (10, 'Rechazada por DGDP')
insert into #estados values (11, 'Devuelta de Finanzas')
go

begin tran

update dbo.sg_ecuo
   set des_estcuo = x.descripcion
  from dbo.sg_ecuo e, #estados x
 where e.cod_estcuo = x.codigo
   and (e.des_estcuo is null or e.des_estcuo <> x.descripcion)
if @@error <> 0 goto error_carga

insert into dbo.sg_ecuo (cod_estcuo, des_estcuo)
select x.codigo, x.descripcion
  from #estados x
 where not exists (select 1 from dbo.sg_ecuo e where e.cod_estcuo = x.codigo)
if @@error <> 0 goto error_carga

commit tran
select 'Catalogo actualizado correctamente.' as msg
return

error_carga:
if @@trancount > 0 rollback tran
raiserror 20000 'No fue posible completar la carga de datos base.'
go

drop table #estados
go
select cod_estcuo, des_estcuo from dbo.sg_ecuo order by cod_estcuo
go
