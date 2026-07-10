# Database Edge Functions

`user-provisioning` es la única función implementada: bootstrap, listar Auth sin profile, crear/invitar y aprovisionar. Valida JWT, permiso y tenant; Admin API pagina usuarios; RPC confirma datos atómicamente. Futuras funciones: registro de asistencia idempotente, correcciones, PIN servidor, nómina y documentos. Cada una debe validar JWT, capacidad, alcance, idempotency key y emitir auditoría sin secretos.
