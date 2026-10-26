-- secgen_db.dbo.sg_efum definition

-- Drop table

-- DROP TABLE secgen_db.dbo.sg_efum;

CREATE TABLE secgen_db.dbo.sg_efum (
	cod_estfum tinyint NOT NULL,
	des_estfum varchar(60) NOT NULL,
	CONSTRAINT SG_EFUM_PK PRIMARY KEY (cod_estfum)
);
CREATE UNIQUE INDEX PK_sg_efum ON secgen_db.dbo.sg_efum (cod_estfum);


-- secgen_db.dbo.sg_fume definition

-- Drop table

-- DROP TABLE secgen_db.dbo.sg_fume;

CREATE TABLE secgen_db.dbo.sg_fume (
	id_funprse int NOT NULL,
	corr_fume tinyint NOT NULL,
	ano_prop smallint NOT NULL,
	mes_prop tinyint NOT NULL,
	cod_estfum tinyint NOT NULL,
	ano_ejec smallint NULL,
	mes_ejec tinyint NULL,
	mto_apagar int NULL,
	id_evidenc int NULL,
	val_licmed char(1) NULL,
	val_inabili char(1) NULL,
	val_singoce char(1) NULL,
	val_ciecc char(1) NULL,
	fec_valida datetime NULL,
	rut_autori char(9) NULL,
	fec_autori datetime NULL,
	fec_envrem datetime NULL,
	mto_realpa int NULL,
	mto_deslic int NULL,
	mto_dessg int NULL,
	CONSTRAINT SG_FUME_PK PRIMARY KEY (id_funprse,corr_fume)
);
CREATE UNIQUE INDEX PK_sg_fume ON secgen_db.dbo.sg_fume (id_funprse,corr_fume);


-- secgen_db.dbo.sg_fups definition

-- Drop table

-- DROP TABLE secgen_db.dbo.sg_fups;

CREATE TABLE secgen_db.dbo.sg_fups (
	id_funprse int NOT NULL,
	nro_solici int NOT NULL,
	rut char(9) NOT NULL,
	cod_cargo smallint NULL,
	cod_sitm varchar(5) NULL,
	itm_global varchar(15) NULL,
	motivo varchar(255) NULL,
	periodos tinyint NOT NULL,
	monto_mes decimal(19,2) NOT NULL,
	mto_total decimal(19,2) NOT NULL,
	cod_moneda tinyint NULL,
	cod_tpps int NULL,
	f_inicio datetime NULL,
	f_termino datetime NULL,
	cod_estfun tinyint NULL,
	dentro_jor char(1) NULL,
	cod_contra int NULL,
	mes_haber tinyint NULL,
	ano_haber smallint NULL,
	mto_haber int NULL,
	mto_tope int NULL,
	f_cal_tope datetime NULL,
	tot_cuotas tinyint NULL,
	ext_cuotas char(1) NULL,
	CONSTRAINT SG_FUPS_PK PRIMARY KEY (id_funprse)
);
CREATE INDEX NC_sg_fups_rut ON secgen_db.dbo.sg_fups (rut);
CREATE UNIQUE INDEX PK_sg_fups ON secgen_db.dbo.sg_fups (id_funprse);


-- secgen_db.dbo.sg_dpag definition

-- Drop table

-- DROP TABLE secgen_db.dbo.sg_dpag;

CREATE TABLE secgen_db.dbo.sg_dpag (
	id_funprse int NOT NULL,
	nro_cuota tinyint NOT NULL,
	corr_fume tinyint NOT NULL,
	CONSTRAINT SG_DPAG_PK PRIMARY KEY (id_funprse,nro_cuota,corr_fume)
);
CREATE UNIQUE INDEX PK_sg_dpag ON secgen_db.dbo.sg_dpag (id_funprse,nro_cuota,corr_fume);


-- secgen_db.dbo.sg_fuc2 definition

-- Drop table

-- DROP TABLE secgen_db.dbo.sg_fuc2;

