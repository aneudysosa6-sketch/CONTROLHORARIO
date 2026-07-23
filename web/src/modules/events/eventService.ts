import { journeyService, type Journey } from '../journeys/journeyService';
import { supervisorService, type SupervisorIncident } from '../supervisor/supervisorService';

export type EventPriority = 'CRITICA' | 'ALTA' | 'MEDIA' | 'BAJA' | 'INFORMATIVA';
export type EventStatus = 'Pendiente' | 'Revisado' | 'Cerrado';
export type EventRecord = { id: string; journeyId: string; date: string; employee: string; code: string; branch: string; department: string; type: string; priority: EventPriority; status: EventStatus; description: string; observations: string; workedMinutes: number };
const priority = (severity: string): EventPriority => severity === 'CRITICA' ? 'CRITICA' : severity === 'ALTA' ? 'ALTA' : severity === 'MEDIA' ? 'MEDIA' : severity === 'BAJA' ? 'BAJA' : 'INFORMATIVA';
const map = (journey: Journey): EventRecord[] => journey.incidents.map((incident) => ({ id: incident.id, journeyId: journey.id, date: incident.createdAt, employee: journey.employee, code: journey.code, branch: journey.branch, department: journey.department, type: incident.type, priority: priority(incident.severity), status: incident.resolved ? 'Cerrado' : incident.read ? 'Revisado' : 'Pendiente', description: incident.message, observations: '', workedMinutes: journey.workedMinutes }));
const mapAssigned = (incident: SupervisorIncident): EventRecord => ({
  id: incident.id,
  journeyId: incident.jornada_id,
  date: incident.creada_en,
  employee: incident.nombre,
  code: incident.codigo,
  branch: incident.sucursal,
  department: incident.departamento,
  type: incident.tipo,
  priority: priority(incident.severidad),
  status: incident.resuelta ? 'Cerrado' : incident.leida ? 'Revisado' : 'Pendiente',
  description: incident.mensaje,
  observations: '',
  workedMinutes: incident.minutos ?? 0,
});

export const eventService = {
  /** Incidencias visibles por el alcance general del usuario. */
  list: async () => (await journeyService.list()).flatMap(map),
  /** Incidencias de los departamentos asignados al supervisor autenticado. */
  listAssignedToMe: async () => (await supervisorService.incidents()).map(mapAssigned),
  review: (id: string) => supervisorService.markIncidentRead(id),
  close: (id: string, observations: string) => supervisorService.resolveIncident(id, true, observations),
  reopen: (id: string, observations: string) => supervisorService.resolveIncident(id, false, observations),
};
