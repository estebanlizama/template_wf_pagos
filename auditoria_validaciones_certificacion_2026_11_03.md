# Auditoría de validaciones y desarrollo — WF pagos y WF resolución

**Fecha:** 03-11-2026 · **Revisión 3:** misma fecha. La 2 integró los comentarios del usuario; la 3 suma el contexto de certificación, el DDL de pagos, el registro del login simulado y los TODO del PDS (§11).
**Objetivo:** determinar, antes del pase a certificación, si las validaciones —el
núcleo de la aplicación— se cumplen y están bien aplicadas en los dos flujos;
qué falta, qué sobra y qué datos lo condicionan; y si el desarrollo sigue los
estándares esperados.
**Tipo:** auditoría de solo lectura. No se modificó código, PA ni datos.

**Principio rector de esta revisión** (comentario del usuario):

> No romper el sistema. Un cambio sobre una validación que hoy funciona —por
> ejemplo, reemplazar una variable por otra más amplia— exige plena confianza
> y un análisis de que el cambio ayuda. Por eso cada cambio propuesto lleva su
> **riesgo de romper** y su **confianza** (§8).

**Vara de medida** (en este orden de autoridad):

1. `requerimientos_wf/8_matriz_validaciones_resolucion_a_pago.md` — matriz oficial.
2. `impacto_cambios/impacto_19_estado_validaciones_pago.md` §9–§15 — decisiones
   del 14-10-2026 y la lista final de 9 validaciones de pago (§11.7).
3. `impacto_cambios/impacto_30` (corte 30-10) e `impacto_31` (02-11).
4. `checklist_validaciones_y_paso_a_certificacion.md` e `INTERRUPTOR-DU09.md`.
5. `template-du09/.../contexto_reglas_cambios_agregados/06`, `07`, `09`.
6. Skill `ufro-typescript-fullstack` y `estandar_visual_obligatorio_du288.md`.
7. Para base de datos: **lo último desarrollado** es lo que se aplica (decisión
   del usuario), aunque un documento anterior diga otra cosa.

---

## 0. Registro de decisiones del usuario

| Hallazgo | Comentario del usuario | Efecto en el plan |
|:-:|:--|:--|
| 2 · 3 | Todo lo que falsea el login para probar desde `.env` se elimina al pasar a producción, en front y back. Analizar a detalle `/sg-solicitudes/access`. `DISABLE_AUTH` es configuración de prueba y no se usa en certificación. | Nueva §1: inventario completo de trampas de prueba con el retiro de punta a punta. El login simulado se trata como una sola trampa de dos capas (T1–T4). |
| 4 · 5 | Los PA de `sissolic-procedimientos/` los actualiza el usuario a mano; se trabaja solo con `cambios_pa/` y el otro repo no se toca. | **Fuera de alcance.** Quedan como nota informativa para el paquete manual (§7). |
| 6 | Se debe activar. | **Analizado y reclasificado:** activarlo como bloqueo rompe el pago de cuotas devengadas (§5.1). Se propone visibilidad en vez de bloqueo. |
| 7 | Identificar cuáles validaciones faltan. | §4: son **cinco**, no cuatro. Corregido y listado. |
| 8 | Ajustamos. | Aprobado (§9, A3). |
| 9 | ¿Qué se recomienda? | Recomendación en §6.1. |
| 10 | Quitar esos logs para no imprimir datos críticos. | Aprobado (§9, A4). |
| 11 | Está bien: el Excel guarda lo mismo que muestra la tabla según estándares y filtros. | **Cerrado por decisión.** No es hallazgo. |
| 12 | No aplica si no hay claridad; considerar pagos desfasados; verificar si el documento es antiguo. | **Verificado contra el código actual** (no es documento antiguo); queda como decisión funcional sin aplicar (§5.2). |
| §1.1 | Identificar a detalle las validaciones y variables trampa que cambian el flujo para pasar sin verificación, en PA, back y front, con el cambio de punta a punta. | §1 completa. |
| §1.3 | En base de datos se aplica lo último desarrollado, para estados y tablas estructurales y base. | §3 reescrita con la versión vigente de cada script y el orden corregido. |
| §1.5 | No romper lo que funciona; plena confianza en cada cambio. | Principio rector y §8. |
| DDL | `00_ddl_pagos.sql` no existe. Certificación tiene lo construido con `template-du09/cambios_pa_solicitud_wf` (ya antiguo, subido como versión previa de resolución). Lo de pagos se trabajó con `template_wf_pagos/cambios_pa`, que es lo más actualizado y lo que se debe implementar. Certificación = resolución + pagos. | El DDL **no se recupera: se escribe**. §3.5 lista lo que debe cubrir. Se resuelve B3: certificación no tiene datos de pago, así que corresponde `01`. |
| Login | El login simulado del backend no debe existir; dejar todo registrado en un md para reimplementarlo si hace falta. | Registrado en `nuevo_workflow_fase_2/login_simulado_desarrollo.md`, anclado a los commits actuales. Se resuelve B8: en desarrollo local se entra con credenciales reales de la Intranet. |
| TODO | Revisar los TODO del PDS en los dos flujos y sumarlos al plan. | Nueva §11. |

---

## 1. Resumen ejecutivo

### 🔴 Bloquean la certificación

