/* Perfil 33 y privilegios de pagos SG/SISSOLIC. Reutiliza el perfil 6.
   No asigna perfiles a personas; la pertenencia se resuelve por vigencia. */
use sistema_db
go

set nocount on
go

create table #privilegios_pago (codigo smallint not null, nombre varchar(100) not null)
create table #perfil_privilegio_pago (perfil smallint not null, privilegio smallint not null)

insert into #privilegios_pago values (92, 'provision-payment-create')
insert into #privilegios_pago values (93, 'provision-payment-read')
insert into #privilegios_pago values (94, 'provision-payment-read-waiting')
insert into #privilegios_pago values (95, 'provision-payment-approve')
insert into #privilegios_pago values (96, 'provision-payment-adjust')
insert into #privilegios_pago values (97, 'provision-payment-submit')
insert into #privilegios_pago values (98, 'provision-payment-history-read')
insert into #privilegios_pago values (99, 'provision-payment-document-read')

insert into #perfil_privilegio_pago values (6, 92)
insert into #perfil_privilegio_pago values (6, 93)
insert into #perfil_privilegio_pago values (6, 98)
insert into #perfil_privilegio_pago values (6, 99)
insert into #perfil_privilegio_pago values (33, 92)
insert into #perfil_privilegio_pago values (33, 93)
insert into #perfil_privilegio_pago values (33, 94)
insert into #perfil_privilegio_pago values (33, 95)
insert into #perfil_privilegio_pago values (33, 96)
insert into #perfil_privilegio_pago values (33, 97)
insert into #perfil_privilegio_pago values (33, 98)
insert into #perfil_privilegio_pago values (33, 99)
go

if not exists (select 1 from dbo.bd_per1
                where cod_sistem = 'SG' and cod_modulo = 'SISSOLIC' and cod_perfil = 6)
   or exists (
        select 1 from dbo.bd_per1
         where cod_sistem = 'SG' and cod_modulo = 'SISSOLIC'
           and ((cod_perfil = 33 and (des_perfil is null or des_perfil <> 'payment_validator'))
                or (des_perfil = 'payment_validator' and cod_perfil <> 33))
   )
   or exists (
        select 1 from dbo.bd_prvg p, #privilegios_pago n
         where p.cod_sistem = 'SG' and p.cod_modulo = 'SISSOLIC'
           and ((p.cod_privil = n.codigo and (p.nom_privil is null or p.nom_privil <> n.nombre))
                or (p.nom_privil = n.nombre and p.cod_privil <> n.codigo))
   )
begin
    raiserror 20000 'Falta el perfil solicitante o hay codigos de pagos ocupados.'
    return
end

begin tran

if not exists (select 1 from dbo.bd_per1
                where cod_sistem = 'SG' and cod_modulo = 'SISSOLIC' and cod_perfil = 33)
begin
    insert into dbo.bd_per1 (cod_sistem, cod_modulo, cod_perfil, des_perfil, des_perext)
    values ('SG', 'SISSOLIC', 33, 'payment_validator', 'Validador de pagos DGDP')
    if @@error <> 0 goto error_carga
end

insert into dbo.bd_prvg (cod_sistem, cod_modulo, cod_privil, des_privil, nom_privil)
select 'SG', 'SISSOLIC', n.codigo, n.nombre, n.nombre
  from #privilegios_pago n
 where not exists (select 1 from dbo.bd_prvg p
                    where p.cod_sistem = 'SG' and p.cod_modulo = 'SISSOLIC'
                      and p.cod_privil = n.codigo)
if @@error <> 0 goto error_carga

insert into dbo.bd_pepr (cod_sistem, cod_modulo, cod_perfil, cod_privil)
select 'SG', 'SISSOLIC', m.perfil, m.privilegio
  from #perfil_privilegio_pago m
 where not exists (select 1 from dbo.bd_pepr p
                    where p.cod_sistem = 'SG' and p.cod_modulo = 'SISSOLIC'
                      and p.cod_perfil = m.perfil and p.cod_privil = m.privilegio)
if @@error <> 0 goto error_carga

commit tran
select 'Perfiles y privilegios de pagos verificados.' as msg
return

error_carga:
if @@trancount > 0 rollback tran
raiserror 20000 'No fue posible completar la carga de datos base.'
go

drop table #perfil_privilegio_pago
drop table #privilegios_pago
go

select p.cod_perfil, p.cod_privil, v.nom_privil
  from dbo.bd_pepr p, dbo.bd_prvg v
 where p.cod_sistem = 'SG' and p.cod_modulo = 'SISSOLIC'
   and v.cod_sistem = p.cod_sistem and v.cod_modulo = p.cod_modulo
   and v.cod_privil = p.cod_privil
   and p.cod_perfil in (6, 33) and p.cod_privil between 92 and 99
 order by p.cod_perfil, p.cod_privil
go
