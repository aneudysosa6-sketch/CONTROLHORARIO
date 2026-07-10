# Database Security

Amenazas cubiertas: tenant spoofing, IDOR, autoasignación de rol, profile huérfano, empleado cruzado, secreto cliente y borrado de auditoría. Controles: FK compuesta, tenant derivado del JWT, RLS, DML revocado, RPC service-only, auditoría append-only y bootstrap de un uso.

Pendientes productivos: MFA administrativo, rate-limit Edge, rotación de secretos, pgTAP RLS, retención de auditoría, cifrado de campos bancarios y migración de PIN local heredado. Nunca almacenar huellas, tokens, contraseñas ni `service_role` en tablas/logs/clientes.
