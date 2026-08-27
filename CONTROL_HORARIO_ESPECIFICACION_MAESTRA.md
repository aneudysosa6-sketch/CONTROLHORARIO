> **ACTUALIZACIÓN NORMATIVA TERMINAL-ONLY 2026-08-25**
>
> La aplicación Android queda limitada exclusivamente a registrar jornadas desde un Terminal autorizado. Las secciones antiguas que describan Login, dashboards, portales, administración o enrolamiento facial del empleado dentro de Android quedan sustituidas por [docs/TERMINAL_ONLY_FACE_QR.md](docs/TERMINAL_ONLY_FACE_QR.md). Toda administración y todo enrolamiento facial por QR se realizan en la Web.
# CONTROL HORARIO — ESPECIFICACIÓN FUNCIONAL MAESTRA

**Estado:** APROBADO
**Fecha de consolidación:** 2026-08-22
**Uso:** fuente de verdad para continuar el desarrollo en otro chat, con Codex o con cualquier agente de programación.

## 0. Reglas de uso

- Este documento contiene las decisiones funcionales aprobadas.
- Si el código actual contradice este documento, la especificación funcional manda salvo cambio explícito posterior del usuario.
- No inventar reglas nuevas si ya existe una decisión aquí.
- Si falta una decisión realmente nueva, preguntar solo por ese punto.
- Toda función administrativa debe proteger UI, rutas y acciones.
- Los permisos deben respetar el alcance por sucursal/departamento cuando aplique.
- Evitar duplicar pantallas y reportes.
- Conservar históricos cerrados sin recalcularlos con datos actuales, salvo que una regla lo indique.

# 1. Estructura general de módulos

1. Inicio / Dashboard
2. Portal del empleado
3. Recursos Humanos
4. Asistencia
5. Nómina / Pagos
6. Reportes
   - Asistencia
   - Nómina
7. Configuración general
   - Empresa
   - Sucursales y Departamentos
   - Roles y permisos
   - Dispositivos
   - Mensajes a empleados
8. Seguridad y auditoría
9. Mi cuenta / Sesión

Reglas:
- Portal del empleado siempre permanece visible para una cuenta perteneciente a un empleado, aunque luego reciba otro rol.
- Las pantallas adicionales autorizadas por el rol aparecen debajo.
- Los módulos sin permiso no se muestran y tampoco pueden abrirse por ruta directa.
- Terminal facial vive dentro de Dispositivos.
- Mensajes a empleados va justo debajo de Dispositivos.
- Empleados vive dentro de Recursos Humanos.
- Reportes solo tendrá Asistencia y Nómina.

# 2. Roles, permisos y alcance

## 2.1 Principio
- Las acciones dependen de permisos específicos.
- El rol agrupa permisos.
- Los permisos sensibles aparecen en una sección visual “Permisos críticos”.
- Los permisos dependientes activan automáticamente sus requisitos básicos.

## 2.2 Un solo rol
- Cada usuario tiene un solo rol principal.
- Todo empleado nuevo recibe el rol base EMPLEADO.
- El acceso al Portal del empleado es una capacidad base que permanece aunque cambie el rol.

## 2.3 Rol EMPLEADO
- Protegido.
- No se modifican sus permisos base.
- Es el rol automático al crear un empleado.

## 2.4 Rol ADMINISTRADOR
- Protegido.
- Tiene todos los permisos.
- Al asignarlo, los permisos se aplican inmediatamente.
- Al quitarlo, pierde inmediatamente esos permisos y toma los del nuevo rol.

## 2.5 Roles personalizados
- Crear desde cero o copiar otro.
- Duplicar copia permisos, no usuarios.
- Editables: nombre, descripción y permisos.
- Cambios aplican inmediatamente a sus usuarios.
- No se eliminan; se desactivan.
- Al reactivar conservan permisos anteriores.
- Roles inactivos se muestran al final con etiqueta INACTIVO.
- Un rol con usuarios no puede desactivarse hasta reasignarlos.
- Al abrir un rol se ve la lista de usuarios y se puede cambiarles el rol desde ahí.
- Buscador por nombre de rol y nombre de usuario.

## 2.6 Alcance de supervisores
Flujo:
Usuario → Sucursal(es) → departamentos de cada sucursal → selección múltiple.

Reglas:
- Puede tener varias sucursales.
- Puede seleccionar uno o varios departamentos por sucursal.
- Su alcance final es la suma de esos departamentos.
- Solo puede ver/modificar empleados dentro de su alcance y según permisos.
- Si se le quita un departamento, pierde acceso inmediatamente.
- Si un empleado cambia a un departamento fuera de su alcance, pierde acceso inmediatamente.
- No existe “permiso global” para supervisor.
- La pantalla administrativa de Asistencia definida como de alcance total tendrá alcance total para el usuario administrativo autorizado.

# 3. Recursos Humanos — crear empleado

## 3.1 Flujo por pasos
1. Datos personales
2. Datos laborales
3. Pago
4. Acceso / Rol
5. Revisar empleado
6. Confirmar creación

La pantalla Revisar empleado permite entrar de nuevo a cualquier sección antes de crear definitivamente.

## 3.2 Código
- Automático.
- 6 dígitos.
- Aleatorio/no secuencial.
- Puede tener ceros a la izquierda.
- Único.
- Validar colisión.

Ejemplo: 080301.

## 3.3 Usuario/correo/contraseña
Si código = 080301:
- Usuario/correo: usuario@example.invalid
- Contraseña inicial: definida mediante el flujo seguro de aprovisionamiento; no se publican valores.
- Restablecer contraseña usa un flujo seguro y obliga cambio en el siguiente acceso.

