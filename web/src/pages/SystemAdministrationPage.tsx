import{useEffect,useMemo,useState,type FormEvent,type ReactNode}from'react';
import{Activity,ArrowLeft,Building2,CalendarClock,ChevronDown,ChevronRight,ContactRound,GitBranch,HelpCircle,KeyRound,MonitorCog,Search,ShieldCheck,Smartphone,UsersRound}from'lucide-react';
import{Link,useNavigate}from'react-router-dom';
import{Badge,Empty,PageHeader,Toast}from'../components/UI';
import{useAuth}from'../context/AuthContext';
import{AdministrationError,administrationService,type AdminSection,type AdministrationOverview,type AuditEvent,type Branch,type Department,type Permission,type OrganizationData,type Position}from'../modules/administration/administrationService';

const cards:{key:AdminSection;title:string;description:string;icon:(p:{size?:number})=>ReactNode;count?:keyof AdministrationOverview['counts']}[]=[
 {key:'empresa',title:'Empresa',description:'Identidad, logo, RNC, contacto y zona horaria.',icon:Building2},
 {key:'sucursales',title:'Sucursales',description:'Ubicaciones, contacto, zona horaria y estado.',icon:GitBranch,count:'branches'},
 {key:'departamentos',title:'Departamentos',description:'Estructura por sucursal y supervisores asignados.',icon:UsersRound,count:'departments'},
 {key:'cargos',title:'Cargos',description:'Cargos laborales por departamento y estado.',icon:ContactRound,count:'positions'},
 {key:'usuarios',title:'Accesos',description:'Credenciales vinculadas a empleados, roles y permisos.',icon:KeyRound,count:'profiles'},
 {key:'horarios',title:'Horarios',description:'Turnos, dÃ­as, almuerzo y tolerancia.',icon:CalendarClock,count:'schedules'},
 {key:'jornadas',title:'Jornadas',description:'Pendientes, incidencias y reglas operativas.',icon:Activity,count:'pending_journeys'},
 {key:'dispositivos',title:'Dispositivos',description:'Android registrados, sincronizaciÃ³n y revocaciÃ³n.',icon:Smartphone,count:'devices'},
 {key:'seguridad',title:'Seguridad',description:'SesiÃ³n actual, auditorÃ­a y accesos.',icon:ShieldCheck,count:'audit_events'},
];
const emptyOrg:OrganizationData={branches:[],departments:[],positions:[],profiles:[],employees:[],roles:[],permissions:[],departmentAssignments:[],rolePermissions:[]};
const errorText=(error:unknown)=>error instanceof AdministrationError?error.visible():error instanceof Error?error.message:'Error desconocido de administraciÃ³n.';
const defaultBranch={name:'',code:'',address:'',phone:'',email:'',timezone:'',status:'active'};
const defaultDepartment={name:'',code:'',branch_id:'',description:'',is_active:true,supervisor:''};
const defaultPosition={name:'',code:'',department_id:'',description:'',level:1,is_active:true};
const permissionCategoryColors=['blue','green','amber','red','purple','teal','indigo','orange'];
const quickTemplates=[
  {key:'administrador',label:'Administrador',match:(permission:Permission)=>['roles','permisos','usuarios','configuracion','dispositivos'].includes((permission.modulo||'').toLowerCase())||permission.codigo.toLowerCase()==='*'},
  {key:'supervisor',label:'Supervisor',match:(permission:Permission)=>{const module=(permission.modulo||permission.codigo).toLowerCase();const code=permission.codigo.toLowerCase();return module.startsWith('empleados')||module.startsWith('jornadas')||module.startsWith('incidencias')||module.startsWith('eventos')||code==='asistencia.registrar_propia';}},
  {key:'rrhh',label:'RRHH',match:(permission:Permission)=>{const module=(permission.modulo||permission.codigo).toLowerCase();const code=permission.codigo.toLowerCase();return module.startsWith('empleados')||module.startsWith('departamentos')||module.startsWith('usuarios')||code==='usuarios.view';}},
  {key:'nomina',label:'NÃƒÂ³mina',match:(permission:Permission)=>(permission.modulo||permission.codigo).toLowerCase().startsWith('nomina')},
  {key:'auditor',label:'Auditor',match:(permission:Permission)=>{const module=(permission.modulo||permission.codigo).toLowerCase();const code=permission.codigo.toLowerCase();return module.startsWith('reportes')||code.includes('auditoria')||code.includes('seguridad');}},
  {key:'empleado',label:'Empleado',match:(permission:Permission)=>{const module=(permission.modulo||permission.codigo).toLowerCase();const code=permission.codigo.toLowerCase();return code==='dashboard.view'||code==='empleados.view'||module.startsWith('asistencia');}},
];

