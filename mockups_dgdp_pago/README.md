# Mockups de Referencia — Rol DGDP (Flujo de Pagos PDS)

Esta carpeta contiene los mockups visuales de alta fidelidad diseñados para la implementación del rol **DGDP (Dirección de Gestión y Desarrollo de Personas)** en el módulo de pagos de Prestación de Servicios (D.U. 009/2026).

---

## 📸 Catálogo de Vistas

### 1. `01_dgdp_bandeja_pagos.jpg` — Bandeja de Solicitudes de Pago
* **KPIs Superiores:** Solicitudes en revisión, monto total por aprobar, cuotas con alertas y tiempos de respuesta.
* **Filtros Avanzados:** Centro de Costo, N° Resolución Exenta, RUT Funcionario, Estado, Rango de fechas.
* **Tabla de Gestión:** Lista de cuotas con semáforo de validaciones en tiempo real (Licencia médica, Tope 50%, Saldo CC) y accesos directos al expediente.

---

### 2. `02_dgdp_detalle_revision.jpg` — Expediente y Dictamen de Pago
* **Encabezado y Edición Rápida:** Acciones directas para editar encabezados permitidos y dictaminar (`Aprobar para Finanzas`, `Observar con Causal`, `Rechazar`).
* **Antecedentes PDS y Resolución:** Número de resolución, vigencia, Jefe de Proyecto, Centro de Costo y saldo presupuestario disponible.
* **Detalle de la Cuota:** Visor integrado del documento PDF de justificación adjunto (`MySecGen.sg_evid_<año>`) y monto solicitado.

---

### 3. `03_dgdp_control_biometrico_calendario.jpg` — Control Biométrico y Jornada en Calendario
* **Ficha del Funcionario:** Datos de contrato (44h, estamento, departamento).
* **Calendario Mensual Interactivo:** Visualización codificada por colores de turnos regulares vs. tramos compensados de PDS (`sg_fuc2`).
* **Comparativa de Cumplimiento:** Barra de horas comprometidas en PDS vs. efectivamente compensadas (100% de cumplimiento).
* **Historial de Marcas de Reloj Control:** Registro detallado de entradas, salidas y tramos de compensación fuera de jornada ordinaria.

---

### 4. `04_dgdp_validaciones_topes_concurrencia.jpg` — Motor de Validaciones Normativas D.U. 009/2026
* **Semáforo Normativo:**
  * Licencias Médicas SISPER (sin registros activos).
  * Permisos Sin Goce de Sueldo (aprobado).
  * Tope del 50% mensual (cálculo de sueldo base vs. asignación).
  * Vigencia y disponibilidad presupuestaria del Centro de Costo.
* **Historial y Comparativa de Prestaciones Previas:** Matriz de todas las solicitudes PDS del funcionario en el año 2026 para detección de alertas de concurrencia.
