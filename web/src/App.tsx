import type{ReactNode}from'react';
import{Navigate,Outlet,Route,Routes}from'react-router-dom';
import{useAuth}from'./context/AuthContext';
import{AdminLayout}from'./layouts/AdminLayout';
import{ExecutiveDashboardPage}from'./pages/ExecutiveDashboardPage';
import{DevicesPage}from'./pages/DevicesPage';
import{EmployeeDetailPage}from'./pages/EmployeeDetailPage';
import{EmployeeFormPage}from'./pages/EmployeeFormPage';
import{EmployeesPage}from'./pages/EmployeesPage';
import{LoginPage}from'./pages/LoginPage';
import{AccessDeniedPage,PasswordRecoveryPage,PasswordUpdatePage}from'./pages/AuthPages';
import{KioskPage,ReportsPage}from'./pages/OperationsPages';
import{PayrollPage}from'./pages/PayrollPage';
import{PayrollDiscountsPage}from'./pages/PayrollDiscountsPage';
import{PayrollPaymentsPage}from'./pages/PayrollPaymentsPage';
import{PayrollClosurePage,PayrollHistoryPage}from'./pages/PayrollClosurePages';
import{LoansPage}from'./pages/LoansPage';
import{LoanHistoryPage}from'./pages/LoanHistoryPage';
import{ReportsCenterPage}from'./pages/ReportsCenterPage';
import{JourneyReportPage}from'./pages/JourneyReportPage';
import{AttendanceReportPage}from'./pages/AttendanceReportPage';
import{OvertimeReportPage}from'./pages/OvertimeReportPage';
import{HolidaysReportPage,IncidentsReportPage,LoansReportPage,PayrollReportPage,PermissionsReportPage,ProductivityReportPage}from'./pages/RemainingReportsPages';
import{TerminatedEmployeesPage}from'./pages/TerminatedEmployeesPage';
import{AttendancePage,JourneysPage}from'./pages/JourneyPages';
import{SupervisorAuditPage,SupervisorDashboardPage,SupervisorEmployeesPage,SupervisorIncidentsPage,SupervisorJourneysPage,SupervisorSchedulesPage}from'./pages/SupervisorPages';
import{UserProvisioningPage}from'./pages/UserProvisioningPage';
import{BootstrapPage}from'./pages/BootstrapPage';
import{BootstrapGate}from'./pages/BootstrapGate';
import{SystemAdministrationPage}from'./pages/SystemAdministrationPage';
import{EmployeeLayout}from'./layouts/EmployeeLayout';
import{EmployeePortalPage}from'./pages/EmployeePortalPage';
import{LoanRequestsPage}from'./pages/LoanRequestsPage';
import{UsersAdministrationPage}from'./pages/UsersAdministrationPage';
import{EmployeeHistoryPage}from'./pages/EmployeeHistoryPage';
import{BranchesPage,CompaniesPage,DepartmentsPage}from'./pages/OrganizationPages';
import{SupervisorsManagementPage}from'./pages/SupervisorsManagementPage';
import{EventsPage}from'./pages/EventsPage';

function Protected(){const{session,loading}=useAuth();if(loading)return <div className="empty">Restaurando sesión…</div>;return session?<Outlet/>:<Navigate to="/login" replace/>}
function RequirePermission({permission,children}:{permission:string;children:ReactNode}){const{session,loading,hasPermission}=useAuth();if(loading)return <div className="empty">Cargando permisos…</div>;const allowed=hasPermission(permission);if(import.meta.env.DEV&&!allowed)console.debug('[auth] redirección acceso-denegado',{guard:'RequirePermission',usuario:session?.email??null,empresa:session?.companyId??null,rol:session?.role??null,roleCode:session?.roleCode??null,permisos:session?.permissions??[],permisoRequerido:permission,motivo:'hasPermission devolvió false'});return allowed?children:<Navigate to="/acceso-denegado" replace/>}
function RequireAnyPermission({permissions,children}:{permissions:string[];children:ReactNode}){const{session,loading,hasPermission}=useAuth();if(loading)return <div className="empty">Cargando permisos…</div>;const allowed=permissions.some(hasPermission);if(import.meta.env.DEV&&!allowed)console.debug('[auth] redirección acceso-denegado',{guard:'RequireAnyPermission',usuario:session?.email??null,empresa:session?.companyId??null,rol:session?.role??null,roleCode:session?.roleCode??null,permisos:session?.permissions??[],permisosRequeridos:permissions,motivo:'ningún permiso requerido fue autorizado'});return allowed?children:<Navigate to="/acceso-denegado" replace/>}
function RequireEmployee({children}:{children:ReactNode}){const{session,loading}=useAuth();if(loading)return <div className="empty">Cargando portal...</div>;return ['employee','empleado'].includes(session?.roleCode??'')?children:<Navigate to="/dashboard" replace/>}
function DashboardByRole(){const{session}=useAuth();if(['employee','empleado'].includes(session?.roleCode??''))return <Navigate to="/mi-portal" replace/>;return session?.roleCode==='supervisor'?<SupervisorDashboardPage/>:<ExecutiveDashboardPage/>}