| # | Hallazgo | Dónde |
|:-:|:--|:--|
| 1 | **La aprobación DGDP no tiene compuerta normativa.** El endpoint de decisión solo verifica el permiso, y `sg_epaguSecgen03` solo actor, estado 2 y motivo. Una llamada directa aprueba una cuota sin saldo, con el centro de costo cerrado o sin tope. | `service-provision-payment.controller.ts:206-236` · `sg_epaguSecgen03.sql` |
| 2 | **Login simulado de punta a punta** (T1–T4): un usuario elige a quién suplantar en `/access` y el backend acepta cualquier base64 como RUT. Con `NODE_ENV` distinto de `production` en certificación, cualquiera entra como cualquiera. El `dist/` local, además, ya contiene 40 RUT del catálogo de simulación. | §2 |
| 3 | **No existe DDL de pagos y hay que escribirlo.** El README de `datos_base` declara un `00_ddl_pagos.sql` que nunca se guardó. Certificación solo tiene el esquema del paquete antiguo de resolución, de modo que `sg_efum`, `sg_epag`, `sg_dpag`, `sg_com1` y las columnas nuevas de `sg_fume`, `sg_fum2` y `sg_fuc2` no existen allí. Sin ellas no se instala ningún PA de pagos. | §3.5 |
| 4 | **Certificación tiene la versión antigua de dos PA de resolución.** Resolución se subió desde `template-du09/cambios_pa_solicitud_wf`, con `sg_fumeuSecgen01` y `sg_fupssSecgen17` sobre `cod_estcuo`. El backend actual ya envía `@cod_estfum`, y la versión que lo acepta solo existe en `template_wf_pagos/cambios_pa/sg_fume/`. Si el backend nuevo llega antes que esos PA, o sin ellos, falla el **guardado de cualquier solicitud DU288**. | §3.3 |

### 🟠 Corregir antes de producción

| # | Hallazgo |
|:-:|:--|
| 5 | Cinco de las nueve validaciones de pago acordadas el 14-10 siguen sin implementar (§4). |
| 6 | El rechazo del envío (422) llega como toast que se desvanece (`_nroSolici/index.vue:972`). **Aprobado ajustar.** |
| 7 | 37 mensajes de error devuelven el RUT en claro (§6.1). |
| 8 | Dos `console.log` imprimen el RUT y los datos del usuario en el camino de autenticación (`user-permissions.repository.ts:302`, `:310`). **Aprobado quitar.** |
| 9 | `@nuxtjs/dotenv` inyecta **todas** las variables del `.env` del frontend en el bundle (§2, T4). Hoy solo hay URLs y los catálogos de simulación; un secreto agregado ahí mañana llegaría al navegador. |

### 🟡 Decisiones o mejoras sin urgencia

| # | Hallazgo |
|:-:|:--|
| 10 | Revalidación de cargo y asignaciones omitida cuando el contrato ya no está vigente: **es una decisión documentada**, no un error; falta hacerla visible (§5.1). |
| 11 | Cupo anual: el backend de resolución cuenta todas las prestaciones del funcionario; el frontend, solo las del mismo centro de costo (§5.2). Decisión funcional, no se aplica. |
| 12 | Estándares de desarrollo: `any`, tamaño de archivos, reglas en el controlador (§6). |

### Cerrados o fuera de alcance

| Ítem | Estado |
|:--|:--|
| Excel de Finanzas | Cerrado por decisión del usuario: exporta lo mismo que muestra la tabla. |
| `sg_usacsSecgen01` del repo de release sin el rol revisor de pagos | Fuera de alcance: actualización manual del usuario. Nota en §7. |
| 37 PA que solo están en `cambios_pa/` | Fuera de alcance: ídem. |
| Carpeta huérfana `d:\trabajo_ufro_2026\components` | Ya no existe. |

### Lo que sí está bien

- Backend: `npm run build` limpio y **288 pruebas unitarias en verde, 0 fallando**.
- Frontend: 23 archivos de prueba en verde, estándar visual validado en 55 archivos, ESLint limpio en todo `services-provision`, stores y utils DU288.
- Ninguna vista de `services-provision` llama HTTP directo; los archivos de pagos tienen 0 usos de `any`.
- Los PA de cuota rechazan bien lo estructural: CC cerrado, mes repetido, mes ya asignado, cuota final anticipada, evidencia, saldo autorizado, máximo de cuotas.
- Resolución revalida en servidor al guardar: período, contrato, monto autorizado, inhabilidad, asignaciones y carga horaria.

---

## 2. Trampas de prueba: inventario completo y retiro de punta a punta

Se buscó en front, back y PA toda marca que cambie el flujo para probar sin
verificación (`INTERRUPTOR`, *prueba*, *temporal*, *simulación*,
`DISABLE_AUTH`, `TEST_RUT` y similares). Aparecieron **once**; el catastro
entregado conocía siete.

### 2.1 Cómo funciona hoy el login, real y simulado

```
Real:      Intranet ──POST rsu cifrado──▶ backend /auth/init ──descifra con API Intranet──▶
           redirige a /access/auth?access=… ──▶ pages/access/auth.vue ──▶ /auth/login ──▶ JWT

Simulado:  pages/access/index.vue (elige usuario de SIMULATION_USERS) ──POST rsu = base64(RUT)──▶
           backend /auth/init ──INTRANET_AUTH_FLOW ≠ 'true': acepta el base64 como RUT──▶ igual que arriba
```

**Lo que hay que conservar**, porque es el login real: `POST /auth/init`,
`POST /auth/login`, `pages/access/auth.vue` y la rama de `decryptDni` que
consulta a la Intranet. Borrar la carpeta `pages/access/` completa dejaría a
todos sin poder entrar.

