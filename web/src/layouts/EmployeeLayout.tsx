import { LogOut } from 'lucide-react';
import { Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { BrandCopy, BrandMark } from '../components/BrandMark';

export function EmployeeLayout() {
  const { session, logout } = useAuth();
  const navigate = useNavigate();

  async function exit() {
    await logout();
    navigate('/login', { replace: true });
  }

  return <div className="employee-shell">
    <header className="employee-topbar">
      <div className="brand"><BrandMark size={46}/><BrandCopy tagline="PORTAL DEL EMPLEADO"/></div>
      <div className="user">
        <span className="avatar">{session?.name.split(' ').map((part) => part[0]).join('').slice(0, 2)}</span>
        <div><b>{session?.name}</b><small>{session?.role}</small></div>
        <button className="secondary" onClick={exit}><LogOut/>Salir</button>
      </div>
    </header>
    <main className="employee-main"><Outlet/></main>
  </div>;
}
