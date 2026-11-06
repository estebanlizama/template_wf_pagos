
if exists( select 1 from sysobjects a, sysusers b
              where a.uid  = b.uid
                and a.type = "P"
                and b.name = "Analisis"
                and a.name = "sspasd1")
           drop procedure Analisis.sspasd1
go

CREATE PROCEDURE Analisis.sspasd1  
/*Inserta datos en tabla Asignaciones a la Persona, creado por Maria Sandoval B*/  
  
@numero_resol   varchar(10),  
@codigo_decres  char(1),  
@codigo_unidad  char(8),  
@ano            char(4),  
@codigo_ficha   varchar(10),  
@numero_cuenta  varchar(10),  
@vigencia       char(1),  
@fec_inicio     char(10),  
@fec_termino    char(10),  
@observacion    varchar(100),  
@valor          decimal(9,2),  
@permanente     char(1),  
@cuotas         varchar(5),  
@unidad_medida  char(1)  
  
as  
  
declare @codigo_asignac     varchar(5)    
declare @contador		int   
select @contador = count (*) from ss_asds where cod_ficha = @codigo_ficha   
     
if @contador = 0   
	begin     
		select @codigo_asignac = convert(varchar, @@rowcount + 1 )   
	end     
else    
	begin     
    		select  @codigo_asignac = convert(varchar, max(convert(int, cod_asign)) +1) from ss_asds  
		where cod_ficha = @codigo_ficha    
	end         
  
if @fec_termino  = '__/__/____'     
	begin    
		select @fec_termino  = Null  
  
 end    
  
if @cuotas = ''    
	begin   
		select @cuotas = Null   
 end   
   
insert ss_asds  
  
values  
    (@numero_resol, @codigo_decres, @codigo_unidad, @ano, @codigo_ficha, @codigo_asignac,  
     @numero_cuenta, @vigencia, convert(datetime, @fec_inicio, 103),   
     convert(datetime, @fec_termino, 103), @observacion, @valor, @permanente,   
	convert(smallint, @cuotas), @unidad_medida,'1',getdate())  
  
select  @codigo_asignac   

go
grant execute on Analisis.sspasd1 to Person, Remune