const toModule=(permission:Permission)=> (permission.modulo||permission.codigo).toLowerCase().split('.')[0]||'otros';
const moduleTitle=(module:string)=> module.charAt(0).toUpperCase()+module.slice(1).replace(/_/g,' ');
const permissionLabel=(permission:Permission)=>permission.nombre?.trim()||permission.codigo;
const moduleFrom=(permission:Permission)=> (permission.modulo||permission.codigo).toLowerCase().split('.')[0]||'otros';
const colorForModule=(module:string)=>permissionCategoryColors[Math.abs(module.split('').reduce((total,char)=>total+char.charCodeAt(0),0))%permissionCategoryColors.length];
const tooltipForPermission=(permission:Permission)=>`${moduleTitle(moduleFrom(permission))} Â· ${permissionLabel(permission)} (${permission.codigo})`;
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
 if(loading)return <Empty text="Cargando datos reales de la empresaâ€¦"/>;
 if(!overview)return <><PageHeader eyebrow="ADMINISTRACIÃ“N" title="AdministraciÃ³n del sistema" description="No fue posible cargar el contexto administrativo."/>{error&&<div className="error admin-error">{error}</div>}</>;
 if(!section)return <AdministrationHub overview={overview}/>;
 if(!overview.sections[section])return <AdminShell title={cards.find(x=>x.key===section)?.title??section} onBack={()=>nav('/administracion')}><div className="error">Permisos insuficientes para abrir este mÃ³dulo. La navegaciÃ³n administrativa permanece disponible.</div></AdminShell>;
 const common={overview,organization,busy,run};
 return <>{error&&<div className="error admin-floating-error"><b>Error real de Supabase</b><span>{error}</span></div>}{section==='empresa'&&<CompanySection {...common}/>} {section==='sucursales'&&<BranchesSection {...common}/>} {section==='departamentos'&&<DepartmentsSection {...common}/>} {section==='cargos'&&<PositionsSection {...common}/>} {section==='usuarios'&&<UsersSection {...common} hasPermission={hasPermission}/>} {section==='jornadas'&&<JourneysSection overview={overview}/>} {section==='seguridad'&&<SecuritySection overview={overview} audit={audit}/>}<Toast message={message}/></>;
}

function AdministrationHub({overview}:{overview:AdministrationOverview}){return <><PageHeader eyebrow="CONTROL CENTRAL" title="AdministraciÃ³n del sistema" description={`${overview.company.name} Â· ConfiguraciÃ³n segura por permisos efectivos y aislamiento multiempresa.`}/><section className="admin-cards">{cards.filter(c=>overview.sections[c.key]).map(({key,title,description,icon:Icon,count})=><Link className="admin-card panel" to={key==='usuarios'?'/accesos':`/administracion/${key}`} key={key}><span className="admin-card-icon"><Icon size={22}/></span><div><h2>{title}</h2><p>{description}</p>{count&&<Badge tone="blue">{overview.counts[count]} registros</Badge>}</div><ChevronRight/></Link>)}</section></>}
function AdminShell({title,children,action}:{title:string;children:ReactNode;action?:ReactNode;onBack?:()=>void}){return <><PageHeader eyebrow="ADMINISTRACIÃ“N DEL SISTEMA" title={title} description="Datos reales de la empresa autenticada y operaciones protegidas por permisos." action={<div className="button-row"><Link className="secondary" to="/administracion"><ArrowLeft/>AdministraciÃ³n</Link>{action}</div>}/>{children}</>}

