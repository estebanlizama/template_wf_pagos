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
          cod_tpps: 1,
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
