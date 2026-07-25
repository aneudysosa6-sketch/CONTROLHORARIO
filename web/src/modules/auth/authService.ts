import type { AuthChangeEvent, Session as SupabaseSession } from '@supabase/supabase-js';
import { getSupabaseClient } from '../../infrastructure/supabase/client';
import type { Session } from '../../types';

type ServerAuthorization = {
  auth_user_id: string;
  profile_id: string;
  company_id: string;
  employee_id: string | null;
  email: string;
  nombre: string;
  role_id: string;
  role_code_original: string;
  role_code_canonical: string;
  role_name: string;
  active: boolean;
  permission_codes: unknown;
};

const normalizeRoleForClient = (value: string): string => {
  const normalized = value.trim().toUpperCase();
  const map: Record<string, string> = {
    ADMIN: 'admin',
    ADMINISTRADOR: 'admin',
    ADMINISTRATOR: 'admin',
    SUPERVISOR: 'supervisor',
    EMPLEADO: 'employee',
    RRHH: 'rrhh',
    NOMINA: 'nomina',
    AUDITOR: 'auditor',
  };
  return map[normalized] ?? normalized.toLowerCase();
};

const asPermissionCodes = (value: unknown): string[] => {
  if (!Array.isArray(value)) return [];
  return value.map((item) => String(item)).filter(Boolean);
};

export async function hydrateSession(authSession: SupabaseSession): Promise<Session> {
  const supabase = getSupabaseSessionClient();
  const { data, error } = await supabase.rpc('obtener_mi_autorizacion');
  if (error) {
    throw new Error(`No fue posible cargar tu autorización: ${error.message}`);
  }
  const authorization = (Array.isArray(data) ? data[0] : data) as ServerAuthorization | null | undefined;
  if (!authorization) {
    throw new Error('No fue posible obtener una autorización válida del backend.');
  }

  const permissionCodes = asPermissionCodes(authorization.permission_codes);
  const canonicalRole = (authorization.role_code_canonical ?? authorization.role_code_original ?? '').trim();
  const clientRoleCode = canonicalRole
    ? normalizeRoleForClient(canonicalRole)
    : (authorization.role_code_original?.toLowerCase().trim() ?? '');

  if (import.meta.env.DEV) {
    console.debug('[auth] autorización rpc', {
      role_code_canonical: canonicalRole,
      permission_codes: permissionCodes,
      role_code_original: authorization.role_code_original,
      role_name: authorization.role_name,
      role_code_client: clientRoleCode,
      company_id: authorization.company_id,
      active: authorization.active,
    });
  }

  return {
    id: authSession.user.id,
    email: authorization.email ?? authSession.user.email ?? '',
    name: authorization.nombre,
    role: authorization.role_name,
    roleCode: clientRoleCode,
    roleCodeCanonical: canonicalRole,
    roleId: authorization.role_id,
    companyId: authorization.company_id,
    status: authorization.active ? 'active' : 'inactive',
    permissions: permissionCodes,
  };
}

function getSupabaseSessionClient() {
  return getSupabaseClient();
}

export const authService = {
  async current() {
    const { data, error } = await getSupabaseClient().auth.getSession();
    if (error) throw error;
    return data.session ? hydrateSession(data.session) : null;
  },
  async login(email: string, password: string) {
    const { data, error } = await getSupabaseClient().auth.signInWithPassword({ email, password });
    if (error) throw error;
    if (!data.session) {
      throw new Error('Supabase no devolvió una sesión válida.');
    }
    return hydrateSession(data.session);
  },
  async logout() {
    const { error } = await getSupabaseClient().auth.signOut();
    if (error) throw error;
  },
  async requestPasswordReset(email: string) {
    const { error } = await getSupabaseClient().auth.resetPasswordForEmail(email, { redirectTo: `${window.location.origin}/actualizar-password` });
    if (error) throw error;
  },
  async updatePassword(password: string) {
    const { error } = await getSupabaseClient().auth.updateUser({ password });
    if (error) throw error;
  },
  listen(callback: (event: AuthChangeEvent, session: SupabaseSession | null) => void) {
    return getSupabaseClient().auth.onAuthStateChange(callback).data.subscription;
  },
};
