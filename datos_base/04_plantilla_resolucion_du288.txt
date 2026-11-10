/*
===============================================================================
DU288 - PLANTILLA DE RESOLUCION PARA CERTIFICACION
Motor : Sybase ASE 12.5

IDs definidos:
  sg_plse.cod_tipsec = 1
  sg_plre.id_planti  = 7
  sg_plde.id_pladet  = 31..44, con el orden normativo ya acordado.

Actualiza los registros existentes e inserta los faltantes.
===============================================================================
*/

USE secgen_db
GO

SET NOCOUNT ON
GO

UPDATE secgen_db.dbo.sg_plse
SET des_tipsec = 'Sección General', nro_orden = 1, vigente = 'S'
WHERE cod_tipsec = 1

IF @@rowcount = 0
    INSERT INTO secgen_db.dbo.sg_plse
        (cod_tipsec, des_tipsec, nro_orden, vigente)
    VALUES (1, 'Sección General', 1, 'S')
GO

UPDATE secgen_db.dbo.sg_plre
SET nombre = 'Plantilla Prestación de Servicios DU288',
    vigente = 'S',
    cod_tipsol = 1,
    f_ultmodif = GETDATE()
WHERE id_planti = 7

IF @@rowcount = 0
    INSERT INTO secgen_db.dbo.sg_plre
        (id_planti, nombre, vigente, cod_tipsol, f_creacion, f_ultmodif)
    VALUES
        (7, 'Plantilla Prestación de Servicios DU288', 'S', 1, GETDATE(), GETDATE())
GO

/* VISTOS */
UPDATE secgen_db.dbo.sg_plde
SET id_planti = 7,
    cod_tipsec = 1,
    nombre = 'VISTOS',
    valor = '<h4><strong>VISTOS:</strong></h4><ul><li><p>Ley N° 21.094, Ley sobre Universidades del Estado.</p></li><li><p>DFL N° 17 de 1981 del MINEDUC que crea la Universidad de La Frontera.</p></li><li><p>DFL N° 156 de 1981 del MINEDUC que aprueba el Estatuto de la Universidad de La Frontera.</p></li><li><p>D.U. N° 288 de 1991 que aprueba el Reglamento sobre Prestaciones de Servicios, modificado por D.U. N° 405 de 2016.</p></li><li><p>D.U. N° 314 de 2010 que aprueba nombramiento de Secretario General de la Universidad de La Frontera.</p></li><li><p>Decreto TRA N° 228 de 2018 que aprueba nombramiento de Vicerrector de Administración y Finanzas de la Universidad de La Frontera.</p></li><li><p>Resolución Exenta N° 1650 de 2010, que aprobó la delegación de facultades, modificada por la Resolución Exenta N° 3901 de 2011.</p></li></ul>',
    editable = 'S', orden = 1, f_ultmodif = GETDATE()
WHERE id_pladet = 31

IF @@rowcount = 0
    INSERT INTO secgen_db.dbo.sg_plde
        (id_pladet, id_planti, cod_tipsec, nombre, valor, editable, orden, f_creacion, f_ultmodif)
    VALUES
        (31, 7, 1, 'VISTOS', '<h4><strong>VISTOS:</strong></h4><ul><li><p>Ley N° 21.094, Ley sobre Universidades del Estado.</p></li><li><p>DFL N° 17 de 1981 del MINEDUC que crea la Universidad de La Frontera.</p></li><li><p>DFL N° 156 de 1981 del MINEDUC que aprueba el Estatuto de la Universidad de La Frontera.</p></li><li><p>D.U. N° 288 de 1991 que aprueba el Reglamento sobre Prestaciones de Servicios, modificado por D.U. N° 405 de 2016.</p></li><li><p>D.U. N° 314 de 2010 que aprueba nombramiento de Secretario General de la Universidad de La Frontera.</p></li><li><p>Decreto TRA N° 228 de 2018 que aprueba nombramiento de Vicerrector de Administración y Finanzas de la Universidad de La Frontera.</p></li><li><p>Resolución Exenta N° 1650 de 2010, que aprobó la delegación de facultades, modificada por la Resolución Exenta N° 3901 de 2011.</p></li></ul>', 'S', 1, GETDATE(), GETDATE())
GO

