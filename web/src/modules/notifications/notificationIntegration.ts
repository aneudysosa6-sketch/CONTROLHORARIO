import { authService } from '../auth/authService';
import { notificationService } from './notificationService';
import type { NotificationChannel, NotificationType } from './NotificationProvider';

const sent = new Set<string>();
export function publishNotification(type: NotificationType, subject: string, data: Record<string, unknown>, correlationId: string, channels: NotificationChannel[] = ['webhook']) {
  if (sent.has(correlationId)) return;
  sent.add(correlationId);
  void (async () => { try { const session = await authService.current(); if (!session) throw new Error('No hay sesión para identificar la empresa.'); const result = await notificationService.send({ type, channels, companyId: session.companyId, occurredAt: new Date().toISOString(), subject, data, correlationId }); console.info('[notifications] delivered', { correlationId, accepted: result.accepted, attempts: result.attempts }); } catch (error) { console.warn('[notifications] delivery skipped or failed', { correlationId, type, message: error instanceof Error ? error.message : 'Error desconocido' }); sent.delete(correlationId); } })();
}