CREATE TABLE secgen_db.dbo.sg_fuc2 (
	id_funprse int NOT NULL,
	corr_fume tinyint NOT NULL,
	fec_comrea datetime NOT NULL,
	hora_ini time(3) NOT NULL,
	hora_ter time(3) NOT NULL,
	rut_regist char(9) NULL,
	CONSTRAINT SG_FUC2_PK PRIMARY KEY (id_funprse,corr_fume,fec_comrea)
);
CREATE UNIQUE INDEX PK_sg_fuc2 ON secgen_db.dbo.sg_fuc2 (id_funprse,corr_fume,fec_comrea);


-- secgen_db.dbo.sg_fum2 definition

-- Drop table

-- DROP TABLE secgen_db.dbo.sg_fum2;

CREATE TABLE secgen_db.dbo.sg_fum2 (
	id_funprse int NOT NULL,
	corr_fume tinyint NOT NULL,
	correlativ tinyint NOT NULL,
	ano_prop smallint NOT NULL,
	mes_prop tinyint NOT NULL,
	cod_estfum tinyint NOT NULL,
	ano_ejec smallint NULL,
	mes_ejec tinyint NULL,
	mto_apagar int NULL,
	id_evidenc int NULL,
	val_licmed char(1) NULL,
	val_inabili char(1) NULL,
	val_singoce char(1) NULL,
	val_ciecc char(1) NULL,
	fec_valida datetime NULL,
	rut_autori char(9) NULL,
	fec_autori datetime NULL,
	fec_envrem datetime NULL,
	mto_realpa int NULL,
	mto_deslic int NULL,
	mto_dessg int NULL,
	rut_regist char(9) NULL,
	f_regist datetime NULL,
	CONSTRAINT SG_FUM2_PK PRIMARY KEY (id_funprse,corr_fume,correlativ)
);
CREATE UNIQUE INDEX PK_sg_fum2 ON secgen_db.dbo.sg_fum2 (id_funprse,corr_fume,correlativ);


-- secgen_db.dbo.sg_fume foreign keys

ALTER TABLE secgen_db.dbo.sg_fume ADD CONSTRAINT FK_sg_fume_sg_efum FOREIGN KEY (cod_estfum) REFERENCES secgen_db.dbo.sg_efum(cod_estfum) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_fume ADD CONSTRAINT FK_sg_fume_sg_fups_2 FOREIGN KEY (id_funprse) REFERENCES secgen_db.dbo.sg_fups(id_funprse) ON DELETE RESTRICT ON UPDATE RESTRICT;


-- secgen_db.dbo.sg_fups foreign keys

ALTER TABLE secgen_db.dbo.sg_fups ADD CONSTRAINT FK_sg_fups_sg_efun FOREIGN KEY (cod_estfun) REFERENCES secgen_db.dbo.sg_efun(cod_estfun) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_fups ADD CONSTRAINT FK_sg_fups_sg_prse_2 FOREIGN KEY (nro_solici) REFERENCES secgen_db.dbo.sg_prse(nro_solici) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_fups ADD CONSTRAINT FK_sg_fups_sg_tpps_3 FOREIGN KEY (cod_tpps) REFERENCES secgen_db.dbo.sg_tpps(cod_tpps) ON DELETE RESTRICT ON UPDATE RESTRICT;


-- secgen_db.dbo.sg_dpag foreign keys

ALTER TABLE secgen_db.dbo.sg_dpag ADD CONSTRAINT FK_sg_dpag_sg_epag FOREIGN KEY (id_funprse,nro_cuota) REFERENCES secgen_db.dbo.sg_epag(id_funprse,nro_cuota) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_dpag ADD CONSTRAINT FK_sg_dpag_sg_fume FOREIGN KEY (corr_fume) REFERENCES secgen_db.dbo.sg_fume(id_funprse,corr_fume) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_dpag ADD CONSTRAINT FK_sg_dpag_sg_fume_3 FOREIGN KEY (id_funprse) REFERENCES secgen_db.dbo.sg_fume(id_funprse,corr_fume) ON DELETE RESTRICT ON UPDATE RESTRICT;