/* CONSIDERANDO 1 */
UPDATE secgen_db.dbo.sg_plde
SET id_planti = 7, cod_tipsec = 1, nombre = 'CONSIDERANDO - 1',
    valor = '<h4><strong>CONSIDERANDO:</strong></h4><p>1.- Que el artículo 99 de la Ley 18.681, del Ministerio de Hacienda, publicada en el Diario Oficial con fecha 31 de diciembre de 1987, autoriza a la Universidad de La Frontera a:</p><p>a) Prestar servicios remunerados, tales como asistencia técnica, investigación y de toda otra clase, a personas naturales o jurídicas de derecho público o privado, nacionales, extranjeras o internacionales, en las áreas de conocimiento o de competencia de los respectivos organismos.</p><p>b) Ejecutar actos y celebrar contratos que, estando orientados a mantener, a mejorar o acrecentar las condiciones de funcionamiento y operatividad de la entidad de Educación Superior, puedan implicar también contribución a su financiamiento o incremento de su patrimonio.</p>',
    editable = 'S', orden = 2, f_ultmodif = GETDATE()
WHERE id_pladet = 32

IF @@rowcount = 0
    INSERT INTO secgen_db.dbo.sg_plde VALUES
        (32, 7, 1, 'CONSIDERANDO - 1', '<h4><strong>CONSIDERANDO:</strong></h4><p>1.- Que el artículo 99 de la Ley 18.681, del Ministerio de Hacienda, publicada en el Diario Oficial con fecha 31 de diciembre de 1987, autoriza a la Universidad de La Frontera a:</p><p>a) Prestar servicios remunerados, tales como asistencia técnica, investigación y de toda otra clase, a personas naturales o jurídicas de derecho público o privado, nacionales, extranjeras o internacionales, en las áreas de conocimiento o de competencia de los respectivos organismos.</p><p>b) Ejecutar actos y celebrar contratos que, estando orientados a mantener, a mejorar o acrecentar las condiciones de funcionamiento y operatividad de la entidad de Educación Superior, puedan implicar también contribución a su financiamiento o incremento de su patrimonio.</p>', 'S', 2, GETDATE(), GETDATE())
GO

/* CONSIDERANDO 2 */
UPDATE secgen_db.dbo.sg_plde
SET id_planti = 7, cod_tipsec = 1, nombre = 'CONSIDERANDO - 2',
    valor = '<p>2.- Con arreglo a esa normativa, la Rectoría de la Universidad de La Frontera dictó el D.U. N°288 de 12 de julio de 1991, modificado por el D.U. N°405 de 29 de noviembre de 2016, que en su artículo 13° dispone que la participación de los académicos y funcionarios en las actividades descritas en las letras a) y b) del artículo 99 de la Ley N°18.681 se pagará a través de una &quot;asignación de prestación de servicios&quot;, imponible y tributable; cuya liquidación se efectuará junto al pago de remuneraciones del mes que corresponda. Siendo responsabilidad del director de la Unidad prestadora de servicio, o de la realización del estudio, trabajo, etc., informar acerca del funcionario o funcionarios involucrados y los montos que deberán ser pagados a cada uno. El pago de la asignación se hará contra ingresos realmente percibidos.</p>',
    editable = 'S', orden = 3, f_ultmodif = GETDATE()
WHERE id_pladet = 33

IF @@rowcount = 0
    INSERT INTO secgen_db.dbo.sg_plde VALUES
        (33, 7, 1, 'CONSIDERANDO - 2', '<p>2.- Con arreglo a esa normativa, la Rectoría de la Universidad de La Frontera dictó el D.U. N°288 de 12 de julio de 1991, modificado por el D.U. N°405 de 29 de noviembre de 2016, que en su artículo 13° dispone que la participación de los académicos y funcionarios en las actividades descritas en las letras a) y b) del artículo 99 de la Ley N°18.681 se pagará a través de una &quot;asignación de prestación de servicios&quot;, imponible y tributable; cuya liquidación se efectuará junto al pago de remuneraciones del mes que corresponda. Siendo responsabilidad del director de la Unidad prestadora de servicio, o de la realización del estudio, trabajo, etc., informar acerca del funcionario o funcionarios involucrados y los montos que deberán ser pagados a cada uno. El pago de la asignación se hará contra ingresos realmente percibidos.</p>', 'S', 3, GETDATE(), GETDATE())
GO

