# `sisper_db..sp_easi` — estados de asistencia

Catálogo. Clasifica **cómo terminó** un día en `sp_as01`.

---

## Estructura

| Columna | Qué es |
| :--- | :--- |
| `cod_estasi` | PK |
| `des_estasi` | descripción |

---

## Contenido

| cod | Descripción | Qué significa |
| :---: | :--- | :--- |
| **0** | Estado inicial | El día existe pero no hubo marcaje. Fin de semana, feriado, ausencia o simplemente no marcó |
| **1** | Editado | Alguien corrigió el registro a mano |
| **2** | Completo | Marcó entrada **y** salida |
| **3** | Incompleto | Marcó sólo una de las dos |
| **4** | Error | El registro es inválido |

---

## Lo que cada estado significa para el WF de pagos

| Estado | ¿El día es acreditable? |
| :---: | :--- |
| 2 Completo | **Sí** — hay entrada y salida, el tiempo es verificable |
| 3 Incompleto | **Ambiguo** — marcó una vez, no se sabe cuánto estuvo |
| 0 Estado inicial | **No** — salvo que sea feriado o fin de semana, es inasistencia |
| 1 Editado | **Depende** — hubo intervención manual; conviene revisarlo aparte |
| 4 Error | **No** — el dato no sirve |

### El 3 Incompleto es el caso que hay que decidir

Aparece con frecuencia en los datos reales, en dos formas:

```
marcó entrada 08:23, no marcó salida
no marcó entrada, marcó salida 17:49
```

Para acreditar ejecución de una prestación hay que definir si cuenta, si no cuenta, o si queda a
criterio de DGDP. **No hay forma de deducir cuánto tiempo estuvo.**

### El 1 Editado merece atención

Un registro editado a mano no viene del reloj. Si el WF de pagos va a usar el biométrico como
evidencia objetiva, conviene distinguirlo y decidir si se acepta igual.

---

## Observación de los datos

En la muestra revisada sólo aparecen los estados **0, 2 y 3**. Los estados **1 Editado** y
**4 Error** existen en el catálogo pero no en los datos de prueba, así que su comportamiento
real no está verificado.

---

## Relación

```
sp_as01 ──── cod_estasi ────► sp_easi
```
