# Datos fijos para certificación de pagos DU288 / DU09

Esta carpeta contiene únicamente la carga de catálogos, acciones y permisos del
flujo. Cada SQL tiene un TXT idéntico: se ejecuta una sola extensión.

| Orden | Script | Tabla | Datos que deja disponibles |
| :-- | :-- | :-- | :-- |
| 1 | [01_sg_ecuo.sql](01_sg_ecuo.sql) | `secgen_db.dbo.sg_ecuo` | Estados de la cuota: 1, 2, 3, 4, 8, 10 y 11 |
| 2 | [02_sg_efum.sql](02_sg_efum.sql) | `secgen_db.dbo.sg_efum` | Estados del mes: 1, 2, 3 y 4 |
| 3 | [05_sg_tacc_acciones_pago.sql](05_sg_tacc_acciones_pago.sql) | `secgen_db.dbo.sg_tacc` | Acciones 32, 33 y 34 de DGDP, consumidas por el historial de cuota `sg_com1` |
| 4 | [04_roles_privilegios_pagos.sql](04_roles_privilegios_pagos.sql) | `sistema_db.dbo.bd_per1`, `bd_prvg`, `bd_pepr` | Perfil 33, privilegios 92–99 y 12 asociaciones con los perfiles 6 y 33 |

Ejecutar en una sesión sin transacción externa. Detener la carga si un script
reporta error. Los catálogos 01 y 02 insertan filas faltantes y actualizan
descripciones; los scripts 04 y 05 verifican los códigos antes de insertar. Los
textos con tildes de 01 se conservan en UTF-8: configurar la codificación del
cliente al cargar y verificar en la base las dos etiquetas con tildes.

| Código | Estado de cuota (`sg_ecuo`) | Estado del mes (`sg_efum`) |
| :-- | :-- | :-- |
| 1 | Borrador | Propuesta |
| 2 | En revisión DGDP | Comprometida |
| 3 | Devuelta para corrección | Enviada a pago |
| 4 | Aprobada por DGDP | Rechazada |
| 8 | Enviada a remuneraciones | |
| 10 | Rechazada por DGDP | |
| 11 | Devuelta de Finanzas | |

Los estados 5, 6, 7, 9 y 12 de `sg_ecuo` se conservan si existen por historia;
el listado de estados vigentes del flujo los excluye.

| Código | Acción de DGDP (`sg_tacc`) |
| :-- | :-- |
| 32 | Devolver la cuota a corrección |
| 33 | Rechazar la cuota |
| 34 | Devolver una cuota aprobada a visación |

El perfil 6 recibe `create`, `read`, `history-read` y `document-read`. El perfil
33 (`payment_validator`) recibe esos cuatro más `read-waiting`, `approve`,
`adjust` y `submit`. El script no asigna el perfil a personas. La pertenencia
dinámica del validador se resuelve en `sg_usacsSecgen01`.

Antes de cargar, confirmar en certificación que estén las tablas de catálogo y
permisos. Antes de instalar los [PA del inventario](../cambios_pa/inventario_certificacion.md),
confirmar también `sg_epag`, `sg_dpag`, `sg_com1`, el correlativo `corr_fume` en
`sg_fume`, `sg_fum2` y `sg_fuc2`, y el estado `cod_estfum` del esquema vigente.
La adaptación de un esquema anterior y de sus filas históricas se gestiona por
separado con el equipo de base de datos. Los PA compartidos con resolución y el
backend que los invoca deben desplegarse en la misma ventana.

La [consulta de marcas DU09](../soporte_certificacion/06_marcas_du09_centro_costo.sql)
es de solo lectura. Las marcas por centro de costo, los saldos presupuestarios,
las solicitudes y los registros de personas se gestionan fuera de esta carga.