## 3.4 Datos personales
Obligatorios:
- Nombres
- Apellidos
- Teléfono

Opcionales:
- Cédula
- Fecha de nacimiento
- Dirección
- Contacto de emergencia
- Teléfono de emergencia
- Foto del empleado

La foto del perfil es independiente de la biometría facial.

## 3.5 Datos laborales
- Fecha de ingreso obligatoria.
- Se escribe manualmente.
- Después queda fijada.
- Solo acción especial autorizada de RR. HH./Administración puede cambiarla.
- Departamento.
- Supervisor derivado del departamento.
- No existen cargos/puestos; solo departamentos.

## 3.6 Sucursal y departamento
- Un empleado puede registrar asistencia en cualquier sucursal cuando el terminal está en Uso general.
- El departamento determina principalmente el supervisor.
- Los terminales configurados Por departamentos sí pueden limitar quién marca.

## 3.7 Horario semanal
Lo llena el supervisor.

Campo:
- Horas de pausa/almuerzo permitidas, manual.
- Se usa solo para alerta por exceso de pausa, no para pago.

Tabla:
Día | Entrada | Salida | Día libre

Días:
Lunes, Martes, Miércoles, Jueves, Viernes, Sábado, Domingo.

## 3.8 Activación final
Orden definitivo:
1. Crear empleado.
2. Supervisor asigna horario.
3. Supervisor asigna día libre.
4. Empleado registra rostro.
5. Servidor confirma el rostro.
6. Empleado pasa automáticamente a ACTIVO.

Si intenta registrar rostro antes de horario/día libre:
“SUPERVISOR DEBE ASIGNAR HORARIO Y DÍA LIBRE”
- rojo ↔ blanco
- 5 segundos
- volver a cámara

## 3.9 Sueldo y pago
- Sueldo base mensual.
- Frecuencia/forma salarial: Mensual, Quincenal, Semanal o Diario.
- Forma de entrega por defecto: Efectivo.
- Puede cambiar a Transferencia.
- Transferencia exige Banco + Número de cuenta.
- Nómina usa la forma de pago vigente al cerrar.
- Valor hora extra: manual por empleado.
- Impuesto por quincena: monto fijo en perfil.

## 3.10 Rol al crear
- Se selecciona un rol.
- Predeterminado EMPLEADO.
- Un solo rol principal.
- Portal del empleado permanece aunque el rol cambie.

## 3.11 Ficha de ingreso
Generar al finalizar la creación:
- Código
- Nombre y datos
- Sueldo
- Usuario
- Contraseña inicial

Reglas:
- La ficha que contiene contraseña solo se imprime una vez al crear.
- Reimpresiones normales no incluyen contraseña.
- Un Administrador autorizado puede volver a visualizarla si el sistema conserva esa capacidad.

# 4. Perfil del empleado

Diseño:
- Resumen arriba: foto, nombre, código, departamento, supervisor, estado.
- Debajo: pestañas/desplegables.

Secciones:
- Datos personales
- Datos laborales
- Horario
- Salario y pago
- Acceso/Rol
- Rostro
- Documentos
- Licencias
- Vacaciones
- Préstamos
- Historial

Acciones sensibles dependen de permisos.

## 4.1 Desactivar
No borrar.
Guardar:
- Fecha de salida
- Motivo
- Usuario que desactivó
- Observación opcional

Efectos:
- No login
- No jornadas
- Rostro deja de usarse
- Históricos se conservan

## 4.2 Reactivar
- Reactivar misma ficha.
- Conserva código, historial, usuario y datos.

## 4.3 Sueldo
Cada cambio guarda:
- sueldo anterior
- sueldo nuevo
- fecha efectiva

## 4.4 Departamento
- Cambio directo.
- Sin historial adicional obligatorio.
- Nuevo supervisor aplica inmediatamente.

## 4.5 Rol
- Reemplazo inmediato.
- Permisos inmediatos.

## 4.6 Datos personales
- Actualización directa.
- Sin historial adicional obligatorio.

## 4.7 Eliminar rostro
- Eliminar plantilla.
- Estado biométrico pasa a Rostro pendiente.
- No puede marcar facialmente hasta volver a registrarse.

## 4.8 Documentos
Tipos:
- Cédula
- Documentos laborales
- Certificados
- Licencias
- Otros

Subir/reemplazar/eliminar depende de permisos.

# 5. Licencias

Campos:
- Fecha inicio
- Fecha final
- Porcentaje manual
- Documento opcional

Cálculo:
Sueldo mensual ÷ 30 = salario diario
Salario diario × porcentaje = ganancia diaria por licencia

- Se usa el sueldo vigente al inicio de la licencia durante toda la licencia.
- Todos los días calendario cuentan, incluidos días libres.
- Solo días completos, nunca horas.

Efectos:
- Estado EN LICENCIA.
- No puede marcar jornada.
- Asistencia muestra LICENCIA.
- No cuenta como ausencia/tardanza.
- Solo genera ganancia de licencia.
- Al terminar vuelve a ACTIVO.

Modificar licencia activa:
- preguntar si recalcular desde el inicio o aplicar hacia adelante.

Cancelar:
- elimina todo lo generado por la licencia.

Nómina:
- cada período toma solo días incluidos en ese período.
- En fila principal de Pago no necesita columna especial.
- En detalle/volante puede mostrarse el valor monetario de Licencia.