export default function App(){return <Routes>
 <Route path="/" element={<BootstrapGate/>}/><Route path="/login" element={<LoginPage/>}/><Route path="/bootstrap" element={<BootstrapPage/>}/>
 <Route path="/recuperar-password" element={<PasswordRecoveryPage/>}/><Route path="/actualizar-password" element={<PasswordUpdatePage/>}/><Route path="/kiosco" element={<KioskPage/>}/>
 <Route element={<Protected/>}><Route path="/acceso-denegado" element={<AccessDeniedPage/>}/><Route element={<EmployeeLayout/>}><Route path="/mi-portal" element={<RequireEmployee><EmployeePortalPage/></RequireEmployee>}/></Route><Route element={<AdminLayout/>}>
  <Route path="/dashboard" element={<RequirePermission permission="dashboard.view"><DashboardByRole/></RequirePermission>}/>
  <Route path="/equipo" element={<RequirePermission permission="empleados.ver_asignados"><SupervisorEmployeesPage/></RequirePermission>}/>
  <Route path="/supervisor/jornadas" element={<RequirePermission permission="jornadas.ver_asignadas"><SupervisorJourneysPage/></RequirePermission>}/>
  <Route path="/supervisor/pendientes" element={<RequirePermission permission="jornadas.ver_asignadas"><SupervisorJourneysPage pendingOnly/></RequirePermission>}/>
  <Route path="/supervisor/incidencias" element={<RequirePermission permission="incidencias.ver_asignadas"><SupervisorIncidentsPage/></RequirePermission>}/>
  <Route path="/supervisor/horarios" element={<RequirePermission permission="horarios.ver_asignados"><SupervisorSchedulesPage/></RequirePermission>}/>
  <Route path="/supervisor/auditoria" element={<RequirePermission permission="jornadas.ver_asignadas"><SupervisorAuditPage/></RequirePermission>}/>
  <Route path="/empleados" element={<RequirePermission permission="empleados.view"><EmployeesPage/></RequirePermission>}/>
  <Route path="/empleados/bajas" element={<RequireAnyPermission permissions={['empleados.view','reportes.empleados_baja']}><TerminatedEmployeesPage/></RequireAnyPermission>}/>
  <Route path="/eventos" element={<RequirePermission permission="eventos.view"><EventsPage/></RequirePermission>}/><Route path="/eventos/:id" element={<RequirePermission permission="eventos.view"><EventsPage detail/></RequirePermission>}/>
  <Route path="/supervisores" element={<RequirePermission permission="supervisores.view"><SupervisorsManagementPage/></RequirePermission>}/><Route path="/supervisores/:id" element={<RequirePermission permission="supervisores.edit"><SupervisorsManagementPage detail/></RequirePermission>}/>
  <Route path="/empresas" element={<RequirePermission permission="empresas.view"><CompaniesPage/></RequirePermission>}/><Route path="/sucursales" element={<RequirePermission permission="sucursales.view"><BranchesPage/></RequirePermission>}/><Route path="/departamentos" element={<RequirePermission permission="departamentos.view"><DepartmentsPage/></RequirePermission>}/>
  <Route path="/empleados/nuevo" element={<RequirePermission permission="empleados.create"><EmployeeFormPage/></RequirePermission>}/><Route path="/empleados/:id" element={<RequirePermission permission="empleados.view"><EmployeeDetailPage/></RequirePermission>}/><Route path="/empleados/:id/editar" element={<RequirePermission permission="empleados.edit"><EmployeeFormPage/></RequirePermission>}/><Route path="/empleados/:id/historial" element={<RequirePermission permission="empleados.view"><EmployeeHistoryPage/></RequirePermission>}/>
  <Route path="/asistencia" element={<RequirePermission permission="jornadas.ver_todas"><AttendancePage/></RequirePermission>}/><Route path="/jornadas" element={<RequirePermission permission="jornadas.ver_todas"><JourneysPage/></RequirePermission>}/>
  <Route path="/reportes" element={<RequirePermission permission="reportes.ver"><ReportsCenterPage/></RequirePermission>}/><Route path="/nomina" element={<RequirePermission permission="nomina.ver"><PayrollPage/></RequirePermission>}/><Route path="/nomina/descuentos" element={<RequirePermission permission="nomina.descuentos"><PayrollDiscountsPage/></RequirePermission>}/><Route path="/nomina/solicitudes" element={<RequirePermission permission="prestamos.solicitudes_ver"><LoanRequestsPage/></RequirePermission>}/>
  <Route path="/reportes/jornadas" element={<RequirePermission permission="reportes.jornadas"><JourneyReportPage/></RequirePermission>}/>
  <Route path="/reportes/asistencia" element={<RequirePermission permission="reportes.asistencia"><AttendanceReportPage/></RequirePermission>}/>
  <Route path="/reportes/horas-extras" element={<RequirePermission permission="reportes.horas_extras"><OvertimeReportPage/></RequirePermission>}/>
  <Route path="/reportes/nomina" element={<RequirePermission permission="reportes.nomina"><PayrollReportPage/></RequirePermission>}/>
  <Route path="/reportes/prestamos" element={<RequirePermission permission="reportes.prestamos"><LoansReportPage/></RequirePermission>}/>
  <Route path="/reportes/productividad" element={<RequirePermission permission="reportes.productividad"><ProductivityReportPage/></RequirePermission>}/>
  <Route path="/reportes/incidencias" element={<RequirePermission permission="reportes.incidencias"><IncidentsReportPage/></RequirePermission>}/>
  <Route path="/reportes/empleados-baja" element={<Navigate to="/empleados/bajas" replace/>}/>
  <Route path="/reportes/dias-festivos" element={<RequirePermission permission="reportes.dias_festivos"><HolidaysReportPage/></RequirePermission>}/>
  <Route path="/reportes/permisos" element={<RequirePermission permission="reportes.permisos"><PermissionsReportPage/></RequirePermission>}/>
  <Route path="/nomina/pagos" element={<RequirePermission permission="nomina.ver"><PayrollPaymentsPage/></RequirePermission>}/>
  <Route path="/nomina/cierre" element={<RequirePermission permission="nomina.cierre"><PayrollClosurePage/></RequirePermission>}/><Route path="/nomina/historial" element={<RequirePermission permission="nomina.historial"><PayrollHistoryPage/></RequirePermission>}/>
  <Route path="/prestamos" element={<RequirePermission permission="prestamos.ver"><LoansPage/></RequirePermission>}/>
  <Route path="/prestamos/historial" element={<RequirePermission permission="prestamos.historial"><LoanHistoryPage/></RequirePermission>}/>
  <Route path="/configuracion" element={<Navigate to="/administracion" replace/>}/><Route path="/administracion" element={<RequireAnyPermission permissions={['configuracion.administrar','configuracion.ver']}><SystemAdministrationPage/></RequireAnyPermission>}/>
  <Route path="/administracion/empresa" element={<RequireAnyPermission permissions={['configuracion.administrar','configuracion.empresa']}><SystemAdministrationPage section="empresa"/></RequireAnyPermission>}/><Route path="/administracion/sucursales" element={<RequireAnyPermission permissions={['configuracion.administrar','configuracion.sucursales']}><SystemAdministrationPage section="sucursales"/></RequireAnyPermission>}/><Route path="/administracion/departamentos" element={<RequireAnyPermission permissions={['configuracion.administrar','configuracion.departamentos']}><SystemAdministrationPage section="departamentos"/></RequireAnyPermission>}/><Route path="/administracion/cargos" element={<RequireAnyPermission permissions={['configuracion.administrar','configuracion.cargos']}><SystemAdministrationPage section="cargos"/></RequireAnyPermission>}/><Route path="/administracion/accesos" element={<RequireAnyPermission permissions={['usuarios.administrar','roles.administrar','permisos.administrar']}><SystemAdministrationPage section="usuarios"/></RequireAnyPermission>}/><Route path="/administracion/usuarios" element={<Navigate to="/administracion/accesos" replace/>}/><Route path="/administracion/horarios" element={<RequireAnyPermission permissions={['configuracion.administrar','configuracion.horarios']}><SystemAdministrationPage section="horarios"/></RequireAnyPermission>}/><Route path="/administracion/jornadas" element={<RequireAnyPermission permissions={['configuracion.administrar','configuracion.jornadas']}><SystemAdministrationPage section="jornadas"/></RequireAnyPermission>}/><Route path="/administracion/dispositivos" element={<RequirePermission permission="dispositivos.ver"><DevicesPage/></RequirePermission>}/><Route path="/administracion/seguridad" element={<RequireAnyPermission permissions={['configuracion.administrar','configuracion.seguridad']}><SystemAdministrationPage section="seguridad"/></RequireAnyPermission>}/><Route path="/administracion/apariencia" element={<RequireAnyPermission permissions={['configuracion.administrar','configuracion.apariencia']}><SystemAdministrationPage section="apariencia"/></RequireAnyPermission>}/>
  <Route path="/accesos" element={<RequireAnyPermission permissions={['usuarios.view','usuarios.administrar']}><UsersAdministrationPage/></RequireAnyPermission>}/>
  <Route path="/accesos/nuevo" element={<RequireAnyPermission permissions={['usuarios.create','usuarios.administrar']}><UserProvisioningPage/></RequireAnyPermission>}/>
  <Route path="/accesos/:id" element={<RequireAnyPermission permissions={['usuarios.view','usuarios.administrar']}><UsersAdministrationPage mode="view"/></RequireAnyPermission>}/>
  <Route path="/accesos/:id/editar" element={<RequireAnyPermission permissions={['usuarios.edit','usuarios.administrar']}><UsersAdministrationPage mode="edit"/></RequireAnyPermission>}/>
  <Route path="/accesos/:id/auditoria" element={<RequireAnyPermission permissions={['usuarios.view','usuarios.administrar']}><UsersAdministrationPage mode="audit"/></RequireAnyPermission>}/>
  <Route path="/usuarios/sincronizar" element={<RequirePermission permission="usuarios.administrar"><UserProvisioningPage/></RequirePermission>}/><Route path="/dispositivos" element={<Navigate to="/administracion/dispositivos" replace/>}/><Route path="/cambiar-password" element={<PasswordUpdatePage/>}/>
  <Route path="/usuarios" element={<Navigate to="/accesos" replace/>}/>
  <Route path="/usuarios/nuevo" element={<Navigate to="/accesos/nuevo" replace/>}/>
  <Route path="/usuarios/:id" element={<RequireAnyPermission permissions={['usuarios.view','usuarios.administrar']}><UsersAdministrationPage mode="view"/></RequireAnyPermission>}/>
  <Route path="/usuarios/:id/editar" element={<RequireAnyPermission permissions={['usuarios.edit','usuarios.administrar']}><UsersAdministrationPage mode="edit"/></RequireAnyPermission>}/>
  <Route path="/usuarios/:id/auditoria" element={<RequireAnyPermission permissions={['usuarios.view','usuarios.administrar']}><UsersAdministrationPage mode="audit"/></RequireAnyPermission>}/>
 </Route></Route><Route path="*" element={<Navigate to="/" replace/>}/>
</Routes>}
