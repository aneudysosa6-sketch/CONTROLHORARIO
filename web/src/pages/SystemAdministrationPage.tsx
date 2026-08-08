import{useEffect,useMemo,useRef,useState,type FormEvent,type ReactNode}from'react';
import{Activity,ArrowLeft,Building2,CalendarClock,ChevronDown,ChevronRight,CheckCircle2,ContactRound,GitBranch,HelpCircle,Info,KeyRound,Loader2,MonitorCog,Search,ShieldCheck,Smartphone,UsersRound}from'lucide-react';
import{Link,useNavigate}from'react-router-dom';
import{Badge,Empty,PageHeader,Toast}from'../components/UI';
import{useAuth}from'../context/AuthContext';
import{AdministrationError,administrationService,type AdminSection,type AdministrationOverview,type AuditEvent,type Branch,type Department,type Permission,type OrganizationData,type Position,type Role}from'../modules/administration/administrationService';

const cards:{key:AdminSection;title:string;description:string;icon:(p:{size?:number})=>ReactNode;count?:keyof AdministrationOverview['counts']}[]=[
 {key:'empresa',title:'Empresa',description:'Identidad, logo, RNC, contacto y zona horaria.',icon:Building2},
 {key:'sucursales',title:'Sucursales',description:'Ubicaciones, contacto, zona horaria y estado.',icon:GitBranch,count:'branches'},
 {key:'departamentos',title:'Departamentos',description:'Estructura por sucursal y supervisores asignados.',icon:UsersRound,count:'departments'},
 {key:'cargos',title:'Cargos',description:'Cargos laborales por departamento y estado.',icon:ContactRound,count:'positions'},
 {key:'usuarios',title:'Accesos',description:'Credenciales vinculadas a empleados, roles y permisos.',icon:KeyRound,count:'profiles'},
  {key:'horarios',title:'Horarios',description:'Turnos, días, almuerzo y tolerancia.',icon:CalendarClock,count:'schedules'},
 {key:'jornadas',title:'Jornadas',description:'Pendientes, incidencias y reglas operativas.',icon:Activity,count:'pending_journeys'},
  {key:'dispositivos',title:'Dispositivos',description:'Android registrados, sincronización y revocación.',icon:Smartphone,count:'devices'},
  {key:'seguridad',title:'Seguridad',description:'Sesión actual, auditoría y accesos.',icon:ShieldCheck,count:'audit_events'},
];
const emptyOrg:OrganizationData={branches:[],departments:[],positions:[],profiles:[],employees:[],roles:[],permissions:[],departmentAssignments:[],rolePermissions:[]};
const errorText=(error:unknown)=>error instanceof AdministrationError?error.visible():error instanceof Error?error.message:'Error desconocido de administración.';
const defaultBranch={name:'',code:'',address:'',phone:'',email:'',timezone:'',status:'active'};
const defaultDepartment={name:'',code:'',branch_id:'',description:'',is_active:true};
const defaultPosition={name:'',code:'',department_id:'',description:'',level:1,is_active:true};
const permissionCategoryColors=['blue','green','amber','red','purple','teal','indigo','orange'];
const roleCodePattern=/^[A-Z](?:[A-Z0-9_]*[A-Z0-9])?$/;
function normalizeRoleNameInput(value: string) {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}
function generateRoleCode(roleName: string) {
  const normalized = normalizeRoleNameInput(roleName).toUpperCase();
  const code = normalized
    .replace(/[^A-Z0-9\s_-]/g, ' ')
    .split(/[\s_-]+/)
    .map((token) =>
      token
        .replace(/[^A-Z0-9]/g, '')
        .replace(/^[^A-Z]+/g, ''),
    )
    .filter(Boolean)
    .join('_');
  return roleCodePattern.test(code) ? code : '';
}
function isValidRoleCode(value: string) {
  return roleCodePattern.test(value);
}
function mapRoleCreationError(error: unknown) {
  if (error instanceof AdministrationError) {
    const details = (error.details || '').toLowerCase();
    const message = (error.message || '').toLowerCase();
    const full = `${error.code} ${details} ${message}`;

    if (error.code === 'roles_code_format' || full.includes('roles_code_format')) {
      return 'El código interno generado no tiene un formato válido.';
    }
    if (error.code === 'ROLE_NAME_REQUIRED') {
      return 'El nombre del rol es obligatorio.';
    }
    if (error.code === 'ROLE_CODE_REQUIRED') {
      return 'No se pudo generar un código interno para el rol.';
    }
    if (
      error.code === '23505' ||
      full.includes('duplicate key') ||
      (full.includes('unique') && full.includes('roles'))
    ) {
      return 'Ya existe un rol con ese nombre o ese código interno.';
    }
    if (full.includes('permission denied') || full.includes('rls') || full.includes('policy')) {
      return 'No tienes permisos para crear roles.';
    }
  }

  const text = error instanceof Error ? error.message.toLowerCase() : String(error || '').toLowerCase();
  if (!text) {
    return 'No se pudo crear el rol. Inténtalo nuevamente.';
  }
  if (text.includes('failed to fetch') || text.includes('network') || text.includes('failed to load') || text.includes('ERR_INTERNET_DISCONNECTED')) {
    return 'No fue posible conectar con el servidor. Revisa tu conexión.';
  }
  if (text.includes('timeout')) {
    return 'La operación tardó demasiado. Inténtalo nuevamente.';
  }
  return 'No se pudo crear el rol. Inténtalo nuevamente.';
}
const quickTemplates=[
  {key:'administrador',label:'Administrador',match:(permission:Permission)=>['roles','permisos','usuarios','configuracion','dispositivos'].includes((permission.modulo||'').toLowerCase())||permission.codigo.toLowerCase()==='*'},
  {key:'supervisor',label:'Supervisor',match:(permission:Permission)=>{const module=(permission.modulo||permission.codigo).toLowerCase();const code=permission.codigo.toLowerCase();return module.startsWith('empleados')||module.startsWith('jornadas')||module.startsWith('incidencias')||module.startsWith('eventos')||code==='asistencia.registrar_propia';}},
  {key:'rrhh',label:'RRHH',match:(permission:Permission)=>{const module=(permission.modulo||permission.codigo).toLowerCase();const code=permission.codigo.toLowerCase();return module.startsWith('empleados')||module.startsWith('departamentos')||module.startsWith('usuarios')||code==='usuarios.view';}},
  {key:'nomina',label:'Nómina',match:(permission:Permission)=>(permission.modulo||permission.codigo).toLowerCase().startsWith('nomina')},
  {key:'auditor',label:'Auditor',match:(permission:Permission)=>{const module=(permission.modulo||permission.codigo).toLowerCase();const code=permission.codigo.toLowerCase();return module.startsWith('reportes')||code.includes('auditoria')||code.includes('seguridad');}},
  {key:'empleado',label:'Empleado',match:(permission:Permission)=>{const module=(permission.modulo||permission.codigo).toLowerCase();const code=permission.codigo.toLowerCase();return code==='dashboard.view'||code==='empleados.view'||module.startsWith('asistencia');}},
];

