import type { NotificationPayload, NotificationProvider, NotificationResult } from './NotificationProvider';
import { N8nProvider } from './n8nProvider';

let provider: NotificationProvider = new N8nProvider();
export const notificationService = { send: (payload: NotificationPayload): Promise<NotificationResult> => provider.send(payload), setProvider: (next: NotificationProvider) => { provider = next; } };
// Punto de extensión: los módulos pueden importar notificationService y enviar un payload después de sus operaciones existentes.
