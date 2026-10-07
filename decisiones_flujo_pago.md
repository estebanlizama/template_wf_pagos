# Flujo de pago DU288 — decisiones tomadas

**Actualizado:** 02-10-2026 · rama `bandeja_pagos`

Clasificación: **✅ implementado y verificado** · **📦 construido, sin desplegar** · **📋 decidido, sin construir** · **🔶 abierto** · **⚠️ conflicto de fuentes**

---

## 1. Acceso y roles

**✅ El módulo se enciende por configuración, no por variable de entorno.**
`service-provision-payments` está en `ACTIVE_MODULES` del backend y del frontend. Si sale de ahí, `application.ts` desvincula el controlador en boot y `guardian.js` corta la ruta con 403, sin borrar código.

**✅ El permiso del jefe de proyecto es DERIVADO, no asignado.**
`provision-payment-manage` lo recibe en `/auth/user` quien es **responsable vigente de al menos un centro de costo DU288**, según `fin21_db..es_ecct` vía `sg_cctosSecgen05`. No se asigna a mano porque se desalinearía cada vez que cambia un responsable.

**✅ El submenú «Prestaciones por pagar» solo aparece si hay trabajo real.**
Se evalúa `hasPaymentWork`: tener al menos una prestación con **resolución archivada** (`cod_estsol = 11`), modalidad DU288, y meses registrados en `sg_fume`. Un jefe de proyecto sin prestaciones archivadas no ve el submenú.

> Caso detectado en pruebas: una resolución archivada **sin meses** en `sg_fume` deja `cod_estpag = 0` y el submenú no aparece. No era un error de configuración sino un hueco de datos — `sg_fume` se escribe solo al ENVIAR la resolución.

**✅ El RUT sale siempre del token, nunca de la query.**
Es criterio de autorización, no filtro. Recibirlo por parámetro dejaría a cualquier jefe de proyecto listar las prestaciones de otro.

**✅ La autorización vive en el procedimiento, no solo en el backend.**
Todos los PA de pago validan contra `es_ecct` igual que `sg_fupssSecgen18`. Así la escritura no depende de que quien llame se acuerde de comprobarlo. Es **más estricto que los PA de resolución**, que autorizan en la capa de aplicación.

**✅ El revisor DGDP de pagos se deriva por asignación concreta.**
El perfil de validación requiere contrato activo y `sp_orde.cod_organi = 696`, `sp_orde.rut_person` igual al RUT autenticado y `vigente = 'S'`. No usa `cod_design`, `sp_desg`, `eta/apso` ni el rol Director DGDP. Es un perfil independiente del Director DGDP de resoluciones.

---

## 2. Grano del modelo

**✅ Tres niveles.**

```
sg_prse  (nro_solici)                              resolución: actividad, centro de costo, jefe de proyecto
  sg_fups  (id_funprse)                            UN funcionario y su marco autorizado
    sg_fume  (id_funprse, corr_fume)               un MES propuesto
    sg_epag  (id_funprse, nro_cuota)               una CUOTA de ese funcionario
      sg_dpag  (id_funprse, nro_cuota, corr_fume)  qué meses abarca la cuota
```

**✅ La cuota es por FUNCIONARIO, no por resolución.**
`sg_epag.id_funprse` está en la PK. Una resolución con N funcionarios produce N encabezados de cuota.

**✅ Pero la pantalla de gestión es por RESOLUCIÓN.**
El saldo y el tope que hay que validar son del centro de costo; validarlos de a un funcionario deja pasar la suma. Además el jefe de proyecto está en `sg_prse.rut_jefpro`, a nivel de solicitud.

**✅ Un mes entra en una sola cuota, completo.**
`sg_dpag` no tiene columna de monto, así que el mes aporta su `mto_apagar` íntegro y no se reparte entre dos cuotas.

---

## 3. Estados

### 3.1 Mes de ejecución — `sg_efum` ✅ desplegado

| | | |
| :-- | :--- | :--- |
| **1** | Propuesta | la escribe el WF de resolución al ENVIAR |
| **2** | Comprometida | dentro de una cuota enviada; consume cupo, reversible |
| **3** | Enviada a pago | su cuota se subió a Finanzas |
| **4** | Rechazada | DGDP descartó ese mes puntual |

**Principio rector:** *el estado guarda hechos y decisiones, nunca resultados de validación.* Por eso no existe un estado «Validada»: cachearía un resultado que caduca y nadie volvería a evaluarlo. Las validaciones se recalculan en cada transición; los `val_*` y `fec_valida` quedan como **auditoría de lo que DGDP vio ese día**, no como permiso vigente.

Tampoco son estados «Disponible» (depende de la fecha actual) ni «Ejecutado» (se lee de `ano_ejec`/`mes_ejec`).

