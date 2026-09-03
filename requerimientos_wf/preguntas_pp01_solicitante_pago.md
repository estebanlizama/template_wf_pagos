# Banco de preguntas — PP01 Solicitante de Pago

**Uso:** taller funcional con PO, responsables de centro de costo, DGDP, Finanzas y arquitectura.  
**Regla:** una respuesta informal se registra como preliminar hasta tener responsable, fecha y evidencia.

## 1. Acceso y búsqueda

| ID | Pregunta | Respuesta preliminar | Dato/decisión que produce | Dueño |
| :--- | :--- | :--- | :--- | :--- |
| Q-PP01-001 | ¿Quién puede iniciar un pago: titular, delegado, ambos o sustituto? | Responsable/delegado. | regla de autorización y delegación | PO |
| Q-PP01-002 | ¿La autorización se limita a centro de costo, proyecto, unidad o PDS? | Centro/proyecto. | filtro y control de acceso | PO/Seguridad |
| Q-PP01-003 | ¿Cuál es el criterio principal de búsqueda? | Resolución exenta/externa. | filtros obligatorios | Usuario negocio |
| Q-PP01-004 | ¿Qué estados exactos habilitan una PDS? | Formalizada/firmada. | catálogo de elegibilidad | DGDP |
| Q-PP01-005 | ¿Se pueden pagar PDS históricas creadas fuera del nuevo workflow? | Pendiente. | migración/compatibilidad | PO/BDD |
| Q-PP01-006 | ¿Cómo se informa una PDS no habilitada? | Mostrar motivo. | mensaje y código de bloqueo | UX/Negocio |

## 2. Funcionarios, periodos y cuotas

| ID | Pregunta | Respuesta preliminar | Dato/decisión que produce | Dueño |
| :--- | :--- | :--- | :--- | :--- |
| Q-PP01-007 | ¿Se muestran todos los funcionarios o solo los seleccionables? | Todos; seleccionar solo vigentes y pendientes. | grilla e histórico | PO |
| Q-PP01-008 | ¿Cuándo se crea `sg_fume`: resolución, borrador o envío? | Recomendado en pago; sin ratificar. | evento de creación | PO/Arquitectura |
| Q-PP01-009 | ¿Quién define cantidad y monto base de cuotas? | Pendiente. | responsable y pantalla | PO |
| Q-PP01-010 | ¿Una cuota puede cubrir varios meses o un hito? | Debe soportarse técnicamente. | cardinalidad de cobertura | Negocio |
| Q-PP01-011 | ¿Se permiten varios funcionarios en una solicitud? | Sí, preliminar. | cardinalidad | PO |
| Q-PP01-012 | ¿Se permiten varias cuotas/meses del mismo funcionario? | Sí. | selección múltiple | PO |
| Q-PP01-013 | ¿Se mezclan meses atrasados y actual? | Sí si cumplen reglas. | regla retroactiva | DGDP |
| Q-PP01-014 | ¿Existe máximo de cuotas por actividad, PDS o año? | Hay referencias no ratificadas. | límite normativo | DGDP |
| Q-PP01-015 | ¿Qué estado hace una cuota seleccionable? | Disponible; pendiente saldo después de liberación. | máquina de estados | Negocio/BDD |

## 3. Monto y saldo

| ID | Pregunta | Respuesta preliminar | Dato/decisión que produce | Dueño |
| :--- | :--- | :--- | :--- | :--- |
| Q-PP01-016 | ¿El sistema propone monto o el usuario lo ingresa? | Usuario puede ajustar. | campo editable y valor inicial | PO |
| Q-PP01-017 | ¿Se permite pago parcial? | Sí, con motivo. | `motivo_ajuste` y saldo | PO/DGDP |
| Q-PP01-018 | ¿Quién decide reducción por ausencia? | Solicitante propone; DGDP revisa. | responsabilidad y validación | DGDP |
| Q-PP01-019 | ¿Un producto cumplido permite pago total pese a licencia parcial? | Caso mencionado; falta regla. | excepción y evidencia | DGDP |
| Q-PP01-020 | ¿Qué tope se valida y a qué fecha? | Pendiente. | fuente/fecha/fórmula | DGDP |
| Q-PP01-021 | ¿La falta de saldo bloquea guardar, enviar o solo pagar? | Reintento permitido; punto exacto pendiente. | severidad por etapa | Finanzas |
| Q-PP01-022 | ¿El borrador reserva presupuesto? | Pendiente; recomendación no. | concurrencia | Finanzas/Arquitectura |
| Q-PP01-023 | ¿Se agrupa el saldo por UF+CC+ítem? | Recomendación técnica sí. | contrato del PA | Finanzas |
| Q-PP01-024 | ¿Cómo se validan ítems/proyectos globales? | Pendiente. | ruta alternativa a FIN21 | Finanzas |