type Common={overview:AdministrationOverview;organization:OrganizationData;busy:boolean;run:(action:()=>Promise<unknown>,ok:string)=>Promise<boolean>};
function CompanySection({overview,busy,run}:Common){const c=overview.company,[form,setForm]=useState({name:c.name,legal_name:c.legal_name??'',tax_id:c.tax_id??'',logo_url:c.logo_url??'',address:c.address??'',email:c.email??'',phone:c.phone??'',timezone:c.timezone}),[reason,setReason]=useState('');return <AdminShell title="Empresa"><form className="panel admin-form" onSubmit={e=>{e.preventDefault();void run(()=>administrationService.updateCompany(form,reason),'Datos de empresa actualizados')}}><label>Nombre comercial<input value={form.name} onChange={e=>setForm(v=>({...v,name:e.target.value}))} required/></label><label>RazÃ³n social<input value={form.legal_name} onChange={e=>setForm(v=>({...v,legal_name:e.target.value}))}/></label><label>RNC<input value={form.tax_id} onChange={e=>setForm(v=>({...v,tax_id:e.target.value}))}/></label><label>Logo URL<input type="url" value={form.logo_url} onChange={e=>setForm(v=>({...v,logo_url:e.target.value}))}/></label><label className="span-2">DirecciÃ³n<input value={form.address} onChange={e=>setForm(v=>({...v,address:e.target.value}))}/></label><label>Correo<input type="email" value={form.email} onChange={e=>setForm(v=>({...v,email:e.target.value}))}/></label><label>TelÃ©fono<input value={form.phone} onChange={e=>setForm(v=>({...v,phone:e.target.value}))}/></label><label>Zona horaria<input value={form.timezone} onChange={e=>setForm(v=>({...v,timezone:e.target.value}))} required/></label><label>Motivo del cambio<input value={reason} onChange={e=>setReason(e.target.value)} required/></label><button className="primary" disabled={busy}>Guardar cambios</button></form></AdminShell>}

function BranchesSection({organization,busy,run}:Common){const[editing,setEditing]=useState<string|null>(null),[form,setForm]=useState(defaultBranch),[reason,setReason]=useState('');function edit(x:Branch){setEditing(x.id);setForm({name:x.name,code:x.code,address:x.address??'',phone:x.phone??'',email:x.email??'',timezone:x.timezone??'',status:x.status})}async function save(e:FormEvent){e.preventDefault();if(await run(()=>administrationService.saveBranch(editing,form,reason),editing?'Sucursal actualizada':'Sucursal creada')){setEditing(null);setForm(defaultBranch);setReason('')}}return <AdminShell title="Sucursales"><CrudLayout form={<form className="panel admin-form single" onSubmit={save}><h2>{editing?'Editar sucursal':'Nueva sucursal'}</h2>{(['name','code','address','phone','email','timezone']as const).map(k=><label key={k}>{({name:'Nombre',code:'CÃ³digo',address:'DirecciÃ³n',phone:'TelÃ©fono',email:'Correo',timezone:'Zona horaria'})[k]}<input type={k==='email'?'email':'text'} value={form[k]} onChange={e=>setForm(v=>({...v,[k]:e.target.value}))} required={k==='name'||k==='code'}/></label>)}<label>Estado<select value={form.status} onChange={e=>setForm(v=>({...v,status:e.target.value}))}><option value="active">Activa</option><option value="inactive">Inactiva</option></select></label><label>Motivo<input value={reason} onChange={e=>setReason(e.target.value)} required/></label><button className="primary" disabled={busy}>Guardar</button></form>} table={<SimpleTable headers={['CÃ³digo','Sucursal','Contacto','Zona/estado','']} rows={organization.branches.map(x=>[x.code,x.name,<small>{x.phone||'â€”'} Â· {x.email||'â€”'}</small>,<><Badge tone={x.status==='active'?'green':'gray'}>{x.status}</Badge><small>{x.timezone||'Hereda empresa'}</small></>,<button className="secondary" onClick={()=>edit(x)}>Editar</button>])}/>}/></AdminShell>}

