/*
 * Datos de maqueta del Workflow de Pagos — DU288 / D.U. 009-2026
 *
 * Estructura calcada de los payloads reales del sistema:
 *   - expediente        = GET /requests/service-provision/{id}  (cabecera + provision + staffList)
 *   - expediente.resolucion  = datos de la resolución archivada
 *   - pagosPrevios      = cuotas ya registradas en sg_fume para ese funcionario
 *
 * Las claves conservan el nombre del backend para que la maqueta sea contrastable
 * campo a campo con la BDD. No inventar campos: lo que no existe se marca como null
 * y se muestra en pantalla como "pendiente de fuente".
 */

const DB_PAGOS = {

  // Usuario en sesión: en el flujo de pagos el solicitante es el JEFE DE PROYECTO
  usuarioSesion: {
    dni: "056024069",
    dniFormato: "5.602.406-9",
    nombre: "JEFE DE PROYECTO (titular del CC)",
    perfil: "Solicitante de pago / Jefe de proyecto",
  },

  // Bandeja del solicitante: solicitudes de pago que requieren su acción
  bandeja: [
    {
      tipo: "devuelta",
      folio: "PAG-2026-0031",
      funcionario: "JEANETTE DEL PILAR POZA ARAVENA",
      detalle: "DGDP solicitó corregir el periodo cubierto por la cuota.",
      fecha: "2026-08-28",
    },
    {
      tipo: "borrador",
      folio: null,
      funcionario: "JEANETTE DEL PILAR POZA ARAVENA",
      detalle: "Borrador sin enviar, sin evidencia adjunta.",
      fecha: "2026-09-01",
    },
  ],

  // Bandejas por rol. El flujo es Solicitante → DGDP → Finanzas (Q-E05), y
  // Finanzas puede devolver a DGDP por falta de fondos, no rechazar de plano
  // (Q-E11). Cada fila abre la vista del rol correspondiente.
  bandejas: {
    solicitante: {
      rol: "Solicitante · Jefe de proyecto",
      vista: "01_vista_solicitante_pago.html",
      accion: "Continuar",
      filas: [
        { folio: "PAG-2026-0031", funcionario: "JEANETTE DEL PILAR POZA ARAVENA", resolucion: "42/2026",
          cuota: "1 de 2", monto: 141111, estado: "Devuelta a corrección", tono: "warn",
          detalle: "DGDP solicitó corregir el periodo cubierto por la cuota.", fecha: "2026-08-28" },
        { folio: null, funcionario: "JEANETTE DEL PILAR POZA ARAVENA", resolucion: "42/2026",
          cuota: "1 de 2", monto: 141111, estado: "Borrador", tono: "secondary",
          detalle: "Sin enviar. Falta adjuntar el informe de actividades.", fecha: "2026-09-01" },
        { folio: "PAG-2026-0028", funcionario: "MARCO ANTONIO SEPULVEDA DIAZ", resolucion: "39/2026",
          cuota: "2 de 2", monto: 220000, estado: "En revisión DGDP", tono: "info",
          detalle: "Enviada el 26-08. Sin acción pendiente de su parte.", fecha: "2026-08-26" },
      ],
    },
    dgdp: {
      rol: "DGDP · Revisión normativa",
      vista: "02_vista_dgdp_pago.html",
      accion: "Revisar",
      filas: [
        { folio: "PAG-2026-0028", funcionario: "MARCO ANTONIO SEPULVEDA DIAZ", resolucion: "39/2026",
          cuota: "2 de 2", monto: 220000, estado: "Pendiente de revisión", tono: "warn",
          detalle: "Última cuota: exige ejecución terminada.", fecha: "2026-08-26" },
        { folio: "PAG-2026-0033", funcionario: "CAROLINA ANDREA MUÑOZ SOTO", resolucion: "51/2026",
          cuota: "1 de 2", monto: 98000, estado: "Pendiente de revisión", tono: "warn",
          detalle: "Cuota parcial con causal de licencia médica.", fecha: "2026-09-03" },
        { folio: "PAG-2026-0021", funcionario: "JORGE LUIS FUENTES ROJAS", resolucion: "33/2026",
          cuota: "1 de 1", monto: 310000, estado: "Devuelta por Finanzas", tono: "danger",
          detalle: "Finanzas devolvió por falta de saldo en el centro de costo.", fecha: "2026-09-04" },
      ],
    },
    finanzas: {
      rol: "Finanzas · Autorización y pago",
      vista: "03_vista_direccion_finanzas_pago.html",
      accion: "Autorizar",
      filas: [
        { folio: "PAG-2026-0019", funcionario: "PATRICIA ELENA GODOY LEIVA", resolucion: "28/2026",
          cuota: "2 de 2", monto: 180000, estado: "Aprobada por DGDP", tono: "info",
          detalle: "CC 1610-0 · ítem 306. Saldo suficiente.", fecha: "2026-09-05" },
        { folio: "PAG-2026-0022", funcionario: "RODRIGO ESTEBAN VERA CAMPOS", resolucion: "35/2026",
          cuota: "1 de 2", monto: 256250, estado: "Aprobada por DGDP", tono: "info",
          detalle: "CC 9010-5 · ítem 306. Verificar saldo antes de comprometer.", fecha: "2026-09-05" },
      ],
    },
  },

  expedientes: [
    {
      requestId: 205,
      applicantDni: "092867439",
      applicantName: "PAMELA DEL-PILAR IBARRA PALMA",
      applicantPosition: "Solicitante",
      resolutionId: 198,
      resolutionYear: 2026,
      resolutionExternalNumber: 42,
      currentStageCode: 130,
      currentStageName: "Jefe Archivo Universitario",
      requestStatusId: 11,
      requestStatus: "Resolución Archivada",
      requestTypeId: 1,
      requestDate: "2026-09-02T13:37:27.410Z",
      creationDate: "2026-09-02T13:37:27.410Z",
      modifiedDate: "2026-09-02T13:47:48.480Z",

      resolucion: {
        resolutionExternalNumber: 42,
        resolutionDate: "2026-09-02",
        sdgCode: "RHA1",
        resolutionId: 198,
        resolutionYear: 2026,
        resolutionDetailId: 903,
        SGD: "",
        views: "",
      },

      provision: {
        requestId: 205,
        // El dato viene con codificación dañada desde el origen ("OPERACI?N CODA").
        activity: "OPERACIÓN CODA, CLINICA UNIVERSITARIA DOCENTE",
        activityRaw: "OPERACI�“N CODA, CLINICA UNIVERSITARIA DOCENTE",
        periodFrom: "2026-09-02T04:00:00.0Z",
        periodTo: "2026-09-17T03:00:00.0Z",
        projectManagerDni: "056024069",
        costCenter1: 9010,
        costCenter2: 5,
        costCenterName: "ARRIENDO SALON AUDITORIUM",
        costCenter3: "AGRDEC001",
        costCenter4: "200506331976",
        idModprse: 2,
        workflowId: 1,
        workflowStageId: 130,
        workflowProfileId: 18,
        workflowStage: "Jefe Archivo Universitario",
        financingType: 21,
        financingTypeName: "Fondos Propios",
        executingUnitName: "DECANATO FACULTAD DE AGRONOMIA",
        decreeCode: "2",
        decreeDescription: "No Afecto",
        // Sin fuente en el payload actual: pendiente de definir (S0-013 D02)
        indAnid: null,
      },

      staffList: [
        {
          id: 1,
          name: "JEANETTE DEL PILAR POZA ARAVENA",
          hierarchy: "2",
          requestId: 205,
          staffDni: "087962717",
          staffDniFormato: "8.796.271-7",
          persistedPositionId: 4351,
          item1: "306",
          item2: "No Académico",
          budgetItemLabel: "306 No Académicos",
          reason: "OPERACIÓN CODA, CLINICA UNIVERSITARIA DOCENTE",
          periods: 1,
          monthAmmount: 141111,
          total: 141111,
          totalAmmount: 141111,
          grossTotal: 141111,
          codCoin: 1,
          // cod_tpps (catálogo sg_tpps) se usa como tipo de monto:
          //   1 = Fijo    → el total se reparte parejo entre los meses de
          //                 ejecución; el monto de cada mes viene comprometido
          //                 desde la resolución y no se ingresa en el pago.
          //   2 = Variable→ el monto real de cada mes se define en el pago;
          //                 la resolución solo reservó el techo.
          // (S0-013 Q-A06: "también hay pagos fijos y variables")
          cod_tpps: 1,
          // Cuotas declaradas en la resolución (sg_fups.tot_cuotas). Fija el
          // techo del bruto: tope × cuotas. El límite se cuenta POR CUOTA, no
          // por meses (Q-C01), y cada cuota dispone del tope completo (Q-C02).
          totCuotas: 2,
          f_inicio: "2026-09-02T04:00:00.0Z",
          f_termino: "2026-09-17T03:00:00.0Z",
          nomCargo: "ADMINISTRATIVOS",
          positionName: "ADMINISTRATIVOS 70",
          dentroJor: "S",
          persistedContractId: 21001,
          monthlyCap: 256250,
          capCalculatedAt: "2026-09-02T17:37:13.0Z",
          codEstfun: 1,
          principal: "1",
          codUnidad: "07050800",
          desUnidad: "DEPTO. DE ING. INDUSTRIAL Y DE SISTEMAS",
          codCargoContrato: 4351,
          codEstame: "3",
          desEstame: "ADMINISTRATIVO",
          codCalida: "03",
          desCalida: "PROPIEDAD",
          codJerpla: "41",
          desJerpla: "ADMINISTRATIVO",
          codNivGr: "70",
          desNivGr: "6",
          codJornad: "01",
          desJornad: "J/C",
          numHoras: 44,
          fInicioD: "2011-12-31T03:00:00.0Z",
          vigenCont: "0",
          desVigen: "Vigente",
          compensations: [
            { fecCompro: "2026-09-02", horaIni: "18:00", horaTer: "18:40" },
            { fecCompro: "2026-09-10", horaIni: "18:40", horaTer: "19:00" },
          ],
          schedules: [
            { dayOfWeek: 1, sequence: 1, startTime: "08:30", endTime: "09:00" },
          ],

          // ---- Estado de pago (sg_fume). Sin cuotas creadas todavía ----
          cuotas: [],
          maxCuotasAnio: 2,

          // ---- Datos sin fuente integrada: se muestran como pendientes ----
          compensacionAcreditada: null,   // fuente de marcaje / reloj (dependencia D8)
          licenciasPeriodo: null,         // fuente de licencias (dependencia D3)
          permisoSinGoce: null,
          deudaInstitucional: null,
        },
      ],
    },
  ],

  // Vista previa presupuestaria: respuesta esperada de valida_saldo_cc_cs
  saldoPresupuestario: {
    codUnifin: 9010,
    codCcto: 5,
    codSitm: "306",
    codTipmov: 21,
    afecta: "1",
    Estatus: 1,
    Mensaje: "OK",
    SaldoInicial: 2860000,
    Saldo: 2860000,
    fechaConsulta: "2026-09-02T14:05:00.0Z",
  },
};

// Compat con maquetas que esperan un nombre genérico
const DB_MOCK_PAGOS_DU288 = DB_PAGOS;
