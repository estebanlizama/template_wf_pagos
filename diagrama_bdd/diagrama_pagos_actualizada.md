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


-- secgen_db.dbo.sg_dpag foreign keys

ALTER TABLE secgen_db.dbo.sg_dpag ADD CONSTRAINT FK_sg_dpag_sg_epag FOREIGN KEY (id_funprse,nro_cuota) REFERENCES secgen_db.dbo.sg_epag(id_funprse,nro_cuota) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_dpag ADD CONSTRAINT FK_sg_dpag_sg_fume FOREIGN KEY (corr_fume) REFERENCES secgen_db.dbo.sg_fume(id_funprse,corr_fume) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_dpag ADD CONSTRAINT FK_sg_dpag_sg_fume_3 FOREIGN KEY (id_funprse) REFERENCES secgen_db.dbo.sg_fume(id_funprse,corr_fume) ON DELETE RESTRICT ON UPDATE RESTRICT;


-- secgen_db.dbo.sg_epag foreign keys

ALTER TABLE secgen_db.dbo.sg_epag ADD CONSTRAINT FK_sg_epag_sg_ecuo FOREIGN KEY (cod_estcuo) REFERENCES secgen_db.dbo.sg_ecuo(cod_estcuo) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_epag ADD CONSTRAINT FK_sg_epag_sg_fups_2 FOREIGN KEY (id_funprse) REFERENCES secgen_db.dbo.sg_fups(id_funprse) ON DELETE RESTRICT ON UPDATE RESTRICT;


-- secgen_db.dbo.sg_fume foreign keys

ALTER TABLE secgen_db.dbo.sg_fume ADD CONSTRAINT FK_sg_fume_sg_efum FOREIGN KEY (cod_estfum) REFERENCES secgen_db.dbo.sg_efum(cod_estfum) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_fume ADD CONSTRAINT FK_sg_fume_sg_fups_2 FOREIGN KEY (id_funprse) REFERENCES secgen_db.dbo.sg_fups(id_funprse) ON DELETE RESTRICT ON UPDATE RESTRICT;

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


-- secgen_db.dbo.sg_dpag foreign keys

ALTER TABLE secgen_db.dbo.sg_dpag ADD CONSTRAINT FK_sg_dpag_sg_epag FOREIGN KEY (id_funprse,nro_cuota) REFERENCES secgen_db.dbo.sg_epag(id_funprse,nro_cuota) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_dpag ADD CONSTRAINT FK_sg_dpag_sg_fume FOREIGN KEY (corr_fume) REFERENCES secgen_db.dbo.sg_fume(id_funprse,corr_fume) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_dpag ADD CONSTRAINT FK_sg_dpag_sg_fume_3 FOREIGN KEY (id_funprse) REFERENCES secgen_db.dbo.sg_fume(id_funprse,corr_fume) ON DELETE RESTRICT ON UPDATE RESTRICT;


-- secgen_db.dbo.sg_epag foreign keys

ALTER TABLE secgen_db.dbo.sg_epag ADD CONSTRAINT FK_sg_epag_sg_ecuo FOREIGN KEY (cod_estcuo) REFERENCES secgen_db.dbo.sg_ecuo(cod_estcuo) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_epag ADD CONSTRAINT FK_sg_epag_sg_fups_2 FOREIGN KEY (id_funprse) REFERENCES secgen_db.dbo.sg_fups(id_funprse) ON DELETE RESTRICT ON UPDATE RESTRICT;


-- secgen_db.dbo.sg_fume foreign keys

ALTER TABLE secgen_db.dbo.sg_fume ADD CONSTRAINT FK_sg_fume_sg_efum FOREIGN KEY (cod_estfum) REFERENCES secgen_db.dbo.sg_efum(cod_estfum) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_fume ADD CONSTRAINT FK_sg_fume_sg_fups_2 FOREIGN KEY (id_funprse) REFERENCES secgen_db.dbo.sg_fups(id_funprse) ON DELETE RESTRICT ON UPDATE RESTRICT;


-- secgen_db.dbo.sg_efun definition

-- Drop table

-- DROP TABLE secgen_db.dbo.sg_efun;

CREATE TABLE secgen_db.dbo.sg_efun (
	cod_estfun tinyint NOT NULL,
	des_estfun varchar(60) NOT NULL,
	CONSTRAINT SG_EFUN_PK PRIMARY KEY (cod_estfun)
);
CREATE UNIQUE INDEX PK_sg_efun ON secgen_db.dbo.sg_efun (cod_estfun);


-- secgen_db.dbo.sg_tpps definition

-- Drop table

-- DROP TABLE secgen_db.dbo.sg_tpps;

