export type { NotificationChannel, NotificationPayload, NotificationProvider, NotificationResult, NotificationType } from '../notifications/NotificationProvider';
import type { EventRecord } from './eventService';
export const notificationProvider = { notify: async (_event: EventRecord) => undefined };