# 6. Vacaciones

Mismo motor que Licencia pero concepto separado:
- Fecha inicio
- Fecha final
- Porcentaje manual
- Todos los días calendario
- Documento opcional
- Estado EN VACACIONES
- No marca jornada
- Asistencia muestra VACACIONES
- Vuelve a ACTIVO al terminar
- Historial de vacaciones anteriores

# 7. Asistencia y jornadas

## 7.1 Una jornada diaria
- Solo una jornada por día.
- Si ya FINALIZÓ, no puede iniciar otra.
- Mostrar “JORNADA YA FINALIZADA” 5 segundos y volver a cámara.

## 7.2 Eventos
1. INICIAR JORNADA
2. PAUSA
3. REANUDAR
4. FINALIZAR

Trabajando:
- PAUSA
- FINALIZAR

En pausa:
- solo REANUDAR

Pausas ilimitadas.

## 7.3 Pago de tiempo
- Solo tiempo realmente trabajado.
- Pausas nunca se pagan.
- Tiempo de pausa permitido en perfil solo sirve para alertas.

## 7.4 Exceso de pausa
- Incidencia en Asistencia.
- Supervisor la ve.
- No requiere revisión/observación.
- Sin penalización extra.
- El exceso simplemente no se paga.

## 7.5 Tardanza
- 0–10 min: tolerancia.
- >10 min y ≤1 hora: TARDANZA, puede iniciar.
- >1 hora: BLOQUEADO.

Bloqueado:
- no genera pago.
- pago empieza cuando se desbloquea y realmente inicia.
- si no lo desbloquean ese día: AUSENCIA, sin pago.
- bloqueo se elimina automáticamente al siguiente día.

Terminal:
“EMPLEADO BLOQUEADO”
- 5 segundos
- rojo ↔ blanco
- volver a cámara

## 7.6 Lista de bloqueados
Orden:
1. Jornada incompleta
2. Tardanza

Mostrar:
- Nombre
- Hora de entrada programada
- Tiempo de tardanza
- Etiqueta motivo
- Acción

Colores:
- TARDANZA amarillo
- JORNADA INCOMPLETA rojo

Supervisor:
- solo sus departamentos
- buscador por nombre
- botón Desbloquear empleado
- desbloqueo inmediato
- empleado desaparece de lista
- todos los terminales reciben el cambio

Contador:
- Jornadas incompletas: X
- Tardanzas: Y
Se actualiza al volver a entrar.

## 7.7 Salida temprana
- Hasta 10 min antes: sin alerta.
- >10 min antes: incidencia.
- Se permite Finalizar.
- Solo se paga tiempo real.

## 7.8 Hora normal
Valor hora normal = Sueldo mensual ÷ 30 ÷ 8

Ejemplo:
30,000 ÷ 30 = 1,000
1,000 ÷ 8 = 125/hora

Minutos se pagan proporcionalmente.

## 7.9 Horas extra
- Después de 8 horas realmente trabajadas al día.
- Pausas excluidas.
- Valor hora extra manual por empleado.
- Minutos se pagan proporcionalmente.
- Licencia/Vacaciones no generan extra.

## 7.10 Día libre trabajado
- Puede trabajar normalmente.
- Sin aviso especial.
- Primeras 8 horas normales.
- Después extras.

# 8. Festivos

En Pago:
1. Cantidad de días festivos.
2. Abrir exactamente esa cantidad de casillas de fecha.
3. Fechas dentro del período.
4. Sin duplicados.
5. Botón Borrar días festivos elimina todo.

Pago:
- Horas trabajadas normales se pagan.
- Se agrega pago adicional igual al valor normal de esas horas.
- Resultado: esas horas quedan al doble.
- Después de 8h, horas extra usan la tarifa extra normal, sin duplicar.

Visual:
- Monto afectado parpadea azul ↔ negro.
- Aproximadamente 1 segundo por color.
- 1 minuto.
- Un nuevo cambio reinicia el minuto.

Detalle:
- Fecha
- Horas trabajadas
- Monto adicional

# 9. Jornada incompleta

## 9.1 Detección
Si no finaliza:
- 1 hora después de su salida programada se marca INCOMPLETA.
- No se paga automáticamente.
- Empleado queda bloqueado.
- No inicia nueva jornada hasta resolver.

Mensaje al día siguiente:
“Jornada anterior sin finalizar. Comuníquese con su supervisor.”
- 10 segundos
- volver a cámara

## 9.2 Corrección normal
Supervisor puede corregir desde:
- lista de bloqueados
- historial de asistencia

Solo edita hora FINALIZAR.
No puede ser anterior al último evento.

Al guardar:
- cerrar jornada
- recalcular
- desbloquear si no quedan otras incompletas

Si hay varias:
- resolver primero la más antigua.

## 9.3 Corrección después de nómina cerrada
- Volante anterior permanece intacto.
- Pago va a próxima nómina como Ajuste de jornada anterior.
- Recupera cálculo original: horas normales, extras, festivo, pausas, tardanza.
- Participa en deducciones actuales.
- Se marca APLICADO al pagarse.
- Total ajustes anteriores + Ver detalle.
- Portal suma el ajuste al acumulado actual sin nueva sección.

# 10. NO PAGAR

Botón de supervisor para jornada incompleta.

Al pulsar:
- popup con último evento válido.

Solo si el único evento fue INICIAR JORNADA:
- mostrar Horas a pagar
- manual
- 0 a 8
- 0 = día sin pago

Si hay más eventos:
- no mostrar campo manual
- pagar solo intervalos demostrables por eventos

