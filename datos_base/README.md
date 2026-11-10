# Datos base DU288: WF resolución y WF pagos

Esta carpeta es la carga única de los datos fijos que necesitan los dos flujos
de prestación de servicios DU288:
- perfiles y privilegios;
- catálogos de estados;
- acciones del historial;
- topes;
- plantilla de resolución;
- flujos, etapas y transiciones.

**Consolidada al 10-11-2026.** Reemplaza las dos cargas que existían por
separado: la de WF resolución (`certificacion_db_base_du288`) y la de WF pagos
(la que tenía esta carpeta hasta el 06-11). En cada tema se tomó la versión más
reciente y las decisiones registradas después de ella.

Cada `.sql` tiene un `.txt` idéntico; se ejecuta solo una de las dos
extensiones. No se crean ni se modifican tablas.

---

## 1. Orden de ejecución

| Orden | Script | Base | Tablas | Qué deja disponible |
| :-: | :--- | :--- | :--- | :--- |
| 1 | [01_roles_permisos_du288.sql](01_roles_permisos_du288.sql) | `sistema_db` | `bd_per1`, `bd_prvg`, `bd_pepr` | Perfiles DU288 6 a 32, privilegios PDS (65–71, 81, 83–87, 91) y su matriz. Incluye la fila **(18, 65)** |
| 2 | [02_catalogos_estados_du288.sql](02_catalogos_estados_du288.sql) | `secgen_db` | `sg_tsol`, `sg_tmod`, `sg_tpps`, `sg_esol`, `sg_eapr`, `sg_efun`, `sg_ersl`, `sg_tacc` | Tipo de solicitud 1 y modalidad 2. Tipo de monto 1 **Fijo** y 2 **Variable**. Estados de solicitud 1–11, de tarea 1–11, de funcionario 1–5 y de resolución. Acciones 1–15, 28 y 29 |
| 3 | [03_topes_cargo_du288.sql](03_topes_cargo_du288.sql) | `secgen_db` | `sg_toca` | Topes 2026 del cargo 3120 por unidad |
| 4 | [04_plantilla_resolucion_du288.sql](04_plantilla_resolucion_du288.sql) | `secgen_db` | `sg_plse`, `sg_plre`, `sg_plde` | Plantilla 7 de la resolución DU288, detalles 31–44 |
| 5 | [05_flujos_etapas_du288.sql](05_flujos_etapas_du288.sql) | `secgen_db` | `sg_tfls`, `sg_eta1` | Ocho flujos y sus 99 etapas |
| 6 | [06_transiciones_flujo_du288.sql](06_transiciones_flujo_du288.sql) | `secgen_db` | `sg_eta2` | Las 265 transiciones. **Va después del 5** |
| 7 | [07_sg_ecuo_estados_cuota.sql](07_sg_ecuo_estados_cuota.sql) | `secgen_db` | `sg_ecuo` | Estados de la cuota: 1, 2, 3, 4, 8, 10 y 11 |
| 8 | [08_sg_efum_estados_mes.sql](08_sg_efum_estados_mes.sql) | `secgen_db` | `sg_efum` | Estados del mes de ejecución: 1 a 4 |
| 9 | [09_sg_tacc_acciones_pago.sql](09_sg_tacc_acciones_pago.sql) | `secgen_db` | `sg_tacc` | Acciones DGDP de la cuota: 32, 33 y 34. **Va después del 2** |
| 10 | [10_roles_privilegios_pagos.sql](10_roles_privilegios_pagos.sql) | `sistema_db` | `bd_per1`, `bd_prvg`, `bd_pepr` | Perfil 33 `payment_validator`, privilegios 92–99 y 12 asociaciones con los perfiles 6 y 33. **Va después del 1**: exige que el perfil 6 exista |

**Cómo ejecutar:**
- Use una sesión sin transacción externa.
- Si un script reporta error, detenga la carga.

**Se pueden repetir:** ningún script borra filas ni cambia estructuras. Los
catálogos insertan las filas faltantes y actualizan las descripciones. Los
scripts de acciones y privilegios verifican los códigos antes de insertar.

**Codificación:** los scripts 01, 02, 04, 05 y 07 tienen textos con tildes en
UTF-8. Configure el cliente de Sybase en UTF-8 antes de cargarlos. Después,
verifique en la base alguna etiqueta con tilde, por ejemplo
«En revisión DGDP» de `sg_ecuo`.

### Nombres anteriores de los scripts de pagos

Los documentos fechados antes del 10-11 los citan con su nombre antiguo:

