# Correo — consulta sobre registro de asistencia

Texto para acompañar las dos tablas. Los marcadores indican dónde va cada una.

---

Estimados Don Alex, Don Jaime:

En el marco del proceso de pago de prestaciones de servicios (D.U. 009/2026) estamos evaluando
usar el registro de asistencia para acreditar que el funcionario ejecutó efectivamente las horas
comprometidas en la resolución.

Adaptamos el procedimiento que usa el módulo de calificaciones para poder consultar por rango de
fechas. Estos son los atributos que obtenemos:

> **[ TABLA 1 — atributos ]**

Y este es el resultado para un funcionario, entre enero y marzo de 2016:

> **[ TABLA 2 — resultado ]**

Con estos datos podemos ver qué días trabajó y cuánto tiempo estuvo. Lo que no logramos
determinar es lo siguiente.

---

**1. A qué corresponde el tiempo trabajado fuera del turno**

Una prestación compromete horas específicas —por ejemplo, lunes y miércoles de 18:00 a 20:00— y
cuando esas horas se ejecutan dentro de la jornada, deben compensarse fuera de ella.

En el registro vemos que el 08/01 la salida fue a las 18:05 con turno hasta las 17:20, pero no
sabemos si esos 45 minutos corresponden a la prestación, a una compensación o a carga habitual.

¿Existe alguna marca o clasificación que permita atribuir ese tiempo? Si no la hay, entendemos
que la atribución debe venir de lo declarado previamente en la resolución, y que el registro sólo
confirma que el tiempo existió. Quisiéramos validar ese criterio con ustedes.

**2. Horario flexible**

¿Existe una ventana de entrada flexible y cuál es su rango?

Lo consultamos porque cambia el cálculo. En otro periodo vemos un día con entrada 09:19 y salida
18:24: salió 64 minutos después del turno, pero llegó 49 tarde, de modo que el excedente real
serían 15 minutos.

¿Las columnas `min_atraso`, `min_adelan` y `min_extras` de `sp_as01` ya consideran esa ventana, o
sólo aplican la tolerancia de 5 minutos configurada en `sp_pasi`?

**3. Licencias médicas, permisos y vacaciones**

El catálogo `sp_eaus` contempla lo que necesitamos —licencias médicas, permiso sin goce de
sueldo, vacaciones—, pero en el ambiente de prueba la tabla `sp_as21` no tiene registros para el
funcionario consultado, por lo que no pudimos verificar cómo llegan esos datos.

¿Se registran automáticamente o requieren carga manual? ¿Con qué oportunidad quedan disponibles?

Es relevante porque el decreto no permite pagar periodos cubiertos por licencia médica o permiso
sin goce, y necesitamos determinarlo con precisión de días para calcular el descuento
proporcional.

**4. Estado Incompleto y registros duplicados**

Vemos días con una sola marca —el 07/03 registra salida 17:49 sin marca de entrada—. ¿Existe
algún proceso posterior que complete esos registros?

Además, entre el 01 y el 11 de septiembre de 2016 aparecen **dos registros por día** para el
mismo funcionario, con horarios de turno distintos. ¿A qué corresponde y cuál debe considerarse
válido?

**5. Si esta es la vía correcta**

El procedimiento del que partimos pertenece al proceso de calificaciones. Nuestro uso es
distinto: consultar la asistencia de cada funcionario incluido en una prestación de servicios,
acotada al periodo de ejecución que se está pagando.

¿Es correcto usar esta misma fuente para ese propósito, o existe otro procedimiento o vía más
apropiada que debiéramos considerar?

Consultamos también porque el volumen es distinto: haríamos una consulta por funcionario y rango
de fechas cada vez que se solicita un pago, desde `secgen_db`. Quisiéramos saber si eso presenta
alguna restricción de acceso o de rendimiento que debamos tener en cuenta.

---

Quedamos atentos, y por supuesto disponibles para revisarlo en conjunto si resulta más práctico.

Saludos cordiales,
