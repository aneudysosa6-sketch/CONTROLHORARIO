# Guía de uso del precheck resumido de producción

Esta guía sirve únicamente para recopilar evidencia de solo lectura. El
resultado no autoriza una migración ni constituye por sí mismo una decisión
`GO`.

## Ejecución controlada

1. Abra Supabase desde el navegador y seleccione visualmente el proyecto
   **controlhorario-prod**. Confirme también la organización y el entorno que se
   muestran en pantalla. Si el nombre es distinto o existe cualquier duda sobre
   el destino, deténgase y no ejecute nada.
2. Abra el SQL Editor de ese proyecto en una consulta nueva y vacía.
3. Copie íntegramente y ejecute **solo** el contenido de
   `artifacts/production-readiness/production-promotion-precheck-summary.sql`.
   No agregue sentencias, no vuelva a ejecutar el precheck extenso y no ejecute
   migraciones desde esa pestaña.
4. Verifique que el resultado sea una única tabla y que incluya una última fila
   llamada `FINAL_DECISION`. Esta versión revisada devuelve 77 filas fijas: 76
   checks y la decisión final. Si el conteo difiere, deténgase.
5. Para revisión, copie únicamente las filas cuyo `status` sea distinto de
   `PASS`, incluida `FINAL_DECISION`. No comparta el resultado completo ni las
   filas `PASS`.

El precheck detallado que llegó a `MANUAL_GO_NO_GO_REQUIRED` ya demostró que las
tablas base se pueden resolver. El resumen maneja por catálogo la ausencia
normal de funciones e índices futuros. PostgreSQL resuelve las tablas base antes
de evaluar los checks; por ello, si aparece un error de relación o columna
inexistente, trátelo como `BLOCKED`, deténgase y comparta solo el código y mensaje
redactados. No intente crear el objeto ni ejecutar una consulta alternativa.

## Redacción obligatoria antes de compartir

Revise cada celda copiada, especialmente `actual_value` e `instruction`, y
reemplace cualquier dato sensible por una etiqueta genérica:

- UUID o identificador de registro: `<UUID_REDACTED>`.
- Correo electrónico: `<EMAIL_REDACTED>`.
- Token, JWT, bearer, clave, secreto o credencial: `<SECRET_REDACTED>`.
- Dirección IP, hostname, URL de base de datos o identificador técnico del
  proyecto: `<INFRA_REDACTED>`.
- Nombre, documento, teléfono, dirección u otro dato personal: `<PII_REDACTED>`.

Si una celda mezcla un diagnóstico con datos sensibles, redacte la celda
completa y conserve únicamente `check_name`, `status` y el significado general
del problema. No comparta capturas sin recortarlas y redactarlas previamente.

## Interpretación de estados

- `PASS`: el check SQL cumplió su expectativa. No significa autorización para
  promover a producción.
- `WARNING`: no hay un bloqueo demostrado por ese check, pero requiere revisión
  y aceptación explícita antes de continuar.
- `BLOCKED`: detenga la promoción. La causa debe corregirse o aprobarse mediante
  un procedimiento separado y volver a comprobarse.
- `BASELINE_REQUIRED`: SQL no puede demostrar esa condición; falta evidencia
  externa indispensable, como backup/PITR, configuración o versión desplegada
  de Edge Functions, `verify_jwt`, nombres de secrets o una preimagen de
  rollback.

`FINAL_DECISION` resume únicamente lo que puede concluir este precheck. Incluso
si aparece como `PASS`, significa «precheck SQL sin bloqueos detectados» y
**nunca `GO` definitivo**. La promoción continúa prohibida hasta completar y
aprobar los gates externos del plan de producción.

## Acciones prohibidas en esta etapa

No ejecute `db push`, deploys de Edge Functions, migraciones, SQL adicional,
cambios de secrets ni modificaciones de producción. Conserve la evidencia
redactada en el canal seguro definido para la revisión.
