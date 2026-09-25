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
  PAGOS        escribe los 4, incluido el 1 al liberar meses por rechazo.

-------------------------------------------------------------------------------
ESTADOS
-------------------------------------------------------------------------------
  1  Propuesta        HECHO. Lo escribe sg_fumeuSecgen01 al guardar la
                      resolucion. Es el unico estado que ese flujo asigna: el
                      mes se crea en 1 y, si el periodo se acorta, se borra
                      fisicamente. Tambien es el estado al que PAGOS devuelve
                      un mes cuando se rechaza su cuota.
                      Columnas con dato: ano_prop, mes_prop.

  2  Comprometida     HECHO. El mes esta dentro de una cuota enviada. Consume
                      cupo y saldo, pero todavia es reversible. Se mantiene
                      mientras DGDP visa, observa o aprueba: el avance del
                      tramite vive en sg_epag, no aca.
                      Columnas con dato: mto_apagar, id_evidenc, y --cuando
                      DGDP revisa-- val_licmed, val_inabili, val_singoce,
                      val_ciecc, fec_valida, rut_autori, fec_autori,
                      mto_deslic, mto_dessg.

  3  Enviada a pago   HECHO. Su cuota se subio a Finanzas. TERMINAL: consume
                      cupo de forma irreversible, sin acuse de vuelta.
                      Columnas con dato: fec_envrem, mto_realpa.

  4  Rechazada        DECISION. DGDP descarto ESTE mes: licencia, sin goce,
                      receso no acreditado o trabajo no acreditado. No se paga
                      y no se vuelve a ofrecer. La causal queda en los val_*.

-------------------------------------------------------------------------------
LOS DOS RECHAZOS SON DISTINTOS
-------------------------------------------------------------------------------
  Rechazo del ENCABEZADO  sg_epag.cod_estcuo = 10
      Cae la solicitud completa. Los meses NO quedan rechazados: vuelven a
      sg_efum = 1 y liberan cupo y saldo, para que el jefe de proyecto pueda
      rehacer la solicitud (S0-004: "libera cupo, saldo y meses").

  Rechazo del MES         sg_fume.cod_estfum = 4
      DGDP descarta un mes puntual mientras el resto de la cuota sigue su
      curso. Ese mes no vuelve a estar disponible.

-------------------------------------------------------------------------------
TRANSICIONES
-------------------------------------------------------------------------------
   --  -> 1    sg_fumeuSecgen01 inserta el mes                   RESOLUCION
    1  -> 2    ENVIAR: se crea la cuota y su fila en sg_dpag     PAGOS
    2  -> 4    DGDP descarta el mes                              PAGOS
    2  -> 3    la cuota se envia a Finanzas        TERMINAL      PAGOS
    2  -> 1    la CUOTA es rechazada -> libera el mes            PAGOS
  1,4  -> X    la resolucion acorta el periodo -> DELETE fisico  RESOLUCION

  Mientras DGDP visa, observa o aprueba la cuota, el mes NO cambia: sigue en 2.
  Que DGDP lo haya revisado se lee en fec_valida, no en el estado.

-------------------------------------------------------------------------------
COMO LOS LEE EL COMPARADOR (cupo del numeral 6)
-------------------------------------------------------------------------------
  consume cupo, reversible     cod_estfum = 2
  consume cupo, irreversible   cod_estfum = 3
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
  - "Validado" no es estado: se lee de fec_valida + los val_*, y de todos
    modos las validaciones se recalculan en cada transicion.
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
