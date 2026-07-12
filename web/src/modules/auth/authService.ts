import type { AuthChangeEvent, Session as SupabaseSession } from '@supabase/supabase-js';
import { navigationItems } from '../../app/navigation';
import { getSupabaseClient } from '../../infrastructure/supabase/client';
import type { Session } from '../../types';

type ProfileRow = {
  id: string;
  company_id: string;
  status: string;
  full_name: string;
  role_id: string;
};

type RoleRow = { name: string; code: string; is_active: boolean };

const permissionCodes = [...new Set(['portal.acceder', ...navigationItems.map(item => item.permission)])];

export async function hydrateSession(authSession: SupabaseSession): Promise<Session> {
  const supabase = getSupabaseClient();
  const { data: profileData, error: profileError } = await supabase
    .from('profiles')
    .select('id,company_id,status,full_name,role_id')
    .eq('id', authSession.user.id)
    .maybeSingle();

  if (profileError) throw new Error(`No fue posible consultar tu profile: ${profileError.message}`);
  if (!profileData) throw new Error('Tu cuenta Auth no está vinculada a un profile empresarial.');

  const profile = profileData as ProfileRow;
  if (profile.id !== authSession.user.id) throw new Error('El profile devuelto no corresponde al usuario autenticado.');
  if (profile.status !== 'active') {
    await supabase.auth.signOut();
    throw new Error('Tu acceso está inactivo. Contacta a un administrador.');
  }

  const { data: roleData, error: roleError } = await supabase
    .from('roles')
    .select('name,code,is_active')
    .eq('id', profile.role_id)
    .eq('company_id', profile.company_id)
    .maybeSingle();

  if (roleError) throw new Error(`No fue posible consultar el rol de tu profile: ${roleError.message}`);
  if (!roleData) throw new Error('El profile no tiene un rol válido dentro de su empresa.');
  const role = roleData as RoleRow;
  if (!role.is_active) {
    await supabase.auth.signOut();
    throw new Error('El rol asignado a tu cuenta está inactivo.');
  }

  const checks = await Promise.all(permissionCodes.map(async codigo => {
    const { data: allowed, error: rpcError } = await supabase.rpc('tiene_permiso', { codigo_permiso: codigo });
    if (rpcError) throw new Error(`No fue posible resolver el permiso ${codigo}: ${rpcError.message}`);
    return [codigo, allowed === true] as const;
  }));
  const permissions = checks.filter(([, allowed]) => allowed).map(([codigo]) => codigo);
  if (!permissions.includes('portal.acceder')) {
    await supabase.auth.signOut();
    throw new Error('Tu cuenta no tiene permiso para acceder al portal.');
  }

  return {
    id: authSession.user.id,
    email: authSession.user.email ?? '',
    name: profile.full_name,
    role: role.name,
    roleCode: role.code,
    status: profile.status,
    permissions,
  };
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
    if (!data.session) throw new Error('Supabase no devolvió una sesión válida.');
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
