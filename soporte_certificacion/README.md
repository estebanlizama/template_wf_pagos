# Soporte para la certificación de pagos

- `06_marcas_du09_centro_costo.sql`: consulta de solo lectura sobre vigencia y
  marcas DU09 de los centros asociados a prestaciones archivadas. Cualquier
  ajuste se gestiona con Finanzas.
- `07_sg_ecuo_descripciones.sql`: ajuste opcional para instalaciones que ya
  tienen los códigos vigentes y solo necesitan corregir sus etiquetas.
  La carga estándar `datos_base/07_sg_ecuo_estados_cuota.sql` ya aplica las mismas etiquetas.

Estas herramientas no forman parte de la carga inicial de datos fijos.
