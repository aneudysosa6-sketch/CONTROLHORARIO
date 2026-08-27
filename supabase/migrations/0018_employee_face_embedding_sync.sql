alter table public.empleados add column if not exists face_embedding jsonb null;
alter table public.empleados add constraint empleados_face_embedding_array check (face_embedding is null or jsonb_typeof(face_embedding)='array') not valid;
