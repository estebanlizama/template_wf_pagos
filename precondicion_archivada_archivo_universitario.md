# La precondición de "archivada" y el rol Archivo Universitario

Todo el WF de pagos depende de que la solicitud llegue a `cod_estsol = 11`
(*Archivada*), y eso depende de un solo rol. Revisión de si ese supuesto se
sostiene.

Fecha: 20-10-2026. Análisis, no implementación.

---

## 1. De qué depende el pago

`sg_epagiSecgen01` no deja crear una cuota si la solicitud no está archivada:

```sql
and soli.cod_estsol = 11
and soli.nro_resolu is not null
...
select 'La prestacion no existe, no esta archivada o no esta a su cargo' as msg
```

Y para PDS hay **un solo camino** a `11`. Lo escriben dos repositorios con el
mismo código:

```ts
// service-provision-request-approval.repository.ts:223
// resolution-approval.repository.ts:494
if (isFinalSigner) {
  const finalStatusCode =
    id_perfil === 18 || id_perfil === 77
      ? ServiceProvisionRequestStatusCode.ARCHIVED   // 11
      : ServiceProvisionRequestStatusCode.FINISHED;  // 8
  ...
}
```

*(El otro `cod_estsol: 11` del backend, en `resolution-document.repository.ts:71`,
cuelga del endpoint `/baco/resolution/mark-as-entered` — bases de concurso, no
PDS.)*

---

## 2. La buena noticia: el supuesto se sostiene

La etapa de Archivo Universitario es **terminal y obligatoria en los ocho
flujos** DU288. De `cargar_datos_base/05_flujos_etapas_du288.sql`:

| `cod_flusol` | `cod_etapa` | `des_etapa` | `cod_perfil` | `est_final` |
| ---: | ---: | :--- | ---: | :---: |
| 1 | 130 | Jefe Archivo Universitario | 18 | **S** |
| 2 | 130 | Jefe Archivo Universitario | 18 | **S** |
| 3 | 130 | Jefe Archivo Universitario | 18 | **S** |
| 4 | 130 | Jefe Archivo Universitario | 18 | **S** |
| 5 | 110 | Jefe Archivo Universitario | 18 | **S** |
| 6 | 120 | Jefe Archivo Universitario | 18 | **S** |
| 7 | 120 | Jefe Archivo Universitario | 18 | **S** |
| 8 | 120 | Jefe Archivo Universitario | 18 | **S** |

Hay exactamente **una** etapa con `est_final = 'S'` por flujo, y en los ocho es
la misma, con el mismo perfil `18`.

Y no se puede omitir. `maestros/flujo_decision_responsables_etapas_du288.md` §7:

> La politica conservadora aplicada permite omision por responsable repetido
> solamente para Jefe Directo, perfil `26`. Las autoridades formales,
> Solicitante y Jefe de Proyecto mantienen su tarea aunque el RUT efectivo se
> repita.

El perfil 18 es autoridad formal: conserva su tarea siempre. Entonces **todo
flujo DU288 tiene que pasar por el perfil 18 para terminar**, y ese paso es el
que archiva. El supuesto del WF de pagos es correcto.

La subrogancia tampoco lo rompe: el subrogante actúa **sobre la misma etapa**
(`es_subrogante = 'S'` cuando la selección viene de AUFI), así que la etapa
resuelta sigue siendo la 130 del perfil 18.

---

## 3. El `77` es un error: es `cod_organi`, no un perfil

Mirá la misma fila de la semilla, entera:

```sql
INSERT INTO #etapas_du288 VALUES (1, 130, 'Jefe Archivo Universitario', 18, 'S', 'S', 77)
/*                                                        cod_perfil ──┘   │    │   └── cod_organi */
/*                                                              est_final ─┘    └─ vigente        */
```

- **18** es `cod_perfil` — *Jefe de archivo Universitario*, según
  `01_roles_permisos_du288.sql:45`.
- **77** es `cod_organi` — la **unidad organizacional** de Archivo
  Universitario.

El backend compara `id_perfil === 77`, o sea **un código de perfil contra un
código de unidad**. Y el catálogo de perfiles DU288 va del 6 al 32
(`01_roles_permisos_du288.sql`): **el perfil 77 no existe**.

