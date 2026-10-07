# Detalle de revisión DGDP: qué se espera de esta vista

**Fecha:** 06-10-2026
**Alcance:** la pantalla que abre el revisor DGDP desde la bandeja, para una cuota de un funcionario.
**Fuentes contrastadas:** el diagrama de flujo entregado (bloque `VIS` y `CIE`), los cuatro mockups de `mockups_dgdp_pago/`, el prototipo `02_vista_dgdp_pago.html`, `requerimientos_wf/2_requerimientos_dgdp_pago.md` (PP02-F02 a F06), `requerimientos_wf/9_catastro_validaciones_y_saldos.md` (PAG-30 a 41 y 70 a 74), `decisiones_flujo_pago.md`, y las tarjetas de ClickUp de la lista **WF de Pago**.

Las validaciones, la asistencia y los descuentos se detallan aparte, en [detalle_dgdp_validaciones.md](./detalle_dgdp_validaciones.md).

---

## 1. Qué decide esta vista

La unidad de decisión es **una cuota de un funcionario**, no la solicitud completa. El diagrama lo confirma: `SOL` se titula "una cuota por FUNCIONARIO" y `B7 Decisión` cuelga de una sola cuota. PP02-F06 habla de resolver la solicitud cuando todos sus detalles tienen dictamen, pero en el modelo implementado ese agregado no existe: cada `sg_epag` vive por su cuenta.

Tres salidas, las tres ya soportadas por `sg_epaguSecgen03`:

| Decisión | Estado | Efecto en los meses |
| :--- | :--- | :--- |
| Aprobar | 4 Aprobada | ninguno todavía; el cierre es otro paso |
| Devolver | 3 Observada | **no** libera los meses, siguen comprometidos |
| Rechazar | 10 Rechazada | meses 2 → 1 y se borra `sg_dpag`, liberando el cupo |

---

## 2. Lo que pide el diagrama, bloque por bloque

| Nodo | Qué exige | Estado hoy |
| :--- | :--- | :--- |
| **B1** Abrir la cuota · escribe bitácora | registrar que DGDP abrió el expediente | ✗ no hay bitácora |
| **B2** Re-ejecutar validaciones por mes | volver a correr el panel normativo con datos frescos, por mes | ✗ la vista no valida nada |
| **V7** Marcas de auditoría del mes | `val_licmed`, `val_singoce`, `val_inabili`, `val_ciecc` | ◐ `sg_epagsSecgen04` ya los entrega; la tabla los descarta |
| **B3** Comparar con prestaciones previas | historial del funcionario en el año y alerta de concurrencia | ◐ existe `Du288StaffPreviousProvisionsModal` del lado solicitante |
| **B4** Revisar respaldo, parentesco y asistencia | visor del PDF, constancia de parentesco, marcaje biométrico como antecedente | ✗ solo se imprime "Documento #N" |
| **V8** Montos y descuentos | licencia → `mto_deslic`, sin goce → `mto_dessg`, proporcionalidad, acumulado mensual | ✗ ningún PA escribe esos campos |
| **B5** Aplicar descuento · escribe meses | editar el descuento de un mes | ✗ `sg_fumeuSecgen02` solo escribe `mto_apagar` |
| **B6** Excluir un mes no pagable → mes 4 Rechazado | sacar un mes de la cuota sin rechazarla entera | ✗ no existe |
| **B7** Decisión | aprobar / devolver / rechazar | ✓ implementado |
| **CIE C1–C3** | `mto_realpa` = pedido − descuentos, registrar petición, cuota → 8 y meses 2 → 3 | ✗ nada escribe 8 ni `cod_estfum = 3` |
| **DEV** Devuelta Finanzas → 11, meses 3 → 2 | DGDP la registra a mano | ✗ no existe |

Lo implementado cubre **B7 y nada más**. El resto del bloque `VIS` y todo `CIE` están por construir.

---

## 3. Lo que piden los mockups y el prototipo

`mockups_dgdp_pago/02_dgdp_detalle_revision.jpg` — expediente y dictamen:

