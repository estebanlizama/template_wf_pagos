num_resol |cod_ders|cod_unidad|ano |f_resoluc              |motivo                                                                                              |vistos|consider|resuelvo|num_docant|f_ingreso              |
----------+--------+----------+----+-----------------------+----------------------------------------------------------------------------------------------------+------+--------+--------+----------+-----------------------+
2250      |2       |05000000  |1931|2200-11-20 00:00:00.000|OTORGA ASIG. AL GRADO                                                                               |      |        |        |          |2002-12-30 17:16:52.067|
929       |2       |08000000  |1931|2200-10-21 00:00:00.000|Comisión de Servicios.                                                                              |      |        |        |          |2004-12-28 12:46:47.343|
702       |2       |08000000  |1931|2033-11-05 00:00:00.000|COMISION DE SERVICIOS                                                                               |      |        |        |          |2005-04-11 17:13:49.827|
5284 RA   |2       |05000000  |2026|2026-07-08 00:00:00.000|ENCOMENDACION DE FUNCIONES DIRECTIVAS                                                               |      |        |        |          |2026-07-24 17:09:46.890|

Datos que recibe y guarda
Parámetro	Tipo recibido	Qué representa según su nombre	Qué guarda
@num_resoluc	varchar(10)	Número de la resolución	El valor recibido
@cod_tipo_rs	char(1)	Código del tipo de resolución	El valor recibido
@codigo_unid	char(8)	Código de la unidad asociada	El valor recibido
@ano	char(4)	Año de la resolución	El valor recibido
@fec_resol	char(10)	Fecha de la resolución como texto	La convierte a fecha usando formato 103 (dd/mm/yyyy)
@motivo	varchar(250)	Motivo o fundamento de la resolución	El valor recibido
@vistos	varchar(250)	Antecedentes o documentos indicados en “Vistos”	El valor recibido
@considera	varchar(250)	Texto de los considerandos	El valor recibido
@resuelvo	varchar(250)	Texto de la parte resolutiva	El valor recibido
@num_doc_ant	varchar(10)	Número de documento antecedente, según el nombre	El valor recibido
—	—	Fecha y hora de registro de la inserción	getdate() del servidor