Ejemplos:
- Último evento PAUSA: pagar Entrada→Pausa.
- Último evento REANUDAR: pagar solo intervalos cerrados anteriores; no pagar tiempo posterior a esa reanudación sin cierre.

Resultado:
“JORNADA INCOMPLETA RESUELTA — RD$[monto]”

Volante:
“Jornada incompleta resuelta — [fecha] — RD$[monto]”

Reglas:
- editable mientras nómina abierta
- después del cierre no se modifica
- desbloquea solo si no quedan otras incompletas
- no genera horas extra

# 11. Portal del empleado

- Siempre visible para cuenta de empleado.
- Si cambia de rol, el Portal permanece primero.
- Sin funciones administrativas.
- No puede exportar reportes/archivos.

# 12. Portal → Eventos

Quincena actual:
- más nuevos arriba
- más antiguos abajo

Colores:
- Verde normal
- Amarillo tardanza/incidencia moderada
- Rojo jornada incompleta/incidencia grave

Eventos:
- Entrada
- Pausa
- Reanudar
- Finalizar

Detalle al tocar:
- fecha
- hora
- tipo
Sin sucursal/departamento/dispositivo.

JORNADA SIN FINALIZAR:
- siempre arriba
- “JORNADA SIN FINALIZAR — [fecha]”
- negro ↔ rojo cada 0.5 s
- permanece hasta corrección

Al tocar:
- fecha
- entrada
- pausas
- reanudaciones
- falta Finalizar

Historial:
- quincena actual arriba
- archivo automático al terminar fecha
- Año → Quincena
- más reciente primero
- cada quincena muestra Jornadas, Tardanzas, Jornadas incompletas
- colores verde/amarillo/rojo
- quincena anterior abre pantalla aparte
- si se corrige una archivada, recalcular resumen y color
- si se archiva con incompleta, alerta sigue arriba hasta corregir

# 13. Nómina — períodos

Cierres:
- 15
- 30
- Febrero 15/28 o 15/29

Sistema prepara período.
Usuario pulsa Iniciar nómina.

Mostrar:
- período
- cantidad empleados
- total acumulado
- Comenzar

Flujo:
Deducciones → Pago → Cerrar nómina

Inclusión:
- empleado con cualquier ganancia en período aunque ya esté inactivo
- excluir si RD$0.00 en todo el período
- préstamos/impuestos pendientes se arrastran si no hay ganancia

# 14. Deducciones

Por empleado:
- Crédito manual
- Préstamo automático
- Impuestos automáticos
- Ausencia automática/referencia
- Otros manual

Mostrar:
- Ganancia acumulada
- Total deducciones
- Neto

Crédito/Otros:
- manuales
- siguiente nómina = 0
- Otros sin descripción
- edición directa

Ausencia:
- se muestra como referencia
- no volver a restar si el día ya no generó ganancia

Impuestos:
- monto fijo por quincena
- no editable aquí
- faltante se acumula
- mostrar una sola cifra “Impuestos totales”

Prioridad:
1. Ausencia
2. Impuestos
3. Préstamo
4. Crédito
5. Otros

Neto nunca negativo.

Guardar:
- botón Guardar por empleado
- al guardar contraer fila
- nombre + ✅ GUARDADO + Desplegar

Continuar a Pago:
- fijo abajo
- se puede continuar con empleados sin guardar
- no guardado: Crédito=0, Otros=0, automáticos sí aplican

Orden inteligente:
- empleados con Crédito/Otros quincena anterior arriba
- solo por una quincena
- mostrar monto anterior como referencia
- al guardar desaparece
- no copiar automático

Buscador por nombre.

Dashboard:
- Total general deducciones
- actualiza al guardar
- amarillo unos segundos cuando sube

# 15. Préstamos

Un solo saldo vigente por empleado.

Crear:
- monto nuevo
- interés manual
- cuota quincenal

Interés:
- una sola vez sobre monto nuevo
- no recalcular deuda anterior
- no recalcular después de abonos

Nuevo préstamo sobre saldo:
- sumar monto nuevo + interés
- mantener cuota actual salvo cambio manual

Deducción:
- automática
- saldo menor que cuota: descontar saldo y SALDADO
- si no alcanza dinero: descontar disponible y resto pendiente
- préstamo creado/aumentado durante nómina empieza a descontarse en la próxima

Crear/aumentar:
- perfil
- Deducciones
- formulario: monto, interés, cuota actual, opcional cambiar cuota

Ver préstamo:
- popup
- saldo
- cuota
- interés
- historial
- desde popup se puede cambiar cuota

Abono manual:
- reduce saldo inmediato
- no excede saldo
- 0 → SALDADO automático
- recibo: nombre, monto abonado, saldo restante
- abonos en historial

Perfil:
- Préstamo vigente arriba
- Préstamos saldados desplegable
- saldados conservan monto, interés, pagos

# 16. Pago

Dashboard superior:
- Total efectivo
- Total banco
- Total general
- Total nómina
- Total REVISADO
- Total PENDIENTE

Filtros:
- Todos / Pendientes / Revisados
- Todos / Efectivo / Banco

Orden A–Z.

Fila:
- Nombre
- Monto a pagar
- Ver detalle
- Imprimir volante
Sin código.

Estado:
PENDIENTE → REVISADO
- no usar PAGADO
- individual o masivo
- puede volver a PENDIENTE
- automáticos no editables
- manuales editables incluso REVISADO
- recálculo inmediato
- mantiene REVISADO