const toModule=(permission:Permission)=> (permission.modulo||permission.codigo).toLowerCase().split('.')[0]||'otros';
const moduleTitle=(module:string)=> module.charAt(0).toUpperCase()+module.slice(1).replace(/_/g,' ');
const permissionLabel=(permission:Permission)=>permission.nombre?.trim()||permission.codigo;
const moduleFrom=(permission:Permission)=> (permission.modulo||permission.codigo).toLowerCase().split('.')[0]||'otros';
const colorForModule=(module:string)=>permissionCategoryColors[Math.abs(module.split('').reduce((total,char)=>total+char.charCodeAt(0),0))%permissionCategoryColors.length];
const tooltipForPermission=(permission:Permission)=>`${moduleTitle(moduleFrom(permission))} · ${permissionLabel(permission)} (${permission.codigo})`;
const matchesSearch=(permission:Permission,query:string)=>{const value=query.trim().toLowerCase();if(!value) return true;return permission.codigo.toLowerCase().includes(value)||permissionLabel(permission).toLowerCase().includes(value)||moduleFrom(permission).toLowerCase().includes(value);}

function buildDependencyMap(permissions:Permission[]){const codeToId=new Map<string,string>();for(const permission of permissions){codeToId.set(permission.codigo.toLowerCase(),permission.id)}const map=new Map<string,string[]>();for(const permission of permissions){const dependencies:string[]=[];const code=permission.codigo.toLowerCase();const module=toModule(permission);const add=(candidate:string)=>{const id=codeToId.get(candidate);if(id&&!dependencies.includes(id))dependencies.push(id)};if(!code.endsWith('.view')&&!code.endsWith('.ver'))add(`${module}.view`);if(code.endsWith('_asignadas')||code.endsWith('.asignadas')||code.endsWith('_asignados'))add(`${module}.ver_todas`);if(/\\.(crear|editar|eliminar|aprobar|asignar|autorizar|supervisar|validar|cerrar|abrir|revisar)\\b/.test(code)){add(`${module}.view`);add(`${module}.ver_todas`);}map.set(permission.id,[...dependencies]);}return map;}
function applyDependencyRules(current: Set<string>, dependencyMap: Map<string, string[]>, permissionId: string, checked: boolean) {
  const next = new Set(current);
  if (checked) {
    next.add(permissionId);
    let changed = true;
    while (changed) {
      changed = false;
      for (const [currentId, dependencies] of dependencyMap.entries()) {
        if (!next.has(currentId)) continue;
        for (const dependencyId of dependencies) {
          if (!next.has(dependencyId)) {
            next.add(dependencyId);
            changed = true;
          }
        }
      }
    }
    return next;
  }

  next.delete(permissionId);
  let changed = true;
  while (changed) {
    changed = false;
    for (const [currentId, dependencies] of dependencyMap.entries()) {
      if (!next.has(currentId)) continue;
      const valid = dependencies.every((dependencyId) => next.has(dependencyId));
      if (!valid) {
        next.delete(currentId);
        changed = true;
      }
    }
  }

  return next;
}