/* CONSIDERANDO 3 */
UPDATE secgen_db.dbo.sg_plde
SET id_planti = 7, cod_tipsec = 1, nombre = 'CONSIDERANDO - 3',
    valor = '<p>3.- Que, conforme al Ordinario N°159, de fecha 03 de diciembre de 2014, de Contraloría Universitaria, es la unidad que solicita el otorgamiento de la prestación de servicios la que da fe y es responsable de que se cumplan los supuestos de la norma antes indicada, ello ya que el artículo 10° del D.U. N°288 de 1991 y sus modificaciones dispone que es &quot;responsabilidad del Director de la Unidad prestadora de servicio, informar acerca de los funcionarios involucrados y los montos que deberán ser cancelados a cada uno. La cancelación de la asignación se hará contra ingresos realmente percibidos&quot;.</p>',
    editable = 'S', orden = 4, f_ultmodif = GETDATE()
WHERE id_pladet = 34

IF @@rowcount = 0
    INSERT INTO secgen_db.dbo.sg_plde VALUES
        (34, 7, 1, 'CONSIDERANDO - 3', '<p>3.- Que, conforme al Ordinario N°159, de fecha 03 de diciembre de 2014, de Contraloría Universitaria, es la unidad que solicita el otorgamiento de la prestación de servicios la que da fe y es responsable de que se cumplan los supuestos de la norma antes indicada, ello ya que el artículo 10° del D.U. N°288 de 1991 y sus modificaciones dispone que es &quot;responsabilidad del Director de la Unidad prestadora de servicio, informar acerca de los funcionarios involucrados y los montos que deberán ser cancelados a cada uno. La cancelación de la asignación se hará contra ingresos realmente percibidos&quot;.</p>', 'S', 4, GETDATE(), GETDATE())
GO

/* CONSIDERANDO 4 */
UPDATE secgen_db.dbo.sg_plde
SET id_planti = 7, cod_tipsec = 1, nombre = 'CONSIDERANDO - 4',
    valor = '<p>4.- Que, el D.U. N°009 de 2026 establece que el otorgamiento de dicha asignación debe formalizarse mediante resolución fundada, indicando funciones, evidencias, jornada y encuadre normativo, y sujetándose a condiciones y límites previamente verificados. Adicionalmente, impone que la procedencia del otorgamiento de la asignación exige, copulativamente: (i) la existencia de una prestación de servicios debidamente autorizada; (ii) solicitud fundada de la unidad ejecutora con individualización de funciones y evidencias; (iii) verificación por la Dirección de Gestión y Desarrollo de Personas del cumplimiento de los requisitos personales, compatibilidad de funciones y ausencia de inhabilidades; (iv) respeto del límite máximo mensual de la asignación; y (v) disponibilidad presupuestaria certificada con cargo al proyecto respectivo. Asimismo, no procederá su otorgamiento respecto de acciones de formación continua, tales como postítulos, diplomados, magísteres, doctorados, cursos u otras actividades análogas, ni respecto de actividades que deban financiarse mediante programas docentes especiales u otro régimen especial de pago previsto en la normativa institucional.</p>',
    editable = 'S', orden = 5, f_ultmodif = GETDATE()
WHERE id_pladet = 35

IF @@rowcount = 0
    INSERT INTO secgen_db.dbo.sg_plde VALUES
        (35, 7, 1, 'CONSIDERANDO - 4', '<p>4.- Que, el D.U. N°009 de 2026 establece que el otorgamiento de dicha asignación debe formalizarse mediante resolución fundada, indicando funciones, evidencias, jornada y encuadre normativo, y sujetándose a condiciones y límites previamente verificados. Adicionalmente, impone que la procedencia del otorgamiento de la asignación exige, copulativamente: (i) la existencia de una prestación de servicios debidamente autorizada; (ii) solicitud fundada de la unidad ejecutora con individualización de funciones y evidencias; (iii) verificación por la Dirección de Gestión y Desarrollo de Personas del cumplimiento de los requisitos personales, compatibilidad de funciones y ausencia de inhabilidades; (iv) respeto del límite máximo mensual de la asignación; y (v) disponibilidad presupuestaria certificada con cargo al proyecto respectivo. Asimismo, no procederá su otorgamiento respecto de acciones de formación continua, tales como postítulos, diplomados, magísteres, doctorados, cursos u otras actividades análogas, ni respecto de actividades que deban financiarse mediante programas docentes especiales u otro régimen especial de pago previsto en la normativa institucional.</p>', 'S', 5, GETDATE(), GETDATE())
