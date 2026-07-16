import type{ReactNode}from'react';
import{Navigate,Outlet,Route,Routes}from'react-router-dom';
import{useAuth}from'./context/AuthContext';
import{AdminLayout}from'./layouts/AdminLayout';
import{Rc2DashboardPage as DashboardPage}from'./pages/Rc2DashboardPage';
import{DevicesPage}from'./pages/DevicesPage';
import{EmployeeDetailPage}from'./pages/EmployeeDetailPage';
import{EmployeeFormPage}from'./pages/EmployeeFormPage';
import{EmployeesPage}from'./pages/EmployeesPage';
import{LoginPage}from'./pages/LoginPage';
import{AccessDeniedPage,PasswordRecoveryPage,PasswordUpdatePage}from'./pages/AuthPages';
import{KioskPage,ReportsPage}from'./pages/OperationsPages';
import{PayrollPage}from'./pages/PayrollPage';
import{PayrollDiscountsPage}from'./pages/PayrollDiscountsPage';
import{AttendancePage,JourneysPage}from'./pages/JourneyPages';
import{SupervisorAuditPage,SupervisorDashboardPage,SupervisorEmployeesPage,SupervisorIncidentsPage,SupervisorJourneysPage,SupervisorSchedulesPage}from'./pages/SupervisorPages';
import{UserProvisioningPage}from'./pages/UserProvisioningPage';
import{BootstrapPage}from'./pages/BootstrapPage';
import{BootstrapGate}from'./pages/BootstrapGate';
import{SystemAdministrationPage}from'./pages/SystemAdministrationPage';
import{EmployeeLayout}from'./layouts/EmployeeLayout';
import{EmployeePortalPage}from'./pages/EmployeePortalPage';
import{LoanRequestsPage}from'./pages/LoanRequestsPage';

function Protected(){const{session,loading}=useAuth();if(loading)return <div className="empty">Restaurando sesión…</div>;return session?<Outlet/>:<Navigate to="/login" replace/>}
function RequirePermission({permission,children}:{permission:string;children:ReactNode}){const{session,loading,hasPermission}=useAuth();console.info('[auth] evaluación de ruta',{permiso_requerido:permission,codigos_cargados:session?.permissions??[],role_id:session?.roleId??null,company_id:session?.companyId??null,loading});if(loading)return <div className="empty">Cargando permisos…</div>;return hasPermission(permission)?children:<Navigate to="/acceso-denegado" replace/>}
function RequireAnyPermission({permissions,children}:{permissions:string[];children:ReactNode}){const{loading,hasPermission}=useAuth();if(loading)return <div className="empty">Cargando permisos…</div>;return permissions.some(hasPermission)?children:<Navigate to="/acceso-denegado" replace/>}
function RequireEmployee({children}:{children:ReactNode}){const{session,loading}=useAuth();if(loading)return <div className="empty">Cargando portal...</div>;return ['employee','empleado'].includes(session?.roleCode??'')?children:<Navigate to="/dashboard" replace/>}
function DashboardByRole(){const{session}=useAuth();if(['employee','empleado'].includes(session?.roleCode??''))return <Navigate to="/mi-portal" replace/>;return session?.roleCode==='supervisor'?<SupervisorDashboardPage/>:<DashboardPage/>}