| Antes (hasta 06-11) | Ahora |
| :--- | :--- |
| `01_sg_ecuo.sql` | `07_sg_ecuo_estados_cuota.sql` |
| `02_sg_efum.sql` | `08_sg_efum_estados_mes.sql` |
| `05_sg_tacc_acciones_pago.sql` | `09_sg_tacc_acciones_pago.sql` |
| `04_roles_privilegios_pagos.sql` | `10_roles_privilegios_pagos.sql` |

El contenido de los cuatro es idéntico al de antes; solo cambió el nombre.

`05_auditoria_revision_dgdp.sql`, que nombran algunos documentos de octubre, no
existe ni forma parte de la carga.

---

## 2. Origen de cada script

| Script | Origen (copia exacta con fin de línea CRLF) | Fecha |
| :--- | :--- | :--- |
| 01 a 06 | `template-du09/cambios_pa_solicitud_wf/maestros/certificacion_db_base_du288/`. Es idéntico a `certificacion_03_09_2026/cargar_datos_base/` | 26-08-2026; el 02, 07-09-2026 |
| 07 a 10 | Esta misma carpeta, con los nombres anteriores | 06-11-2026 |

Las carpetas de WF resolución se conservan como historial. **La carga vigente es
esta carpeta.**

---

## 3. Decisiones aplicadas

| Tema | Qué se tomó | Por qué |
| :--- | :--- | :--- |
| **El perfil 18 firma la resolución** | Se agregó `(18, 65)` a la matriz del 01 | Decisión del 20-10-2026. Sin `provision-request-approve`, el Jefe de archivo Universitario recibe un 403 al firmar. Ver [403_archivo_universitario_privilegio_aprobar.md](../403_archivo_universitario_privilegio_aprobar.md). Es la única línea que cambia respecto de los orígenes |
| **Tipo de monto** | `sg_tpps`: 1 = **Fijo**, 2 = **Variable** (el `.sql` del 02) | El `.sql` del 07-09 ya incorpora `certificacion_next/datos_base/01_catalogo_tpps_fijo_variable`. El `.txt` del origen seguía con «Meses / Días» y quedó desactualizado; aquí se regeneró desde el `.sql` |
| **Acciones DGDP de la cuota** | 32, 33 y 34 | Coinciden con `history-action-type.constant.ts`. El diseño del 23-10 ([comentario_devolucion_dgdp_diseno.md](../comentario_devolucion_dgdp_diseno.md)) proponía 31 y 32, pero el 31 ya es «solicitud agrupada»; **esa propuesta queda reemplazada** |
| **Estados de la cuota y del mes** | Los acordados en WF pagos (§7) | La carga de resolución excluía `sg_ecuo` a propósito, porque pertenece a pagos |
| **Estados antiguos de `sg_ecuo` (5, 6, 7, 9 y 12)** | No se borran | Se conservan por historia. El listado de estados vigentes del flujo no los incluye |
| **Estado 12 «Agrupada» de la solicitud y acciones 30–31** | No se cargan | No pertenecen a DU288. Si ya existen en la base, se respetan |
| **Privilegio 72** | No se carga | En la base vigente es de otro módulo: incentivo a la productividad científica |

### Perfiles y privilegios de pagos (script 10)

| Perfil | Privilegios |
| :--- | :--- |
| 6 | `create`, `read`, `history-read` y `document-read` |
| 33 `payment_validator` | Los cuatro anteriores, más `read-waiting`, `approve`, `adjust` y `submit` |

El script no asigna el perfil a personas. La pertenencia del validador DGDP se
resuelve por vigencia en `sg_usacsSecgen01`.

### Privilegios del código que no se cargan, a propósito

Los guardianes DU288 consultan `bd_pepr` a través de `sg_usacsSecgen01`.
Todos los privilegios DU288 que se exigen de verdad están en el script 01 o en
el 10. Los de esta tabla no:

| Nombre | Por qué no se carga |
| :--- | :--- |
| `provision-payment-manage` | Se calcula en vivo para el responsable vigente de un centro de costo DU288 (`sg_cctosSecgen05`). No vive en `bd_prvg` |
| `provision-request-detail` | No es un privilegio: es el nombre de un módulo del store del frontend |
| `provision-request-update`, `-approve-history`, `-resolution-approve`, `-resolution-document-read`, `-resolution-document-approve`, `-resolution-document-load-firm`, `-resolution-document-mark`, `-group` | Son del mapa estático de roles del régimen anterior (`utils/permissions.ts`) y de las pantallas sin sufijo `-normative`. El flujo DU288 no los exige |

---

## 4. Antes de cargar