-- secgen_db.dbo.sg_fuc2 foreign keys

ALTER TABLE secgen_db.dbo.sg_fuc2 ADD CONSTRAINT FK_sg_fuc2_sg_fume FOREIGN KEY (id_funprse,corr_fume) REFERENCES secgen_db.dbo.sg_fume(id_funprse,corr_fume) ON DELETE RESTRICT ON UPDATE RESTRICT;


-- secgen_db.dbo.sg_fum2 foreign keys

ALTER TABLE secgen_db.dbo.sg_fum2 ADD CONSTRAINT FK_sg_fum2_sg_fume FOREIGN KEY (id_funprse,corr_fume) REFERENCES secgen_db.dbo.sg_fume(id_funprse,corr_fume) ON DELETE RESTRICT ON UPDATE RESTRICT;


-- secgen_db.dbo.sg_ecuo definition

-- Drop table

-- DROP TABLE secgen_db.dbo.sg_ecuo;

CREATE TABLE secgen_db.dbo.sg_ecuo (
	cod_estcuo tinyint NOT NULL,
	des_estcuo varchar(60) NOT NULL,
	CONSTRAINT SG_ECUO_PK PRIMARY KEY (cod_estcuo)
);
CREATE UNIQUE INDEX PK_sg_ecuo ON secgen_db.dbo.sg_ecuo (cod_estcuo);


-- secgen_db.dbo.sg_epag definition

-- Drop table

-- DROP TABLE secgen_db.dbo.sg_epag;

CREATE TABLE secgen_db.dbo.sg_epag (
	id_funprse int NOT NULL,
	nro_cuota tinyint NOT NULL,
	cod_estcuo tinyint NULL,
	rut_solici char(9) NULL,
	fec_solici datetime NULL,
	id_evidenc int NULL,
	fec_pago datetime NULL,
	ano_pago smallint NULL,
	mes_pago tinyint NULL,
	mto_realpa int NULL,
	CONSTRAINT SG_EPAG_PK PRIMARY KEY (id_funprse,nro_cuota)
);
CREATE UNIQUE INDEX PK_sg_epag ON secgen_db.dbo.sg_epag (id_funprse,nro_cuota);


-- secgen_db.dbo.sg_fups definition

-- Drop table

-- DROP TABLE secgen_db.dbo.sg_fups;

CREATE TABLE secgen_db.dbo.sg_fups (
	id_funprse int NOT NULL,
	nro_solici int NOT NULL,
	rut char(9) NOT NULL,
	cod_cargo smallint NULL,
	cod_sitm varchar(5) NULL,
	itm_global varchar(15) NULL,
	motivo varchar(255) NULL,
	periodos tinyint NOT NULL,
	monto_mes decimal(19,2) NOT NULL,
	mto_total decimal(19,2) NOT NULL,
	cod_moneda tinyint NULL,
	cod_tpps int NULL,
	f_inicio datetime NULL,
	f_termino datetime NULL,
	cod_estfun tinyint NULL,
	dentro_jor char(1) NULL,
	cod_contra int NULL,
	mes_haber tinyint NULL,
	ano_haber smallint NULL,
	mto_haber int NULL,
	mto_tope int NULL,
	f_cal_tope datetime NULL,
	tot_cuotas tinyint NULL,
	ext_cuotas char(1) NULL,
	CONSTRAINT SG_FUPS_PK PRIMARY KEY (id_funprse)
);
CREATE INDEX NC_sg_fups_rut ON secgen_db.dbo.sg_fups (rut);
CREATE UNIQUE INDEX PK_sg_fups ON secgen_db.dbo.sg_fups (id_funprse);


-- secgen_db.dbo.sg_com1 definition

-- Drop table

-- DROP TABLE secgen_db.dbo.sg_com1;