### 2.2 Inventario

| T | Trampa | Capa | Dónde | Qué hace | Retiro | Riesgo de romper |
|:-:|:--|:-:|:--|:--|:--|:-:|
| T1 | Simulador de login | front | `pages/access/index.vue` (todo el archivo; rama de producción en `:13-28`) · `.env`: `SIMULATION_USERS`, `SIMULATION_USERS_CATALOG` · `LOGIN_URL` local apunta a `/access` | Pantalla para elegir a quién suplantar | Dejar `index.vue` solo con la rama de producción (enlace a la Intranet) en vez de borrarlo; quitar las dos variables de todo `.env`; `LOGIN_URL` a la Intranet en cada ambiente | **Medio** si se borra la página: un ambiente cuyo `LOGIN_URL` siga apuntando a `/access` da 404 al cerrar sesión. Con la página reducida a la rama de producción, **bajo** |
| T2 | Descifrado local del RUT | back | `auth.service.ts`: constante `INTRANET_AUTH_FLOW`, rama base64 de `decryptDni`, retorno anticipado de `init()` · `.env` del backend define `INTRANET_AUTH_FLOW` **dos veces**, ambas distintas de `'true'` · `.env.example` la incluye | Acepta cualquier base64 como RUT | Eliminar la constante, la rama local y el retorno anticipado; quitar la variable de `.env` y `.env.example` | **Bajo** para certificación y producción (ya fuerzan el flujo real con `NODE_ENV=production`). **Alto para desarrollo local**: sin credenciales de la API Intranet, nadie podrá entrar en local. Decisión del usuario |
| T3 | `DISABLE_AUTH` | front | `nuxt.config.js:62` | Apaga `auth` y `guardian` en todas las rutas | Quitar el ternario: siempre `middleware: ['auth', 'guardian']` | **Bajo** |
| T4 | Variables del `.env` horneadas en el bundle | front | `nuxt.config.js:50` (`@nuxtjs/dotenv`) | Toda variable del `.env` queda en el JS del navegador | Configurar `@nuxtjs/dotenv` con lista explícita (`only`) de las variables públicas; reconstruir `dist` con `NODE_ENV=production` y comprobar que no contenga identificadores del catálogo | **Bajo**, si la lista incluye `BASE_URL`, `API_URL` y `LOGIN_URL` |
| T5 | INTERRUPTOR-DU09 | front · back · PA | Store `service-provision-payment-detail.js:23` · `controller.ts:66` · guardas comentadas en `sg_epagiSecgen01:120-127`, `sg_epaguSecgen01:129-136`, `sg_epaguSecgen02:104-111` · criterio en `sg_cctosSecgen05:66-68` y `:89-91` · **aviso visible** «Modo de prueba» en `Du288PaymentValidationsSection.vue:26-30` | Saldo y DU09 informan pero no bloquean | Los 6 puntos conocidos, sincronizados, **y** retirar el aviso y sus textos `testModeTitle`/`testModeDetail` (el aviso se oculta solo al encender, pero queda código muerto) | **Alto** si se enciende sin datos: los CC con `afec_du9` nulo quedan sin poder pagar ni listarse en resolución. Requiere §3.4 primero |
| T6 | RUT de prueba de asistencia | back · front | `payment-procedures.repository.ts:122` (constante), `:964-966` (getter), `:1071-1072` (sustitución) · `controller.ts:608` (tipo), `:702-703` (campo) · `_installmentNumber.vue:589`, `:1345` · `Du288PaymentAttendanceSection.vue:22` (aviso), `:114-115` (prop) · `pds.js` `testRut`, `testRutSuffix` | Consulta las marcas de otra persona y la pantalla muestra **ese RUT en claro** | Retirar los 10 puntos juntos | **Bajo**: hoy está vacía y la ruta real ya es la que se usa |
| T7 | Funcionario sin contrato | front · back | `PdsDu288RequestForm.vue:5019-5022` (toast y continúa) · `request-procedures.repository.ts:2908` (sale sin error si falta la fecha de inicio del contrato) | Permite resolver sobre un funcionario sin contrato | Volver a cortar la selección en el front **y** exigir contrato en el backend | **Medio**: se debe confirmar antes que la fuente de contratos vigentes esté completa en certificación; si no, se bloquean funcionarios legítimos |
| T8 | Alerta del contrato persistido | front | `PdsDu288RequestForm.vue:5816-5818` | Al reabrir una fila, no avisa que el contrato guardado ya no cubre el período | Reactivar la alerta | **Bajo**: es una alerta, no bloquea guardar. La validación en vivo `CONTRATO_NO_CUBRE_MESES` (`:6378-6390`) y la del backend (`:2897-2915`) **ya están activas** |
| T9 | Endpoint «alias temporal» | back | `service-provision-request.controller.ts:1656-1673`, `GET …/normative/calculated-cap/{rutPerson}` | Duplica el perfil normativo; ningún consumidor en el front | Eliminar el endpoint | **Bajo** |
| T10 | Compatibilidad con PA antiguos | back | `request-procedures.repository.ts:610` | Acepta el mensaje de éxito de PA anteriores al contrato `status`/`code` | Eliminar **solo después** de confirmar que certificación tiene `sg_fupsiSecgen01`/`u01` con `status`/`code` | **Alto** si se retira antes: guardar un funcionario falla aunque el PA haya escrito bien |
| T11 | Acción de saldo sin uso | front | `store/enabled-cost-center.js:31` | Acción comentada como temporal a la espera de permisos de `UsuaVrac` | Mantener hasta resolver el permiso, o eliminar | **Ninguno** |

