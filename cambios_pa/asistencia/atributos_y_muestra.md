# Consulta de asistencia — atributos y muestra de datos

---

## Tabla 1 · Atributos que devuelve la consulta

| # | Atributo | Origen | Tipo | Para qué sirve |
| :--: | :--- | :--- | :--- | :--- |
| 1 | `cod_asist` | `sp_as01.cod_asist` | int | Identificador del registro de asistencia. Permite correlacionar la fila con sus ausencias y justificaciones |
| 2 | `fecha` | `sp_as01.f_ent_o` | char(8) | Día del registro en formato `YYYYMMDD`, ordenable |
| 3 | `fec_asist` | `sp_as01.f_ent_o` | datetime | El mismo día como fecha, para cálculos |
| 4 | `cod_diasem` | calculado | tinyint | Día de la semana, 1 = Lunes … 7 = Domingo |
| 5 | `des_diasem` | calculado | varchar | Nombre del día |
| 6 | `hora_marca_ent` | `sp_as01.f_entrada` | char(5) | **Marca real de entrada** registrada por el reloj |
| 7 | `hora_marca_sal` | `sp_as01.f_salida` | char(5) | **Marca real de salida** |
| 8 | `hora_turno_ent` | `sp_as01.hora_ent_o` | char(5) | **Horario de entrada que le correspondía** ese día |
| 9 | `hora_turno_sal` | `sp_as01.hora_sal_o` | char(5) | **Horario de salida que le correspondía** |
| 10 | `min_marcados` | calculado | int | Minutos entre las dos marcas. Es el tiempo que estuvo |
| 11 | `min_turno` | calculado | int | Minutos que dura el turno. Es el tiempo que debía estar |
| 12 | `cod_turno` | `sp_as01.cod_turno` | int | Turno asignado ese día |
| 13 | `ver_hora` | `sp_turn.ver_hora` | char(1) | `S` = el marcaje es exigible · `N` = sin obligación de marcar |
| 14 | `cod_estasi` | `sp_as01.cod_estasi` | tinyint | Estado del día: 0 inicial · 1 editado · 2 completo · 3 incompleto · 4 error |
| 15 | `des_estasi` | `sp_easi.des_estasi` | varchar | Descripción del estado |
| 16 | `tie_ausenc` | derivado | char(1) | `S` si el día tiene ausencias registradas |
| 17 | `res_ausen` | `sp_as21` + `sp_eaus` | varchar | Motivo o motivos de la ausencia, separados por ` \| ` |
| 18 | `tie_justif` | derivado | char(1) | `S` si el día tiene justificación |
| 19 | `excusa` | `sp_as31` + `sp_tjus` + `sp_cjus` | varchar | Justificación como `tipo/categoría` |
| 20 | `es_feriado` | derivado | char(1) | `S` si el día está en el calendario institucional |
| 21 | `cod_tipfer` | `es_cfer.cod_tipfer` | tinyint | 1 Feriado Nacional · 2 Feriado Universitario · 3 Suspensión Actividades Lectivas |
| 22 | `des_tipfer` | `es_tfer.des_tipfer` | varchar | Descripción del feriado |
| 23 | `min_atraso` | calculado | int | Minutos de atraso sobre el turno, descontada la tolerancia. 0 = llegó a tiempo |
| 24 | `min_anticip` | calculado | int | Minutos de salida anticipada, misma lógica |
| 25 | `tol_entrad` | `sp_pasi.tol_entrad` | int | Tolerancia institucional de entrada, en minutos |
| 26 | `tol_salida` | `sp_pasi.tol_salida` | int | Tolerancia institucional de salida |

---

## Tabla 2 · Resultado — enero a marzo de 2016

Turno 08:30–17:20 (530 minutos). `cod_turno` = 1 y `ver_hora` = `S` en todas las filas.
`tol_entrad` y `tol_salida` = 5. Sin ausencias ni justificaciones en el periodo.