- cabecera con N° de solicitud, badge de estado y las tres acciones de dictamen;
- antecedentes PDS y resolución exenta: N° de resolución, fecha, vigencia, jefe de proyecto, centro de costo;
- **saldo disponible del centro de costo** con barra de avance sobre el presupuesto;
- meses de ejecución autorizados contra ejecutados;
- **visor del PDF de justificación embebido**, no un identificador;
- monto solicitado editable con lápiz;
- lista de verificación del revisor: documentos completos, monto correcto, causal válida, justificación adjunta.

`04_dgdp_validaciones_topes_concurrencia.jpg` — motor normativo:

- semáforo de cuatro tarjetas: licencia médica SISPER, permisos sin goce, tope del 50 % mensual con la cifra usada sobre la disponible, vigencia y saldo del centro de costo;
- matriz de todas las PDS del funcionario en el año con **alerta de concurrencia** por fila.

`03_dgdp_control_biometrico_calendario.jpg` — jornada:

- ficha del funcionario con cargo, tipo de contrato y departamento;
- calendario mensual con turno regular contra tramos compensados de `sg_fuc2`;
- barra comprometido contra efectivamente compensado con el porcentaje de cumplimiento;
- historial de marcas de reloj control, como antecedente.

El prototipo `02_vista_dgdp_pago.html` agrega, sobre lo anterior: cuatro KPI de cabecera (total solicitado, habilitado para Finanzas, observado, rechazado), estamento y actividad contractual aprobada, renta bruta aprobada, ya pagado previamente, saldo pendiente de la PDS, tipo de cobro, monto base de la cuota, historial de cuotas de la PDS, y el dictamen con **observación obligatoria cuando es observado o rechazado**.

---

## 4. Lo que piden los requerimientos y el catastro

**PP02-F02** — encabezado e historial: cabecera de pago, PDS origen, resolución, solicitante o delegación, etapa, tiempo pendiente e historial completo. Los datos de origen son de **solo lectura** (coincide con PAG-72).

**PP02-F03** — por cada detalle: funcionario, cargo/estamento, actividad y modalidad; cuota y cobertura; monto aprobado PDS, solicitado, pagado y pendiente; licencias, inhabilidades, permisos, sin goce y otras restricciones; jornada/horario y compensación; evidencias, constancias y versiones; **resultados de cada regla con fuente, fecha y severidad**; decisiones anteriores sobre el mismo detalle.

**PP02-F04** — observar exige causal, comentario accionable y responsable de corrección.

**PP02-F05** — acciones mínimas: aprobar, aprobar con excepción formal, observar, rechazar este intento, bloquear cuota.

**Catastro, controles que esta vista debe mostrar:**

| ID | Control | Severidad | Fuente ya cableada |
| :--- | :--- | :--- | :--- |
| PAG-30 | Cargo o contrato habilitado a la fecha de pago | bloqueo | `sg_fupssSecgen14` |
| PAG-31 | Sin asignación inhabilitante en el periodo | bloqueo | `sg_fupssSecgen15` |
| PAG-32 | Constancia jurada de parentesco | bloqueo | `sg_fupssSecgen16` |
| PAG-33 | Sin licencia médica en el periodo | bloqueo | `sp_eaus` grupo 2 |
| PAG-34 | Sin permiso sin goce | bloqueo | `sp_eaus` grupo 1 código 2 |
| PAG-36 | Proyecto vigente y no cerrado | bloqueo | `sg_cctosSecgen06` |
| PAG-37 | Sin deuda institucional (desde 2027) | bloqueo diferido | — |
| PAG-38 | `sg_fuc2` cubre `sg_fuco` en los meses de la cuota | bloquea el envío | `sg_fucosSecgen01` + `sg_fuc2sSecgen01` |
| PAG-38c | Reglas horarias sobre los tramos | bloqueo | `sg_fuhosSecgen01` |
| PAG-39 | La actividad no es formación continua | bloqueo | contenido de la evidencia |
| PAG-40 | Ajuste proporcional por ausencias | advertencia con ajuste | — |
| PAG-41 | Cambio de cargo o contrato posterior a la resolución | por decidir | `sg_fupssSecgen12/13` |
| SAL-02 | Tope completo por cuota, sin descontar cuotas previas | bloqueo | `sg_fupssSecgen13` |
| PAG-70 | Historial: actor, perfil, acción, estado anterior y nuevo, fecha, observación | regla de sistema | — |
| PAG-74 | Ningún código sin entrada de catálogo se muestra como etiqueta | presentación | `sg_ecuo`, `sg_efum` |