Banco:
- Nombre
- Cuenta
- Total

Efectivo:
- Nombre
- Total

# 17. Exportaciones de Pago

Botones siempre visibles:
- Exportar transferencias
- Exportar efectivo

Incluyen todos los empleados del tipo sin importar estado.

Transferencias Excel:
- Nombre
- Cuenta
- Total
Archivo: Transferencias_YYYY-MM-DD.xlsx

Efectivo Excel:
- Nombre
- Total
Archivo: Efectivo_YYYY-MM-DD.xlsx

Ambos:
- encabezado empresa
- período
- fecha cierre
- A–Z
- sin total final

# 18. Volante

Disponible aunque PENDIENTE.

- Imprimir volante individual
- Imprimir todos
- 2 por página
- impresión masiva respeta filtro activo

Encabezado:
- Logo
- Empresa
- Dirección
- Teléfono

Empleado:
- Nombre
- Período
- Sueldo bruto

Ganancias monetarias:
- Ganancia normal
- Horas extra
- Festivos
- Licencia
- Vacaciones
- Ganancia total

No mostrar cantidad de horas.

Deducciones por separado:
- Crédito
- Préstamo
- Impuestos
- Ausencia
- Otros

Jornada incompleta sin pagar:
“Descuento por jornada incompleta — [fecha] — RD$[monto]”

Jornada resuelta:
“Jornada incompleta resuelta — [fecha] — RD$[monto]”

Final:
- Neto a pagar

# 19. Cierre/reapertura

Cerrar:
- puede cerrar con PENDIENTES
- confirmación “¿Seguro que deseas cerrar esta nómina?”
- portal acumulado vuelve a RD$0
- histórico queda congelado
- pantalla final: Ver historial / Volver al inicio

Reabrir:
- libre
- portal permanece RD$0
- corregir solo dentro de nómina reabierta
- al recerrar conservar internamente versión anterior y crear corregida
- UI histórica muestra solo la versión más reciente

# 20. Historial y exportación general de Nómina

Historial:
Año → Mes → Quincena

Mostrar:
- Total general
- Efectivo
- Banco
- Empleados
- Deducciones
- última versión
- imprimir volantes

Empleado:
- Nombre
- Neto
- Estado
- Ver detalle

Solo nóminas CERRADAS exportan.

Exportar → PDF / Excel

Excel hojas:
- Resumen
- Empleados
- Deducciones
- Detalle de ganancias
Archivo Nomina_YYYY-MM-DD.xlsx

PDF:
- horizontal
- Resumen
- Empleados
- Ganancias
- Deducciones
- Totales
Archivo Nomina_YYYY-MM-DD.pdf

Abrir menú del sistema para guardar/compartir.

# 21. Reportes → Asistencia

No existe Reporte de Jornadas separado.

Flujo:
- buscar empleado
- abrir empleado
- última quincena abierta
- historial Año → Quincena

Quincena:
- Jornadas
- Tardanzas
- Ausencias
- Incompletas

Botón:
Imprimir quincena

Imprime solo esa quincena de ese empleado:
- Fecha
- Entrada
- Pausa
- Reanudar
- Finalizar
- Estado
- resumen final

# 22. Reportes → Nómina

Flujo:
1. Año
2. Quincena
3. Filtro Todos/Efectivo/Banco
4. Barra: Monto total + cantidad empleados
5. Cargar todos A–Z
6. Campo manual de búsqueda por nombre

Cada empleado:
- una fila por quincena
- Ganancias
- Festivos
- Deducciones
- Total
- Estado
- Ver detalle
- Imprimir volante

Arriba:
Imprimir todos los volantes
- imprime toda la quincena seleccionada
- ignora texto del buscador

# 23. Dashboard

Dinámico por permisos y alcance.

Filtros:
- Sucursal
- Departamento
- Fecha de un solo día
- Actualizar

Actualiza:
- automático cada 3 min
- manual
- Última actualización: hora

Tarjetas tocables:
- Presentes
- Ausentes
- Tardanzas
- En pausa
- Bloqueados
- otras operativas autorizadas

Al tocar:
- lista empleados
- etiqueta Sucursal + Departamento

No mostrar:
- tarjeta Nómina
- tarjeta Terminal facial
- Actividad reciente duplicada

# 24. EMPLEADO EN LISTA NEGRA

Nombre exacto.
Visible solo con permiso “Ver lista negra”.

Dashboard:
- una sola tarjeta
- 4 contadores
- abre pantalla completa

Categorías:
1. AUSENCIAS: >2 faltas/mes
2. TARDANZA: >5 tardanzas/mes
3. SIN FINALIZAR JORNADA: >5 incompletas/mes
4. MODIFICADOS: empleados con correcciones

MODIFICADOS agrupa:
- supervisor
- día
- tiempo corregido

Orden:
- actividad más reciente arriba

Puede aparecer en varias categorías.

Si corrección reduce el conteo:
- permanece hasta fin de mes.

Archivo:
- al nuevo mes, archivar automático
- Año → Mes
- contadores nuevos a 0

Pantalla:
- mes actual
- 4 tarjetas cerradas
- Año
- Mes
- buscador nombre

Resultado:
- categorías
- cantidad eventos
- último evento

Reporte por empleado:
- no general
- mensual
- datos actualizados
- resumen categorías
- detalle
- botón Actualizar manual
- vista previa
- Imprimir

Encabezado:
- Logo
- Empresa
- Año
- Mes
- Fecha impresión
- Empleado

Si aparece en varias categorías:
- un solo reporte.