### 3.2 Encabezado de cuota — `sg_ecuo` 📋 catálogo por depurar

Siete estados, conservando los códigos originales sin renumerar:

| | | Efecto en los meses |
| :-- | :--- | :--- |
| **1** | Propuesta | ninguno |
| **2** | En visación — **es el ENVIAR** | 1 → 2 |
| **3** | Observada | ninguno, siguen comprometidos |
| **4** | Aprobada | ninguno |
| **8** | Enviada remuneraciones | 2 → 3 |
| **11** | Devuelta Finanzas | 3 → 2 |
| **10** | Rechazada · **terminal** | 2 → 1, libera cupo y saldo |

Se quitan cinco: `5 Disponible pago` (se deriva por fecha), `6 Solicitada pago` (se fundió con el 8), `7 Autorizada pago` (era el acto de Finanzas), `9 Pagada` (ocurre fuera del sistema), `12 Bloqueada` (es del mes, no del encabezado).

**Reglas de transición:**
- **Crear no compromete.** El borrador deja los meses en 1. Si crear ya los comprometiera, un borrador abandonado bloquearía meses y consumiría cupo sin que nadie haya pedido nada.
- **Observar no libera.** Los meses siguen en 2, y por eso una cuota observada **no puede cambiar los meses que abarca** — solo montos y respaldo. Cambiarlos es rechazarla y rehacerla.
- **Rechazar sí libera** cupo, saldo y meses.
- **Editable por el solicitante:** estados 1 y 3. Desde el 2 en adelante, solo lectura.
- **Eliminable:** solo en estado 1.

---

## 4. Finanzas y el retorno

**📋 Finanzas opera fuera del sistema.** El WF termina al registrar la petición de pago; no hay integración de ida ni de vuelta.

**📋 Pero Finanzas puede devolver.** Se reincorporó el estado `11 Devuelta Finanzas`. La devolución **la registra DGDP a mano** cuando se lo comunican por fuera. Desde el 11 la cuota vuelve al punto de decisión: reenviar, devolver al solicitante o rechazar.

**Consecuencia:** `sg_fume = 3` dejó de ser terminal. Antes decía *"consume cupo de forma irreversible, sin acuse de vuelta"*; ahora admite `3 → 2`. Los cuatro estados no cambian, solo la regla — sin migración de datos.

**🔶 Sin reversa** queda únicamente la cuota que Finanzas **pagó**. Se corrige fuera del sistema.

---

## 5. Montos

**✅ Tres montos distintos, no uno.**

| | Dónde vive | Quién lo escribe |
| :--- | :--- | :--- |
| **Solicitado** | derivado: `sum(sg_fume.mto_apagar)` | el solicitante, mes a mes |
| **Descuentos** | `sg_fume.mto_deslic` + `mto_dessg` | DGDP en la visación |
| **Monto de la cuota** | **`sg_epag.mto_realpa`** | el **cierre**, tras aplicar descuentos |

`mto_realpa` es el monto de la cuota y sí se persiste; viene nulo mientras está en trámite. Lo **solicitado** no se persiste en el encabezado porque `sg_dpag` no tiene columna de monto.

**Obligación del cierre:** `sg_epag.mto_realpa` y `sg_fume.mto_realpa` guardan la misma cifra, agregada y desglosada. Están denormalizadas a propósito — la bandeja suma el per-mes — así que el PA de cierre debe escribir ambas en la misma transacción.

**✅ Fija vs Variable.** Con `cod_tpps = 1` (Fija) el reparto quedó comprometido en la resolución y la pantalla lo muestra sin permitir editarlo. Con `cod_tpps = 2` (Variable) lo ingresa el solicitante.

**✅ El tope entra completo por cuota**, sin descontar cuotas anteriores. Si la primera usó una fracción, la segunda no hereda el remanente ni queda mermada.

---

## 6. Mes de pago y agrupación

**✅ Corriente o atrasado se DERIVA, no se guarda.**

```
mes de pago = último mes ejecutado + 1   →  corriente
posterior a eso                          →  atrasada
```

**📋 Dos cuotas en el mismo mes de pago: permitido**, con advertencia y causal registrada. Es el caso legítimo de pagar en octubre la corriente de septiembre más una atrasada de julio. Pero dos cuotas agotan el cupo del año salvo extensión autorizada.

**✅ Cupo:** máximo 2 cuotas por prestación y funcionario en el año de ejecución, **sin límite si `sg_fups.ext_cuotas = 'S'`** (ANID o extensión autorizada).

---

## 7. Compensación realizada

**✅ `sg_fuc2` es la realizada; `sg_fuco` la comprometida.** Misma estructura, una dimensión más: el mes (`corr_fume`).

**✅ Solo aplica si `sg_fups.dentro_jor` ∈ {S, D}.** Quien ejecuta fuera de jornada no compensa, y la sección no debe aparecer.

