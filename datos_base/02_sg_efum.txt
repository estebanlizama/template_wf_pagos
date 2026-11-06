/* Estados del mes de ejecucion. No modifica los estados de las cuotas. */
use secgen_db
go

set nocount on
go

create table #estados (
    codigo tinyint not null,
    descripcion varchar(60) not null
)
insert into #estados values (1, 'Propuesta')
insert into #estados values (2, 'Comprometida')
insert into #estados values (3, 'Enviada a pago')
insert into #estados values (4, 'Rechazada')
go

begin tran

update dbo.sg_efum
   set des_estfum = x.descripcion
  from dbo.sg_efum e, #estados x
 where e.cod_estfum = x.codigo
   and (e.des_estfum is null or e.des_estfum <> x.descripcion)
if @@error <> 0 goto error_carga

insert into dbo.sg_efum (cod_estfum, des_estfum)
select x.codigo, x.descripcion
  from #estados x
 where not exists (select 1 from dbo.sg_efum e where e.cod_estfum = x.codigo)
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
select cod_estfum, des_estfum from dbo.sg_efum order by cod_estfum
go