CREATE TABLE secgen_db.dbo.sg_tpps (
	cod_tpps int NOT NULL,
	des_tpps varchar(10) NOT NULL,
	CONSTRAINT SG_TPPS_PK PRIMARY KEY (cod_tpps)
);
CREATE UNIQUE INDEX PK_sg_tpps ON secgen_db.dbo.sg_tpps (cod_tpps);


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


-- secgen_db.dbo.sg_prse definition

-- Drop table

-- DROP TABLE secgen_db.dbo.sg_prse;

CREATE TABLE secgen_db.dbo.sg_prse (
	nro_solici int NOT NULL,
	actividad varchar(255) NOT NULL,
	per_desde datetime NOT NULL,
	per_hasta datetime NOT NULL,
	rut_jefpro char(9) NOT NULL,
	cod_unifin smallint NULL,
	cod_ccto smallint NULL,
	cc_global varchar(9) NULL,
	pry_global varchar(12) NULL,
	cod_modprs tinyint NULL,
	cod_flusol tinyint NULL,
	cod_etapa tinyint NULL,
	CONSTRAINT SG_PRSE_PK PRIMARY KEY (nro_solici)
);
CREATE UNIQUE INDEX PK_sg_prse ON secgen_db.dbo.sg_prse (nro_solici);


-- secgen_db.dbo.sg_apso definition

-- Drop table

-- DROP TABLE secgen_db.dbo.sg_apso;

CREATE TABLE secgen_db.dbo.sg_apso (
	nro_aproba int NOT NULL,
	nro_solici int NOT NULL,
	rut_usua char(9) NOT NULL,
	cod_estapr tinyint NOT NULL,
	comentario text NULL,
	f_aprobac datetime NULL,
	f_creacion datetime NULL,
	f_ultmodif datetime NULL,
	cod_flusol tinyint NULL,
	cod_etapa tinyint NULL,
	rut_autori char(9) NULL,
	id_funprse int NULL,
	CONSTRAINT SG_APSO_PK PRIMARY KEY (nro_aproba)
);
CREATE INDEX NC_sg_apso_rut ON secgen_db.dbo.sg_apso (rut_usua);
CREATE INDEX NC_sg_apso_soli ON secgen_db.dbo.sg_apso (nro_solici);
CREATE UNIQUE INDEX PK_sg_apso ON secgen_db.dbo.sg_apso (nro_aproba);


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


-- secgen_db.dbo.sg_fuco definition

-- Drop table

-- DROP TABLE secgen_db.dbo.sg_fuco;

CREATE TABLE secgen_db.dbo.sg_fuco (
	id_funprse int NOT NULL,
	fec_compro datetime NOT NULL,
	hora_ini time(3) NOT NULL,
	hora_ter time(3) NOT NULL,
	CONSTRAINT SG_FUCO_PK PRIMARY KEY (id_funprse,fec_compro)
);
CREATE UNIQUE INDEX PK_sg_fuco ON secgen_db.dbo.sg_fuco (id_funprse,fec_compro);


-- secgen_db.dbo.sg_fuho definition

-- Drop table

-- DROP TABLE secgen_db.dbo.sg_fuho;

CREATE TABLE secgen_db.dbo.sg_fuho (
	id_funprse int NOT NULL,
	cod_diasem tinyint NOT NULL,
	correlativ tinyint NOT NULL,
	hora_ini time(3) NOT NULL,
	hora_ter time(3) NOT NULL,
	CONSTRAINT SG_FUHO_PK PRIMARY KEY (id_funprse,cod_diasem,correlativ)
);
CREATE UNIQUE INDEX PK_sg_fuho ON secgen_db.dbo.sg_fuho (id_funprse,cod_diasem,correlativ);


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


-- secgen_db.dbo.sg_his2 definition

-- Drop table

-- DROP TABLE secgen_db.dbo.sg_his2;

CREATE TABLE secgen_db.dbo.sg_his2 (
	id_funprse int NOT NULL,
	f_visacion datetime NOT NULL,
	rut_visado char(9) NOT NULL,
	cod_estact tinyint NOT NULL,
	cod_estnue tinyint NOT NULL,
	CONSTRAINT SG_HIS2_PK PRIMARY KEY (id_funprse,f_visacion)
);
CREATE UNIQUE INDEX PK_sg_his2 ON secgen_db.dbo.sg_his2 (id_funprse,f_visacion);


-- secgen_db.dbo.sg_fups foreign keys