# 25. Empresa

Campos:
- Nombre
- Logo
- Dirección
- Teléfono
- Correo
- RNC/Identificación fiscal

Permiso:
Administrar datos de empresa

Cambios:
- aplican a documentos nuevos
- documentos antiguos conservan snapshot

# 26. Sucursales y Departamentos

Sucursal:
- Nombre
- Dirección
- Teléfono
- ACTIVA/INACTIVA

Departamentos:
- crear manual
- copiar de otra sucursal
- al copiar no copiar supervisor

Puede crear departamento sin supervisor, pero:
- no asignar empleados hasta tener supervisor

Supervisor:
- uno por departamento
- cambio aplica inmediatamente
- antes de desactivar supervisor, asignar otro

Desactivar departamento:
- mover empleados antes
- eliminarlo de configuraciones de terminal

Desactivar sucursal:
- reasignar empleados
- reasignar dispositivos
- desactivar departamentos
- conservar historial

Reactivar sucursal:
- conservar datos
- departamentos quedan INACTIVOS
- reactivar manualmente los necesarios

# 27. Dispositivos

Secciones:
1. Dispositivos registrados
2. Terminales faciales
3. Dispositivos retirados

Dispositivo registrado:
- Nombre
- Modelo
- Sucursal
- Última conexión
- Estado
- Configurar

Configurar abre popup:
- Nombre
- Voz
- Sucursal
- Departamentos
- Activar/desactivar

# 28. Terminal facial — tipo de uso

Accesible en cualquier Android por permiso.
No depende de modelo de teléfono.

Para kiosco Android realmente bloqueado:
- requiere preparación correcta del dispositivo / Device Owner / lock-task.
- sin eso no simular activación segura.

Puede haber varios terminales activos.

Nombre manual + sucursal.

Tipo de uso:

Uso general:
- cualquier empleado de la empresa.

Por departamentos:
1. Elegir modo
2. Sucursal
3. Cargar departamentos
4. Seleccionar uno o varios

Si cambia sucursal:
- limpiar selección anterior.

Al menos un departamento obligatorio.
Si queda sin departamentos:
- bloquear registros
- no pasar a Uso general automático

No activar sin departamentos:
“SELECCIONE AL MENOS UN DEPARTAMENTO”

Empleado fuera del alcance:
“TERMINAL NO AUTORIZADO PARA SU DEPARTAMENTO”
- 5 segundos
- volver

# 29. Panel de Terminales

Cada terminal:
- Nombre
- Sucursal
- Estado
- Última conexión
- Activar
- Desactivar
- Configurar

Estados:
🟢 ACTIVO
⚪ INACTIVO
🔴 SIN CONEXIÓN
⚫ RETIRADO

Orden:
ACTIVO → SIN CONEXIÓN → INACTIVO → RETIRADO

Filtro:
- Sucursal

Sin conexión:
- después de 10 min.

Al volver:
- estado real automático.

No eliminar terminal:
- retirar
- conservar datos
- permitir reactivar

# 30. Configuración del Terminal

Pantalla aparte.
Secciones desplegables:
1. General
2. Voz
3. Pantalla de espera
4. Sincronización

General:
- Nombre
- Sucursal
- Estado
- Última conexión
- Retirar/Reactivar
- Tipo uso

Voz:
- configuración general + excepción por dispositivo
- activar/desactivar
- volumen
- velocidad
- Normal por defecto
- slider
- Restablecer
- Probar voz con texto libre

Pantalla espera:
- tiempo inactividad configurable
- referencia inicial 5 min
- Probar pantalla

Sincronización:
- Estado
- Última sync
- Sincronizar ahora
- delta primero
- full si hay problema

Guardar y aplicar:
- aplica al terminal activo
- si falla mantener anterior y mostrar error
- no parcial

# 31. Persistencia/activación Terminal

Salir físicamente:
- mantener logo 5 segundos
- usuario
- contraseña
- validar permiso
- salir
- entrar al panel del usuario autenticado

Conservar:
- nombre
- sucursal
- plantillas cifradas

Reinicio/energía:
- si estaba activo, volver automáticamente

Activación remota:
- permitida
- verifica config + sync
- si offline queda pendiente
- al volver se ejecuta
- si falla no activa y muestra motivo

Desactivación remota:
- inmediata
- vuelve a login

# 32. Sincronización Terminal

Al activar:
- empleados
- estados
- rostros
- “Sincronizando terminal…” + %
- >60s: “Conexión lenta. Seguimos intentando…”

Si sync inicial falla:
- bloquear hasta Internet

Al completar:
- “✅ Terminal listo”
- 2 segundos
- cámara

Si servidor cae después de operativo:
- funcionar offline con local
- guardar marcaciones
- sincronizar luego

Reinicio con marcaciones pendientes:
- intentar sync primero
- si algunas fallan tras reintentos, abrir cámara y seguir en background
- icono discreto de sync pendiente
- icono solo informativo

# 33. Datos locales

Guardar mínimo:
- Código
- Primer nombre/nombre
- Estado
- Plantilla facial
- Datos operativos mínimos

No guardar ficha completa de RR. HH. innecesariamente.

Si empleado se desactiva o se elimina rostro:
- borrar plantilla local
- bloquear marcaciones

Cambios de nombre/estado/departamento:
- sync automática

# 34. Registro facial nuevo

Botón:
“Registrar rostro nuevo (X pendientes)”

Visible solo si hay empleados sin rostro.

