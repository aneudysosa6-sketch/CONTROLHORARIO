import { Navigate, Outlet, Route, Routes } from 'react-router-dom';
import { useAuth } from './context/AuthContext';
import { AdminLayout } from './layouts/AdminLayout';
import { DashboardPage } from './pages/DashboardPage';
import { EmployeeDetailPage } from './pages/EmployeeDetailPage';
import { EmployeeFormPage } from './pages/EmployeeFormPage';
import { EmployeesPage } from './pages/EmployeesPage';
import { LoginPage } from './pages/LoginPage';
import { AttendancePage, JourneysPage, KioskPage, PayrollPage, ReportsPage, SettingsPage } from './pages/OperationsPages';
function Protected(){return useAuth().session?<Outlet/>:<Navigate to="/login" replace/>}
export default function App(){return <Routes><Route path="/login" element={<LoginPage/>}/><Route path="/kiosco" element={<KioskPage/>}/><Route element={<Protected/>}><Route element={<AdminLayout/>}><Route path="/dashboard" element={<DashboardPage/>}/><Route path="/empleados" element={<EmployeesPage/>}/><Route path="/empleados/nuevo" element={<EmployeeFormPage/>}/><Route path="/empleados/:id" element={<EmployeeDetailPage/>}/><Route path="/empleados/:id/editar" element={<EmployeeFormPage/>}/><Route path="/asistencia" element={<AttendancePage/>}/><Route path="/jornadas" element={<JourneysPage/>}/><Route path="/reportes" element={<ReportsPage/>}/><Route path="/nomina" element={<PayrollPage/>}/><Route path="/configuracion" element={<SettingsPage/>}/></Route></Route><Route path="*" element={<Navigate to="/dashboard" replace/>}/></Routes>}
