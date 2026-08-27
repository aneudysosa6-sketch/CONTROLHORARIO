import { getSupabaseClient } from '../../infrastructure/supabase/client';

export type EmployeeMessageType = 'TEXTO' | 'VOZ_SISTEMA' | 'VOZ_GRABADA';

export interface CreateEmployeeMessageInput {
  employeeId: string;
  type: EmployeeMessageType;
  text: string | null;
  audioObjectPath: string | null;
  audioDurationSeconds: number | null;
  idempotencyKey: string;
}

async function create(input: CreateEmployeeMessageInput) {
  const { data, error } = await getSupabaseClient().rpc('crear_mensaje_empleado', {
    p_empleado: input.employeeId,
    p_tipo: input.type,
    p_contenido_texto: input.text,
    p_audio_object_path: input.audioObjectPath,
    p_audio_duracion_segundos: input.audioDurationSeconds,
    p_idempotency_key: input.idempotencyKey,
  });
  if (error) throw error;
  return data as { id: string; status: 'PENDIENTE'; idempotent_replay: boolean };
}

async function uploadAudio(companyId: string, file: File) {
  const extension = file.name.split('.').pop()?.replace(/[^a-z0-9]/gi, '').toLowerCase() || 'webm';
  const path = companyId + '/' + crypto.randomUUID() + '.' + extension;
  const { error } = await getSupabaseClient().storage
    .from('employee-message-audio')
    .upload(path, file, { contentType: file.type || 'audio/webm', upsert: false });
  if (error) throw error;
  return path;
}

async function removeAudio(path: string) {
  await getSupabaseClient().storage.from('employee-message-audio').remove([path]);
}

export const employeeMessageService = { create, uploadAudio, removeAudio };