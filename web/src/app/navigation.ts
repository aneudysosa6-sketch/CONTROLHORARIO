import {
  AlertTriangle,
  CalendarClock,
  Clock3,
  CreditCard,
  LayoutDashboard,
  ListChecks,
  MonitorCog,
  Settings,
  ShieldCheck,
  Smartphone,
  UserCog,
  UserX,
  Users,
  type LucideIcon,
} from 'lucide-react';

/**
 * The sidebar is deliberately limited to the operating model of the product.
 * Other routes may still be opened by contextual actions, but they are not
 * duplicate modules in the main navigation.
 */
export type NavigationSection =
  | 'Dashboard'
  | 'PERSONAL'
  | 'OPERACIONES'
  | 'NÓMINA'
  | 'ORGANIZACIÓN'
  | 'SEGURIDAD'
  | 'CONFIGURACIÓN';

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
    label: 'Dashboard',
    section: 'Dashboard',
    permission: 'dashboard.view',
    icon: LayoutDashboard,
  },

  {
    to: '/empleados',
    label: 'Empleados',
    section: 'PERSONAL',
    permission: ['empleados.view', 'empleados.ver_asignados'],
    icon: Users,
  },
  {
    to: '/accesos',
    label: 'Usuarios',
    section: 'PERSONAL',
    permission: ['usuarios.view', 'usuarios.administrar'],
    icon: UserCog,
  },
  {
    to: '/empleados/bajas',
    label: 'Empleados dados de baja',
    section: 'PERSONAL',
    permission: ['empleados.view', 'reportes.empleados_baja'],
    icon: UserX,
  },

  {
    to: '/asistencia',
    label: 'Asistencia',
    section: 'OPERACIONES',
    permission: ['jornadas.ver_todas', 'jornadas.ver_asignadas'],
    icon: Clock3,
  },
  {
    to: '/jornadas',
    label: 'Jornadas',
    section: 'OPERACIONES',
    permission: ['jornadas.ver_todas', 'jornadas.ver_asignadas'],
    icon: CalendarClock,
  },
  {
    to: '/incidencias',
    label: 'Incidencias',
    section: 'OPERACIONES',
    permission: ['eventos.view', 'incidencias.ver_asignadas'],
    icon: AlertTriangle,
  },
  {
    to: '/pendientes',
    label: 'Pendientes',
    section: 'OPERACIONES',
    permission: ['jornadas.ver_todas', 'jornadas.ver_asignadas'],
    icon: ListChecks,
  },

  {
    to: '/nomina',
    label: 'Procesamiento',
    section: 'NÓMINA',
    permission: 'nomina.ver',
    icon: Settings,
  },
  {
    to: '/nomina/descuentos',
    label: 'Descuentos',
    section: 'NÓMINA',
    permission: 'nomina.descuentos',
    icon: Settings,
  },
  {
    to: '/nomina/pagos',
    label: 'Pagos',
    section: 'NÓMINA',
    permission: 'nomina.ver',
    icon: CreditCard,
  },

  {
    to: '/empresas',
    label: 'Empresas',
    section: 'ORGANIZACIÓN',
    permission: 'empresas.view',
    icon: Settings,
  },
  {
    to: '/sucursales',
    label: 'Sucursales',
    section: 'ORGANIZACIÓN',
    permission: 'sucursales.view',
    icon: Settings,
  },
  {
    to: '/departamentos',
    label: 'Departamentos',
    section: 'ORGANIZACIÓN',
    permission: 'departamentos.view',
    icon: Settings,
  },
  {
    to: '/administracion/cargos',
    label: 'Cargos',
    section: 'ORGANIZACIÓN',
    permission: ['configuracion.administrar', 'configuracion.cargos'],
    icon: UserCog,
  },

  {
    to: '/administracion/accesos',
    label: 'Roles y permisos',
    section: 'SEGURIDAD',
    permission: ['usuarios.administrar', 'roles.administrar', 'permisos.administrar'],
    icon: ShieldCheck,
  },
  {
    to: '/administracion/dispositivos',
    label: 'Dispositivos Android',
    section: 'SEGURIDAD',
    permission: 'dispositivos.ver',
    icon: Smartphone,
  },
  {
    to: '/administracion/seguridad',
    label: 'Seguridad y auditoría',
    section: 'SEGURIDAD',
    permission: ['configuracion.administrar', 'configuracion.seguridad'],
    icon: ShieldCheck,
  },

  {
    to: '/administracion/horarios',
    label: 'Horarios',
    section: 'CONFIGURACIÓN',
    permission: ['configuracion.administrar', 'configuracion.horarios', 'horarios.ver_asignados'],
    icon: CalendarClock,
  },
  {
    to: '/administracion/jornadas',
    label: 'Jornadas',
    section: 'CONFIGURACIÓN',
    permission: ['configuracion.administrar', 'configuracion.jornadas'],
    icon: Clock3,
  },
  {
    to: '/kiosco',
    label: 'Modo kiosco',
    section: 'CONFIGURACIÓN',
    permission: 'asistencia.registrar_propia',
    icon: MonitorCog,
  },
];

export const navigationSections: NavigationSection[] = [
  'Dashboard',
  'PERSONAL',
  'OPERACIONES',
  'NÓMINA',
  'ORGANIZACIÓN',
  'SEGURIDAD',
  'CONFIGURACIÓN',
];