### 2.3 Orden de retiro sugerido

1. **T3, T4, T6, T9** — independientes y de bajo riesgo.
2. **T1 + T2 juntos**, después de fijar `LOGIN_URL` a la Intranet en cada ambiente. Antes, decidir qué hará el equipo para entrar en desarrollo local sin T2.
3. **T8**, alerta sin efecto de bloqueo.
4. **T7**, cuando se confirme la fuente de contratos en certificación.
5. **T5**, siguiendo §3.4.
6. **T10**, cuando se confirme la versión instalada de los PA de funcionario.

---

## 3. Base de datos: la versión vigente de cada script

### 3.1 Regla aplicada

Se aplica lo último desarrollado. Donde un documento contradice al script más
reciente, manda el script y el documento queda por corregir.

| Script | Última modificación | Qué hace (según el script) | Documentos desfasados |
|:--|:-:|:--|:--|
| `00_ddl_pagos.sql` | — | **No existe.** El README lo describe: crea `sg_efum`, `sg_epag`, `sg_dpag`, `sg_com1`, agrega columnas, renombra | — |
| `01_sg_ecuo.sql` | 02-11 | Borra 5, 6, 7, 9, 12; conserva 1, 2, 3, 4, 8, 10, **11** con los nombres acordados | Catastro, checklist y `orden_de_despliegue.md` dicen que borra el 11 |
| `02_sg_efum.sql` | 26-10 | Carga los 4 estados del mes | — |
| `03_migracion_sg_fume.sql` | 25-09 | Pasa `cod_estcuo` a `cod_estfum` en `sg_fume` | — |
| `04_roles_privilegios_pagos.sql` | 20-10 | Rol 33 `PAGO_DGDP` y sus privilegios | Omitido en el catastro y en `orden_de_despliegue.md` |
| `05_sg_tacc_acciones_pago.sql` | 29-10 | Acciones **32, 33 y 34** | Catastro, checklist y README dicen solo 32 y 33 |
| `06_marcas_du09_centro_costo.sql` | 14-10 | **Diagnóstico**: lista CC sin `afec_du9`; el `update` va comentado | README dice que «carga marcas» |
| `07_sg_ecuo_descripciones.sql` | 02-11 | Solo actualiza las descripciones de los 7 estados | Omitido en el catastro, el checklist y `orden_de_despliegue.md` |

### 3.2 `01` o `07`: en certificación corresponde `01`

- **Base sin cuotas de pago:** `01_sg_ecuo.sql`.
- **Base con cuotas de pago** (la de desarrollo): solo `07_sg_ecuo_descripciones.sql`,
  como indican el README y el impacto 31.

Certificación tiene resolución pero nunca tuvo pagos, así que no hay filas en
`sg_epag` que dependan de los códigos que `01` elimina. Va al final del orden
(§3.4, paso 7): `sg_fume.cod_estcuo` también apunta a `sg_ecuo` mientras exista,
y el guard de `01` aborta si encuentra un código en uso en vez de fallar por
la FK.

### 3.3 La migración toca dos PA de resolución

La migración `cod_estcuo` → `cod_estfum` obliga a recompilar
`sg_fumeuSecgen01` (el único PA de escritura de resolución) y
`sg_fupssSecgen17` (el modal de prestaciones previas).

| Versión | `cod_estfum` | `cod_estcuo` |
|:--|:-:|:-:|
| `template_wf_pagos/cambios_pa/sg_fume/` | ✅ | — |
| `template-du09/.../certificacion_next/entrega/` | — | ✅ |
| `template-du09/.../solicitante/` | — | ✅ |
| `sissolic-procedimientos/` | — | ✅ |
| **Backend actual** (plantilla de la query) | envía `@cod_estfum` | — |

Consecuencias:

1. Certificación tiene hoy la versión con `cod_estcuo`, porque resolución se subió desde el paquete antiguo. El pase de pagos la **reemplaza** con la de `template_wf_pagos/cambios_pa/sg_fume/`.
2. Se instalan **en la misma ventana** que el backend y **después** del DDL (§3.5). Mientras tanto, el backend de resolución que hoy corre en certificación debe seguir siendo el anterior, que envía `@cod_estcuo`.
3. Es una excepción a la regla «pagos no modifica un PA de resolución»: aquí no hay alternativa, porque cambia la columna que los dos leen. Conviene dejarla registrada.

### 3.4 Orden corregido, con lo último desarrollado

| Paso | Qué | ¿Resolución funciona durante el paso? |
|:-:|:--|:-:|
| 0 | **Escribir `00_ddl_pagos.sql`** (§3.5) y probarlo sobre una copia de certificación | — |
| 1 | `00` — tablas nuevas y `cod_estfum` nula en `sg_fume`/`sg_fum2` | ✅ |
| 2 | `02_sg_efum.sql` | ✅ |
| 3 | `03_migracion_sg_fume.sql` | ✅ |
| 4 | `00` — `cod_estfum` a `NOT NULL` + FK | ✅ |
| 5 | **Una ventana:** `sg_fumeuSecgen01` y `sg_fupssSecgen17` desde `cambios_pa/sg_fume/` **+** backend | ✅ si van juntos |
| 6 | `DROP` de las columnas antiguas | ✅ |
| 7 | `01` (base nueva) o `07` (base existente) | ✅ |
| 8 | `04_roles_privilegios_pagos.sql` | ✅ |
| 9 | `05_sg_tacc_acciones_pago.sql` | ✅ |
| 10 | PA de pagos de `cambios_pa/` | ✅ |
| 11 | `06_marcas_du09` (diagnóstico) → cargar `afec_du9` → recién entonces T5 | ✅ |