function DepartmentsSection({organization,busy,run}:Common){const[editing,setEditing]=useState<string|null>(null),[form,setForm]=useState(defaultDepartment),[reason,setReason]=useState('');const supervisors=organization.profiles.filter(p=>organization.roles.find(r=>r.id===p.role_id)?.code==='supervisor');function edit(x:Department){setEditing(x.id);setForm({name:x.name,code:x.code,branch_id:x.branch_id??'',description:x.description??'',is_active:x.is_active,supervisor:organization.departmentAssignments.find(a=>a.departamento_id===x.id)?.perfil_id??''})}async function save(e:FormEvent){e.preventDefault();if(await run(()=>administrationService.saveDepartment(editing,form,form.supervisor||null,reason),editing?'Departamento actualizado':'Departamento creado')){setEditing(null);setForm(defaultDepartment);setReason('')}}return <AdminShell title="Departamentos"><CrudLayout form={<form className="panel admin-form single" onSubmit={save}><h2>{editing?'Editar departamento':'Nuevo departamento'}</h2><label>Nombre<input value={form.name} onChange={e=>setForm(v=>({...v,name:e.target.value}))} required/></label><label>CÃ³digo<input value={form.code} onChange={e=>setForm(v=>({...v,code:e.target.value}))} required/></label><label>Sucursal<select value={form.branch_id} onChange={e=>setForm(v=>({...v,branch_id:e.target.value}))}><option value="">Corporativo</option>{organization.branches.map(x=><option key={x.id} value={x.id}>{x.name}</option>)}</select></label><label>Supervisor<select value={form.supervisor} onChange={e=>setForm(v=>({...v,supervisor:e.target.value}))}><option value="">Sin asignar</option>{supervisors.map(x=><option key={x.id} value={x.id}>{x.full_name}</option>)}</select></label><label>DescripciÃ³n<input value={form.description} onChange={e=>setForm(v=>({...v,description:e.target.value}))}/></label><label><input type="checkbox" checked={form.is_active} onChange={e=>setForm(v=>({...v,is_active:e.target.checked}))}/> Activo</label><label>Motivo<input value={reason} onChange={e=>setReason(e.target.value)} required/></label><button className="primary" disabled={busy}>Guardar</button></form>} table={<SimpleTable headers={['CÃ³digo','Departamento','Sucursal','Supervisor','']} rows={organization.departments.map(x=>{const assignment=organization.departmentAssignments.find(a=>a.departamento_id===x.id);return[x.code,x.name,organization.branches.find(b=>b.id===x.branch_id)?.name??'Corporativo',organization.profiles.find(p=>p.id===assignment?.perfil_id)?.full_name??'Sin asignar',<button className="secondary" onClick={()=>edit(x)}>Editar</button>]})}/>}/></AdminShell>}

function PositionsSection({organization,busy,run}:Common){const[editing,setEditing]=useState<string|null>(null),[form,setForm]=useState(defaultPosition),[reason,setReason]=useState('');function edit(x:Position){setEditing(x.id);setForm({name:x.name,code:x.code,department_id:x.department_id??'',description:x.description??'',level:x.level,is_active:x.is_active})}async function save(e:FormEvent){e.preventDefault();if(await run(()=>administrationService.savePosition(editing,form,reason),editing?'Cargo actualizado':'Cargo creado')){setEditing(null);setForm(defaultPosition);setReason('')}}return <AdminShell title="Cargos"><CrudLayout form={<form className="panel admin-form single" onSubmit={save}><h2>{editing?'Editar cargo':'Nuevo cargo'}</h2><label>Nombre<input value={form.name} onChange={e=>setForm(v=>({...v,name:e.target.value}))} required/></label><label>CÃ³digo<input value={form.code} onChange={e=>setForm(v=>({...v,code:e.target.value}))} required/></label><label>Departamento<select value={form.department_id} onChange={e=>setForm(v=>({...v,department_id:e.target.value}))}><option value="">General</option>{organization.departments.map(x=><option key={x.id} value={x.id}>{x.name}</option>)}</select></label><label>Nivel<input type="number" min="1" max="20" value={form.level} onChange={e=>setForm(v=>({...v,level:Number(e.target.value)}))}/></label><label>DescripciÃ³n<input value={form.description} onChange={e=>setForm(v=>({...v,description:e.target.value}))}/></label><label><input type="checkbox" checked={form.is_active} onChange={e=>setForm(v=>({...v,is_active:e.target.checked}))}/> Activo</label><label>Motivo<input value={reason} onChange={e=>setReason(e.target.value)} required/></label><button className="primary" disabled={busy}>Guardar</button></form>} table={<SimpleTable headers={['CÃ³digo','Cargo','Departamento','Estado','']} rows={organization.positions.map(x=>[x.code,x.name,organization.departments.find(d=>d.id===x.department_id)?.name??'General',<Badge tone={x.is_active?'green':'gray'}>{x.is_active?'Activo':'Inactivo'}</Badge>,<button className="secondary" onClick={()=>edit(x)}>Editar</button>])}/>}/></AdminShell>}

