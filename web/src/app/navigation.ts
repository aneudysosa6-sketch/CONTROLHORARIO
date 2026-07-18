import {
  AlertTriangle,
  BarChart3,
  CalendarCheck2,
  CalendarClock,
  Calculator,
  Clock3,
  CreditCard,
  FileBarChart,
  HandCoins,
  History,
  LayoutDashboard,
  ListChecks,
  Settings,
  ShieldCheck,
  Smartphone,
  UserCog,
  Users,
  type LucideIcon,
} from 'lucide-react';

export type NavigationSection =
  | 'Inicio'
  | 'Personal'
  | 'Tiempo'
  | 'Nómina'
  | 'Eventos'
  | 'Reportes'
  | 'Organización'
  | 'Administración';

export interface NavigationItem {
  to: string;
  label: string;
  section: NavigationSection;
  permission: string | string[];
  icon: LucideIcon;
}

export const navigationItems: NavigationItem[] = [
  {
    to: '/dashboard',
    label: 'Dashboard ejecutivo',
    section: 'Inicio',
    permission: 'dashboard.view',
    icon: LayoutDashboard,
  },

  {
    to: '/empleados',
    label: 'Empleados',
    section: 'Personal',
    permission: 'empleados.view',
    icon: Users,
  },
  {
    to: '/equipo',
    label: 'Mi equipo',
    section: 'Personal',
    permission: 'empleados.ver_asignados',
    icon: Users,
  },
  {
    to: '/supervisores',
    label: 'Supervisores',
    section: 'Personal',
    permission: 'supervisores.view',
    icon: UserCog,
  },

  {
    to: '/asistencia',
    label: 'Asistencia',
    section: 'Tiempo',
    permission: 'jornadas.ver_todas',
    icon: Clock3,
  },
  {
    to: '/jornadas',
    label: 'Jornadas',
    section: 'Tiempo',
    permission: 'jornadas.ver_todas',
    icon: CalendarClock,
  },
  {
    to: '/supervisor/jornadas',
    label: 'Jornadas asignadas',
    section: 'Tiempo',
    permission: 'jornadas.ver_asignadas',
    icon: CalendarClock,
  },
  {
    to: '/supervisor/pendientes',
    label: 'Pendientes',
    section: 'Tiempo',
    permission: 'jornadas.ver_asignadas',
    icon: ListChecks,
  },
  {
    to: '/supervisor/auditoria',
    label: 'Auditoría operativa',
    section: 'Tiempo',
    permission: 'jornadas.ver_asignadas',
    icon: ShieldCheck,
  },
  {
    to: '/supervisor/incidencias',
    label: 'Incidencias asignadas',
    section: 'Tiempo',
    permission: 'incidencias.ver_asignadas',
    icon: AlertTriangle,
  },
  {
    to: '/supervisor/horarios',
    label: 'Horarios asignados',
    section: 'Tiempo',
    permission: 'horarios.ver_asignados',
    icon: Clock3,
  },
  {
    to: '/kiosco',
    label: 'Modo kiosco',
    section: 'Tiempo',
    permission: 'asistencia.registrar_propia',
    icon: BarChart3,
  },

  {
    to: '/nomina',
    label: 'Procesamiento',
    section: 'Nómina',
    permission: 'nomina.ver',
    icon: Calculator,
  },
  {
    to: '/nomina/descuentos',
    label: 'Descuentos',
    section: 'Nómina',
    permission: 'nomina.descuentos',
    icon: Calculator,
  },
  {
    to: '/nomina/pagos',
    label: 'Pagos',
    section: 'Nómina',
    permission: 'nomina.ver',
    icon: CreditCard,
  },
  {
    to: '/nomina/cierre',
    label: 'Cierre de nómina',
    section: 'Nómina',
    permission: 'nomina.cierre',
    icon: ShieldCheck,
  },
  {
    to: '/nomina/historial',
    label: 'Historial de nómina',
    section: 'Nómina',
    permission: 'nomina.historial',
    icon: History,
  },
  {
    to: '/prestamos',
    label: 'Préstamos',
    section: 'Nómina',
    permission: 'prestamos.ver',
    icon: HandCoins,
  },
  {
    to: '/prestamos/historial',
    label: 'Historial de préstamos',
    section: 'Nómina',
    permission: 'prestamos.historial',
    icon: History,
  },
  {
    to: '/nomina/solicitudes',
    label: 'Solicitudes de préstamos',
    section: 'Nómina',
    permission: 'prestamos.solicitudes_ver',
    icon: ListChecks,
  },
  {
    to: '/nomina?vista=creditos',
    label: 'Créditos',
    section: 'Nómina',
    permission: 'nomina.ver',
    icon: CreditCard,
  },

  {
    to: '/eventos',
    label: 'Eventos e incidencias',
    section: 'Eventos',
    permission: 'eventos.view',
    icon: AlertTriangle,
  },

  {
    to: '/reportes',
    label: 'Centro de reportes',
    section: 'Reportes',
    permission: 'reportes.ver',
    icon: FileBarChart,
  },
  {
    to: '/reportes/jornadas',
    label: 'Reporte de jornadas',
    section: 'Reportes',
    permission: 'reportes.jornadas',
    icon: CalendarClock,
  },
  {
    to: '/reportes/asistencia',
    label: 'Reporte de asistencia',
    section: 'Reportes',
    permission: 'reportes.asistencia',
    icon: CalendarCheck2,
  },
  {
    to: '/reportes/horas-extras',
    label: 'Reporte de horas extras',
    section: 'Reportes',
    permission: 'reportes.horas_extras',
    icon: Clock3,
  },
  {
    to: '/reportes/nomina',
    label: 'Reporte de nómina',
    section: 'Reportes',
    permission: 'reportes.nomina',
    icon: Calculator,
  },
  {
    to: '/reportes/prestamos',
    label: 'Reporte de préstamos',
    section: 'Reportes',
    permission: 'reportes.prestamos',
    icon: HandCoins,
  },
  {
    to: '/reportes/productividad',
    label: 'Reporte de productividad',
    section: 'Reportes',
    permission: 'reportes.productividad',
    icon: BarChart3,
  },
  {
    to: '/reportes/incidencias',
    label: 'Reporte de incidencias',
    section: 'Reportes',
    permission: 'reportes.incidencias',
    icon: AlertTriangle,
  },
  {
    to: '/reportes/empleados-baja',
    label: 'Empleados dados de baja',
    section: 'Reportes',
    permission: 'reportes.empleados_baja',
    icon: Users,
  },
  {
    to: '/reportes/dias-festivos',
    label: 'Días festivos trabajados',
    section: 'Reportes',
    permission: 'reportes.dias_festivos',
    icon: CalendarCheck2,
  },
  {
    to: '/reportes/permisos',
    label: 'Permisos y licencias',
    section: 'Reportes',
    permission: 'reportes.permisos',
    icon: FileBarChart,
  },

  {
    to: '/empresas',
    label: 'Empresas',
    section: 'Organización',
    permission: 'empresas.view',
    icon: Settings,
  },
  {
    to: '/sucursales',
    label: 'Sucursales',
    section: 'Organización',
    permission: 'sucursales.view',
    icon: Settings,
  },
  {
    to: '/departamentos',
    label: 'Departamentos',
    section: 'Organización',
    permission: 'departamentos.view',
    icon: Settings,
  },

  {
    to: '/administracion',
    label: 'Administración del sistema',
    section: 'Administración',
    permission: ['configuracion.administrar', 'configuracion.ver'],
    icon: Settings,
  },
  {
    to: '/usuarios',
    label: 'Usuarios',
    section: 'Administración',
    permission: 'usuarios.view',
    icon: UserCog,
  },
  {
    to: '/administracion/usuarios',
    label: 'Roles y permisos',
    section: 'Administración',
    permission: [
      'usuarios.administrar',
      'roles.administrar',
      'permisos.administrar',
    ],
    icon: ShieldCheck,
  },
  {
    to: '/administracion/cargos',
    label: 'Cargos',
    section: 'Administración',
    permission: ['configuracion.administrar', 'configuracion.cargos'],
    icon: UserCog,
  },
  {
    to: '/administracion/horarios',
    label: 'Configuración de horarios',
    section: 'Administración',
    permission: ['configuracion.administrar', 'configuracion.horarios'],
    icon: CalendarClock,
  },
  {
    to: '/administracion/jornadas',
    label: 'Configuración de jornadas',
    section: 'Administración',
    permission: ['configuracion.administrar', 'configuracion.jornadas'],
    icon: Clock3,
  },
  {
    to: '/administracion/seguridad',
    label: 'Seguridad y auditoría',
    section: 'Administración',
    permission: ['configuracion.administrar', 'configuracion.seguridad'],
    icon: ShieldCheck,
  },
  {
    to: '/administracion/apariencia',
    label: 'Apariencia',
    section: 'Administración',
    permission: ['configuracion.administrar', 'configuracion.apariencia'],
    icon: Settings,
  },
  {
    to: '/usuarios/sincronizar',
    label: 'Sincronizar usuarios',
    section: 'Administración',
    permission: 'usuarios.administrar',
    icon: UserCog,
  },
  {
    to: '/administracion/dispositivos',
    label: 'Dispositivos Android',
    section: 'Administración',
    permission: 'dispositivos.ver',
    icon: Smartphone,
  },
];

export const navigationSections: NavigationSection[] = [
  'Inicio',
  'Personal',
  'Tiempo',
  'Nómina',
  'Eventos',
  'Reportes',
  'Organización',
  'Administración',
];
