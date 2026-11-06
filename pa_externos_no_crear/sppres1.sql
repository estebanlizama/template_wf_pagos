
if exists( select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = "P"
                and b.name = "Analisis"
                and a.name = "sppres1")
           drop procedure Analisis.sppres1
go

CREATE PROCEDURE Analisis.sppres1 
/*Inserta datos en tabla Resoluciones y Decretos, creado por Maria Sandoval B*/ 
 
@num_resoluc    varchar(10), 
@cod_tipo_rs    char(1), 
@codigo_unid    char(8), 
@ano            char(4), 
@fec_resol      char(10), 
@motivo         varchar(250), 
@vistos         varchar(250), 
@considera      varchar(250), 
@resuelvo       varchar(250), 
@num_doc_ant    varchar(10) 
 
as 
 
insert sp_resl 
 
values   
    (@num_resoluc, @cod_tipo_rs, @codigo_unid, @ano, convert(datetime, @fec_resol,103), 
     @motivo,@vistos, @considera, @resuelvo, @num_doc_ant, 
     getdate())

go
grant execute on Analisis.sppres1 to Person, Remune