### 3.5 Qué debe cubrir el DDL de pagos

**Fuente recomendada:** la base de desarrollo, donde pagos ya funciona. Extraer
con `ddlgen` la definición vigente de las siete tablas de abajo y compararla
con certificación (`sp_help` de cada una): lo que falte en certificación es el
contenido del DDL. Escribirlo desde los PA, sin esa comparación, arriesga
tipos, nulabilidad y llaves equivocados.

**Piso mínimo**, extraído de lo que escriben los PA de `cambios_pa/`
(`INSERT … (columnas)` y `UPDATE … SET`). El DDL debe tener al menos esto:

| Tabla | Situación | Columnas que los PA escriben |
|:--|:--|:--|
| `sg_efum` | nueva | `cod_estfum`, `des_estfum` |
| `sg_epag` | nueva | `id_funprse`, `nro_cuota`, `cod_estcuo`, `ano_pago`, `mes_pago`, `fec_solici`, `rut_solici`, `id_evidenc`, `mto_realpa` |
| `sg_dpag` | nueva | `id_funprse`, `nro_cuota`, `corr_fume` |
| `sg_com1` | nueva | definida en `cambios_pa/sg_com1/README.md:38-48`, con PK `(id_funprse, nro_cuota, f_observa)` y FK a `sg_epag` y `sg_tacc` |
| `sg_fume` | se altera | escribe `cod_estfum`, `ano_ejec`, `mes_ejec`, `mto_apagar`, `mto_deslic`, `mto_dessg`, `mto_realpa`, `val_licmed`, `val_singoce`, `fec_valida`, `fec_envrem`; además lee `id_evidenc`, `val_inabili`, `val_ciecc`, `rut_autori`, `fec_autori` para versionar |
| `sg_fum2` | se altera | las de `sg_fume` más `correlativ`, `rut_regist`, `f_regist` |
| `sg_fuc2` | verificar | `id_funprse`, `corr_fume`, `fec_comrea`, `hora_ini`, `hora_ter`, `rut_regist` |

**Lo que sale** (paso 6 de §3.4): `sg_fume.cod_estcuo`, `sg_fum2.cod_estcuo` y
`sg_fume.fec_pago`, `ano_pago`, `mes_pago`, que pasaron a `sg_epag`.

**Cómo debe escribirse**, según lo que el README de `datos_base` ya establecía
para este script: idempotente (crear o agregar solo si no existe) y sin borrar
nada; los `DROP` quedan como paso aparte. `ESTANDARES.md` de
`sissolic-procedimientos` regula los PA, no el DDL, así que no fija formato
para este archivo.

---

## 4. WF pagos — las nueve validaciones acordadas (impacto 19 §11.7)

**Faltan cinco**, más dos que existen a medias:

| # | Validación | Acordada | Estado |
|:-:|:--|:--|:--|
| 1 | Centro de costo cerrado | bloquea · 3 PA | ✅ (`vig_ccto <> '1'`) |
| 2 | Centro de costo fuera de DU09 | bloquea · 3 PA | 🟡 escrita, apagada por T5 |
| 3 | **Flujo de pago configurado** | bloquea · compuerta | ❌ no existe en ninguna capa |
| 4 | Tope por cuota | bloquea · 3 PA | 🟡 solo en la compuerta API (`controller.ts:1071-1100`), no en PA |
| 5 | **Contrato cubre los meses de la cuota** | bloquea · `u02` | ❌ no existe |
| 6 | Cuota que cruza el año calendario | bloquea · `i01`/`u01` | ✅ cubierta por resolución, que impide que la prestación cruce de año (`request-procedures.repository.ts:2802`) |
| 7 | **Asignaciones sobre el período cubierto** | bloquea · compuerta | ❌ se evalúan a hoy (`controller.ts:1051`, sin fecha) |
| 8 | **Mes ya pagado en otra prestación del mismo CC** | bloquea · `i01`/`u01` | ❌ el chequeo sigue acotado a la misma prestación (`sg_epagiSecgen01.sql:213-217`) |
| 9 | **Cargo o contrato modificado** | advierte | ❌ no existe en pagos |

| # | Presentación | Estado |
|:-:|:--|:--|
| 10 | Rechazo del envío persistente + revalidación tras el 422 | ❌ toast · **aprobado ajustar** |
| 11 | Descuento desglosado por causal | ✅ |
| 12 | Chip *Deuda institucional · Sin información* | ✅ |
| 13 | Retiro del chip de calendario | ✅ |

**Riesgo de cada faltante**, aplicando el principio rector:

| # | Riesgo de implementarla | Por qué |
|:-:|:--|:--|
| 3 | **Medio** | Hay que definir qué es «flujo de pago configurado» (impacto 19 §11.5 dice que es distinto de `afec_du9`, sin fijar la fuente). Sin esa definición, la regla bloquearía o no por accidente |
| 5 | **Medio** | Choca con la decisión del controlador de no bloquear cuotas devengadas con contrato terminado (§5.1). Debe acotarse a contrato que **no cubría** el mes **cuando se ejecutó** |
| 7 | **Bajo** | Mismo PA que hoy, con la fecha del período en vez de hoy; es más permisiva para asignaciones que vencieron después de ejecutar |
| 8 | **Bajo-medio** | Es la misma consulta sin `id_funprse`, acotada por RUT y CC. Probar que no bloquee meses de una cuota **rechazada** (que conserva `sg_dpag`) |
| 9 | **Bajo** | Advierte, no bloquea; el criterio ya existe en resolución |
| 4 en PA | **Medio** | La compuerta usa el tope **recalculado**, con el congelado como respaldo. El PA tendría que usar el mismo criterio, y esa elección sigue abierta en la matriz §6.1 |