CREATE TABLE secgen_db.dbo.sg_com1 (
	id_funprse int NOT NULL,
	nro_cuota tinyint NOT NULL,
	f_observa datetime NOT NULL,
	id_tipacc tinyint NOT NULL,
	rut_accion char(9) NOT NULL,
	observaci text NULL,
	CONSTRAINT SG_COM1_PK PRIMARY KEY (id_funprse,nro_cuota,f_observa)
);
CREATE UNIQUE INDEX PK_sg_com1 ON secgen_db.dbo.sg_com1 (id_funprse,nro_cuota,f_observa);


-- secgen_db.dbo.sg_dpag definition

-- Drop table

-- DROP TABLE secgen_db.dbo.sg_dpag;

CREATE TABLE secgen_db.dbo.sg_dpag (
	id_funprse int NOT NULL,
	nro_cuota tinyint NOT NULL,
	corr_fume tinyint NOT NULL,
	CONSTRAINT SG_DPAG_PK PRIMARY KEY (id_funprse,nro_cuota,corr_fume)
);
CREATE UNIQUE INDEX PK_sg_dpag ON secgen_db.dbo.sg_dpag (id_funprse,nro_cuota,corr_fume);


-- secgen_db.dbo.sg_epag foreign keys

ALTER TABLE secgen_db.dbo.sg_epag ADD CONSTRAINT FK_sg_epag_sg_ecuo FOREIGN KEY (cod_estcuo) REFERENCES secgen_db.dbo.sg_ecuo(cod_estcuo) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_epag ADD CONSTRAINT FK_sg_epag_sg_fups_2 FOREIGN KEY (id_funprse) REFERENCES secgen_db.dbo.sg_fups(id_funprse) ON DELETE RESTRICT ON UPDATE RESTRICT;


-- secgen_db.dbo.sg_fups foreign keys

ALTER TABLE secgen_db.dbo.sg_fups ADD CONSTRAINT FK_sg_fups_sg_efun FOREIGN KEY (cod_estfun) REFERENCES secgen_db.dbo.sg_efun(cod_estfun) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_fups ADD CONSTRAINT FK_sg_fups_sg_prse_2 FOREIGN KEY (nro_solici) REFERENCES secgen_db.dbo.sg_prse(nro_solici) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_fups ADD CONSTRAINT FK_sg_fups_sg_tpps_3 FOREIGN KEY (cod_tpps) REFERENCES secgen_db.dbo.sg_tpps(cod_tpps) ON DELETE RESTRICT ON UPDATE RESTRICT;


-- secgen_db.dbo.sg_com1 foreign keys

ALTER TABLE secgen_db.dbo.sg_com1 ADD CONSTRAINT FK_sg_com1_sg_epag FOREIGN KEY (id_funprse,nro_cuota) REFERENCES secgen_db.dbo.sg_epag(id_funprse,nro_cuota) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_com1 ADD CONSTRAINT FK_sg_com1_sg_tacc_3 FOREIGN KEY (id_tipacc) REFERENCES secgen_db.dbo.sg_tacc(id_tipacc) ON DELETE RESTRICT ON UPDATE RESTRICT;


-- secgen_db.dbo.sg_dpag foreign keys

ALTER TABLE secgen_db.dbo.sg_dpag ADD CONSTRAINT FK_sg_dpag_sg_epag FOREIGN KEY (id_funprse,nro_cuota) REFERENCES secgen_db.dbo.sg_epag(id_funprse,nro_cuota) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_dpag ADD CONSTRAINT FK_sg_dpag_sg_fume FOREIGN KEY (corr_fume) REFERENCES secgen_db.dbo.sg_fume(id_funprse,corr_fume) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_dpag ADD CONSTRAINT FK_sg_dpag_sg_fume_3 FOREIGN KEY (id_funprse) REFERENCES secgen_db.dbo.sg_fume(id_funprse,corr_fume) ON DELETE RESTRICT ON UPDATE RESTRICT;