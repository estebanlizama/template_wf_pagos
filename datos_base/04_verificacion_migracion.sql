/*
===============================================================================
VERIFICACION DE LA MIGRACION sg_fume -> sg_efum
Motor : Sybase ASE 12.5

Solo lectura. Cada bloque devuelve OK o el detalle de lo que falta.
Ejecutar despues de aplicar el DDL, la carga de sg_efum y la migracion.
===============================================================================
*/

use secgen_db
go

set nocount on
go

/* --- 1. Catalogo sg_efum: debe existir con 4 filas (1,2,3,4) ------------- */

select
    case when count(*) = 4 then 'OK' else 'FALTA' end as estado,
    'sg_efum cargado' as control,
    count(*) as filas
from secgen_db.dbo.sg_efum
go

select cod_estfum, des_estfum
from secgen_db.dbo.sg_efum
order by cod_estfum
go

/* --- 2. sg_fume: columnas nuevas presentes y viejas eliminadas ----------- */

select
    case when sum(nuevas) = 5 and sum(viejas) = 0 then 'OK' else 'REVISAR' end as estado,
    'columnas de sg_fume' as control,
    sum(nuevas) as nuevas_presentes,
    sum(viejas) as viejas_pendientes
from (
    select
        case when c.name in ('corr_fume','cod_estfum','mto_realpa','mto_deslic','mto_dessg')
             then 1 else 0 end as nuevas,
        case when c.name in ('nro_cuota','cod_estcuo','fec_pago','ano_pago','mes_pago')
             then 1 else 0 end as viejas
    from syscolumns c, sysobjects o
    where o.name = 'sg_fume' and c.id = o.id
) x
go

/* --- 3. sg_fume: tipo de los montos ------------------------------------- */

select
    c.name as columna,
    t.name as tipo,
    c.prec as precision_,
    c.scale as escala,
    case when t.name = 'decimal' and c.scale = 2 then 'OK' else 'REVISAR' end as estado
from syscolumns c, sysobjects o, systypes t
where o.name = 'sg_fume'
  and c.id = o.id
  and c.usertype = t.usertype
  and c.name in ('mto_apagar','mto_realpa','mto_deslic','mto_dessg')
order by c.name
go

/* --- 4. sg_fume: ninguna fila sin estado, y todas en 1 ------------------- */

select
    case when count(*) = 0 then 'OK' else 'FALTA MIGRAR' end as estado,
    'filas sin cod_estfum' as control,
    count(*) as filas
from secgen_db.dbo.sg_fume
where cod_estfum is null
go

select
    cod_estfum,
    count(*) as filas,
    case when cod_estfum = 1 then 'esperado en resolucion'
         else 'revisar: solo pagos escribe otros estados' end as nota
from secgen_db.dbo.sg_fume
group by cod_estfum
order by cod_estfum
go

select
    case when count(*) = 0 then 'OK' else 'REVISAR' end as estado,
    'filas sin corr_fume' as control,
    count(*) as filas
from secgen_db.dbo.sg_fume
where corr_fume is null
go

/* --- 5. sg_fume: un solo registro por funcionario y mes ----------------- */

select
    case when count(*) = 0 then 'OK' else 'DUPLICADOS' end as estado,
    'meses duplicados por funcionario' as control,
    count(*) as casos
from (
    select id_funprse, ano_prop, mes_prop
    from secgen_db.dbo.sg_fume
    group by id_funprse, ano_prop, mes_prop
    having count(*) > 1
) x
go

/* --- 6. sg_fum2: espejo con las mismas columnas ------------------------- */

select
    case when count(*) = 5 then 'OK' else 'FALTAN COLUMNAS' end as estado,
    'columnas de sg_fum2' as control,
    count(*) as presentes
from syscolumns c, sysobjects o
where o.name = 'sg_fum2'
  and c.id = o.id
  and c.name in ('corr_fume','cod_estfum','mto_realpa','mto_deslic','mto_dessg')
go

/* --- 7. sg_fuc2: repuntada a corr_fume ---------------------------------- */

select
    case when count(*) = 1 then 'OK' else 'FALTA' end as estado,
    'sg_fuc2.corr_fume' as control,
    count(*) as presente
from syscolumns c, sysobjects o
where o.name = 'sg_fuc2' and c.id = o.id and c.name = 'corr_fume'
go

/* --- 8. Llaves y restricciones ------------------------------------------ */

select
    o.name as tabla,
    i.name as indice,
    index_col(o.name, i.indid, 1) as col_1,
    index_col(o.name, i.indid, 2) as col_2
from sysindexes i, sysobjects o
where i.id = o.id
  and o.name in ('sg_fume','sg_fum2','sg_efum')
  and i.indid > 0
order by o.name, i.indid
go

/* --- 9. Los dos PA existen ---------------------------------------------- */

select
    case when count(*) = 2 then 'OK' else 'FALTAN' end as estado,
    'PA de sg_fume compilados' as control,
    count(*) as presentes
from sysobjects o, sysusers u
where o.uid = u.uid
  and u.name = 'Analisis2'
  and o.type = 'P'
  and o.name in ('sg_fumeuSecgen01','sg_fupssSecgen17')
go

select
    case when count(*) = 4 then 'OK' else 'FALTAN' end as estado,
    'PA de sg_efum compilados' as control,
    count(*) as presentes
from sysobjects o, sysusers u
where o.uid = u.uid
  and u.name = 'Analisis2'
  and o.type = 'P'
  and o.name in ('sg_efumsSecgen01','sg_efumsSecgen02','sg_efumiSecgen01','sg_efumuSecgen01')
go

/* --- 10. Prueba funcional del PA de lectura ----------------------------- */

/* Reemplazar por un RUT con prestaciones DU288 archivadas. Debe devolver
   filas con corr_fume, cod_estfum y des_estfum poblados. Si corr_fume viene
   nulo, el modelo del backend descarta la fila en silencio y el cupo del
   numeral 6 contara cero. */

/* execute secgen_db.Analisis2.sg_fupssSecgen17 @rut_person = '000000000' */
go