---

## 5. Lo analizado a pedido del usuario

### 5.1 Hallazgo de la revisión 1, n.º 6: no conviene activarlo como bloqueo

`sg_fupssSecgen13` solo devuelve contratos con `vigen_cont in ('0','2')`
(`sg_fupssSecgen13.sql:99`, `:109`, `:125`). Por eso, cuando el contrato con que
se autorizó la prestación terminó, la compuerta no encuentra perfil y no
revalida cargo ni asignaciones (`controller.ts:985`).

El controlador lo documenta como decisión (`:974-976`): *un contrato no
vigente en SISPER no debe bloquear el pago de cuotas devengadas*. Y la matriz
§4.2 deja abierta esa misma pregunta para `persistedContractNotCurrent`.

Además, `VALIDACION_CARGO_PENDIENTE` **sí se respeta** cuando hay perfil: si la
habilitación llega vacía o distinta de `S`, la compuerta rechaza (`:1037-1048`).

**Conclusión:** convertir el `if (profile)` en bloqueo rompería el pago de toda
cuota de un funcionario cuyo contrato terminó después de ejecutar. Lo que sí
falta es que la omisión deje de ser silenciosa: un chip no bloqueante, en el
panel del solicitante y en la revisión DGDP, que diga que cargo y asignaciones
no se pudieron revalidar porque el contrato ya no está vigente. DGDP decide.

**Confianza: alta.** **Riesgo de la alternativa propuesta: bajo.**

### 5.2 Cupo anual por centro de costo: verificado, no se aplica

Verificado en el código actual (no es documento antiguo):

- Frontend: `editingWorkerCommittedInstallmentMonths` filtra por centro de costo (`PdsDu288RequestForm.vue:1524`).
- Backend: `getCommittedInstallmentMonthsForYear` cuenta todas las prestaciones del funcionario, salvo las con extensión (`request-procedures.repository.ts:462-474`).

El backend es el más restrictivo, de modo que **no hay riesgo económico**: el
efecto posible es un rechazo al guardar de una solicitud que la pantalla
aprobó. Los pagos desfasados no alteran el conteo, porque se cuenta por mes de
ejecución y no por mes de pago.

Queda como decisión funcional, sin aplicar, como indicó el usuario.

### 5.3 Tope en pagos con extensión

El modal de historial de resolución dice bien *No aplica por extensión de
cuotas*: el impacto 19 §11.1 fija que la extensión exime del tope y la
compuerta lo aplica (`controller.ts:1078-1080`). Lo que confunde es pagos:
`Du288PaymentContextSection.vue:152` muestra el `mto_tope` guardado sin
considerar la extensión.

---

## 6. Desarrollo y estándares

### 6.1 Recomendación sobre los 37 mensajes con RUT (pregunta del usuario)

Los 37 están en `service-provision-request-procedures.repository.ts` y siguen
el patrón `El funcionario con RUT ${rut} …`. No hay helper de enmascarado en el
backend ni en el frontend, y **el frontend no extrae el RUT del texto** para
marcar filas, así que quitarlo no rompe ninguna pantalla.

**Recomendación: sacar el RUT del texto, sin enmascararlo.**

- Una solicitud DU288 tiene exactamente un funcionario (§9 del documento 09):
  quien recibe el error ya sabe de quién se trata. El RUT no agrega información.
- Enmascararlo (`12.***.***-K`) seguiría exponiendo parte del dato y obligaría a
  crear y mantener un helper que hoy no existe.
- Si algún mensaje se usa también en solicitudes legacy con varios
  funcionarios, identificar por **nombre** en el texto y por `id_funprse` en un
  campo `details`, que es el patrón que ya usa el mismo archivo para los errores
  de asignación de etapas (`throwInvalidWorkflowAssignments`, `:476-512`).

**Riesgo: bajo.** Cambia solo el texto del 422; ninguna lógica lo lee.

Fuera del backend hay un caso menor en el frontend:
`utils/services-provision/normative/messages.js:77` (`corruptSummary`) arma un
texto local con el RUT.

### 6.2 Resto de los estándares

| Regla | Hallazgo | Severidad |
|:--|:--|:-:|
| Sin RUT en logs | `user-permissions.repository.ts:302`, `:310` · **aprobado quitar** | 🟠 |
| Sin `any` en fronteras | 52 en `service-provision-request-procedures.repository.ts`, 9 en `service-provision-request.controller.ts`; 0 en pagos | 🟡 |
| Reglas de negocio en servicio | La compuerta del envío (~200 líneas) vive en el controlador. Al escribir la de aprobación, moverlas a un servicio y no duplicar | 🟡 |
| Funciones pequeñas / extraer patrones | `PdsDu288RequestForm.vue` 8.851 líneas; `Du288StaffPreviousProvisionsModal.vue` 3.294 | 🟡 |
| Números mágicos | `21` (`codTipmov`, `controller.ts:1112`), `696` (`cod_organi`), haber `2417` | 🟡 |
| Mensaje del tope sin formato | `la cuota solicita 1111111 y el tope vigente es 256250` (`controller.ts:1097`) | 🟡 |
| Capas | Ninguna vista llama HTTP directo | ✅ |
| Errores Sybase | No se reenvía el mensaje crudo al cliente | ✅ |