export default function App(){return <Routes>
 <Route path="/" element={<BootstrapGate/>}/><Route path="/login" element={<LoginPage/>}/><Route path="/bootstrap" element={<BootstrapPage/>}/>
 <Route path="/recuperar-password" element={<PasswordRecoveryPage/>}/><Route path="/actualizar-password" element={<PasswordUpdatePage/>}/><Route path="/kiosco" element={<KioskPage/>}/>
 <Route element={<Protected/>}><Route path="/acceso-denegado" element={<AccessDeniedPage/>}/><Route element={<EmployeeLayout/>}><Route path="/mi-portal" element={<RequireEmployee><EmployeePortalPage/></RequireEmployee>}/></Route><Route element={<AdminLayout/>}>
  <Route path="/dashboard" element={<RequirePermission permission="portal.ver_dashboard"><DashboardByRole/></RequirePermission>}/>
  <Route path="/equipo" element={<RequirePermission permission="empleados.ver_asignados"><SupervisorEmployeesPage/></RequirePermission>}/>
  <Route path="/supervisor/jornadas" element={<RequirePermission permission="jornadas.ver_asignadas"><SupervisorJourneysPage/></RequirePermission>}/>
  <Route path="/supervisor/pendientes" element={<RequirePermission permission="jornadas.ver_asignadas"><SupervisorJourneysPage pendingOnly/></RequirePermission>}/>
  <Route path="/supervisor/incidencias" element={<RequirePermission permission="incidencias.ver_asignadas"><SupervisorIncidentsPage/></RequirePermission>}/>
  <Route path="/supervisor/horarios" element={<RequirePermission permission="horarios.ver_asignados"><SupervisorSchedulesPage/></RequirePermission>}/>
  <Route path="/supervisor/auditoria" element={<RequirePermission permission="jornadas.ver_asignadas"><SupervisorAuditPage/></RequirePermission>}/>
  <Route path="/empleados" element={<RequirePermission permission="empleados.ver_todos"><EmployeesPage/></RequirePermission>}/>
  <Route path="/empleados/nuevo" element={<RequirePermission permission="empleados.crear"><EmployeeFormPage/></RequirePermission>}/><Route path="/empleados/:id" element={<RequirePermission permission="empleados.ver_todos"><EmployeeDetailPage/></RequirePermission>}/><Route path="/empleados/:id/editar" element={<RequirePermission permission="empleados.editar"><EmployeeFormPage/></RequirePermission>}/>
  <Route path="/asistencia" element={<RequirePermission permission="jornadas.ver_todas"><AttendancePage/></RequirePermission>}/><Route path="/jornadas" element={<RequirePermission permission="jornadas.ver_todas"><JourneysPage/></RequirePermission>}/>
  <Route path="/reportes" element={<RequirePermission permission="reportes.ver_globales"><ReportsPage/></RequirePermission>}/><Route path="/nomina" element={<RequirePermission permission="nomina.ver"><PayrollPage/></RequirePermission>}/><Route path="/nomina/descuentos" element={<RequirePermission permission="nomina.descuentos"><PayrollDiscountsPage/></RequirePermission>}/><Route path="/nomina/solicitudes" element={<RequirePermission permission="prestamos.solicitudes_ver"><LoanRequestsPage/></RequirePermission>}/>
  <Route path="/configuracion" element={<Navigate to="/administracion" replace/>}/><Route path="/administracion" element={<RequireAnyPermission permissions={['configuracion.administrar','configuracion.ver']}><SystemAdministrationPage/></RequireAnyPermission>}/>
  <Route path="/administracion/empresa" element={<RequireAnyPermission permissions={['configuracion.administrar','configuracion.empresa']}><SystemAdministrationPage section="empresa"/></RequireAnyPermission>}/><Route path="/administracion/sucursales" element={<RequireAnyPermission permissions={['configuracion.administrar','configuracion.sucursales']}><SystemAdministrationPage section="sucursales"/></RequireAnyPermission>}/><Route path="/administracion/departamentos" element={<RequireAnyPermission permissions={['configuracion.administrar','configuracion.departamentos']}><SystemAdministrationPage section="departamentos"/></RequireAnyPermission>}/><Route path="/administracion/cargos" element={<RequireAnyPermission permissions={['configuracion.administrar','configuracion.cargos']}><SystemAdministrationPage section="cargos"/></RequireAnyPermission>}/><Route path="/administracion/usuarios" element={<RequireAnyPermission permissions={['usuarios.administrar','roles.administrar','permisos.administrar']}><SystemAdministrationPage section="usuarios"/></RequireAnyPermission>}/><Route path="/administracion/horarios" element={<RequireAnyPermission permissions={['configuracion.administrar','configuracion.horarios']}><SystemAdministrationPage section="horarios"/></RequireAnyPermission>}/><Route path="/administracion/jornadas" element={<RequireAnyPermission permissions={['configuracion.administrar','configuracion.jornadas']}><SystemAdministrationPage section="jornadas"/></RequireAnyPermission>}/><Route path="/administracion/dispositivos" element={<RequirePermission permission="dispositivos.ver"><DevicesPage/></RequirePermission>}/><Route path="/administracion/seguridad" element={<RequireAnyPermission permissions={['configuracion.administrar','configuracion.seguridad']}><SystemAdministrationPage section="seguridad"/></RequireAnyPermission>}/><Route path="/administracion/apariencia" element={<RequireAnyPermission permissions={['configuracion.administrar','configuracion.apariencia']}><SystemAdministrationPage section="apariencia"/></RequireAnyPermission>}/>
  <Route path="/usuarios/sincronizar" element={<RequirePermission permission="usuarios.administrar"><UserProvisioningPage/></RequirePermission>}/><Route path="/dispositivos" element={<Navigate to="/administracion/dispositivos" replace/>}/><Route path="/cambiar-password" element={<PasswordUpdatePage/>}/>
 </Route></Route><Route path="*" element={<Navigate to="/" replace/>}/>
</Routes>}