| cod_asist | fecha | día | marca ent | marca sal | min marc | estado | feriado | atraso | anticip |
| ---: | :--- | :--- | :--- | :--- | ---: | :--- | :--- | ---: | ---: |
| 6313 | 20160101 | Viernes | | | | Estado inicial | **Nacional** | | |
| 6314 | 20160102 | Sabado | | | | Estado inicial | | | |
| 6315 | 20160103 | Domingo | | | | Estado inicial | | | |
| 6316 | 20160104 | Lunes | 08:32 | | | **Incompleto** | | 0 | |
| 6317 | 20160105 | Martes | 08:32 | 17:24 | 532 | Completo | | 0 | 0 |
| 6318 | 20160106 | Miercoles | | | | Estado inicial | | | |
| 6319 | 20160107 | Jueves | 08:29 | | | **Incompleto** | | 0 | |
| 6320 | 20160108 | Viernes | 08:31 | **18:05** | 573 | Completo | | 0 | 0 |
| 6321 | 20160109 | Sabado | | | | Estado inicial | | | |
| 6322 | 20160110 | Domingo | | | | Estado inicial | | | |
| 6323 | 20160111 | Lunes | 08:17 | **17:50** | 573 | Completo | | 0 | 0 |
| 6324 | 20160112 | Martes | 08:21 | 17:37 | 555 | Completo | | 0 | 0 |
| 6325 | 20160113 | Miercoles | **08:39** | 17:22 | 522 | Completo | | **4** | 0 |
| 6326 | 20160114 | Jueves | 08:33 | 17:40 | 547 | Completo | | 0 | 0 |
| 6327 | 20160115 | Viernes | **08:43** | 17:36 | 532 | Completo | | **8** | 0 |
| 6328 | 20160116 | Sabado | | | | Estado inicial | | | |
| 6329 | 20160117 | Domingo | | | | Estado inicial | | | |
| 6330 | 20160118 | Lunes | 08:27 | 17:26 | 538 | Completo | | 0 | 0 |
| 6331 | 20160119 | Martes | 08:34 | 17:24 | 529 | Completo | | 0 | 0 |
| 6332 | 20160120 | Miercoles | 08:29 | 17:25 | 536 | Completo | | 0 | 0 |
| 6333 | 20160121 | Jueves | 08:24 | 17:30 | 546 | Completo | | 0 | 0 |
| 6334 | 20160122 | Viernes | 08:27 | | | **Incompleto** | | 0 | |
| 6335 | 20160123 | Sabado | | | | Estado inicial | | | |
| 6336 | 20160124 | Domingo | | | | Estado inicial | | | |
| 6337 | 20160125 | Lunes | | | | Estado inicial | **Universitario** | | |
| 6338 | 20160126 | Martes | | | | Estado inicial | **Universitario** | | |
| 6339 | 20160127 | Miercoles | | | | Estado inicial | **Universitario** | | |
| 6340 | 20160128 | Jueves | | | | Estado inicial | **Universitario** | | |
| 6341 | 20160129 | Viernes | | | | Estado inicial | **Universitario** | | |
| 6342 | 20160130 | Sabado | | | | Estado inicial | **Universitario** | | |
| 6343 | 20160131 | Domingo | | | | Estado inicial | **Universitario** | | |
| 6344 | 20160201 | Lunes | | | | Estado inicial | **Universitario** | | |
| 6345 | 20160202 | Martes | | | | Estado inicial | **Universitario** | | |
| 6346 | 20160203 | Miercoles | | | | Estado inicial | **Universitario** | | |
| 6347 | 20160204 | Jueves | | | | Estado inicial | **Universitario** | | |
| 6348 | 20160205 | Viernes | | | | Estado inicial | **Universitario** | | |
| 6349 | 20160206 | Sabado | | | | Estado inicial | **Universitario** | | |
| 6350 | 20160207 | Domingo | | | | Estado inicial | **Universitario** | | |
| 6351 | 20160208 | Lunes | | | | Estado inicial | **Universitario** | | |
| 6352 | 20160209 | Martes | | | | Estado inicial | **Universitario** | | |
| 6353 | 20160210 | Miercoles | | | | Estado inicial | **Universitario** | | |
| 6354 | 20160211 | Jueves | | | | Estado inicial | **Universitario** | | |
| 6355 | 20160212 | Viernes | | | | Estado inicial | **Universitario** | | |
| 6356 | 20160213 | Sabado | | | | Estado inicial | **Universitario** | | |
| 6357 | 20160214 | Domingo | | | | Estado inicial | **Universitario** | | |
| 6358 | 20160215 | Lunes | | | | Estado inicial | **Universitario** | | |
| 6359 | 20160216 | Martes | | | | Estado inicial | **Universitario** | | |
| 6360 | 20160217 | Miercoles | | | | Estado inicial | **Universitario** | | |
| 6361 | 20160218 | Jueves | | | | Estado inicial | **Universitario** | | |
| 6362 | 20160219 | Viernes | | | | Estado inicial | **Universitario** | | |
| 6363 | 20160220 | Sabado | | | | Estado inicial | **Universitario** | | |
| 6364 | 20160221 | Domingo | | | | Estado inicial | **Universitario** | | |
| 6365 | 20160222 | Lunes | 08:26 | 17:26 | 539 | Completo | | 0 | 0 |
| 6366 | 20160223 | Martes | 08:34 | **17:17** | 523 | Completo | | 0 | 0 |
| 6367 | 20160224 | Miercoles | 08:27 | | | **Incompleto** | | 0 | |
| 6368 | 20160225 | Jueves | 08:24 | 17:25 | 540 | Completo | | 0 | 0 |
| 6369 | 20160226 | Viernes | 08:31 | 17:31 | 539 | Completo | | 0 | 0 |
| 6370 | 20160227 | Sabado | | | | Estado inicial | | | |
| 6371 | 20160228 | Domingo | | | | Estado inicial | | | |
| 6372 | 20160229 | Lunes | **08:37** | 17:21 | 524 | Completo | | **2** | 0 |
| 6373 | 20160301 | Martes | | | | Estado inicial | | | |
| 6374 | 20160302 | Miercoles | 08:23 | 17:27 | 544 | Completo | | 0 | 0 |
| 6375 | 20160303 | Jueves | 08:29 | **17:01** | 511 | Completo | | 0 | **13** |
| 6376 | 20160304 | Viernes | 08:31 | **17:54** | 563 | Completo | | 0 | 0 |
| 6377 | 20160305 | Sabado | | | | Estado inicial | | | |
| 6378 | 20160306 | Domingo | | | | Estado inicial | | | |
| 6379 | 20160307 | Lunes | | 17:49 | | **Incompleto** | | | 0 |
| 6380 | 20160308 | Martes | 08:18 | 17:43 | 565 | Completo | | 0 | 0 |
| 6381 | 20160309 | Miercoles | 08:23 | 17:37 | 553 | Completo | | 0 | 0 |
| 6382 | 20160310 | Jueves | 08:21 | 17:32 | 550 | Completo | | 0 | 0 |
| 6383 | 20160311 | Viernes | 08:19 | **17:47** | 567 | Completo | | 0 | 0 |
| 6384 | 20160312 | Sabado | | | | Estado inicial | | | |
| 6385 | 20160313 | Domingo | | | | Estado inicial | | | |
| 6386 | 20160314 | Lunes | 08:27 | 17:29 | 542 | Completo | | 0 | 0 |
| 6387 | 20160315 | Martes | 08:30 | 17:33 | 543 | Completo | | 0 | 0 |
| 6388 | 20160316 | Miercoles | 08:18 | 17:25 | 546 | Completo | | 0 | 0 |
| 6389 | 20160317 | Jueves | 08:30 | 17:35 | 544 | Completo | | 0 | 0 |
| 6390 | 20160318 | Viernes | 08:23 | 17:28 | 544 | Completo | | 0 | 0 |
| 6391 | 20160319 | Sabado | | | | Estado inicial | | | |
| 6392 | 20160320 | Domingo | | | | Estado inicial | | | |
| 6393 | 20160321 | Lunes | 08:32 | 17:28 | 536 | Completo | | 0 | 0 |
| 6394 | 20160322 | Martes | 08:22 | 17:30 | 547 | Completo | | 0 | 0 |
| 6395 | 20160323 | Miercoles | 08:18 | 17:21 | 542 | Completo | | 0 | 0 |
| 6396 | 20160324 | Jueves | 08:24 | **17:51** | 567 | Completo | | 0 | 0 |
| 6397 | 20160325 | Viernes | | | | Estado inicial | **Nacional** | | |
| 6398 | 20160326 | Sabado | | | | Estado inicial | **Nacional** | | |
| 6399 | 20160327 | Domingo | | | | Estado inicial | | | |
| 6400 | 20160328 | Lunes | 08:28 | 17:25 | 536 | Completo | | 0 | 0 |
| 6401 | 20160329 | Martes | 08:22 | 17:28 | 545 | Completo | | 0 | 0 |
| 6402 | 20160330 | Miercoles | **08:37** | 17:40 | 542 | Completo | | **2** | 0 |
| 6403 | 20160331 | Jueves | 08:26 | 17:42 | 555 | Completo | | 0 | 0 |

**91 filas.** Una por cada día calendario del periodo, sin excepción.