GO

/* CONSIDERANDO 5 */
UPDATE secgen_db.dbo.sg_plde
SET id_planti = 7, cod_tipsec = 1, nombre = 'CONSIDERANDO - 5',
    valor = '<p>5.- Que, mediante documento de fecha {{fecha_solicitud}}, {{unidad_solicitante}} solicitó el otorgamiento de la asignación de prestación de servicios, individualizando a los/las funcionarios/as, las funciones a desempeñar, sus evidencias asociadas, el período de ejecución y su encuadre en las hipótesis del artículo 99 de la Ley N°18.681.</p>',
    editable = 'S', orden = 6, f_ultmodif = GETDATE()
WHERE id_pladet = 36

IF @@rowcount = 0
    INSERT INTO secgen_db.dbo.sg_plde VALUES
        (36, 7, 1, 'CONSIDERANDO - 5', '<p>5.- Que, mediante documento de fecha {{fecha_solicitud}}, {{unidad_solicitante}} solicitó el otorgamiento de la asignación de prestación de servicios, individualizando a los/las funcionarios/as, las funciones a desempeñar, sus evidencias asociadas, el período de ejecución y su encuadre en las hipótesis del artículo 99 de la Ley N°18.681.</p>', 'S', 6, GETDATE(), GETDATE())
GO

/* CONSIDERANDO 6 */
UPDATE secgen_db.dbo.sg_plde
SET id_planti = 7, cod_tipsec = 1, nombre = 'CONSIDERANDO - 6',
    valor = '<p>6.- Que, la unidad requirente ha certificado que las funciones encomendadas se vinculan directamente con la ejecución del proyecto o actividad {{proyecto_actividad}}, asegurando la debida trazabilidad del gasto.</p>',
    editable = 'S', orden = 7, f_ultmodif = GETDATE()
WHERE id_pladet = 37

IF @@rowcount = 0
    INSERT INTO secgen_db.dbo.sg_plde VALUES
        (37, 7, 1, 'CONSIDERANDO - 6', '<p>6.- Que, la unidad requirente ha certificado que las funciones encomendadas se vinculan directamente con la ejecución del proyecto o actividad {{proyecto_actividad}}, asegurando la debida trazabilidad del gasto.</p>', 'S', 7, GETDATE(), GETDATE())
GO

/* CONSIDERANDO 7 */
UPDATE secgen_db.dbo.sg_plde
SET id_planti = 7, cod_tipsec = 1, nombre = 'CONSIDERANDO - 7',
    valor = '<p>7.- Que, la Dirección de Gestión y Desarrollo de Personas ha validado el cumplimiento de los requisitos establecidos en el protocolo vigente, verificando:</p><p>a) La inexistencia de inhabilidades para percibir la asignación.</p><p>b) La correcta individualización de las funciones a desempeñar y de sus evidencias asociadas.</p><p>c) Que el monto propuesto no excede del límite máximo mensual aplicable, equivalente al 50% de la remuneración bruta mensual de la persona beneficiaria, entendida, para estos efectos, como sueldo base y asignaciones permanentes del mes anterior a la solicitud, o del límite especial que corresponda según la planta o estamento respectivo.</p><p>d) Que las funciones objeto de la asignación resultan compatibles con la jornada y obligaciones del cargo, sea porque, tratándose de personal académico, se relacionan con funciones institucionales reconocidas que pueden imputarse a su jornada académica, o porque, tratándose de personal administrativo, se ejecutarán fuera de la jornada ordinaria de trabajo o serán debidamente compensadas conforme a los mecanismos institucionales vigentes.</p><p>e) Que las actividades cuya ejecución se remunera no corresponden a acciones de formación continua, tales como postítulos, diplomados, cursos u otras análogas, ni a actividades que deban financiarse por la vía de programas docentes especiales u otro régimen especial de pago previsto en la normativa institucional.</p><p>f) Que la distribución del pago de la asignación se ajusta al límite de prorrateo previsto en el protocolo vigente para una misma actividad o proyecto, o cuenta con la autorización excepcional correspondiente.</p>',
    editable = 'S', orden = 8, f_ultmodif = GETDATE()