export function SystemAdministrationPage({section}: {section?:AdminSection}){
 const nav=useNavigate(),{hasPermission}=useAuth();const[overview,setOverview]=useState<AdministrationOverview|null>(null),[organization,setOrganization]=useState<OrganizationData>(emptyOrg),[audit,setAudit]=useState<AuditEvent[]>([]),[loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[error,setError]=useState(''),[message,setMessage]=useState('');
 async function load(){setLoading(true);setError('');try{const summary=await administrationService.overview();setOverview(summary);if(section&&['sucursales','departamentos','cargos','usuarios'].includes(section))setOrganization(await administrationService.organization());if(section==='seguridad')setAudit(await administrationService.audit())}catch(e){setError(errorText(e))}finally{setLoading(false)}}
 useEffect(()=>{void load()},[section]);
 async function run(action:()=>Promise<unknown>,ok:string){setBusy(true);setError('');try{await action();setMessage(ok);await load();return true}catch(e){setError(errorText(e));return false}finally{setBusy(false)}}
 if(loading)return <Empty text="Cargando datos reales de la empresa…"/>;
  if(!overview)return <><PageHeader eyebrow="ADMINISTRACIÓN" title="Administración del sistema" description="No fue posible cargar el contexto administrativo."/>{error&&<div className="error admin-error">{error}</div>}</>;
 if(!section)return <AdministrationHub overview={overview}/>;
  if(!overview.sections[section])return <AdminShell title={cards.find(x=>x.key===section)?.title??section} onBack={()=>nav('/administracion')}><div className="error">Permisos insuficientes para abrir este módulo. La navegación administrativa permanece disponible.</div></AdminShell>;
 const common={overview,organization,busy,run};
 return <>{error&&<div className="error admin-floating-error"><b>Error real de Supabase</b><span>{error}</span></div>}{section==='empresa'&&<CompanySection {...common}/>} {section==='sucursales'&&<BranchesSection {...common}/>} {section==='departamentos'&&<DepartmentsSection {...common}/>} {section==='cargos'&&<PositionsSection {...common}/>} {section==='usuarios'&&<UsersSection {...common} hasPermission={hasPermission}/>} {section==='jornadas'&&<JourneysSection overview={overview}/>} {section==='seguridad'&&<SecuritySection overview={overview} audit={audit}/>}<Toast message={message}/></>;
}

function AdministrationHub({overview}:{overview:AdministrationOverview}){return <><PageHeader eyebrow="CONTROL CENTRAL" title="Administración del sistema" description={`${overview.company.name} · Configuración segura por permisos efectivos y aislamiento multiempresa.`}/><section className="admin-cards">{cards.filter(c=>overview.sections[c.key]).map(({key,title,description,icon:Icon,count})=><Link className="admin-card panel" to={key==='usuarios'?'/accesos':`/administracion/${key}`} key={key}><span className="admin-card-icon"><Icon size={22}/></span><div><h2>{title}</h2><p>{description}</p>{count&&<Badge tone="blue">{overview.counts[count]} registros</Badge>}</div><ChevronRight/></Link>)}</section></>}
function AdminShell({title,children,action,onBack}:{title:string;children:ReactNode;action?:ReactNode;onBack?:()=>void}){return <><PageHeader eyebrow="ADMINISTRACIÓN DEL SISTEMA" title={title} description="Datos reales de la empresa autenticada y operaciones protegidas por permisos." action={<div className="button-row">{onBack?<button className="secondary" type="button" onClick={onBack}><ArrowLeft/>Administración</button>:<Link className="secondary" to="/administracion"><ArrowLeft/>Administración</Link>}{action}</div>}/>{children}</>}

type Common={overview:AdministrationOverview;organization:OrganizationData;busy:boolean;run:(action:()=>Promise<unknown>,ok:string)=>Promise<boolean>};
function CompanySection({overview,busy,run}:Common){const c=overview.company,[form,setForm]=useState({name:c.name,legal_name:c.legal_name??'',tax_id:c.tax_id??'',logo_url:c.logo_url??'',address:c.address??'',email:c.email??'',phone:c.phone??'',timezone:c.timezone}),[reason,setReason]=useState('');return <AdminShell title="Empresa"><form className="panel admin-form" onSubmit={e=>{e.preventDefault();void run(()=>administrationService.updateCompany(form,reason),'Datos de empresa actualizados')}}><label>Nombre comercial<input value={form.name} onChange={e=>setForm(v=>({...v,name:e.target.value}))} required/></label><label>Razón social<input value={form.legal_name} onChange={e=>setForm(v=>({...v,legal_name:e.target.value}))}/></label><label>RNC<input value={form.tax_id} onChange={e=>setForm(v=>({...v,tax_id:e.target.value}))}/></label><label>Logo URL<input type="url" value={form.logo_url} onChange={e=>setForm(v=>({...v,logo_url:e.target.value}))}/></label><label className="span-2">Dirección<input value={form.address} onChange={e=>setForm(v=>({...v,address:e.target.value}))}/></label><label>Correo<input type="email" value={form.email} onChange={e=>setForm(v=>({...v,email:e.target.value}))}/></label><label>Teléfono<input value={form.phone} onChange={e=>setForm(v=>({...v,phone:e.target.value}))}/></label><label>Zona horaria<input value={form.timezone} onChange={e=>setForm(v=>({...v,timezone:e.target.value}))} required/></label><label>Motivo del cambio<input value={reason} onChange={e=>setReason(e.target.value)} required/></label><button className="primary" disabled={busy}>Guardar cambios</button></form></AdminShell>}

function BranchesSection({organization,busy,run}:Common){const[editing,setEditing]=useState<string|null>(null),[form,setForm]=useState(defaultBranch),[reason,setReason]=useState('');function edit(x:Branch){setEditing(x.id);setForm({name:x.name,code:x.code,address:x.address??'',phone:x.phone??'',email:x.email??'',timezone:x.timezone??'',status:x.status})}async function save(e:FormEvent){e.preventDefault();if(await run(()=>administrationService.saveBranch(editing,form,reason),editing?'Sucursal actualizada':'Sucursal creada')){setEditing(null);setForm(defaultBranch);setReason('')}}return <AdminShell title="Sucursales"><CrudLayout form={<form className="panel admin-form single" onSubmit={save}><h2>{editing?'Editar sucursal':'Nueva sucursal'}</h2>{(['name','code','address','phone','email','timezone']as const).map(k=><label key={k}>{({name:'Nombre',code:'Código',address:'Dirección',phone:'Teléfono',email:'Correo',timezone:'Zona horaria'})[k]}<input type={k==='email'?'email':'text'} value={form[k]} onChange={e=>setForm(v=>({...v,[k]:e.target.value}))} required={k==='name'||k==='code'}/></label>)}<label>Estado<select value={form.status} onChange={e=>setForm(v=>({...v,status:e.target.value}))}><option value="active">Activa</option><option value="inactive">Inactiva</option></select></label><label>Motivo<input value={reason} onChange={e=>setReason(e.target.value)} required/></label><button className="primary" disabled={busy}>Guardar</button></form>} table={<SimpleTable headers={['Código','Sucursal','Contacto','Zona/estado','']} rows={organization.branches.map(x=>[x.code,x.name,<small>{x.phone||'—'} · {x.email||'—'}</small>,<><Badge tone={x.status==='active'?'green':'gray'}>{x.status}</Badge><small>{x.timezone||'Hereda empresa'}</small></>,<button className="secondary" onClick={()=>edit(x)}>Editar</button>])}/>}/></AdminShell>}

function DepartmentsSection({organization,busy,run}:Common){
  const[editing,setEditing]=useState<string|null>(null),[form,setForm]=useState(defaultDepartment),[reason,setReason]=useState('');
  function edit(x:Department){setEditing(x.id);setForm({name:x.name,code:x.code,branch_id:x.branch_id??'',description:x.description??'',is_active:x.is_active})}
  async function save(e:FormEvent){e.preventDefault();if(await run(()=>administrationService.saveDepartment(editing,form,reason),editing?'Departamento actualizado':'Departamento creado')){setEditing(null);setForm(defaultDepartment);setReason('')}}
  return <AdminShell title="Departamentos"><CrudLayout form={<form className="panel admin-form single" onSubmit={save}><h2>{editing?'Editar departamento':'Nuevo departamento'}</h2><p className="muted">El alcance de supervisión se administra desde Crear usuario o Editar acceso.</p><label>Nombre<input value={form.name} onChange={e=>setForm(v=>({...v,name:e.target.value}))} required/></label><label>Código<input value={form.code} onChange={e=>setForm(v=>({...v,code:e.target.value}))} required/></label><label>Sucursal<select value={form.branch_id} onChange={e=>setForm(v=>({...v,branch_id:e.target.value}))}><option value="">Corporativo</option>{organization.branches.map(x=><option key={x.id} value={x.id}>{x.name}</option>)}</select></label><label>Descripción<input value={form.description} onChange={e=>setForm(v=>({...v,description:e.target.value}))}/></label><label><input type="checkbox" checked={form.is_active} onChange={e=>setForm(v=>({...v,is_active:e.target.checked}))}/> Activo</label><label>Motivo<input value={reason} onChange={e=>setReason(e.target.value)} required/></label><button className="primary" disabled={busy}>Guardar</button></form>} table={<SimpleTable headers={['Código','Departamento','Sucursal','']} rows={organization.departments.map(x=>[x.code,x.name,organization.branches.find(b=>b.id===x.branch_id)?.name??'Corporativo',<button className="secondary" onClick={()=>edit(x)}>Editar</button>])}/>}/></AdminShell>
}

function PositionsSection({organization,busy,run}:Common){const[editing,setEditing]=useState<string|null>(null),[form,setForm]=useState(defaultPosition),[reason,setReason]=useState('');function edit(x:Position){setEditing(x.id);setForm({name:x.name,code:x.code,department_id:x.department_id??'',description:x.description??'',level:x.level,is_active:x.is_active})}async function save(e:FormEvent){e.preventDefault();if(await run(()=>administrationService.savePosition(editing,form,reason),editing?'Cargo actualizado':'Cargo creado')){setEditing(null);setForm(defaultPosition);setReason('')}}return <AdminShell title="Cargos"><CrudLayout form={<form className="panel admin-form single" onSubmit={save}><h2>{editing?'Editar cargo':'Nuevo cargo'}</h2><label>Nombre<input value={form.name} onChange={e=>setForm(v=>({...v,name:e.target.value}))} required/></label><label>Código<input value={form.code} onChange={e=>setForm(v=>({...v,code:e.target.value}))} required/></label><label>Departamento<select value={form.department_id} onChange={e=>setForm(v=>({...v,department_id:e.target.value}))}><option value="">General</option>{organization.departments.map(x=><option key={x.id} value={x.id}>{x.name}</option>)}</select></label><label>Nivel<input type="number" min="1" max="20" value={form.level} onChange={e=>setForm(v=>({...v,level:Number(e.target.value)}))}/></label><label>Descripción<input value={form.description} onChange={e=>setForm(v=>({...v,description:e.target.value}))}/></label><label><input type="checkbox" checked={form.is_active} onChange={e=>setForm(v=>({...v,is_active:e.target.checked}))}/> Activo</label><label>Motivo<input value={reason} onChange={e=>setReason(e.target.value)} required/></label><button className="primary" disabled={busy}>Guardar</button></form>} table={<SimpleTable headers={['Código','Cargo','Departamento','Estado','']} rows={organization.positions.map(x=>[x.code,x.name,organization.departments.find(d=>d.id===x.department_id)?.name??'General',<Badge tone={x.is_active?'green':'gray'}>{x.is_active?'Activo':'Inactivo'}</Badge>,<button className="secondary" onClick={()=>edit(x)}>Editar</button>])}/>}/></AdminShell>}

function UsersSection({
  organization,
  overview,
  busy,
  run,
  hasPermission,
}: Common & {
  hasPermission: (permission: string) => boolean;
}) {
  type LocalRolePermission = {
    rol_id: string;
    permiso_id: string;
    permitido: boolean;
    alcance: string;
  };

  const nav = useNavigate();
  const [reason, setReason] = useState('');
  const [roles, setRoles] = useState<Role[]>(organization.roles);
  const [rolePermissionsState, setRolePermissionsState] = useState<LocalRolePermission[]>(organization.rolePermissions);
  const [editingRoleId, setEditingRoleId] = useState<string | null>(null);
  const [roleForm, setRoleForm] = useState({ name: '', description: '', isActive: true });
  const [editingRoleSnapshot, setEditingRoleSnapshot] = useState<{ name: string; description: string; isActive: boolean; permissions: string[] } | null>(null);
  const [roleSaving, setRoleSaving] = useState(false);
  const [roleSuccess, setRoleSuccess] = useState<{ name: string; code: string } | null>(null);
  const [roleError, setRoleError] = useState('');
  const [validationErrors, setValidationErrors] = useState({ name: '', code: '', permissions: '', duplicate: '' });
  const [search, setSearch] = useState('');
  const [expanded, setExpanded] = useState<Record<string, boolean>>({});
  const [selectedPermissions, setSelectedPermissions] = useState<string[]>([]);
  const [highlightedRoleId, setHighlightedRoleId] = useState('');
  const [discardDialog, setDiscardDialog] = useState<null | (() => void)>(null);

  const roleMessageRef = useRef<HTMLDivElement>(null);
  const roleNameRef = useRef<HTMLInputElement>(null);
  const permissionErrorRef = useRef<HTMLDivElement>(null);
  const roleRowRefs = useRef<Record<string, HTMLTableRowElement | null>>({});

  const canManageRoles = hasPermission('roles.administrar');
  const canManagePermissions = hasPermission('permisos.administrar');
  const activePermissions = useMemo(() => organization.permissions.filter((permission) => permission.activo), [organization.permissions]);
  const dependencyMap = useMemo(() => buildDependencyMap(activePermissions), [activePermissions]);

  const generatedCode = useMemo(() => generateRoleCode(roleForm.name), [roleForm.name]);
  const normalizedRoleName = useMemo(() => normalizeRoleNameInput(roleForm.name).toUpperCase(), [roleForm.name]);
  const selectedPermissionsSet = useMemo(() => new Set(selectedPermissions), [selectedPermissions]);
  const normalizedSelectedPermissions = useMemo(() => {
    let next = new Set(selectedPermissions);
    for (const permissionId of Array.from(next)) {
      next = applyDependencyRules(next, dependencyMap, permissionId, true);
    }
    return [...next];
  }, [selectedPermissions, dependencyMap]);

  const canCreateRole = Boolean(
    normalizedRoleName &&
      generatedCode &&
      isValidRoleCode(generatedCode) &&
      !validationErrors.name &&
      !validationErrors.code &&
      !validationErrors.duplicate &&
      !validationErrors.permissions,
  );

  const duplicateRole = useMemo(() => {
    if (!normalizedRoleName) {
      return null;
    }
    return roles.find(
      (role) => role.id !== (editingRoleId ?? 'new') && normalizeRoleNameInput(role.name).toUpperCase() === normalizedRoleName,
    );
  }, [roles, editingRoleId, normalizedRoleName]);
  const duplicateCodeRole = useMemo(() => {
    if (!generatedCode) {
      return null;
    }
    return roles.find((role) => role.id !== (editingRoleId ?? 'new') && role.code === generatedCode);
  }, [roles, editingRoleId, generatedCode]);

  const hasUnsavedChanges = useMemo(() => {
    if (editingRoleId === null || !editingRoleSnapshot) {
      return roleForm.name.trim().length > 0 || roleForm.description.trim().length > 0 || selectedPermissions.length > 0;
    }
    if (roleForm.name !== editingRoleSnapshot.name || roleForm.description !== editingRoleSnapshot.description || roleForm.isActive !== editingRoleSnapshot.isActive) {
      return true;
    }
    const current = new Set(selectedPermissions);
    const original = new Set(editingRoleSnapshot.permissions);
    if (current.size !== original.size) {
      return true;
    }
    for (const permissionId of current) {
      if (!original.has(permissionId)) {
        return true;
      }
    }
    return false;
  }, [editingRoleId, editingRoleSnapshot, roleForm.name, roleForm.description, roleForm.isActive, selectedPermissions]);

  const groupedPermissions = useMemo(() => {
    const groups = new Map<string, Permission[]>();
    for (const permission of activePermissions) {
      const module = moduleFrom(permission);
      const list = groups.get(module);
      if (list) {
        list.push(permission);
      } else {
        groups.set(module, [permission]);
      }
    }
    for (const list of groups.values()) {
      list.sort((a, b) => permissionLabel(a).localeCompare(permissionLabel(b)));
    }
    const normalized = search.trim().toLowerCase();
    return [...groups.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([module, list]) => {
        const visible = normalized ? list.filter((permission) => matchesSearch(permission, normalized)) : list;
        return {
          module,
          title: moduleTitle(module),
          color: colorForModule(module),
          permissions: visible,
          total: list.length,
          selectedCount: visible.filter((permission) => selectedPermissionsSet.has(permission.id)).length,
        };
      });
  }, [activePermissions, search, selectedPermissionsSet]);

  const anyPermissionVisible = useMemo(() => groupedPermissions.some((group) => group.permissions.length > 0), [groupedPermissions]);

  useEffect(() => {
    setRoles([...organization.roles].sort((a, b) => a.name.localeCompare(b.name)));
    setRolePermissionsState([...organization.rolePermissions]);
  }, [organization.roles, organization.rolePermissions]);

  useEffect(() => {
    if (!roleSuccess && !roleError) {
      return;
    }
    if (roleMessageRef.current) {
      roleMessageRef.current.focus();
      roleMessageRef.current.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  }, [roleSuccess, roleError]);

  useEffect(() => {
    if (!highlightedRoleId) {
      return;
    }
    const node = roleRowRefs.current[highlightedRoleId];
    if (node) {
      node.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
    const id = window.setTimeout(() => setHighlightedRoleId(''), 2300);
    return () => window.clearTimeout(id);
  }, [highlightedRoleId]);

  useEffect(() => {
    if (!groupedPermissions.length) {
      setExpanded({});
      return;
    }
    setExpanded((current) => {
      const next = { ...current };
      let changed = false;
      const visible = new Set(groupedPermissions.map((item) => item.module));
      for (const module of Object.keys(next)) {
        if (!visible.has(module)) {
          delete next[module];
          changed = true;
        }
      }
      for (const { module } of groupedPermissions) {
        if (next[module] === undefined) {
          next[module] = false;
          changed = true;
        }
      }
      return changed ? next : current;
    });
  }, [groupedPermissions]);

  useEffect(() => {
    const normalized = search.trim();
    if (!normalized) {
      return;
    }
    setExpanded((current) => {
      const next = { ...current };
      let changed = false;
      for (const { module, permissions } of groupedPermissions) {
        const shouldOpen = permissions.length > 0;
        if (next[module] !== shouldOpen) {
          next[module] = shouldOpen;
          changed = true;
        }
      }
      return changed ? next : current;
    });
  }, [search, groupedPermissions]);

  function setErrorMessages() {
    const next = { name: '', code: '', permissions: '', duplicate: '' };
    if (!normalizedRoleName.trim()) {
      next.name = 'El nombre del rol es obligatorio.';
    }
    if (!generatedCode.trim()) {
      next.code = 'No se pudo generar el código interno desde el nombre.';
    } else if (!isValidRoleCode(generatedCode)) {
      next.code = 'El código interno generado no tiene un formato válido.';
    }
    if (!normalizedSelectedPermissions.length) {
      next.permissions = 'Selecciona al menos un permiso para crear el rol.';
    }
    if (duplicateRole || duplicateCodeRole) {
      next.duplicate =
        'Ya existe un rol con ese nombre.\\nCódigo interno:\\n' + generatedCode + '\\nUtiliza un nombre diferente.';
    }
    setValidationErrors(next);
    return next;
  }

  function clearValidation() {
    setValidationErrors({ name: '', code: '', permissions: '', duplicate: '' });
    setRoleError('');
    setRoleSuccess(null);
  }

  function rolePermissionIds(roleId: string) {
    return rolePermissionsState.filter((item) => item.rol_id === roleId && item.permitido).map((item) => item.permiso_id);
  }

  function assignedUsers(roleId: string) {
    return organization.profiles.filter((profile) => profile.role_id === roleId);
  }

  function isAdministratorRole(role: { code: string; name: string }) {
    const normalized = `${role.code} ${role.name}`
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toUpperCase()
      .replace(/[^A-Z]/g, '');
    return (
      normalized.includes('ADMIN') ||
      normalized.includes('ADMINISTRADOR') ||
      normalized.includes('ADMINISTRATOR')
    );
  }

  function setModuleExpanded(module: string) {
    if (roleSaving) {
      return;
    }
    setExpanded((current) => ({ ...current, [module]: !current[module] }));
  }

  function syncDependencies(nextSet: Set<string>, permissionId: string, checked: boolean) {
    return applyDependencyRules(nextSet, dependencyMap, permissionId, checked);
  }

  function applyTemplatePermissionSet(templateKey: 'administrador' | 'supervisor' | 'rrhh' | 'nomina' | 'auditor' | 'empleado', current: Set<string>) {
    const template = quickTemplates.find((item) => item.key === templateKey);
    if (!template) {
      return current;
    }
    const next = new Set(current);
    for (const permission of activePermissions) {
      if (template.match(permission)) {
        syncDependencies(next, permission.id, true);
      }
    }
    return next;
  }

  function applyQuickTemplate(templateKey: 'administrador' | 'supervisor' | 'rrhh' | 'nomina' | 'auditor' | 'empleado') {
    if (roleSaving) {
      return;
    }
    setSelectedPermissions((current) => [...applyTemplatePermissionSet(templateKey, new Set(current))]);
  }

  function togglePermission(permission: Permission, checked: boolean) {
    if (roleSaving) {
      return;
    }
    setSelectedPermissions((current) => [...syncDependencies(new Set(current), permission.id, checked)]);
  }

  function resetRoleForm() {
    setEditingRoleId(null);
    setEditingRoleSnapshot(null);
    setRoleForm({ name: '', description: '', isActive: true });
    setSearch('');
    setSelectedPermissions([]);
    setExpanded({});
    clearValidation();
    setDiscardDialog(null);
  }

  function requestResetOrLeave(action: () => void) {
    if (!hasUnsavedChanges || roleSaving) {
      action();
      return;
    }
    setDiscardDialog(() => action);
  }

  function editRole(role: { id: string; name: string; code: string; description: string | null; is_active: boolean }) {
    const normalized = rolePermissionIds(role.id);
    setEditingRoleId(role.id);
    setEditingRoleSnapshot({
      name: role.name,
      description: role.description ?? '',
      isActive: role.is_active,
      permissions: normalized,
    });
    setRoleForm({ name: role.name, description: role.description ?? '', isActive: role.is_active });
    setSelectedPermissions(normalized);
    setSearch('');
    clearValidation();
    setRoleSuccess(null);
  }

  async function saveRole(event: FormEvent) {
    event.preventDefault();
    if (roleSaving || busy || !canManageRoles) {
      return;
    }

    const errors = setErrorMessages();
    if (errors.name || errors.code || errors.permissions || errors.duplicate) {
      if (errors.name) {
        roleNameRef.current?.focus();
      } else {
        permissionErrorRef.current?.focus();
      }
      return;
    }

    if (editingRoleId !== null && !reason.trim()) {
      setRoleError('Para editar un rol, especifica un motivo de cambio.');
      return;
    }

    const created = editingRoleId === null;
    const roleName = roleForm.name.trim();
    const roleDescription = roleForm.description.trim();
    const roleCode = generatedCode;
    const desiredPermissions = new Set(normalizedSelectedPermissions);
    setRoleSaving(true);
    setRoleError('');

    try {
      const roleId = await administrationService.saveRole(
        editingRoleId,
        roleName,
        roleCode,
        roleDescription,
        roleForm.isActive,
        created ? '' : reason,
      );

      const previousPermissions = new Set(editingRoleId ? rolePermissionIds(editingRoleId) : []);
      const permissionReason = created ? 'Creación inicial del rol' : reason;
      for (const permission of activePermissions) {
        const isAssigned = desiredPermissions.has(permission.id);
        const wasAssigned = previousPermissions.has(permission.id);
        if (wasAssigned !== isAssigned) {
          await administrationService.setRolePermission(roleId, permission.id, isAssigned, permissionReason);
        }
      }

      const newRole: Role = {
        id: roleId,
        company_id: overview.company.id,
        name: roleName,
        code: roleCode,
        description: roleDescription || null,
        is_active: roleForm.isActive,
      };

      setRoles((current) => {
        const next = editingRoleId ? current.map((role) => (role.id === roleId ? newRole : role)) : [...current, newRole];
        return [...next].sort((a, b) => a.name.localeCompare(b.name));
      });
      setRolePermissionsState((current) => {
        const kept = current.filter((permission) => permission.rol_id !== roleId);
        const permissionEntries = activePermissions
          .filter((permission) => desiredPermissions.has(permission.id))
          .map((permission) => ({
            rol_id: roleId,
            permiso_id: permission.id,
            permitido: true,
            alcance: 'manual',
          }));
        return [...kept, ...permissionEntries];
      });

      if (created) {
        setRoleSuccess({ name: roleName, code: roleCode });
      }

      resetRoleForm();
      setHighlightedRoleId(roleId);
    } catch (error) {
      console.error('[roles] error al guardar rol', error);
      setRoleError(mapRoleCreationError(error));
    } finally {
      setRoleSaving(false);
    }
  }

  async function toggleRoleStatus(role: { id: string; name: string; code: string; description: string | null; is_active: boolean }) {
    if (!reason.trim()) {
      return;
    }
    const users = assignedUsers(role.id);
    const deactivating = role.is_active;
    if (deactivating && isAdministratorRole(role)) {
      return;
    }
    if (deactivating && users.length > 0) {
      return;
    }
    const action = deactivating ? 'desactivar' : 'activar';
    if (!window.confirm(`¿Confirmas ${action} el rol "${role.name}"? Esta acción quedará auditada.`)) {
      return;
    }
    await run(
      () => administrationService.saveRole(role.id, role.name, role.code, role.description ?? '', !deactivating, reason),
      deactivating ? 'Rol desactivado' : 'Rol activado',
    );
  }

  return (
    <AdminShell
      title="Roles y permisos"
      onBack={() => requestResetOrLeave(() => void nav('/administracion'))}
    >
      {discardDialog && (
        <div className="admin-discard-overlay">
          <div className="admin-discard-dialog" role="alertdialog" aria-modal="true" aria-label="confirmar descartar cambios">
            <h3>¿Descartar los cambios?</h3>
            <p>Los datos y permisos seleccionados se perderán.</p>
            <div className="button-row">
              <button type="button" className="secondary" onClick={() => setDiscardDialog(null)}>
                Seguir editando
              </button>
              <button
                type="button"
                className="primary"
                onClick={() => {
                  discardDialog?.();
                  setDiscardDialog(null);
                }}
              >
                Descartar cambios
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="admin-users-actions">
        {hasPermission('usuarios.administrar') && (
          <Link className="primary" to="/accesos">
            Administrar accesos
          </Link>
        )}
        <label>
          Motivo para cambios
          <input
            value={reason}
            onChange={(event) => setReason(event.target.value)}
            aria-label="Motivo para cambios"
            placeholder="Obligatorio para editar, permisos y estado"
          />
        </label>
      </div>

      {canManageRoles && (
        <>
          <section className="panel admin-role-panel">
            <h2>{editingRoleId ? 'Editar rol' : 'Nuevo rol'}</h2>
            {roleError && (
              <div className="admin-inline-alert admin-inline-alert-error" role="alert" aria-live="assertive">
                {roleError}
              </div>
            )}
             {roleSuccess && (
              <div className="admin-inline-alert admin-inline-alert-success" role="alert" aria-live="polite" ref={roleMessageRef} tabIndex={-1}>
                <p>Rol creado correctamente</p>
                <p><strong>Nombre:</strong> {roleSuccess.name}</p>
                <p><strong>Código:</strong> {roleSuccess.code}</p>
              </div>
            )}
              <form className="admin-inline-form" onSubmit={(event) => void saveRole(event)} aria-busy={roleSaving ? 'true' : 'false'}>
                <label>
                  <span>Nombre</span>
                  <input
                    ref={roleNameRef}
                    placeholder="Nombre"
                    value={roleForm.name}
                    onChange={(event) => {
                      setRoleForm((current) => ({ ...current, name: event.target.value }));
                    if (validationErrors.name || validationErrors.duplicate || validationErrors.code || validationErrors.permissions) {
                        clearValidation();
                      }
                    }}
                    aria-label="Nombre del rol"
                    aria-describedby="role-name-error role-code-hint role-permission-error role-duplicate-error"
                    required
                    disabled={roleSaving}
                  />
                  {validationErrors.name && <small id="role-name-error" role="alert">{validationErrors.name}</small>}
                </label>
                <div className="admin-inline-code">
                  <small>Código interno</small>
                  <div id="role-code-hint" className="admin-readonly-code">
                    <Info size={15} />
                    <span aria-live="polite">{generatedCode || '—'}</span>
                  </div>
                  {validationErrors.code && <small role="alert" className="admin-field-error">{validationErrors.code}</small>}
                </div>
                <label>
                  <span>Descripción</span>
                  <input
                    placeholder="Descripción"
                    aria-label="Descripción del rol"
                    value={roleForm.description}
                    onChange={(event) => setRoleForm((current) => ({ ...current, description: event.target.value }))}
                    disabled={roleSaving}
                  />
                </label>

              <div className="admin-row-actions">
                <button
                  className="primary"
                  aria-label={editingRoleId ? 'Guardar cambios del rol' : 'Crear rol'}
                  disabled={
                    busy ||
                    roleSaving ||
                    !canCreateRole ||
                    Boolean(duplicateRole || duplicateCodeRole) ||
                    (editingRoleId !== null && !reason.trim())
                  }
                  aria-busy={roleSaving ? 'true' : 'false'}
                >
                  {roleSaving ? (
                    <><Loader2 size={16} className="spin" />{editingRoleId ? 'Guardando...' : 'Creando rol...'}</>
                  ) : editingRoleId ? 'Guardar cambios' : 'Crear rol'}
                </button>
                {editingRoleId && (
                  <button
                    type="button"
                    className="secondary"
                    disabled={busy || roleSaving}
                    onClick={() => requestResetOrLeave(resetRoleForm)}
                  >
                    Cancelar edición
                  </button>
                )}
              </div>

              {validationErrors.duplicate && (
                <small id="role-duplicate-error" role="alert" className="admin-field-error">
                  {validationErrors.duplicate.split('\\n').map((line) => (
                    <span key={line}>{line}<br /></span>
                  ))}
                </small>
              )}
              {validationErrors.permissions && (
                <small id="role-permission-error" role="alert" className="admin-field-error">
                  {validationErrors.permissions}
                </small>
              )}
            </form>
          </section>

          <section className="panel admin-role-permissions" aria-busy={roleSaving ? 'true' : 'false'}>
            <header className="admin-role-permissions__header">
              <div>
                <h2>{editingRoleId ? 'Permisos del rol' : 'Permisos iniciales del rol'}</h2>
                <small>{roleForm.name ? `Rol: ${roleForm.name}` : 'Plantilla visual de permisos'}</small>
              </div>
                {canManagePermissions && (
                  <button
                    className="secondary"
                    type="button"
                    onClick={() => setSelectedPermissions([])}
                    aria-label="Limpiar selección de permisos"
                    disabled={roleSaving}
                  >
                    Limpiar selección
                  </button>
                )}
              </header>

            <div className="admin-role-toolbar">
              <label className="admin-permission-search">
                <Search size={15} />
                <input
                  value={search}
                  onChange={(event) => setSearch(event.target.value)}
                  placeholder="Buscar permisos por nombre, código o módulo"
                  aria-label="Buscar permisos"
                  aria-describedby="role-permission-error"
                  disabled={roleSaving}
                />
              </label>
              {canManagePermissions && (
                <div className="admin-template-row">
                  {quickTemplates.map((template) => (
                    <button
                      key={template.key}
                      type="button"
                      className="secondary"
                      aria-label={`Aplicar plantilla ${template.label}`}
                      onClick={() => applyQuickTemplate(template.key as 'administrador' | 'supervisor' | 'rrhh' | 'nomina' | 'auditor' | 'empleado')}
                      disabled={roleSaving}
                    >
                      {template.label}
                    </button>
                  ))}
                </div>
              )}
            </div>

            <div className="admin-permission-categories" ref={permissionErrorRef} tabIndex={-1}>
              {!anyPermissionVisible && <div className="admin-empty-permissions">Sin coincidencias para esta búsqueda.</div>}
              {canManagePermissions && groupedPermissions.map(({ module, title, color, permissions, total, selectedCount }) => {
                if (!permissions.length) {
                  return null;
                }
                const isOpen = expanded[module] ?? false;
                return (
                    <section key={module} className={`admin-permission-category admin-permission-category-${color}`}>
                    <button
                      className="admin-permission-category-head"
                      type="button"
                      aria-label={`${isOpen ? 'Ocultar' : 'Mostrar'} permisos del módulo ${title}`}
                      onClick={() => setModuleExpanded(module)}
                      aria-expanded={isOpen}
                    >
                      <span>
                        <ChevronDown size={14} />
                        {title}
                      </span>
                      <small>{selectedCount}/{total}</small>
                    </button>
                    <div className={`admin-permission-list ${isOpen ? 'open' : 'closed'}`}>
                      {permissions.map((permission) => {
                        const checked = selectedPermissionsSet.has(permission.id);
                        return (
                          <label key={permission.id} className={`admin-permission-row ${checked ? 'selected' : ''}`} title={tooltipForPermission(permission)}>
                            <input
                              type="checkbox"
                              checked={checked}
                              aria-label={`Permiso ${permissionLabel(permission)} ${checked ? 'seleccionado' : 'no seleccionado'}`}
                              disabled={busy || roleSaving || (editingRoleId !== null && !reason.trim())}
                              onChange={(event) => togglePermission(permission, event.target.checked)}
                            />
                            <div>
                              <strong>{permissionLabel(permission)}</strong>
                              <small>{permission.codigo}</small>
                            </div>
                            <span className="admin-permission-help" title={tooltipForPermission(permission)}>
                              <HelpCircle size={13} />
                            </span>
                          </label>
                        );
                      })}
                    </div>
                  </section>
                );
              })}
            </div>

             {!canManagePermissions && <div className="admin-empty-permissions">No tienes permiso para administrar permisos.</div>}
             {editingRoleId && !reason.trim() && <small>Escribe el motivo para modificar los permisos del rol.</small>}
          </section>

          <section className="panel admin-role-panel">
            <h2>Roles existentes</h2>
            <div className="table-wrap">
              <table>
                <thead>
                      <tr>
                    <th>Nombre</th>
                    <th>Código</th>
                    <th>Descripción</th>
                    <th>Estado</th>
                    <th>Permisos</th>
                    <th>Acciones</th>
                  </tr>
                </thead>
                <tbody>
                  {roles.map((role) => {
                    const users = assignedUsers(role.id);
                    const isPrimaryAdministrator = isAdministratorRole(role);
                    const canDeactivate = role.is_active && !isPrimaryAdministrator && users.length === 0;
                    const actionDisabled = busy || !reason.trim() || (role.is_active && !canDeactivate);
                    return (
                      <tr
                        key={role.id}
                        ref={(node) => {
                          roleRowRefs.current[role.id] = node;
                        }}
                        className={highlightedRoleId === role.id ? 'admin-role-highlighted' : undefined}
                      >
                        <td>{role.name}</td>
                        <td><code>{role.code}</code></td>
                        <td>{role.description || '—'}</td>
                        <td><Badge tone={role.is_active ? 'green' : 'gray'}>{role.is_active ? 'Activo' : 'Inactivo'}</Badge></td>
                        <td>{rolePermissionIds(role.id).length} permiso(s)</td>
                        <td>
                          <div className="button-row">
                             <button className="secondary" disabled={busy || roleSaving} aria-label={`Editar rol ${role.name}`} onClick={() => editRole(role)}>Editar</button>
                             <button
                               className="secondary"
                               disabled={actionDisabled}
                               aria-label={role.is_active ? `Desactivar rol ${role.name}` : `Activar rol ${role.name}`}
                               title={
                                 isPrimaryAdministrator && role.is_active
                                   ? 'El rol Administrador principal no se puede desactivar.'
                                  : users.length > 0 && role.is_active
                                    ? `Reasigna los ${users.length} usuario(s) antes de desactivar.`
                                    : !reason.trim()
                                      ? 'Escribe el motivo para cambiar el estado.'
                                      : undefined
                              }
                              onClick={() => void toggleRoleStatus(role)}
                            >
                              {role.is_active ? 'Desactivar' : 'Activar'}
                            </button>
                             {users.length > 0 && <small>{users.length} usuario(s) asignado(s): reasignación requerida</small>}
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                  {!roles.length && (
                    <tr>
                      <td colSpan={6}><Empty text="No hay roles registrados." /></td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </section>
        </>
      )}
    </AdminShell>
  );
}
function JourneysSection({overview}:{overview:AdministrationOverview}){return <AdminShell title="Jornadas" action={<Link className="primary" to="/jornadas">Abrir jornadas</Link>}><section className="stats admin-mini-stats"><article className="stat"><span>Pendientes de revisión</span><strong>{overview.counts.pending_journeys}</strong></article><article className="stat"><span>Reglas</span><strong>RC2</strong><small>Cierre e incidencias centralizados</small></article><article className="stat"><span>ADMIN-OFF/ON</span><strong>Protegido</strong><small>Requiere permiso explícito</small></article></section><div className="panel"><h2>Operación segura</h2><p>Las reglas, cierres automáticos, incidencias y pendientes se administran en el módulo real de Jornadas. Esta pantalla no duplica ni altera el motor RC2/RC3.</p><div className="button-row"><Link className="secondary" to="/pendientes">Revisión de pendientes</Link><Link className="secondary" to="/incidencias">Incidencias</Link></div></div></AdminShell>}
function SecuritySection({overview,audit}:{overview:AdministrationOverview;audit:AuditEvent[]}){return <AdminShell title="Seguridad" action={<Link className="primary" to="/cambiar-password">Cambiar contraseña</Link>}><section className="panel admin-session"><ShieldCheck/><div><h2>Sesión administrativa activa</h2><p>Usuario {overview.session.auth_uid} · Rol {overview.session.role} · Empresa {overview.company.name}</p><small>No se muestran tokens ni credenciales.</small></div></section><SimpleTable headers={['Fecha','Sección','Acción','Entidad','Motivo']} rows={audit.map(x=>[new Date(x.fecha).toLocaleString('es-DO'),x.seccion,x.accion,`${x.entidad}${x.entidad_id?` · ${x.entidad_id}`:''}`,x.motivo??'—'])}/>{!audit.length&&<Empty text="No hay eventos administrativos visibles para esta empresa."/>}</AdminShell>}

function CrudLayout({form,table}:{form:ReactNode;table:ReactNode}){return <div className="admin-crud">{form}<section className="table-wrap">{table}</section></div>}
function SimpleTable({headers,rows}:{headers:string[];rows:ReactNode[][]}){return <div className="table-wrap"><table><thead><tr>{headers.map(x=><th key={x}>{x}</th>)}</tr></thead><tbody>{rows.map((row,i)=><tr key={i}>{row.map((cell,j)=><td key={j}>{cell}</td>)}</tr>)}</tbody></table>{!rows.length&&<Empty text="No hay datos visibles para este alcance."/>}</div>}

