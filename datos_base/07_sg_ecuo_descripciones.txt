/* Actualiza solo descripciones; conserva codigos, cuotas y transiciones. */
use secgen_db
go

update dbo.sg_ecuo
   set des_estcuo = case cod_estcuo
       when 1 then 'Borrador'
       when 2 then 'En revisión DGDP'
       when 3 then 'Devuelta para corrección'
       when 4 then 'Aprobada por DGDP'
       when 8 then 'Enviada a remuneraciones'
       when 10 then 'Rechazada por DGDP'
       when 11 then 'Devuelta de Finanzas'
   end
 where cod_estcuo in (1, 2, 3, 4, 8, 10, 11)
go

select cod_estcuo, des_estcuo
  from dbo.sg_ecuo
 order by cod_estcuo
go
