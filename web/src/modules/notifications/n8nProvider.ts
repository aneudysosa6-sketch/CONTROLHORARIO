import type { NotificationPayload, NotificationProvider, NotificationResult } from './NotificationProvider';

type N8nConfig = { baseUrl: string; timeoutMs: number; retries: number };
const config = (): N8nConfig => ({ baseUrl: String(import.meta.env.VITE_N8N_BASE_URL ?? '').replace(/\/$/, ''), timeoutMs: Number(import.meta.env.VITE_N8N_TIMEOUT_MS ?? 8000), retries: Number(import.meta.env.VITE_N8N_RETRIES ?? 2) });
const delay = (milliseconds: number) => new Promise((resolve) => setTimeout(resolve, milliseconds));
const requestId = () => crypto.randomUUID();

export class N8nProvider implements NotificationProvider {
  async send(payload: NotificationPayload): Promise<NotificationResult> {
    const { baseUrl, timeoutMs, retries } = config(); const id = requestId();
    if (!baseUrl) throw new Error('N8N no está configurado: falta VITE_N8N_BASE_URL.');
    let lastError: unknown;
    for (let attempt = 1; attempt <= retries + 1; attempt += 1) {
      const controller = new AbortController(); const timer = setTimeout(() => controller.abort(), timeoutMs);
      try { console.info('[notifications] n8n request', { requestId: id, type: payload.type, channels: payload.channels, attempt }); const response = await fetch(`${baseUrl}/webhook/erp-notifications`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Request-Id': id }, body: JSON.stringify(payload), signal: controller.signal }); console.info('[notifications] n8n response', { requestId: id, status: response.status, attempt }); if (!response.ok) throw new Error(`N8N respondió ${response.status}.`); return { accepted: true, status: response.status, requestId: id, attempts: attempt }; } catch (error) { lastError = error; console.warn('[notifications] n8n failure', { requestId: id, type: payload.type, attempt, message: error instanceof Error ? error.message : 'Error desconocido' }); if (attempt <= retries) await delay(250 * attempt); } finally { clearTimeout(timer); }
    }
    throw lastError instanceof Error ? lastError : new Error('No fue posible entregar la notificación a N8N.');
  }
}