Hoy es inofensivo —nunca calza—, pero es un hueco latente: si en otro módulo
existiera un perfil 77, un firmante que no es Archivo Universitario archivaría
una PDS. Y está duplicado en los dos repositorios.

---

## 4. El riesgo real: "firmante final" y "quién archiva" no coinciden

Esta es la asimetría que conviene mirar. `isUniversityComptrollerSigner`
(`service-provision-request-approval.repository.ts:63-93`) devuelve `true` para
**dos** roles:

```ts
return (
  signerRole === this.normalizeRole(UniversityComptroller) ||   // 17 Contralor
  ...
  signerRole === this.normalizeRole(UniversityArchiveHead) ||   // 18 Archivo
  ...
)
```

Pero la asignación de estado acepta **solo 18**. Entonces, si el que firma último
es el **Contralor (17)**:

- `isFinalSigner` → **true** (el código concluye "esta es la firma final");
- `id_perfil === 18 || 77` → **false**;
- la solicitud queda en **8 (`FINISHED`)**, no en 11.

Y una solicitud en 8 **nunca va a poder generar una cuota de pago**. El jefe de
proyecto recibe *"La prestacion no existe, no esta archivada o no esta a su
cargo"*, que no dice nada de la causa real: el trámite terminó, pero terminó en
el estado equivocado.

Hoy la configuración de etapas impide que el Contralor sea el último (§2), así
que esto no debería ocurrir. Pero el código **lo contempla** —acepta al Contralor
como firmante final— y en ese camino produce un estado que bloquea el pago para
siempre y sin diagnóstico.

### Y `id_perfil` lo manda el cliente

No se deriva de la etapa en el servidor:

```ts
// service-provision-request-approval.repository.ts:118
const id_perfil = Number(params.id_perfil || request.idPerfil || 0);
```

`idPerfil` es una propiedad del request body (`resolution-approval.model.ts:55`,
mapeada a `id_perfil`). Así que **el archivado depende de un código de perfil que
envía el frontend**. Una persona con varios perfiles, o un subrogante cuyo perfil
propio no es el de la etapa, puede dejar la solicitud en 8 en vez de 11 sin que
nada avise.

---

## 5. Qué conviene hacer

Ninguno de estos puntos cambia el diseño del comentario de DGDP
([comentario_devolucion_dgdp_diseno.md](comentario_devolucion_dgdp_diseno.md)):
si la solicitud queda en 8 no hay cuota, y sin cuota no hay comentario. Son tres
arreglos del WF de resolución, independientes entre sí:

| # | Arreglo | Por qué |
| :-- | :--- | :--- |
| 1 | **Derivar el archivado de la etapa**, no del perfil que manda el cliente: la etapa resuelta con `est_final = 'S'` y su `cod_perfil` ya están en `sg_eta1`/`sg_eta2` | Quita del cliente una decisión de estado, y hace que subrogancia y perfiles múltiples dejen de importar |
| 2 | **Sacar `\|\| id_perfil === 77`** (o reemplazarlo por el chequeo real) en los dos repositorios | Compara un perfil contra una unidad organizacional. Dead code con un hueco latente |
| 3 | **Distinguir el error del pago**: que `sg_epagiSecgen01` diga si la solicitud no existe, si no está a su cargo, o si está en 8 en vez de 11 | Hoy los tres casos dan el mismo mensaje y el del estado 8 es indiagnosticable desde la vista |

El 3 es el más barato y el que más tiempo ahorra cuando pase: convierte un
"no funciona y no sé por qué" en un dato.

---

## 6. A confirmar

- **¿El Contralor puede quedar como último firmante** en algún caso real
  (configuración distinta por ambiente, flujo nuevo, etapa 120 marcada final por
  error)? Si la respuesta es no, el arreglo 1 igual conviene, pero deja de ser
  urgente.
- **¿Existe el perfil 77 en algún otro módulo** de SISSOLIC? Si existe, el hueco
  del §3 es explotable hoy.
- **¿Hay solicitudes DU288 en estado 8** con resolución firmada? Serían
  exactamente los casos que no pueden pagar. Conviene contarlas antes de decidir
  la prioridad:

```sql
select count(*)
  from secgen_db.dbo.sg_soli
 where cod_tipsol = 1
   and cod_estsol = 8
   and nro_resolu is not null
```