Flujo:
1. Código
2. Buscar empleado
3. Validar existe/activo/sin rostro/horario+día libre
4. Mostrar nombre + código + foto si existe
5. Confirmar “Registrar rostro para este empleado”
6. Requiere Internet
7. Captura guiada

Capturas:
- frente
- izquierda
- derecha
- automáticas
- repetir solo posición mala
- liveness automático
- plantilla consolidada única
- comprobar duplicado contra rostros existentes
- si duplicado: “Rostro ya registrado en otro empleado”
- no revelar identidad
- eliminar capturas originales
- guardar solo plantilla
- éxito solo cuando servidor confirma

Si pierde Internet:
- cancelar
- “Sin conexión. Inténtalo nuevamente cuando vuelva Internet.”

Resultado:
- “✅ Rostro registrado correctamente”
- 5 segundos
- empleado ACTIVO automático
- volver a cámara
- debe reconocerse otra vez para marcar

# 35. Cámara/reconocimiento

Cámara configurable:
- frontal
- trasera

Orientación automática.

Guías:
- Acércate
- Aléjate
- Mira al frente

Poca luz:
- “Mejora la iluminación”
- no reconocer

Varias personas:
- “Solo una persona frente a la cámara”

Distancia incorrecta:
- bloquear hasta correcta

Lentes oscuros:
- intentar
- si falla: “Retira los lentes oscuros”

Mascarilla/casco/gorra:
- pedir retirar si dificulta

Cambios de apariencia:
- sin acción especial si sigue coincidiendo

Vivacidad:
- automática
- 3 intentos
- luego “COMUNICARSE CON EL ADMINISTRADOR”
- 5 segundos
- volver
- no guardar intentos fallidos

# 36. Fallback por código

Código no sustituye rostro.

Si 1:N falla:
1. Pedir código
2. Identificar empleado
3. Mostrar nombre
4. Esperar 5 segundos
5. Cámara
6. Validar 1:1 contra ese empleado
7. Hasta 3 intentos

Si falla:
“COMUNICARSE CON EL ADMINISTRADOR”
- blanco ↔ rojo
- 5 segundos
- volver

Si no tiene rostro:
- código no permite marcar
- primero registrar rostro

# 37. Acciones Terminal

Después de reconocer:
- primer nombre
- acción disponible
- Cancelar
- no tiempos

Colores:
- Iniciar verde
- Pausa amarillo
- Reanudar azul
- Finalizar rojo
- iconos distintos

Estado:
- no iniciado: INICIAR
- trabajando: PAUSA + FINALIZAR
- en pausa: solo REANUDAR

Pantalla:
- fija
- sin timeout
- hasta acción o Cancelar

Cancelar:
- cámara inmediata

Acción:
- registrar inmediatamente
- sin segunda confirmación

# 38. Voz y confirmación

Frases:
- Iniciar: “Bienvenido, [primer nombre].”
- Pausa: “Recuerda volver a la hora asignada, [primer nombre].”
- Reanudar: “Gracias por volver, [primer nombre].”
- Finalizar: “Adiós, que tengas un excelente resto del día, [primer nombre].”
- Error: “Inténtalo de nuevo, [primer nombre].”

Confirmación:
- ✅ Registro exitoso + acción realizada
- no hora
- hora solo historial
- mantener hasta que termine voz
- luego cámara

Error:
- ❌ Inténtalo de nuevo
- voz
- luego cámara

Sin vibración.
Sin tonos extra.

# 39. Evitar doble reconocimiento

Después de acción:
- empleado debe salir completamente del encuadre.
- mensaje “Retírate de la cámara para continuar”
- basta un instante sin rostro.
- luego siguiente reconocimiento inmediato.

# 40. Estados especiales Terminal

LICENCIA:
“EMPLEADO EN LICENCIA” 5s, sin voz.

VACACIONES:
“EMPLEADO EN VACACIONES” 5s, sin voz.

INACTIVO:
“EMPLEADO INACTIVO” 5s, sin voz.

PENDIENTE:
“COMUNICARSE CON EL SUPERVISOR” 5s, sin voz.

BLOQUEADO:
“EMPLEADO BLOQUEADO” 5s, rojo ↔ blanco, sin voz.

# 41. Pantalla de espera

Se activa tras 5 min de inactividad solo en cámara.
No interrumpe pantalla fija de acción.
Pantalla siempre encendida.
Brillo normal.

Diseño:
Mitad superior:
- ESPERANDO A
- azul

Mitad inferior:
- EN PAUSA
- amarillo

Solo sucursal asignada.
Nombres rotan cada 3 segundos.
Mostrar primer nombre + tiempo relevante.

Orden:
- Esperando: más atrasado primero
- Pausa: más tiempo en pausa primero

Si vacío:
“— SIN EMPLEADOS —”

Mantener ambas mitades.

Día libre:
- no aparece en Esperando
- si trabajó y está en pausa sí aparece en Pausa

Actualización en tiempo real.
Tocar cualquier parte → cámara.

Modo Por departamentos:
- solo empleados de departamentos autorizados.

# 42. Consolidación multi-terminal

- Entrada: primera hora válida.
- Finalizar: última hora válida.
- Pausa/Reanudar: consolidar por ciclos; ante duplicados usar primera Pausa válida y última Reanudación válida del ciclo.
- Importa hora real del evento, no hora de sync.
- Offline conserva fecha, hora, terminal, sucursal.

# 43. Mensajes a empleados

Opción separada debajo de Dispositivos.
Permiso:
“Administrar mensajes a empleados”

Selección:
Sucursal → Departamento → Empleado