**📋 Se puede guardar incompleta; bloquea el ENVÍO.** La diferencia entre lo comprometido y lo informado se muestra siempre, pero solo impide enviar la cuota — mismo criterio que resolución: guardar valida integridad mínima, enviar valida reglas completas.

**📦 Reglas de cada tramo:**
- horas de inicio y término distintas
- dentro de `f_inicio`–`f_termino`
- no es feriado nacional
- **fuera de la jornada institucional** — lunes a viernes 08:30 a 17:18
- **sin solapamiento con ningún tramo de la persona**, comprometido o realizado, de cualquier mes
- el mes admite cambios (estado 1, o 2 con su cuota observada)

> La fecha se guarda con la **hora de inicio incrustada**, convención heredada de `sg_fuco`. Sin eso la PK solo admitiría un tramo por día, y compensar dos horas en la mañana y dos en la tarde es normal.

> El borrado va por `(id_funprse, corr_fume)`, **no por funcionario**. El equivalente de resolución borra todos los tramos de la persona de un viaje, lo que aquí arrasaría meses ya comprometidos en una cuota enviada.

---

## 8. Asistencia biométrica

**📋 No valida automáticamente.** Decisión cerrada el 30-09-2026 con Alex y José Luis, informada a Jaime.

Queda como **antecedente para el revisor**, que la pondera según su criterio. No bloquea el envío ni determina por sí sola si un mes es pagable.

**Fundamento:** el registro no tiene los identificadores para atribuir tiempo a una prestación concreta — falta el horario del prestador, el tipo de ingreso y el vínculo con `sg_fups`. A eso se suma la ventana de horario flexible, que vuelve aproximado cualquier cálculo de excedente.

**⚠️ Esto deja desactualizada a PAG-38 del catálogo**, que exigía contraste contra marcaje biométrico como bloqueo. El contraste que queda es declarativo: `sg_fuco` contra `sg_fuc2`.

---

## 9. Receso universitario

**📋 Fuera de alcance.** No cambia la decisión de pago: el respaldo documental acompaña la solicitud igual, caiga o no en receso. Se retiró del diagrama, se tachó PAG-35 y su dependencia del calendario de receso.

El calendario institucional **sigue en uso** para los feriados nacionales, que sí bloquean un tramo de compensación.

---

## 10. Respaldo documental

**📋 Un documento por cuota**, PDF u otro, con **toda** la evidencia de esa solicitud de pago. Lo sube el **jefe de proyecto**. Vive en `sg_epag.id_evidenc`.

**Obligatorio al ENVIAR, no al guardar.** Subir otro reemplaza al anterior. DGDP lo ve durante la visación.

Esto simplifica un diseño previo de la fase DU09 —`sg_fuev` + `sg_tevi`, evidencias por mes con catálogo de tipos— que nunca se construyó: su modelo existe en TypeScript pero su repositorio tiene los cinco métodos en `//TODO`.

`sg_fume.id_evidenc` queda sin uso: la evidencia pertenece a la cuota, no a cada mes.

**✅ Decisión aplicada:** el binario vive en MySQL en `MySecGen.sg_doju_<año>`, con un `id_docum` negativo derivado de `(id_funprse, nro_cuota)`. Así se conserva el identificador en `sg_epag.id_evidenc` sin colisionar con los números positivos de solicitud. La aplicación valida PDF de hasta 20 MB, asocia el ID al guardar la cuota y bloquea el envío si el archivo no existe. Antes del despliegue se debe confirmar que `sg_doju.id_docum` sea un entero con signo en el MySQL del ambiente.

---

## 11. Validaciones del envío

**✅ El envío revalida el panel normativo COMPLETO con datos frescos.** No se confía en lo que validó la resolución: entre el decreto y el pago pueden haber cambiado el contrato, el cargo, el saldo o la vigencia del responsable.

**✅ Las reglas normativas no se duplican en SQL.** Se reutilizan los PA de resolución; escribirlas de nuevo crearía una segunda versión que se desincroniza. El PA de envío valida solo lo **estructural** y los saldos, dentro de la transacción.

**✅ 16 PA se reutilizan sin modificar:** 8 del panel normativo (`sg_fupssSecgen12` a `17`, `sg_cctosSecgen06`, `es_cfersSecgen01`), 7 de antecedentes (`sg_cctosSecgen05`, `sg_fucosSecgen01`, `sg_fuhosSecgen01`, `sg_prsesSecgen01`, `sg_fupssSecgen01`/`02`, `sg_histsSecgen01`) y la ruta del documento decretado.

**✅ La resolución es de solo lectura en este flujo.** No se crea, actualiza ni elimina información de `sg_soli`, `sg_rslc` ni otra tabla de resolución. Mostrarla no autoriza a modificarla.

