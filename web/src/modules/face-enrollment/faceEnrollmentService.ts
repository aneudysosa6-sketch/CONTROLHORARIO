import { getSupabaseClient } from '../../infrastructure/supabase/client';

export interface FaceEnrollmentStatus {
  employee_id: string;
  face_status: 'PENDING' | 'ENROLLED';
  face_enrolled_at: string | null;
}

export const faceEnrollmentService = {
  async status(employeeId: string): Promise<FaceEnrollmentStatus> {
    const { data, error } = await getSupabaseClient().rpc(
      'estado_enrolamiento_facial_empleado',
      { p_empleado: employeeId },
    );
    if (error) throw error;
    const row = Array.isArray(data) ? data[0] : data;
    if (!row) throw new Error('FACE_STATUS_NOT_FOUND');
    return {
      employee_id: String(row.employee_id),
      face_status: row.face_status === 'ENROLLED' ? 'ENROLLED' : 'PENDING',
      face_enrolled_at: typeof row.face_enrolled_at === 'string' ? row.face_enrolled_at : null,
    };
  },

  async reset(employeeId: string): Promise<boolean> {
    const { data, error } = await getSupabaseClient().rpc(
      'eliminar_rostro_empleado',
      { p_empleado: employeeId },
    );
    if (error) throw error;
    return data === true;
  },
};
