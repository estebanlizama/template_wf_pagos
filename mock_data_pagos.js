// Banco de Datos Mock para el Flujo de Pagos (UFRO 2026)
// Alineado con el modelo normalizado de bdd_maestros.md y los requerimientos de la Fase 2
// Sincronizado con mock_data_d9.js (LIZAMA AILLAPAN, SOTO FIGUEROA, PEREZ SOTO)

const DB_MOCK_PAGOS = {
  // PDS Formalizadas y Firmadas (sg_prse)
  prestaciones: [
    {
      nro_solpds: "PDS-2026-0001",
      resolucion: "RE-001/2026",
      fecha_decretacion: "22 de Mayo de 2026",
      solicitante: "FRANCO VALDEBENITO",
      unidad_ejecutora: "FACULTAD DE INGENIERÍA",
      centro_costo: {
        codigo: "4050.21",
        nombre: "INSTITUTO DE AGROINDUSTRIA",
        unifin: "UNIFIN-AGRO",
        financiamiento: "21 - Fondos Propios",
        decreto_afecto: "0 - DU 288",
        proyecto: "Proyecto Agroindustria D9",
        saldo_cc: 15420000
      },
      jefe_proyecto: "DR. MARIO GODOY RIVERA",
      actividad_general: "Modernización de procesos para el Instituto de Agroindustria mediante la implementación de nuevos flujos de trabajo en entorno D9/2026, asegurando la trazabilidad.",
      monto_total: 1460000,
      total_pagado: 730000,
      saldo_pendiente: 730000,
      estado_doc_firmado: "Firmado y Vigente",
      du_decreto: "DECRETO UNIVERSITARIO N° 288/2026",
      
      // Items Presupuestarios por Cargo (sg_fups)
      items_presupuestarios: [
        { cargo: 'Académico', funcionario: 'LIZAMA AILLAPAN ESTEBAN NICOLAS', item: '30300 - Académicos', aprobado: 900000, solicitado: 450000, saldo_item: 3580000, estado: 'Disponible' },
        { cargo: 'Administrativo', funcionario: 'SOTO FIGUEROA MARÍA ELENA', item: '30600 - No Académicos', aprobado: 560000, solicitado: 280000, saldo_item: 800000, estado: 'Disponible' }
      ],
      
      // Evidencias cargadas/requeridas de la PDS por cuota/mes
      evidencias: [
        { id_fuev: 9001, id_funprse: 1001, id_funmes: 3001, cod_tievi: "EVID_PAGO", label: "Acta de Conformidad de la Jefatura (PDF)", obligatoria: true, loaded: true, file: "acta_lizama_junio.pdf", format: ".pdf", rut_carga: "12.345.678-9", f_carga: "01/06/2026" },
        { id_fuev: 9002, id_funprse: 1001, id_funmes: 3001, cod_tievi: "EVID_PAGO", label: "Informe Técnico de Actividades (PDF)", obligatoria: true, loaded: true, file: "informe_lizama_junio.pdf", format: ".pdf", rut_carga: "12.345.678-9", f_carga: "01/06/2026" },
        
        { id_fuev: 9003, id_funprse: 1001, id_funmes: 3002, cod_tievi: "EVID_PAGO", label: "Acta de Conformidad de la Jefatura (PDF)", obligatoria: true, loaded: false, file: null, format: ".pdf", rut_carga: null, f_carga: null },
        { id_fuev: 9004, id_funprse: 1001, id_funmes: 3002, cod_tievi: "EVID_PAGO", label: "Informe Técnico de Actividades (PDF)", obligatoria: true, loaded: false, file: null, format: ".pdf", rut_carga: null, f_carga: null },
        
        { id_fuev: 9005, id_funprse: 1002, id_funmes: 3003, cod_tievi: "EVID_PAGO", label: "Acta de Conformidad firmada (PDF)", obligatoria: true, loaded: true, file: "acta_soto_junio.pdf", format: ".pdf", rut_carga: "12.345.678-9", f_carga: "01/06/2026" },
        { id_fuev: 9006, id_funprse: 1002, id_funmes: 3003, cod_tievi: "EVID_PAGO", label: "Informe Técnico de Actividades (PDF)", obligatoria: true, loaded: true, file: "informe_soto_junio.pdf", format: ".pdf", rut_carga: "12.345.678-9", f_carga: "01/06/2026" },
        
        { id_fuev: 9007, id_funprse: 1002, id_funmes: 3004, cod_tievi: "EVID_PAGO", label: "Acta de Conformidad firmada (PDF)", obligatoria: true, loaded: false, file: null, format: ".pdf", rut_carga: null, f_carga: null },
        { id_fuev: 9008, id_funprse: 1002, id_funmes: 3004, cod_tievi: "EVID_PAGO", label: "Informe Técnico de Actividades (PDF)", obligatoria: true, loaded: false, file: null, format: ".pdf", rut_carga: null, f_carga: null }
      ],

      // Constancias especiales por mes
      constancias_requeridas: [
        { tipo_condicion: "CONST_LICENCIA", id_funmes: 3002, obligatoria: false, loaded: false, file: null }
      ],

      // Funcionarios asociados (sg_fups)
      funcionarios: [
        {
          id_funprse: 1001,
          rut: "15.890.342-K",
          nombre: "LIZAMA AILLAPAN ESTEBAN NICOLAS",
          unidad: "FACULTAD DE INGENIERÍA",
          contrato_pds: "Contrato Indefinido — Académico",
          monto_bruto_aprobado: 900000,
          total_pagado: 450000,
          monto_en_tramite: 0,
          saldo_pendiente: 450000,
          ind_retfun: "N",
          responsable_origen: "DR. MARIO GODOY RIVERA",
          responsable_delegado: "FRANCO VALDEBENITO",
          estamento: "Académico",
          cargo: "Titular | Grado 4 | Antigüedad: 12 años 3 meses",
          actividad: "Diseño de arquitectura de microservicios y validación de reglas de negocio para el proyecto D9.",
          tipo_prestacion: "Asistencia Técnica",
          modalidad: "Fuera de Jornada",
          sea: "No",
          compensacion_html: `<div class="alert alert-success p-1 mb-0" style="font-size: 0.6rem; border-radius: 4px; border-left: 2px solid var(--ufro-green) !important; margin-top: 5px;"><i class="fas fa-check-circle mr-1"></i> No requiere compensación (Académico fuera de jornada).</div>`,
          
          // Cuotas canónicas (sg_fume). Su momento de creación está pendiente de ratificación funcional.
          cuotas: [
            { 
              id_funcuo: 5001, 
              id_funmes: 3001, 
              nro_cuota: 1, 
              tot_cuotas: 2, 
              mes_ejecucion: 6, 
              anio_ejecucion: 2026, 
              mto_cuota: 450000, 
              cod_estcuo: "PAGADA",
              monto_pagado_previo: 450000,
              monto_en_tramite: 0,
              saldo_pendiente_funcionario: 0,
              monto_tope_mensual_aprobado_pds: 450000,
              ind_excepcion_tope_aprobada_pds: "N",
              licencia_medica_periodo: "N",
              permiso_sin_goce_periodo: "N",
              receso_universitario_periodo: "N",
              ausencias_periodo: 0,
              requiere_ajuste_proporcional: "N",
              monto_ajustado_proporcional: 0
            },
            { 
              id_funcuo: 5002, 
              id_funmes: 3002, 
              nro_cuota: 2, 
              tot_cuotas: 2, 
              mes_ejecucion: 7, 
              anio_ejecucion: 2026, 
              mto_cuota: 450000, 
              cod_estcuo: "DISPONIBLE",
              monto_pagado_previo: 0,
              monto_en_tramite: 0,
              saldo_pendiente_funcionario: 450000,
              monto_tope_mensual_aprobado_pds: 450000,
              ind_excepcion_tope_aprobada_pds: "N",
              licencia_medica_periodo: "S", // Activamos licencia médica en julio para probar constancias y alertas
              permiso_sin_goce_periodo: "N",
              receso_universitario_periodo: "N",
              ausencias_periodo: 0,
              requiere_ajuste_proporcional: "N",
              monto_ajustado_proporcional: 0
            }
          ],

          validaciones: {
            inhabilidad_cargo: true,
            deudas_pendientes: true,
            contrato_asociado: true,
            meses_asignados: true,
            monto_ok: true,
            jornada_sea: true,
            compensacion: true
          }
        },
        {
          id_funprse: 1002,
          rut: "16.452.891-2",
          nombre: "SOTO FIGUEROA MARÍA ELENA",
          unidad: "FACULTAD DE INGENIERÍA",
          contrato_pds: "Contrato Planta — Administrativo",
          monto_bruto_aprobado: 560000,
          total_pagado: 280000,
          monto_en_tramite: 0,
          saldo_pendiente: 280000,
          ind_retfun: "N",
          responsable_origen: "DR. MARIO GODOY RIVERA",
          responsable_delegado: "FRANCO VALDEBENITO",
          estamento: "Administrativo",
          cargo: "Administrativo Planta | Grado 16 | Antigüedad: 12 años",
          actividad: "Apoyo administrativo en la recopilación de actas, foliación de expedientes físicos y digitalización de documentos para el repositorio de procesos.",
          tipo_prestacion: "Asistencia Técnica",
          modalidad: "Fuera de Jornada",
          sea: "No",
          compensacion_html: `
            <div class="bg-light p-2 rounded border text-left" style="font-size: 0.65rem; margin-top: 5px;">
              <div class="font-weight-bold text-ufro-blue mb-1" style="font-size: 0.62rem;"><i class="fas fa-history mr-1"></i> Compensación Horaria:</div>
              <div class="row no-gutters text-dark">
                <div class="col-12"><strong>Sábado:</strong> 8 Hrs</div>
              </div>
            </div>`,
          
          cuotas: [
            { 
              id_funcuo: 5003, 
              id_funmes: 3003, 
              nro_cuota: 1, 
              tot_cuotas: 2, 
              mes_ejecucion: 6, 
              anio_ejecucion: 2026, 
              mto_cuota: 280000, 
              cod_estcuo: "PAGADA",
              monto_pagado_previo: 280000,
              monto_en_tramite: 0,
              saldo_pendiente_funcionario: 0,
              monto_tope_mensual_aprobado_pds: 280000,
              ind_excepcion_tope_aprobada_pds: "N",
              licencia_medica_periodo: "N",
              permiso_sin_goce_periodo: "N",
              receso_universitario_periodo: "N",
              ausencias_periodo: 0,
              requiere_ajuste_proporcional: "N",
              monto_ajustado_proporcional: 0
            },
            { 
              id_funcuo: 5004, 
              id_funmes: 3004, 
              nro_cuota: 2, 
              tot_cuotas: 2, 
              mes_ejecucion: 7, 
              anio_ejecucion: 2026, 
              mto_cuota: 280000, 
              cod_estcuo: "DISPONIBLE",
              monto_pagado_previo: 0,
              monto_en_tramite: 0,
              saldo_pendiente_funcionario: 280000,
              monto_tope_mensual_aprobado_pds: 280000,
              ind_excepcion_tope_aprobada_pds: "N",
              licencia_medica_periodo: "N",
              permiso_sin_goce_periodo: "N",
              receso_universitario_periodo: "N",
              ausencias_periodo: 0,
              requiere_ajuste_proporcional: "N",
              monto_ajustado_proporcional: 0
            }
          ],

          validaciones: {
            inhabilidad_cargo: true,
            deudas_pendientes: true,
            contrato_asociado: true,
            meses_asignados: true,
            monto_ok: true,
            jornada_sea: true,
            compensacion: true
          }
        }
      ]
    }
  ],
  // Solicitudes de Pago en Trámite (sg_soli, sg_paso)
  solicitudes_pago: [
        {
          nro_solpag: "SP-2026-39402",
          nro_solpds: "PDS-2026-0001",
          resolucion: "RE-001/2026",
          cod_estsol: "EN_TRAMITE",
          detalles: [
            {
              id_pagdet: 7001,
              id_funcuo: 5002,
              id_funmes: 3002,
              id_funprse: 1001,
              rut: "15.890.342-K",
              nombre: "LIZAMA AILLAPAN ESTEBAN NICOLAS",
              estamento: "Académico",
              cargo: "Titular | Grado 4",
              actividad: "Diseño de arquitectura de microservicios y validación de reglas de negocio para el proyecto D9.",
              sea: "No",
              compensacion: "No requiere compensación (fuera de jornada)",
              monto_bruto_aprobado: 900000,
              nro_cuota: 2,
              tot_cuotas: 2,
              mes_ejecucion: 7,
              anio_ejecucion: 2026,
              nro_mespag: 7,
              anio_pag: 2026,
              mto_cuota: 450000,
              mto_solpag: 450000,
              mto_autpag: null,
              total_pagado_previo: 450000,
              saldo_pendiente_pds: 450000,
              cod_estcuo: "EN_TRAMITE",
              cod_estdet: "EN_PROCESO",
              receso: false,
              prorrateo: false,
              comentario_excep: "",
              nro_transac: null,
              f_pago: null,
              evidencias: [
                { id_fuev: 9003, label: 'Acta de Conformidad de la Jefatura (PDF)', file: 'acta_conformidad_lizama.pdf', loaded: true, size: '1.2 MB', rut_carga: '12.345.678-9', f_carga: '01/06/2026 09:15', cod_estevi: 'CARGADA' },
                { id_fuev: 9004, label: 'Informe Técnico Mensual de Actividades (PDF)', file: 'informe_tecnico_mensual_lizama.pdf', loaded: true, size: '4.8 MB', rut_carga: '12.345.678-9', f_carga: '01/06/2026 09:18', cod_estevi: 'CARGADA' }
              ],
              validaciones: [
                { label: 'Licencia Médica Activa', badge: 'Cero Licencias', status: 'success' },
                { label: 'Permiso sin Goce de Sueldo', badge: 'Sin Suspensiones', status: 'success' },
                { label: 'Vigencia Proyecto y CC', badge: 'Vigente Dic-2026', status: 'success' },
                { label: 'Morosidad Centralizada', badge: 'Sin Deudas', status: 'success' }
              ],
              sg_obre: []
            },
            {
              id_pagdet: 7002,
              id_funcuo: 5004,
              id_funmes: 3004,
              id_funprse: 1002,
              rut: "16.452.891-2",
              nombre: "SOTO FIGUEROA MARÍA ELENA",
              estamento: "Administrativo",
              cargo: "Secretaria Ejecutiva | Grado 14",
              actividad: "Apoyo administrativo al proyecto, gestión documental y coordinación de actividades del equipo.",
              sea: "No",
              compensacion: "No requiere compensación (fuera de jornada)",
              monto_bruto_aprobado: 560000,
              nro_cuota: 2,
              tot_cuotas: 2,
              mes_ejecucion: 7,
              anio_ejecucion: 2026,
              nro_mespag: 7,
              anio_pag: 2026,
              mto_cuota: 280000,
              mto_solpag: 280000,
              mto_autpag: null,
              total_pagado_previo: 280000,
              saldo_pendiente_pds: 280000,
              cod_estcuo: "EN_TRAMITE",
              cod_estdet: "EN_PROCESO",
              receso: false,
              prorrateo: false,
              comentario_excep: "",
              nro_transac: null,
              f_pago: null,
              evidencias: [
                { id_fuev: 9005, label: 'Acta de Conformidad firmada (PDF)', file: 'acta_conformidad_soto.pdf', loaded: true, size: '980 KB', rut_carga: '12.345.678-9', f_carga: '01/06/2026 09:25', cod_estevi: 'CARGADA' },
                { id_fuev: 9006, label: 'Informe Técnico de Actividades (PDF)', file: 'informe_tecnico_soto.pdf', loaded: true, size: '2.5 MB', rut_carga: '12.345.678-9', f_carga: '01/06/2026 09:27', cod_estevi: 'CARGADA' }
              ],
              validaciones: [
                { label: 'Licencia Médica Activa', badge: 'Cero Licencias', status: 'success' },
                { label: 'Permiso sin Goce de Sueldo', badge: 'Sin Suspensiones', status: 'success' },
                { label: 'Vigencia Proyecto y CC', badge: 'Vigente Dic-2026', status: 'success' },
                { label: 'Morosidad Centralizada', badge: 'Sin Deudas', status: 'success' }
              ],
              sg_obre: []
            }
          ]
        },
        {
          nro_solpag: "SP-2026-MOCK-PARCIAL",
          nro_solpds: "PDS-2026-0001",
          resolucion: "RE-001/2026",
          cod_estsol: "APROBADO_DGDP",
          detalles: [
            {
              id_pagdet: 7004,
              id_funcuo: 5002,
              id_funmes: 3002,
              id_funprse: 1001,
              rut: "15.890.342-K",
              nombre: "LIZAMA AILLAPAN ESTEBAN NICOLAS",
              estamento: "Académico",
              cargo: "Titular | Grado 4",
              actividad: "Diseño de arquitectura de microservicios y validación de reglas de negocio para el proyecto D9.",
              sea: "No",
              compensacion: "No requiere compensación (fuera de jornada)",
              monto_bruto_aprobado: 900000,
              nro_cuota: 2,
              tot_cuotas: 2,
              mes_ejecucion: 7,
              anio_ejecucion: 2026,
              nro_mespag: 7,
              anio_pag: 2026,
              mto_cuota: 450000,
              mto_solpag: 450000,
              mto_autpag: 450000,
              total_pagado_previo: 0,
              saldo_pendiente_pds: 450000,
              cod_estcuo: "APROBADO_DGDP",
              cod_estdet: "APROBADO_DGDP",
              receso: false,
              prorrateo: false,
              comentario_excep: "",
              nro_transac: null,
              f_pago: null,
              evidencias: [
                { id_fuev: 9007, label: 'Acta de Conformidad de la Jefatura (PDF)', file: 'acta_conformidad_lizama.pdf', loaded: true, size: '1.2 MB', rut_carga: '12.345.678-9', f_carga: '01/06/2026 09:15', cod_estevi: 'APROBADA_DGDP' }
              ],
              validaciones: [],
              sg_obre: [
                { cod_estdet: 'APROBADO', comentario: 'Documentación completa. Cumple normativa D9/2026.', rut_usua: 'MARCELA.MORALES', f_registro: '03/06/2026 10:45' }
              ]
            },
            {
              id_pagdet: 7005,
              id_funmes: 3004,
              id_funprse: 1002,
              rut: "16.452.891-2",
              nombre: "SOTO FIGUEROA MARÍA ELENA",
              estamento: "Administrativo",
              cargo: "Secretaria Ejecutiva | Grado 14",
              actividad: "Apoyo administrativo al proyecto, gestión documental y coordinación de actividades del equipo.",
              sea: "No",
              compensacion: "No requiere compensación (fuera de jornada)",
              monto_bruto_aprobado: 560000,
              nro_cuota: 2,
              tot_cuotas: 2,
              mes_ejecucion: 7,
              anio_ejecucion: 2026,
              nro_mespag: 7,
              anio_pag: 2026,
              mto_cuota: 280000,
              mto_solpag: 280000,
              mto_autpag: 280000,
              total_pagado_previo: 0,
              saldo_pendiente_pds: 280000,
              cod_estcuo: "APROBADO_DGDP",
              cod_estdet: "APROBADO_DGDP",
              receso: false,
              prorrateo: false,
              comentario_excep: "",
              nro_transac: null,
              f_pago: null,
              evidencias: [
                { id_fuev: 9008, label: 'Acta de Conformidad firmada (PDF)', file: 'acta_conformidad_soto.pdf', loaded: true, size: '980 KB', rut_carga: '12.345.678-9', f_carga: '01/06/2026 09:25', cod_estevi: 'APROBADA_DGDP' }
              ],
              validaciones: [],
              sg_obre: [
                { cod_estdet: 'APROBADO', comentario: 'Documentación en regla.', rut_usua: 'MARCELA.MORALES', f_registro: '03/06/2026 10:48' }
              ]
            }
          ]
        }
      ]
};

// Cargar y guardar estado local simulado
const getLocalDB = () => {
  const saved = localStorage.getItem("DB_MOCK_PAGOS_STATE");
  if (saved) {
    try {
      return JSON.parse(saved);
    } catch(e) {
      console.error("Error parsing saved DB_MOCK_PAGOS_STATE", e);
    }
  }
  return DB_MOCK_PAGOS;
};

const saveLocalDB = (db) => {
  localStorage.setItem("DB_MOCK_PAGOS_STATE", JSON.stringify(db));
};
