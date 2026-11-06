/* Acciones de devolucion, rechazo y reapertura de una cuota por DGDP. */
use secgen_db
go

set nocount on
go

create table #acciones_pago (codigo tinyint not null, descripcion varchar(80) not null)
insert into #acciones_pago values (32, 'DGDP devolvio a correccion la cuota de pago')
insert into #acciones_pago values (33, 'DGDP rechazo la cuota de pago')
insert into #acciones_pago values (34, 'DGDP devolvio una cuota aprobada a visacion')
go

if exists (
    select 1
      from dbo.sg_tacc a, #acciones_pago n
     where a.id_tipacc = n.codigo
       and (a.des_accion is null or a.des_accion <> n.descripcion)
)
begin
    raiserror 20000 'Un codigo de accion de pagos ya tiene otro significado.'
    return
end

begin tran

insert into dbo.sg_tacc (id_tipacc, des_accion)
select n.codigo, n.descripcion
  from #acciones_pago n
 where not exists (select 1 from dbo.sg_tacc a where a.id_tipacc = n.codigo)
if @@error <> 0 goto error_carga

commit tran
select 'Acciones de pagos verificadas.' as msg
return

error_carga:
if @@trancount > 0 rollback tran
raiserror 20000 'No fue posible completar la carga de datos base.'
go

drop table #acciones_pago
go

select id_tipacc, des_accion from dbo.sg_tacc where id_tipacc in (32, 33, 34)
 order by id_tipacc
go