1. **Confirme en certificación que existan las tablas.**
   - Catálogos y permisos: las tablas de la columna «Tablas» del §1.
   - Antes de instalar los [PA del inventario](../cambios_pa/inventario_certificacion.md):
     - `sg_epag`, `sg_dpag`, `sg_com1`, `sg_fum2` y `sg_fuc2`;
     - el correlativo `corr_fume` y el estado `cod_estfum` en `sg_fume`, con el
       esquema vigente.

   Si falta alguna de las de pagos, los scripts 07 y 08 fallan. Todavía no hay
   un script que las cree (`00_ddl_pagos.sql`). Lo que debe cubrir está en
   [auditoria_validaciones_certificacion_2026_11_03.md](../auditoria_validaciones_certificacion_2026_11_03.md)
   §3.5. La adaptación de un esquema anterior y de sus filas históricas se
   gestiona con el equipo de base de datos.
2. **Revise los controles que esta carga no incluye:**
   - `sg_parm` (correlativos);
   - `sg_prm1` (año de proceso).
3. **Despliegue en la misma ventana:**
   - los PA de pagos del inventario, después de esta carga;
   - los PA compartidos con resolución;
   - el backend que los invoca.

---

## 5. Qué no contiene

- **Datos de personas.** No hay usuarios en `sg_uspe` ni asignación de perfiles.
  - El actor de cada etapa se resuelve por etapa y RUT en `sg_apso`.
  - El validador DGDP se resuelve por vigencia en `sg_usacsSecgen01`.
- **Datos transaccionales.** No hay solicitudes, funcionarios, meses, cuotas,
  historiales ni resoluciones.
- **Datos de otros sistemas.** Se gestionan con sus dueños:
  - marcas DU09 y saldos (`fin21_db`);
  - asistencia (`sisper_db`);
  - feriados (`ufro_db`).
- **Herramientas de soporte.** Están en [../soporte_certificacion/](../soporte_certificacion/)
  y no forman parte de la carga:
  - `06_marcas_du09_centro_costo.sql`: consulta de solo lectura.
  - `07_sg_ecuo_descripciones.sql`: corrige solo las etiquetas de `sg_ecuo` en
    una base que ya tiene cuotas.

---

## 6. Verificación después de cargar

Cada script muestra al final lo que dejó cargado. Además, puede ejecutar estas
consultas:

```sql
-- Perfil 18 con el privilegio de aprobar (decisión 20-10-2026)
select p.cod_perfil, v.nom_privil
  from sistema_db.dbo.bd_pepr p, sistema_db.dbo.bd_prvg v
 where p.cod_sistem = 'SG' and p.cod_modulo = 'SISSOLIC'
   and v.cod_sistem = p.cod_sistem and v.cod_modulo = p.cod_modulo
   and v.cod_privil = p.cod_privil
   and p.cod_perfil = 18 and p.cod_privil = 65

-- Tipo de monto
select cod_tpps, des_tpps from secgen_db.dbo.sg_tpps where cod_tpps in (1, 2)

-- Acciones del historial: resolución y pagos
select id_tipacc, des_accion from secgen_db.dbo.sg_tacc
 where id_tipacc between 1 and 15 or id_tipacc in (28, 29, 32, 33, 34)
 order by id_tipacc

-- Flujos, etapas y transiciones
select count(*) as flujos from secgen_db.dbo.sg_tfls
select count(*) as etapas from secgen_db.dbo.sg_eta1
select count(*) as transiciones from secgen_db.dbo.sg_eta2
```

---

## 7. Estados y acciones de pagos

| Código | Estado de la cuota (`sg_ecuo`) | Estado del mes (`sg_efum`) |
| :-: | :--- | :--- |
| 1 | Borrador | Propuesta |
| 2 | En revisión DGDP | Comprometida |
| 3 | Devuelta para corrección | Enviada a pago |
| 4 | Aprobada por DGDP | Rechazada |
| 8 | Enviada a remuneraciones | |
| 10 | Rechazada por DGDP | |
| 11 | Devuelta de Finanzas | |

| Código | Acción de DGDP (`sg_tacc`) |
| :-: | :--- |
| 32 | Devolver la cuota a corrección |
| 33 | Rechazar la cuota |
| 34 | Devolver una cuota aprobada a visación |

**Diferencias con lo que muestra la aplicación.** La aplicación muestra sus
textos según el código, así que no hay error funcional, pero las etiquetas no
siempre coinciden con las de la base:

- **Cuota.** Las pantallas de pagos muestran:
  - 1 «Propuesta»;
  - 2 «En visación»;
  - 3 «Devuelta»;
  - 10 «Rechazada».
- **Mes.** El historial de prestaciones habla del mes en masculino: «propuesto»,
  «comprometido», «enviado a pago», «rechazado».

El catálogo completo de textos por pantalla está en
[catalogo_pantallas/README.md](../../catalogo_pantallas/README.md) §5.