`decisiones_flujo_pago.md` ya cerró que **las reglas normativas no se reescriben en SQL**: se reutilizan los PA de resolución. Los doce PA que esta vista necesita ya están declarados como query assets en `service-provision-request.ts`; falta exponerlos para el revisor DGDP.

---

## 5. Especificación propuesta de la vista

Siete secciones, en el orden en que se revisa. Entre paréntesis, de dónde sale el dato.

### 5.1 Cabecera del expediente

Solicitud, cuota "i de n", funcionario con RUT, estado con badge, antigüedad desde el envío, quién la envió y cuándo. Acciones de dictamen ancladas abajo, no aquí (§7 del estándar visual y lo ya corregido en el detalle del solicitante).
*(ya llega en `sg_epagsSecgen03`)*

### 5.2 Antecedentes de la PDS — solo lectura

Resolución exenta y año, vigencia, jefe de proyecto, centro de costo con unidad financiera y financiamiento, actividad, modalidad y periodo de ejecución de la prestación.
*(`sg_prsesSecgen01`, `sg_fupssSecgen01/02`, ya cableados)*

### 5.3 Saldo y tope

Saldo disponible del centro de costo con la barra del mockup; tope mensual aplicable y cuánto de él consume esta cuota; monto autorizado de la PDS, ya pagado, comprometido y pendiente.
*(`sg_cctosSecgen06` y `sg_fupssSecgen13`; el componente `Du288PaymentBudgetSection` ya existe y recibe `balance`)*

### 5.4 Panel normativo — el corazón de la vista

Una tarjeta por control con resultado, **fuente y fecha de evaluación**, y severidad, tal como pide PP02-F03 y muestra el mockup 04. Como mínimo los bloqueantes PAG-30 a 39 más SAL-02.
*(componente `Du288PaymentValidationsSection`, que ya recibe `tags`, `validatedAt` y `loading`)*

### 5.5 Meses de la cuota

Tabla por mes con: periodo propuesto, estado del mes, monto solicitado, **descuento por licencia y por sin goce editables**, monto resultante, las cuatro marcas de auditoría de V7, y la acción de excluir el mes.
*(`sg_epagsSecgen04` ya entrega todo salvo la edición; faltan los PA de escritura)*

### 5.6 Jornada y compensación

Solo si `sg_fups.dentro_jor` ∈ {S, D}. Comprometido contra informado con el porcentaje de cumplimiento, calendario del mes y, como **antecedente no bloqueante**, el marcaje biométrico — decisión cerrada el 30-09-2026.
*(`Du288ExecutedCompensationSection` ya tiene modo `readOnly`; `Du288CompensationCalendarModal` existe; la asistencia depende del PA `sp_as01sSecgen01`, aún en requerimiento)*

### 5.7 Respaldo y antecedentes del funcionario

Visor del PDF de justificación, no el identificador. Prestaciones previas del año con alerta de concurrencia. Historial de decisiones sobre esta cuota.
*(`Du288PaymentAntecedentsTab` ya recibe `documentBlobUrl`; `Du288StaffPreviousProvisionsModal` existe; el binario sigue bloqueado por la decisión 5 de `decisiones_flujo_pago.md`)*

### 5.8 Dictamen

Al final de la página, bajo las validaciones, igual que en el detalle del solicitante. Observación obligatoria para observar y rechazar, con error junto al campo y no solo botón deshabilitado. **Modal de confirmación** con el resumen de lo que se resuelve y a quién afecta: las tres decisiones son irreversibles desde la interfaz.

---

## 6. Qué falta para construirlo

**Reutilizable tal cual (frontend).** Siete componentes ya existen y varios soportan solo lectura: `Du288PaymentBudgetSection`, `Du288PaymentValidationsSection`, `Du288PaymentStaffSection`, `Du288PaymentScheduleSection`, `Du288PaymentMonthsSection`, `Du288ExecutedCompensationSection`, `Du288PaymentAntecedentsTab`. Hoy la pantalla DGDP no usa ninguno: es una `b-table` cruda. Rehacerla sobre esos componentes es la mayor parte del trabajo visual y no toca la base.