WHERE id_pladet = 38

IF @@rowcount = 0
    INSERT INTO secgen_db.dbo.sg_plde VALUES
        (38, 7, 1, 'CONSIDERANDO - 7', '<p>7.- Que, la Dirección de Gestión y Desarrollo de Personas ha validado el cumplimiento de los requisitos establecidos en el protocolo vigente, verificando:</p><p>a) La inexistencia de inhabilidades para percibir la asignación.</p><p>b) La correcta individualización de las funciones a desempeñar y de sus evidencias asociadas.</p><p>c) Que el monto propuesto no excede del límite máximo mensual aplicable, equivalente al 50% de la remuneración bruta mensual de la persona beneficiaria, entendida, para estos efectos, como sueldo base y asignaciones permanentes del mes anterior a la solicitud, o del límite especial que corresponda según la planta o estamento respectivo.</p><p>d) Que las funciones objeto de la asignación resultan compatibles con la jornada y obligaciones del cargo, sea porque, tratándose de personal académico, se relacionan con funciones institucionales reconocidas que pueden imputarse a su jornada académica, o porque, tratándose de personal administrativo, se ejecutarán fuera de la jornada ordinaria de trabajo o serán debidamente compensadas conforme a los mecanismos institucionales vigentes.</p><p>e) Que las actividades cuya ejecución se remunera no corresponden a acciones de formación continua, tales como postítulos, diplomados, cursos u otras análogas, ni a actividades que deban financiarse por la vía de programas docentes especiales u otro régimen especial de pago previsto en la normativa institucional.</p><p>f) Que la distribución del pago de la asignación se ajusta al límite de prorrateo previsto en el protocolo vigente para una misma actividad o proyecto, o cuenta con la autorización excepcional correspondiente.</p>', 'S', 8, GETDATE(), GETDATE())
GO

/* CONSIDERANDO 8 */
UPDATE secgen_db.dbo.sg_plde
SET id_planti = 7, cod_tipsec = 1, nombre = 'CONSIDERANDO - 8',
    valor = '<p>8.- Que, la Dirección de Finanzas ha certificado la disponibilidad presupuestaria en el centro de costos correspondiente, verificando que los recursos provienen del proyecto que da origen a la asignación.</p>',
    editable = 'S', orden = 9, f_ultmodif = GETDATE()
WHERE id_pladet = 39

IF @@rowcount = 0
    INSERT INTO secgen_db.dbo.sg_plde VALUES
        (39, 7, 1, 'CONSIDERANDO - 8', '<p>8.- Que, la Dirección de Finanzas ha certificado la disponibilidad presupuestaria en el centro de costos correspondiente, verificando que los recursos provienen del proyecto que da origen a la asignación.</p>', 'S', 9, GETDATE(), GETDATE())
GO

/* CONSIDERANDO 9 */
UPDATE secgen_db.dbo.sg_plde
SET id_planti = 7, cod_tipsec = 1, nombre = 'CONSIDERANDO - 9',
    valor = '<p>9.- Que, se ha verificado que las funciones cuentan con mecanismos de respaldo verificable, siendo responsabilidad del Director/a de la Unidad prestadora mantener dicha documentación para efectos de control.</p>',
    editable = 'S', orden = 10, f_ultmodif = GETDATE()
WHERE id_pladet = 40

IF @@rowcount = 0
    INSERT INTO secgen_db.dbo.sg_plde VALUES
        (40, 7, 1, 'CONSIDERANDO - 9', '<p>9.- Que, se ha verificado que las funciones cuentan con mecanismos de respaldo verificable, siendo responsabilidad del Director/a de la Unidad prestadora mantener dicha documentación para efectos de control.</p>', 'S', 10, GETDATE(), GETDATE())
GO

/* CONSIDERANDO 10: el ID 44 se mantiene por definicion. */
UPDATE secgen_db.dbo.sg_plde
SET id_planti = 7, cod_tipsec = 1, nombre = 'CONSIDERANDO - 10',
    valor = '<p>10.- Que, de conformidad a lo dispuesto en la Resolución Exenta N°36 de 2024 de la Contraloría General de La República sobre toma de razón, la presente resolución se encuentra exenta del trámite de toma de razón.</p>',
    editable = 'S', orden = 11, f_ultmodif = GETDATE()
