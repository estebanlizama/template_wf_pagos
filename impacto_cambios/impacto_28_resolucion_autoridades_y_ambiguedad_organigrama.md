# Impacto 28 — Resolución Dinámica de Autoridades y Manejo de Ambigüedad Orgánica (`sp_orco`)

> Alcance de la revisión 30-10-2026: diagnóstico histórico y propuestas, no constancia de saneamiento de datos maestros ni de selector de autoridades implementado. La elección manual descrita al final requiere una decisión funcional; no sustituye automáticamente la asignación configurada ni autoriza cambios en el catálogo institucional. El consolidado de pagos mantiene esta incidencia separada de la integración SISPER.

**Fecha:** 30-10-2026  
**Módulo:** Resoluciones y Workflow DU288 — Decretación y Cadena de Firmantes  
**Archivos impactados:**
- **Procedimientos Almacenados / Base de Datos:**
  - `sisper_db.Analisis2.sp_orcosSecgen01` (Resolución de cargos orgánicos y jefaturas)
  - `secgen_db.Analisis2.sg_etasSecgen01` (Motor de resolución de etapas y actores DU288)
  - `sisper_db.dbo.sp_orco` (Tabla de ocupantes de cargos)
- **Backend:**
  - `src/controllers/service-provision/service-provision-request-approval.controller.ts` (`GET .../resolution-signers-preview`)
  - `src/services/service-provision-workflow.service.ts` (`previewConfiguredDu288SignerChain`)
  - `src/repositories/storedProcedures/service-provision-request-procedures.repository.ts` (`resolveWorkflowStageAssignmentPreview`)
- **Frontend:**
  - `components/services-provision/resolution-format/DynamicResolutionSigners.vue`
  - `pages/services-provision/_id/resolution-format-normative.vue`

---

## 1. Diagnóstico del Estado `AMBIGUO` en Decretación

Al previsualizar los firmantes de una resolución exenta (ejemplo: solicitud 210), la tarjeta de decretación del Secretario General se marcaba en rojo con error bloqueante:

```
[1] SECRETARIO GENERAL - RESPONSABLE SIN NOMBRE DISPONIBLE
    La organizacion posee mas de un titular vigente.
```

### 1.1 Causa Raíz en `sisper_db.dbo.sp_orco`
En `sp_orcosSecgen01`, para resolver la autoridad de una organización (`@cod_organi`):

```sql
select @cantidad = count(distinct orco.rut_person)
from sisper_db.dbo.sp_orco orco
where orco.cod_organi = @cod_organi
  and orco.vigente = 'S'
  and upper(ltrim(rtrim(isnull(orco.ausente, 'N')))) <> 'S'
```

Al consultar la organización `73` (Secretaría General), se detectaron **dos registros simultáneos con `vigente = 'S'`**:

| `cod_contra` | `rut_person` | Funcionario | Tipo de Registro |
| :---: | :---: | :--- | :--- |
| **500013** | `000010103` | OSVALDO RODRIGUEZ SECGENERAL | Cuenta *mock* de testing institucional (`000010xxx`) |
| **178557** | `169506833` | JUAN CARLOS GUAJARDO PUGA | Titular real en SISPER |

Al haber `@cantidad = 2`, el procedimiento devuelve:
- `@estado = 'AMBIGUO'`
- `@mensaje = 'La organizacion posee mas de un titular vigente.'`
- `rut_responsable = NULL`
- `canProceed = false`

---

## 2. Análisis de Variables de Desempate en SISPER

Se inspeccionaron las tablas de personal (`sp_pers`), contratos (`sp_cont`) y organigrama (`sp_aufi`, `sg_uspe`):
- Los contratos `500013` y `178557` tienen idéntica fecha de inicio, cargo y decreto, confirmando que el registro `500013` fue un clon creado para poblar usuarios simulados.
- En el modelo oficial de la UFRO **no existe una columna secundaria de desempate**: la regla de negocio estipula que una organización nunca debe tener más de un titular activo con `vigente = 'S'`.

---

## 3. Soluciones y Recomendaciones

1. **Saneamiento Inmediato de Datos Maestros:**  
   En la base de datos de pruebas o producción, desactivar la vigencia del registro caduco o del usuario de pruebas:
   ```sql
   UPDATE sisper_db.dbo.sp_orco
   SET vigente = 'N'
   WHERE cod_organi = 73 AND rut_person = '000010103'
   ```
2. **Propuesta de Visor Informativo y Selector de Desempate en Frontend:**  
   - En lugar de mostrar un error ciego (*«sin nombre disponible»*), el backend puede retornar la lista de candidatos en conflicto.
   - En `DynamicResolutionSigners.vue`, si `resolutionStatus === 'AMBIGUO'`, habilitar un selector condicional que permita al usuario que decreta elegir cuál de los candidatos registrados firma la resolución, evitando bloqueos operativos mientras RRHH actualiza SISPER.