ALTER TABLE secgen_db.dbo.sg_fups ADD CONSTRAINT FK_sg_fups_sg_efun FOREIGN KEY (cod_estfun) REFERENCES secgen_db.dbo.sg_efun(cod_estfun) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_fups ADD CONSTRAINT FK_sg_fups_sg_prse_2 FOREIGN KEY (nro_solici) REFERENCES secgen_db.dbo.sg_prse(nro_solici) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_fups ADD CONSTRAINT FK_sg_fups_sg_tpps_3 FOREIGN KEY (cod_tpps) REFERENCES secgen_db.dbo.sg_tpps(cod_tpps) ON DELETE RESTRICT ON UPDATE RESTRICT;


-- secgen_db.dbo.sg_prse foreign keys

ALTER TABLE secgen_db.dbo.sg_prse ADD CONSTRAINT FK_sg_prse_sg_eta1 FOREIGN KEY (cod_flusol,cod_etapa) REFERENCES secgen_db.dbo.sg_eta1(cod_flusol,cod_etapa) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_prse ADD CONSTRAINT FK_sg_prse_sg_soli_3 FOREIGN KEY (nro_solici) REFERENCES secgen_db.dbo.sg_soli(nro_solici) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_prse ADD CONSTRAINT FK_sg_prse_sg_tmod_4 FOREIGN KEY (cod_modprs) REFERENCES secgen_db.dbo.sg_tmod(cod_modprs) ON DELETE RESTRICT ON UPDATE RESTRICT;


-- secgen_db.dbo.sg_apso foreign keys

ALTER TABLE secgen_db.dbo.sg_apso ADD CONSTRAINT FK_sg_apso_sg_eapr FOREIGN KEY (cod_estapr) REFERENCES secgen_db.dbo.sg_eapr(cod_estapr) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_apso ADD CONSTRAINT FK_sg_apso_sg_eta1 FOREIGN KEY (cod_etapa) REFERENCES secgen_db.dbo.sg_eta1(cod_flusol,cod_etapa) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_apso ADD CONSTRAINT FK_sg_apso_sg_eta1_2 FOREIGN KEY (cod_flusol) REFERENCES secgen_db.dbo.sg_eta1(cod_flusol,cod_etapa) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_apso ADD CONSTRAINT FK_sg_apso_sg_fups_4 FOREIGN KEY (id_funprse) REFERENCES secgen_db.dbo.sg_fups(id_funprse) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_apso ADD CONSTRAINT FK_sg_apso_sg_soli_5 FOREIGN KEY (nro_solici) REFERENCES secgen_db.dbo.sg_soli(nro_solici) ON DELETE RESTRICT ON UPDATE RESTRICT;


-- secgen_db.dbo.sg_epag foreign keys

ALTER TABLE secgen_db.dbo.sg_epag ADD CONSTRAINT FK_sg_epag_sg_ecuo FOREIGN KEY (cod_estcuo) REFERENCES secgen_db.dbo.sg_ecuo(cod_estcuo) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_epag ADD CONSTRAINT FK_sg_epag_sg_fups_2 FOREIGN KEY (id_funprse) REFERENCES secgen_db.dbo.sg_fups(id_funprse) ON DELETE RESTRICT ON UPDATE RESTRICT;


-- secgen_db.dbo.sg_fuco foreign keys

ALTER TABLE secgen_db.dbo.sg_fuco ADD CONSTRAINT FK_sg_fuco_sg_fups FOREIGN KEY (id_funprse) REFERENCES secgen_db.dbo.sg_fups(id_funprse) ON DELETE RESTRICT ON UPDATE RESTRICT;


-- secgen_db.dbo.sg_fuho foreign keys

ALTER TABLE secgen_db.dbo.sg_fuho ADD CONSTRAINT FK_sg_fuho_sg_fups FOREIGN KEY (id_funprse) REFERENCES secgen_db.dbo.sg_fups(id_funprse) ON DELETE RESTRICT ON UPDATE RESTRICT;


-- secgen_db.dbo.sg_fume foreign keys

ALTER TABLE secgen_db.dbo.sg_fume ADD CONSTRAINT FK_sg_fume_sg_efum FOREIGN KEY (cod_estfum) REFERENCES secgen_db.dbo.sg_efum(cod_estfum) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE secgen_db.dbo.sg_fume ADD CONSTRAINT FK_sg_fume_sg_fups_2 FOREIGN KEY (id_funprse) REFERENCES secgen_db.dbo.sg_fups(id_funprse) ON DELETE RESTRICT ON UPDATE RESTRICT;


-- secgen_db.dbo.sg_his2 foreign keys

ALTER TABLE secgen_db.dbo.sg_his2 ADD CONSTRAINT FK_sg_his2_sg_fups FOREIGN KEY (id_funprse) REFERENCES secgen_db.dbo.sg_fups(id_funprse) ON DELETE RESTRICT ON UPDATE RESTRICT;