WHERE id_pladet = 44

IF @@rowcount = 0
    INSERT INTO secgen_db.dbo.sg_plde VALUES
        (44, 7, 1, 'CONSIDERANDO - 10', '<p>10.- Que, de conformidad a lo dispuesto en la Resolución Exenta N°36 de 2024 de la Contraloría General de La República sobre toma de razón, la presente resolución se encuentra exenta del trámite de toma de razón.</p>', 'S', 11, GETDATE(), GETDATE())
GO

/* RESUELVO 1 */
UPDATE secgen_db.dbo.sg_plde
SET id_planti = 7, cod_tipsec = 1, nombre = 'RESUELVO - 1',
    valor = '<h4><strong>RESUELVO:</strong></h4><p><strong>1°) DISPÓNESE</strong> el pago de la &quot;Asignación de Prestación de Servicios&quot;, por el monto bruto señalado y con la remuneración del mes correspondiente, a los/las funcionarios/as individualizados/as en la presente resolución.</p>',
    editable = 'S', orden = 12, f_ultmodif = GETDATE()
WHERE id_pladet = 41

IF @@rowcount = 0
    INSERT INTO secgen_db.dbo.sg_plde VALUES
        (41, 7, 1, 'RESUELVO - 1', '<h4><strong>RESUELVO:</strong></h4><p><strong>1°) DISPÓNESE</strong> el pago de la &quot;Asignación de Prestación de Servicios&quot;, por el monto bruto señalado y con la remuneración del mes correspondiente, a los/las funcionarios/as individualizados/as en la presente resolución.</p>', 'S', 12, GETDATE(), GETDATE())
GO

/* RESUELVO 2 */
UPDATE secgen_db.dbo.sg_plde
SET id_planti = 7, cod_tipsec = 1, nombre = 'RESUELVO - 2',
    valor = '<p><strong>2°) DÉJESE CONSTANCIA</strong> que la Unidad Prestadora del Servicio o de la realización del estudio, trabajo, etc., será responsable de mantener a disposición de la Universidad los antecedentes de respaldo que acrediten la efectiva ejecución de las funciones, su correspondencia con el proyecto o actividad respectivo y el cumplimiento de las condiciones que justifican el pago de la asignación.</p>',
    editable = 'S', orden = 13, f_ultmodif = GETDATE()
WHERE id_pladet = 42

IF @@rowcount = 0
    INSERT INTO secgen_db.dbo.sg_plde VALUES
        (42, 7, 1, 'RESUELVO - 2', '<p><strong>2°) DÉJESE CONSTANCIA</strong> que la Unidad Prestadora del Servicio o de la realización del estudio, trabajo, etc., será responsable de mantener a disposición de la Universidad los antecedentes de respaldo que acrediten la efectiva ejecución de las funciones, su correspondencia con el proyecto o actividad respectivo y el cumplimiento de las condiciones que justifican el pago de la asignación.</p>', 'S', 13, GETDATE(), GETDATE())
GO

/* RESUELVO 3 */
UPDATE secgen_db.dbo.sg_plde
SET id_planti = 7, cod_tipsec = 1, nombre = 'RESUELVO - 3',
    valor = '<p><strong>3°) ESTABLÉCESE</strong> que la verificación posterior del incumplimiento de las condiciones que habilitan el otorgamiento de la asignación, o la falta de acreditación suficiente de las funciones y evidencias comprometidas, podrá dar lugar a la suspensión de pagos pendientes y, en su caso, a la restitución de las sumas indebidamente percibidas, sin perjuicio de las demás responsabilidades que procedan.</p>',
    editable = 'S', orden = 14, f_ultmodif = GETDATE()
WHERE id_pladet = 43

IF @@rowcount = 0
    INSERT INTO secgen_db.dbo.sg_plde VALUES
        (43, 7, 1, 'RESUELVO - 3', '<p><strong>3°) ESTABLÉCESE</strong> que la verificación posterior del incumplimiento de las condiciones que habilitan el otorgamiento de la asignación, o la falta de acreditación suficiente de las funciones y evidencias comprometidas, podrá dar lugar a la suspensión de pagos pendientes y, en su caso, a la restitución de las sumas indebidamente percibidas, sin perjuicio de las demás responsabilidades que procedan.</p>', 'S', 14, GETDATE(), GETDATE())
GO
