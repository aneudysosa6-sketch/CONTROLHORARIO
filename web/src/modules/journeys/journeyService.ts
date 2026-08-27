import { getSupabaseClient } from "../../infrastructure/supabase/client";
export {
  ATTENDANCE_CONTRACT_VERSION,
  applyCanonicalTransition,
  allowedCanonicalActions,
} from "./attendanceContract";
export type JourneyStatus =
  "SIN_INICIAR" | "EN_CURSO" | "EN_PAUSA" | "FINALIZADA";
export type Journey = {
  id: string;
  employeeId: string;
  employee: string;
  code: string;
  branch: string;
  department: string;
  workDate: string;
  status: JourneyStatus;
  workedMinutes: number;
  breakMinutes: number;
  pendingReview: boolean;
  severity: string;
  updatedAt: string;
  incidents: JourneyIncident[];
};
export type JourneyIncident = {
  id: string;
  journeyId: string;
  type: string;
  severity: string;
  minutes: number | null;
  message: string;
  read: boolean;
  resolved: boolean;
  createdAt: string;
};
export type JourneyConflict = {
  id: string;
  journeyId: string;
  reason: string;
  status: string;
  createdAt: string;
};
export const journeyService = {
  async list(): Promise<Journey[]> {
    const { data, error } = await getSupabaseClient()
      .from("jornadas")
      .select(
        "id,empleado_id,fecha_laboral,estado,minutos_trabajados,minutos_pausa,revision_pendiente,severidad,actualizada_en,empleados!inner(codigo_empleado,nombre_completo,branches!empleados_sucursal_misma_empresa_fk(name),departments!empleados_departamento_misma_empresa_fk(name)),jornada_incidencias(id,jornada_id,tipo,severidad,minutos,mensaje,leida,resuelta,creada_en)",
      )
      .order("fecha_laboral", { ascending: false });
    if (error) throw error;
    return (data ?? []).map((row: any) => ({
      id: row.id,
      employeeId: row.empleado_id,
      employee: row.empleados?.nombre_completo ?? "",
      code: row.empleados?.codigo_empleado ?? "",
      branch: row.empleados?.branches?.name ?? "",
      department: row.empleados?.departments?.name ?? "",
      workDate: row.fecha_laboral,
      status: row.estado,
      workedMinutes: row.minutos_trabajados ?? 0,
      breakMinutes: row.minutos_pausa ?? 0,
      pendingReview: row.revision_pendiente === true,
      severity: row.severidad ?? "NINGUNA",
      updatedAt: row.actualizada_en,
      incidents: (row.jornada_incidencias ?? []).map((x: any) => ({
        id: x.id,
        journeyId: x.jornada_id,
        type: x.tipo,
        severity: x.severidad,
        minutes: x.minutos,
        message: x.mensaje,
        read: x.leida,
        resolved: x.resuelta,
        createdAt: x.creada_en,
      })),
    }));
  },
  async incidents(): Promise<JourneyIncident[]> {
    const { data, error } = await getSupabaseClient()
      .from("jornada_incidencias")
      .select(
        "id,jornada_id,tipo,severidad,minutos,mensaje,leida,resuelta,creada_en",
      )
      .order("creada_en", { ascending: false });
    if (error) throw error;
    return (data ?? []).map((x: any) => ({
      id: x.id,
      journeyId: x.jornada_id,
      type: x.tipo,
      severity: x.severidad,
      minutes: x.minutos,
      message: x.mensaje,
      read: x.leida,
      resolved: x.resuelta,
      createdAt: x.creada_en,
    }));
  },
  async conflicts(): Promise<JourneyConflict[]> {
    const { data, error } = await getSupabaseClient()
      .from("jornada_conflictos")
      .select("id,jornada_id,motivo,estado,creado_en")
      .order("creado_en", { ascending: false });
    if (error) throw error;
    return (data ?? []).map((x: any) => ({
      id: x.id,
      journeyId: x.jornada_id,
      reason: x.motivo,
      status: x.estado,
      createdAt: x.creado_en,
    }));
  },
  async approve(journeyId: string, reason: string) {
    const { error } = await getSupabaseClient().rpc(
      "resolver_jornada_pendiente",
      { p_jornada: journeyId, p_decision: "APROBADA", p_motivo: reason },
    );
    if (error) throw error;
  },
  async setEnabled(employeeId: string, enabled: boolean, reason: string) {
    const { error } = await getSupabaseClient().rpc(
      "establecer_jornada_habilitada",
      { p_empleado: employeeId, p_habilitada: enabled, p_motivo: reason },
    );
    if (error) throw error;
  },
};