---

## 7. Datos: lo que falta, sobra o es ambiguo

| Dato | Situación | Efecto |
|:--|:--|:--|
| DDL de pagos | `00_ddl_pagos.sql` no existe | §3.4, paso 0 |
| `es_ccto.afec_du9` | `NULL` en los CC de prueba | T5 no se enciende sin cargarlo |
| `sg_fups.cod_sitm` | ítem de 3 dígitos o subítem de 5 según el origen | La compuerta lo pasa como `cod_sitm` al PA de saldo (`controller.ts:1112`): confirmar el formato que espera `valida_saldo_cc_cs` antes de encender T5 |
| `tot_cuotas` vs filas de `sg_fume` | Pueden no coincidir (N° 212: declara 2, tiene 6) | El modal lo reporta |
| `sg_fume.val_ciecc` | Sin escritor | Columna muerta |
| `sg_epag.mto_realpa` | No se congela al aprobar, solo al cerrar | Decisión abierta (impacto 30) |
| `sg_ecuo.des_estcuo` | La pantalla lo lee directo | `07` en base existente |
| Haber `2417` | Constante en código | Ratificar |
| `.env` del backend | `INTRANET_AUTH_FLOW` definida dos veces | T2 |

**Nota para el paquete manual del usuario** (fuera de alcance): la versión de
`sg_usacsSecgen01` en `sissolic-procedimientos/` tiene 137 líneas y no incluye
`es_revisor_pago`; la de `cambios_pa/sg_usacs/` tiene 168 y sí. Con la primera,
la bandeja DGDP aparece vacía sin error. Y 37 PA que invoca el backend solo
están en `cambios_pa/`.

---

## 8. Verificación ejecutada

| Verificación | Resultado |
|:--|:--|
| Backend `npm run build` | sin errores |
| Backend `lb-mocha` unitarias | 288 pasando, 0 fallando |
| Frontend pruebas PDS | 23 archivos, todos correctos |
| Estándar visual DU288 | 55 archivos |
| ESLint `services-provision`, stores y utils DU288 | limpio |
| Pares `.sql`/`.txt` de `sg_epagiSecgen01`, `u01`, `u02` | idénticos |
| Variables del `.env` del front presentes en `dist/` | las 6 (contadas por nombre, sin imprimir valores) |

---

## 9. Plan

### A. Aprobados o sin decisión pendiente

| | Qué | Capa | Riesgo | Confianza |
|:-:|:--|:-:|:-:|:-:|
| A1 | Retirar T3, T4, T6 y T9 | front · back | bajo | alta |
| A2 | Retirar T1 + T2 juntos, con `LOGIN_URL` a la Intranet y `index.vue` reducido a la rama de producción. **Aprobado**; registrado para reimplementar en `login_simulado_desarrollo.md` | front · back | bajo en certificación; en desarrollo local se entra con credenciales reales (aceptado) | alta |
| A3 | Rechazo del envío a `installmentError` + revalidar tras el 422 | front | bajo | alta |
| A4 | Quitar los dos `console.log` de autenticación | back | ninguno | alta |
| A5 | Sacar el RUT de los 37 mensajes (§6.1) | back | bajo | alta |
| A6 | Chip no bloqueante cuando no se puede revalidar cargo y asignaciones (§5.1) | front · back | bajo | alta |
| A7 | Reactivar la alerta del contrato persistido (T8) | front | bajo | alta |
| A8 | Corregir catastro, checklist, README de `datos_base` y `orden_de_despliegue.md` según §3 | documentación | ninguno | alta |
| A9 | Quitar los TODO obsoletos y retirar los 29 métodos stub sin llamadores (§11.2, §11.3) | back | ninguno | alta |

### B. Requieren decisión o un insumo antes de escribirse

| | Qué | Lo que falta |
|:-:|:--|:--|
| B1 | Compuerta normativa de la aprobación DGDP | Qué validaciones aplican al aprobar (no son las del envío) |
| B2 | Escribir `00_ddl_pagos.sql` (§3.5) | La definición vigente de las siete tablas en desarrollo (`ddlgen`) y `sp_help` de certificación para compararlas |
| B4 | Validaciones 3, 5, 7, 8, 9 y tope en PA (§4) | Fuente de «flujo de pago configurado»; alcance de «contrato cubre los meses»; tope congelado o recalculado |
| B5 | T7 sin contrato | Confirmar la fuente de contratos vigentes en certificación |
| B6 | T5 interruptor | Cargar `afec_du9` y confirmar el formato de `cod_sitm` |
| B7 | T10 compatibilidad | Confirmar la versión instalada de los PA de funcionario |
| B9 | Errores de lectura que se convierten en objetos vacíos (§11.2) | Revisar a los 3 llamadores de `getRequestById` antes de cambiar el `catch` |

### C. Cerrados o fuera de alcance

Excel de Finanzas (decisión), `sissolic-procedimientos/` (manual), cupo por
centro de costo (decisión funcional sin aplicar), carpeta `components/`
(ya no existe). **B3** resuelto: en certificación corresponde `01` (§3.2).
**B8** resuelto: el login simulado del backend no se conserva (§0).

