
if exists( select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = "P"
                and b.name = "Analisis"
                and a.name = "sspcca1")
           drop procedure Analisis.sspcca1
go

CREATE PROCEDURE Analisis.sspcca1                  
/*Inserta datos en la tabla centros de costo de la asignacion a la persona, creado por Maria Sandoval B*/                  
                  
@codigo_ficha    varchar(10),                  
@codigo_asignac	varchar(5),                  
@unid_finan       smallint,                  
@financiamiento     smallint,                  
@valor_asignado     varchar(10),                  
@cod_sitm	varchar(5),                  
@centro_costo	smallint,                  
@f_inicio			char(10),                  
@f_termino		char(10)                  
                  
as                  
                  
    if @f_inicio = '__/__/____'                      
	    begin                     
		    select @f_inicio = Null                     
	    end                     
                   
    if @f_termino = '__/__/____'                      
	    begin                     
		    select @f_termino = Null                     
	    end                    
                  
                  
declare @codigo_cecoscon    varchar(5)                    
declare @contador		int                   
select @contador = count (*) from ss_ccas                   
                     
if @contador = 0                   
	begin                     
		select @codigo_cecoscon = convert(varchar, @@rowcount + 1 )                   
	end                     
else                    
	begin                     
    	select  @codigo_cecoscon = 'S'  + convert(varchar, max(convert(int, substring(cod_ccasig,2,4))) +1) from ss_ccas                  
					where  substring(cod_ccasig,1,1)='S'                   
                 
		if @codigo_cecoscon ='S'                 
			begin                  
				select @codigo_cecoscon ='S1'                 
			end                 
	end                  
                  
if @valor_asignado = ''                  
    begin                  
        select @valor_asignado = Null                  
    end                  
                  
insert ss_ccas                  
                  
values (@codigo_ficha, @codigo_asignac, @codigo_cecoscon, @unid_finan, @financiamiento,                   
        convert(decimal(9,2), @valor_asignado), @cod_sitm, @centro_costo, convert(datetime, @f_inicio,103),                   
		convert(datetime, @f_termino,103))                  
                  
select @codigo_cecoscon             
           
            
go
grant execute on Analisis.sspcca1 to Person,Remune