function UsersSection({
  organization,
  busy,
  run,
  hasPermission,
}: Common & {
  hasPermission: (permission: string) => boolean;
}) {
  const [reason, setReason] = useState('');
  const [editingRoleId, setEditingRoleId] = useState<string | null>(null);
  const [roleForm, setRoleForm] = useState({
    name: '',
    code: '',
    description: '',
    isActive: true,
  });
  const [search, setSearch] = useState('');
  const [expanded, setExpanded] = useState<Record<string, boolean>>({});
  const [selectedPermissions, setSelectedPermissions] = useState<string[]>([]);

  const canManageRoles = hasPermission('roles.administrar');
  const canManagePermissions = hasPermission('permisos.administrar');
  const activePermissions = useMemo(
    () => organization.permissions.filter((permission) => permission.activo),
    [organization.permissions],
  );
  const dependencyMap = useMemo(
    () => buildDependencyMap(activePermissions),
    [activePermissions],
  );
  const editingRole = organization.roles.find(
    (role) => role.id === editingRoleId,
  );

  const selectedPermissionsSet = useMemo(
    () => new Set(selectedPermissions),
    [selectedPermissions],
  );

  const groupedPermissions = useMemo(() => {
    const groups = new Map<string, Permission[]>();
    for (const permission of activePermissions) {
      const module = moduleFrom(permission);
      const permissions = groups.get(module);
      if (permissions) {
        permissions.push(permission);
      } else {
        groups.set(module, [permission]);
      }
    }
    for (const permissions of groups.values()) {
      permissions.sort((a, b) => permissionLabel(a).localeCompare(permissionLabel(b)));
    }

    const normalized = search.trim().toLowerCase();
    return [...groups.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([module, permissions]) => {
        const list = normalized
          ? permissions.filter((permission) => matchesSearch(permission, normalized))
          : permissions;
        return {
          module,
          title: moduleTitle(module),
          color: colorForModule(module),
          permissions: list,
          total: permissions.length,
          selectedCount: list.filter((permission) =>
            selectedPermissionsSet.has(permission.id),
          ).length,
        };
      });
  }, [activePermissions, search, selectedPermissionsSet]);

  const anyPermissionVisible = useMemo(
    () => groupedPermissions.some((group) => group.permissions.length > 0),
    [groupedPermissions],
  );

  useEffect(() => {
    if (!groupedPermissions.length) {
      setExpanded({});
      return;
    }

    setExpanded((current) => {
      const next: Record<string, boolean> = { ...current };
      let changed = false;
      const visibleModules = new Set(groupedPermissions.map((group) => group.module));

      for (const module of Object.keys(next)) {
        if (!visibleModules.has(module)) {
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

      if (!changed) {
        return current;
      }
      return next;
    });
  }, [groupedPermissions]);

  useEffect(() => {
    const normalized = search.trim();
    setExpanded((current) => {
      if (!normalized) {
        return current;
      }
      const next = { ...current };
      let changed = false;
      for (const { module, permissions } of groupedPermissions) {
        const shouldOpen = permissions.length > 0;
        if (next[module] !== shouldOpen) {
          next[module] = shouldOpen;
          changed = true;
        }
      }
      if (!changed) {
        return current;
      }
      return next;
    });
  }, [search, groupedPermissions]);

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

  function rolePermissionIds(roleId: string) {
    return organization.rolePermissions
      .filter(
        (rolePermission) =>
          rolePermission.rol_id === roleId && rolePermission.permitido,
      )
      .map((rolePermission) => rolePermission.permiso_id);
  }

  function assignedUsers(roleId: string) {
    return organization.profiles.filter((profile) => profile.role_id === roleId);
  }

  function syncDependencies(
    nextSet: Set<string>,
    permissionId: string,
    checked: boolean,
  ) {
    return applyDependencyRules(nextSet, dependencyMap, permissionId, checked);
  }

  function applyTemplatePermissionSet(
    templateKey:
      | 'administrador'
      | 'supervisor'
      | 'rrhh'
      | 'nomina'
      | 'auditor'
      | 'empleado',
    current: Set<string>,
  ) {
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

  function normalizeSelected(permissions: Iterable<string>) {
    let next = new Set(permissions);
    for (const permissionId of Array.from(next)) {
      next = syncDependencies(next, permissionId, true);
    }
    return [...next];
  }

  function resetRoleForm() {
    setEditingRoleId(null);
    setRoleForm({
      name: '',
      code: '',
      description: '',
      isActive: true,
    });
    setSearch('');
    setSelectedPermissions([]);
  }

  function editRole(role: {
    id: string;
    name: string;
    code: string;
    description: string | null;
    is_active: boolean;
  }) {
    const normalized = normalizeSelected(rolePermissionIds(role.id));
    setEditingRoleId(role.id);
    setRoleForm({
      name: role.name,
      code: role.code,
      description: role.description ?? '',
      isActive: role.is_active,
    });
    setSelectedPermissions(normalized);
    setSearch('');
  }

  async function saveRole(event: FormEvent) {
    event.preventDefault();

    if (
      busy ||
      !roleForm.name.trim() ||
      !roleForm.code.trim() ||
      (editingRoleId !== null && !reason.trim())
    ) {
      return;
    }

    const created = editingRoleId === null;
    const saved = await run(async () => {
      const roleId = await administrationService.saveRole(
        editingRoleId,
        roleForm.name,
        roleForm.code,
        roleForm.description,
        roleForm.isActive,
        created ? '' : reason,
      );
      const previousPermissions = new Set(
        editingRoleId ? rolePermissionIds(editingRoleId) : [],
      );
      const nextPermissions = new Set(selectedPermissions);
      const permissionReason = created
        ? 'CreaciÃ³n inicial del rol'
        : reason;
      for (const permission of activePermissions) {
        const wasAssigned = previousPermissions.has(permission.id);
        const isAssigned = nextPermissions.has(permission.id);

        if (wasAssigned !== isAssigned) {
          await administrationService.setRolePermission(
            roleId,
            permission.id,
            isAssigned,
            permissionReason,
          );
        }
      }
    }, created ? 'Rol creado' : 'Rol actualizado');

    if (saved) {
      resetRoleForm();
    }
  }

  async function toggleRoleStatus(role: {
    id: string;
    name: string;
    code: string;
    description: string | null;
    is_active: boolean;
  }) {
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
    if (
      !window.confirm(
        `Â¿Confirmas ${action} el rol "${role.name}"? Esta acciÃ³n quedarÃ¡ auditada.`,
      )
    ) {
      return;
    }

    await run(
      () =>
        administrationService.saveRole(
          role.id,
          role.name,
          role.code,
          role.description ?? '',
          !deactivating,
          reason,
        ),
      deactivating ? 'Rol desactivado' : 'Rol activado',
    );
  }

  function setModuleExpanded(module: string) {
    setExpanded((current) => ({
      ...current,
      [module]: !current[module],
    }));
  }

  function applyQuickTemplate(
    key:
      | 'administrador'
      | 'supervisor'
      | 'rrhh'
      | 'nomina'
      | 'auditor'
      | 'empleado',
  ) {
    setSelectedPermissions((current) => {
      const next = applyTemplatePermissionSet(key, new Set(current));
      return [...next];
    });
  }

  function togglePermission(permission: Permission, checked: boolean) {
    setSelectedPermissions((current) => {
      const next = syncDependencies(new Set(current), permission.id, checked);
      return [...next];
    });
  }

  return (
    <AdminShell title="Roles y permisos">
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
            placeholder="Obligatorio para editar, permisos y estado"
          />
        </label>
      </div>

      {canManageRoles && (
        <>
          <section className="panel admin-role-panel">
            <form
              className="admin-inline-form"
              onSubmit={(event) => void saveRole(event)}
            >
              <h2>{editingRoleId ? 'Editar rol' : 'Nuevo rol'}</h2>

              <input
                placeholder="Nombre"
                value={roleForm.name}
                onChange={(event) =>
                  setRoleForm((current) => ({
                    ...current,
                    name: event.target.value,
                  }))
                }
                required
              />
              <input
                placeholder="CÃ³digo"
                value={roleForm.code}
                onChange={(event) =>
                  setRoleForm((current) => ({
                    ...current,
                    code: event.target.value,
                  }))
                }
                required
                readOnly={editingRoleId !== null}
                title={
                  editingRoleId
                    ? 'El cÃ³digo tÃ©cnico del rol no se modifica.'
                    : undefined
                }
              />
              <input
                placeholder="DescripciÃ³n"
                value={roleForm.description}
                onChange={(event) =>
                  setRoleForm((current) => ({
                    ...current,
                    description: event.target.value,
                  }))
                }
              />

              <button
                className="primary"
                disabled={
                  busy ||
                  !roleForm.name.trim() ||
                  !roleForm.code.trim() ||
                  (editingRoleId !== null && !reason.trim())
                }
              >
                {busy
                  ? 'Guardandoâ€¦'
                  : editingRoleId
                    ? 'Guardar cambios'
                    : 'Crear rol'}
              </button>
              {editingRoleId && (
                <button
                  type="button"
                  className="secondary"
                  disabled={busy}
                  onClick={resetRoleForm}
                >
                  Cancelar ediciÃ³n
                </button>
              )}
            </form>
          </section>

          <section className="panel admin-role-permissions">
            <header className="admin-role-permissions__header">
              <div>
                <h2>{editingRoleId ? 'Permisos del rol' : 'Permisos iniciales del rol'}</h2>
                <small>
                  {editingRole
                    ? `Rol: ${editingRole.name}`
                    : 'Plantilla visual de permisos'}
                </small>
              </div>
              {canManagePermissions && (
                <button
                  type="button"
                  className="secondary"
                  onClick={() => setSelectedPermissions([])}
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
                />
              </label>

              {canManagePermissions && (
                <div className="admin-template-row">
                  {quickTemplates.map((template) => (
                    <button
                      key={template.key}
                      type="button"
                      className="secondary"
                      onClick={() =>
                        applyQuickTemplate(
                          template.key as
                            | 'administrador'
                            | 'supervisor'
                            | 'rrhh'
                            | 'nomina'
                            | 'auditor'
                            | 'empleado',
                        )
                      }
                    >
                      {template.label}
                    </button>
                  ))}
                </div>
              )}
            </div>

            {canManagePermissions && (
              <div className="admin-permission-categories">
                {!anyPermissionVisible && (
                  <div className="admin-empty-permissions">
                    Sin coincidencias para esta bÃºsqueda.
                  </div>
                )}
                {groupedPermissions.map(
                  ({ module, title, color, permissions, total, selectedCount }) => {
                    if (!permissions.length) {
                      return null;
                    }
                    const isOpen = expanded[module] ?? false;
                    return (
                      <section
                        key={module}
                        className={`admin-permission-category admin-permission-category-${color}`}
                      >
                        <button
                          className="admin-permission-category-head"
                          type="button"
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
                              <label
                                key={permission.id}
                                className={`admin-permission-row ${checked ? 'selected' : ''}`}
                                title={tooltipForPermission(permission)}
                              >
                                <input
                                  type="checkbox"
                                  checked={checked}
                                  disabled={busy || (editingRoleId !== null && !reason.trim())}
                                  onChange={(event) =>
                                    togglePermission(permission, event.target.checked)
                                  }
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
                  },
                )}
              </div>
            )}

            {!canManagePermissions && (
              <div className="admin-empty-permissions">
                No tienes permiso para administrar permisos.
              </div>
            )}

            {editingRoleId && !reason.trim() && (
              <small>Escribe el motivo para modificar los permisos del rol.</small>
            )}
          </section>

          <section className="panel admin-role-panel">
            <h2>Roles existentes</h2>
            <SimpleTable
              headers={[
                'Nombre',
                'CÃ³digo',
                'DescripciÃ³n',
                'Estado',
                'Permisos',
                'Acciones',
              ]}
              rows={organization.roles.map((role) => {
                const users = assignedUsers(role.id);
                const isPrimaryAdministrator = isAdministratorRole(role);
                const canDeactivate =
                  role.is_active &&
                  !isPrimaryAdministrator &&
                  users.length === 0;
                const actionDisabled =
                  busy ||
                  !reason.trim() ||
                  (role.is_active && !canDeactivate);

                return [
                  role.name,
                  <code key={`${role.id}-code`}>{role.code}</code>,
                  role.description || 'â€”',
                  <Badge
                    key={`${role.id}-status`}
                    tone={role.is_active ? 'green' : 'gray'}
                  >
                    {role.is_active ? 'Activo' : 'Inactivo'}
                  </Badge>,
                  `${rolePermissionIds(role.id).length} permiso(s)`,
                  <div key={`${role.id}-actions`} className="button-row">
                    <button
                      className="secondary"
                      disabled={busy}
                      onClick={() => editRole(role)}
                    >
                      Editar
                    </button>
                    <button
                      className="secondary"
                      disabled={actionDisabled}
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
                    {users.length > 0 && (
                      <small>
                        {users.length} usuario(s) asignado(s): reasignaciÃ³n
                        requerida
                      </small>
                    )}
                  </div>,
                ];
              })}
            />
          </section>
        </>
      )}
    </AdminShell>
  );
}
function JourneysSection({overview}:{overview:AdministrationOverview}){return <AdminShell title="Jornadas" action={<Link className="primary" to="/jornadas">Abrir jornadas</Link>}><section className="stats admin-mini-stats"><article className="stat"><span>Pendientes de revisiÃ³n</span><strong>{overview.counts.pending_journeys}</strong></article><article className="stat"><span>Reglas</span><strong>RC2</strong><small>Cierre e incidencias centralizados</small></article><article className="stat"><span>ADMIN-OFF/ON</span><strong>Protegido</strong><small>Requiere permiso explÃ­cito</small></article></section><div className="panel"><h2>OperaciÃ³n segura</h2><p>Las reglas, cierres automÃ¡ticos, incidencias y pendientes se administran en el mÃ³dulo real de Jornadas. Esta pantalla no duplica ni altera el motor RC2/RC3.</p><div className="button-row"><Link className="secondary" to="/pendientes">RevisiÃ³n de pendientes</Link><Link className="secondary" to="/incidencias">Incidencias</Link></div></div></AdminShell>}
function SecuritySection({overview,audit}:{overview:AdministrationOverview;audit:AuditEvent[]}){return <AdminShell title="Seguridad" action={<Link className="primary" to="/cambiar-password">Cambiar contraseÃ±a</Link>}><section className="panel admin-session"><ShieldCheck/><div><h2>SesiÃ³n administrativa activa</h2><p>Usuario {overview.session.auth_uid} Â· Rol {overview.session.role} Â· Empresa {overview.company.name}</p><small>No se muestran tokens ni credenciales.</small></div></section><SimpleTable headers={['Fecha','SecciÃ³n','AcciÃ³n','Entidad','Motivo']} rows={audit.map(x=>[new Date(x.fecha).toLocaleString('es-DO'),x.seccion,x.accion,`${x.entidad}${x.entidad_id?` Â· ${x.entidad_id}`:''}`,x.motivo??'â€”'])}/>{!audit.length&&<Empty text="No hay eventos administrativos visibles para esta empresa."/>}</AdminShell>}

function CrudLayout({form,table}:{form:ReactNode;table:ReactNode}){return <div className="admin-crud">{form}<section className="table-wrap">{table}</section></div>}
function SimpleTable({headers,rows}:{headers:string[];rows:ReactNode[][]}){return <div className="table-wrap"><table><thead><tr>{headers.map(x=><th key={x}>{x}</th>)}</tr></thead><tbody>{rows.map((row,i)=><tr key={i}>{row.map((cell,j)=><td key={j}>{cell}</td>)}</tr>)}</tbody></table>{!rows.length&&<Empty text="No hay datos visibles para este alcance."/>}</div>}

