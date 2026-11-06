# Inventario de procedimientos de pagos para certificacion

Se revisaron los 50 pares SQL/TXT. La tabla identifica la consulta registrada y
su invocacion en el codigo del backend. Son 48 procedimientos con consumidor
identificado y dos de administracion del catalogo sin invocacion encontrada.
La trazabilidad de codigo no confirma que los objetos esten instalados en el destino.

Aplicar el [orden de datos base](../datos_base/README.md). Instalar los 48 PA con
consumidor desde esta tabla, una vez cada uno: el TXT es la misma entrega que el SQL.
Los tres PA de SISPER conservan su base y se coordinan con su administrador. Los
originales de referencia de `../pa_externos_no_crear/` no forman parte de la instalacion.

| Procedimiento | Base | Consulta y consumidor |
| :-- | :-- | :-- |
| [sp_as01sSecgen01](asistencia/sp_as01sSecgen01.sql) | `secgen_db` | `selectStaffAttendance` — `service-provision-payment-procedures.repository.ts` |
| [sg_asdiSecgen01](pa_externos/sg_asdiSecgen01.sql) | `sisper_db` | `registerSisperAssignment` — `service-provision-payment-procedures.repository.ts` |
| [sg_ccaiSecgen01](pa_externos/sg_ccaiSecgen01.sql) | `sisper_db` | `registerSisperCostCenter` — `service-provision-payment-procedures.repository.ts` |
| [sg_resliSecgen01](pa_externos/sg_resliSecgen01.sql) | `sisper_db` | `registerSisperResolution` — `service-provision-request-approval.repository.ts`, `service-provision-payment-procedures.repository.ts` |
| [sg_cctosSecgen05](sg_ccto/sg_cctosSecgen05.sql) | `secgen_db` | `selectResponsibleCostCenterResume` — `enabled-cost-center.repository.ts` |
| [sg_com1sSecgen01](sg_com1/sg_com1sSecgen01.sql) | `secgen_db` | `selectDgdpInstallmentComments` — `service-provision-payment-procedures.repository.ts` |
| [sg_com1sSecgen02](sg_com1/sg_com1sSecgen02.sql) | `secgen_db` | `selectInstallmentComments` — `service-provision-payment-procedures.repository.ts` |
| [sg_ecuosSecgen01](sg_ecuo/sg_ecuosSecgen01.sql) | `secgen_db` | `selectInstallmentStatuses` — `service-provision-payment-procedures.repository.ts` |
| [sg_ecuosSecgen02](sg_ecuo/sg_ecuosSecgen02.sql) | `secgen_db` | `selectInstallmentStatusById` — `service-provision-payment-procedures.repository.ts` |
| [sg_efumiSecgen01](sg_efum/sg_efumiSecgen01.sql) | `secgen_db` | Administrativo. Sin invocacion en la aplicacion; fuera de la instalacion del flujo. |
| [sg_efumsSecgen01](sg_efum/sg_efumsSecgen01.sql) | `secgen_db` | `selectMonthStatuses` — `month-status.controller.ts` |
| [sg_efumsSecgen02](sg_efum/sg_efumsSecgen02.sql) | `secgen_db` | `selectMonthStatusById` — `month-status.controller.ts` |
| [sg_efumuSecgen01](sg_efum/sg_efumuSecgen01.sql) | `secgen_db` | Administrativo. Sin invocacion en la aplicacion; fuera de la instalacion del flujo. |
| [sg_epagdSecgen01](sg_epag/sg_epagdSecgen01.sql) | `secgen_db` | `deleteInstallment` — `service-provision-payment-procedures.repository.ts` |
| [sg_epagiSecgen01](sg_epag/sg_epagiSecgen01.sql) | `secgen_db` | `insertInstallment` — `service-provision-payment-procedures.repository.ts` |
| [sg_epagsSecgen01](sg_epag/sg_epagsSecgen01.sql) | `secgen_db` | `selectInstallments` — `service-provision-payment-procedures.repository.ts` |
| [sg_epagsSecgen02](sg_epag/sg_epagsSecgen02.sql) | `secgen_db` | `selectInstallmentMonths` — `service-provision-payment-procedures.repository.ts` |
| [sg_epagsSecgen03](sg_epag/sg_epagsSecgen03.sql) | `secgen_db` | `selectDgdpInstallments` — `service-provision-payment-procedures.repository.ts` |
| [sg_epagsSecgen04](sg_epag/sg_epagsSecgen04.sql) | `secgen_db` | `selectDgdpInstallmentMonths` — `service-provision-payment-procedures.repository.ts` |
| [sg_epagsSecgen05](sg_epag/sg_epagsSecgen05.sql) | `secgen_db` | `selectFinanceExcelRows` — `service-provision-payment-procedures.repository.ts` |
| [sg_epagsSecgen06](sg_epag/sg_epagsSecgen06.sql) | `secgen_db` | `selectSisperRegistrationStatus` — `service-provision-payment-procedures.repository.ts` |
| [sg_epaguSecgen01](sg_epag/sg_epaguSecgen01.sql) | `secgen_db` | `updateInstallment` — `service-provision-payment-procedures.repository.ts` |
| [sg_epaguSecgen02](sg_epag/sg_epaguSecgen02.sql) | `secgen_db` | `submitInstallment` — `service-provision-payment-procedures.repository.ts` |
| [sg_epaguSecgen03](sg_epag/sg_epaguSecgen03.sql) | `secgen_db` | `resolveDgdpInstallment` — `service-provision-payment-procedures.repository.ts` |
| [sg_epaguSecgen04](sg_epag/sg_epaguSecgen04.sql) | `secgen_db` | `markInstallmentSentToPayroll` — `service-provision-payment-procedures.repository.ts` |
| [sg_epaguSecgen05](sg_epag/sg_epaguSecgen05.sql) | `secgen_db` | `reopenApprovedDgdpInstallment` — `service-provision-payment-procedures.repository.ts` |
| [sg_fuc2dSecgen01](sg_fuc2/sg_fuc2dSecgen01.sql) | `secgen_db` | `deleteExecutedCompensations` — `service-provision-payment-procedures.repository.ts` |
| [sg_fuc2dSecgen02](sg_fuc2/sg_fuc2dSecgen02.sql) | `secgen_db` | `deleteDgdpExecutedCompensations` — `service-provision-payment-procedures.repository.ts` |
| [sg_fuc2iSecgen01](sg_fuc2/sg_fuc2iSecgen01.sql) | `secgen_db` | `insertExecutedCompensation` — `service-provision-payment-procedures.repository.ts` |
| [sg_fuc2iSecgen02](sg_fuc2/sg_fuc2iSecgen02.sql) | `secgen_db` | `insertDgdpExecutedCompensation` — `service-provision-payment-procedures.repository.ts` |
| [sg_fuc2sSecgen01](sg_fuc2/sg_fuc2sSecgen01.sql) | `secgen_db` | `selectExecutedCompensations` — `service-provision-payment-procedures.repository.ts` |
| [sg_fuc2sSecgen02](sg_fuc2/sg_fuc2sSecgen02.sql) | `secgen_db` | `selectDgdpExecutedCompensations` — `service-provision-payment-procedures.repository.ts` |
| [sg_fuc2sSecgen03](sg_fuc2/sg_fuc2sSecgen03.sql) | `secgen_db` | `selectOtherProvisionsCompensations` — `service-provision-payment-procedures.repository.ts` |
| [sg_fucosSecgen02](sg_fuco/sg_fucosSecgen02.sql) | `secgen_db` | `selectStaffPreviousProposedCompensations` — `service-provision-request-procedures.repository.ts` |
| [sg_fum2sSecgen01](sg_fume/sg_fum2sSecgen01.sql) | `secgen_db` | `selectMonthVersions` — `service-provision-payment-procedures.repository.ts` |
| [sg_fum2sSecgen02](sg_fume/sg_fum2sSecgen02.sql) | `secgen_db` | `selectDgdpMonthVersions` — `service-provision-payment-procedures.repository.ts` |
| [sg_fumesSecgen02](sg_fume/sg_fumesSecgen02.sql) | `secgen_db` | `selectProvisionMonths` — `service-provision-payment-procedures.repository.ts` |
| [sg_fumesSecgen03](sg_fume/sg_fumesSecgen03.sql) | `secgen_db` | `selectDgdpProvisionMonths` — `service-provision-payment-procedures.repository.ts` |
| [sg_fumeuSecgen01](sg_fume/sg_fumeuSecgen01.sql) | `secgen_db` | `updateStaffMonths` — `service-provision-request-procedures.repository.ts` |
| [sg_fumeuSecgen02](sg_fume/sg_fumeuSecgen02.sql) | `secgen_db` | `updateMonthAmount` — `service-provision-payment-procedures.repository.ts` |
| [sg_fumeuSecgen03](sg_fume/sg_fumeuSecgen03.sql) | `secgen_db` | `updateDgdpMonthDeductions` — `service-provision-payment-procedures.repository.ts` |
| [sg_fupssSecgen17](sg_fume/sg_fupssSecgen17.sql) | `secgen_db` | `selectStaffPreviousProvisions` — `service-provision-request-procedures.repository.ts` |
| [sg_fupsiSecgen01](sg_fups/sg_fupsiSecgen01.sql) | `secgen_db` | `insertStaff` — `service-provision-request-procedures.repository.ts` |
| [sg_fupssSecgen02](sg_fups/sg_fupssSecgen02.sql) | `secgen_db` | `selectStaffRequestId` — `service-provision-request-procedures.repository.ts` |
| [sg_fupssSecgen14](sg_fups/sg_fupssSecgen14.sql) | `secgen_db` | `getStaffNormativeDisablement` — `service-provision-request-procedures.repository.ts` |
| [sg_fupssSecgen15](sg_fups/sg_fupssSecgen15.sql) | `secgen_db` | `selectNormativeStaffAssignments` — `service-provision-request-procedures.repository.ts` |
| [sg_fupssSecgen18](sg_fups/sg_fupssSecgen18.sql) | `secgen_db` | `selectPayableProvisions` — `service-provision-payment-procedures.repository.ts` |
| [sg_fupssSecgen19](sg_fups/sg_fupssSecgen19.sql) | `secgen_db` | `selectStaffRejections` — `service-provision-request-procedures.repository.ts` |
| [sg_fupsuSecgen01](sg_fups/sg_fupsuSecgen01.sql) | `secgen_db` | `updateStaff` — `service-provision-request-procedures.repository.ts` |
| [sg_usacsSecgen01](sg_usacs/sg_usacsSecgen01.sql) | `secgen_db` | `selectServiceProvisionAccess` — `permissions.repository.ts` |

## Contratos conservados

- `sg_fupsiSecgen01` y `sg_fupsuSecgen01`: en error conservan `code` junto a
  `msg` porque el repositorio distingue conflictos de errores de validacion.
  Se quito el `status = 0`; el repositorio ya contempla su ausencia.
- `sg_resliSecgen01`: conserva `EXISTS` como resultado exitoso al encontrar
  una resolucion ya registrada; mantiene `OK` cuando inserta.
- `sg_fupssSecgen14`, `sg_fupssSecgen15` y `sg_epagsSecgen06`: conservan
  filas de lectura con columnas de validacion o conciliacion. No son mutaciones.
- `sp_as01sSecgen01` conserva el nombre institucional de asistencia que ya
  usa el backend. Los PA externos cuya creacion original no consta lo declaran
  en la cabecera; no se atribuyen autores ni fechas sin registro.
- `sg_fupssSecgen18`: ambas extensiones incluyen `cant_cuotas_devu` y el
  resumen de devoluciones de la version SQL vigente.
