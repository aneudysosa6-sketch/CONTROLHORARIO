# GUIA UI/UX OSINET - CONTROL HORARIO

## 1. Objetivo

La interfaz debe sentirse operativa, precisa y confiable. El lenguaje visual
actual es oscuro, azul y de alta legibilidad. No se deben crear pantallas
genericas que parezcan ajenas a OSINET.

Esta guia describe el sistema vigente y la direccion normativa. No obliga a
que Android y Web usen el mismo framework, pero si la misma semantica.

## 2. Principios

1. Estado antes que decoracion.
2. Una accion primaria por contexto.
3. Seguridad visible sin exponer detalles tecnicos.
4. Informacion densa, pero escaneable.
5. Responsive real, no solo scroll horizontal.
6. Carga, vacio, error y sin permiso son estados de primera clase.
7. El color refuerza texto e icono; nunca es la unica senal.
8. Datos sensibles se ocultan por defecto.

## 2.1 Identidad visual oficial

La marca oficial combina:

- marco de escaneo facial;
- malla biometrica;
- reloj de control horario;
- fondo azul marino;
- acento azul electrico;
- indicador verde de verificacion.

Wordmark:

- nombre: `CONTROL HORARIO`;
- `CONTROL` en blanco;
- `HORARIO` en azul;
- descriptor: `FACE TIME ERP ENTERPRISE`.

Recursos oficiales:

- Android: launcher adaptativo, launcher redondo, capa monocromatica y splash;
- Web: `control-horario-mark.svg`;
- Web horizontal: `control-horario-logo.svg`;
- Web monocromatico: `control-horario-mark-monochrome.svg`.

No se debe volver a usar el isotipo circular anterior ni mostrar `OSINET` como
nombre principal visible. Los nombres internos de componentes pueden
conservarse temporalmente para evitar refactorizaciones sin valor funcional.

## 3. Paleta vigente

### Web

| Token | Valor |
|---|---|
| Fondo | `#07101F` |
| Superficie | `#0C1729` |
| Superficie elevada | `#101E33` |
| Borde | `#1D304A` |
| Texto secundario | `#8495AE` |
| Azul primario | `#1689FF` |
| Azul luminoso | `#37B8FF` |
| Exito | `#2DD4A3` |
| Advertencia | `#FFB648` |
| Peligro | `#FF6378` |

### Android OSINET

| Token | Valor |
|---|---|
| Fondo | `#06111F` |
| Superficie | `#091A2E` |
| Superficie alternativa | `#0D233A` |
| Borde | `#17476F` |
| Texto principal | `#F4F4F4` |
| Texto secundario | `#CFCFCF` |
| Azul primario | `#128CFF` |
| Azul suave | `#55B8FF` |
| Informacion | `#00A3FF` |
| Advertencia | `#FFC107` |
| Peligro | `#E53935` |

Regla:

- reutilizar tokens de la plataforma;
- no introducir una tercera paleta;
- la diferencia menor entre azules Web y Android es aceptada temporalmente;
- una convergencia futura debe registrarse como decision de arquitectura.

Android conserva colores verdes y violetas de temas anteriores. No son la
fuente visual para componentes nuevos.

## 4. Tipografia

Web:

- cuerpo: DM Sans;
- encabezados: Manrope.

Android:

- tipografia Material actual;
- no hay una fuente personalizada oficial.

Jerarquia:

| Uso | Recomendacion |
|---|---|
| Titulo de pantalla | 28-36 px/sp, peso 700 |
| Titulo de tarjeta | 18-22 px/sp, peso 650-700 |
| Cuerpo | 14-16 px/sp |
| Etiqueta | 12-14 px/sp, peso 600 |
| Dato metrico | 24-36 px/sp, cifras tabulares cuando exista |
| Ayuda | 12-14 px/sp, color secundario |

No usar mayusculas largas para parrafos. Los codigos y estados pueden usar
mayusculas controladas.

## 5. Espaciado y forma

- Unidad base: 4.
- Separacion minima entre controles: 8.
- Separacion habitual: 12, 16 o 24.
- Margen de pantalla: 16 en movil, 24 en escritorio/tablet.
- Radio de tarjeta: 16 a 18.
- Altura de accion principal Android: 56.
- Bordes: uno visualmente suave, sin dobles contornos.
- Sombras: discretas; la elevacion se expresa principalmente con superficie.

## 6. Estructura de pagina

Orden recomendado:

1. Titulo y subtitulo funcional.
2. Acciones principales.
3. Indicadores resumidos.
4. Filtros.
5. Contenido principal.
6. Paginacion o acciones secundarias.

En movil:

- apilar controles;
- convertir tablas densas en tarjetas;
- mantener acciones esenciales visibles;
- evitar ancho fijo;
- no depender de hover.

## 7. Componentes

### Tarjetas