---

## 12. Lo construido

| | Estado |
| :--- | :--- |
| Bandeja del solicitante · `sg_fupssSecgen18` + 2 endpoints | ✅ desplegado |
| Catálogo `sg_efum` + CRUD · 4 PA + 4 endpoints | ✅ desplegado |
| Compensación realizada · `sg_fuc2` × 3 PA + 4 endpoints | 📦 sin desplegar |
| Cuotas · `sg_epag` × 6 PA + 5 endpoints | 📦 sin desplegar |
| Catálogo `sg_ecuo` + CRUD · 4 PA + 4 endpoints | 📦 sin desplegar |
| Meses y montos · `sg_fumesSecgen01` migrado, `sg_fumeuSecgen02` | 📦 sin desplegar |
| Bandeja y detalle DGDP · `sg_epagsSecgen03/04` + resolución `sg_epaguSecgen03` | 📦 construido, SQL pendiente de aplicar |

**15 PA del flujo solicitante** se habían construido antes de esta integración. Esta implementación agrega dos PA de lectura DGDP y uno de resolución. La compilación local se vuelve a verificar; la aplicación Sybase sigue pendiente.

**Lado DGDP:** acceso derivado, bandeja estado 2, detalle de meses y resoluciones 2 → 3/4/10 construidas; SQL pendiente de aplicar en Sybase.

---

## 13. Pendientes de base de datos

El índice único sobre `sg_dpag` quedó descartado y su función la cubren los procedimientos con `holdlock`. La revisión DGDP se ajusta al esquema actual de `sg_epag`: se persiste el estado, mientras que motivo, RUT revisor y fecha no se guardan. `datos_base/05_auditoria_revision_dgdp.sql` es una extensión opcional y no forma parte de la aplicación al esquema vigente.

Pendiente en base: depurar el catálogo de estados de cuota. La extensión opcional de auditoría DGDP está fuera del esquema vigente:

```sql
delete from secgen_db.dbo.sg_ecuo where cod_estcuo in (5, 6, 7, 9, 12)

-- Ver script idempotente datos_base/05_auditoria_revision_dgdp.sql
```

El **1** es el más urgente: la PK de `sg_dpag` admite el mismo mes en dos cuotas, y los endpoints recién construidos son justamente los que arman esa relación.

**`sg_fum2` quedó desfasado:** le faltan `mto_realpa`, `mto_deslic` y `mto_dessg`, y conserva `cod_estcuo` sin migrar. El espejo histórico perdería justo los montos de pago y los descuentos.

---

## 14. Decisiones abiertas

| # | Pregunta | Qué cambia |
| :-- | :--- | :--- |
| 1 | ¿Compensar **de más** también bloquea el envío? | En resolución la diferencia es error en ambos sentidos. En pago, informar más horas no perjudica a nadie |
| 2 | ¿El bloqueo de compensación es por mes o por cuota? | Si es por mes, el solicitante puede sacar el mes incompleto y enviar el resto |
| 3 | ¿Un tramo puede caer fuera del mes de su `corr_fume`? | Trabajó el 30/09 y compensa el 02/10. Hoy el PA lo acepta |
| 4 | **PAG-18 / PAG-38b** — recompromiso de tramos faltantes | No es implementable: `sg_fuc2` no distingue *realizado* de *recomprometido* |
| 5 | ¿Dónde vive el binario de la evidencia en MySQL? | Bloquea subida y descarga |
| 6 | ¿El solicitante puede retirar lo enviado? | Sería `2 → 1` mientras DGDP no abra la cuota |
| 7 | ¿Se renombra `cuotas` → `meses` en la API? | El PA cuenta `corr_fume` y la columna dice «Cuotas» |
| 8 | ¿Hace falta un estado «tomada por DGDP»? | Solo si hay varios revisores sobre la misma bandeja |

---

## 15. Conflictos de fuentes registrados

**⚠️ `sg_fume` en la formalización.** El documento de decisión de agosto dice que el flujo de solicitud **no debe crear** `sg_fume`; el backend implementado y el paquete `certificacion_next` lo sincronizan **al enviar**. Hay que resolverlo antes de tocar la semántica de reserva o de pago.

**⚠️ PAG-38 del catálogo** sigue redactada con contraste biométrico bloqueante, superada por la decisión de asistencia del 30-09. Ya actualizada en el catálogo, pendiente de confirmar con quien la escribió.

**⚠️ «Pagada» vs «Enviada a pago».** La interfaz dice *Pagada*, *pagadas* y *Pagado* en cuatro lugares, pero el sistema solo sabe que la cuota **se envió** — no recibe acuse de Finanzas. El backend lo documenta explícitamente. Es vocabulario de negocio y quedó sin decidir.
