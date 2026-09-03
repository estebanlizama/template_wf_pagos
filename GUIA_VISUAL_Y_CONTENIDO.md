# Guía visual y de contenido — Workflow de pagos

Esta guía mantiene las maquetas alineadas con el lenguaje y la identidad ya usados por el proyecto. No reemplaza los requerimientos funcionales.

## 1. Paleta semántica

| Uso | Color | Variable/referencia |
| :--- | :--- | :--- |
| Identidad y navegación | `#004b8d` | `--ufro-blue` |
| Acción favorable/disponible | `#00875e` | `--ufro-green` |
| Advertencia/atención | `#f47920` | `--ufro-orange` |
| Error, rechazo o bloqueo | rojo Bootstrap/semántico | acompañar con texto |
| Fondo general | `#f8fafd` / `#f1f5f9` | `--bg-light` |
| Texto secundario | `#718096` | `--text-muted` |

Nunca comunicar un estado solo por color. Incluir icono, nombre del estado y explicación accesible.

## 2. Vocabulario canónico de interfaz

| Usar | Evitar |
| :--- | :--- |
| PDS origen | contrato origen, si no corresponde al nombre funcional |
| Solicitud de pago | expediente mensual, salvo definición aprobada |
| Cuota | mes, cuando la cuota cubra varios periodos |
| Periodo de ejecución | mes de pago |
| Mes solicitado de pago | fecha efectiva de pago |
| Monto aprobado PDS | monto disponible presupuestario |
| Monto solicitado | monto autorizado |
| Pendiente de saldo | rechazado, cuando la causal sea temporal |
| Observado | bloqueado, cuando puede corregirse |

## 3. Etiquetas de origen del dato

Las pantallas deben distinguir:

- **PDS:** dato heredado y no editable;
- **Calculado:** total o saldo derivado;
- **Ingresado en pago:** monto, periodo solicitado, motivo;
- **Externo:** SISPER, FIN21, documental o Tesorería;
- **Pendiente de validación:** fuente no disponible o regla no ejecutada.

## 4. Estados visibles

Mostrar tres chips o zonas separadas cuando corresponda:

1. estado global de la solicitud;
2. estado del detalle seleccionado;
3. estado acumulado de la cuota.

No mostrar un único estado ambiguo “Aprobado” sin indicar nivel y actor.

## 5. Mensajes

Formato recomendado:

```text
[resultado] + [objeto afectado] + [causa] + [acción esperada]
```

Ejemplo: “No es posible enviar la cuota 2 de Ana Pérez porque está incluida en otra solicitud activa. Actualice la grilla o retire el detalle.”

Evitar mensajes genéricos como “Error”, “No disponible” o “No tiene fondos” sin monto, ítem, momento y acción siguiente.

## 6. Componentes esperados por vista

### PP01

- buscador de PDS;
- cabecera origen de solo lectura;
- resumen financiero;
- grilla de funcionarios/cuotas;
- editor de detalle;
- evidencias;
- validaciones y confirmación de envío.

### PP02

- bandeja y SLA;
- cabecera/historial;
- navegación por detalles;
- matriz de reglas;
- visor de evidencias;
- causal/comentario;
- resolución individual y global.

### PP03

- bandeja financiera;
- agrupación por imputación;
- saldo inicial/comprometido/remanente;
- decisión por detalle;
- monto autorizado;
- transacción y fecha;
- resumen de cierre mixto.

## 7. Estados de definición en maquetas

Cuando una función dependa de una decisión abierta, marcarla como:

- **Propuesta funcional**;
- **Pendiente de confirmación**;
- **Dato simulado**.

Los objetos de `mock_data_pagos.js` son DTO de maqueta y no nombres físicos de tablas.

## 8. Accesibilidad y consistencia

- contraste suficiente;
- foco visible y navegación con teclado;
- etiquetas asociadas a campos;
- tablas con encabezados;
- confirmaciones para acciones irreversibles;
- fechas en formato claro y montos con moneda;
- misma etiqueta y color para un estado en las tres vistas;
- diseño responsivo sin ocultar causal o estado.
