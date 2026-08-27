# Archivos que no deben incluirse en commits funcionales

No se elimino ningun archivo. Las acciones indicadas deben ejecutarse durante la preparacion manual de commits.

| Ruta o patron | Motivo | Accion recomendada |
|---|---|---|
| .idea/deploymentTargetSelector.xml | Estado local del dispositivo seleccionado por Android Studio | Ignorar y excluir; si ya esta trackeado, retirarlo del indice en una tarea autorizada |
| app/build.gradle.kts.before-staging-debug | Respaldo previo | Conservar solo localmente; ignorar |
| app/src/main/java/com/example/controlhorario/ui/kiosk/KioskDeviceSettingsScreen.kt.before-kiosk-navigation-fix | Respaldo de fuente | Mover fuera del arbol o conservar localmente; ignorar |
| app/src/main/java/com/example/controlhorario/ui/navigation/AppNavigation.kt.before-kiosk-navigation-fix | Respaldo de fuente | Mover fuera del arbol o conservar localmente; ignorar |
| gradle.properties.before-wp23-staging-test | Respaldo de configuracion | Conservar solo localmente; ignorar |
| local.properties | Rutas y configuracion Android local | Conservar solo localmente; ignorar |
| local.properties.before-wp23-staging-key-fix | Respaldo local potencialmente sensible | Conservar solo localmente; ignorar |
| logs/ y *.log | Logs historicos con identificadores y referencias operativas | Conservar localmente fuera de commits |
| app_startup*.txt | Diagnosticos de arranque | Conservar localmente; ignorar |
| face_registration*.txt | Logs de camara o rostro | Conservar localmente con acceso restringido; ignorar |
| fingerprint*.txt | Diagnosticos biometricos | Conservar localmente con acceso restringido; ignorar |
| artifacts/wp23-staging-after-kiosk-update.apk | APK generado | Conservar localmente o mover a almacenamiento de artefactos |
| artifacts/wp23-staging-before-kiosk-update.apk | APK generado | Conservar localmente o mover a almacenamiento de artefactos |
| artifacts/CODEX_REVIEW_BUNDLE.zip | Paquete derivado | Conservar localmente; no versionar |
| artifacts/CONTROLHORARIO_LOCAL_WORKTREE_2026-08-18.diff | Copia completa del worktree | Conservar localmente; no versionar |
| artifacts/*-before-*.kt | Copias de fuentes | Conservar localmente; ignorar |
| artifacts/kiosk-* | Respaldos y salidas de quiosco | Conservar localmente; ignorar |
| artifacts/00*.txt | Auditorias e insumos temporales anteriores | Mover a archivo externo o conservar localmente |
| artifacts/*-audit*.txt | Salidas de auditoria derivadas | Conservar localmente; ignorar |
| artifacts/*-build*.txt | Salidas de compilacion | Conservar localmente; ignorar |
| artifacts/*-input*.txt | Insumos temporales | Conservar localmente; ignorar |
| artifacts/*-snapshot*.txt | Instantaneas derivadas | Conservar localmente; ignorar |
| artifacts/*-review*.txt | Revisiones temporales TXT | Conservar localmente; ignorar |
| controlhorario_0044_release/ | Copia de release historico | Mover fuera del repositorio o conservar localmente |
| ntent seguido de caracter grave | Archivo accidental malformado | Conservar hasta revision del usuario; excluir |
| rcmainjavauipunchKioskExitCoordinator.kt seguido de apostrofe | Archivo accidental malformado | Conservar hasta revision del usuario; excluir |

## Documentacion que si puede versionarse

Los archivos artifacts/CODEX_*.md son documentacion del saneamiento y pueden incluirse en un commit documental separado. No deben mezclarse con binarios, logs o respaldos.
