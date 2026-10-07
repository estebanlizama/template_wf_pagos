# Plan aplicado: bandeja de gestión DGDP para cuotas DU288

**Fecha:** 06-10-2026  
**Estado:** implementado en código y artefactos SQL; pendiente aplicar los SQL al ambiente.

## Objetivo

Exponer las cuotas enviadas a visación (`sg_epag.cod_estcuo = 2`) en una bandeja de Prestaciones y abrir su detalle para la gestión DGDP. El rol de revisión es independiente del Director DGDP del flujo de resoluciones y no usa `eta/apso`.

## Regla de acceso acordada

El RUT se obtiene de la sesión. Se deriva el perfil de permisos de revisión únicamente cuando existe contrato activo y una fila vigente en `sisper_db.dbo.sp_orde` con `cod_organi = 696` y `rut_person` igual al RUT autenticado. Puede haber varias asignaciones/personas bajo la organización; la comprobación siempre es para la persona que inició sesión. No se usa `cod_design = 696` ni se exige `sp_desg`. El permiso de bandeja es `provision-payment-read-waiting` y el de resolución es `provision-payment-approve`.

## Trabajo

1. **Backend y permisos:** exponer el permiso derivado en `/auth/user`; proteger endpoints nuevos de cola y detalle con ese permiso, y revalidar el criterio dentro de Sybase al leer.
2. **Datos:** crear PA de lectura acotados a estado 2 que entreguen datos de solicitud, funcionario, centro de costo, período, montos, meses vinculados y evidencia disponible; registrar SQL y TXT de certificación.
3. **Frontend:** agregar un acceso independiente en Prestaciones para quien tenga el permiso DGDP; listar cuotas en visación y navegar al detalle.
4. **Detalle y resoluciones:** mostrar funcionario, prestación, centro de costo, resolución, monto, meses, descuentos informados y cantidad de compensaciones; permitir aprobar, observar o rechazar. Observar/rechazar exigen motivo. El rechazo devuelve los meses a Propuesta y libera su relación para asociarlos a otra cuota. La observación no se persiste: el esquema vigente no tiene columnas para motivo, RUT revisor ni fecha, como indica el apartado de límites.
5. **Entrega:** mantener SQL/TXT de certificación, revisar contratos y documentación de rol; ejecutar compilación/tipado y no afirmar despliegue de Sybase.

## Criterios de aceptación

- Jefe de proyecto sin asignación `sp_orde` no ve la entrada DGDP ni puede llamar sus endpoints.
- Revisor DGDP válido no necesita ser Director DGDP ni tener una tarea `eta/apso`.
- Bandeja y detalle se filtran en servidor por estado 2 y la misma asignación vigente.
- Los permisos CRUD del solicitante permanecen independientes.
- Cambios a Sybase quedan entregados como artefactos certificables, sin afirmar ejecución en ambiente.
- Decisiones DGDP solo aceptan cuotas en estado 2 y se ejecutan transaccionalmente en Sybase.

## Límites de la primera entrega

Los estados y transiciones usados son los documentados: 3 Observada, 4 Aprobada y 10 Rechazada; se conserva el encabezado rechazado. La BDD vigente no define columnas para guardar motivo, RUT revisor o fecha, por lo que esta integración persiste solo el estado y no presenta la decisión como auditable. `datos_base/05_auditoria_revision_dgdp.sql` queda como propuesta opcional de extensión, fuera del despliegue compatible con el esquema actual. El binario asociado a `id_evidenc` continúa dependiendo de la integración documental MySQL pendiente; esta pantalla muestra el identificador disponible y no descarga el archivo. El privilegio CRUD queda en el perfil DGDP en la matriz; las rutas CRUD existentes siguen verificando además la relación de jefe de proyecto con el centro de costo.
