# CONTROL HORARIO - LEER PRIMERO

Estado: documentación oficial final
Última actualización: 2026-08-26
Entorno aceptado: STAGING [STAGING_PROJECT_REF]
Producción: [PRODUCTION_PROJECT_REF] - NO TOCAR

## 1. Arquitectura normativa

CONTROL HORARIO tiene dos clientes con responsabilidades separadas:

- Android es exclusivamente un Terminal autorizado de jornadas.
- Android también registra rostros pendientes dentro del propio Terminal.
- Web concentra administración, supervisión, empleados, horarios, nómina,
  reportes, usuarios, roles, permisos, sucursales, departamentos y dispositivos.
- Supabase/PostgreSQL es la fuente remota de verdad.
- Edge Functions son la frontera privilegiada para usuario Web o Terminal.
- N8N es una integración secundaria y no una fuente de verdad.

Android no contiene Login normal, dashboard, portal ni módulos administrativos.

## 2. Arranque Android

Sin credencial:

Código de registro -> validación y sincronización en segundo plano -> cámara.

Credencial y lease válidos:

Cámara directamente.

Credencial inválida, vencida, revocada o revalidación obligatoria fallida:

TERMINAL NO AUTORIZADO.

No existe una pantalla visible intermedia de "Terminal autorizado".

## 3. Registro facial

- El botón "Registrar rostro nuevo (X pendientes)" aparece solo si X es mayor que cero.
- El empleado se selecciona por código dentro del Terminal.
- Se capturan frontal, izquierda y derecha.
- Liveness por parpadeo es obligatorio.
- FaceNet-128 genera la plantilla.
- El servidor revalida Terminal, empresa, alcance, horario, día libre,
  duplicidad e idempotencia.
- No se guardan imágenes ni se registran embeddings en logs.
- QR facial y teléfono personal están deprecados y no operativos.

## 4. Identificación

- face_match_threshold es el criterio primario.
- El valor aceptado actual es 0.75.
- face_match_margin es una protección adicional opcional.
- Si el margen es null, se omite solo la comprobación best-vs-second.
- Si está configurado, la diferencia debe cumplirlo.
- Con una sola identidad no existe segundo candidato y el margen no aplica.
- Liveness y autorización del Terminal siguen siendo obligatorios.

La calibración estadística de un margen adicional es una mejora futura no
bloqueante.

## 5. Seguridad no negociable

- Credencial Terminal cifrada mediante Android Keystore.
- Clave P-256 no exportable para firma.
- Jornada solo con credencial activa, prueba biométrica e idempotencia.
- Lease offline limitado y revocación efectiva.
- Tenant y alcance revalidados en servidor.
- RLS habilitada y funciones SECURITY DEFINER con grants mínimos.
- service_role solo en Edge.
- Sin tokens, credenciales, imágenes o embeddings en logs.
- El mantenimiento Android solo se abre mediante salida protegida.

## 6. Orden de lectura

1. [PROJECT_CONSTITUTION.md](./PROJECT_CONSTITUTION.md)
2. [01_ESTADO_PROYECTO.md](./01_ESTADO_PROYECTO.md)
3. [02_ARQUITECTURA_GENERAL.md](./02_ARQUITECTURA_GENERAL.md)
4. [03_AUTENTICACION_Y_AUTORIZACION.md](./03_AUTENTICACION_Y_AUTORIZACION.md)
5. [08_ANDROID.md](./08_ANDROID.md)
6. [09_WEB.md](./09_WEB.md)
7. [10_SUPABASE.md](./10_SUPABASE.md)
8. [TERMINAL_ONLY_FACE_ANDROID.md](./TERMINAL_ONLY_FACE_ANDROID.md)
9. [ARCHITECTURE_DECISIONS.md](./ARCHITECTURE_DECISIONS.md)
10. [12_DEPLOYMENT.md](./12_DEPLOYMENT.md)
11. [ROADMAP.md](./ROADMAP.md)
12. [CHANGELOG.md](./CHANGELOG.md)

La especificación funcional amplia permanece en
[../CONTROL_HORARIO_ESPECIFICACION_MAESTRA.md](../CONTROL_HORARIO_ESPECIFICACION_MAESTRA.md).
La regla terminal-only de este documento tiene prioridad sobre secciones
históricas incompatibles.

## 7. Evidencia aceptada

- Migraciones 0055-0061 aplicadas únicamente en STAGING.
- pgTAP/RLS/RPC de la fase terminal: PASS.
- Edge Functions terminales en STAGING: PASS.
- WP23: terminal-only, cámara directa, enrolamiento, reconocimiento, liveness,
  jornada completa, retiro de cámara, reinicio, revocación y salida protegida:
  PASS.
- TTS físico de INICIAR, PAUSA, REANUDAR y FINALIZAR: PASS.
- Producción no tocada.

El informe único de cierre se encuentra en
artifacts/CODEX_PROJECT_FINAL_ACCEPTANCE.md.