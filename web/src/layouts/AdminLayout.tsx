import { useEffect, useRef, useState } from 'react';
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { Bell, LogOut, Menu, PanelLeftClose, PanelLeftOpen, X } from 'lucide-react';
import { navigationItems, navigationSections } from '../app/navigation';
import { useAuth } from '../context/AuthContext';
import { createPermissionReader, isAdministratorRole, visibleNavigationItems } from '../infrastructure/permissions/permissionAdapter';
import { BrandMark } from '../components/BrandMark';

const dashboardShortcuts = [
  { to: '/dashboard', label: 'Dashboard' },
  { to: '/empleados', label: 'Empleados' },
  { to: '/asistencia', label: 'Asistencia' },
  { to: '/jornadas', label: 'Jornadas' },
  { to: '/nomina', label: 'Nómina' },
] as const;

export function AdminLayout() {
  const [mobileOpen, setMobileOpen] = useState(false);
  const [compact, setCompact] = useState(true);
  const mobileTriggerRef = useRef<HTMLButtonElement>(null);
  const mobileCloseRef = useRef<HTMLButtonElement>(null);
  const { session, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const administrator = isAdministratorRole(session?.roleCode, session?.role);
  const items = visibleNavigationItems(navigationItems, createPermissionReader(session?.permissions), administrator);
  const current = `${location.pathname}${location.search}`;
  const isExecutiveDashboard = administrator && location.pathname === '/dashboard';
  const compactMode = isExecutiveDashboard && compact;
  const quickItems = dashboardShortcuts.flatMap((shortcut) => {
    const item = items.find((candidate) => candidate.to === shortcut.to);
    return item ? [{ ...shortcut, icon: item.icon }] : [];
  });
  const fullNavigation = <>
    {navigationSections.map((section) => {
      const children = items.filter((item) => item.section === section);
      return children.length ? <div className="nav-section" key={section}>
        {section !== 'Dashboard' && <span>{section}</span>}
        {children.map(({ to, label, icon: Icon }) => <NavLink key={to} to={to} className={current === to ? 'active' : undefined} onClick={afterNavigation}><Icon size={19} /><span>{label}</span></NavLink>)}
      </div> : null;
    })}
  </>;

  useEffect(() => {
    if (!mobileOpen) return;
    mobileCloseRef.current?.focus();
    const sidebar = document.getElementById('admin-sidebar');
    const handleDrawerKeys = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        closeMobileNavigation();
        return;
      }
      if (event.key !== 'Tab' || !sidebar) return;
      const focusable = [...sidebar.querySelectorAll<HTMLElement>('a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])')].filter((element) => element.offsetParent !== null);
      const first = focusable[0];
      const last = focusable.at(-1);
      if (!first || !last) return;
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };
    window.addEventListener('keydown', handleDrawerKeys);
    return () => window.removeEventListener('keydown', handleDrawerKeys);
  }, [mobileOpen]);

  function closeMobileNavigation() {
    setMobileOpen(false);
    window.requestAnimationFrame(() => mobileTriggerRef.current?.focus());
  }

  function afterNavigation() {
    if (mobileOpen) closeMobileNavigation();
  }

  async function closeSession() {
    await logout();
    navigate('/login');
  }

  return <div className={`shell${compactMode ? ' shell-compact' : ''}`}>
    <aside id="admin-sidebar" className={mobileOpen ? 'sidebar open' : 'sidebar'} aria-label="Navegación principal">
      <div className="brand">
        <BrandMark />
        <div className="brand-copy"><b>OSINET</b><small>TIME ERP ENTERPRISE</small></div>
        {isExecutiveDashboard && <button type="button" className="icon sidebar-toggle desktop-sidebar-toggle" aria-label={compactMode ? 'Expandir navegación' : 'Compactar navegación'} aria-expanded={!compactMode} aria-controls="admin-navigation" onClick={() => setCompact((value) => !value)}>{compactMode ? <PanelLeftOpen /> : <PanelLeftClose />}</button>}
        <button ref={mobileCloseRef} type="button" className="icon mobile" onClick={closeMobileNavigation} aria-label="Cerrar menú"><X /></button>
      </div>
      <nav id="admin-navigation">
        {compactMode ? <>
          <div className="sidebar-shortcuts">{quickItems.map(({ to, label, icon: Icon }) => <NavLink key={to} to={to} aria-label={label} title={label} onClick={afterNavigation} className={({ isActive }) => isActive ? 'active' : undefined}><Icon /><span>{label}</span></NavLink>)}</div>
          <div className="sidebar-full-navigation">{fullNavigation}</div>
        </> : fullNavigation}
      </nav>
      <button type="button" className="logout" onClick={closeSession} aria-label="Cerrar sesión"><LogOut size={18} /><span>Cerrar sesión</span></button>
    </aside>
    <button type="button" className={`sidebar-backdrop${mobileOpen ? ' open' : ''}`} tabIndex={-1} aria-label="Cerrar navegación" onClick={closeMobileNavigation} />
    <div className="workspace" aria-hidden={mobileOpen || undefined}>
      <header className="topbar">
        <button ref={mobileTriggerRef} type="button" className="icon mobile" onClick={() => setMobileOpen(true)} aria-label="Abrir menú" aria-expanded={mobileOpen} aria-controls="admin-sidebar"><Menu /></button>
        <div className="company"><span className="live-dot" />OSINET · sesión protegida</div>
        <div className="user">
          <button type="button" className="icon" aria-label="Notificaciones" onClick={() => navigate('/dashboard')}><Bell /></button>
          <span className="avatar">{session?.name.split(' ').map((part) => part[0]).join('').slice(0, 2).toUpperCase()}</span>
          <div><b>{session?.name}</b><small>{session?.role}</small></div>
        </div>
      </header>
      <main><Outlet /></main>
    </div>
  </div>;
}