- superficie elevada;
- borde sutil;
- titulo corto;
- valor principal legible;
- soporte para loading y empty;
- no convertir cada texto en una tarjeta separada.

### Botones

- primario: una accion principal;
- secundario: borde/superficie;
- peligro: solo para accion destructiva;
- deshabilitado: motivo explicable;
- loading: bloquear repeticion y mantener ancho.

### Filtros

- agrupar en tarjeta;
- usar etiquetas persistentes;
- ofrecer `Aplicar` cuando la consulta sea costosa;
- ofrecer `Limpiar filtros`;
- reflejar filtros activos;
- preservar accesibilidad de teclado.

### Tablas

- encabezado visible;
- filas con espaciado vertical;
- hover solo como refuerzo;
- alineacion numerica;
- acciones explicitas;
- estado vacio integrado;
- tarjetas equivalentes en movil.

### Badges

Estados recomendados de jornada:

| Estado | Semantica |
|---|---|
| `EN_CURSO` | Azul o advertencia controlada |
| `FINALIZADA` | Exito |
| `PENDIENTE` | Naranja/advertencia |
| `INCOMPLETA` | Peligro |

Siempre mostrar texto junto al color.

## 8. Presentacion de tiempo

Los minutos se almacenan y calculan sin cambios. La UI usa una utilidad unica:

`formatDurationMinutes(totalMinutes)`

| Entrada | Salida |
|---|---|
| `null` | `0 h 00 min` |
| negativo | `0 h 00 min` |
| `0` | `0 h 00 min` |
| `5` | `0 h 05 min` |
| `60` | `1 h 00 min` |
| `312` | `5 h 12 min` |
| `395` | `6 h 35 min` |

Trabajo y pausa deben distinguirse:

`5 h 12 min - Pausa 30 min`

No duplicar conversiones dentro de componentes.

## 9. Estados de pantalla

### Carga

- skeleton con forma aproximada al contenido;
- evitar pantalla en blanco;
- no mostrar datos viejos como nuevos sin indicador.

### Vacio

- icono semantico;
- titulo: `No se encontraron resultados`;
- ayuda concreta: `Prueba cambiando los filtros.`;
- accion solo si existe en el producto.

### Error

- mensaje funcional;
- boton `Reintentar` cuando sea seguro;
- correlation ID opcional para soporte;
- detalles SQL solo en log seguro.

### Sin permiso

- explicar que el acceso no esta habilitado;
- no revelar existencia de datos ajenos;
- ofrecer volver;
- no mostrar una pantalla rota debajo.

### Sin alcance

- diferenciarlo de falta de permiso;
- ejemplo: `No tienes departamentos asignados. Contacta al administrador.`

## 10. Empleado en listas

Mostrar:

- nombre como dato principal;
- codigo como texto secundario;
- sucursal y departamento como contexto;
- estado mediante badge;
- acciones segun permisos efectivos.

Si no hay una accion implementada o permitida, mostrar `Sin acciones`. No se
inventan botones.

## 11. Navegacion

- El dashboard se selecciona por rol canonico.
- Los modulos internos se muestran por permisos.
- Ocultar un enlace no reemplaza el guard.
- Una ruta denegada debe conservar una salida segura.
- Login no debe aparecer durante un bootstrap que todavia carga sesion.
- El back stack autenticado se limpia al cerrar sesion.

## 12. Accesibilidad

- Contraste AA como minimo.
- Foco visible en Web.
- Objetivos tactiles de al menos 44x44.
- Etiquetas para iconos.
- Orden de lectura coherente.
- Soporte de teclado en Web.
- Respeto a `prefers-reduced-motion`.
- Mensajes anunciables para carga/error.
- No depender solo de color, sonido o vibracion.

## 13. Kiosco y biometria

- Mostrar que sensor se espera: rostro, huella o biometria del dispositivo.
- No mezclar terminologia facial y huella.
- Explicar permiso USB/camara con lenguaje funcional.
- Indicar progreso de captura sin exponer plantilla.
- Proporcionar alternativa controlada despues de fallos permitidos.
- No afirmar `deteccion de vida` mientras no exista.

## 14. Contenido y tono

Usar espanol claro:

- `No fue posible validar tu acceso.`
- `Revisa tu conexion e intentalo nuevamente.`
- `No tienes departamentos asignados.`

Evitar:

- `P0001`;
- `Details: null`;
- `Hint: null`;
- nombres de tablas;
- stack traces;
- mensajes acusatorios.

## 15. Anti-patrones

- dashboard administrativo como fallback universal;
- permiso vacio como acceso;
- tabla de escritorio forzada en movil;
- accion visible que no funciona;
- componentes con colores hardcoded fuera de tokens;
- duplicar formateadores;
- spinner infinito sin estado;
- mostrar datos mock como si fueran reales;
- usar el nombre del rol para navegacion.
