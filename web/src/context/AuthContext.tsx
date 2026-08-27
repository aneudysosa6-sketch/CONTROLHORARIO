import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';
import { authService, hydrateSession } from '../modules/auth/authService';
import { createPermissionReader, isAdministratorRole } from '../infrastructure/permissions/permissionAdapter';
import type { Session } from '../types';

type AuthValue = {
  session: Session | null;
  loading: boolean;
  error: string;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  refresh: () => Promise<Session | null>;
  requestPasswordReset: (email: string) => Promise<void>;
  updatePassword: (password: string) => Promise<void>;
  hasPermission: (permission: string) => boolean;
};

const AuthContext = createContext<AuthValue | null>(null);

const message = (error: unknown) => error instanceof Error ? error.message : 'No fue posible completar la operación.';

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;

    authService.current()
      .then((value) => {
        if (active) {
          setSession(value);
          if (import.meta.env.DEV) {
            console.debug('[auth] sesión hidratada', value ? {
              usuario: value.email,
              empresa: value.companyId,
              rol: value.role,
              roleCode: value.roleCode,
              roleCodeCanonical: value.roleCodeCanonical,
              permisos: value.permissions,
              isAdministrator: isAdministratorRole(value.roleCode, value.role),
              permission_codes: value.permissions,
            } : { usuario: null });
          }
        }
      })
      .catch((e) => {
        if (active) setError(message(e));
      })
      .finally(() => {
        if (active) setLoading(false);
      });

    const subscription = authService.listen((event, authSession) => {
      if (!active) return;
      if (event === 'SIGNED_OUT') {
        setSession(null);
        setLoading(false);
        return;
      }
      if (authSession && (event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED' || event === 'USER_UPDATED')) {
        setLoading(true);
        setTimeout(() => {
          hydrateSession(authSession)
            .then((value) => {
              if (active) {
                setSession(value);
                setError('');
                if (import.meta.env.DEV) {
                  console.debug('[auth] sesión actualizada', {
                    usuario: value.email,
                    empresa: value.companyId,
                    rol: value.role,
                    roleCode: value.roleCode,
                    roleCodeCanonical: value.roleCodeCanonical,
                    permisos: value.permissions,
                    isAdministrator: isAdministratorRole(value.roleCode, value.role),
                    permission_codes: value.permissions,
                  });
                }
              }
            })
            .catch((e) => {
              if (active) {
                setSession(null);
                setError(message(e));
              }
            })
            .finally(() => {
              if (active) setLoading(false);
            });
        }, 0);
      }
    });

    let refreshRunning = false;
    const refreshAuthoritative = async () => {
      if (!active || refreshRunning) return;
      refreshRunning = true;
      try {
        const value = await authService.current();
        if (active) {
          setSession(value);
          setError('');
        }
      } catch (e) {
        if (active) {
          const visible = message(e);
          if (/AUTHORIZATION_INACTIVE|PROFILE_INACTIVE|COMPANY_INACTIVE|ROLE_INACTIVE|HTTP_401/.test(visible)) {
            setSession(null);
          }
          setError(visible);
        }
      } finally {
        refreshRunning = false;
      }
    };
    const interval = window.setInterval(() => void refreshAuthoritative(), 5_000);
    const onFocus = () => void refreshAuthoritative();
    const onVisibility = () => { if (document.visibilityState === 'visible') void refreshAuthoritative(); };
    window.addEventListener('focus', onFocus);
    document.addEventListener('visibilitychange', onVisibility);

    return () => {
      active = false;
      window.clearInterval(interval);
      window.removeEventListener('focus', onFocus);
      document.removeEventListener('visibilitychange', onVisibility);
      subscription.unsubscribe();
    };
  }, []);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const value = await authService.current();
      setSession(value);
      return value;
    } finally {
      setLoading(false);
    }
  }, []);

  const login = async (email: string, password: string) => {
    setLoading(true);
    setError('');
    try {
      setSession(await authService.login(email, password));
    } finally {
      setLoading(false);
    }
  };

  const logout = async () => {
    await authService.logout();
    setSession(null);
  };

  const hasPermission = (permission: string) => {
    const administrator = Boolean(session && isAdministratorRole(session.roleCode, session.role));
    const assigned = createPermissionReader(session?.permissions).has(permission);
    const allowed = administrator || assigned;

    const motivo = !session
      ? 'sin sesión'
      : administrator
      ? 'rol administrador normalizado'
      : assigned
      ? 'permiso explícito'
      : 'permiso no cargado';

    if (import.meta.env.DEV) {
      console.debug('[auth] decisión permiso', {
        usuario: session?.email ?? null,
        empresa: session?.companyId ?? null,
        rol: session?.role ?? null,
        roleCode: session?.roleCode ?? null,
        roleCodeCanonical: session?.roleCodeCanonical ?? null,
        permission_codes: session?.permissions ?? [],
        permisoRequerido: permission,
        hasPermission: allowed,
        isAdministrator: administrator,
        motivo,
      });
    }

    return allowed;
  };

  return <AuthContext.Provider value={{
    session,
    loading,
    error,
    login,
    logout,
    refresh,
    requestPasswordReset: authService.requestPasswordReset,
    updatePassword: authService.updatePassword,
    hasPermission,
  }}>
    {children}
  </AuthContext.Provider>;
}

export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) throw new Error('AuthProvider requerido');
  return value;
}