## 4. Evidencias y ejecución

| ID | Pregunta | Respuesta preliminar | Dato/decisión que produce | Dueño |
| :--- | :--- | :--- | :--- | :--- |
| Q-PP01-025 | ¿La evidencia pertenece a funcionario, cuota, periodo o detalle? | Funcionario+periodo; agregar detalle para intento. | FK y nivel documental | DGDP |
| Q-PP01-026 | ¿Qué evidencias exige cada tipo de prestación? | Pendiente. | catálogo | DGDP/Unidad |
| Q-PP01-027 | ¿Formato, tamaño, firma y vigencia por tipo? | Pendiente. | metadatos y validación | Documental |
| Q-PP01-028 | ¿Un documento puede respaldar varios detalles? | Pendiente. | relación N:M | DGDP |
| Q-PP01-029 | ¿Cómo se reemplaza una evidencia? | Mantener versión anterior no vigente. | versionamiento | Documental |
| Q-PP01-030 | ¿Quién certifica ejecución: solicitante o Jefatura? | Pendiente S0-008. | etapa/actor/evidencia | PO/DGDP |
| Q-PP01-031 | ¿Se registran horas reales por cuota en `sg_fuc2`? | Según modalidad; confirmar. | obligatoriedad y cobertura | DGDP |

## 5. Borrador, envío y concurrencia

| ID | Pregunta | Respuesta preliminar | Dato/decisión que produce | Dueño |
| :--- | :--- | :--- | :--- | :--- |
| Q-PP01-032 | ¿Se permite guardar sin detalles? | Antes se indicó que sí; ratificar. | precondición de guardado | PO |
| Q-PP01-033 | ¿Cuándo se crea la cabecera? | Al guardar explícitamente. | evento y auditoría | PO |
| Q-PP01-034 | ¿Quién puede editar un borrador? | Pendiente. | ownership | PO/Seguridad |
| Q-PP01-035 | ¿El borrador bloquea cuota? | Respuesta previa: no; requiere regla de conflicto al enviar. | reserva y concurrencia | Arquitectura |
| Q-PP01-036 | ¿Cuánto dura y cómo caduca? | Pendiente. | limpieza lógica | PO |
| Q-PP01-037 | Si un detalle falla, ¿se bloquea todo o se permite excluirlo? | Se ha propuesto excluir el detalle. | atomicidad funcional | PO |
| Q-PP01-038 | ¿Qué confirmación muestra el envío? | Pendiente. | declaración del usuario | UX/Legal |
| Q-PP01-039 | ¿Cuál es la etapa siguiente: Jefatura o DGDP? | Pendiente S0-008. | transición | PO/DGDP |

## 6. Devolución, anulación y reintento

| ID | Pregunta | Respuesta preliminar | Dato/decisión que produce | Dueño |
| :--- | :--- | :--- | :--- | :--- |
| Q-PP01-040 | ¿Una observación individual devuelve toda la solicitud? | Respuestas anteriores son contradictorias. | estado global/detalle | PO/DGDP |
| Q-PP01-041 | ¿Qué puede editarse al corregir? | Solo monto, selección y evidencia de pago. | permisos por campo | PO |
| Q-PP01-042 | ¿Se puede agregar/quitar detalle al corregir? | Quitar funcionario/cuota fue aceptado; agregar pendiente. | vigencia de detalle | PO |
| Q-PP01-043 | ¿Anular requiere motivo y confirmación? | Pendiente; recomendado sí. | causal/auditoría | PO |
| Q-PP01-044 | ¿Anular libera inmediatamente cuota y saldo? | Debe definirse por estado. | reversión | Finanzas/BDD |
| Q-PP01-045 | ¿Pendiente saldo se reintenta en la misma solicitud o una nueva? | Reintento manual; contenedor pendiente. | identidad de intento | Finanzas |
| Q-PP01-046 | ¿Qué datos se reutilizan al reintentar? | PDS, cuota y evidencia vigente. | precarga | PO |

## 7. Cierre del taller PP01

Para cada pregunta se debe registrar:

```text
respuesta
estado: preliminar | aprobada | descartada
responsable que responde
fecha
fundamento o evidencia
impacto en flujo
datos afectados
reglas y estados afectados
tarjetas ClickUp afectadas
acción siguiente y fecha compromiso
```

PP01 queda listo para desarrollo solo cuando Q-PP01-001, 004, 008, 009, 015, 017, 021, 025, 030, 035, 037, 039, 040 y 045 estén aprobadas.
