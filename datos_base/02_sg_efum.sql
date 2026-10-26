/*
===============================================================================
sg_efum - ESTADOS DEL MES DE EJECUCION
Motor : Sybase ASE 12.5
Tabla que lo usa: sg_fume.cod_estfum

Catalogo propio con numeracion contigua. NO coincide con sg_ecuo: un reporte
que muestre encabezado y mes juntos necesita traducir.

-------------------------------------------------------------------------------
PRINCIPIO
-------------------------------------------------------------------------------
El estado guarda HECHOS y DECISIONES, nunca resultados de validacion.

Las validaciones (licencia, sin goce, inhabilidad, contrato, saldo) son
dinamicas y se recalculan en cada transicion, sin cache. Persistir un estado
tipo "Validada" seria cachear un resultado que caduca: el mes quedaria marcado
como aprobado y nadie lo volveria a evaluar.

Por eso los val_* y fec_valida se conservan como REGISTRO DE AUDITORIA -- lo
que DGDP vio y decidio ese dia -- y no como permiso vigente.

-------------------------------------------------------------------------------
QUE ESCRIBE CADA FLUJO
-------------------------------------------------------------------------------
  RESOLUCION   escribe solo el 1. Lee los 4 (guarda de edicion y comparador).
  PAGOS        escribe el 2, el 3 y el 4, mas el retorno de 3 a 2 cuando
               Finanzas devuelve la cuota. NO escribe el 1: desde el
               26-10-2026 el rechazo de la cuota bloquea sus meses en 4 en
               vez de devolverlos a Propuesta.

-------------------------------------------------------------------------------
ESTADOS
-------------------------------------------------------------------------------
  1  Propuesta        HECHO. Lo escribe sg_fumeuSecgen01 al guardar la
                      resolucion. Es el unico estado que ese flujo asigna: el
                      mes se crea en 1 y, si el periodo se acorta, se borra
                      fisicamente. PAGOS no asigna este estado.
                      Columnas con dato: ano_prop, mes_prop.

  2  Comprometida     HECHO. El mes esta dentro de una cuota enviada. Consume
                      cupo y saldo, pero todavia es reversible. Se mantiene
                      mientras DGDP visa, observa o aprueba: el avance del
                      tramite vive en sg_epag, no aca.
                      Columnas con dato: mto_apagar, id_evidenc, y --cuando
                      DGDP revisa-- val_licmed, val_inabili, val_singoce,
                      val_ciecc, fec_valida, rut_autori, fec_autori,
                      mto_deslic, mto_dessg.

  3  Enviada a pago   HECHO. Su cuota se subio a Finanzas. Consume cupo.
                      NO es terminal: si Finanzas devuelve la cuota
                      (sg_ecuo = 11), el mes vuelve a 2 y puede reenviarse.
                      Columnas con dato: fec_envrem, mto_realpa. En un reenvio
                      ambas se sobrescriben: valen para el ultimo envio, no
                      para el primero.

  4  Rechazada        DECISION. DGDP descarto el mes y no se paga. Llega aca
                      por dos caminos: porque DGDP lo descarto puntualmente
                      -licencia, sin goce o trabajo no acreditado, con la
                      causal en los val_*- o porque se rechazo la cuota
                      completa que lo contenia. No se vuelve a ofrecer.

-------------------------------------------------------------------------------
LOS DOS RECHAZOS SON DISTINTOS
-------------------------------------------------------------------------------
  Rechazo del ENCABEZADO  sg_epag.cod_estcuo = 10
      Cae la cuota completa y arrastra a TODOS sus meses: pasan a sg_efum = 4.
      El cupo de la cuota queda consumido y el monto descontado del total
      decretado. Las filas de sg_dpag se conservan, para que la cuota siga
      mostrando que solicito y cuanto.

  Rechazo del MES         sg_fume.cod_estfum = 4
      DGDP descarta un mes puntual mientras el resto de la cuota sigue su
      curso.

  El estado del mes es el mismo en los dos casos; lo que cambia es el alcance.
  Para distinguirlos se mira la cuota: si su cod_estcuo es 10, el rechazo fue
  del encabezado. Decidido el 26-10-2026; antes el rechazo del encabezado
  devolvia los meses a 1 y liberaba cupo y saldo.

-------------------------------------------------------------------------------
TRANSICIONES
-------------------------------------------------------------------------------
   --  -> 1    sg_fumeuSecgen01 inserta el mes                   RESOLUCION
    1  -> 2    ENVIAR: se crea la cuota y su fila en sg_dpag     PAGOS
    2  -> 4    DGDP descarta el mes                              PAGOS
    2  -> 3    la cuota se envia a Finanzas                      PAGOS
    3  -> 2    Finanzas devuelve la cuota (sg_ecuo = 11)         PAGOS
    2  -> 4    la CUOTA es rechazada -> arrastra todos sus meses PAGOS
  1,4  -> X    la resolucion acorta el periodo -> DELETE fisico  RESOLUCION

  Mientras DGDP visa, observa o aprueba la cuota, el mes NO cambia: sigue en 2.
  Que DGDP lo haya revisado se lee en val_licmed is not null, no en el
  estado: la resolucion deja los val_* en NULL y sg_fumeuSecgen03 siempre
  los escribe 'S' o 'N'.

-------------------------------------------------------------------------------
COMO LOS LEE EL COMPARADOR (cupo del numeral 6)
-------------------------------------------------------------------------------
  consume cupo, reversible     cod_estfum = 2
  consume cupo, en Finanzas    cod_estfum = 3
  no consume cupo              cod_estfum in (1, 4)
  disponible para una cuota    cod_estfum = 1 y la ejecucion ya paso
                               ((ano_prop*100+mes_prop) < @mes_actual
                                or f_termino < getdate())

  Reemplaza el matching por texto del backend (includes('PAGO'),
  includes('REMUN')...), que hoy clasifica mal "Disponible pago" y "Aprobada".

-------------------------------------------------------------------------------
NOTAS DE IMPLEMENTACION
-------------------------------------------------------------------------------
  - Los valores 2, 3 y el retorno a 1 los escribe UNICAMENTE el PA que mueve
    el encabezado. El valor 4, el PA de validacion de DGDP, mes a mes.
    La aplicacion nunca escribe cod_estfum.
  - "Validado" no es estado: se lee de los val_*, y de todos modos las
    validaciones se recalculan en cada transicion. fec_valida NO sirve para
    eso: es la fecha de la ultima gestion del mes y la mueve tambien el
    cambio de monto del solicitante (sg_fumeuSecgen02).
  - "Ejecutado" no es estado: se lee de ano_ejec / mes_ejec.
  - "Disponible" no es estado: depende de la fecha actual.
  - Guarda de sg_fumeuSecgen01:
        cod_estfum not in (1, 4)
        -- el periodo solo se puede acortar si ningun mes esta tomado
===============================================================================
*/

USE secgen_db
GO

SET NOCOUNT ON
GO

INSERT INTO secgen_db.dbo.sg_efum (cod_estfum, des_estfum) VALUES (1, 'Propuesta')
GO
INSERT INTO secgen_db.dbo.sg_efum (cod_estfum, des_estfum) VALUES (2, 'Comprometida')
GO
INSERT INTO secgen_db.dbo.sg_efum (cod_estfum, des_estfum) VALUES (3, 'Enviada a pago')
GO
INSERT INTO secgen_db.dbo.sg_efum (cod_estfum, des_estfum) VALUES (4, 'Rechazada')
GO

SELECT cod_estfum, des_estfum
FROM secgen_db.dbo.sg_efum
ORDER BY cod_estfum
GO