**Exponer al rol DGDP (backend, sin PA nuevos).** Los doce PA normativos y de antecedentes ya son query assets del repositorio de resolución. Falta un endpoint de contexto normativo para el revisor, con su propia guardia de permiso.

**PA nuevos (base de datos).**

| Necesidad | Nodo | PA propuesto |
| :--- | :--- | :--- |
| Detalle de una cuota por su clave, sin refiltrar la bandeja | B1 | `sg_epagsSecgen05` |
| Escribir descuentos del mes | V8 · B5 | `sg_fumeuSecgen03` |
| Excluir un mes de la cuota | B6 | `sg_dpagdSecgen01` o estado 4 del mes |
| Cierre: `mto_realpa`, cuota → 8, meses 2 → 3 | C1–C3 | `sg_epaguSecgen04` |
| Registrar devolución de Finanzas: cuota → 11, meses 3 → 2 | DEV | `sg_epaguSecgen05` |
| Persistir observación, RUT revisor y fecha | B7 · PAG-70 | `datos_base/05_auditoria_revision_dgdp.sql` |
| Bitácora de decisiones | PAG-70 | por definir |

**Ya conocido y sin cambios:** la observación no se guarda, y `Du288InstallmentsSection.vue:39` sigue pintando un `reviewObservation` que ningún PA produce.

---

## 7. Decisiones abiertas que condicionan el diseño

1. **¿DGDP edita montos?** El mockup muestra "Edit Amount" y un lápiz sobre el monto solicitado; `9_catastro...` §19.12 registra el conflicto: B07 propone que DGDP corrija, F07 y E09 dejan la edición en el solicitante. Si DGDP edita, cambia el modelo de segregación. **El diagrama toma partido:** DGDP aplica descuentos y excluye meses, pero no reescribe el monto pedido. Propongo seguir el diagrama y dejar el lápiz del mockup fuera.
2. **Q-N05 a Q-N08 del cuestionario maestro siguen sin responder** — justamente las cuatro preguntas sobre qué espera ver y qué puede hacer DGDP. El contenido de §5 es una propuesta derivada del diagrama y los mockups, no una respuesta ratificada.
3. **PP02-F05 pide "aprobar con excepción formal" y "bloquear cuota".** `sg_ecuo` no tiene estados para eso y el diagrama no los dibuja. Hay que decidir si se descartan o se agregan.
4. **Dónde vive el binario de la evidencia** (decisión 5). Sin eso el visor del PDF del mockup 02 no se puede construir y la revisión documental de B4 queda coja.
5. **¿Hace falta un estado "tomada por DGDP"?** (decisión 8). Hoy la bandeja es global y dos revisores pueden abrir la misma cuota; `sg_epaguSecgen03` protege con `holdlock`, así que el segundo pierde, pero recién al decidir.
6. **El acumulado mensual de V8** necesita una fuente: el tope del 50 % del mockup 04 se calcula contra la renta, pero el catastro no define de dónde sale el consumo mensual del funcionario entre varias PDS.

---

## 8. Orden de construcción sugerido

1. **PA de detalle por clave** (`sg_epagsSecgen05`) y rehacer la pantalla sobre los componentes existentes, con las secciones 5.1 a 5.3, 5.5 y 5.8. Sin tocar más base que ese PA.
2. **Panel normativo** (5.4): endpoint que reúne los PA de resolución y los pinta con fuente, fecha y severidad. Es lo que convierte la vista en una revisión y no en una lectura.
3. **Compensación y jornada** (5.6) en solo lectura, reutilizando lo del solicitante.
4. **Descuentos y exclusión de mes** (V8, B5, B6) con sus dos PA de escritura.
5. **Cierre y Finanzas** (C1–C3 y DEV) con sus dos PA.
6. **Respaldo documental y bitácora**, cuando se cierren las decisiones 4 y la de auditoría.

Los pasos 1 a 3 no dependen de ninguna decisión abierta. El 4 depende de la decisión 1 y de la fuente del acumulado mensual; el 5 y el 6, del resto.