---

## 10. Límites de esta auditoría

- No se ejecutó SQL contra Sybase: que un PA exista en el repositorio no prueba
  que esté instalado, ni con qué versión. Lo mismo para el DDL.
- No se abrió la aplicación en el navegador: los hallazgos de pantalla salen
  del código fuente.
- Los identificadores del catálogo de simulación y los valores del `.env` se
  contaron o clasificaron sin imprimirlos; este documento no contiene ninguno.

---

## 11. TODO del PDS en WF pagos y WF resolución

### 11.1 Alcance y resultado

Se buscaron `TODO`, `FIXME`, `XXX`, `HACK` y `PENDIENTE` en el frontend de PDS
(`components/services-provision`, `pages/services-provision`, `store`,
`utils/services-provision`, `lang/es/pds.js`, `middleware`), en todo
`sg-solicitudes-backend/src` y en los PA de `template_wf_pagos/cambios_pa` y
`datos_base`; en los PA, también marcas en minúscula como «por definir» o
«quitar cuando».

**51 marcas.** Siete son el valor `'PENDIENTE'` de un estado, no pendientes de
desarrollo. De las 44 restantes:

| Tipo | Cantidad | Riesgo hoy |
|:--|:-:|:--|
| Pendiente real de PDS | 3 | ya en el plan |
| TODO obsoleto que esconde otro problema | 2 | medio |
| Métodos stub sin llamadores | 29 | ninguno; trampa si alguien los usa |
| Preguntas abiertas en código legacy de resolución | 4 | bajo |
| Fuera de PDS (apertura y cierre de centro de costo, permisos) | 4 | fuera de alcance |
| PA de pagos y datos base | 0 | solo la marca `INTERRUPTOR-DU09` (T5) |

### 11.2 Pendientes reales y TODO obsoletos

| Marca | Dónde | Qué es | Plan |
|:--|:--|:--|:--|
| `TODO PRUEBAS` | `Du288PaymentAttendanceSection.vue:114` · `pds.js:2169` | Aviso del RUT de prueba de asistencia | T6 (A1) |
| `TODO DU288` | `store/enabled-cost-center.js:31` | Acción de saldo sin uso, a la espera del permiso `SELECT` de `UsuaVrac` sobre `wf_sol2`/`wf_tra1` | T11 |
| `TODO: change to real data` | `service-provision-request-procedures.repository.ts:837`, `:862` | **Obsoleto**: los dos métodos ya consultan datos reales | Quitar el comentario (A9) |

Lo que esconden esos dos métodos: el `catch` imprime el error y devuelve
`new RequestI()`. Si la consulta falla, quien llama recibe una solicitud vacía
como si existiera. El mismo archivo tiene **cinco** `catch` que devuelven un
objeto vacío. `getRequestById` tiene tres llamadores; `getSimpleRequestById`,
ninguno. Cambiar el `catch` para que lance un error controlado es lo correcto,
pero exige revisar antes qué hace cada llamador con el objeto vacío: alguno
puede depender de él para seguir (B9).

### 11.3 Métodos stub

29 métodos con `//TODO: run query` arman los parámetros, **no ejecutan nada** y
devuelven `1` (éxito) o una lista vacía. Ninguno tiene llamadores. Hoy no
causan daño, pero un método de escritura que responde éxito sin escribir es una
trampa para quien lo use mañana.

| Archivo | Métodos |
|:--|:--|
| `service-provision-request.repository.ts` | `create`, `getAll`, `update`, `delete` (el repositorio se inyecta en `resolution.controller.ts` y `cost-center-close-resolution.controller.ts`, pero esos cuatro métodos no se llaman) |
| `service-provision-request-file.repository.ts` | `create`, `getAll`, `getById`, `update`, `delete` |
| `request-staff.repository.ts` | ídem |
| `request-service.repository.ts` | ídem |
| `request-provision.repository.ts` | ídem |
| `payment-type.repository.ts`, `request-record.repository.ts`, `request-recruitment-type.repository.ts` | `delete` |
| `return-resource.repository.ts`, `return-resource-type.repository.ts` | `delete` (módulo de devolución de saldos, fuera de PDS) |

Retirarlos (A9) no cambia ningún comportamiento. Antes conviene correr el build
y las pruebas: si un llamador escapó a la búsqueda, el compilador lo detecta.

### 11.4 Preguntas abiertas en el código legacy de resolución

| Marca | Dónde | Efecto |
|:--|:--|:--|
| `name: possible.dni // TODO: Get real name` | `resolution-approval.repository.ts:249`, `:354` | En la página **legacy** `resolution-format.vue`, la lista de quién firma (`WhoSignsUp.vue`) muestra el **RUT donde va el nombre**. La página DU288 (`resolution-format-normative.vue:981-988`) no usa este endpoint |
| `Falta actualizar la información general, ¿qué es resolución exenta?` | `resolution-detail.repository.ts:61` | Pregunta funcional sin responder |
| `¿consultar por más centros de costo?` | `request-history-response.model.ts:31` | El historial solo trae un centro de costo |

Ninguna afecta a DU288. La primera expone un RUT en pantalla en el flujo legacy
y conviene cerrarla junto con A5.

### 11.5 Fuera de PDS

`cost-center-close.controller.ts:292`, `cost-center-close-request.ts:16`,
`cost-center-opening.model.ts:38`, `permissions-const.ts:204`,
`permissions.ts:95`. Se listan para que no se confundan con pendientes del PDS.
