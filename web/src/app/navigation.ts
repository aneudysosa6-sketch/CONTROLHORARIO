import { AlertTriangle, BarChart3, CalendarClock, Clock3, FileBarChart, LayoutDashboard, Settings, ShieldCheck, Smartphone, UserCog, Users, WalletCards, type LucideIcon } from 'lucide-react';
export type NavigationSection='Inicio'|'Personal'|'Tiempo'|'Nómina'|'Reportes'|'Administración';
export interface NavigationItem{to:string;label:string;section:NavigationSection;permission:string;icon:LucideIcon}
export const navigationItems:NavigationItem[]=[
 {to:'/dashboard',label:'Dashboard',section:'Inicio',permission:'portal.ver_dashboard',icon:LayoutDashboard},
 {to:'/equipo',label:'Mi equipo',section:'Personal',permission:'empleados.ver_asignados',icon:Users},
 {to:'/supervisor/jornadas',label:'Jornadas asignadas',section:'Tiempo',permission:'jornadas.ver_asignadas',icon:CalendarClock},
 {to:'/supervisor/pendientes',label:'Pendientes',section:'Tiempo',permission:'jornadas.ver_asignadas',icon:Clock3},
 {to:'/supervisor/incidencias',label:'Incidencias',section:'Tiempo',permission:'incidencias.ver_asignadas',icon:AlertTriangle},
 {to:'/supervisor/horarios',label:'Horarios',section:'Tiempo',permission:'horarios.ver_asignados',icon:Clock3},
 {to:'/supervisor/auditoria',label:'Auditoría operativa',section:'Tiempo',permission:'jornadas.ver_asignadas',icon:ShieldCheck},
 {to:'/empleados',label:'Empleados',section:'Personal',permission:'empleados.ver_todos',icon:Users},
 {to:'/asistencia',label:'Asistencia',section:'Tiempo',permission:'asistencia.ver_todas',icon:Clock3},
 {to:'/jornadas',label:'Jornadas',section:'Tiempo',permission:'asistencia.ver_todas',icon:CalendarClock},
 {to:'/kiosco',label:'Modo kiosco',section:'Tiempo',permission:'asistencia.registrar_propia',icon:BarChart3},
 {to:'/nomina',label:'Procesamiento',section:'Nómina',permission:'nomina.procesar',icon:WalletCards},
 {to:'/reportes',label:'Reportes',section:'Reportes',permission:'reportes.ver_globales',icon:FileBarChart},
 {to:'/configuracion',label:'Configuración',section:'Administración',permission:'configuracion.administrar',icon:Settings},
 {to:'/usuarios/sincronizar',label:'Sincronizar usuarios',section:'Administración',permission:'usuarios.administrar',icon:UserCog},
 {to:'/dispositivos',label:'Dispositivos Android',section:'Administración',permission:'dispositivos.ver',icon:Smartphone},
];
export const navigationSections:NavigationSection[]=['Inicio','Personal','Tiempo','Nómina','Reportes','Administración'];
