import { BarChart3, CalendarClock, Clock3, FileBarChart, LayoutDashboard, Settings, Users, WalletCards, type LucideIcon } from 'lucide-react';
export type NavigationSection='Inicio'|'Personal'|'Tiempo'|'Nómina'|'Reportes'|'Administración';
export interface NavigationItem{to:string;label:string;section:NavigationSection;permission:string;icon:LucideIcon}
export const navigationItems:NavigationItem[]=[
 {to:'/dashboard',label:'Dashboard',section:'Inicio',permission:'portal.ver_dashboard',icon:LayoutDashboard},
 {to:'/empleados',label:'Empleados',section:'Personal',permission:'empleados.ver_todos',icon:Users},
 {to:'/asistencia',label:'Asistencia',section:'Tiempo',permission:'asistencia.ver_todas',icon:Clock3},
 {to:'/jornadas',label:'Jornadas',section:'Tiempo',permission:'asistencia.ver_todas',icon:CalendarClock},
 {to:'/kiosco',label:'Modo kiosco',section:'Tiempo',permission:'asistencia.registrar_propia',icon:BarChart3},
 {to:'/nomina',label:'Procesamiento',section:'Nómina',permission:'nomina.procesar',icon:WalletCards},
 {to:'/reportes',label:'Reportes',section:'Reportes',permission:'reportes.ver_globales',icon:FileBarChart},
 {to:'/configuracion',label:'Configuración',section:'Administración',permission:'configuracion.administrar',icon:Settings},
];
export const navigationSections:NavigationSection[]=['Inicio','Personal','Tiempo','Nómina','Reportes','Administración'];