Un empleado por mensaje.
No mostrar quién tiene pendiente.

Si ya tiene:
“ESTE EMPLEADO TIENE UN MENSAJE PENDIENTE”
- no crear otro

Tipos:
1. Texto
2. Voz del sistema
3. Voz grabada

Texto:
- sin límite fijo
- scroll vertical
- MENSAJE RECIBIDO fijo abajo
- URLs no navegables

Voz grabada:
- máximo 30s

Vista previa.
Si voz: Reproducir.

Después de enviar:
“✅ Mensaje enviado”
- 3s
- volver

Una vez enviado:
- no cancelar
- no reemplazar
- sin vencimiento

Entrega:
- espera próximo movimiento exitoso: iniciar/pausa/reanudar/finalizar
- primero guardar jornada
- luego mensaje sustituye voz normal de esa acción
- pantalla fija
- MENSAJE RECIBIDO obligatorio

Voz:
- auto reproducir
- botón Repetir mensaje

Al recibir:
- eliminar definitivamente
- sin historial
- “✅ Mensaje recibido” 2s
- cámara

No enviar a:
- INACTIVO
- PENDIENTE

Sí enviar a:
- LICENCIA
- VACACIONES
Queda pendiente hasta próxima jornada.

Sync:
- todos los terminales
- puede entregarse offline si ya local
- confirmación offline se sincroniza luego
- primera confirmación válida gana
- eliminar en todos

# 44. Seguridad y auditoría

Registrar:
- cambio sueldo
- cambio rol
- permisos
- alcance
- activar/desactivar empleado
- restablecer contraseña
- corrección jornada
- NO PAGAR
- préstamos
- cierre/reapertura nómina
- deducciones manuales
- cambios importantes Empresa

No registrar:
- cada reconocimiento facial
- sync rutinaria
- intentos liveness
- contenido mensajes
- actividad técnica rutinaria

Registro:
- Fecha/hora
- Usuario
- Acción
- Módulo
- Elemento afectado
- Valor anterior/nuevo cuando aplique

Pantalla:
- permiso Ver auditoría
- filtros Fecha / Usuario / Módulo / Acción
- más reciente arriba
- solo lectura
- no borrar/editar
- PDF/Excel solo con permiso específico

# 45. Mi cuenta y sesión

Mi cuenta:
- Nombre
- Usuario
- Rol
- Cambiar contraseña
- Cerrar sesión

No puede:
- cambiar propio rol
- cambiar propios permisos

Sesiones:
- varias sesiones permitidas
- cambios de rol/permisos/alcance se reflejan en todas
- desactivar usuario invalida sesiones
- restablecer contraseña cierra otras sesiones
- logout no borra inscripción del dispositivo
- Terminal facial mantiene persistencia propia

# 46. Decisiones que reemplazan versiones anteriores

- Activación empleado: horario + día libre → rostro → ACTIVO automático.
- Terminal facial está dentro de Dispositivos.
- No existe Reporte de Jornadas separado.
- No existe Reporte de Empleados separado.
- No existe Reporte de Incidencias separado.
- No hay permiso global para supervisor; alcance = suma de departamentos seleccionados.
- Portal del empleado permanece aunque cambie rol.
- Estado de Nómina: PENDIENTE / REVISADO, no PAGADO.
- Vacaciones usan fecha inicio/final, no solo cantidad de días.
- Campo manual Horas a pagar en NO PAGAR solo aparece si el único evento fue INICIAR.
- Pantalla de acción Terminal sin timeout.
- Cámara configurable frontal/trasera.
- Día libre no muestra aviso especial.
- Mensajes se entregan en el próximo movimiento exitoso, no solo al iniciar jornada.
- EMPLEADO EN LISTA NEGRA se imprime por empleado y mes, no reporte general.

# 47. Instrucción para Codex / otro chat

Antes de cambiar código:

1. Leer este archivo completo.
2. Usarlo como fuente de verdad funcional.
3. Revisar el código actual y clasificar:
   - implementado;
   - parcial;
   - faltante;
   - en conflicto.
4. No cambiar reglas aprobadas sin autorización.
5. Hacer cambios pequeños y verificables.
6. Crear migraciones cuando haga falta.
7. Proteger por permiso + alcance + estado + integridad de datos.
8. Mantener históricos compatibles.
9. Probar cada fase antes de avanzar.
10. Si un punto no está definido, preguntar solo por ese punto.

## Orden recomendado de implementación

1. Roles/permisos/alcances.
2. Sucursales/departamentos.
3. Recursos Humanos.
4. Asistencia.
5. Terminal facial.
6. Nómina.
7. Portal y Reportes.
8. Dispositivos y Mensajes.
9. Auditoría y sesión.
10. Pruebas integrales de permisos, alcance, offline, concurrencia y nómina.

**FIN — ESPECIFICACIÓN FUNCIONAL MAESTRA CONTROL HORARIO**

## ACTUALIZACIÓN NORMATIVA FINAL TERMINAL-ONLY 2026-08-26

Esta actualización prevalece sobre cualquier flujo histórico incompatible. Android es exclusivamente un Terminal autorizado de jornadas: instalación nueva mediante código de dispositivo y aperturas posteriores directamente en cámara. No existe Login normal ni administración en Android. El enrolamiento facial operativo se realiza dentro del Terminal autorizado; el flujo QR facial Web queda retirado. `face_match_threshold` es el criterio primario y `face_match_margin` es un filtro adicional nullable y opcional. La administración permanece exclusivamente en Web.
