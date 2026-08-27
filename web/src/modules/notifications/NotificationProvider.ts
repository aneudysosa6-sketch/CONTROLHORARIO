export type NotificationChannel = 'whatsapp' | 'email' | 'webhook' | 'push';
export type NotificationType = 'journey_started' | 'journey_finished' | 'journey_incomplete' | 'late_arrival' | 'absence' | 'lunch_exceeded' | 'early_departure' | 'overtime' | 'employee_deactivated' | 'schedule_changed' | 'supervisor_changed' | 'department_changed' | 'payroll_generated' | 'loan_approved' | 'loan_rejected' | 'critical_event';
export type NotificationPayload = { type: NotificationType; channels: NotificationChannel[]; companyId: string; occurredAt: string; subject: string; data: Record<string, unknown>; correlationId?: string };
export type NotificationResult = { accepted: boolean; status?: number; requestId: string; attempts: number };
export interface NotificationProvider { send(payload: NotificationPayload): Promise<NotificationResult>; }
