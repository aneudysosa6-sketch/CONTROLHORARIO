import type { Session } from '../../types';

type PostgrestFailure = { code?: unknown; message?: unknown; details?: unknown; hint?: unknown };
const text = (value: unknown) => typeof value === 'string' ? value : '';

export function dashboardErrorMessage(error: unknown): string {
  const failure = (error && typeof error === 'object' ? error : {}) as PostgrestFailure;
  const message = error instanceof Error ? error.message : text(failure.message);
  return [
    text(failure.code) && `Código ${text(failure.code)}`,
    message || 'Error desconocido al consultar el dashboard.',
    text(failure.details) && `Details: ${text(failure.details)}`,
    text(failure.hint) && `Hint: ${text(failure.hint)}`,
  ].filter(Boolean).join(' · ');
}

export function logDashboardFailure(query: string, error: unknown, session: Session | null) {
  const failure = (error && typeof error === 'object' ? error : {}) as PostgrestFailure;
  console.error('[Dashboard]', {
    query,
    code: text(failure.code) || null,
    error: error instanceof Error ? error.message : text(failure.message) || 'Error desconocido',
    details: text(failure.details) || null,
    hint: text(failure.hint) || null,
    role_id: session?.roleId ?? null,
    company_id: session?.companyId ?? null,
    permisos_cargados: session?.permissions ?? [],
  });
}
